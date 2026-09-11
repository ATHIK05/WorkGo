import "dart:math" as math;
import "package:easy_localization/easy_localization.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:google_fonts/google_fonts.dart";
import "../../models/app_user.dart";
import "customer_auth_sheet.dart";

/// State-of-the-art Editorial Consumer Onboarding & Welcome Screen.
/// Inspired by modern high-fashion and health apps:
/// - Editorial serif/sans typography pairing
/// - Floating staggered dashed capsules and pastel pill badges
/// - Bold tactile "Get Started" and "I Already Have an Account" controls
class CustomerEditorialWelcomeScreen extends StatefulWidget {
  const CustomerEditorialWelcomeScreen({
    super.key,
    required this.onSuccess,
    this.role = UserRole.customer,
  });

  final void Function(AppUser user) onSuccess;
  final UserRole role;

  @override
  State<CustomerEditorialWelcomeScreen> createState() =>
      _CustomerEditorialWelcomeScreenState();
}

class _CustomerEditorialWelcomeScreenState
    extends State<CustomerEditorialWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _driftController;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _driftController.dispose();
    super.dispose();
  }
  void _openAuthSheet({
    CustomerAuthTab initialTab = CustomerAuthTab.google,
    bool isSignUp = false,
  }) {
    HapticFeedback.lightImpact();
    showCustomerAuthSheet(
      context,
      onSuccess: widget.onSuccess,
      role: widget.role,
      initialTab: initialTab,
      isSignUp: isSignUp,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        bottom: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final isCompact = availableHeight < 680;

            return Column(
              children: [
                SizedBox(height: isCompact ? 36 : 96),

                // ── 1. HERO TYPOGRAPHY LOCKUP (Positioned down for luxury editorial balance) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(
                        "hero_lets_make".tr(),
                        style: _headlineSansStyle(context, isCompact: isCompact),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        widget.role == UserRole.worker
                            ? "hero_your_craft".tr()
                            : "hero_your_home".tr(),
                        style: _headlineSerifStyle(context, isCompact: isCompact),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        "hero_effortless".tr(),
                        style: _headlineSansStyle(context, isCompact: isCompact),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isCompact ? 10 : 16),
                      Text(
                        widget.role == UserRole.worker
                            ? "hero_worker_tagline".tr()
                            : "hero_tagline".tr(),
                        style: _subtitleStyle(context, isCompact: isCompact),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // ── 2. THE CENTERPIECE: FLOATING CAPSULE MATRIX (Smooth Drifting Motion) ──
                AnimatedBuilder(
                  animation: _driftController,
                  builder: (context, child) {
                    final driftVal = CurvedAnimation(
                      parent: _driftController,
                      curve: Curves.easeInOutSine,
                    ).value;
                    final offset1 = (driftVal - 0.5) * 22.0;
                    final offset2 = (0.5 - driftVal) * 16.0;
                    final offset3 = (driftVal - 0.5) * 20.0;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ROW 1: Symmetrically centered, side pills bleed off both screen edges
                        ClipRect(
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: 50,
                            child: OverflowBox(
                              alignment: Alignment.center,
                              minWidth: 0,
                              maxWidth: 1200,
                              minHeight: 0,
                              maxHeight: 54,
                              child: Transform.translate(
                                offset: Offset(offset1, 0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildDashedPill(
                                      label: "pill_appliances".tr(),
                                      bgColor: const Color(0xFFFEF08A),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildCircleCraftIcon(
                                      icon: Icons.eco_rounded,
                                      iconColor: const Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildDashedPill(
                                      label: "pill_track_mindfully".tr(),
                                      bgColor: Colors.white,
                                    ),
                                    const SizedBox(width: 10),
                                    _buildDashedPill(
                                      label: "pill_fix_leaks".tr(),
                                      bgColor: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ROW 2: CIRCULAR BADGE LOCKED AT DEAD HORIZONTAL CENTER (screenWidth / 2)
                        ClipRect(
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: 50,
                            child: Transform.translate(
                              offset: Offset(offset2, 0),
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  // Center Badge: Guaranteed at screenWidth / 2
                                  Center(
                                    child: _buildCircleCraftIcon(
                                      icon: Icons.bolt_rounded,
                                      iconColor: const Color(0xFF15803D),
                                    ),
                                  ),
                                  // Left Pill: Anchored 10px to the left of the center badge
                                  Positioned(
                                    right: (constraints.maxWidth / 2) + 22 + 10,
                                    child: _buildDashedPill(
                                      label: "pill_build_habits".tr(),
                                      bgColor: Colors.white,
                                    ),
                                  ),
                                  // Right Pill: Anchored 10px to the right of the center badge (pastel yellow)
                                  Positioned(
                                    left: (constraints.maxWidth / 2) + 22 + 10,
                                    child: _buildDashedPill(
                                      label: "pill_support_pros".tr(),
                                      bgColor: const Color(0xFFFEF08A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ROW 3: Symmetrically centered, side pills bleed off both screen edges
                        ClipRect(
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: 50,
                            child: OverflowBox(
                              alignment: Alignment.center,
                              minWidth: 0,
                              maxWidth: 1200,
                              minHeight: 0,
                              maxHeight: 54,
                              child: Transform.translate(
                                offset: Offset(offset3, 0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildDashedPill(
                                      label: "pill_electrical".tr(),
                                      bgColor: const Color(0xFFFEF08A),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildCircleCraftIcon(
                                      icon: Icons.handyman_rounded,
                                      iconColor: const Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildDashedPill(
                                      label: "pill_increase_earnings".tr(),
                                      bgColor: Colors.white,
                                    ),
                                    const SizedBox(width: 10),
                                    _buildDashedPill(
                                      label: "pill_transparent_pricing".tr(),
                                      bgColor: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const Spacer(flex: 1),

                // ── 3. BOTTOM ACTION STACK & LANGUAGE TOGGLE (No Overlap) ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Primary Solid Black Pill Button: Get Started
                      SizedBox(
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () => _openAuthSheet(
                              initialTab: CustomerAuthTab.google,
                              isSignUp: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF141416),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(29),
                            ),
                          ),
                          child: Text(
                            "btn_get_started".tr(),
                            style: _buttonTextStyle(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Secondary Text Button: I Already Have an Account
                      Center(
                        child: GestureDetector(
                          onTap: () => _openAuthSheet(
                              initialTab: CustomerAuthTab.phone,
                              isSignUp: false),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 12),
                            child: Text(
                              "btn_already_have_account".tr(),
                              style: _secondaryButtonTextStyle(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Discreet, Centered Language Switcher at Bottom
                      Center(
                        child: _buildLanguageSwitcher(context),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── EXACT TEMPLATE CAPSULE WIDGETS ──

  Widget _buildDashedPill({
    required String label,
    Color bgColor = Colors.white,
    Color textColor = const Color(0xFF141416),
  }) {
    return CustomPaint(
      painter: DashedBorderPainter(
        color: const Color(0xFF374151),
        strokeWidth: 1.15,
        dashLength: 4.2,
        dashGap: 2.8,
        borderRadius: 24,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: _pillTextStyle(context, textColor: textColor),
        ),
      ),
    );
  }

  // ── LOCALIZED TYPOGRAPHY SYSTEM (Same Font Style in EN, HI, TA) ──

  TextStyle _headlineSansStyle(BuildContext context,
      {required bool isCompact}) {
    final lang = context.locale.languageCode;
    const color = Color(0xFF141416);
    if (lang == "hi") {
      return GoogleFonts.mukta(
        fontSize: isCompact ? 34 : 42,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.2,
        height: 1.12,
      );
    } else if (lang == "ta") {
      return GoogleFonts.catamaran(
        fontSize: isCompact ? 32 : 39,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.2,
        height: 1.15,
      );
    } else {
      return GoogleFonts.plusJakartaSans(
        fontSize: isCompact ? 40 : 48,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -1.6,
        height: 1.02,
      );
    }
  }

  TextStyle _headlineSerifStyle(BuildContext context,
      {required bool isCompact}) {
    final lang = context.locale.languageCode;
    const color = Color(0xFF141416);
    if (lang == "hi") {
      return GoogleFonts.notoSerifDevanagari(
        fontSize: isCompact ? 40 : 50,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.0,
        height: 1.08,
      );
    } else if (lang == "ta") {
      return GoogleFonts.notoSerifTamil(
        fontSize: isCompact ? 38 : 46,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.0,
        height: 1.12,
      );
    } else {
      return GoogleFonts.playfairDisplay(
        fontSize: isCompact ? 48 : 58,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.6,
        height: 0.96,
      );
    }
  }

  TextStyle _subtitleStyle(BuildContext context, {required bool isCompact}) {
    final lang = context.locale.languageCode;
    const color = Color(0xFF262626);
    if (lang == "hi") {
      return GoogleFonts.mukta(
        fontSize: isCompact ? 13.5 : 15,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.25,
      );
    } else if (lang == "ta") {
      return GoogleFonts.catamaran(
        fontSize: isCompact ? 13.5 : 15,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.25,
      );
    } else {
      return GoogleFonts.plusJakartaSans(
        fontSize: isCompact ? 13.5 : 15,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.1,
      );
    }
  }

  TextStyle _pillTextStyle(BuildContext context, {required Color textColor}) {
    final lang = context.locale.languageCode;
    if (lang == "hi") {
      return GoogleFonts.notoSerifDevanagari(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.18,
      );
    } else if (lang == "ta") {
      return GoogleFonts.notoSerifTamil(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.18,
      );
    } else {
      return GoogleFonts.newsreader(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: textColor,
      );
    }
  }

  TextStyle _buttonTextStyle(BuildContext context) {
    final lang = context.locale.languageCode;
    if (lang == "hi") {
      return GoogleFonts.mukta(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
      );
    } else if (lang == "ta") {
      return GoogleFonts.catamaran(
        fontSize: 16.0,
        fontWeight: FontWeight.w700,
      );
    } else {
      return GoogleFonts.plusJakartaSans(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      );
    }
  }

  TextStyle _secondaryButtonTextStyle(BuildContext context) {
    final lang = context.locale.languageCode;
    const color = Color(0xFF141416);
    if (lang == "hi") {
      return GoogleFonts.mukta(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: color,
      );
    } else if (lang == "ta") {
      return GoogleFonts.catamaran(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        color: color,
      );
    } else {
      return GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: color,
      );
    }
  }

  Widget _buildCircleCraftIcon({
    required IconData icon,
    Color iconColor = const Color(0xFF15803D),
    Color bgColor = Colors.white,
  }) {
    return CustomPaint(
      painter: DashedBorderPainter(
        color: const Color(0xFF374151),
        strokeWidth: 1.15,
        dashLength: 3.8,
        dashGap: 2.8,
        borderRadius: 22,
      ),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, color: iconColor, size: 21),
        ),
      ),
    );
  }

  Widget _buildLanguageSwitcher(BuildContext context) {
    final current = context.locale.languageCode;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langChip(context, code: "en", label: "EN", active: current == "en"),
          _langChip(context, code: "hi", label: "HI", active: current == "hi"),
          _langChip(context, code: "ta", label: "TA", active: current == "ta"),
        ],
      ),
    );
  }

  Widget _langChip(
    BuildContext context, {
    required String code,
    required String label,
    required bool active,
  }) {
    return GestureDetector(
      onTap: () {
        if (!active) {
          context.setLocale(Locale(code));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF141416) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

/// Custom Painter for authentic dashed borders on rounded rectangles
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashLength = 4.0,
    this.dashGap = 3.0,
    this.borderRadius = 16.0,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final nextDistance = math.min(distance + dashLength, metric.length);
        final extractPath = metric.extractPath(distance, nextDistance);
        canvas.drawPath(extractPath, paint);
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.dashGap != dashGap ||
        oldDelegate.borderRadius != borderRadius;
  }
}
