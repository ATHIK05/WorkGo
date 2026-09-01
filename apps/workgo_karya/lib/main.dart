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

  try {
    await Firebase.initializeApp(options: WorkGoFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase init note: $e");
  }

  runApp(
    EasyLocalization(
      supportedLocales: WorkGoLocale.supported,
      path: WorkGoLocale.assetPath,
      fallbackLocale: WorkGoLocale.fallback,
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
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: WorkGoTheme.light(),
      darkTheme: WorkGoTheme.dark(),
      themeMode: ThemeMode.dark,
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
  bool _forceSkipOnboarding = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const WorkGoSplashScreen(
            appName: 'WorkGo Karya',
            tagline: 'Artisan Co-op Network',
          );
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return AuthShell(
            role: UserRole.worker,
            onSuccess: (user) {
              setState(() {
                _forceSkipOnboarding = false;
              });
            },
          );
        }

        return StreamBuilder<AppUser?>(
          stream: _authService.streamAppUser(firebaseUser.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting &&
                !userSnapshot.hasData) {
              return const WorkGoSplashScreen(
                appName: 'WorkGo Karya',
                tagline: 'Artisan Co-op Network',
              );
            }

            final appUser = userSnapshot.data ??
                AppUser(
                  uid: firebaseUser.uid,
                  email: firebaseUser.email ?? "",
                  displayName: firebaseUser.displayName ?? "Artisan",
                  role: UserRole.worker,
                  region: "Tamil Nadu",
                );

            return StreamBuilder<Worker?>(
              stream: _workerService.streamWorker(firebaseUser.uid),
              builder: (context, workerSnapshot) {
                if (workerSnapshot.connectionState == ConnectionState.waiting &&
                    !workerSnapshot.hasData) {
                  return const WorkGoSplashScreen(
                    appName: 'WorkGo Karya',
                    tagline: 'Artisan Co-op Network',
                  );
                }

                final worker = workerSnapshot.data;
                // If worker document does not exist or skills are empty, prompt onboarding once
                if (!_forceSkipOnboarding && (worker == null || worker.skills.isEmpty)) {
                  final initialWorker = worker ??
                      Worker(
                        id: firebaseUser.uid,
                        userId: firebaseUser.uid,
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

                return KaryaHomeScreen(
                  user: appUser,
                  onSignOut: () async {
                    karyaNavigatorKey.currentState?.popUntil((route) => route.isFirst);
                    setState(() {
                      _forceSkipOnboarding = false;
                    });
                    await _authService.signOut();
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


