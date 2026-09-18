import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:workgo_core/workgo_core.dart";
import "../admin_theme.dart";

/// Comprehensive Worker Welfare, Micro-Insurance & Claim Settlement Cockpit (SIH 26089).
/// Features:
/// 1. Tab 1: "Claims Review & Settlement" — Master-Detail claim queue, document decryption,
///    corroboration checklist with >= 20 char notes, live scoring, and immutable decision audit.
/// 2. Tab 2: "Insurance Corpus & Artisan Roster" — Accumulated welfare pool & worker policy enrollments.
class WorkerWelfareManagementScreen extends StatefulWidget {
  const WorkerWelfareManagementScreen({super.key});

  @override
  State<WorkerWelfareManagementScreen> createState() => _WorkerWelfareManagementScreenState();
}

class _WorkerWelfareManagementScreenState extends State<WorkerWelfareManagementScreen> {
  final WorkerService _workerService = WorkerService();
  final BookingService _bookingService = BookingService();
  final WelfareService _welfareService = WelfareService();

  // Primary top tab: 0 = Claims Review & Settlement, 1 = Corpus & Roster
  int _activeTopTab = 0;

  // Claims Filter State
  String _claimStatusFilter = "all"; // "all" | "pending_review" | "approved" | "rejected"
  String _claimSearchQuery = "";
  WelfareClaim? _selectedClaim;

  // Claim Detail State
  WelfareClaimDetailResponse? _claimDetailResponse;
  bool _isLoadingDetail = false;

  // Verification Checklist Editing State
  bool _editDoctorCall = false;
  final TextEditingController _doctorCallNoteCtrl = TextEditingController();

  bool _editCustomerCall = false;
  final TextEditingController _customerCallNoteCtrl = TextEditingController();

  bool _editSos = false;
  final TextEditingController _sosNoteCtrl = TextEditingController();

  bool _editPhotoOverride = false;
  final TextEditingController _photoOverrideNoteCtrl = TextEditingController();

  bool _isSavingVerification = false;
  String? _verificationError;

  // Corpus Roster Search
  String _rosterSearchQuery = "";

  @override
  void dispose() {
    _doctorCallNoteCtrl.dispose();
    _customerCallNoteCtrl.dispose();
    _sosNoteCtrl.dispose();
    _photoOverrideNoteCtrl.dispose();
    super.dispose();
  }

  void _onSelectClaim(WelfareClaim claim) {
    setState(() {
      _selectedClaim = claim;
      _isLoadingDetail = true;
      _verificationError = null;

      // Populate initial values from claim
      _editDoctorCall = claim.doctorCallConfirmed;
      _doctorCallNoteCtrl.text = claim.doctorCallNote ?? "";

      _editCustomerCall = claim.customerCallConfirmed;
      _customerCallNoteCtrl.text = claim.customerCallNote ?? "";

      _editSos = claim.sosCorroborated;
      _sosNoteCtrl.text = claim.sosNote ?? "";

      _editPhotoOverride = claim.photoOverride;
      _photoOverrideNoteCtrl.text = claim.photoOverrideNote ?? "";
    });

    _loadClaimDetail(claim.id);
  }

