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
      darkTheme: WorkGoTheme.dark(),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const WorkGoSplashScreen(
            appName: "WorkGo Console",
            tagline: "Cooperative Governance & Telemetry Cockpit",
          );
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return AuthShell(
            role: UserRole.admin,
            onSuccess: (user) {
              setState(() {});
            },
          );
        }

        return StreamBuilder<AppUser?>(
          stream: _authService.streamAppUser(firebaseUser.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting &&
                !userSnapshot.hasData) {
              return const WorkGoSplashScreen(
                appName: "WorkGo Console",
                tagline: "Cooperative Governance & Telemetry Cockpit",
              );
            }

            final appUser = userSnapshot.data ??
                AppUser(
                  uid: firebaseUser.uid,
                  email: firebaseUser.email ?? "admin@workgo.coop",
                  role: UserRole.admin,
                  displayName: firebaseUser.displayName ?? "Cooperative Administrator",
                  region: "Tamil Nadu",
                );

            return AdminDashboardScreen(
              user: appUser,
              onSignOut: () async {
                adminNavigatorKey.currentState?.popUntil((route) => route.isFirst);
                await _authService.signOut();
              },
            );
          },
        );
      },
    );
  }
}
