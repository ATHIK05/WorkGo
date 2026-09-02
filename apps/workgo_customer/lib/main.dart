import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:workgo_core/workgo_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/screens/customer_home_screen.dart';

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
      child: const WorkGoCustomerApp(),
    ),
  );
}

final GlobalKey<NavigatorState> customerNavigatorKey = GlobalKey<NavigatorState>();

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
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

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return AuthShell(
            role: UserRole.customer,
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

            final appUser = userSnapshot.data ??
                AppUser(
                  uid: firebaseUser.uid,
                  email: firebaseUser.email ?? "",
                  displayName: firebaseUser.displayName ?? "Customer",
                  role: UserRole.customer,
                  region: "Tamil Nadu",
                );

            return CustomerHomeScreen(
              user: appUser,
              onSignOut: () async {
                customerNavigatorKey.currentState?.popUntil((route) => route.isFirst);
                await _authService.signOut();
              },
            );
          },
        );
      },
    );
  }
}


