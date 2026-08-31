import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class WorkGoAdminApp extends StatelessWidget {
  const WorkGoAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkGo Console',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: WorkGoTheme.light(),
      darkTheme: WorkGoTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const AdminRootScreen(),
    );
  }
}

class AdminRootScreen extends StatefulWidget {
  const AdminRootScreen({super.key});

  @override
  State<AdminRootScreen> createState() => _AdminRootScreenState();
}

class _AdminRootScreenState extends State<AdminRootScreen> {
  AppUser? _currentUser;
  bool _isSplashActive = true;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkPersistedUserSession();
  }

  Future<void> _checkPersistedUserSession() async {
    try {
      final fbUser = _authService.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final persistedEmail = prefs.getString("workgo_admin_email");

      if (fbUser != null) {
        var user = await _authService.fetchUser(fbUser.uid);
        user ??= AppUser(
          uid: fbUser.uid,
          email: fbUser.email ?? (persistedEmail ?? "admin@workgo.coop"),
          role: UserRole.admin,
          displayName: fbUser.displayName ?? "Cooperative Administrator",
          preferredLanguage: prefs.getString("workgo_admin_lang") ?? "en",
          region: "Tamil Nadu",
        );

        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      } else if (persistedEmail != null && persistedEmail.isNotEmpty) {
        // Fallback for persistent web session
        if (mounted) {
          setState(() {
            _currentUser = AppUser(
              uid: "admin_persisted_session",
              email: persistedEmail,
              role: UserRole.admin,
              displayName: "Cooperative Administrator",
              preferredLanguage: prefs.getString("workgo_admin_lang") ?? "en",
              region: "Tamil Nadu",
            );
          });
        }
      }
    } catch (e) {
      debugPrint("Auth session restore note: $e");
    }
  }

  Future<void> _saveUserSession(AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("workgo_admin_email", user.email);
      await prefs.setString("workgo_admin_uid", user.uid);
      if (user.preferredLanguage != null) {
        await prefs.setString("workgo_admin_lang", user.preferredLanguage!);
      }
    } catch (e) {
      debugPrint("Session save note: $e");
    }
  }

  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("workgo_admin_email");
      await prefs.remove("workgo_admin_uid");
      await prefs.remove("workgo_admin_lang");
      await _authService.signOut();
    } catch (e) {
      debugPrint("Session clear note: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Initial Animated Splash Screen
    if (_isSplashActive) {
      return WorkGoSplashScreen(
        appName: "WorkGo Console",
        tagline: "Cooperative Governance & Telemetry Cockpit",
        totalDuration: const Duration(milliseconds: 2400),
        nextScreen: _buildMainScreen(),
      );
    }

    return _buildMainScreen();
  }

  Widget _buildMainScreen() {
    if (_currentUser == null) {
      return AuthShell(
        role: UserRole.admin,
        onSuccess: (user) async {
          await _saveUserSession(user);
          if (mounted) {
            setState(() {
              _currentUser = user;
              _isSplashActive = false;
            });
          }
        },
      );
    }

    return AdminDashboardScreen(
      user: _currentUser!,
      onSignOut: () async {
        await _clearUserSession();
        if (mounted) {
          setState(() {
            _currentUser = null;
            _isSplashActive = false;
          });
        }
      },
    );
  }
}
