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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Cooperative Welfare & Insurance Corpus", style: AX.display(fontSize: 20)),
                          const SizedBox(height: 2),
                          Text("PMJJBY / PMSBY micro-insurance pool auto-accumulated from 2% booking dividend", style: AX.body(fontSize: 12)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: AX.glassBox(radius: 12, borderColor: AX.emerald.withValues(alpha: 0.4)),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: AX.emerald, size: 16),
                            const SizedBox(width: 6),
                            Text("GOV CORPUS v2.4", style: AX.mono(fontSize: 11, color: AX.emeraldLight)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Welfare Pool KPI Banners ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _buildCorpusCard(
                          title: "Accumulated Welfare Pool",
                          value: "₹${welfareCorpus >= 1000 ? '${(welfareCorpus / 1000).toStringAsFixed(2)}k' : welfareCorpus.toStringAsFixed(0)}",
                          subtitle: "2% of ₹${realizedGrossVolume.toStringAsFixed(0)} settled volume",
                          icon: Icons.account_balance_wallet_rounded,
                          color: AX.emerald,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildCorpusCard(
                          title: "Insured Artisans",
                          value: "$insuredCount / ${workers.length}",
                          subtitle: "${coverageRate.toStringAsFixed(0)}% membership coverage",
                          icon: Icons.health_and_safety_rounded,
                          color: AX.violet,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildCorpusCard(
                          title: "Policy Schemes",
                          value: "PMJJBY + PMSBY",
                          subtitle: "₹2L Life + ₹2L Accident Cover",
                          icon: Icons.security_rounded,
                          color: AX.cyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Search & Filter Controls ──────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Artisan Insurance Roster (${workers.length})", style: AX.display(fontSize: 16)),
                      SizedBox(
                        width: 280,
                        height: 38,
                        child: TextField(
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: "Search artisan name or trade...",
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 16),
                            filled: true,
                            fillColor: AX.bgCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                        ),
                      ),
                    ],
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
                                  const Icon(Icons.people_outline_rounded, color: Colors.white24, size: 36),
                                  const SizedBox(height: 12),
                                  Text("No Workers Found", style: AX.display(fontSize: 15)),
                                  Text("Artisans who register on the WorkGo network will appear here.", style: AX.body(fontSize: 12)),
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
      decoration: AX.glowBox(glowColor: color, radius: 16, blurRadius: 16, opacity: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AX.body(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AX.display(fontSize: 22, color: Colors.white)),
          Text(subtitle, style: AX.mono(fontSize: 10, color: Colors.white38)),
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
            backgroundColor: w.insuranceStatus ? AX.emeraldDark : Colors.white10,
            child: Icon(
              w.insuranceStatus ? Icons.health_and_safety_rounded : Icons.person_rounded,
              color: w.insuranceStatus ? Colors.white : Colors.white60,
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
                    Text(w.name.isNotEmpty ? w.name : "Artisan #${w.id.substring(0, 6).toUpperCase()}", style: AX.heading(fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AX.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(w.skills.join(", "), style: AX.mono(fontSize: 10, color: AX.cyanLight)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  w.insuranceStatus
                      ? "Enrolled: PMJJBY + PMSBY Plan (₹436/yr auto-debited from welfare fund)"
                      : "Micro-insurance inactive · Tap toggle to enroll from cooperative corpus",
                  style: AX.body(fontSize: 11, color: w.insuranceStatus ? AX.emeraldLight : Colors.white38),
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
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white10,
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
