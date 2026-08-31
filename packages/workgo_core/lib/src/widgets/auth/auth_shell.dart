import 'dart:math' as math;
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../firebase/auth_service.dart';
import '../../models/app_user.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../safe_text.dart';
import 'auth_role_badge.dart';
import 'forgot_password_form.dart';
import 'sign_in_form.dart';
import 'sign_up_form.dart';
import '../workgo_splash_screen.dart';

enum AuthMode { signIn, signUp, forgotPassword }

/// Immersive Authentication Shell for all WorkGo apps.
/// Features animated mesh gradient, floating glow orbs, frosted glass card,
/// live language switcher, and full Firebase Auth & Firestore upsert integration.
class AuthShell extends StatefulWidget {
  const AuthShell({
    super.key,
    required this.role,
    required this.onSuccess,
    this.initialMode = AuthMode.signIn,
    this.customRoleLabel,
  });

  final UserRole role;
  final void Function(AppUser user) onSuccess;
  final AuthMode initialMode;
  final String? customRoleLabel;

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell>
    with TickerProviderStateMixin {
  late AuthMode _mode;
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  // Background Animation Controllers
  late final AnimationController _bgAnimationController;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  Future<void> _handleSignIn(String email, String password) async {
    final currentLang = context.locale.languageCode;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = await _authService.signIn(email: email, password: password);
      final uid = cred.user!.uid;

      var appUser = await _authService.fetchUser(uid);
      if (appUser == null) {
        // First time or role document setup
        appUser = AppUser(
          uid: uid,
          email: email,
          displayName: cred.user?.displayName ?? email.split('@').first,
          photoUrl: cred.user?.photoURL,
          role: widget.role,
          preferredLanguage: currentLang,
          region: 'IN-TN',
        );
        await _authService.upsertUser(appUser);
      }

      if (mounted) {
        widget.onSuccess(appUser);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = switch (e.code) {
            'user-not-found' || 'wrong-password' || 'invalid-credential' =>
              'error_invalid_credentials'.tr(),
            'network-request-failed' => 'error_network'.tr(),
            'too-many-requests' => 'Too many attempts. Please try again later.',
            _ => e.message ?? 'error_unknown'.tr(),
          };
        });
        _triggerShake();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        _triggerShake();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignUp(
    String name,
    String email,
    String password,
  ) async {
    final currentLang = context.locale.languageCode;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = await _authService.signUp(
        email: email,
        password: password,
        displayName: name,
      );

      final uid = cred.user!.uid;
      final appUser = AppUser(
        uid: uid,
        email: email,
        displayName: name,
        photoUrl: cred.user?.photoURL,
        role: widget.role,
        preferredLanguage: currentLang,
        region: 'IN-TN',
      );

      await _authService.upsertUser(appUser);

      if (mounted) {
        widget.onSuccess(appUser);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = switch (e.code) {
            'email-already-in-use' => 'error_email_in_use'.tr(),
            'weak-password' => 'error_password_short'.tr(),
            'invalid-email' => 'error_email_invalid'.tr(),
            'network-request-failed' => 'error_network'.tr(),
            _ => e.message ?? 'error_unknown'.tr(),
          };
        });
        _triggerShake();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        _triggerShake();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResetPassword(String email) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.sendPasswordReset(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('reset_email_sent'.tr()),
            backgroundColor: WorkGoColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _mode = AuthMode.signIn;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = switch (e.code) {
            'user-not-found' => 'No account found with this email.',
            'invalid-email' => 'error_email_invalid'.tr(),
            _ => e.message ?? 'error_unknown'.tr(),
          };
        });
        _triggerShake();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        _triggerShake();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: WorkGoBrandColors.bgBottom,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Atmospheric Deep Mesh Background ─────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [WorkGoBrandColors.bgTop, WorkGoBrandColors.bgBottom],
                ),
              ),
            ),
          ),

          // ── 2. Soft Ambient Radial Glows (No hard solid shapes) ─────────────
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, _) {
              final t = _bgAnimationController.value * 2 * math.pi;
              final glow = 0.6 + 0.3 * math.sin(t);
              return Stack(
                children: [
                  Align(
                    alignment: const Alignment(0, -0.65),
                    child: Container(
                      width: size.width * 1.1,
                      height: size.width * 1.1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            WorkGoBrandColors.violetCore.withValues(alpha: 0.24 * glow),
                            WorkGoBrandColors.violetDeep.withValues(alpha: 0.08 * glow),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.48, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0.7, 0.6),
                    child: Container(
                      width: size.width * 0.7,
                      height: size.width * 0.7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            WorkGoBrandColors.yellow.withValues(alpha: 0.05 * glow),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── 3. Ambient Floating Particle Field ──────────────────────────────
          CustomPaint(
            painter: WorkGoParticlePainter(
              loopValue: _bgAnimationController.value,
              revealValue: 1.0,
            ),
            size: Size.infinite,
          ),

          // ── 4. Main Auth Content Layer ──────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: WorkGoSpacing.lg,
                  vertical: WorkGoSpacing.md,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTopHeader(context),
                      const SizedBox(height: WorkGoSpacing.xl),

                      if (_errorMessage != null) ...[
                        _buildErrorBanner(),
                        const SizedBox(height: WorkGoSpacing.md),
                      ],

                      AnimatedBuilder(
                        animation: _shakeController,
                        builder: (context, child) {
                          final sine = math.sin(_shakeController.value * 3 * math.pi * 2);
                          final dx = sine * 10 * (1 - _shakeController.value);
                          return Transform.translate(
                            offset: Offset(dx, 0),
                            child: child,
                          );
                        },
                        child: _buildGlassCard(context),
                      ),

                      const SizedBox(height: WorkGoSpacing.xl),

                      SafeText(
                        'WorkGo • 100% Direct Payout to Certified Artisans',
                        style: TextStyle(
                          color: WorkGoBrandColors.textSecondary.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WorkGoMark(size: 38),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SafeText(
                      'WorkGo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SafeText(
                      'app_name'.tr(),
                      style: TextStyle(
                        color: WorkGoBrandColors.textSecondary.withValues(alpha: 0.75),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildLanguageSelector(context),
      ],
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    final currentLang = context.locale.languageCode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1633).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langOption(context, code: 'en', label: 'EN', active: currentLang == 'en'),
          _langOption(context, code: 'hi', label: 'HI', active: currentLang == 'hi'),
          _langOption(context, code: 'ta', label: 'TA', active: currentLang == 'ta'),
        ],
      ),
    );
  }

  Widget _langOption(
    BuildContext context, {
    required String code,
    required String label,
    required bool active,
  }) {
    return GestureDetector(
      onTap: () async {
        if (!active) {
          await context.setLocale(Locale(code));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [WorkGoBrandColors.yellowSoft, WorkGoBrandColors.yellow],
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: WorkGoBrandColors.yellow.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF120B22) : WorkGoBrandColors.textSecondary,
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WorkGoColors.error.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: WorkGoColors.error.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: WorkGoColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(WorkGoSpacing.xl),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1633).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthRoleBadge(
                role: widget.role,
                customLabel: widget.customRoleLabel,
              ),
              const SizedBox(height: WorkGoSpacing.lg),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: switch (_mode) {
                  AuthMode.signIn => SignInForm(
                      key: const ValueKey('signInForm'),
                      isLoading: _isLoading,
                      onSignIn: _handleSignIn,
                      onSwitchToSignUp: () {
                        setState(() {
                          _mode = AuthMode.signUp;
                          _errorMessage = null;
                        });
                      },
                      onForgotPassword: () {
                        setState(() {
                          _mode = AuthMode.forgotPassword;
                          _errorMessage = null;
                        });
                      },
                    ),
                  AuthMode.signUp => SignUpForm(
                      key: const ValueKey('signUpForm'),
                      isLoading: _isLoading,
                      onSignUp: _handleSignUp,
                      onSwitchToSignIn: () {
                        setState(() {
                          _mode = AuthMode.signIn;
                          _errorMessage = null;
                        });
                      },
                    ),
                  AuthMode.forgotPassword => ForgotPasswordForm(
                      key: const ValueKey('forgotPasswordForm'),
                      isLoading: _isLoading,
                      onResetPassword: _handleResetPassword,
                      onBackToSignIn: () {
                        setState(() {
                          _mode = AuthMode.signIn;
                          _errorMessage = null;
                        });
                      },
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
