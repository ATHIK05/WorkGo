import 'package:flutter/material.dart';
import 'package:workgo_core/workgo_core.dart';
import '../admin_theme.dart';

class ProxyVerificationQueueScreen extends StatelessWidget {
  const ProxyVerificationQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workerService = WorkerService();

    return Container(
      color: AX.bgCosmic,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title Bar ─────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Proxy Artisan Voice Onboarding Queue", style: AX.display(fontSize: 20)),
                  const SizedBox(height: 2),
                  Text("Verify non-smartphone artisans referred by cooperative members via telephone bridge", style: AX.body(fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: AX.glassBox(radius: 12, borderColor: AX.violet.withValues(alpha: 0.4)),
                child: Row(
                  children: [
                    const Icon(Icons.phone_in_talk_rounded, color: AX.violetLight, size: 16),
                    const SizedBox(width: 6),
                    Text("CALL-TO-BOOK BRIDGE", style: AX.mono(fontSize: 11, color: AX.violetLight)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Real-Time Proxy Queue Stream (Zero Mock Data) ─────────────────
          Expanded(
            child: StreamBuilder<List<Worker>>(
              stream: workerService.streamPendingWorkers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AX.violet));
                }

                final proxyWorkers = (snapshot.data ?? [])
                    .where((w) => w.isProxy && w.verificationStatus == VerificationStatus.pending)
                    .toList();

                if (proxyWorkers.isEmpty) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(36),
                      decoration: AX.glassBox(radius: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: AX.violet.withValues(alpha: 0.15)),
                            child: const Icon(Icons.phone_in_talk_rounded, color: AX.violetLight, size: 36),
                          ),
                          const SizedBox(height: 16),
                          Text("No Proxy Verifications Pending", style: AX.display(fontSize: 16)),
                          const SizedBox(height: 6),
                          Text("Feature-phone artisans referred by registered members will show up here for voice verification.", style: AX.body(fontSize: 12), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: proxyWorkers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final pw = proxyWorkers[index];
                    return _buildProxyCard(context, pw, workerService);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProxyCard(BuildContext context, Worker pw, WorkerService workerService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AX.glassBox(radius: 18, borderColor: AX.violet.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AX.violetDark,
                    ),
                    child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pw.name.isNotEmpty ? pw.name : "Proxy Artisan #${pw.id.substring(0, 6).toUpperCase()}", style: AX.display(fontSize: 16)),
                      Text("Calling Phone: ${pw.phoneForCalling ?? '+91 (Co-op Proxy Phone)'}", style: AX.mono(fontSize: 12, color: AX.emeraldLight)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AX.violet.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text("PHONE VERIFICATION QUEUE", style: AX.mono(fontSize: 10, color: AX.violetLight)),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),

          Text(
            "Primary Skill: ${pw.skills.isNotEmpty ? pw.skills.join(', ') : 'General Maintenance'} • ${pw.experienceYears} Years Experience",
            style: AX.body(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.call_rounded, color: AX.cyan, size: 18),
                  label: const Text("Initiate Verification Call", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AX.cyan, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Calling ${pw.phoneForCalling ?? pw.name}... Connecting through cooperative voice bridge."),
                        backgroundColor: AX.cyanDark,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  label: const Text("Approve & Activate Worker", style: TextStyle(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AX.emeraldDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await workerService.approveWorker(pw.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Proxy artisan successfully verified and activated for Call-to-Book!"),
                          backgroundColor: AX.emerald,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
