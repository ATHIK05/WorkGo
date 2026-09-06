import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:workgo_core/workgo_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/screens/customer_home_screen.dart';

/// Enables drag-scrolling across touch, mouse, trackpad, and stylus devices
class WorkGoScrollBehavior extends MaterialScrollBehavior {
  const WorkGoScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: WorkGoFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init note: $e");
  }

  // Pre-warm local session cache
  await SessionManager.instance.init();

  // Initialize Push Notifications
  await PushNotificationService.instance.initialize(userType: 'customer');

  runApp(
    EasyLocalization(
      supportedLocales: WorkGoLocale.supported,
      path: WorkGoLocale.assetPath,
      fallbackLocale: WorkGoLocale.fallback,
      child: const WorkGoCustomerApp(),
    ),
  );
}

final GlobalKey<NavigatorState> customerNavigatorKey =
    GlobalKey<NavigatorState>();

class WorkGoCustomerApp extends StatefulWidget {
  const WorkGoCustomerApp({super.key});

  @override
  State<WorkGoCustomerApp> createState() => _WorkGoCustomerAppState();
}

class _WorkGoCustomerAppState extends State<WorkGoCustomerApp> {
  bool _hasSeenSplash = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: customerNavigatorKey,
      title: 'WorkGo Customer',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const WorkGoScrollBehavior(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: WorkGoTheme.light(),
      darkTheme: WorkGoTheme.dark(),
      themeMode: ThemeMode.light,
      home: _hasSeenSplash
          ? const CustomerRootScreen()
          : WorkGoSplashScreen(
              totalDuration: const Duration(milliseconds: 2800),
              onFinish: () {
                if (mounted) {
                  setState(() {
                    _hasSeenSplash = true;
                  });
                }
              },
              nextScreen: const CustomerRootScreen(),
            ),
    );
  }
}

class CustomerRootScreen extends StatefulWidget {
  const CustomerRootScreen({super.key});

  @override
  State<CustomerRootScreen> createState() => _CustomerRootScreenState();
}

class _CustomerRootScreenState extends State<CustomerRootScreen> {
  final AuthService _authService = AuthService();
  AppUser? _cachedUser;
  bool _isLoadingCache = true;
  String? _lastSyncedTokenUid;

  @override
  void initState() {
    super.initState();
    _loadInitialSession();
  }

  Future<void> _loadInitialSession() async {
    final cached = await _authService.getCachedSession(UserRole.customer);
    if (mounted) {
      setState(() {
        _cachedUser = cached;
        _isLoadingCache = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCache) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0E17),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFFB800),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        final firebaseUser = authSnapshot.data;

        // If no active Firebase user and no cached user, show AuthShell
        if (firebaseUser == null && _cachedUser == null) {
          return AuthShell(
            role: UserRole.customer,
            onSuccess: (user) {
              setState(() {
                _cachedUser = user;
              });
            },
          );
        }

        // If we have a cached user but Firebase Auth is still resolving, use cached user
        final effectiveUid = firebaseUser?.uid ?? _cachedUser?.uid;
        if (effectiveUid == null || effectiveUid.isEmpty) {
          return AuthShell(
            role: UserRole.customer,
            onSuccess: (user) {
              setState(() {
                _cachedUser = user;
              });
            },
          );
        }

        return StreamBuilder<AppUser?>(
          stream: _authService.streamAppUser(effectiveUid),
          builder: (context, userSnapshot) {
            final appUser =
                userSnapshot.data ??
                _cachedUser ??
                AppUser(
                  uid: effectiveUid,
                  email: firebaseUser?.email ?? _cachedUser?.email ?? "",
                  displayName:
                      firebaseUser?.displayName ??
                      _cachedUser?.displayName ??
                      "Customer",
                  role: UserRole.customer,
                  region: "Tamil Nadu",
                );

            // Sync device token to Firestore for customer push notifications (idempotent, outside build)
            if (_lastSyncedTokenUid != appUser.uid) {
              _lastSyncedTokenUid = appUser.uid;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PushNotificationService.instance.syncDeviceToken(
                  appUser.uid,
                  userType: 'customer',
                  preferredLanguage: context.locale.languageCode,
                );
              });
            }

            return CustomerHomeScreen(
              user: appUser,
              onSignOut: () async {
                customerNavigatorKey.currentState?.popUntil(
                  (route) => route.isFirst,
                );
                setState(() {
                  _cachedUser = null;
                });
                await _authService.signOut(role: UserRole.customer);
              },
            );
          },
        );
      },
    );
  }
}
