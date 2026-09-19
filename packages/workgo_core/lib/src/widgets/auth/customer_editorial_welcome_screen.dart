import "dart:math" as math;
import "package:easy_localization/easy_localization.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:google_fonts/google_fonts.dart";
import "../../models/app_user.dart";
import "../../localization/locale_config.dart";
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "hero_lets_make".tr(),
                          style: _headlineSansStyle(context, isCompact: isCompact),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.role == UserRole.worker
                              ? "hero_your_craft".tr()
                              : "hero_your_home".tr(),
                          style: _headlineSerifStyle(context, isCompact: isCompact),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "hero_effortless".tr(),
                          style: _headlineSansStyle(context, isCompact: isCompact),
                          textAlign: TextAlign.center,
                        ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

  // ── LOCALIZED TYPOGRAPHY SYSTEM (Uniform Font Sizes Across All Languages) ──

  TextStyle _getSansFont(
    String lang, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
    double? height,
  }) {
    switch (lang) {
      case "hi":
      case "mr":
      case "ne":
      case "sa":
      case "mai":
      case "kok":
      case "doi":
      case "brx":
        return GoogleFonts.mukta(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing ?? -0.2,
          height: height ?? 1.12,
        );
      case "ta":
        return GoogleFonts.catamaran(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing ?? -0.2,
          height: height ?? 1.15,
        );
      case "te":
        return GoogleFonts.notoSansTelugu(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
        );
      case "kn":
        return GoogleFonts.notoSansKannada(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
        );
      case "ml":
        return GoogleFonts.notoSansMalayalam(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
        );
      case "bn":
      case "as":
      case "mni":
        return GoogleFonts.notoSansBengali(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
        );
      case "gu":
        return GoogleFonts.notoSansGujarati(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
        );
      case "pa":
        return GoogleFonts.notoSansGurmukhi(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
        );
      case "or":
        return GoogleFonts.notoSansOriya(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
        );
      case "ur":
      case "ks":
      case "sd":
        return GoogleFonts.notoSansArabic(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
        );
      default:
        return GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
        );
    }
  }

  TextStyle _getSerifFont(
    String lang, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
  }) {
    switch (lang) {
      case "hi":
      case "mr":
      case "ne":
      case "sa":
      case "mai":
      case "kok":
      case "doi":
      case "brx":
        return GoogleFonts.notoSerifDevanagari(
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing ?? 0.0,
          height: height ?? 1.08,
        );
      case "ta":
        return GoogleFonts.notoSerifTamil(
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing ?? 0.0,
          height: height ?? 1.12,
        );
      case "te":
        return GoogleFonts.notoSerifTelugu(
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing ?? 0.0,
          height: height,
        );
      case "kn":
        return GoogleFonts.notoSerifKannada(
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing ?? 0.0,
          height: height,
        );
      case "ml":
        return GoogleFonts.notoSerifMalayalam(
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing ?? 0.0,
          height: height,
        );
      case "bn":
      case "as":
      case "mni":
        return GoogleFonts.notoSerifBengali(
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing ?? 0.0,
          height: height,
        );
      case "gu":
        return GoogleFonts.notoSerifGujarati(
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing ?? 0.0,
          height: height,
        );
      case "pa":
        return GoogleFonts.notoSerifGurmukhi(
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing ?? 0.0,
          height: height,
        );
      case "or":
        return GoogleFonts.notoSerifOriya(
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing ?? 0.0,
          height: height,
        );
      case "ur":
      case "ks":
      case "sd":
        return GoogleFonts.notoNaskhArabic(
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing ?? 0.0,
          height: height,
        );
      default:
        return GoogleFonts.playfairDisplay(
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
        );
    }
  }

  TextStyle _headlineSansStyle(BuildContext context,
      {required bool isCompact}) {
    final lang = context.locale.languageCode;
    const color = Color(0xFF141416);
    // Uniform font size across all languages
    final fontSize = isCompact ? 38.0 : 46.0;
    return _getSansFont(
      lang,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: lang == "en" ? -1.4 : -0.2,
      height: 1.05,
    );
  }

  TextStyle _headlineSerifStyle(BuildContext context,
      {required bool isCompact}) {
    final lang = context.locale.languageCode;
    const color = Color(0xFF141416);
    // Uniform font size across all languages
    final fontSize = isCompact ? 44.0 : 52.0;
    return _getSerifFont(
      lang,
      fontSize: fontSize,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: lang == "en" ? -0.6 : 0.0,
      height: 0.98,
    );
  }

  TextStyle _subtitleStyle(BuildContext context, {required bool isCompact}) {
    final lang = context.locale.languageCode;
    const color = Color(0xFF262626);
    final fontSize = isCompact ? 13.5 : 15.0;
    return _getSansFont(
      lang,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.25,
      letterSpacing: -0.1,
    );
  }

  TextStyle _pillTextStyle(BuildContext context, {required Color textColor}) {
    final lang = context.locale.languageCode;
    const fontSize = 14.0;
    return _getSerifFont(
      lang,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: textColor,
      height: 1.18,
    );
  }

  TextStyle _buttonTextStyle(BuildContext context) {
    final lang = context.locale.languageCode;
    const fontSize = 16.0;
    return _getSansFont(
      lang,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: -0.2,
    );
  }

  TextStyle _secondaryButtonTextStyle(BuildContext context) {
    final lang = context.locale.languageCode;
    const color = Color(0xFF141416);
    const fontSize = 14.0;
    return _getSansFont(
      lang,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 0.0,
    );
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
    final activeIndex = WorkGoLocale.allLanguages
        .indexWhere((l) => l.code == current)
        .clamp(0, WorkGoLocale.allLanguages.length - 1);

    return SizedBox(
      height: 36,
      child: _WelcomeScrollToActiveLangStrip(
        activeIndex: activeIndex,
        children: WorkGoLocale.allLanguages.map((lang) {
          final isActive = lang.code == current;
          return _langChip(
            context,
            code: lang.code,
            label: lang.nativeName,
            active: isActive,
          );
        }).toList(),
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
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF141416) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? const Color(0xFF141416) : const Color(0xFFE5E7EB),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          // Prevent system accessibility scaling from making some scripts
          // appear larger than others in the pill strip.
          textScaler: TextScaler.noScaling,
          // forceStrutHeight clamps every script to the same line-box height
          strutStyle: const StrutStyle(
            fontSize: 11,
            height: 1.0,
            forceStrutHeight: true,
          ),
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF4B5563),
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// Horizontal scrollable strip that auto-scrolls to the active language pill
class _WelcomeScrollToActiveLangStrip extends StatefulWidget {
  const _WelcomeScrollToActiveLangStrip({
    required this.activeIndex,
    required this.children,
  });

  final int activeIndex;
  final List<Widget> children;

  @override
  State<_WelcomeScrollToActiveLangStrip> createState() =>
      _WelcomeScrollToActiveLangStripState();
}

class _WelcomeScrollToActiveLangStripState
    extends State<_WelcomeScrollToActiveLangStrip> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  @override
  void didUpdateWidget(covariant _WelcomeScrollToActiveLangStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _scrollToActive() {
    if (!_controller.hasClients) return;
    const itemEstimate = 75.0;
    final target = (widget.activeIndex * itemEstimate) -
        (_controller.position.viewportDimension / 2) +
        (itemEstimate / 2);
    final clamped = target.clamp(0.0, _controller.position.maxScrollExtent);
    _controller.animateTo(
      clamped,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.children,
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
