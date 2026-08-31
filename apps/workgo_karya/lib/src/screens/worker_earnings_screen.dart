import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

class WorkerEarningsScreen extends StatelessWidget {
  const WorkerEarningsScreen({super.key, required this.worker});
  final Worker worker;

  @override
  Widget build(BuildContext context) {
    final bookingService = BookingService();

    return KaryaScaffold(
      appBar: KaryaAppBar(
        title: 'todays_earnings'.tr(),
        subtitle: "Cooperative Direct Payout Ledger",
      ),
      body: SafeArea(
        child: StreamBuilder<List<Booking>>(
          stream: bookingService.streamWorkerActiveJobs(worker.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                children: const [
                  KaryaShimmer(height: 140, borderRadius: 20),
                  SizedBox(height: 12),
                  KaryaShimmer(height: 80, borderRadius: 16),
                  SizedBox(height: 12),
                  KaryaShimmer(height: 200, borderRadius: 18),
                ],
              );
            }

            final allJobs = snapshot.data ?? [];
            final completedJobs = allJobs
                .where((b) => b.status == BookingStatus.completed)
                .toList();

            final totalGross = completedJobs.fold<double>(
              0.0,
              (sum, b) => sum + b.amount,
            );
            final welfareReserve = totalGross * 0.02;
            final netPayout = totalGross - welfareReserve;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero Net Payout Card
                  KSlideFadeIn(
                    child: _HeroLuminaPayoutCard(
                      netPayout: netPayout,
                      gross: totalGross,
                      welfare: welfareReserve,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── KPI Quick Row
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 40),
                    child: Row(
                      children: [
                        Expanded(
                          child: _KpiMiniCard(
                            label: 'completed_jobs'.tr(),
                            value: "${completedJobs.length}",
                            icon: Icons.task_alt_rounded,
                            accentColor: KX.emeraldLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _KpiMiniCard(
                            label: "Welfare Reserve (2%)",
                            value: "₹${welfareReserve.toStringAsFixed(0)}",
                            icon: Icons.shield_rounded,
                            accentColor: KX.violetLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _KpiMiniCard(
                            label: "Avg. Per Job",
                            value: completedJobs.isNotEmpty
                                ? "₹${(netPayout / completedJobs.length).toStringAsFixed(0)}"
                                : "₹0",
                            icon: Icons.bar_chart_rounded,
                            accentColor: KX.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Chronological Job History
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      "Job Ledger History",
                      style: WorkGoFonts.display(
                        color: KX.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (allJobs.isEmpty) ...[
                    KSlideFadeIn(
                      delay: const Duration(milliseconds: 120),
                      child: KaryaCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.receipt_long_rounded,
                                  color: KX.textMuted, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                "No jobs completed yet today",
                                style: WorkGoFonts.heading(
                                  color: KX.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Accept incoming job alerts from the radar to start generating payouts.",
                                style: WorkGoFonts.body(
                                  color: KX.textSecondary,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    ...List.generate(allJobs.length, (i) {
                      final job = allJobs[i];
                      return KSlideFadeIn(
                        delay: Duration(milliseconds: 120 + i * 40),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _LedgerTile(job: job),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  HERO LUMINA PAYOUT CARD
// ──────────────────────────────────────────────────────────────
class _HeroLuminaPayoutCard extends StatelessWidget {
  const _HeroLuminaPayoutCard({
    required this.netPayout,
    required this.gross,
    required this.welfare,
  });

  final double netPayout;
  final double gross;
  final double welfare;

  @override
  Widget build(BuildContext context) {
    return KaryaCard(
      glowColor: KX.gold,
      borderColor: KX.gold.withValues(alpha: 0.35),
      gradient: LinearGradient(
        colors: [
          KX.canvasCard,
          KX.violet.withValues(alpha: 0.22),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Accumulated Net Earnings",
                style: WorkGoFonts.body(
                  color: KX.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const KaryaBadge(
                label: "DIRECT CO-OP BANK PAYOUT",
                style: KaryaBadgeStyle.gold,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: KAnimatedCounter(
              value: netPayout,
              style: WorkGoFonts.numeric(
                color: KX.gold,
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: KX.glassBorder, height: 1),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Gross: ₹${gross.toStringAsFixed(0)}",
                style: WorkGoFonts.body(
                  color: KX.textSecondary,
                  fontSize: 11.5,
                ),
              ),
              Text(
                "Co-op Fund: ₹${welfare.toStringAsFixed(0)}",
                style: WorkGoFonts.body(
                  color: KX.emeraldLight,
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
//  KPI MINI CARD
// ──────────────────────────────────────────────────────────────
class _KpiMiniCard extends StatelessWidget {
  const _KpiMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return KaryaCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      borderRadius: 16,
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            style: WorkGoFonts.numeric(
              color: KX.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: WorkGoFonts.body(
              color: KX.textSecondary.withValues(alpha: 0.75),
              fontSize: 9.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  LEDGER TILE
// ──────────────────────────────────────────────────────────────
class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.job});
  final Booking job;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (job.status) {
      BookingStatus.completed => KX.emerald,
      BookingStatus.inProgress => KX.info,
      BookingStatus.accepted => KX.gold,
      BookingStatus.cancelled => KX.rose,
      _ => KX.textMuted,
    };

    final dateStr = job.scheduledAt != null
        ? "${job.scheduledAt!.toLocal().day}/${job.scheduledAt!.toLocal().month}"
        : "Today";

    return KaryaCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 14,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: KX.luminaVioletGold,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.handyman_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.serviceType,
                  style: WorkGoFonts.heading(
                    color: KX.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    KPulsingDot(color: statusColor, size: 5),
                    const SizedBox(width: 4),
                    Text(
                      "$dateStr · ${job.status.name.toUpperCase()}",
                      style: WorkGoFonts.body(
                        color: KX.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            "₹${job.amount.toStringAsFixed(0)}",
            style: WorkGoFonts.numeric(
              color: KX.gold,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
