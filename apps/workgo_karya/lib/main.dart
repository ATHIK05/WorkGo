import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:workgo_core/workgo_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/screens/karya_home_screen.dart';
import 'src/screens/worker_onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await WorkGoLocale.ensureInitialized();

  try {
    await Firebase.initializeApp(options: WorkGoFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase init note: $e");
  }

  // Pre-warm local session cache
  await SessionManager.instance.init();

  // Initialize Push Notifications
  await PushNotificationService.instance.initialize(userType: 'worker');

  runApp(
    EasyLocalization(
      supportedLocales: WorkGoLocale.supported,
      path: WorkGoLocale.assetPath,
      fallbackLocale: WorkGoLocale.fallback,
      assetLoader: WorkGoLocale.loader,
      child: const WorkGoKaryaApp(),
    ),
  );
}

final GlobalKey<NavigatorState> karyaNavigatorKey = GlobalKey<NavigatorState>();

class WorkGoKaryaApp extends StatelessWidget {
  const WorkGoKaryaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: karyaNavigatorKey,
      title: 'WorkGo Karya',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: WorkGoLocale.delegates(context),
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: WorkGoTheme.light(),
      darkTheme: WorkGoTheme.dark(),
      themeMode: ThemeMode.light,
      home: WorkGoSplashScreen(
        totalDuration: const Duration(milliseconds: 3200),
        appName: 'WorkGo Karya',
        tagline: 'Artisan Co-op Network',
        nextScreen: const KaryaRootScreen(),
      ),
    );
  }
}

class KaryaRootScreen extends StatefulWidget {
  const KaryaRootScreen({super.key});

  @override
  State<KaryaRootScreen> createState() => _KaryaRootScreenState();
}

class _KaryaRootScreenState extends State<KaryaRootScreen> {
  final AuthService _authService = AuthService();
  final WorkerService _workerService = WorkerService();
  AppUser? _cachedUser;
  bool _isLoadingCache = true;
  bool _forceSkipOnboarding = false;
  String? _lastSyncedTokenUid;

  @override
  void initState() {
    super.initState();
    _loadInitialSession();
  }

  Future<void> _loadInitialSession() async {
    final cached = await _authService.getCachedSession(UserRole.worker);
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
        appName: 'WorkGo Karya',
        tagline: 'Artisan Co-op Network',
      );
    }

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        final firebaseUser = authSnapshot.data;

        // If no active Firebase user and no cached user, show AuthShell
        if (firebaseUser == null && _cachedUser == null) {
          return AuthShell(
            role: UserRole.worker,
            onSuccess: (user) {
              setState(() {
                _cachedUser = user;
                _forceSkipOnboarding = false;
              });
            },
          );
        }

        final effectiveUid = firebaseUser?.uid ?? _cachedUser?.uid;
        if (effectiveUid == null || effectiveUid.isEmpty) {
          return AuthShell(
            role: UserRole.worker,
            onSuccess: (user) {
              setState(() {
                _cachedUser = user;
                _forceSkipOnboarding = false;
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
                  email: firebaseUser?.email ?? _cachedUser?.email ?? "",
                  displayName: firebaseUser?.displayName ?? _cachedUser?.displayName ?? "Artisan",
                  role: UserRole.worker,
                  region: "Tamil Nadu",
                );

            return StreamBuilder<Worker?>(
              stream: _workerService.streamWorker(effectiveUid),
              builder: (context, workerSnapshot) {
                final worker = workerSnapshot.data;
                // If worker document does not exist or skills are empty, prompt onboarding once
                if (!_forceSkipOnboarding && (worker == null || worker.skills.isEmpty)) {
                  final initialWorker = worker ??
                      Worker(
                        id: effectiveUid,
                        userId: effectiveUid,
                        name: appUser.displayName.isNotEmpty ? appUser.displayName : "Co-op Artisan",
                        organizationId: "coop_tn_01",
                        skills: const ["Plumbing", "Electrical"],
                        experienceYears: 2,
                        verificationStatus: VerificationStatus.pending,
                        availabilityStatus: AvailabilityStatus.offline,
                        isCheckedIn: false,
                        serviceRadiusKm: 10.0,
                      );

                  return WorkerOnboardingScreen(
                    worker: initialWorker,
                    onComplete: () {
                      setState(() {
                        _forceSkipOnboarding = true;
                      });
                    },
                  );
                }

                // Sync device token to Firestore for artisan push notifications (idempotent, outside build)
                if (_lastSyncedTokenUid != effectiveUid) {
                  _lastSyncedTokenUid = effectiveUid;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PushNotificationService.instance.syncDeviceToken(
                      effectiveUid,
                      userType: 'worker',
                      preferredLanguage: context.locale.languageCode,
                    );
                    if (worker != null && worker.skills.isNotEmpty) {
                      for (final skill in worker.skills) {
                        PushNotificationService.instance.subscribeToTradeTopic(skill);
                      }
                    }
                  });
                }

                return KaryaHomeScreen(
                  user: appUser,
                  onSignOut: () async {
                    karyaNavigatorKey.currentState?.popUntil((route) => route.isFirst);
                    setState(() {
                      _cachedUser = null;
                      _forceSkipOnboarding = false;
                    });
                    await _authService.signOut(role: UserRole.worker);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}


