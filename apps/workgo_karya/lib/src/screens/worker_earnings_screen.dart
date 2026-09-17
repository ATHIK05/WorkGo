import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

// ══════════════════════════════════════════════════════════════
//  SCULPTED CARD GEOMETRY (Exact Wave Curve from Reference)
// ══════════════════════════════════════════════════════════════

/// Custom clipper that carves the signature organic saddle wave contour:
/// - Top edge dips smoothly downward in the middle.
/// - Bottom edge sweeps downward parallel to the top dip.
/// - 34px smooth squircle corners.
class SculptedCardClipper extends CustomClipper<Path> {
  const SculptedCardClipper({this.dip = 13.0, this.radius = 34.0});

  final double dip;
  final double radius;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius;
    final path = Path();

    // Start at top-left below corner radius
    path.moveTo(0, r);
    // Top-left smooth corner
    path.quadraticBezierTo(0, 0, r, 0);
    // Top edge: gentle concave downward curve towards center
    path.cubicTo(w * 0.35, dip * 1.15, w * 0.65, dip * 1.15, w - r, 0);
    // Top-right smooth corner
    path.quadraticBezierTo(w, 0, w, r);
    // Right vertical edge
    path.lineTo(w, h - r);
    // Bottom-right smooth corner
    path.quadraticBezierTo(w, h, w - r, h);
    // Bottom edge: matching concave U-curve inward (mirroring top edge)
    path.cubicTo(w * 0.65, h - dip * 1.15, w * 0.35, h - dip * 1.15, r, h);
    // Bottom-left smooth corner
    path.quadraticBezierTo(0, h, 0, h - r);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant SculptedCardClipper oldClipper) =>
      oldClipper.dip != dip || oldClipper.radius != radius;
}

/// Custom painter that paints the ambient drop shadow along the exact
/// organic path, eliminating rectangular box shadow artifacts.
class SculptedCardPainter extends CustomPainter {
  const SculptedCardPainter({
    required this.backgroundColor,
    this.dip = 13.0,
    this.radius = 34.0,
    this.shadowColor = const Color(0x10000000),
    this.shadowBlur = 18.0,
    this.shadowOffset = const Offset(0, 6),
    this.borderColor,
    this.borderWidth = 1.0,
  });

  final Color backgroundColor;
  final double dip;
  final double radius;
  final Color shadowColor;
  final double shadowBlur;
  final Offset shadowOffset;
  final Color? borderColor;
  final double borderWidth;

  Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius;
    final path = Path();

    path.moveTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.cubicTo(w * 0.35, dip * 1.15, w * 0.65, dip * 1.15, w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h);
    path.cubicTo(w * 0.65, h - dip * 1.15, w * 0.35, h - dip * 1.15, r, h);
    path.quadraticBezierTo(0, h, 0, h - r);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // Draw organic ambient shadow
    if (shadowColor.a > 0) {
      final shadowPaint = Paint()
        ..color = shadowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);
      canvas.save();
      canvas.translate(shadowOffset.dx, shadowOffset.dy);
      canvas.drawPath(path, shadowPaint);
      canvas.restore();
    }

    // Draw body fill
    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Draw optional crisp border
    if (borderColor != null && borderWidth > 0) {
      final borderPaint = Paint()
        ..color = borderColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SculptedCardPainter oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.dip != dip ||
      oldDelegate.radius != radius ||
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.borderColor != borderColor;
}

/// Reusable container wrapping the custom painter and clipper.
class SculptedCard extends StatelessWidget {
  const SculptedCard({
    super.key,
    required this.backgroundColor,
    required this.child,
    this.dip = 13.0,
    this.radius = 34.0,
    this.padding = const EdgeInsets.fromLTRB(24, 26, 24, 22),
    this.shadowColor = const Color(0x10000000),
    this.borderColor,
  });

