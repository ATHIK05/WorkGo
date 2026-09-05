import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../theme/spacing.dart';
import '../safe_text.dart';
import 'auth_text_field.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({
    super.key,
    required this.onSignUp,
    this.onSignUpWithPhone,
    required this.onSwitchToSignIn,
    required this.isLoading,
  });

  final Future<void> Function(String name, String email, String password) onSignUp;
  final Future<void> Function(String name, String email, String password, String phone)? onSignUpWithPhone;
  final VoidCallback onSwitchToSignIn;
  final bool isLoading;

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'error_phone_empty'.tr();
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'error_phone_invalid'.tr();
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'error_name_empty'.tr();
    }
    return null;
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

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'error_password_empty'.tr();
    }
    if (value != _passwordController.text) {
      return 'error_passwords_mismatch'.tr();
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final phoneRaw = _phoneController.text.trim();
      final normalizedPhone = phoneRaw.startsWith('+91')
          ? phoneRaw
          : (phoneRaw.isNotEmpty ? '+91$phoneRaw' : '');
      if (widget.onSignUpWithPhone != null) {
        widget.onSignUpWithPhone!(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          normalizedPhone,
        );
      } else {
        widget.onSignUp(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
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
            'join_workgo'.tr(),
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
            'sign_up'.tr(),
            style: const TextStyle(
              color: Color(0xFF78716C),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: WorkGoSpacing.xl),

          // Name Field
          AuthTextField(
            controller: _nameController,
            labelText: 'full_name'.tr(),
            hintText: 'full_name_hint'.tr(),
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            autofillHints: const [AutofillHints.name],
            validator: _validateName,
            enabled: !widget.isLoading,
          ),
          const SizedBox(height: WorkGoSpacing.md),

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

          // Mobile Phone Number Field
          AuthTextField(
            controller: _phoneController,
            labelText: 'phone_number'.tr(),
            hintText: 'phone_number_hint'.tr(),
            prefixIcon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: _validatePhone,
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
            autofillHints: const [AutofillHints.newPassword],
            validator: _validatePassword,
            enabled: !widget.isLoading,
          ),
          const SizedBox(height: WorkGoSpacing.md),

          // Confirm Password Field
          AuthTextField(
            controller: _confirmPasswordController,
            labelText: 'confirm_password'.tr(),
            hintText: '••••••••',
            prefixIcon: Icons.lock_clock_outlined,
            isPassword: true,
            textInputAction: TextInputAction.done,
            validator: _validateConfirmPassword,
            onFieldSubmitted: (_) => _submit(),
            enabled: !widget.isLoading,
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

          // Switch to Sign In
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: SafeText(
                  'have_account'.tr(),
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
              GestureDetector(
                onTap: widget.isLoading ? null : widget.onSwitchToSignIn,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: SafeText(
                    'sign_in'.tr(),
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
            ],
          ),
        ],
      ),
    );
  }
}