  Future<void> _loadClaimDetail(String claimId) async {
    try {
      final res = await _welfareService.fetchClaimDetail(claimId);
      if (mounted && _selectedClaim?.id == claimId) {
        setState(() {
          _claimDetailResponse = res;
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      if (mounted && _selectedClaim?.id == claimId) {
        setState(() {
          _isLoadingDetail = false;
        });
      }
    }
  }

  Future<void> _saveVerifications() async {
    if (_selectedClaim == null) return;

    // Validate >= 20 characters if checked
    if (_editDoctorCall && _doctorCallNoteCtrl.text.trim().length < 20) {
      setState(() => _verificationError = "Doctor call confirmation requires a note of at least 20 characters.");
      return;
    }
    if (_editCustomerCall && _customerCallNoteCtrl.text.trim().length < 20) {
      setState(() => _verificationError = "Customer call confirmation requires a note of at least 20 characters.");
      return;
    }
    if (_editSos && _sosNoteCtrl.text.trim().length < 20) {
      setState(() => _verificationError = "SOS beacon confirmation requires a note of at least 20 characters.");
      return;
    }
    if (_editPhotoOverride && _photoOverrideNoteCtrl.text.trim().length < 20) {
      setState(() => _verificationError = "Photo override requires a justification note of at least 20 characters.");
      return;
    }

    setState(() {
      _isSavingVerification = true;
      _verificationError = null;
    });

    try {
      await _welfareService.verifyClaim(
        claimId: _selectedClaim!.id,
        doctorCallConfirmed: _editDoctorCall,
        doctorCallNote: _editDoctorCall ? _doctorCallNoteCtrl.text.trim() : null,
        customerCallConfirmed: _selectedClaim!.isBookingLinked ? _editCustomerCall : false,
        customerCallNote: (_selectedClaim!.isBookingLinked && _editCustomerCall) ? _customerCallNoteCtrl.text.trim() : null,
        sosCorroborated: _editSos,
        sosNote: _editSos ? _sosNoteCtrl.text.trim() : null,
        photoOverride: _editPhotoOverride,
        photoOverrideNote: _editPhotoOverride ? _photoOverrideNoteCtrl.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Admin verifications saved and confidence score recomputed."),
            backgroundColor: AX.emeraldDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Refresh detail view
        await _loadClaimDetail(_selectedClaim!.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _verificationError = "Failed to save verification: $e");
      }
    } finally {
      if (mounted) setState(() => _isSavingVerification = false);
    }
  }

  void _showDecisionDialog(String decision) {
    if (_selectedClaim == null) return;
    final noteCtrl = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isApprove = decision == "approved";
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  isApprove ? Icons.verified_user_rounded : Icons.cancel_outlined,
                  color: isApprove ? const Color(0xFF065F46) : AX.rose,
                ),
                const SizedBox(width: 10),
                Text(
                  isApprove ? "Approve Welfare Claim" : "Reject Welfare Claim",
                  style: AX.heading(fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You are about to finalize this micro-insurance claim. The current confidence score and frequency threshold will be permanently snapshotted into the immutable audit trail.",
                    style: AX.body(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Text("Administrative Justification (Min. 10 characters)*", style: AX.heading(fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: AX.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: isApprove
                          ? "e.g. Doctor certificate and customer corroboration confirmed. Approved for medical relief."
                          : "e.g. Insufficient medical documentation provided and uncorroborated on-duty incident.",
                      hintStyle: const TextStyle(color: AX.textMuted, fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFFF9F6EE),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AX.divider)),
                    ),
                    onChanged: (_) => setDlgState(() => dialogError = null),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(dialogError!, style: const TextStyle(color: AX.rose, fontSize: 11)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text("Cancel", style: AX.body(color: AX.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final note = noteCtrl.text.trim();
                  if (note.length < 10) {
                    setDlgState(() => dialogError = "Justification note must be at least 10 characters.");
                    return;
                  }
                  Navigator.of(ctx).pop();
                  await _submitDecision(decision, note);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApprove ? const Color(0xFF065F46) : AX.rose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isApprove ? "Confirm Approval" : "Confirm Rejection"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitDecision(String decision, String note) async {
    if (_selectedClaim == null) return;
    try {
      await _welfareService.submitDecision(
        claimId: _selectedClaim!.id,
        decision: decision,
        decisionNote: note,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Claim ${decision.toUpperCase()}: Historical score and threshold snapshotted."),
            backgroundColor: decision == "approved" ? const Color(0xFF065F46) : AX.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadClaimDetail(_selectedClaim!.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to record decision: $e"),
            backgroundColor: AX.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _viewDecryptedDocument(String docId, String title) async {
    if (_selectedClaim == null) return;

    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: _welfareService.getDecryptedDocument(
          workerId: _selectedClaim!.workerId,
          docId: docId,
        ),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null || snap.data!["success"] != true) {
            return AlertDialog(
              title: Text("Document Vault Error", style: AX.heading(fontSize: 15)),
              content: Text("Could not decrypt document: ${snap.error ?? snap.data?['error'] ?? 'Unknown error'}"),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Close")),
              ],
            );
          }

          final data = snap.data!;
          final base64Str = data["base64Data"] as String? ?? "";
          final fileName = data["fileName"] as String? ?? "document.dat";
          final mimeType = data["mimeType"] as String? ?? "";
          final isImage = mimeType.startsWith("image/") || fileName.toLowerCase().endsWith(".png") || fileName.toLowerCase().endsWith(".jpg") || fileName.toLowerCase().endsWith(".jpeg");

          Uint8List? bytes;
          if (base64Str.isNotEmpty) {
            try {
              bytes = base64Decode(base64Str);
            } catch (_) {}
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_open_rounded, color: Color(0xFF065F46), size: 18),
                    const SizedBox(width: 8),
                    Text("Decrypted: $title", style: AX.heading(fontSize: 14)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "File: $fileName · Type: $mimeType · Size: ${bytes != null ? '${(bytes.length / 1024).toStringAsFixed(1)} KB' : 'Unknown'}",
                      style: AX.mono(fontSize: 11, color: AX.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: isImage && bytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(bytes, fit: BoxFit.contain, width: double.infinity),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F6EE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AX.divider),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                "Binary document decrypted successfully via AES-256-CBC backend pipeline.\n\nMIME: $mimeType\nPayload Length: ${base64Str.length} characters.",
                                style: AX.mono(fontSize: 11),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AX.bgCosmic,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Header & Tab Switcher ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Worker Welfare & Micro-Insurance Cockpit", style: AX.display(fontSize: 20)),
                  const SizedBox(height: 2),
                  Text("SIH 26089 Micro-Insurance claim scoring, encrypted verification & PMJJBY/PMSBY corpus", style: AX.body(fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0EA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildTopTabItem(0, "Claim Review & Settlement", Icons.rate_review_rounded),
                    const SizedBox(width: 4),
                    _buildTopTabItem(1, "Insurance Corpus & Roster", Icons.account_balance_wallet_rounded),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Active Tab View ───────────────────────────────────────────────
          Expanded(
            child: _activeTopTab == 0 ? _buildClaimsReviewTab() : _buildCorpusAndRosterTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTabItem(int index, String label, IconData icon) {
    final isSelected = _activeTopTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTopTab = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: isSelected ? AX.emeraldDark : AX.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AX.heading(
                fontSize: 12,
                color: isSelected ? AX.textPrimary : AX.textSecondary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB 1: CLAIMS REVIEW & SETTLEMENT COCKPIT (MASTER-DETAIL)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildClaimsReviewTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: Master Claim Queue ───────────────────────────────────────
        SizedBox(
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & Filter Row
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        style: const TextStyle(color: AX.textPrimary, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "Search claim ID or worker...",
                          hintStyle: const TextStyle(color: AX.textMuted, fontSize: 11),
                          prefixIcon: const Icon(Icons.search, size: 16, color: AX.textSecondary),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AX.divider)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        onChanged: (val) => setState(() => _claimSearchQuery = val.toLowerCase().trim()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("all", "All"),
                    const SizedBox(width: 6),
                    _buildFilterChip("pending_review", "Pending"),
                    const SizedBox(width: 6),
                    _buildFilterChip("approved", "Approved"),
                    const SizedBox(width: 6),
                    _buildFilterChip("rejected", "Rejected"),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Claims Stream List
              Expanded(
                child: StreamBuilder<List<WelfareClaim>>(
                  stream: _welfareService.streamAllClaims(
                    status: _claimStatusFilter == "all" ? null : _claimStatusFilter,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var claims = snapshot.data ?? [];
                    if (_claimSearchQuery.isNotEmpty) {
                      claims = claims.where((c) {
                        return c.id.toLowerCase().contains(_claimSearchQuery) ||
                            c.workerId.toLowerCase().contains(_claimSearchQuery) ||
                            c.description.toLowerCase().contains(_claimSearchQuery);
                      }).toList();
                    }

                    if (claims.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: AX.glassBox(radius: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inbox_rounded, color: AX.textMuted, size: 36),
                            const SizedBox(height: 8),
                            Text("No Claims Found", style: AX.heading(fontSize: 13)),
                            Text("Claims filed by artisans will appear in this review queue.", textAlign: TextAlign.center, style: AX.body(fontSize: 11)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: claims.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final c = claims[idx];
                        final isSelected = _selectedClaim?.id == c.id;
                        return _buildClaimQueueCard(c, isSelected);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),

        // ── Right: Detail Inspection & Decision Console ────────────────────
        Expanded(
          child: _selectedClaim == null
              ? _buildEmptyDetailPlaceholder()
              : _buildClaimDetailPanel(),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _claimStatusFilter == value;
    return InkWell(
      onTap: () => setState(() => _claimStatusFilter = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF141416) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.transparent : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AX.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildClaimQueueCard(WelfareClaim c, bool isSelected) {
    Color statusBg;
    Color statusFg;
    String statusText;

    if (c.isApproved) {
      statusBg = const Color(0xFFD1FAE5);
      statusFg = const Color(0xFF065F46);
      statusText = "Approved";
    } else if (c.isRejected) {
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFF991B1B);
      statusText = "Rejected";
    } else {
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFF92400E);
      statusText = "Pending Review";
    }

    final shortId = c.id.length > 8 ? c.id.substring(0, 8).toUpperCase() : c.id.toUpperCase();
    final dateStr = "${c.submittedAt.day.toString().padLeft(2, '0')}/${c.submittedAt.month.toString().padLeft(2, '0')}";

    return InkWell(
      onTap: () => _onSelectClaim(c),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF8E8) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AX.emeraldDark : const Color(0xFFF0EDE6),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Claim #$shortId", style: AX.heading(fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(statusText, style: TextStyle(color: statusFg, fontSize: 9.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              c.description.isNotEmpty ? c.description : "Medical emergency / disability relief claim",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AX.body(fontSize: 11, color: const Color(0xFF4B5563)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Artisan: ${c.workerId}", style: AX.mono(fontSize: 10, color: AX.textMuted)),
                Row(
                  children: [
                    if (c.isBookingLinked) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                        child: Text("JOB-LINKED", style: TextStyle(color: const Color(0xFF1D4ED8), fontSize: 8.5, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(dateStr, style: AX.mono(fontSize: 10, color: AX.textSecondary)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDetailPlaceholder() {
    return Container(
      decoration: AX.glassBox(radius: 20),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFFCBD5E1), size: 48),
          const SizedBox(height: 12),
          Text("Select a Claim to Inspect", style: AX.display(fontSize: 16)),
          const SizedBox(height: 4),
          Text("Select any pending or decided claim from the queue to decrypt documents, corroborate evidence, evaluate confidence, and issue decisions.", textAlign: TextAlign.center, style: AX.body(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildClaimDetailPanel() {
    final claim = _selectedClaim!;
    final detail = _claimDetailResponse;

    return Container(
      decoration: AX.glassBox(radius: 20),
      padding: const EdgeInsets.all(22),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoadingDetail) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 12),
            ],
            // ── Top Header Bar ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("Claim #${claim.id.toUpperCase()}", style: AX.display(fontSize: 17)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: claim.isApproved
                                ? const Color(0xFFD1FAE5)
                                : claim.isRejected
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            claim.status.toUpperCase(),
                            style: TextStyle(
                              color: claim.isApproved
                                  ? const Color(0xFF065F46)
                                  : claim.isRejected
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFF92400E),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Filed on ${claim.submittedAt.toIso8601String().substring(0, 10)} · Incident on ${claim.incidentDate.toIso8601String().substring(0, 10)}",
                      style: AX.mono(fontSize: 11, color: AX.textSecondary),
                    ),
                  ],
                ),
                if (claim.bookingId != null && claim.bookingId!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Linked Booking: #${claim.bookingId}",
                      style: AX.mono(fontSize: 11, color: const Color(0xFF1E40AF)),
                    ),
                  ),
              ],
            ),
            const Divider(height: 28, color: AX.divider),

            // ── Description & Worker Context ────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Incident Description", style: AX.heading(fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F6EE),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AX.divider),
                        ),
                        child: Text(
                          claim.description.isNotEmpty ? claim.description : "No written narrative provided.",
                          style: AX.body(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Artisan Vault Context", style: AX.heading(fontSize: 12)),
                        const SizedBox(height: 6),
                        Text("Worker ID: ${claim.workerId}", style: AX.mono(fontSize: 10, color: AX.textPrimary)),
                        if (detail?.worker != null) ...[
                          Text("Name: ${detail!.worker!['name'] ?? 'Artisan'}", style: AX.body(fontSize: 11)),
                          Text("Rating: ${detail.worker!['avgRating'] ?? 'N/A'} ★", style: AX.body(fontSize: 11)),
                          Text("Guild: ${detail.worker!['org'] ?? 'Cooperative'}", style: AX.body(fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Encrypted Document Decryption Vault ─────────────────────────
            Text("Encrypted Document Vault (AES-256-CBC)", style: AX.heading(fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                // Doctor Certificate
                Expanded(
                  child: _buildDocCard(
                    title: "Medical Certificate",
                    docId: claim.doctorCertificateDocId,
                    isRequired: true,
                    icon: Icons.medical_information_rounded,
                    onTap: () => _viewDecryptedDocument(claim.doctorCertificateDocId, "Doctor Certificate"),
                  ),
                ),
                const SizedBox(width: 10),

                // Injury Photo
                Expanded(
                  child: _buildDocCard(
                    title: "Injury Scene Photo",
                    docId: claim.injuryPhotoDocId,
                    isRequired: false,
                    isFlagged: claim.photoFlagged,
                    icon: Icons.photo_camera_rounded,
                    onTap: claim.injuryPhotoDocId != null
                        ? () => _viewDecryptedDocument(claim.injuryPhotoDocId!, "Injury Photo")
                        : null,
                  ),
                ),
                const SizedBox(width: 10),

                // Hospital Record
                Expanded(
                  child: _buildDocCard(
                    title: "Hospital / Discharge",
                    docId: claim.hospitalRecordDocId,
                    isRequired: false,
                    icon: Icons.local_hospital_rounded,
                    onTap: claim.hospitalRecordDocId != null
                        ? () => _viewDecryptedDocument(claim.hospitalRecordDocId!, "Hospital Record")
                        : null,
                  ),
                ),
              ],
            ),
            if (claim.photoFlagged) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AX.rose.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AX.rose, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Synthetic/Altered Image Flagged: AI detector flagged this injury photo as potentially generated or edited. Admin photoOverride with >= 20 char note is required to include in score.",
                        style: TextStyle(color: const Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ── Interactive Admin Verification Checklist ─────────────────────
            Text("Admin Corroboration Checklist (Min. 20 Chars / Factor)", style: AX.heading(fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  // Factor 1: Doctor Call
                  _buildChecklistRow(
                    title: "Doctor / Hospital Direct Call Corroboration",
                    isChecked: _editDoctorCall,
                    onChanged: (val) => setState(() => _editDoctorCall = val ?? false),
                    controller: _doctorCallNoteCtrl,
                    hint: "Spoke with Dr. [Name] at [Hospital]. Confirmed fracture/laceration diagnosed.",
                  ),
                  const Divider(height: 20, color: Color(0xFFF3F4F6)),

                  // Factor 2: Customer Call (Job-linked only: completely hidden when no booking is attached)
                  if (claim.isBookingLinked) ...[
                    _buildChecklistRow(
                      title: "Customer Dispatch Incident Corroboration (Booking-Linked)",
                      isChecked: _editCustomerCall,
                      isEnabled: true,
                      onChanged: (val) => setState(() => _editCustomerCall = val ?? false),
                      controller: _customerCallNoteCtrl,
                      hint: "Contacted customer. Confirmed accident occurred on active premises.",
                    ),
                    const Divider(height: 20, color: Color(0xFFF3F4F6)),
                  ],

                  // Factor 3: SOS Distress Beacon
                  _buildChecklistRow(
                    title: "SOS Distress Beacon / Incident Dispatch Corroborated",
                    isChecked: _editSos,
                    onChanged: (val) => setState(() => _editSos = val ?? false),
                    controller: _sosNoteCtrl,
                    hint: "Cross-checked with peer distress beacon log around incident timestamp.",
                  ),

                  // Factor 4: Photo Override (if photo flagged or provided)
                  if (claim.photoFlagged || claim.injuryPhotoDocId != null) ...[
                    const Divider(height: 20, color: Color(0xFFF3F4F6)),
                    _buildChecklistRow(
                      title: "Photo Tamper Flag Override (Exemption Justification)",
                      isChecked: _editPhotoOverride,
                      onChanged: (val) => setState(() => _editPhotoOverride = val ?? false),
                      controller: _photoOverrideNoteCtrl,
                      hint: "Manual review confirms genuine clinical artifact. Override approved.",
                    ),
                  ],
                  if (_verificationError != null) ...[
                    const SizedBox(height: 10),
                    Text(_verificationError!, style: const TextStyle(color: AX.rose, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isSavingVerification ? null : _saveVerifications,
                      icon: _isSavingVerification
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync_rounded, size: 16),
                      label: Text(_isSavingVerification ? "Saving..." : "Save Verifications & Recompute Score"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AX.emeraldDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Live Confidence Score & Threshold Gauge ─────────────────────
            _buildScoreGaugeSection(detail),
            const SizedBox(height: 20),

            // ── Final Decision Action Panel ─────────────────────────────────
            _buildDecisionPanel(claim),
          ],
        ),
      ),
    );
  }

  Widget _buildDocCard({
    required String title,
    required String? docId,
    required bool isRequired,
    bool isFlagged = false,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final hasDoc = docId != null && docId.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFlagged ? AX.rose : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: hasDoc ? AX.emeraldDark : AX.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: AX.heading(fontSize: 11.5)),
              ),
              if (isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                  child: const Text("GATE", style: TextStyle(color: AX.rose, fontSize: 8, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasDoc ? "Vault ID: ${docId.substring(0, docId.length.clamp(0, 10))}..." : "Not Provided",
            style: AX.mono(fontSize: 9.5, color: hasDoc ? AX.textSecondary : AX.textMuted),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 28,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: BorderSide(color: hasDoc ? AX.emeraldDark : const Color(0xFFE5E7EB)),
              ),
              child: Text(
                hasDoc ? "Decrypt & View" : "Empty",
                style: TextStyle(fontSize: 10, color: hasDoc ? AX.emeraldDark : AX.textMuted, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistRow({
    required String title,
    required bool isChecked,
    bool isEnabled = true,
    required ValueChanged<bool?> onChanged,
    required TextEditingController controller,
    required String hint,
  }) {
    final noteLength = controller.text.trim().length;
    final isNoteValid = noteLength >= 20;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: isChecked,
          onChanged: isEnabled ? onChanged : null,
          activeColor: AX.emeraldDark,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AX.heading(
                  fontSize: 12,
                  color: isEnabled ? AX.textPrimary : AX.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: controller,
                enabled: isEnabled && isChecked,
                style: const TextStyle(color: AX.textPrimary, fontSize: 11),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: AX.textMuted, fontSize: 10.5),
                  filled: true,
                  fillColor: const Color(0xFFF9F6EE),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AX.divider)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (isChecked) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "$noteLength / 20 chars minimum ${isNoteValid ? '✓' : ''}",
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isNoteValid ? const Color(0xFF065F46) : AX.rose,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreGaugeSection(WelfareClaimDetailResponse? detail) {
    if (detail == null || detail.score == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Score Pending Admin Corroboration", style: AX.heading(fontSize: 12.5, color: const Color(0xFF92400E))),
                  const SizedBox(height: 2),
                  Text(
                    "Claims with zero checked verification factors are not scored. Complete at least one verification note above to activate confidence scoring.",
                    style: AX.body(fontSize: 11, color: const Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final score = detail.score!;
    final threshold = detail.approvalThreshold;
    final meets = score.totalScore >= threshold;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text("Claim Confidence Score", style: AX.display(fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: meets ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      meets ? "MEETS TIER THRESHOLD ($threshold%)" : "BELOW TIER THRESHOLD ($threshold%)",
                      style: TextStyle(
                        color: meets ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                "${score.totalScore}%",
                style: AX.display(fontSize: 22, color: meets ? const Color(0xFF065F46) : AX.rose),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: score.totalScore / 100.0,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: AlwaysStoppedAnimation<Color>(meets ? const Color(0xFF065F46) : AX.rose),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Base Evidence: ${score.baseScore}%", style: AX.mono(fontSize: 10.5, color: AX.textSecondary)),
              Text("Trust Bonus: +${score.trustBonus}%", style: AX.mono(fontSize: 10.5, color: const Color(0xFF065F46))),
              Text("Weight Model: ${score.weightTableUsed.toUpperCase()}", style: AX.mono(fontSize: 10.5, color: AX.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionPanel(WelfareClaim claim) {
    if (!claim.isPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  claim.isApproved ? Icons.verified_user_rounded : Icons.block_rounded,
                  color: claim.isApproved ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  "Historical Decision Snapshot (${claim.status.toUpperCase()})",
                  style: AX.heading(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text("Decided By: ${claim.decidedBy ?? 'Admin'}", style: AX.mono(fontSize: 10.5)),
            if (claim.decisionNote != null)
              Text("Decision Note: ${claim.decisionNote}", style: AX.body(fontSize: 11)),
            if (claim.snapshotScore != null)
              Text("Score at Decision: ${claim.snapshotScore}% (Threshold: ${claim.snapshotThreshold ?? 50}%)", style: AX.mono(fontSize: 10.5, color: const Color(0xFF065F46))),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showDecisionDialog("approved"),
            icon: const Icon(Icons.check_circle_rounded, size: 16),
            label: const Text("Approve Welfare Claim"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF065F46),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showDecisionDialog("rejected"),
            icon: const Icon(Icons.cancel_rounded, size: 16),
            label: const Text("Reject Welfare Claim"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AX.rose,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB 2: INSURANCE CORPUS & ARTISAN ROSTER (PRESERVED)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCorpusAndRosterTab() {
    return StreamBuilder<List<Booking>>(
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

            if (_rosterSearchQuery.isNotEmpty) {
              workers = workers.where((w) {
                final nameMatch = w.name.toLowerCase().contains(_rosterSearchQuery);
                final skillMatch = w.skills.any((s) => s.toLowerCase().contains(_rosterSearchQuery));
                final idMatch = w.id.toLowerCase().contains(_rosterSearchQuery);
                return nameMatch || skillMatch || idMatch;
              }).toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Welfare Pool KPI Banners ──────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _buildCorpusCard(
                        title: "Accumulated Welfare Pool",
                        value: "₹${welfareCorpus >= 1000 ? '${(welfareCorpus / 1000).toStringAsFixed(2)}k' : welfareCorpus.toStringAsFixed(0)}",
                        subtitle: "2% of ₹${realizedGrossVolume.toStringAsFixed(0)} settled volume",
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildCorpusCard(
                        title: "Insured Artisans",
                        value: "$insuredCount / ${workers.length}",
                        subtitle: "${coverageRate.toStringAsFixed(0)}% membership coverage",
                        icon: Icons.health_and_safety_rounded,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildCorpusCard(
                        title: "Policy Schemes",
                        value: "PMJJBY + PMSBY",
                        subtitle: "₹2L Life + ₹2L Accident Cover",
                        icon: Icons.security_rounded,
                        color: const Color(0xFF1D4ED8),
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
                        style: const TextStyle(color: AX.textPrimary, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "Search artisan name or trade...",
                          hintStyle: const TextStyle(color: AX.textMuted, fontSize: 11),
                          prefixIcon: const Icon(Icons.search_rounded, color: AX.textSecondary, size: 16),
                          filled: true,
                          fillColor: const Color(0xFFF9F6EE),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AX.divider)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        onChanged: (val) => setState(() => _rosterSearchQuery = val.toLowerCase()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Worker Roster List (Real-Time Data) ────────────────────
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
                      decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(6)),
                      child: Text(w.skills.join(", "), style: const TextStyle(fontFamily: "SpaceGrotesk", fontSize: 10, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  w.insuranceStatus
                      ? "Enrolled: PMJJBY + PMSBY Plan (₹436/yr auto-debited from welfare fund)"
                      : "Micro-insurance inactive · Tap toggle to enroll from cooperative corpus",
                  style: AX.body(fontSize: 11, color: w.insuranceStatus ? const Color(0xFF065F46) : AX.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
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