  final Color backgroundColor;
  final Widget child;
  final double dip;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color shadowColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SculptedCardPainter(
        backgroundColor: backgroundColor,
        dip: dip,
        radius: radius,
        shadowColor: shadowColor,
        borderColor: borderColor,
      ),
      child: ClipPath(
        clipper: SculptedCardClipper(dip: dip, radius: radius),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  WORKER EARNINGS SCREEN (White & Yellow Warm Theme)
// ══════════════════════════════════════════════════════════════

class WorkerEarningsScreen extends StatefulWidget {
  const WorkerEarningsScreen({
    super.key,
    required this.worker,
    this.earningsHeroKey,
  });

  final Worker worker;
  final GlobalKey? earningsHeroKey;

  @override
  State<WorkerEarningsScreen> createState() => _WorkerEarningsScreenState();
}

class _WorkerEarningsScreenState extends State<WorkerEarningsScreen> {
  int _selectedPeriodIndex =
      0; // 0: Today, 1: This Week, 2: This Month, 3: All Time
  late Stream<List<Booking>> _jobsStream;

  @override
  void initState() {
    super.initState();
    _jobsStream = BookingService().streamWorkerActiveJobs(widget.worker.id);
  }

  @override
  void didUpdateWidget(WorkerEarningsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.worker.id != oldWidget.worker.id) {
      _jobsStream = BookingService().streamWorkerActiveJobs(widget.worker.id);
    }
  }

  final List<String> _periodKeys = [
    "period_today",
    "period_this_week",
    "period_this_month",
    "period_all_time",
  ];
  final List<String> _periodDefaults = [
    "Today",
    "This Week",
    "This Month",
    "All Time",
  ];

  List<Booking> _filterJobs(List<Booking> jobs, int periodIndex) {
    final now = DateTime.now();
    switch (periodIndex) {
      case 0: // Today
        return jobs.where((b) {
          final dt = b.completedAt ?? b.scheduledAt ?? b.acceptedAt;
          if (dt == null) return true;
          return dt.year == now.year &&
              dt.month == now.month &&
              dt.day == now.day;
        }).toList();
      case 1: // This Week (past 7 days)
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        return jobs.where((b) {
          final dt = b.completedAt ?? b.scheduledAt ?? b.acceptedAt;
          if (dt == null) return true;
          return dt.isAfter(sevenDaysAgo);
        }).toList();
      case 2: // This Month (past 30 days)
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        return jobs.where((b) {
          final dt = b.completedAt ?? b.scheduledAt ?? b.acceptedAt;
          if (dt == null) return true;
          return dt.isAfter(thirtyDaysAgo);
        }).toList();
      case 3: // All Time
      default:
        return jobs;
    }
  }

  void _showInstantSettlementSheet(BuildContext context, double netPayout) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          _InstantSettlementModal(worker: widget.worker, netPayout: netPayout),
    );
  }

  void _showWelfareReserveSheet(BuildContext context, double welfareReserve) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _WelfareReserveModal(
        worker: widget.worker,
        welfareReserve: welfareReserve,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateSubtitle = DateFormat('EEE, d MMM').format(now);

    return Scaffold(
      backgroundColor: KX.canvas,
      appBar: AppBar(
        backgroundColor: KX.canvas,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "earnings_title".trSafe("Earnings"),
              style: GoogleFonts.urbanist(
                color: KX.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              dateSubtitle,
              style: GoogleFonts.urbanist(
                color: KX.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Booking>>(
          stream: _jobsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 90),
                children: const [
                  KaryaShimmer(height: 220, borderRadius: 34),
                  SizedBox(height: 16),
                  KaryaShimmer(height: 220, borderRadius: 34),
                  SizedBox(height: 16),
                  KaryaShimmer(height: 120, borderRadius: 24),
                ],
              );
            }

            final allJobs = snapshot.data ?? [];
            final filteredJobs = _filterJobs(allJobs, _selectedPeriodIndex);

            final completedJobs = filteredJobs
                .where((b) => b.status == BookingStatus.completed)
                .toList();
            final cancelledJobs = filteredJobs
                .where((b) => b.status == BookingStatus.cancelled)
                .toList();
            final activeJobs = filteredJobs
                .where(
                  (b) =>
                      b.status == BookingStatus.accepted ||
                      b.status == BookingStatus.inProgress ||
                      b.status == BookingStatus.paymentPending,
                )
                .toList();
            // Active first (may convert), cancelled last
            final unsettledJobs = [...activeJobs, ...cancelledJobs];

            final totalGross = completedJobs.fold<double>(
              0.0,
              (runningTotal, b) => runningTotal + b.totalAmount,
            );
            final welfareReserve = totalGross * 0.02;
            final netPayout = totalGross - welfareReserve;
            final avgPerJob = completedJobs.isNotEmpty
                ? totalGross / completedJobs.length
                : 0.0;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Hero Card: Net Payout
                  KeyedSubtree(
                    key: widget.earningsHeroKey,
                    child: _WhiteNetPayoutCard(
                      netPayout: netPayout,
                      gross: totalGross,
                      completedCount: completedJobs.length,
                      onTapArrow: () =>
                          _showInstantSettlementSheet(context, netPayout),
                      onTapPill: () =>
                          _showInstantSettlementSheet(context, netPayout),
                      onTapReceipt: () =>
                          _exportConsolidatedInvoice(context, completedJobs),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── 2. Compact icon-led stats row (replaces cryptic green pill)
                  _buildCompactStatsRow(completedJobs.length, avgPerJob),
                  const SizedBox(height: 10),

                  // ── 3. Hero Card: Welfare Reserve
                  _YellowWelfareReserveCard(
                    welfareReserve: welfareReserve,
                    totalGross: totalGross,
                    onTapArrow: () =>
                        _showWelfareReserveSheet(context, welfareReserve),
                    onTapPill: () =>
                        _showWelfareReserveSheet(context, welfareReserve),
                    onTapInfo: () =>
                        _showWelfareReserveSheet(context, welfareReserve),
                  ),
                  const SizedBox(height: 16),

                  // ── 4. Period filter — below heroes, not the first thing you see
                  _buildPeriodFilterRow(),
                  const SizedBox(height: 20),

                  // ── 5. Ledger header with dual count badge
                  _buildLedgerHeader(
                    completedJobs.length,
                    unsettledJobs.length,
                  ),
                  const SizedBox(height: 10),

                  // ── 6. Completed job cards
                  if (filteredJobs.isEmpty) ...[
                    _buildEmptyLedgerCard(context),
                  ] else ...[
                    ...completedJobs.map(
                      (job) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _JobLedgerCard(job: job, worker: widget.worker),
                      ),
                    ),

                    // ── 7. Not-Settled divider + unsettled cards
                    if (unsettledJobs.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildNotSettledDivider(),
                      const SizedBox(height: 10),
                      ...unsettledJobs.map(
                        (job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _JobLedgerCard(
                            job: job,
                            worker: widget.worker,
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),

                  // ── 7.5 Dial Karya Peer KYC Bounties
                  _buildPeerKycBountiesSection(widget.worker),

                  // ── 8. Linked settlement dock
                  _buildLinkedBankCard(widget.worker),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Compact 3-stat icon row — icon leads, text is secondary
  Widget _buildCompactStatsRow(int jobCount, double avgPerJob) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0EDE6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _statCell(
            Icons.check_circle_outline_rounded,
            const Color(0xFF059669),
            jobCount.toString(),
            "jobs_done_stat".trSafe("Done"),
          ),
          _buildStatDivider(),
          _statCell(
            Icons.account_balance_wallet_outlined,
            const Color(0xFFD97706),
            avgPerJob > 0 ? "\u20b9${avgPerJob.toStringAsFixed(0)}" : "\u2014",
            "avg_per_job_stat".trSafe("Avg/Job"),
          ),
          _buildStatDivider(),
          _statCell(
            Icons.bolt_rounded,
            const Color(0xFFFFAB00),
            "18:00",
            "settlement_time_stat".trSafe("UPI Out"),
          ),
        ],
      ),
    );
  }

  Widget _statCell(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.urbanist(
              color: const Color(0xFF141416),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.urbanist(
              color: const Color(0xFF9CA3AF),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 38,
      color: const Color(0xFFEDE8DE),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  // ── Ledger header: "Job Ledger" + "X Paid · Y Other" badge
  Widget _buildLedgerHeader(int completedCount, int otherCount) {
    final badgeText = otherCount > 0
        ? "$completedCount ${'paid_count_label'.trSafe('Paid')} \u00b7 $otherCount ${'other_count_label'.trSafe('Other')}"
        : "$completedCount ${'recorded_job_ledger'.trSafe('Recorded')}";
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "job_ledger_title".trSafe("Job Ledger"),
          style: GoogleFonts.urbanist(
            color: KX.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFDE59)),
          ),
          child: Text(
            badgeText,
            style: GoogleFonts.urbanist(
              color: const Color(0xFFB45309),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ── Thin "Not Settled" section divider
  Widget _buildNotSettledDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFEDE8DE), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            "not_settled_label".trSafe("Not Settled"),
            style: GoogleFonts.urbanist(
              color: const Color(0xFF9CA3AF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFEDE8DE), height: 1)),
      ],
    );
  }

  Widget _buildPeriodFilterRow() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE6), // Soft warm capsule
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(_periodKeys.length, (index) {
          final isSelected = _selectedPeriodIndex == index;
          final title = _periodKeys[index].trSafe(_periodDefaults[index]);

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedPeriodIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x0C000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    title,
                    style: GoogleFonts.urbanist(
                      color: isSelected
                          ? const Color(0xFF141416)
                          : const Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyLedgerCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3D6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFFD97706),
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "empty_ledger_title".trSafe("No Jobs Yet"),
            style: GoogleFonts.urbanist(
              color: KX.textPrimary,
              fontSize: 14,
                fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "empty_ledger_desc".trSafe(
              "Accept live requests from the Radar to generate payouts.",
            ),
            style: GoogleFonts.urbanist(
              color: const Color(0xFF6B6B6B),
              fontSize: 11.5,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedBankCard(Worker worker) {
    final accountDisplay =
        worker.phoneForCalling != null && worker.phoneForCalling!.length >= 4
        ? "UPI: ••••${worker.phoneForCalling!.substring(worker.phoneForCalling!.length - 4)}@okhdfc"
        : "Direct Co-op Escrow Account";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(
          0xFF141416,
        ), // Signature dark capsule dock on light canvas
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1E000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF26262B),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Color(0xFFFFB800),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "settlement_target_label".trSafe("Settlement Target"),
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  accountDisplay,
                  style: GoogleFonts.urbanist(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 12,
                ),
                SizedBox(width: 4),
                Text(
                  "VERIFIED",
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Dial Karya: Peer KYC Bounty Ledger Section ───────────────────────────
  Widget _buildPeerKycBountiesSection(Worker worker) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wallet_transactions')
          .where('workerId', isEqualTo: worker.id)
          .where('type', isEqualTo: 'PEER_KYC_BOUNTY')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final totalBounties = docs.fold<double>(
          0.0,
          (runningTotal, doc) =>
              runningTotal +
              ((doc.data() as Map<String, dynamic>)['amount'] as num? ?? 150)
                  .toDouble(),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFF0EDE6),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: KX.brandAmber.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: KX.brandAmber,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'peer_kyc_bounties_title'.trSafe("Dial Karya Peer KYC Bounties"),
                          style: const TextStyle(
                            color: KX.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'peer_kyc_bounties_subtitle'.trSafe("₹150 earned per verified feature-phone artisan"),
                          style: const TextStyle(
                            color: KX.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: KX.brandAmber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "₹${totalBounties.toStringAsFixed(0)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              if (docs.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF3F0EA)),
                const SizedBox(height: 10),
                ...docs.take(5).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final desc =
                      data['description'] as String? ?? 'peer_kyc_bounty_item'.trSafe('Peer KYC Bounty');
                  final amt = (data['amount'] as num?)?.toDouble() ?? 150.0;
                  final createdAt = data['createdAt'] as String?;
                  String dateStr = 'Recently';
                  if (createdAt != null) {
                    final dt = DateTime.tryParse(createdAt);
                    if (dt != null) {
                      dateStr = DateFormat('dd MMM, hh:mm a').format(dt);
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF10B981),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                desc,
                                style: const TextStyle(
                                  color: KX.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  color: KX.textSecondary,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "+₹${amt.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF9F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: KX.brandAmber,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'peer_kyc_bounty_hint'.trSafe("Verify nearby dial workers via home alerts to earn ₹150 instantly into your wallet."),
                          style: const TextStyle(
                            color: KX.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportConsolidatedInvoice(
    BuildContext context,
    List<Booking> jobs,
  ) async {
    HapticFeedback.lightImpact();
    if (jobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_completed_jobs_export'.trSafe('No completed jobs to export for this period.')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF141416),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('generating_invoice'.tr()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF141416),
      ),
    );

    try {
      await InvoiceService.exportInvoicePdf(
        booking: jobs.first,
        workerName: widget.worker.name,
        paymentMethod: "UPI Instant",
        context: context,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('invoice_export_error'.tr(args: ['$e'])),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  CARD 1: CRISP PURE WHITE SCULPTED CARD (NET PAYOUT)
// ══════════════════════════════════════════════════════════════

class _WhiteNetPayoutCard extends StatelessWidget {
  const _WhiteNetPayoutCard({
    required this.netPayout,
    required this.gross,
    required this.completedCount,
    required this.onTapArrow,
    required this.onTapPill,
    required this.onTapReceipt,
  });

  final double netPayout;
  final double gross;
  final int completedCount;
  final VoidCallback onTapArrow;
  final VoidCallback onTapPill;
  final VoidCallback onTapReceipt;

  @override
  Widget build(BuildContext context) {
    // Pure White card on warm canvas with subtle warm border & soft ambient shadow
    return SculptedCard(
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFEDE8DE),
      shadowColor: const Color(0x12000000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title + Circular Vibrant Yellow Accent Action Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  "personal_net_payout".trSafe("Personal Net Payout"),
                  style: GoogleFonts.urbanist(
                    color: const Color(0xFF141416),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Circular Accent Button in Theme Yellow
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTapArrow();
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFDE59), // Theme Vibrant Yellow
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_outward_rounded,
                      color: Color(0xFF141416),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Label: "Settlement Target" (Uppercase subtle muted text)
          Text(
            "settlement_target_label".trSafe("Settlement Target"),
            style: GoogleFonts.urbanist(
              color: const Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),

          // Massive Currency Counter: ₹1,450 /net
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "₹${netPayout.toStringAsFixed(0)}",
                style: GoogleFonts.urbanist(
                  color: const Color(0xFF141416),
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                "/net",
                style: GoogleFonts.urbanist(
                  color: const Color(0xFF6B7280),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                "Gross: ₹${gross.toStringAsFixed(0)}",
                style: GoogleFonts.urbanist(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Bottom Interactive Row: Pill Slider Button + Circular Action Button
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTapPill();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFF141416),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "${'instant_upi_settlement_pill'.trSafe('Instant UPI 18:00 Settlement')} >>>",
                            style: GoogleFonts.urbanist(
                              color: const Color(0xFF1F2937),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Circular Receipt / Detail Action Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTapReceipt();
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF141416),
                      size: 21,
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

// ══════════════════════════════════════════════════════════════
//  CARD 2: VIBRANT YELLOW SCULPTED CARD (CO-OP WELFARE RESERVE)
// ══════════════════════════════════════════════════════════════

class _YellowWelfareReserveCard extends StatelessWidget {
  const _YellowWelfareReserveCard({
    required this.welfareReserve,
    required this.totalGross,
    required this.onTapArrow,
    required this.onTapPill,
    required this.onTapInfo,
  });

  final double welfareReserve;
  final double totalGross;
  final VoidCallback onTapArrow;
  final VoidCallback onTapPill;
  final VoidCallback onTapInfo;

  @override
  Widget build(BuildContext context) {
    // Vibrant Theme Yellow background with crisp pure white circular accent
    return SculptedCard(
      backgroundColor: const Color(0xFFFFDE59), // Theme Vibrant Yellow
      borderColor: const Color(0xFFE5C84C),
      shadowColor: const Color(0x18B45309),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title + Circular Pure White Accent Action Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  "coop_welfare_reserve".trSafe("Co-op Welfare Reserve"),
                  style: GoogleFonts.urbanist(
                    color: const Color(0xFF141416),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Circular Accent Button in Pure White
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTapArrow();
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_outward_rounded,
                      color: Color(0xFF141416),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Label: "Cooperative Safety Net (2%)"
          Text(
            "coop_safety_net_label".trSafe("Cooperative Safety Net"),
            style: GoogleFonts.urbanist(
              color: const Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),

          // Massive Currency Counter: ₹290 /reserve
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "₹${welfareReserve.toStringAsFixed(0)}",
                style: GoogleFonts.urbanist(
                  color: const Color(0xFF141416),
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                "/reserve",
                style: GoogleFonts.urbanist(
                  color: const Color(0xFF475569),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                "2% Co-op Pool",
                style: GoogleFonts.urbanist(
                  color: const Color(0xFF475569),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Bottom Interactive Row: Pure White Pill Button + Circular Action Button
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTapPill();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0C000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFF141416),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.health_and_safety_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "${'view_medical_cover_pill'.trSafe('View Medical & Tool Cover')} >>>",
                            style: GoogleFonts.urbanist(
                              color: const Color(0xFF141416),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Circular Info / Shield Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTapInfo();
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0C000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF141416),
                      size: 21,
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

// ══════════════════════════════════════════════════════════════
//  JOB LEDGER CARD — Same SculptedCard wave geometry as hero cards.
//  Completed: white card + yellow accent circle (ref Card 1)
//  Active:    yellow card + dark accent circle  (ref Card 2)
//  Cancelled: muted warm card + red accent circle
//  Layout: large title → label → amount/suffix → bottom pill row
// ══════════════════════════════════════════════════════════════

class _JobLedgerCard extends StatelessWidget {
  const _JobLedgerCard({required this.job, required this.worker});

  final Booking job;
  final Worker worker;

  @override
  Widget build(BuildContext context) {
    final isCompleted = job.status == BookingStatus.completed;
    final isCancelled = job.status == BookingStatus.cancelled;
    final isInProgress = job.status == BookingStatus.inProgress;
    final isPaymentPending = job.status == BookingStatus.paymentPending;
    final isActive = !isCompleted && !isCancelled;

    // ── Card colors: mirrors the hero card palette
    // Completed → white card + yellow accent (like Card 1 in reference)
    // Active    → yellow card + dark accent  (like Card 2 in reference)
    // Cancelled → warm muted card + red accent
    final Color cardBg = isCompleted
        ? Colors.white
        : isActive
        ? const Color(0xFFFFDE59) // Theme yellow
        : const Color(0xFFFCFAF7); // Muted warm for cancelled

    final Color cardBorderColor = isCompleted
        ? const Color(0xFFEDE8DE)
        : isActive
        ? const Color(0xFFE5C84C)
        : const Color(0xFFFFCDD2);

    final Color cardShadowColor = isCompleted
        ? const Color(0x0E000000)
        : isActive
        ? const Color(0x14B45309)
        : const Color(0x0AEF4444);

    // Accent circle: yellow on white, white on yellow, red-tint on cancelled
    final Color accentCircleBg = isCompleted
        ? const Color(0xFFFFDE59)
        : isActive
        ? Colors.white
        : const Color(0xFFFEE2E2);
    final Color accentIconColor = isCompleted || isActive
        ? const Color(0xFF141416)
        : const Color(0xFF991B1B);

    // Pill colors: grey pill on white card, white pill on yellow card
    final Color pillBg = isCompleted
        ? const Color(0xFFF3F4F6)
        : isActive
        ? Colors.white
        : const Color(0xFFFEE2E2);
    final Color pillTextColor = isCompleted || isActive
        ? const Color(0xFF141416)
        : const Color(0xFF991B1B);

    // Right circular icon button (receipt / info)
    final Color iconBtnBg = isCompleted
        ? const Color(0xFFF3F4F6)
        : isActive
        ? Colors.white
        : const Color(0xFFFEE2E2);

    // Label text: uppercase, small, muted
    final String labelKey;
    final String labelDefault;
    if (isCompleted) {
      labelKey = "ledger_label_paid";
      labelDefault = "PAID — TAP FOR RECEIPT";
    } else if (isCancelled) {
      labelKey = "ledger_label_cancelled";
      labelDefault = "CANCELLED — NO PAYOUT";
    } else if (isPaymentPending) {
      labelKey = "ledger_label_unpaid";
      labelDefault = "AWAITING PAYMENT";
    } else if (isInProgress) {
      labelKey = "ledger_label_inprogress";
      labelDefault = "IN PROGRESS";
    } else {
      labelKey = "ledger_label_enroute";
      labelDefault = "WORKER ENROUTE";
    }

    // Pill action text
    final String pillKey;
    final String pillDefault;
    final IconData pillLeadIcon;
    final IconData trailingIcon;
    if (isCompleted) {
      pillKey = "ledger_pill_receipt";
      pillDefault = "Export Receipt";
      pillLeadIcon = Icons.check_rounded;
      trailingIcon = Icons.receipt_long_rounded;
    } else if (isCancelled) {
      pillKey = "ledger_pill_cancelled";
      pillDefault = "Job Cancelled";
      pillLeadIcon = Icons.close_rounded;
      trailingIcon = Icons.info_outline_rounded;
    } else if (isPaymentPending) {
      pillKey = "ledger_pill_payment";
      pillDefault = "Payment Pending";
      pillLeadIcon = Icons.hourglass_top_rounded;
      trailingIcon = Icons.account_balance_wallet_outlined;
    } else {
      pillKey = "ledger_pill_active";
      pillDefault = "Job In Progress";
      pillLeadIcon = Icons.bolt_rounded;
      trailingIcon = Icons.map_outlined;
    }

    final tradeTitle = job.serviceType.toLocalizedTrade();
    final timeStr =
        (job.completedAt ?? job.acceptedAt ?? job.scheduledAt)
            ?.to12HourDateTime() ??
        "";

    final Color titleColor = const Color(0xFF141416);
    final Color labelColor = isCompleted
        ? const Color(0xFF6B7280)
        : isActive
        ? const Color(0xFF475569)
        : const Color(0xFFB45309);
    final Color amountColor = isCompleted
        ? const Color(0xFF141416)
        : isActive
        ? const Color(0xFF141416)
        : const Color(0xFFB0ADA8);
    final Color suffixColor = isCompleted
        ? const Color(0xFF6B7280)
        : isActive
        ? const Color(0xFF475569)
        : const Color(0xFFB0ADA8);

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        if (isCompleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('generating_invoice'.tr()),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF141416),
            ),
          );
          try {
            await InvoiceService.exportInvoicePdf(
              booking: job,
              workerName: worker.name,
              paymentMethod: "UPI Instant",
              context: context,
            );
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('invoice_export_error'.tr(args: ['$e'])),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } else {
          final msg = isCancelled
              ? "cancelled_job_notice".trSafe(
                  "This job was cancelled. No payout is generated.",
                )
              : "active_job_notice".trSafe(
                  "Job in progress. Payout recorded after completion.",
                );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF141416),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: SculptedCard(
        backgroundColor: cardBg,
        borderColor: cardBorderColor,
        shadowColor: cardShadowColor,
        dip: 8,
        radius: 26,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: trade title (left, 2 lines allowed) + accent circle (right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tradeTitle,
                        style: GoogleFonts.urbanist(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                      ),
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          timeStr,
                          style: GoogleFonts.urbanist(
                            color: labelColor.withValues(alpha: 0.6),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Accent circle (yellow on white / white on yellow / red-tint on cancelled)
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentCircleBg,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isCompleted
                          ? Icons.arrow_outward_rounded
                          : isActive
                          ? Icons.bolt_rounded
                          : Icons.close_rounded,
                      color: accentIconColor,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Label (uppercase, small, muted)
            Text(
              labelKey.trSafe(labelDefault),
              style: GoogleFonts.urbanist(
                color: labelColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 3),

            // ── Amount row: large bold ₹ + suffix
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  "\u20b9${job.totalAmount.toStringAsFixed(0)}",
                  style: GoogleFonts.urbanist(
                    color: amountColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                    decorationColor: const Color(0xFFADADAD),
                    decorationThickness: 2,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  isCompleted
                      ? "/net"
                      : isCancelled
                      ? "/void"
                      : "/pending",
                  style: GoogleFonts.urbanist(
                    color: suffixColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isCompleted) ...[
                  const Spacer(),
                  Text(
                    "Net \u20b9${(job.totalAmount * 0.98).toStringAsFixed(0)}",
                    style: GoogleFonts.urbanist(
                      color: const Color(0xFF059669),
                      fontSize: 12,
                              fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Bottom action pill + icon circle (mirrors hero card bottom row)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: isActive
                          ? const [
                              BoxShadow(
                                color: Color(0x0C000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Color(0xFF141416),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              pillLeadIcon,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "${pillKey.trSafe(pillDefault)} >>>",
                            style: GoogleFonts.urbanist(
                              color: pillTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Trailing icon circle
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBtnBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFFE5E7EB)
                          : isActive
                          ? Colors.white.withValues(alpha: 0.6)
                          : const Color(0xFFFFCDD2),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      trailingIcon,
                      color: const Color(0xFF141416),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  INTERACTIVE BOTTOM SHEETS (LIGHT THEMED MODALS)
// ══════════════════════════════════════════════════════════════

class _InstantSettlementModal extends StatelessWidget {
  const _InstantSettlementModal({
    required this.worker,
    required this.netPayout,
  });

  final Worker worker;
  final double netPayout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white, // Light themed modal
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3D6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Instant UPI 18:00 Settlement",
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF141416),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "Direct Co-op Escrow Release",
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Daily Accumulated Net",
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      "₹${netPayout.toStringAsFixed(0)}",
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF141416),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFE5E7EB), height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Settlement Batch Window",
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      "18:00 IST (Daily)",
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF047857),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "instant_payout_notice".trSafe(
              "Earnings are settled directly to your verified UPI account daily at 18:00.",
            ),
            style: GoogleFonts.urbanist(
              color: const Color(0xFF6B7280),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFDE59),
              foregroundColor: const Color(0xFF141416),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              "Done",
              style: GoogleFonts.urbanist(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelfareReserveModal extends StatelessWidget {
  const _WelfareReserveModal({
    required this.worker,
    required this.welfareReserve,
  });

  final Worker worker;
  final double welfareReserve;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white, // Light themed modal
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3D6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "medical_cover_title".trSafe("Co-op Artisan Safety Net"),
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF141416),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "2% Direct Health & Tool Protection",
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _benefitRow(
                  Icons.medical_services_outlined,
                  "OPD & Diagnostic Cover",
                  "₹15,000/yr",
                ),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFE5E7EB), height: 1),
                const SizedBox(height: 10),
                _benefitRow(
                  Icons.handyman_outlined,
                  "Trade Tool Damage Insurance",
                  "100% Repaired",
                ),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFE5E7EB), height: 1),
                const SizedBox(height: 10),
                _benefitRow(
                  Icons.family_restroom_outlined,
                  "Artisan Welfare Fund Reserve",
                  "₹${welfareReserve.toStringAsFixed(0)} allocated",
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "medical_cover_desc".trSafe(
              "2% of each completed booking directly funds your health coverage, OPD reimbursements, and tool repair insurance.",
            ),
            style: GoogleFonts.urbanist(
              color: const Color(0xFF6B7280),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFDE59),
              foregroundColor: const Color(0xFF141416),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              "Understood",
              style: GoogleFonts.urbanist(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD97706), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.urbanist(
              color: const Color(0xFF141416),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.urbanist(
            color: const Color(0xFF047857),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
