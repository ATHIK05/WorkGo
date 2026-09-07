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
                  Text('admin_proxy_title'.trSafe("Proxy Artisan Voice Onboarding Queue"), style: AX.display(fontSize: 20)),
                  const SizedBox(height: 2),
                  Text('admin_proxy_subtitle'.trSafe("Verify non-smartphone artisans referred by cooperative members via telephone bridge"), style: AX.body(fontSize: 12)),
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
                    const Icon(Icons.phone_in_talk_rounded, color: AX.emeraldDark, size: 16),
                    const SizedBox(width: 6),
                    Text('admin_proxy_bridge_badge'.trSafe("CALL-TO-BOOK BRIDGE"), style: AX.mono(fontSize: 11, color: AX.emeraldDark)),
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
                  return const Center(child: CircularProgressIndicator(color: AX.emerald));
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
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFF3D6)),
                            child: const Icon(Icons.phone_in_talk_rounded, color: AX.emeraldDark, size: 36),
                          ),
                          const SizedBox(height: 16),
                          Text('admin_proxy_empty_title'.trSafe("No Proxy Verifications Pending"), style: AX.display(fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('admin_proxy_empty_desc'.trSafe("Feature-phone artisans referred by registered members will show up here for voice verification."), style: AX.body(fontSize: 12), textAlign: TextAlign.center),
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
    final localizedSkills = pw.skills.isNotEmpty
        ? pw.skills.map((s) => s.toLocalizedTradeClean()).join(', ')
        : 'artisan_partner'.trSafe("General Maintenance");

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AX.glassBox(radius: 18),
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
                      color: Color(0xFFFFF3D6),
                    ),
                    child: const Icon(Icons.phone_in_talk_rounded, color: AX.emeraldDark, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pw.name.isNotEmpty ? pw.name : "Proxy Artisan #${pw.id.substring(0, 6).toUpperCase()}", style: AX.display(fontSize: 16)),
                      Text(
                        'admin_proxy_calling_phone'.trSafe("Calling Phone: ${pw.phoneForCalling ?? '+91 (Co-op Proxy Phone)'}", [pw.phoneForCalling ?? '+91 (Co-op Proxy Phone)']),
                        style: const TextStyle(fontFamily: "SpaceGrotesk", fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                child: Text('admin_proxy_phone_queue_badge'.trSafe("PHONE VERIFICATION QUEUE"), style: const TextStyle(fontFamily: "SpaceGrotesk", fontSize: 10, color: Color(0xFF92400E), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(color: AX.divider, height: 24),

          Text(
            'admin_proxy_primary_skill'.trSafe("Primary Skill: $localizedSkills • ${pw.experienceYears} Years Experience", [localizedSkills, '${pw.experienceYears}']),
            style: AX.body(fontSize: 12, color: AX.textSecondary),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.call_rounded, color: Color(0xFF1D4ED8), size: 18),
                  label: Text('admin_proxy_initiate_call'.trSafe("Initiate Verification Call"), style: const TextStyle(color: AX.textPrimary, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AX.divider, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("admin_calling_connecting".trSafe("Calling {}... Connecting through cooperative voice bridge.", [pw.phoneForCalling ?? pw.name])),
                        backgroundColor: const Color(0xFF1D4ED8),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF1A1A1A), size: 18),
                  label: Text('admin_proxy_approve_worker'.trSafe("Approve & Activate Worker"), style: const TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AX.emerald,
                    foregroundColor: const Color(0xFF1A1A1A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    await workerService.approveWorker(pw.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('admin_proxy_approved_snack'.trSafe("Proxy artisan successfully verified and activated for Call-to-Book!")),
                          backgroundColor: const Color(0xFF10B981),
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
