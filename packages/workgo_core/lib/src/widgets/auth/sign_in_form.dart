import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../theme/spacing.dart';
import '../safe_text.dart';
import 'auth_text_field.dart';

class SignInForm extends StatefulWidget {
  const SignInForm({
    super.key,
    required this.onSignIn,
    required this.onSwitchToSignUp,
    required this.onForgotPassword,
    required this.isLoading,
    this.onSwitchToPhone,
  });

  final Future<void> Function(String email, String password) onSignIn;
  final VoidCallback onSwitchToSignUp;
  final VoidCallback onForgotPassword;
  final bool isLoading;
  final VoidCallback? onSwitchToPhone;

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'error_email_empty'.tr();
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'error_email_invalid'.tr();
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'error_password_empty'.tr();
    }
    if (value.length < 6) {
      return 'error_password_short'.tr();
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSignIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          SafeText(
            'welcome_back'.tr(),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          SafeText(
            'sign_in'.tr(),
            style: const TextStyle(
              color: Color(0xFF78716C),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: WorkGoSpacing.xl),

          // Email Field
          AuthTextField(
            controller: _emailController,
            labelText: 'email'.tr(),
            hintText: 'email_hint'.tr(),
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: _validateEmail,
            enabled: !widget.isLoading,
          ),
          const SizedBox(height: WorkGoSpacing.md),

          // Password Field
          AuthTextField(
            controller: _passwordController,
            labelText: 'password'.tr(),
            hintText: '••••••••',
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            validator: _validatePassword,
            onFieldSubmitted: (_) => _submit(),
            enabled: !widget.isLoading,
          ),
          const SizedBox(height: WorkGoSpacing.xs),

          // Remember Me & Forgot Password Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: InkWell(
                  onTap: widget.isLoading
                      ? null
                      : () => setState(() => _rememberMe = !_rememberMe),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: widget.isLoading
                                ? null
                                : (v) => setState(() => _rememberMe = v ?? true),
                            activeColor: const Color(0xFFFFB800),
                            checkColor: const Color(0xFF1A1A1A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: SafeText(
                            'stay_signed_in'.tr(),
                            style: const TextStyle(
                              color: Color(0xFF57534E),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            enableAutoShrink: true,
                            minFontSize: 10.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: TextButton(
                  onPressed: widget.isLoading ? null : widget.onForgotPassword,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: SafeText(
                    'forgot_password'.tr(),
                    style: const TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    enableAutoShrink: true,
                    minFontSize: 10.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: WorkGoSpacing.lg),

          // Submit Button (Radiant Solar Amber Pill Button)
          Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFB800), Color(0xFFF59E0B)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.38),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isLoading ? null : _submit,
                borderRadius: BorderRadius.circular(24),
                child: Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SafeText(
                              'continue_btn'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                              enableAutoShrink: true,
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 19,
                              color: Color(0xFF1A1A1A),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: WorkGoSpacing.xl),

          // Switch to Sign Up
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: SafeText(
                  'no_account'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF78716C),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  enableAutoShrink: true,
                  minFontSize: 10.0,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: GestureDetector(
                  onTap: widget.isLoading ? null : widget.onSwitchToSignUp,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: SafeText(
                      'sign_up'.tr(),
                      style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFFD97706),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      enableAutoShrink: true,
                      minFontSize: 10.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (widget.onSwitchToPhone != null) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: widget.isLoading ? null : widget.onSwitchToPhone,
                icon: const Icon(Icons.phone_android_rounded, size: 16, color: Color(0xFF4B5563)),
                label: Flexible(
                  child: Text(
                    'auth_tab_phone'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
