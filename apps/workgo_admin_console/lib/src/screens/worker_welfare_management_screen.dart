import 'package:flutter/material.dart';
import 'package:workgo_core/workgo_core.dart';
import '../admin_theme.dart';

class WorkerWelfareManagementScreen extends StatefulWidget {
  const WorkerWelfareManagementScreen({super.key});

  @override
  State<WorkerWelfareManagementScreen> createState() => _WorkerWelfareManagementScreenState();
}

class _WorkerWelfareManagementScreenState extends State<WorkerWelfareManagementScreen> {
  final WorkerService _workerService = WorkerService();
  final BookingService _bookingService = BookingService();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AX.bgCosmic,
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<List<Booking>>(
        stream: _bookingService.streamAllBookings(),
        builder: (context, bookingSnap) {
          return StreamBuilder<List<Worker>>(
            stream: _workerService.streamAllWorkers(),
            builder: (context, workerSnap) {
              final bookings = bookingSnap.data ?? [];
              var workers = workerSnap.data ?? [];

              final settledBookings = bookings.where((b) => b.paymentStatus == PaymentStatus.paid).toList();
              final realizedGrossVolume = settledBookings.fold<double>(0.0, (s, b) => s + b.amount);
              final welfareCorpus = realizedGrossVolume * 0.02; // strictly 2% of settled funds
              final insuredCount = workers.where((w) => w.insuranceStatus).length;
              final double coverageRate = workers.isNotEmpty ? (insuredCount / workers.length) * 100 : 0.0;

              if (_searchQuery.isNotEmpty) {
                workers = workers.where((w) {
                  final nameMatch = w.name.toLowerCase().contains(_searchQuery);
                  final skillMatch = w.skills.any((s) => s.toLowerCase().contains(_searchQuery));
                  final idMatch = w.id.toLowerCase().contains(_searchQuery);
                  return nameMatch || skillMatch || idMatch;
                }).toList();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title Bar ─────────────────────────────────────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 750;
                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('admin_welfare_title'.trSafe("Cooperative Welfare & Insurance Corpus"), style: AX.display(fontSize: 18)),
                            const SizedBox(height: 2),
                            Text('admin_welfare_subtitle'.trSafe("PMJJBY / PMSBY micro-insurance pool auto-accumulated from 2% booking dividend"), style: AX.body(fontSize: 11)),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('admin_welfare_title'.trSafe("Cooperative Welfare & Insurance Corpus"), style: AX.display(fontSize: 20)),
                              const SizedBox(height: 2),
                              Text('admin_welfare_subtitle'.trSafe("PMJJBY / PMSBY micro-insurance pool auto-accumulated from 2% booking dividend"), style: AX.body(fontSize: 12)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3D6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AX.emerald.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_rounded, color: AX.emeraldDark, size: 16),
                                const SizedBox(width: 6),
                                Text('admin_welfare_gov_corpus'.trSafe("GOV CORPUS v2.4"), style: AX.mono(fontSize: 11, color: AX.emeraldDark)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Welfare Pool KPI Banners (Responsive Layout) ──────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(
                              child: _buildCorpusCard(
                                title: 'admin_welfare_pool_title'.trSafe("Accumulated Welfare Pool"),
                                value: "₹${welfareCorpus >= 1000 ? '${(welfareCorpus / 1000).toStringAsFixed(2)}k' : welfareCorpus.toStringAsFixed(0)}",
                                subtitle: 'admin_welfare_pool_subtitle'.trSafe("2% of ₹${realizedGrossVolume.toStringAsFixed(0)} settled volume", [realizedGrossVolume.toStringAsFixed(0)]),
                                icon: Icons.account_balance_wallet_rounded,
                                color: const Color(0xFF065F46),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildCorpusCard(
                                title: 'admin_welfare_insured_artisans'.trSafe("Insured Artisans"),
                                value: "$insuredCount / ${workers.length}",
                                subtitle: 'admin_welfare_coverage_subtitle'.trSafe("${coverageRate.toStringAsFixed(0)}% membership coverage", [coverageRate.toStringAsFixed(0)]),
                                icon: Icons.health_and_safety_rounded,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildCorpusCard(
                                title: 'admin_welfare_policy_schemes'.trSafe("Policy Schemes"),
                                value: "PMJJBY + PMSBY",
                                subtitle: 'admin_welfare_cover_subtitle'.trSafe("₹2L Life + ₹2L Accident Cover"),
                                icon: Icons.security_rounded,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildCorpusCard(
                            title: 'admin_welfare_pool_title'.trSafe("Accumulated Welfare Pool"),
                            value: "₹${welfareCorpus >= 1000 ? '${(welfareCorpus / 1000).toStringAsFixed(2)}k' : welfareCorpus.toStringAsFixed(0)}",
                            subtitle: 'admin_welfare_pool_subtitle'.trSafe("2% of ₹${realizedGrossVolume.toStringAsFixed(0)} settled volume", [realizedGrossVolume.toStringAsFixed(0)]),
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFF065F46),
                          ),
                          const SizedBox(height: 12),
                          _buildCorpusCard(
                            title: 'admin_welfare_insured_artisans'.trSafe("Insured Artisans"),
                            value: "$insuredCount / ${workers.length}",
                            subtitle: 'admin_welfare_coverage_subtitle'.trSafe("${coverageRate.toStringAsFixed(0)}% membership coverage", [coverageRate.toStringAsFixed(0)]),
                            icon: Icons.health_and_safety_rounded,
                            color: const Color(0xFF7C3AED),
                          ),
                          const SizedBox(height: 12),
                          _buildCorpusCard(
                            title: 'admin_welfare_policy_schemes'.trSafe("Policy Schemes"),
                            value: "PMJJBY + PMSBY",
                            subtitle: 'admin_welfare_cover_subtitle'.trSafe("₹2L Life + ₹2L Accident Cover"),
                            icon: Icons.security_rounded,
                            color: const Color(0xFF1D4ED8),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Search & Filter Controls ──────────────────────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 650;
                      final searchField = SizedBox(
                        width: isNarrow ? double.infinity : 280,
                        height: 38,
                        child: TextField(
                          style: const TextStyle(color: AX.textPrimary, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'admin_welfare_search_hint'.trSafe("Search artisan name or trade..."),
                            hintStyle: const TextStyle(color: AX.textMuted, fontSize: 11),
                            prefixIcon: const Icon(Icons.search_rounded, color: AX.textSecondary, size: 16),
                            filled: true,
                            fillColor: const Color(0xFFF9F6EE),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AX.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AX.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AX.emerald, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('admin_welfare_roster_title'.trSafe("Artisan Insurance Roster (${workers.length})", ['${workers.length}']), style: AX.display(fontSize: 16)),
                            const SizedBox(height: 10),
                            searchField,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('admin_welfare_roster_title'.trSafe("Artisan Insurance Roster (${workers.length})", ['${workers.length}']), style: AX.display(fontSize: 16)),
                          searchField,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Worker Roster List (100% Real-Time Data) ───────────────
                  Expanded(
                    child: workers.isEmpty
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: AX.glassBox(radius: 18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people_outline_rounded, color: AX.textMuted, size: 36),
                                  const SizedBox(height: 12),
                                  Text('admin_welfare_no_workers'.trSafe("No Workers Found"), style: AX.display(fontSize: 15)),
                                  Text('admin_welfare_no_workers_hint'.trSafe("Artisans who register on the WorkGo network will appear here."), style: AX.body(fontSize: 12)),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: workers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final w = workers[index];
                              return _buildWorkerRosterCard(context, w);
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCorpusCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AX.glowBox(glowColor: color, radius: 16, blurRadius: 16, opacity: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AX.body(fontSize: 12, fontWeight: FontWeight.bold, color: AX.textSecondary)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AX.display(fontSize: 22, color: AX.textPrimary)),
          Text(subtitle, style: AX.mono(fontSize: 10, color: AX.textMuted)),
        ],
      ),
    );
  }

  Widget _buildWorkerRosterCard(BuildContext context, Worker w) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AX.glassBox(radius: 16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: w.insuranceStatus ? const Color(0xFFD1FAE5) : const Color(0xFFF3F0EA),
            child: Icon(
              w.insuranceStatus ? Icons.health_and_safety_rounded : Icons.person_rounded,
              color: w.insuranceStatus ? const Color(0xFF065F46) : AX.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Worker Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(w.name.isNotEmpty ? w.name : "Artisan #${w.id.substring(0, w.id.length.clamp(0, 6)).toUpperCase()}", style: AX.heading(fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        w.skills.map((s) => s.toLocalizedTradeClean()).join(", "),
                        style: const TextStyle(fontFamily: "SpaceGrotesk", fontSize: 10, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  w.insuranceStatus
                      ? 'admin_welfare_enrolled_desc'.trSafe("Enrolled: PMJJBY + PMSBY Plan (₹436/yr auto-debited from welfare fund)")
                      : 'admin_welfare_inactive_desc'.trSafe("Micro-insurance inactive · Tap toggle to enroll from cooperative corpus"),
                  style: AX.body(fontSize: 11, color: w.insuranceStatus ? const Color(0xFF065F46) : AX.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Toggle Switch
          Switch(
            value: w.insuranceStatus,
            activeThumbColor: AX.emerald,
            activeTrackColor: AX.emerald.withValues(alpha: 0.4),
            inactiveThumbColor: AX.textMuted,
            inactiveTrackColor: const Color(0xFFF0EDE6),
            onChanged: (val) async {
              await _workerService.toggleInsurance(w.id, val);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
