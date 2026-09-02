import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'workgo_button.dart';

/// Shows an Obsidian Violet & Solar Yellow styled exit confirmation bottom sheet.
Future<bool?> showExitConfirmationSheet(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _ExitSheetContent(),
  );
}

class _ExitSheetContent extends StatelessWidget {
  const _ExitSheetContent();

  @override
  Widget build(BuildContext context) {
    final title = "exit_app_title".tr();
    final displayTitle = title == "exit_app_title" ? "Exit WorkGo?" : title;
    final subtitle = "exit_app_subtitle".tr();
    final displaySubtitle = subtitle == "exit_app_subtitle"
        ? "Are you sure you want to close the application? You can keep it open to stay connected with your live requests."
        : subtitle;
    final confirmText = "exit_app_confirm".tr();
    final displayConfirm = confirmText == "exit_app_confirm" ? "Exit App" : confirmText;
    final stayText = "exit_app_cancel".tr();
    final displayStay = stayText == "exit_app_cancel" ? "Stay in App" : stayText;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFF0EDE6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 28,
            offset: Offset(0, -4),
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
              color: const Color(0xFFE5E0D8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Glowing Icon Badge
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: WorkGoColors.solarGoldGradient,
              boxShadow: [
                BoxShadow(
                  color: WorkGoColors.accent.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.exit_to_app_rounded,
                color: Color(0xFF1E1035),
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
              fontWeight: FontWeight.w800,
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
              // Stay Button (Primary Amber)
              Expanded(
                child: WorkGoButton(
                  label: displayStay,
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () => Navigator.of(context).pop(false),
                  height: 48,
                ),
              ),
              const SizedBox(width: 12),

              // Exit Button (Outlined)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    SystemNavigator.pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WorkGoColors.textPrimary,
                    side: const BorderSide(
                      color: Color(0xFFE5E0D8),
                      width: 1.2,
                    ),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    displayConfirm,
                    style: WorkGoFonts.heading(
                      color: WorkGoColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
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
