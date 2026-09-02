import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../safe_text.dart';

class AuthRoleBadge extends StatelessWidget {
  const AuthRoleBadge({
    super.key,
    required this.role,
    this.customLabel,
  });

  final UserRole role;
  final String? customLabel;

  @override
  Widget build(BuildContext context) {
    final (icon, defaultKey, color, bgColor) = switch (role) {
      UserRole.customer => (
        Icons.person_rounded,
        'customer_role',
        const Color(0xFF4F46E5),
        const Color(0xFFEEF2FF),
      ),
      UserRole.worker => (
        Icons.handyman_rounded,
        'worker_role',
        const Color(0xFF0284C7),
        const Color(0xFFF0F9FF),
      ),
      UserRole.admin => (
        Icons.admin_panel_settings_rounded,
        'admin_role',
        const Color(0xFF059669),
        const Color(0xFFECFDF5),
      ),
    };

    final label = customLabel ?? defaultKey.tr();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          SafeText(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
            enableAutoShrink: true,
          ),
        ],
      ),
    );
  }
}
