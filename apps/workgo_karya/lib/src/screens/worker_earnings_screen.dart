import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

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
  int _selectedPeriodIndex = 0; // 0: Today, 1: This Week, 2: This Month, 3: All Time
  final List<String> _periods = ["Today", "This Week", "This Month", "All Time"];

  @override
  Widget build(BuildContext context) {
    final bookingService = BookingService();
    final now = DateTime.now();
    final dateSubtitle = "${DateFormat('EEEE, d MMM').format(now)} · Direct Co-op Ledger";

    return Scaffold(
      backgroundColor: KX.canvas,
      appBar: AppBar(
        backgroundColor: KX.canvas,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF0EDE6)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: KX.textPrimary),
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "todays_earnings".trSafe("Today's Earnings"),
              style: WorkGoFonts.heading(
                color: KX.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              dateSubtitle,
              style: WorkGoFonts.body(
                color: KX.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, color: Color(0xFF047857), size: 13),
                SizedBox(width: 3),
                Text(
                  "UPI 18:00",
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Booking>>(
          stream: bookingService.streamWorkerActiveJobs(widget.worker.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 90),
                children: const [
                  KaryaShimmer(height: 160, borderRadius: 24),
                  SizedBox(height: 14),
                  KaryaShimmer(height: 80, borderRadius: 18),
                  SizedBox(height: 14),
                  KaryaShimmer(height: 220, borderRadius: 20),
                ],
              );
            }

            final allJobs = snapshot.data ?? [];
            final completedJobs = allJobs
                .where((b) => b.status == BookingStatus.completed)
                .toList();

            final totalGross = completedJobs.fold<double>(
              0.0,
              (sum, b) => sum + b.totalAmount,
            );
            final welfareReserve = totalGross * 0.02;
            final netPayout = totalGross - welfareReserve;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Hero Earning Master Card (Reference Lavender / Luxury Card)
                  KeyedSubtree(
                    key: widget.earningsHeroKey,
                    child: _HeroEarningMasterCard(
                      netPayout: netPayout,
                      gross: totalGross,
                      welfare: welfareReserve,
                      completedCount: completedJobs.length,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 2. 3 Interactive Bento Metric Chips
                  _buildBentoMetricsRow(completedJobs.length, netPayout),
                  const SizedBox(height: 16),

                  // ── 3. Period Filter Capsule Row
                  _buildPeriodFilterRow(),
                  const SizedBox(height: 18),

                  // ── 4. Job Ledger History Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Job Ledger History",
                        style: WorkGoFonts.display(
                          color: KX.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${allJobs.length} RECORDED",
                          style: const TextStyle(
                            color: Color(0xFF4B5563),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── 5. Job History List / Empty State
                  if (allJobs.isEmpty) ...[
                    _buildEmptyLedgerCard(context),
                  ] else ...[
                    ...List.generate(allJobs.length, (i) {
                      final job = allJobs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LedgerTile(job: job, worker: widget.worker),
                      );
                    }),
                  ],
                  const SizedBox(height: 16),

                  // ── 6. Linked Bank & Instant Transfer Banner
                  _buildLinkedBankCard(widget.worker),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBentoMetricsRow(int completedCount, double netPayout) {
    final avgPerJob = completedCount > 0 ? (netPayout / completedCount) : 0.0;

    return Row(
      children: [
        Expanded(
          child: _bentoSpec(
            "Jobs Done",
            "$completedCount Done",
            const Color(0xFFD1FAE5),
            const Color(0xFF065F46),
            Icons.task_alt_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _bentoSpec(
            "Avg. Ticket",
            "₹${avgPerJob.toStringAsFixed(0)}",
            const Color(0xFFD6EBFF),
            const Color(0xFF1E3A8A),
            Icons.bar_chart_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _bentoSpec(
            "Comm. Rate",
            "0% Co-op",
            const Color(0xFFFFE0A3),
            const Color(0xFF92400E),
            Icons.percent_rounded,
          ),
        ),
      ],
    );
  }

  Widget _bentoSpec(String label, String value, Color bgColor, Color textColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: textColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodFilterRow() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(_periods.length, (index) {
          final isSelected = _selectedPeriodIndex == index;
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
                            color: Color(0x0A000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    _periods[index],
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF141416) : const Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
      padding: const EdgeInsets.all(28),
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
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFD97706), size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            "No Completed Jobs Today",
            style: WorkGoFonts.heading(
              color: KX.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Accept live customer broadcasts from the Radar to generate instant direct payouts.",
            style: WorkGoFonts.body(
              color: const Color(0xFF6B6B6B),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedBankCard(Worker worker) {
    final accountDisplay = worker.phoneForCalling != null && worker.phoneForCalling!.length >= 4
        ? "UPI: ${worker.phoneForCalling!.substring(worker.phoneForCalling!.length - 4)}****@okhdfc"
        : "Direct Co-op Escrow Account";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
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
            child: const Icon(Icons.account_balance_rounded, color: Color(0xFFFFB800), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Settlement Target",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  accountDisplay,
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                SizedBox(width: 4),
                Text(
                  "VERIFIED",
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  HERO EARNING MASTER CARD (Reference Lavender Gradient Card)
// ──────────────────────────────────────────────────────────────
class _HeroEarningMasterCard extends StatelessWidget {
  const _HeroEarningMasterCard({
    required this.netPayout,
    required this.gross,
    required this.welfare,
    required this.completedCount,
  });

  final double netPayout;
  final double gross;
  final double welfare;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE8FF), Color(0xFFDFD4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x127C3AED),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Label + Direct Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Accumulated Net Payout",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF5B4D7A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1035),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFFFB800), size: 11),
                    SizedBox(width: 4),
                    Text(
                      "DIRECT CO-OP PAY",
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Massive Currency Counter
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "₹${netPayout.toStringAsFixed(0)}",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF1E1035),
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "NET",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF047857),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: const Color(0xFF5B4D7A).withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 12),

          // Bottom Breakdown Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Gross Billed: ₹${gross.toStringAsFixed(0)}",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF5B4D7A),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "Co-op Fund (2%): ₹${welfare.toStringAsFixed(0)}",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF047857),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  LEDGER TILE (20px Modern Card)
// ──────────────────────────────────────────────────────────────
class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.job, required this.worker});
  final Booking job;
  final Worker worker;

  @override
  Widget build(BuildContext context) {
    final isCompleted = job.status == BookingStatus.completed;
    final dateStr = job.scheduledAt != null
        ? job.scheduledAt!.to12HourDateTime()
        : "Today";

    final tradeTitle = job.serviceType.toLocalizedTrade();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isCompleted
            ? () async {
                HapticFeedback.lightImpact();
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
                    paymentMethod: "UPI",
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
            : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCompleted ? Icons.receipt_long_rounded : Icons.pending_rounded,
                  color: isCompleted ? const Color(0xFF047857) : const Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tradeTitle,
                      style: WorkGoFonts.heading(
                        color: KX.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$dateStr · ${job.status.name.toUpperCase()}${isCompleted ? ' · Tap for Receipt' : ''}",
                      style: WorkGoFonts.body(
                        color: isCompleted ? const Color(0xFF047857) : const Color(0xFF6B6B6B),
                        fontSize: 11,
                        fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "₹${job.totalAmount.toStringAsFixed(0)}",
                    style: WorkGoFonts.numeric(
                      color: const Color(0xFF141416),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Net: ₹${(job.totalAmount * 0.98).toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (isCompleted) ...[
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF9CA3AF)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

