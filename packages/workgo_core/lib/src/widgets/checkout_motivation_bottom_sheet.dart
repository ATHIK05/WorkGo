import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/worker.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'workgo_button.dart';

/// Shows a motivational, high-energy bottom sheet when an artisan attempts to check out,
/// inspiring them to stay active, complete more jobs, and maximize their cooperative earnings.
Future<bool?> showCheckOutMotivationSheet(BuildContext context, {Worker? worker}) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _CheckOutMotivationSheetContent(worker: worker),
  );
}

class _CheckOutMotivationSheetContent extends StatelessWidget {
  const _CheckOutMotivationSheetContent({this.worker});

  final Worker? worker;

  @override
  Widget build(BuildContext context) {
    final primaryTrade = (worker?.skills.isNotEmpty ?? false)
        ? worker!.skills.first
        : "Local Service";

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0B24),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: WorkGoColors.accent.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: WorkGoColors.accent.withValues(alpha: 0.25),
            blurRadius: 36,
            spreadRadius: -4,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: WorkGoColors.primary.withValues(alpha: 0.4),
            blurRadius: 40,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Glowing Motivational Rocket / Solar Badge
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: WorkGoColors.solarGoldGradient,
                boxShadow: [
                  BoxShadow(
                    color: WorkGoColors.accent.withValues(alpha: 0.5),
                    blurRadius: 24,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.rocket_launch_rounded,
                  color: Color(0xFF1E1035),
                  size: 34,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // High Energy Headline
          Text(
            "Stay Online, Earn More! 🚀",
            style: WorkGoFonts.display(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            "Peak hours are live! Customers nearby are actively booking $primaryTrade experts right now.",
            style: WorkGoFonts.body(
              color: WorkGoColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // ── Incentive Card 1: Extra Earnings Surge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF231548), Color(0xFF160E33)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: WorkGoColors.accent.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: WorkGoColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: WorkGoColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Boost Today's Income",
                        style: WorkGoFonts.heading(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Artisans active for 1 more hour earn an average ₹450 – ₹800 extra today.",
                        style: WorkGoFonts.body(
                          color: WorkGoColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Incentive Card 2: Cooperative Dividend & Titan Milestone
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E143B), Color(0xFF120C28)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: WorkGoColors.primaryLight.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: WorkGoColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    color: WorkGoColors.violetNeon,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cooperative Welfare Dividend",
                        style: WorkGoFonts.heading(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Every completed job credits your 2% healthcare & emergency welfare safety net.",
                        style: WorkGoFonts.body(
                          color: WorkGoColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── Primary Action: KEEP WORKING & EARN MORE
          WorkGoButton(
            label: "Keep Working & Earn More",
            icon: Icons.flash_on_rounded,
            variant: WorkGoButtonVariant.primary,
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.of(context).pop(false); // false = stay online
            },
            height: 52,
          ),
          const SizedBox(height: 10),

          // ── Secondary Action: CHECK OUT ANYWAY
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(true); // true = confirm checkout
            },
            icon: const Icon(
              Icons.power_settings_new_rounded,
              color: Color(0xFFE11D48),
              size: 16,
            ),
            label: Text(
              "Check Out for Today",
              style: WorkGoFonts.heading(
                color: const Color(0xFFFDA4AF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
