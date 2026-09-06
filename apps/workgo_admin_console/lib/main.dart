import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workgo_core/workgo_core.dart';
import 'src/screens/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  try {
    await Firebase.initializeApp(options: WorkGoFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase init note: $e");
  }

  // Pre-warm local session cache
  await SessionManager.instance.init();

  runApp(
    EasyLocalization(
      supportedLocales: WorkGoLocale.supported,
      path: WorkGoLocale.assetPath,
      fallbackLocale: WorkGoLocale.fallback,
      child: const WorkGoAdminApp(),
    ),
  );
}

final GlobalKey<NavigatorState> adminNavigatorKey = GlobalKey<NavigatorState>();

class WorkGoAdminApp extends StatelessWidget {
  const WorkGoAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: adminNavigatorKey,
      title: 'WorkGo Console',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: WorkGoTheme.light(),
      darkTheme: WorkGoTheme.light(),
      themeMode: ThemeMode.light,
      home: WorkGoSplashScreen(
        totalDuration: const Duration(milliseconds: 2400),
        appName: "WorkGo Console",
        tagline: "Cooperative Governance & Telemetry Cockpit",
        nextScreen: const AdminRootScreen(),
      ),
    );
  }
}

class AdminRootScreen extends StatefulWidget {
  const AdminRootScreen({super.key});

  @override
  State<AdminRootScreen> createState() => _AdminRootScreenState();
}

class _AdminRootScreenState extends State<AdminRootScreen> {
  final AuthService _authService = AuthService();
  AppUser? _cachedUser;
  bool _isLoadingCache = true;

  @override
  void initState() {
    super.initState();
    _loadInitialSession();
  }

  Future<void> _loadInitialSession() async {
    final cached = await _authService.getCachedSession(UserRole.admin);
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
      return const WorkGoSplashScreen(
        appName: "WorkGo Console",
        tagline: "Cooperative Governance & Telemetry Cockpit",
      );
    }

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        final firebaseUser = authSnapshot.data;

        // If no active Firebase user and no cached user, show AuthShell
        if (firebaseUser == null && _cachedUser == null) {
          return AuthShell(
            role: UserRole.admin,
            onSuccess: (user) {
              setState(() {
                _cachedUser = user;
              });
            },
          );
        }

        final effectiveUid = firebaseUser?.uid ?? _cachedUser?.uid;
        if (effectiveUid == null || effectiveUid.isEmpty) {
          return AuthShell(
            role: UserRole.admin,
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
            final appUser = userSnapshot.data ??
                _cachedUser ??
                AppUser(
                  uid: effectiveUid,
                  email: firebaseUser?.email ?? _cachedUser?.email ?? "admin@workgo.coop",
                  role: UserRole.admin,
                  displayName: firebaseUser?.displayName ?? _cachedUser?.displayName ?? "Cooperative Administrator",
                  region: "Tamil Nadu",
                );

            return AdminDashboardScreen(
              user: appUser,
              onSignOut: () async {
                adminNavigatorKey.currentState?.popUntil((route) => route.isFirst);
                setState(() {
                  _cachedUser = null;
                });
                await _authService.signOut(role: UserRole.admin);
              },
            );
          },
        );
      },
    );
  }
}
