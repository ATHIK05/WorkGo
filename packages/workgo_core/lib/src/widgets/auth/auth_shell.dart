import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../firebase/auth_service.dart';
import '../../localization/trade_localization.dart';
import '../../models/app_user.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../safe_text.dart';
import 'auth_role_badge.dart';
import 'forgot_password_form.dart';
import 'sign_in_form.dart';
import 'sign_up_form.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF2),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Warm Editorial Light Canvas ───────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFDF9),
                    Color(0xFFFFF8EE),
                    Color(0xFFFFF3D6),
                  ],
                ),
              ),
            ),
          ),

          // ── 2. Soft Warm Amber & Peach Ambient Radial Accents ────────────
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFB800).withValues(alpha: 0.18),
                    const Color(0xFFFEF3C7).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFE3C2).withValues(alpha: 0.35),
                    const Color(0xFFFDE68A).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── 3. Main Auth Content Layer ──────────────────────────────────────
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
                      const SizedBox(height: 20),

                      // Editorial Headline (Image 2 style)
                      _buildEditorialHero(),
                      const SizedBox(height: 22),

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
                        child: _buildLuxuryAuthCard(context),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SafeText(
                            'WorkGo',
                            style: TextStyle(
                              color: Color(0xFF8C7A6B),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFB800),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: SafeText(
                              'direct_payout_certified'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF8C7A6B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              enableAutoShrink: true,
                              minFontSize: 9.5,
                            ),
                          ),
                        ],
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

  Widget _buildEditorialHero() {
    return Column(
      children: [
        SafeText(
          'services_without_limits'.trSafe("Services Without Limits"),
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1.15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        SafeText(
          'auth_hero_subtitle'.trSafe("Connect with verified local craftsmen • 0% commission co-op"),
          style: const TextStyle(
            color: Color(0xFF78716C),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFB800), Color(0xFFF59E0B)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB800).withValues(alpha: 0.38),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.handyman_rounded, color: Color(0xFF1A1A1A), size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SafeText(
                      'WorkGo',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SafeText(
                      'app_name'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF8C7A6B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEFECE6),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFB800), Color(0xFFF59E0B)],
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.32),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF1A1A1A) : const Color(0xFF78716C),
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
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFECDD3),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFE11D48),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFBE123C),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryAuthCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFF0EDE6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 24,
            offset: Offset(0, 8),
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
    );
  }
}
