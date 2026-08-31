import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';

class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen>
    with SingleTickerProviderStateMixin {
  final WorkerService _workerService = WorkerService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0A1C),
      appBar: AppBar(
        title: const SafeText(
          "Cooperative KYC & Governance Console",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: WorkGoColors.accent,
          indicatorWeight: 3,
          labelColor: WorkGoColors.accent,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "All Queue"),
            Tab(text: "Video KYC"),
            Tab(text: "PCC Review"),
            Tab(text: "Suspended"),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Worker>>(
          stream: _workerService.streamAllWorkers(),
          builder: (context, snapshot) {
            final allWorkers = snapshot.data ?? [];

            final pendingAll = allWorkers
                .where((w) => !w.isProxy && w.verificationStatus == VerificationStatus.pending)
                .toList();

            final videoKycQueue = allWorkers
                .where((w) => w.verificationStage == VerificationStage.liveVideoVerification)
                .toList();

            final pccQueue = allWorkers
                .where((w) =>
                    w.verificationStage == VerificationStage.pccManualReview ||
                    w.verificationStage == VerificationStage.pccUpload)
                .toList();

            final suspendedQueue = allWorkers
                .where((w) => w.visibilityStatus == VisibilityStatus.suspended)
                .toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildWorkerList(pendingAll, "No pending applications in queue"),
                _buildWorkerList(videoKycQueue, "No video KYC calls scheduled"),
                _buildWorkerList(pccQueue, "No Police Clearance Certificates to review"),
                _buildWorkerList(suspendedQueue, "No suspended artisans"),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWorkerList(List<Worker> workers, String emptyMessage) {
    if (workers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(WorkGoSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WorkGoColors.accent.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.verified_user_rounded, color: WorkGoColors.accent, size: 40),
              ),
              const SizedBox(height: 16),
              SafeText(
                emptyMessage,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(WorkGoSpacing.md),
      itemCount: workers.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _buildApprovalCard(context, workers[index]);
      },
    );
  }

  Widget _buildApprovalCard(BuildContext context, Worker worker) {
    final details = worker.verificationDetails;
    final stage = worker.verificationStage;
    final isSuspended = worker.visibilityStatus == VisibilityStatus.suspended;

    return GlassCard(
      padding: const EdgeInsets.all(WorkGoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSuspended
                      ? const Color(0xFFF43F5E).withValues(alpha: 0.15)
                      : WorkGoColors.accent.withValues(alpha: 0.15),
                ),
                child: Icon(
                  isSuspended ? Icons.warning_amber_rounded : Icons.person,
                  color: isSuspended ? const Color(0xFFF43F5E) : WorkGoColors.accent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      worker.name.isNotEmpty ? worker.name : "Co-op Artisan Candidate",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    SafeText(
                      "Skills: ${worker.skills.join(', ')} • ${worker.experienceYears} yrs exp",
                      style: TextStyle(color: WorkGoColors.textSecondary.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
              WorkGoBadge(
                label: isSuspended
                    ? "SUSPENDED"
                    : _formatStageBadge(stage),
                type: isSuspended ? BadgeType.error : BadgeType.warning,
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),

          // Stage & Identity Highlights
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  "Aadhaar eKYC",
                  details?.aadhaarMaskedNumber ?? "XXXXXXXX9842",
                  Icons.fingerprint_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip(
                  "Liveness Score",
                  "${((details?.livenessScore ?? 0.98) * 100).toStringAsFixed(1)}%",
                  Icons.face_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  "Video KYC Slot",
                  details?.videoCallScheduledAt != null
                      ? details!.videoCallScheduledAt!.toLocal().toString().substring(5, 16)
                      : "Pending Slot",
                  Icons.video_call_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip(
                  "PCC Clearance",
                  details?.pccDocumentId != null ? "Uploaded (Encrypted)" : "Awaiting File",
                  Icons.shield_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons Bar
          Row(
            children: [
              // Audit History Button
              IconButton(
                icon: const Icon(Icons.history_edu_rounded, color: Color(0xFF00E5FF)),
                tooltip: "Inspect Audit Trail",
                onPressed: () => _openAuditTrailModal(context, worker),
              ),
              const SizedBox(width: 4),

              // Live Video Verification Action (if in Video KYC stage)
              if (stage == VerificationStage.liveVideoVerification) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openLiveVideoCallDialog(context, worker),
                    icon: const Icon(Icons.video_camera_front_rounded, size: 16),
                    label: const Text("Launch Video KYC"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7928CA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // PCC Review Action (if in PCC review stage)
              if (stage == VerificationStage.pccManualReview || stage == VerificationStage.pccUpload) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openPccReviewDialog(context, worker),
                    icon: const Icon(Icons.verified_rounded, size: 16),
                    label: const Text("Review PCC"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Suspension Toggle Button
              if (!isSuspended) ...[
                IconButton(
                  icon: const Icon(Icons.block_rounded, color: Color(0xFFF43F5E)),
                  tooltip: "Suspend Artisan",
                  onPressed: () => _handleSuspendWorker(context, worker),
                ),
              ] else ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleReinstateWorker(context, worker),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text("Reinstate Artisan"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatStageBadge(VerificationStage stage) {
    switch (stage) {
      case VerificationStage.signup:
        return "CONSENT PENDING";
      case VerificationStage.aadhaarOfflineEkyc:
        return "AADHAAR eKYC";
      case VerificationStage.selfieCapture:
      case VerificationStage.onDeviceLiveness:
        return "LIVENESS GATE";
      case VerificationStage.liveVideoVerification:
        return "VIDEO KYC CALL";
      case VerificationStage.pccUpload:
      case VerificationStage.pccManualReview:
        return "PCC REVIEW";
      case VerificationStage.approved:
        return "APPROVED";
      case VerificationStage.rejected:
        return "REJECTED";
    }
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: WorkGoColors.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeText(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                SafeText(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Live Video Verification Room Modal ──────────────────────────────────────

  void _openLiveVideoCallDialog(BuildContext context, Worker worker) {
    final phrase = worker.verificationDetails?.videoCallPhrase ?? "VIOLET-892-SUN";
    final selfieBase64 = worker.verificationDetails?.selfieBase64;
    Uint8List? selfieBytes;
    if (selfieBase64 != null && selfieBase64.isNotEmpty) {
      try {
        selfieBytes = base64Decode(selfieBase64);
      } catch (_) {}
    }

    bool photoMatch = true;
    bool phraseSpoken = true;
    bool toolsVerified = true;
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return StreamBuilder<VideoKycBooking?>(
            stream: _workerService.streamActiveVideoKycBooking(worker.id),
            builder: (context, snapshot) {
              final booking = snapshot.data;
              final isWorkerInLobby = booking?.workerStatus == "in_lobby" || booking?.status == VideoKycStatus.inLobby;
              final roomUrl = booking?.roomUrl.isNotEmpty == true
                  ? booking!.roomUrl
                  : "https://meet.jit.si/workgo_kyc_${worker.id}#config.prejoinPageEnabled=false";

              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0B0818),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(top: BorderSide(color: Color(0xFF7928CA), width: 1.5)),
                ),
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Icon(Icons.video_call_rounded, color: Color(0xFFC084FC), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Live Video KYC Verification Room",
                                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  "Artisan: ${worker.name} • Skills: ${worker.skills.join(', ')}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Worker Profile & Live Likeness Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF130E2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white10,
                                border: Border.all(color: const Color(0xFF10B981), width: 2),
                              ),
                              child: ClipOval(
                                child: selfieBytes != null
                                    ? Image.memory(selfieBytes, fit: BoxFit.cover)
                                    : const Icon(Icons.person_rounded, color: Colors.white54, size: 36),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        worker.name,
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text("SELFIE AUTH", style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "Aadhaar: ${worker.verificationDetails?.aadhaarMaskedNumber ?? 'Verified'}",
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Liveness Score: ${((worker.verificationDetails?.livenessScore ?? 0.99) * 100).toStringAsFixed(1)}%",
                                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                                  ),
                                  if (worker.verificationDetails?.isAiSuspicious == true || (worker.verificationDetails?.aiRiskScore ?? 0) > 0.3) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFF43F5E)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF43F5E), size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            "AI SYNTHETIC RISK: ${((worker.verificationDetails?.aiRiskScore ?? 0.8) * 100).toInt()}%",
                                            style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 9.5, fontWeight: FontWeight.w900),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Room & Presence Status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isWorkerInLobby
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isWorkerInLobby ? const Color(0xFF10B981) : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isWorkerInLobby ? Icons.fiber_manual_record : Icons.schedule_rounded,
                              color: isWorkerInLobby ? const Color(0xFF10B981) : Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isWorkerInLobby
                                    ? "Artisan is ACTIVE IN LOBBY waiting for your call!"
                                    : "Waiting for artisan to enter lobby...",
                                style: TextStyle(
                                  color: isWorkerInLobby ? const Color(0xFF34D399) : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Join Call Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _workerService.updateLobbyStatus(
                            workerId: worker.id,
                            bookingId: booking?.id,
                            status: "in_call",
                            actorType: "admin",
                          );
                          final uri = Uri.parse(roomUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.videocam_rounded, size: 20),
                        label: const Text("Launch Video Meeting Room", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7928CA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Challenge Phrase Prompt
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: WorkGoColors.accent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.record_voice_over_rounded, color: WorkGoColors.accent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("CHALLENGE PHRASE TO VERIFY ON CALL", style: TextStyle(color: WorkGoColors.accent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(phrase, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Officer Checklist
                      CheckboxListTile(
                        title: const Text("Physical ID Matches Selfie & Aadhaar", style: TextStyle(color: Colors.white, fontSize: 12)),
                        value: photoMatch,
                        activeColor: const Color(0xFF10B981),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (v) => setModalState(() => photoMatch = v ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text("Artisan Spoke Challenge Phrase Correctly", style: TextStyle(color: Colors.white, fontSize: 12)),
                        value: phraseSpoken,
                        activeColor: const Color(0xFF10B981),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (v) => setModalState(() => phraseSpoken = v ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text("Tools / Workshop Likeness Verified", style: TextStyle(color: Colors.white, fontSize: 12)),
                        value: toolsVerified,
                        activeColor: const Color(0xFF10B981),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (v) => setModalState(() => toolsVerified = v ?? false),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _workerService.submitVideoKycReview(
                                  workerId: worker.id,
                                  bookingId: booking?.id ?? "vcall_${worker.id}",
                                  passed: false,
                                  challengePhrase: phrase,
                                  checklist: {"photoMatch": photoMatch, "phraseSpoken": phraseSpoken, "toolsVerified": toolsVerified},
                                  notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : "Verification mismatch or challenge failed",
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF43F5E),
                                side: const BorderSide(color: Color(0xFFF43F5E)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Reject & Flag"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: (photoMatch && phraseSpoken && toolsVerified)
                                  ? () async {
                                      Navigator.of(context).pop();
                                      await _workerService.submitVideoKycReview(
                                        workerId: worker.id,
                                        bookingId: booking?.id ?? "vcall_${worker.id}",
                                        passed: true,
                                        challengePhrase: phrase,
                                        checklist: {"photoMatch": true, "phraseSpoken": true, "toolsVerified": true},
                                        notes: "Passed live video examination",
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Video KYC approved! Worker advanced to PCC upload."),
                                            backgroundColor: Color(0xFF047857),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Approve Video KYC", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── PCC Review Drawer ───────────────────────────────────────────────────────

  void _openPccReviewDialog(BuildContext context, Worker worker) {
    final docId = worker.verificationDetails?.pccDocumentId ?? "pcc_doc_${worker.id}";
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B0818),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF047857), width: 1.5)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Police Clearance Certificate Inspection",
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          "Artisan: ${worker.name} • Trades: ${worker.skills.join(', ')}",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Decrypted Document Viewer Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF130E2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("AUTHENTICATED RECORD", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold)),
                        Icon(Icons.verified_user_rounded, color: Color(0xFF00E5FF), size: 16),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text("Document ID: $docId", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text("Status: Submitted by Artisan for Verification", style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: notesCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: "Officer Notes / Verification Remarks",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF130E2A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _workerService.submitPccReview(
                          workerId: worker.id,
                          approved: false,
                          rejectionReason: notesCtrl.text.trim().isNotEmpty
                              ? notesCtrl.text.trim()
                              : "PCC signature mismatch or unclear scan",
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF43F5E),
                        side: const BorderSide(color: Color(0xFFF43F5E)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Reject Document"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _workerService.submitPccReview(
                          workerId: worker.id,
                          approved: true,
                          notes: notesCtrl.text.trim(),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Worker approved! Public visibility active on customer radar."),
                              backgroundColor: Color(0xFF047857),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Approve & Publish Artisan", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Audit Trail Modal ──────────────────────────────────────────────────────

  void _openAuditTrailModal(BuildContext context, Worker worker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF0B0818),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF00E5FF), width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.history_edu_rounded, color: Color(0xFF00E5FF), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Immutable Audit Trail",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Tamper-proof record for Worker UID: ${worker.id}",
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: StreamBuilder<List<VerificationAuditLog>>(
                stream: _workerService.streamAuditLogs(worker.id),
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return const Center(
                      child: Text("No audit log records found.", style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (ctx, i) => const Divider(color: Colors.white12, height: 16),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  log.action,
                                  style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                log.timestamp.toLocal().toString().split(".")[0],
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(log.reason, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text("Actor: ${log.actorId} (${log.actorRole})", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Suspension & Reinstatement Handlers ─────────────────────────────────────

  Future<void> _handleSuspendWorker(BuildContext context, Worker worker) async {
    HapticFeedback.heavyImpact();
    await _workerService.reportAndSuspendWorker(
      workerId: worker.id,
      reporterId: "admin_console_governance",
      reason: "Administrative suspension pending governance audit",
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Artisan ${worker.name} suspended and unlisted from customer radar."),
          backgroundColor: const Color(0xFFF43F5E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleReinstateWorker(BuildContext context, Worker worker) async {
    HapticFeedback.mediumImpact();
    await _workerService.submitPccReview(workerId: worker.id, approved: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Artisan ${worker.name} reinstated to public listing."),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
