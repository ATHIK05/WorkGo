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

  final List<KaryaTourStep> _steps = const [
    KaryaTourStep(
      stepNumber: "1",
      title: "Instant Check-In & Availability Switch",
      subtitle: "Take full control of your working hours. Go live on customer radars across your coverage zone with a single tap.",
      badgeText: "AUTONOMOUS SHIFTS",
      icon: Icons.radar_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: Color(0xFF7C3AED),
      bulletPoints: [
        "1-Tap Check-In button to start receiving incoming booking dispatches",
        "Motivational fuel targets with progress insights",
        "Set custom daily operating hours and service radius (1 to 30 km)",
      ],
    ),
    KaryaTourStep(
      stepNumber: "2",
      title: "Real-Time Job Radar & Incoming Dispatches",
      subtitle: "Nearby service requests flash directly onto your screen with upfront pricing, location distance, and audio alerts.",
      badgeText: "PRIORITY DISPATCH",
      icon: Icons.flash_on_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFFEA580C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: Color(0xFFD97706),
      bulletPoints: [
        "30-second priority countdown to accept bookings before others",
        "Transparent dynamic rate breakdown showing your exact payout",
        "Real-time customer distance and job requirements preview",
      ],
    ),
    KaryaTourStep(
      stepNumber: "3",
      title: "Active Job Tracking & Start OTP Security",
      subtitle: "Navigate safely, connect via in-app calling, start work with a secure customer OTP, and log C2PA proof of completion.",
      badgeText: "ZERO DISPUTE",
      icon: Icons.verified_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: Color(0xFF0284C7),
      bulletPoints: [
        "Google Maps turn-by-turn navigation directly to customer doorstep",
        "4-digit Start Job OTP eliminates false starts and customer confusion",
        "Tamper-proof C2PA photo upload for authentic proof of work",
      ],
    ),
    KaryaTourStep(
      stepNumber: "4",
      title: "₹2 Lakh Welfare Shield & PMJJBY Insurance",
      subtitle: "Every active cooperative artisan is covered by emergency medical protection, death benefits, and accident insurance.",
      badgeText: "100% COVERED",
      icon: Icons.health_and_safety_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF047857)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: Color(0xFF059669),
      bulletPoints: [
        "₹2,00,000 accidental & disability coverage powered by PMJJBY",
        "Instant emergency SOS beacon during active jobs",
        "Cooperative welfare board death grant and family security",
      ],
    ),
    KaryaTourStep(
      stepNumber: "5",
      title: "Daily Fuel Gauge & Direct UPI Payouts",
      subtitle: "Track your earnings in real time with 0% platform commission deductions. Direct settlement to your bank account.",
      badgeText: "0% COMMISSION",
      icon: Icons.account_balance_wallet_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFFE11D48), Color(0xFF9333EA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: Color(0xFFE11D48),
      bulletPoints: [
        "Keep 100% of your labor wages, tips, and distance compensation",
        "Live Fuel Gauge tracking daily goals and peak-hour bonuses",
        "1-Tap instant payout transfer to any registered UPI ID or Bank",
      ],
    ),
    KaryaTourStep(
      stepNumber: "6",
      title: "Government Aadhaar & Live Video KYC Badging",
      subtitle: "Verify your identity with genuine Aadhaar e-KYC, live front-camera selfie, and a quick WebRTC video call with staff.",
      badgeText: "CO-OP CERTIFIED",
      icon: Icons.verified_user_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: Color(0xFF8B5CF6),
      bulletPoints: [
        "Cryptographic SHA-256 and AI anti-spoofing protection",
        "Live Video KYC waiting room with dynamic challenge phrase",
        "Verified artisans get the Co-op Certified Badge and 3x more bookings",
      ],
    ),
    KaryaTourStep(
      stepNumber: "7",
      title: "Multilingual & Vernacular Audio Assistance",
      subtitle: "Work comfortably in your native language with high-contrast text, Tamil, Hindi, or English translations.",
      badgeText: "VERNACULAR READY",
      icon: Icons.translate_rounded,
      gradient: LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: Color(0xFF2563EB),
      bulletPoints: [
        "Switch anytime between தமிழ் (Tamil), हिंदी (Hindi), and English",
        "High-contrast large-button accessibility designed for low literacy",
        "Voice audio prompts during incoming job dispatches",
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
      decoration: const BoxDecoration(
        color: Color(0xFF0F0B1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white24, width: 1.2)),
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
                color: Colors.white30,
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
                      "FEATURE GUIDE · STEP ${_currentIndex + 1} OF ${_steps.length}",
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
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "Skip Tour",
                        style: TextStyle(
                          color: Colors.white70,
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
                          color: isActive ? KX.gold : Colors.white24,
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
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text("Previous", style: TextStyle(fontWeight: FontWeight.bold)),
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
                                isLastStep ? "Get Started 🚀" : "Next Feature",
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
              color: Colors.white,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Bullet Points Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1536),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
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
                            color: Colors.white70,
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
