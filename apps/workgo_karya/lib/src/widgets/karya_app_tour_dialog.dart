import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../karya_theme.dart';

class KaryaTourStep {
  final String stepNumber;
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final LinearGradient gradient;
  final Color glowColor;
  final List<String> bulletPoints;

  const KaryaTourStep({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.bulletPoints,
  });
}

class KaryaAppTourDialog extends StatefulWidget {
  const KaryaAppTourDialog({super.key});

  static const String prefKey = "has_seen_karya_tour_v1";

  /// Displays the interactive app tour.
  /// If [isManual] is true, opens regardless of whether the user has seen it before.
  /// If false, checks SharedPreferences and only opens if not seen.
  static Future<void> checkAndShowTour(BuildContext context, {bool isManual = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(prefKey) ?? false;

    if (!isManual && hasSeen) return;

    if (context.mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: false,
        isDismissible: isManual,
        builder: (ctx) => const KaryaAppTourDialog(),
      );
      await prefs.setBool(prefKey, true);
    }
  }

  @override
  State<KaryaAppTourDialog> createState() => _KaryaAppTourDialogState();
}

class _KaryaAppTourDialogState extends State<KaryaAppTourDialog> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  List<KaryaTourStep> get _steps => [
    KaryaTourStep(
      stepNumber: "1",
      title: 'karya_tour_step1_title'.tr(),
      subtitle: 'karya_tour_step1_subtitle'.tr(),
      badgeText: 'karya_tour_step1_badge'.tr(),
      icon: Icons.radar_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: const Color(0xFF7C3AED),
      bulletPoints: [
        'karya_tour_step1_bp1'.tr(),
        'karya_tour_step1_bp2'.tr(),
        'karya_tour_step1_bp3'.tr(),
      ],
    ),
    KaryaTourStep(
      stepNumber: "2",
      title: 'karya_tour_step2_title'.tr(),
      subtitle: 'karya_tour_step2_subtitle'.tr(),
      badgeText: 'karya_tour_step2_badge'.tr(),
      icon: Icons.flash_on_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFFEA580C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: const Color(0xFFD97706),
      bulletPoints: [
        'karya_tour_step2_bp1'.tr(),
        'karya_tour_step2_bp2'.tr(),
        'karya_tour_step2_bp3'.tr(),
      ],
    ),
    KaryaTourStep(
      stepNumber: "3",
      title: 'karya_tour_step3_title'.tr(),
      subtitle: 'karya_tour_step3_subtitle'.tr(),
      badgeText: 'karya_tour_step3_badge'.tr(),
      icon: Icons.verified_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: const Color(0xFF0284C7),
      bulletPoints: [
        'karya_tour_step3_bp1'.tr(),
        'karya_tour_step3_bp2'.tr(),
        'karya_tour_step3_bp3'.tr(),
      ],
    ),
    KaryaTourStep(
      stepNumber: "4",
      title: 'karya_tour_step4_title'.tr(),
      subtitle: 'karya_tour_step4_subtitle'.tr(),
      badgeText: 'karya_tour_step4_badge'.tr(),
      icon: Icons.health_and_safety_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF047857)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: const Color(0xFF059669),
      bulletPoints: [
        'karya_tour_step4_bp1'.tr(),
        'karya_tour_step4_bp2'.tr(),
        'karya_tour_step4_bp3'.tr(),
      ],
    ),
    KaryaTourStep(
      stepNumber: "5",
      title: 'karya_tour_step5_title'.tr(),
      subtitle: 'karya_tour_step5_subtitle'.tr(),
      badgeText: 'karya_tour_step5_badge'.tr(),
      icon: Icons.account_balance_wallet_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFFE11D48), Color(0xFF9333EA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: const Color(0xFFE11D48),
      bulletPoints: [
        'karya_tour_step5_bp1'.tr(),
        'karya_tour_step5_bp2'.tr(),
        'karya_tour_step5_bp3'.tr(),
      ],
    ),
    KaryaTourStep(
      stepNumber: "6",
      title: 'karya_tour_step6_title'.tr(),
      subtitle: 'karya_tour_step6_subtitle'.tr(),
      badgeText: 'karya_tour_step6_badge'.tr(),
      icon: Icons.verified_user_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: const Color(0xFF8B5CF6),
      bulletPoints: [
        'karya_tour_step6_bp1'.tr(),
        'karya_tour_step6_bp2'.tr(),
        'karya_tour_step6_bp3'.tr(),
      ],
    ),
    KaryaTourStep(
      stepNumber: "7",
      title: 'karya_tour_step7_title'.tr(),
      subtitle: 'karya_tour_step7_subtitle'.tr(),
      badgeText: 'karya_tour_step7_badge'.tr(),
      icon: Icons.translate_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: const Color(0xFF2563EB),
      bulletPoints: [
        'karya_tour_step7_bp1'.tr(),
        'karya_tour_step7_bp2'.tr(),
        'karya_tour_step7_bp3'.tr(),
      ],
    ),
  ];

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentIndex < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishTour();
    }
  }

  void _previousPage() {
    HapticFeedback.lightImpact();
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _finishTour() {
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _currentIndex == _steps.length - 1;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: KX.glassBorder, width: 1.2)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle Bar
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: KX.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Step Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: KX.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: KX.gold.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      "feature_guide_step_arg".tr(args: [(_currentIndex + 1).toString(), _steps.length.toString()]),
                      style: const TextStyle(
                        color: KX.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // Skip Button
                  GestureDetector(
                    onTap: _finishTour,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: KX.canvasElevated,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "skip_tour_btn".tr(),
                        style: const TextStyle(
                          color: KX.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // PageView Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return _buildStepCard(step);
                },
              ),
            ),

            // Bottom Navigation & Indicators
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                children: [
                  // Dot Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (idx) {
                      final isActive = idx == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutQuad,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 24 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isActive ? KX.gold : KX.dividerLight,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: KX.gold.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Buttons Row
                  Row(
                    children: [
                      if (_currentIndex > 0) ...[
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: _previousPage,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: KX.textPrimary,
                              side: BorderSide(color: KX.glassBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text("previous_btn".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLastStep ? const Color(0xFF10B981) : KX.gold,
                            foregroundColor: const Color(0xFF1E1035),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 4,
                            shadowColor: (isLastStep ? const Color(0xFF10B981) : KX.gold).withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLastStep ? "get_started_rocket_btn".tr() : "next_feature_btn".tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                isLastStep ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(KaryaTourStep step) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Illustration Banner
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: step.gradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: step.glowColor.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(
                    step.icon,
                    size: 160,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          step.badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(step.icon, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              step.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            step.subtitle,
            style: const TextStyle(
              color: KX.textPrimary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Bullet Points Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F6EE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KX.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: step.bulletPoints.map((point) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: KX.gold,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          point,
                          style: const TextStyle(
                            color: KX.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
