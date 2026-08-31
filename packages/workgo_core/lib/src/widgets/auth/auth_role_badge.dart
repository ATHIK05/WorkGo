import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
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
    final (icon, defaultKey, color) = switch (role) {
      UserRole.customer => (
        Icons.person_rounded,
        'customer_role',
        WorkGoColors.accent,
      ),
      UserRole.worker => (
        Icons.handyman_rounded,
        'worker_role',
        const Color(0xFF38BDF8), // Cyan/Sky blue for worker
      ),
      UserRole.admin => (
        Icons.admin_panel_settings_rounded,
        'admin_role',
        const Color(0xFF34D399), // Emerald for admin
      ),
    };

    final label = customLabel ?? defaultKey.tr();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: WorkGoSpacing.md,
        vertical: WorkGoSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(WorkGoSpacing.xl),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: WorkGoSpacing.xs + 2),
          SafeText(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
            enableAutoShrink: true,
          ),
        ],
      ),
    );
  }
}
