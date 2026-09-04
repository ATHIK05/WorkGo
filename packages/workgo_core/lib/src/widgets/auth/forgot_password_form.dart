import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../theme/spacing.dart';
import '../safe_text.dart';
import 'auth_text_field.dart';

class ForgotPasswordForm extends StatefulWidget {
  const ForgotPasswordForm({
    super.key,
    required this.onResetPassword,
    required this.onBackToSignIn,
    required this.isLoading,
  });

  final Future<void> Function(String email) onResetPassword;
  final VoidCallback onBackToSignIn;
  final bool isLoading;

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
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

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onResetPassword(_emailController.text.trim());
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
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFD97706)),
              onPressed: widget.isLoading ? null : widget.onBackToSignIn,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(height: WorkGoSpacing.sm),

          // Header
          SafeText(
            'forgot_password'.tr(),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SafeText(
            'reset_password'.tr(),
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
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: _validateEmail,
            onFieldSubmitted: (_) => _submit(),
            enabled: !widget.isLoading,
          ),
          const SizedBox(height: WorkGoSpacing.xl),

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
                      : SafeText(
                          'reset_password'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                          enableAutoShrink: true,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: WorkGoSpacing.lg),

          // Back to Sign In Text
          Center(
            child: TextButton(
              onPressed: widget.isLoading ? null : widget.onBackToSignIn,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  SafeText(
                    'sign_in'.tr(),
                    style: const TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
