import "dart:math";
import "package:easy_localization/easy_localization.dart";
import "package:flutter/material.dart";
import "../../models/worker.dart";
import "../../theme/colors.dart";

/// High-fidelity 5-signal trust verification card.
///
/// Features:
/// - State-of-the-art 5-segment radial precision dial (illuminates per verified signal).
/// - Clean SLA tier pill badge with color-coded live qualification status.
/// - Sleek 5-signal micro-status rows with direct tap action for optional items.
/// - Informative status summary banner guiding artisan on next steps.
class TrustStatusCard extends StatelessWidget {
  const TrustStatusCard({
    super.key,
    required this.trustScore,
    required this.signals,
    this.workerName,
    this.onAddEshram,
    this.onAddPcc,
  });

  final int trustScore;
  final TrustSignals signals;
  final String? workerName;
  final VoidCallback? onAddEshram;
  final VoidCallback? onAddPcc;

  Color _tierColor(int score) {
    if (score >= 5) return const Color(0xFF10B981); // Emerald
    if (score == 4) return const Color(0xFF2563EB); // Royal Blue
    if (score == 3) return const Color(0xFFF59E0B); // Amber Gold
    return const Color(0xFFEF4444); // Coral Red
  }

  _StatusData _statusData(int score) {
    if (score >= 5) {
      return _StatusData(
        label: "trust_score_live".tr(),
        badgeColor: const Color(0xFF10B981),
        subMessage: "trust_score_live_sub".tr(),
        tierPill: "trust_tier_live".tr(),
      );
    } else if (score == 4) {
      return _StatusData(
        label: "trust_score_almost".tr(),
        badgeColor: const Color(0xFF2563EB),
        subMessage: "trust_score_almost_sub".tr(),
        tierPill: "trust_tier_fast_track".tr(),
      );
    } else if (score == 3) {
      return _StatusData(
        label: "trust_score_pending".tr(),
        badgeColor: const Color(0xFFF59E0B),
        subMessage: "trust_score_pending_sub".tr(),
        tierPill: "trust_tier_standard".tr(),
      );
    } else {
      return _StatusData(
        label: "trust_score_action_needed".tr(),
        badgeColor: const Color(0xFFEF4444),
        subMessage: "trust_score_action_sub".tr(),
        tierPill: "trust_tier_action_needed".tr(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusData(trustScore);
    final themeColor = _tierColor(trustScore);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEFECE6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: themeColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          trustScore >= 5 ? Icons.verified_user_rounded : Icons.shield_rounded,
                          color: themeColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "trust_index_title".tr(),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF141416),
                                letterSpacing: -0.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              status.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: themeColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: themeColor.withAlpha(22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor.withAlpha(60), width: 1),
                  ),
                  child: Text(
                    status.tierPill,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: themeColor,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F0EA)),

          // ── Middle Section: Segmented Dial + Signal Rows ───────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Improvised 5-Segment Precision Trust Dial
                _SegmentedTrustRing(
                  score: trustScore,
                  color: themeColor,
                ),
                const SizedBox(width: 18),

                // 5-Signal Checklist Rows
                Expanded(
                  child: Column(
                    children: [
                      _SignalRow(
                        label: "signal_phone".tr(),
                        done: signals.phone,
                        icon: Icons.phone_android_rounded,
                      ),
                      _SignalRow(
                        label: "signal_aadhaar".tr(),
                        done: signals.aadhaar,
                        icon: Icons.fingerprint_rounded,
                      ),
                      _SignalRow(
                        label: "signal_liveness".tr(),
                        done: signals.liveness,
                        pending: signals.aadhaar && !signals.liveness,
                        icon: Icons.face_retouching_natural_rounded,
                      ),
                      _SignalRow(
                        label: "signal_eshram".tr(),
                        done: signals.eshram,
                        recommended: true,
                        icon: Icons.badge_rounded,
                        onTap: (!signals.eshram && onAddEshram != null) ? onAddEshram : null,
                      ),
                      _SignalRow(
                        label: "signal_pcc".tr(),
                        done: signals.pcc,
                        recommended: true,
                        icon: Icons.local_police_rounded,
                        onTap: (!signals.pcc && onAddPcc != null) ? onAddPcc : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Summary Banner ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8F5),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
              border: const Border(
                top: BorderSide(color: Color(0xFFF0EDE6), width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: themeColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.subMessage,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF52525B),
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusData {
  final String label;
  final Color badgeColor;
  final String subMessage;
  final String tierPill;

  const _StatusData({
    required this.label,
    required this.badgeColor,
    required this.subMessage,
    required this.tierPill,
  });
}

/// Improvised 5-Segment Radial Precision Dial.
///
/// Illuminates 5 separate curved pill segments corresponding to each trust signal,
/// with a centered status disc, micro-subtitles, and animated sweep.
class _SegmentedTrustRing extends StatelessWidget {
  const _SegmentedTrustRing({
    required this.score,
    required this.color,
  });

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const size = 84.0;
    final clampedScore = score.clamp(0, 5);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: clampedScore.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Segmented Arc Canvas
              CustomPaint(
                size: const Size(size, size),
                painter: _SegmentedRingPainter(
                  progress: animatedProgress,
                  activeColor: color,
                  trackColor: const Color(0xFFEFECE6),
                ),
              ),

              // Centerpiece Disc
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFFBF2),
                  border: Border.all(color: const Color(0xFFEDE8DE), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: clampedScore >= 5
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: color, size: 22),
                            const SizedBox(height: 1),
                            Text(
                              "5/5",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: color,
                                height: 1,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  "$clampedScore",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: color,
                                    height: 1,
                                  ),
                                ),
                                const Text(
                                  "/5",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: WorkGoColors.textSecondary,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "trust_signals_unit".tr(),
                              style: const TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                color: WorkGoColors.textSecondary,
                                letterSpacing: 0.8,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentedRingPainter extends CustomPainter {
  final double progress; // 0.0 to 5.0
  final Color activeColor;
  final Color trackColor;

  const _SegmentedRingPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 6.2;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const int totalSegments = 5;
    const double gap = 0.18; // ~10.3 degrees gap between segments
    const double totalGap = totalSegments * gap;
    const double totalSweep = (2 * pi) - totalGap;
    const double segSweep = totalSweep / totalSegments;

    // Start at top (-pi/2) with half a gap offset for symmetry
    const double startOffset = -pi / 2 + gap / 2;

    for (int i = 0; i < totalSegments; i++) {
      final segStart = startOffset + i * (segSweep + gap);

      // 1. Inactive Track Segment
      final trackPaint = Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      canvas.drawArc(rect, segStart, segSweep, false, trackPaint);

      // 2. Active Progress Arc
      final segFill = (progress - i).clamp(0.0, 1.0);
      if (segFill > 0.0) {
        // Subtle glow pass
        final glowPaint = Paint()
          ..color = activeColor.withAlpha(35)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth + 3.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        canvas.drawArc(rect, segStart, segSweep * segFill, false, glowPaint);

        // Solid luminous arc
        final activePaint = Paint()
          ..color = activeColor
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth;
        canvas.drawArc(rect, segStart, segSweep * segFill, false, activePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_SegmentedRingPainter old) =>
      old.progress != progress ||
      old.activeColor != activeColor ||
      old.trackColor != trackColor;
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.label,
    required this.done,
    required this.icon,
    this.pending = false,
    this.recommended = false,
    this.onTap,
  });

  final String label;
  final bool done;
  final IconData icon;
  final bool pending;
  final bool recommended;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = done
        ? const Color(0xFF10B981)
        : pending
            ? const Color(0xFF2563EB)
            : const Color(0xFF9CA3AF);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? statusColor
                    : pending
                        ? statusColor.withAlpha(30)
                        : const Color(0xFFF3F4F6),
                border: Border.all(
                  color: (done || pending) ? statusColor : const Color(0xFFD1D5DB),
                  width: 1,
                ),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : pending
                        ? Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF2563EB),
                            ),
                          )
                        : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: done ? const Color(0xFF18181B) : const Color(0xFF71717A),
                  fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (recommended && !done)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                ),
                child: Text(
                  onTap != null ? "trust_link_action".tr() : "trust_recommended_tag".tr(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Flat representation of which trust signals are completed.
class TrustSignals {
  final bool phone;
  final bool aadhaar;
  final bool liveness;
  final bool eshram;
  final bool pcc;

  const TrustSignals({
    this.phone = false,
    this.aadhaar = false,
    this.liveness = false,
    this.eshram = false,
    this.pcc = false,
  });

  /// Build from a Worker's Firestore data.
  factory TrustSignals.fromWorker(Worker worker) {
    final vd = worker.verificationDetails;
    return TrustSignals(
      phone: worker.phoneForCalling != null &&
          worker.phoneForCalling!.isNotEmpty,
      aadhaar: vd?.aadhaarQrVerified == true || vd?.aadhaarVerifiedAt != null,
      liveness: vd?.livenessPassedAt != null,
      eshram: vd?.eshramUan != null && vd!.eshramUan!.isNotEmpty,
      pcc: vd?.pccDocumentId != null && vd?.pccReviewedAt != null,
    );
  }

  /// Build from a raw Firestore map (trustSignals field from backend).
  factory TrustSignals.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TrustSignals();
    return TrustSignals(
      phone: map["phone"] == true,
      aadhaar: map["aadhaar"] == true,
      liveness: map["liveness"] == true,
      eshram: map["eshram"] == true,
      pcc: map["pcc"] == true,
    );
  }
}
