import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'workgo_button.dart';

/// Shows an Obsidian Violet styled sign out confirmation bottom sheet.
Future<bool?> showSignOutConfirmationSheet(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _SignOutSheetContent(),
  );
}

class _SignOutSheetContent extends StatelessWidget {
  const _SignOutSheetContent();

  @override
  Widget build(BuildContext context) {
    final title = "sign_out_title".tr();
    final displayTitle = title == "sign_out_title" ? "Sign Out of WorkGo?" : title;
    final subtitle = "sign_out_subtitle".tr();
    final displaySubtitle = subtitle == "sign_out_subtitle"
        ? "You will be signed out of this device. Incoming job alerts and active dispatches will be paused until you sign back in."
        : subtitle;
    final cancelText = "cancel".tr();
    final displayCancel = cancelText == "cancel" ? "Cancel" : cancelText;
    final signOutText = "sign_out".tr();
    final displaySignOut = signOutText == "sign_out" ? "Sign Out" : signOutText;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0B24),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: WorkGoColors.error.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: WorkGoColors.error.withValues(alpha: 0.3),
            blurRadius: 32,
            spreadRadius: -4,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle pill
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Glowing Logout Icon Badge
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF881337), Color(0xFFF43F5E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: WorkGoColors.error.withValues(alpha: 0.45),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.logout_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            displayTitle,
            style: WorkGoFonts.display(
              color: WorkGoColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            displaySubtitle,
            style: WorkGoFonts.body(
              color: WorkGoColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              // Cancel Button
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    displayCancel,
                    style: WorkGoFonts.heading(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Confirm Sign Out Button
              Expanded(
                child: WorkGoButton(
                  label: displaySignOut,
                  icon: Icons.logout_rounded,
                  variant: WorkGoButtonVariant.danger,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
