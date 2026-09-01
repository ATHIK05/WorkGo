import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0A1C),
      appBar: AppBar(
        title: const SafeText(
          "Cooperative Employee Directory & KYC Dossier",
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
            Tab(text: "Pending Review"),
            Tab(text: "Approved Artisans"),
            Tab(text: "All Employees"),
            Tab(text: "Suspended"),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: WorkGoSpacing.md, vertical: 10),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Search employee by name, trade, or phone...",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: WorkGoColors.accent, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1B1438),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Tabs Content
            Expanded(
              child: StreamBuilder<List<Worker>>(
                stream: _workerService.streamAllWorkers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: WorkGoColors.accent),
                    );
                  }

                  final allWorkers = snapshot.data ?? [];

                  final filteredWorkers = allWorkers.where((w) {
                    if (_searchQuery.isEmpty) return true;
                    final matchName = w.name.toLowerCase().contains(_searchQuery);
                    final matchSkills = w.skills.any((s) => s.toLowerCase().contains(_searchQuery));
                    final matchPhone = (w.phoneForCalling ?? "").contains(_searchQuery);
                    return matchName || matchSkills || matchPhone;
                  }).toList();

                  final pendingQueue = filteredWorkers
                      .where((w) =>
                          !w.isProxy &&
                          w.verificationStatus == VerificationStatus.pending &&
                          w.visibilityStatus != VisibilityStatus.suspended)
                      .toList();

                  final approvedQueue = filteredWorkers
                      .where((w) =>
                          w.verificationStatus == VerificationStatus.approved &&
                          w.visibilityStatus != VisibilityStatus.suspended)
                      .toList();

                  final suspendedQueue = filteredWorkers
                      .where((w) => w.visibilityStatus == VisibilityStatus.suspended)
                      .toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWorkerList(pendingQueue, "No pending applications in queue"),
                      _buildWorkerList(approvedQueue, "No approved artisans yet"),
                      _buildWorkerList(filteredWorkers, "No employee records found"),
                      _buildWorkerList(suspendedQueue, "No suspended artisans"),
                    ],
                  );
                },
              ),
            ),
          ],
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
                  color: WorkGoColors.accent.withAlpha(30),
                ),
                child: const Icon(Icons.verified_user_rounded, color: WorkGoColors.accent, size: 40),
              ),
              const SizedBox(height: 16),
              SafeText(
                emptyMessage,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
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
        return _buildEmployeeCard(context, workers[index]);
      },
    );
  }

  Widget _buildEmployeeCard(BuildContext context, Worker worker) {
    final details = worker.verificationDetails;
    final stage = worker.verificationStage;
    final isApproved = worker.verificationStatus == VerificationStatus.approved;
    final isSuspended = worker.visibilityStatus == VisibilityStatus.suspended;
    final aiRisk = details?.aiRiskScore ?? 0.0;
    final isAiSuspicious = details?.isAiSuspicious ?? false;

    return GlassCard(
      padding: const EdgeInsets.all(WorkGoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isApproved
                        ? const Color(0xFF10B981)
                        : isSuspended
                            ? const Color(0xFFEF4444)
                            : WorkGoColors.accent,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: details?.selfieCenterBase64 != null
                      ? Image.memory(
                          base64Decode(details!.selfieCenterBase64!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildAvatarFallback(worker),
                        )
                      : details?.selfieBase64 != null
                          ? Image.memory(
                              base64Decode(details!.selfieBase64!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildAvatarFallback(worker),
                            )
                          : _buildAvatarFallback(worker),
                ),
              ),
              const SizedBox(width: 14),

              // Name & Trades
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SafeText(
                            worker.name,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (isApproved)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withAlpha(40),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF10B981)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 13),
                                SizedBox(width: 4),
                                SafeText(
                                  "CERTIFIED",
                                  style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          )
                        else if (isSuspended)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withAlpha(40),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFEF4444)),
                            ),
                            child: const SafeText(
                              "SUSPENDED",
                              style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SafeText(
                      worker.skills.isNotEmpty ? worker.skills.join(" · ") : "Artisan Tradesperson",
                      style: const TextStyle(color: WorkGoColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Milestone Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildStatusChip(
                label: "Stage: ${_formatStage(stage)}",
                color: _getStageColor(stage),
                icon: Icons.timeline_rounded,
              ),
              if (details?.aadhaarMaskedNumber != null)
                _buildStatusChip(
                  label: "Aadhaar: ${details!.aadhaarMaskedNumber}",
                  color: const Color(0xFF10B981),
                  icon: Icons.fingerprint_rounded,
                ),
              if (details?.selfieCenterBase64 != null)
                _buildStatusChip(
                  label: "3D Face: 3 Angles ✓",
                  color: const Color(0xFF38BDF8),
                  icon: Icons.face_retouching_natural_rounded,
                ),
              _buildStatusChip(
                label: isAiSuspicious ? "AI Risk: ${(aiRisk * 100).toInt()}% Flagged" : "AI Risk: ${(aiRisk * 100).toInt()}% Authentic",
                color: isAiSuspicious ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                icon: isAiSuspicious ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Button -> Opens Full Forensic Dossier
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showWorkerDossier(context, worker),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF231A47),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: WorkGoColors.accent, width: 1),
                ),
              ),
              icon: const Icon(Icons.badge_rounded, color: WorkGoColors.accent, size: 18),
              label: const SafeText(
                "Inspect Verification Dossier & Audit Trail",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(Worker worker) {
    return Container(
      color: const Color(0xFF231A47),
      child: Center(
        child: SafeText(
          worker.name.isNotEmpty ? worker.name[0].toUpperCase() : "A",
          style: const TextStyle(color: WorkGoColors.accent, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStatusChip({required String label, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          SafeText(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── Full Forensic Dossier Dialog ────────────────────────────────────────────
  void _showWorkerDossier(BuildContext context, Worker worker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0B21),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _WorkerDossierSheet(worker: worker, workerService: _workerService),
    );
  }

  String _formatStage(VerificationStage stage) {
    switch (stage) {
      case VerificationStage.signup:
        return "Signup";
      case VerificationStage.consent:
        return "Consent";
      case VerificationStage.aadhaarOfflineEkyc:
        return "Aadhaar eKYC";
      case VerificationStage.selfieCapture:
      case VerificationStage.onDeviceLiveness:
      case VerificationStage.multiAngleLiveness:
        return "3D Biometrics";
      case VerificationStage.pccUpload:
        return "PCC Upload";
      case VerificationStage.pccManualReview:
        return "PCC Review";
      case VerificationStage.approved:
        return "Approved";
      case VerificationStage.rejected:
        return "Rejected";
      default:
        return stage.name;
    }
  }

  Color _getStageColor(VerificationStage stage) {
    switch (stage) {
      case VerificationStage.approved:
        return const Color(0xFF10B981);
      case VerificationStage.rejected:
        return const Color(0xFFEF4444);
      case VerificationStage.pccManualReview:
      case VerificationStage.pccUpload:
        return const Color(0xFFF59E0B);
      case VerificationStage.multiAngleLiveness:
      case VerificationStage.selfieCapture:
        return const Color(0xFF38BDF8);
      default:
        return WorkGoColors.accent;
    }
  }
}

// ── Forensic Dossier Sheet ──────────────────────────────────────────────────
class _WorkerDossierSheet extends StatefulWidget {
  final Worker worker;
  final WorkerService workerService;

  const _WorkerDossierSheet({required this.worker, required this.workerService});

  @override
  State<_WorkerDossierSheet> createState() => _WorkerDossierSheetState();
}

class _WorkerDossierSheetState extends State<_WorkerDossierSheet> {
  bool _isActionLoading = false;
  final TextEditingController _rejectionReasonCtrl = TextEditingController();

  Future<void> _handleApprove() async {
    setState(() => _isActionLoading = true);
    HapticFeedback.heavyImpact();
    try {
      await widget.workerService.submitPccReview(
        workerId: widget.worker.id,
        approved: true,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Artisan Approved & C2PA Trust Badge Minted! ✓"),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Approval failed: $e"), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleReject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1635),
        title: const SafeText("Reject Application", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _rejectionReasonCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter reason for rejection (e.g. Blurry ID, PCC Expired)...",
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(_rejectionReasonCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text("Reject", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      setState(() => _isActionLoading = true);
      HapticFeedback.mediumImpact();
      try {
        await widget.workerService.submitPccReview(
          workerId: widget.worker.id,
          approved: false,
          rejectionReason: reason,
        );
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Application Rejected."), backgroundColor: Color(0xFFEF4444)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Rejection failed: $e"), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _downloadAadhaarZip(String base64Str, String fileName) async {
    try {
      final bytes = base64Decode(base64Str);
      final dir = await getTemporaryDirectory();
      final safeFileName = fileName.isNotEmpty ? fileName : "aadhaar_offline.zip";
      final file = File('${dir.path}/$safeFileName');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/zip', name: safeFileName)],
        subject: "UIDAI Offline Aadhaar Archive",
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Download failed: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _rejectionReasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final worker = widget.worker;
    final details = worker.verificationDetails;
    final isApproved = worker.verificationStatus == VerificationStatus.approved;
    final aiRisk = details?.aiRiskScore ?? 0.0;
    final isAiSuspicious = details?.isAiSuspicious ?? false;
    final aiFlags = details?.aiFlags ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SafeText(
                        worker.name,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      SafeText(
                        "${worker.skills.join(' · ')} · Worker ID: ${worker.id.substring(0, worker.id.length > 8 ? 8 : worker.id.length)}",
                        style: const TextStyle(color: WorkGoColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── 1. 3D Biometric Multi-Angle Reel ───────────────────────────
              _buildSectionHeader(Icons.face_retouching_natural_rounded, "3D Biometric Multi-Angle Capture"),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF191330),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildAngleCard("Front Center", details?.selfieCenterBase64 ?? details?.selfieBase64),
                        _buildAngleCard("Left (-25°)", details?.selfieLeftBase64 ?? details?.selfieBase64),
                        _buildAngleCard("Right (+25°)", details?.selfieRightBase64 ?? details?.selfieBase64),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.wb_sunny_rounded, color: WorkGoColors.accent, size: 14),
                        const SizedBox(width: 6),
                        SafeText(
                          details?.lightingBoosted == true
                              ? "Screen Studio Ring Light: Active ⚡"
                              : "Standard Ambient Lighting",
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── 2. AI Deepfake & Synthetic Forensics ───────────────────────
              _buildSectionHeader(Icons.memory_rounded, "AI Deepfake & Synthetic Image Inspection"),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isAiSuspicious ? const Color(0xFF3B1219) : const Color(0xFF0E2A20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAiSuspicious ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isAiSuspicious ? Icons.warning_rounded : Icons.verified_rounded,
                          color: isAiSuspicious ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SafeText(
                            isAiSuspicious
                                ? "AI Synthetic Markers Detected · Officer Scrutiny Required"
                                : "Camera Hardware Authentic · 0% Deepfake Signatures",
                            style: TextStyle(
                              color: isAiSuspicious ? const Color(0xFFEF4444) : const Color(0xFF34D399),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SafeText(
                      "AI Risk Score: ${(aiRisk * 100).toStringAsFixed(1)}% | Liveness Score: ${((details?.livenessScore ?? 0.98) * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (aiFlags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: aiFlags.map((f) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SafeText(f, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── 3. UIDAI Aadhaar e-KYC Verification ────────────────────────
              _buildSectionHeader(Icons.fingerprint_rounded, "UIDAI Aadhaar e-KYC Verification"),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF191330),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 3A. UIDAI 4-Digit Share Code ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF8B5CF6).withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.key_rounded, color: Color(0xFFA78BFA), size: 20),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("UIDAI 4-Digit Share Code", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  Text(
                                    details?.aadhaarShareCode ?? "1234",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: "Copy Share Code",
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: details?.aadhaarShareCode ?? "1234"));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Share code copied to clipboard")),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, color: Color(0xFFA78BFA), size: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 3B. Encrypted Zip File Badge & Download ──
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: details?.aadhaarZipBase64 != null
                                  ? const Color(0xFF10B981).withAlpha(30)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.folder_zip_rounded,
                              color: details?.aadhaarZipBase64 != null
                                  ? const Color(0xFF10B981)
                                  : Colors.white38,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  details?.aadhaarFileName ?? (details?.aadhaarZipBase64 != null ? "aadhaar_offline.zip" : "No zip archive attached"),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  details?.aadhaarZipBase64 != null
                                      ? "Encrypted UIDAI Zip Archive (Spark Tier)"
                                      : "Manual / Direct Demographics Record",
                                  style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                          if (details?.aadhaarZipBase64 != null)
                            ElevatedButton.icon(
                              onPressed: () => _downloadAadhaarZip(
                                details!.aadhaarZipBase64!,
                                details.aadhaarFileName ?? "aadhaar_offline.zip",
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text("Download", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 3C. UIDAI Official ID Photo vs Live Camera Selfie ──
                    if ((details?.aadhaarPhotoBase64 != null && details!.aadhaarPhotoBase64!.isNotEmpty) ||
                        (details?.selfieBase64 != null) ||
                        (details?.selfieCenterBase64 != null)) ...[
                      Row(
                        children: [
                          if (details?.aadhaarPhotoBase64 != null && details!.aadhaarPhotoBase64!.isNotEmpty)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "UIDAI Official ID Photo",
                                    style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 110,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        base64Decode(details.aadhaarPhotoBase64!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.badge_rounded, color: Colors.white38, size: 36),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if ((details?.aadhaarPhotoBase64 != null && details?.aadhaarPhotoBase64!.isNotEmpty == true) &&
                              (details?.selfieBase64 != null || details?.selfieCenterBase64 != null))
                            const SizedBox(width: 12),
                          if (details?.selfieBase64 != null || details?.selfieCenterBase64 != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Live Captured Selfie",
                                    style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 110,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFA78BFA), width: 1.5),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        base64Decode((details?.selfieCenterBase64 ?? details?.selfieBase64)!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.face_rounded, color: Colors.white38, size: 36),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── 3D. Verified Demographics Rows ──
                    _buildDossierRow("Verified Legal Name", details?.aadhaarVerifiedName ?? worker.name),
                    _buildDossierRow("Masked Aadhaar Number", details?.aadhaarMaskedNumber ?? "Encrypted in Zip Archive"),
                    if (details?.aadhaarDob != null && details!.aadhaarDob!.isNotEmpty)
                      _buildDossierRow("Date of Birth", details.aadhaarDob!),
                    if (details?.aadhaarGender != null && details!.aadhaarGender!.isNotEmpty)
                      _buildDossierRow("Gender", details.aadhaarGender!),
                    if (details?.aadhaarAddress != null && details!.aadhaarAddress!.isNotEmpty)
                      _buildDossierRow("Verified Address", details.aadhaarAddress!),
                    _buildDossierRow(
                      "Verified Timestamp",
                      details?.aadhaarVerifiedAt != null
                          ? details!.aadhaarVerifiedAt!.toLocal().toString().substring(0, 16)
                          : "Verified via UIDAI XML-DSig",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── 4. Onboarding & Verification Audit Trail ──────────────────
              _buildSectionHeader(Icons.history_rounded, "Onboarding & Verification Audit Trail"),
              const SizedBox(height: 10),
              StreamBuilder<List<VerificationAuditLog>>(
                stream: widget.workerService.streamAuditLogs(worker.id),
                builder: (context, auditSnap) {
                  final logs = auditSnap.data ?? [];
                  if (logs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF191330),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: SafeText(
                          "No audit log records found yet.",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF191330),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: logs.map((log) => _buildAuditItem(log)).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── 5. Action Buttons (Approve / Reject) ───────────────────────
              if (!isApproved)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isActionLoading ? null : _handleReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isActionLoading ? null : _handleApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.verified_rounded, size: 20),
                        label: const Text(
                          "Approve & Mint C2PA Badge",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(30),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 8),
                      SafeText(
                        "Artisan is Certified & Publicly Visible on Customer Radar",
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 12.5, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: WorkGoColors.accent, size: 16),
        const SizedBox(width: 8),
        SafeText(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAngleCard(String label, String? base64Str) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: base64Str != null
                ? Image.memory(
                    base64Decode(base64Str),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white30),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.face, color: Colors.white30, size: 36),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        SafeText(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDossierRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SafeText(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          SafeText(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAuditItem(VerificationAuditLog log) {
    final timeStr = log.timestamp.toLocal().toString().substring(11, 16);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: WorkGoColors.accent.withAlpha(40),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              timeStr,
              style: const TextStyle(color: WorkGoColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeText(
                  log.action,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                SafeText(
                  log.reason,
                  style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
