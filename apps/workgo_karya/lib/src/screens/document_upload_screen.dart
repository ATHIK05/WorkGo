import 'dart:convert';
import 'dart:io' show File;
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';
import 'live_multi_angle_camera_screen.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({
    super.key,
    required this.workerId,
    this.initialVerificationStatus = VerificationStatus.pending,
  });

  final String workerId;
  final VerificationStatus initialVerificationStatus;

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen>
    with TickerProviderStateMixin {
  final WorkerService _workerService = WorkerService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // ── Stage 1: DPDP Consent ──────────────────────────────────────────────────
  bool _consentAgreed = false;

  // ── Stage 2: Aadhaar State ──────────────────────────────────────────────────
  int _aadhaarTabIndex = 0; // 0 = Offline Zip, 1 = Card Photo
  bool _editingAadhaar = false;
  final TextEditingController _shareCodeCtrl = TextEditingController(text: "1234");
  String? _selectedAadhaarFileName;
  String? _selectedAadhaarFileSize;
  bool _isAadhaarZip = false;
  String? _aadhaarBase64;
  Uint8List? _aadhaarPreviewBytes;

  // ── Stage 3: 3D Multi-Angle Biometrics ──────────────────────────────────────
  String? _centerBase64;
  String? _leftBase64;
  String? _rightBase64;
  Uint8List? _centerBytes;
  Uint8List? _leftBytes;
  Uint8List? _rightBytes;
  bool _lightingBoosted = false;

  // ── Stage 4: Police Clearance State ─────────────────────────────────────────
  String? _pccBase64;
  String? _selectedPccFileName;
  String? _selectedPccFileSize;
  Uint8List? _pccPreviewBytes;

  @override
  void dispose() {
    _shareCodeCtrl.dispose();
    super.dispose();
  }

  // ── Real Actions ────────────────────────────────────────────────────────────

  Future<void> _handleConsent() async {
    if (!_consentAgreed) {
      _showErrorSnackBar("Please check the consent box to proceed.");
      return;
    }

    // Native OS Biometric (Fingerprint / Face ID) hardware authentication prompt
    final authenticated = await BiometricService().authenticate(
      reason: "Scan your fingerprint or face to authorize DPDP 2023 Biometric Consent.",
    );

    if (!authenticated) {
      if (mounted) {
        _showErrorSnackBar("Biometric verification cancelled. Scan your fingerprint to record consent.");
      }
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    try {
      await _workerService.submitBiometricConsent(widget.workerId);
      if (mounted) {
        _showSuccessSnackBar("Biometric consent & fingerprint verified successfully! ✓");
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar("Failed to record consent: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openUidaiPortal() async {
    final uri = Uri.parse("https://myaadhaar.uidai.gov.in");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar("Could not open UIDAI portal: $uri");
      }
    } catch (e) {
      _showErrorSnackBar("Error launching portal: $e");
    }
  }

  Future<void> _pickAadhaarFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        final nameLower = file.name.toLowerCase();
        final ext = file.extension?.toLowerCase() ?? (nameLower.contains('.') ? nameLower.split('.').last : '');
        const validExts = ['zip', 'xml', 'pdf', 'jpg', 'jpeg', 'png', 'webp'];
        if (ext.isNotEmpty && !validExts.contains(ext)) {
          _showErrorSnackBar("Please select a .zip, .xml, .pdf, or image file.");
          return;
        }

        Uint8List? bytes = file.bytes;
        if (bytes == null && !kIsWeb && file.path != null) {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            bytes = await ioFile.readAsBytes();
          }
        }
        if (bytes != null && bytes.isNotEmpty) {
          final isZipOrXml = nameLower.endsWith('.zip') || nameLower.endsWith('.xml');
          final isImg = nameLower.endsWith('.jpg') ||
              nameLower.endsWith('.jpeg') ||
              nameLower.endsWith('.png') ||
              nameLower.endsWith('.webp');

          setState(() {
            _selectedAadhaarFileName = file.name;
            _selectedAadhaarFileSize = "${(bytes!.length / 1024).toStringAsFixed(1)} KB";
            _isAadhaarZip = isZipOrXml;
            _aadhaarPreviewBytes = isImg ? bytes : null;
            _aadhaarBase64 = base64Encode(bytes);
          });
          HapticFeedback.lightImpact();
        } else {
          _showErrorSnackBar("Could not read file data. Please ensure the file is downloaded to your device.");
        }
      }
    } catch (e) {
      _showErrorSnackBar("Could not open file picker: $e");
    }
  }

  Future<void> _pickAadhaarImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedAadhaarFileName = file.name.isNotEmpty ? file.name : "aadhaar_card.jpg";
          _selectedAadhaarFileSize = "${(bytes.length / 1024).toStringAsFixed(1)} KB";
          _isAadhaarZip = false;
          _aadhaarPreviewBytes = bytes;
          _aadhaarBase64 = base64Encode(bytes);
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      _showErrorSnackBar("Could not open camera/gallery: $e");
    }
  }

  Future<void> _handleAadhaarSubmit() async {
    if (_aadhaarBase64 == null) {
      _showErrorSnackBar("Please select or capture your Aadhaar document first.");
      return;
    }
    if (_shareCodeCtrl.text.trim().length != 4) {
      _showErrorSnackBar("Please enter the 4-digit code (e.g. 1234).");
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final res = await _workerService.submitAadhaarOfflineKyc(
        workerId: widget.workerId,
        shareCode: _shareCodeCtrl.text.trim(),
        base64Data: _aadhaarBase64!,
        fileName: _selectedAadhaarFileName ?? (_aadhaarTabIndex == 0 ? "offline_aadhaar.zip" : "aadhaar_card.jpg"),
      );

      if (mounted) {
        final verifiedName = res["verifiedName"] ?? "Verified Artisan";
        _showSuccessSnackBar("Aadhaar verified successfully: $verifiedName");
        setState(() => _editingAadhaar = false);
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar("Aadhaar verification failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Launch 3D Multi-Angle Live Camera
  Future<void> _start3DMultiAngleCamera() async {
    HapticFeedback.heavyImpact();
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => const LiveMultiAngleCameraScreen(),
      ),
    );

    if (result != null && mounted) {
      final centerB64 = result["centerBase64"] as String?;
      final leftB64 = result["leftBase64"] as String?;
      final rightB64 = result["rightBase64"] as String?;
      final boosted = result["lightingBoosted"] as bool? ?? false;

      if (centerB64 != null) {
        // Store captures in state — user must tap "Save & Continue" to confirm
        setState(() {
          _centerBase64 = centerB64;
          _leftBase64 = leftB64 ?? centerB64;
          _rightBase64 = rightB64 ?? centerB64;
          _centerBytes = base64Decode(_centerBase64!);
          _leftBytes = base64Decode(_leftBase64!);
          _rightBytes = base64Decode(_rightBase64!);
          _lightingBoosted = boosted;
        });
        // ⬆ No auto-submit — user reviews photos and taps "Save & Continue"
      }
    }
  }

  Future<void> _submit3DBiometrics() async {
    if (_centerBase64 == null) return;
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final res = await _workerService.submitMultiAngleLiveness(
        workerId: widget.workerId,
        centerBase64: _centerBase64!,
        leftBase64: _leftBase64 ?? _centerBase64!,
        rightBase64: _rightBase64 ?? _centerBase64!,
        lightingBoosted: _lightingBoosted,
      );

      if (mounted) {
        if (res["isSuspicious"] == true) {
          _showErrorSnackBar("Biometrics captured with scrutiny flags. Proceeding to Police Clearance.");
        } else {
          _showSuccessSnackBar("3D Biometric Liveness Verified Successfully! ✓");
        }
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar("Biometric verification failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPccFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        final nameLower = file.name.toLowerCase();
        final ext = file.extension?.toLowerCase() ?? (nameLower.contains('.') ? nameLower.split('.').last : '');
        const validExts = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];
        if (ext.isNotEmpty && !validExts.contains(ext)) {
          _showErrorSnackBar("Please select a PDF document or image file.");
          return;
        }

        Uint8List? bytes = file.bytes;
        if (bytes == null && !kIsWeb && file.path != null) {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            bytes = await ioFile.readAsBytes();
          }
        }
        if (bytes != null && bytes.isNotEmpty) {
          final isImg = nameLower.endsWith('.jpg') ||
              nameLower.endsWith('.jpeg') ||
              nameLower.endsWith('.png') ||
              nameLower.endsWith('.webp');

          setState(() {
            _selectedPccFileName = file.name;
            _selectedPccFileSize = "${(bytes!.length / 1024).toStringAsFixed(1)} KB";
            _pccPreviewBytes = isImg ? bytes : null;
            _pccBase64 = base64Encode(bytes);
          });
          HapticFeedback.lightImpact();
        } else {
          _showErrorSnackBar("Could not read document data.");
        }
      }
    } catch (e) {
      _showErrorSnackBar("Could not open file picker: $e");
    }
  }

  Future<void> _pickPccDocument(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedPccFileName = file.name.isNotEmpty ? file.name : "pcc_certificate.jpg";
          _selectedPccFileSize = "${(bytes.length / 1024).toStringAsFixed(1)} KB";
          _pccPreviewBytes = bytes;
          _pccBase64 = base64Encode(bytes);
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      _showErrorSnackBar("Could not open camera/gallery: $e");
    }
  }

  Future<void> _handlePccSubmit() async {
    if (_pccBase64 == null) {
      _showErrorSnackBar("Please select your Police Clearance Certificate first.");
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await _workerService.uploadPccDocument(
        workerId: widget.workerId,
        base64Data: _pccBase64!,
        docName: _selectedPccFileName,
      );

      if (mounted) {
        _showSuccessSnackBar("Police Clearance submitted for cooperative review!");
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar("Failed to upload PCC: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F291E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2C1014),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KaryaColors.backgroundDark,
      appBar: AppBar(
        title: SafeText(
          "verification_hub_title".tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            color: const Color(0xFF1F1635),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) async {
              if (val == "reset_step2") {
                await _workerService.resetVerificationStage(widget.workerId, stage: VerificationStage.aadhaarOfflineEkyc);
                _showSuccessSnackBar("Reset to Step 2: UIDAI Offline e-KYC");
              } else if (val == "reset_all") {
                await _workerService.resetVerificationStage(widget.workerId, stage: VerificationStage.consent);
                _showSuccessSnackBar("Reset to Step 1: Consent");
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: "reset_step2",
                child: Row(
                  children: [
                    Icon(Icons.replay_rounded, color: KaryaColors.brandYellow, size: 18),
                    SizedBox(width: 8),
                    Text("Re-do Aadhaar eKYC (Step 2)", style: TextStyle(color: Colors.white, fontSize: 12.5)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: "reset_all",
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, color: Color(0xFFEF4444), size: 18),
                    SizedBox(width: 8),
                    Text("Restart Verification (Step 1)", style: TextStyle(color: Colors.white, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<Worker?>(
          stream: _workerService.streamWorker(widget.workerId),
          builder: (context, snapshot) {
            final worker = snapshot.data;
            final stage = worker?.verificationStage ?? VerificationStage.signup;
            final isApproved = worker?.verificationStatus == VerificationStatus.approved;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Subtitle ──────────────────────────────────────────
                  SafeText(
                    "verification_hub_subtitle".tr(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Progress Pipeline Bar ────────────────────────────────────
                  _buildPipelineStatusBar(stage, isApproved),
                  const SizedBox(height: 24),

                  // ── Step 1: DPDP 2023 Biometric Consent ───────────────────────
                  _buildConsentCard(stage),
                  const SizedBox(height: 20),

                  // ── Step 2: Aadhaar Offline eKYC + Guide ─────────────────────
                  _buildAadhaarCard(stage, worker),
                  const SizedBox(height: 20),

                  // ── Step 3: 3D Multi-Angle Biometric Liveness ────────────────
                  _build3DMultiAngleCard(stage, worker),
                  const SizedBox(height: 20),

                  // ── Step 4: Police Clearance Certificate (PCC) ───────────────
                  _buildPccCard(stage, worker),
                  const SizedBox(height: 20),

                  // ── Step 5: Verification & Co-op Certification Status ─────────
                  _buildCertificationStatusCard(stage, worker, isApproved),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 1. Pipeline Status Bar ──────────────────────────────────────────────────
  Widget _buildPipelineStatusBar(VerificationStage stage, bool isApproved) {
    int activeStep = 0;
    if (stage == VerificationStage.aadhaarOfflineEkyc) activeStep = 1;
    if (stage == VerificationStage.selfieCapture || stage == VerificationStage.onDeviceLiveness || stage == VerificationStage.multiAngleLiveness) activeStep = 2;
    if (stage == VerificationStage.pccUpload || stage == VerificationStage.pccManualReview) activeStep = 3;
    if (isApproved || stage == VerificationStage.approved) activeStep = 4;

    final steps = ["Consent", "Aadhaar", "3D Face", "PCC", "Certified"];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: KaryaColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isCompleted = index < activeStep;
          final isCurrent = index == activeStep;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted ? const Color(0xFF10B981) : Colors.white12,
                        ),
                      ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? const Color(0xFF10B981)
                            : isCurrent
                                ? KaryaColors.brandYellow
                                : Colors.white12,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text(
                                "${index + 1}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.black : Colors.white54,
                                ),
                              ),
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < activeStep ? const Color(0xFF10B981) : Colors.white12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                SafeText(
                  steps[index],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w500,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : isCurrent
                            ? KaryaColors.brandYellow
                            : Colors.white38,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── 2. DPDP 2023 Consent Card ───────────────────────────────────────────────
  Widget _buildConsentCard(VerificationStage stage) {
    // isDone when worker has advanced past the signup stage to Aadhaar or beyond
    final isDone = stage.index >= VerificationStage.aadhaarOfflineEkyc.index;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KaryaColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? const Color(0xFF10B981).withAlpha(120) : KaryaColors.brandYellow.withAlpha(100),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFF10B981).withAlpha(30) : KaryaColors.brandYellow.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDone ? Icons.verified_user_rounded : Icons.shield_rounded,
                  color: isDone ? const Color(0xFF10B981) : KaryaColors.brandYellow,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      "dpdp_consent_title".tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    SafeText(
                      isDone ? "Consent Accepted & Timestamped ✓" : "Step 1 of 4",
                      style: TextStyle(
                        color: isDone ? const Color(0xFF10B981) : KaryaColors.brandYellow,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SafeText(
            "dpdp_consent_desc".tr(),
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),

          // Itemized Permission Points
          _buildConsentBullet(Icons.camera_alt_rounded, "dpdp_consent_item_camera".tr()),
          _buildConsentBullet(Icons.badge_rounded, "dpdp_consent_item_aadhaar".tr()),
          _buildConsentBullet(Icons.local_police_rounded, "dpdp_consent_item_pcc".tr()),

          if (!isDone) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Checkbox(
                  value: _consentAgreed,
                  activeColor: KaryaColors.brandYellow,
                  checkColor: Colors.black,
                  onChanged: (val) => setState(() => _consentAgreed = val ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _consentAgreed = !_consentAgreed),
                    child: SafeText(
                      "dpdp_consent_checkbox".tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleConsent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KaryaColors.brandYellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : SafeText("accept_consent_btn".tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConsentBullet(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: SafeText(
              text,
              style: const TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Aadhaar Offline eKYC Card with Step-by-Step Guide ────────────────────
  Widget _buildAadhaarCard(VerificationStage stage, Worker? worker) {
    final isDone = stage.index > VerificationStage.aadhaarOfflineEkyc.index;
    final isCurrent = stage == VerificationStage.aadhaarOfflineEkyc;
    final maskedUid = worker?.verificationDetails?.aadhaarMaskedNumber ?? "XXXXXXXX4821";
    final verifiedName = worker?.verificationDetails?.aadhaarVerifiedName ?? worker?.name ?? "";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KaryaColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withAlpha(120)
              : isCurrent
                  ? KaryaColors.brandYellow.withAlpha(120)
                  : Colors.white10,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF10B981).withAlpha(30)
                      : isCurrent
                          ? KaryaColors.brandYellow.withAlpha(30)
                          : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  color: isDone
                      ? const Color(0xFF10B981)
                      : isCurrent
                          ? KaryaColors.brandYellow
                          : Colors.white38,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      "aadhaar_xml_title".tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    SafeText(
                      isDone
                          ? "Aadhaar Verified · $maskedUid ($verifiedName)"
                          : isCurrent
                              ? "Step 2 of 4 · Action Required"
                              : "Locked (Complete Step 1)",
                      style: TextStyle(
                        color: isDone
                            ? const Color(0xFF10B981)
                            : isCurrent
                                ? KaryaColors.brandYellow
                                : Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDone)
                TextButton.icon(
                  onPressed: () => setState(() => _editingAadhaar = !_editingAadhaar),
                  style: TextButton.styleFrom(
                    foregroundColor: KaryaColors.brandYellow,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: Icon(_editingAadhaar ? Icons.close_rounded : Icons.edit_rounded, size: 14),
                  label: Text(
                    _editingAadhaar ? "Close" : "Change",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),

          if (isCurrent || _editingAadhaar) ...[
            const SizedBox(height: 16),

            // ── Interactive Visual Tutorial on 4-Digit Share Code ───────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1635),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KaryaColors.brandYellow.withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline_rounded, color: KaryaColors.brandYellow, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SafeText(
                          "aadhaar_guide_title".tr(),
                          style: const TextStyle(color: KaryaColors.brandYellow, fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SafeText("aadhaar_guide_step1".tr(), style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  const SizedBox(height: 4),
                  SafeText("aadhaar_guide_step2".tr(), style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  const SizedBox(height: 4),
                  SafeText("aadhaar_guide_step3".tr(), style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  const SizedBox(height: 4),
                  SafeText("aadhaar_guide_step4".tr(), style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openUidaiPortal,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KaryaColors.brandYellow,
                        side: const BorderSide(color: KaryaColors.brandYellow),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: SafeText(
                        "open_uidai_portal_btn".tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Toggle Tabs: Offline Zip vs Card Photo
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _aadhaarTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _aadhaarTabIndex == 0 ? KaryaColors.brandYellow : Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "upload_zip_tab".tr(),
                          style: TextStyle(
                            color: _aadhaarTabIndex == 0 ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _aadhaarTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _aadhaarTabIndex == 1 ? KaryaColors.brandYellow : Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "upload_photo_tab".tr(),
                          style: TextStyle(
                            color: _aadhaarTabIndex == 1 ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Share Code Input
            TextField(
              controller: _shareCodeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 3),
              decoration: InputDecoration(
                labelText: "share_code_label".tr(),
                hintText: "share_code_hint".tr(),
                labelStyle: const TextStyle(color: Colors.white70),
                counterText: "",
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: KaryaColors.brandYellow, width: 2)),
              ),
            ),
            const SizedBox(height: 12),

            // File / Photo Picker Trigger
            if (_aadhaarTabIndex == 0) ...[
              // ── Offline Zip Tab ──
              if (_selectedAadhaarFileName != null && _isAadhaarZip) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.folder_zip_rounded, color: Color(0xFF10B981), size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedAadhaarFileName!,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${_selectedAadhaarFileSize ?? 'UIDAI Zip'} · Ready for verification",
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _pickAadhaarFile,
                        child: const Text("Change", style: TextStyle(color: KaryaColors.brandYellow, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _pickAadhaarFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KaryaColors.brandYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.folder_zip_rounded, size: 20),
                    label: const Text(
                      "Select UIDAI Offline Zip (.zip / .xml)",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ] else ...[
              // ── Card Photo Tab ──
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickAadhaarImage(ImageSource.gallery),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: Text(_selectedAadhaarFileName ?? "upload_aadhaar_file".tr(), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _pickAadhaarImage(ImageSource.camera),
                    style: IconButton.styleFrom(
                      backgroundColor: KaryaColors.brandYellow,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.camera_alt_rounded),
                  ),
                ],
              ),
              if (_aadhaarPreviewBytes != null) ...[
                const SizedBox(height: 12),
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_aadhaarPreviewBytes!, fit: BoxFit.cover),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleAadhaarSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : SafeText("verify_aadhaar_btn".tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 4. 3D Multi-Angle Biometric Liveness Card ───────────────────────────────
  Widget _build3DMultiAngleCard(VerificationStage stage, Worker? worker) {
    final details = worker?.verificationDetails;
    final hasBiometricsInDb = details?.selfieCenterBase64 != null ||
        details?.selfieBase64 != null ||
        details?.livenessPassedAt != null ||
        stage.index >= VerificationStage.pccUpload.index;
    final isDone = hasBiometricsInDb;
    final isCurrent = !isDone &&
        (stage == VerificationStage.selfieCapture ||
            stage == VerificationStage.onDeviceLiveness ||
            stage == VerificationStage.multiAngleLiveness);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KaryaColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withAlpha(120)
              : isCurrent
                  ? KaryaColors.brandYellow.withAlpha(120)
                  : Colors.white10,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF10B981).withAlpha(30)
                      : isCurrent
                          ? KaryaColors.brandYellow.withAlpha(30)
                          : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.face_retouching_natural_rounded,
                  color: isDone
                      ? const Color(0xFF10B981)
                      : isCurrent
                          ? KaryaColors.brandYellow
                          : Colors.white38,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      "multi_angle_liveness_title".tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    SafeText(
                      isDone
                          ? "3D Multi-Angle Biometrics Verified ✓"
                          : isCurrent
                              ? "Step 3 of 4 · Real Camera Scan"
                              : "Locked (Complete Step 2)",
                      style: TextStyle(
                        color: isDone
                            ? const Color(0xFF10B981)
                            : isCurrent
                                ? KaryaColors.brandYellow
                                : Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDone)
                TextButton.icon(
                  onPressed: _start3DMultiAngleCamera,
                  style: TextButton.styleFrom(
                    foregroundColor: KaryaColors.brandYellow,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text("Retake", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),

          if (isCurrent) ...[
            const SizedBox(height: 14),
            SafeText(
              "multi_angle_liveness_desc".tr(),
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),

            // Captured Photo Preview Grid (Center, Left, Right)
            if (_centerBytes != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPreviewThumb("Center", _centerBytes!),
                  _buildPreviewThumb("Left 👈", _leftBytes ?? _centerBytes!),
                  _buildPreviewThumb("Right 👉", _rightBytes ?? _centerBytes!),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _start3DMultiAngleCamera,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text("Retake", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit3DBiometrics,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text("Save & Continue", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _start3DMultiAngleCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KaryaColors.brandYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.camera_front_rounded),
                  label: SafeText(
                    "start_liveness_btn".tr(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewThumb(String title, Uint8List bytes) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF10B981), width: 2),
          ),
          child: ClipOval(
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 4),
        SafeText(
          title,
          style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ── 5. Police Clearance Certificate (PCC) Card ──────────────────────────────
  Widget _buildPccCard(VerificationStage stage, Worker? worker) {
    final isDone = stage == VerificationStage.approved || stage == VerificationStage.pccManualReview;
    final isCurrent = stage == VerificationStage.pccUpload;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KaryaColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withAlpha(120)
              : isCurrent
                  ? KaryaColors.brandYellow.withAlpha(120)
                  : Colors.white10,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF10B981).withAlpha(30)
                      : isCurrent
                          ? KaryaColors.brandYellow.withAlpha(30)
                          : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_police_rounded,
                  color: isDone
                      ? const Color(0xFF10B981)
                      : isCurrent
                          ? KaryaColors.brandYellow
                          : Colors.white38,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      "pcc_upload_title".tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    SafeText(
                      isDone
                          ? "PCC Submitted · Under Staff Review ✓"
                          : isCurrent
                              ? "Step 4 of 4 · Final Upload"
                              : "Locked (Complete Step 3)",
                      style: TextStyle(
                        color: isDone
                            ? const Color(0xFF10B981)
                            : isCurrent
                                ? KaryaColors.brandYellow
                                : Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isCurrent) ...[
            const SizedBox(height: 14),
            SafeText(
              "pcc_upload_desc".tr(),
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickPccFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(_selectedPccFileName ?? "upload_pcc_btn".tr(), overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _pickPccDocument(ImageSource.camera),
                  style: IconButton.styleFrom(
                    backgroundColor: KaryaColors.brandYellow,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.camera_alt_rounded),
                ),
              ],
            ),

            if (_selectedPccFileName != null && _pccPreviewBytes == null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_rounded, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "${_selectedPccFileName!} (${_selectedPccFileSize ?? 'Document'})",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                  ],
                ),
              ),
            ],

            if (_pccPreviewBytes != null) ...[
              const SizedBox(height: 12),
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_pccPreviewBytes!, fit: BoxFit.cover),
                ),
              ),
            ],

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handlePccSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const SafeText("Submit for Cooperative Certification", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 6. Certification & C2PA Trust Status Card ───────────────────────────────
  Widget _buildCertificationStatusCard(VerificationStage stage, Worker? worker, bool isApproved) {
    if (!isApproved && stage != VerificationStage.approved && stage != VerificationStage.pccManualReview) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isApproved
              ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
              : [const Color(0xFF312E81), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isApproved ? const Color(0xFF10B981) : KaryaColors.brandYellow,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isApproved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                color: isApproved ? const Color(0xFF10B981) : KaryaColors.brandYellow,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      isApproved ? "stage_approved_title".tr() : "pcc_under_review".tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    SafeText(
                      isApproved ? "c2pa_badge_title".tr() : "Cooperative Officer Audit in Progress",
                      style: TextStyle(
                        color: isApproved ? const Color(0xFF34D399) : KaryaColors.brandYellow,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SafeText(
            isApproved
                ? "stage_approved_desc".tr()
                : "Your Aadhaar, 3D Multi-Angle Biometrics, and Police Clearance have been securely transmitted to the Cooperative Governance Console.",
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
