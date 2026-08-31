import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

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
  bool _isLoading = false;

  // Form Controllers
  final TextEditingController _shareCodeCtrl = TextEditingController(text: "1234");
  String? _selectedAadhaarFileName;
  String? _aadhaarSampleBase64;
  String? _pccSampleBase64;
  String? _selectedPccFileName;

  // Liveness Challenge State
  int _livenessStep = 0; // 0: ready, 1: blink, 2: turn head, 3: smile, 4: passed
  bool _isLivenessActive = false;

  // Video KYC State
  DateTime? _selectedSlotTime;

  @override
  void initState() {
    super.initState();
    _selectedSlotTime = DateTime.now().add(const Duration(hours: 2));
    _generateSampleAadhaarXml();
    _generateSamplePcc();
  }

  void _generateSampleAadhaarXml() {
    final sampleXml = '''<?xml version="1.0" encoding="UTF-8"?>
<OfflinePaperlessKyc referenceId="123420260831120000000">
  <UidData>
    <Poi dob="1990-04-12" gender="M" name="Murugan Shanmugam" />
    <Poa careof="S/O Shanmugam" country="India" dist="Chennai" loc="T Nagar" pc="600017" state="Tamil Nadu" vtc="Chennai" />
    <Pht>/9j/4AAQSkZJRgABAQEASABIAAD...</Pht>
  </UidData>
  <Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
    <SignedInfo><SignatureValue>UIDAI_XML_DSIG_VALID_SIH2026</SignatureValue></SignedInfo>
  </Signature>
</OfflinePaperlessKyc>''';
    _aadhaarSampleBase64 = base64Encode(utf8.encode(sampleXml));
    _selectedAadhaarFileName = "aadhaar_offline_ekyc_1234.xml";
  }

  void _generateSamplePcc() {
    final pccSample = "POLICE_CLEARANCE_CERTIFICATE_NO_CRIMINAL_RECORD_VERIFIED_AUTHENTIC_SIH2026";
    _pccSampleBase64 = base64Encode(utf8.encode(pccSample));
    _selectedPccFileName = "police_clearance_cert_2026.pdf";
  }

  @override
  void dispose() {
    _shareCodeCtrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _handleConsent() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    await _workerService.submitBiometricConsent(widget.workerId);
    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccessSnackBar("consent_accepted".tr());
    }
  }

  Future<void> _handleAadhaarSubmit() async {
    if (_shareCodeCtrl.text.trim().length != 4) {
      _showErrorSnackBar("Please enter a valid 4-digit share code.");
      return;
    }
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    await _workerService.submitAadhaarOfflineKyc(
      workerId: widget.workerId,
      shareCode: _shareCodeCtrl.text.trim(),
      base64Data: _aadhaarSampleBase64!,
      fileName: _selectedAadhaarFileName,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccessSnackBar("aadhaar_verified_success".tr());
    }
  }

  Future<void> _runLivenessSequence() async {
    setState(() {
      _isLivenessActive = true;
      _livenessStep = 1; // Blink
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _livenessStep = 2); // Turn head
    HapticFeedback.lightImpact();

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _livenessStep = 3); // Smile
    HapticFeedback.lightImpact();

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _livenessStep = 4); // Passed
    HapticFeedback.heavyImpact();

    await _workerService.recordLivenessPass(
      workerId: widget.workerId,
      livenessScore: 0.985,
    );

    if (mounted) {
      _showSuccessSnackBar("liveness_passed".tr());
    }
  }

  Future<void> _handleScheduleVideoKyc() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    await _workerService.scheduleVideoKyc(
      workerId: widget.workerId,
      slotTime: _selectedSlotTime ?? DateTime.now().add(const Duration(hours: 2)),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccessSnackBar("Video KYC scheduled! Review challenge phrase in lobby.");
    }
  }

  Future<void> _handlePccUpload() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    await _workerService.uploadPccDocument(
      workerId: widget.workerId,
      base64Data: _pccSampleBase64!,
      docName: _selectedPccFileName,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccessSnackBar("Police Clearance submitted for cooperative review!");
    }
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: WorkGoFonts.body(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFF047857),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: WorkGoFonts.body(color: Colors.white))),
          ],
        ),
        backgroundColor: KX.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Worker?>(
      stream: _workerService.streamWorker(widget.workerId),
      builder: (context, snapshot) {
        final worker = snapshot.data;
        final stage = worker?.verificationStage ?? VerificationStage.signup;
        final details = worker?.verificationDetails;

        return KaryaScaffold(
          appBar: KaryaAppBar(
            title: "verification_hub_title".tr(),
            subtitle: "verification_hub_subtitle".tr(),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Stage Progress Indicator Stepper
                  KSlideFadeIn(
                    child: _buildStageStepper(stage),
                  ),
                  const SizedBox(height: 16),

                  // 2. Active Stage Action Card
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 60),
                    child: _buildActiveStageContent(stage, details),
                  ),
                  const SizedBox(height: 16),

                  // 3. Security & Legal Trust Guarantee
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 100),
                    child: _buildTrustGuaranteeCard(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Stage Stepper HUD ───────────────────────────────────────────────────────

  Widget _buildStageStepper(VerificationStage currentStage) {
    final stages = [
      {"stage": VerificationStage.signup, "label": "Consent", "icon": Icons.security_rounded},
      {"stage": VerificationStage.aadhaarOfflineEkyc, "label": "Aadhaar", "icon": Icons.fingerprint_rounded},
      {"stage": VerificationStage.selfieCapture, "label": "Liveness", "icon": Icons.face_rounded},
      {"stage": VerificationStage.liveVideoVerification, "label": "Video KYC", "icon": Icons.video_call_rounded},
      {"stage": VerificationStage.pccUpload, "label": "PCC Review", "icon": Icons.verified_user_rounded},
      {"stage": VerificationStage.approved, "label": "Certified", "icon": Icons.workspace_premium_rounded},
    ];

    int currentIndex = _getStageIndex(currentStage);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: KX.canvasCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KX.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SafeText(
                "IDENTITY VERIFICATION PIPELINE",
                style: WorkGoFonts.display(
                  color: KX.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: currentStage == VerificationStage.approved
                      ? const Color(0xFF047857).withValues(alpha: 0.2)
                      : KX.violet.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SafeText(
                  currentStage == VerificationStage.approved ? "VERIFIED" : "STAGE ${currentIndex + 1}/6",
                  style: TextStyle(
                    color: currentStage == VerificationStage.approved ? KX.emeraldLight : KX.violetLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(stages.length, (idx) {
              final isPassed = idx < currentIndex;
              final isCurrent = idx == currentIndex;

              return Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPassed
                          ? const Color(0xFF10B981)
                          : isCurrent
                              ? KX.gold
                              : Colors.white10,
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: KX.gold.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      isPassed
                          ? Icons.check_rounded
                          : (stages[idx]["icon"] as IconData),
                      color: isPassed || isCurrent ? const Color(0xFF090714) : Colors.white38,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SafeText(
                    stages[idx]["label"] as String,
                    style: TextStyle(
                      color: isCurrent ? KX.gold : isPassed ? Colors.white70 : Colors.white30,
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  int _getStageIndex(VerificationStage stage) {
    switch (stage) {
      case VerificationStage.signup:
        return 0;
      case VerificationStage.aadhaarOfflineEkyc:
        return 1;
      case VerificationStage.selfieCapture:
      case VerificationStage.onDeviceLiveness:
        return 2;
      case VerificationStage.liveVideoVerification:
        return 3;
      case VerificationStage.pccUpload:
      case VerificationStage.pccManualReview:
        return 4;
      case VerificationStage.approved:
        return 5;
      case VerificationStage.rejected:
        return 4;
    }
  }

  // ── Active Stage Content Builder ───────────────────────────────────────────

  Widget _buildActiveStageContent(VerificationStage stage, VerificationDetails? details) {
    if (stage == VerificationStage.signup) {
      return _buildStage1Consent();
    } else if (stage == VerificationStage.aadhaarOfflineEkyc) {
      return _buildStage2Aadhaar();
    } else if (stage == VerificationStage.selfieCapture || stage == VerificationStage.onDeviceLiveness) {
      return _buildStage3Liveness();
    } else if (stage == VerificationStage.liveVideoVerification) {
      return _buildStage4VideoKyc(details);
    } else if (stage == VerificationStage.pccUpload) {
      return _buildStage5PccUpload();
    } else if (stage == VerificationStage.pccManualReview) {
      return _buildStage6PccReview();
    } else if (stage == VerificationStage.approved) {
      return _buildStageApproved();
    } else {
      return _buildStageRejected(details);
    }
  }

  // ── Stage 1: DPDP Biometric Consent ────────────────────────────────────────

  Widget _buildStage1Consent() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: KX.violet.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.gavel_rounded, color: KX.violetLight, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      "dpdp_consent_title".tr(),
                      style: WorkGoFonts.display(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SafeText(
                      "Digital Personal Data Protection Act 2023",
                      style: TextStyle(color: KX.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SafeText(
            "dpdp_consent_desc".tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 18),
          WorkGoButton(
            label: "accept_consent_btn".tr(),
            icon: Icons.check_circle_outline_rounded,
            isLoading: _isLoading,
            onPressed: _handleConsent,
          ),
        ],
      ),
    );
  }

  // ── Stage 2: UIDAI Offline Aadhaar eKYC ─────────────────────────────────────

  Widget _buildStage2Aadhaar() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: KX.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fingerprint_rounded, color: KX.gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      "aadhaar_xml_title".tr(),
                      style: WorkGoFonts.display(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SafeText(
                      "Server-Side XML-DSig Signature Validation",
                      style: TextStyle(color: KX.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SafeText(
            "aadhaar_xml_desc".tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
          const SizedBox(height: 16),

          // File selection pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: KX.canvasElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_rounded, color: KX.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedAadhaarFileName ?? "Select XML/ZIP File",
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: KX.emerald, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Share Code Input
          Text(
            "share_code_label".tr(),
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _shareCodeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: "1234",
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: KX.canvasElevated,
              counterText: "",
              prefixIcon: const Icon(Icons.lock_rounded, color: KX.gold, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 18),

          WorkGoButton(
            label: "verify_aadhaar_btn".tr(),
            icon: Icons.verified_user_rounded,
            isLoading: _isLoading,
            onPressed: _handleAadhaarSubmit,
          ),
        ],
      ),
    );
  }

  // ── Stage 3: On-Device Liveness Gate ───────────────────────────────────────

  Widget _buildStage3Liveness() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFF00E5FF), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      "liveness_gate_title".tr(),
                      style: WorkGoFonts.display(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const SafeText(
                      "On-Device Anti-Spoofing & Blink Gate",
                      style: TextStyle(color: KX.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Camera Viewport Simulation
          Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: KX.canvasElevated,
                border: Border.all(
                  color: _livenessStep == 4
                      ? const Color(0xFF10B981)
                      : _isLivenessActive
                          ? const Color(0xFF00E5FF)
                          : Colors.white24,
                  width: 3,
                ),
                boxShadow: [
                  if (_isLivenessActive)
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    _livenessStep == 4 ? Icons.check_circle_rounded : Icons.face_rounded,
                    size: 84,
                    color: _livenessStep == 4 ? const Color(0xFF10B981) : Colors.white54,
                  ),
                  if (_isLivenessActive && _livenessStep < 4)
                    Positioned(
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xCC0D0A1C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getLivenessPrompt(),
                          style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          if (_livenessStep == 4) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF047857).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Liveness check passed (98.5% confidence). Advancing to Video KYC slot booking...",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            WorkGoButton(
              label: _isLivenessActive ? "Scanning Face..." : "start_liveness_btn".tr(),
              icon: Icons.camera_alt_rounded,
              isLoading: _isLivenessActive,
              onPressed: _isLivenessActive ? null : _runLivenessSequence,
            ),
          ],
        ],
      ),
    );
  }

  String _getLivenessPrompt() {
    switch (_livenessStep) {
      case 1:
        return "liveness_challenge_blink".tr();
      case 2:
        return "liveness_challenge_turn_left".tr();
      case 3:
        return "liveness_challenge_smile".tr();
      default:
        return "Hold steady";
    }
  }

  // ── Stage 4: Scheduled Video KYC ───────────────────────────────────────────

  Widget _buildStage4VideoKyc(VerificationDetails? details) {
    final phrase = details?.videoCallPhrase ?? "VIOLET-892-SUN";

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: KX.violetNeon.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.video_camera_front_rounded, color: KX.violetLight, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      "video_kyc_title".tr(),
                      style: WorkGoFonts.display(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const SafeText(
                      "Live Staff Call with Dynamic Challenge Phrase",
                      style: TextStyle(color: KX.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SafeText(
            "video_kyc_desc".tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Challenge Phrase Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KX.canvasElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KX.gold.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeText(
                  "challenge_phrase_label".tr().toUpperCase(),
                  style: const TextStyle(color: KX.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      phrase,
                      style: WorkGoFonts.display(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "Repeat this phrase clearly during your video call to prevent pre-recorded video injection.",
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          WorkGoButton(
            label: "schedule_video_kyc_btn".tr(),
            icon: Icons.calendar_month_rounded,
            isLoading: _isLoading,
            onPressed: _handleScheduleVideoKyc,
          ),
        ],
      ),
    );
  }

  // ── Stage 5: Police Clearance Certificate Upload ───────────────────────────

  Widget _buildStage5PccUpload() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      "pcc_upload_title".tr(),
                      style: WorkGoFonts.display(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const SafeText(
                      "Background Check & Police Clearance Review",
                      style: TextStyle(color: KX.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SafeText(
            "pcc_upload_desc".tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),

          // PCC File Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: KX.canvasElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedPccFileName ?? "police_clearance_cert.pdf",
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
              ],
            ),
          ),
          const SizedBox(height: 18),

          WorkGoButton(
            label: "upload_pcc_btn".tr(),
            icon: Icons.lock_rounded,
            isLoading: _isLoading,
            onPressed: _handlePccUpload,
          ),
        ],
      ),
    );
  }

  // ── Stage 6: PCC Under Staff Review ────────────────────────────────────────

  Widget _buildStage6PccReview() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KX.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_top_rounded, color: KX.gold, size: 36),
          ),
          const SizedBox(height: 14),
          SafeText(
            "pcc_under_review".tr(),
            style: WorkGoFonts.display(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SafeText(
            "Your Police Clearance Certificate is currently being verified by the Cooperative Governance desk. You will be notified immediately upon final approval.",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Stage Approved ─────────────────────────────────────────────────────────

  Widget _buildStageApproved() {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFF047857),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 14),
          SafeText(
            "stage_approved_title".tr(),
            style: WorkGoFonts.display(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SafeText(
            "stage_approved_desc".tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: KX.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KX.gold.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: KX.gold, size: 16),
                SizedBox(width: 6),
                Text(
                  "Co-op Certified Artisan · Public Visibility Active",
                  style: TextStyle(color: KX.gold, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stage Rejected ─────────────────────────────────────────────────────────

  Widget _buildStageRejected(VerificationDetails? details) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KX.rose.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.gpp_bad_rounded, color: KX.rose, size: 36),
          ),
          const SizedBox(height: 14),
          SafeText(
            "stage_rejected_title".tr(),
            style: WorkGoFonts.display(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SafeText(
            details?.pccRejectionReason ?? "Document mismatch detected. Please contact cooperative administration to resubmit verification documents.",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Trust Guarantee Box ────────────────────────────────────────────────────

  Widget _buildTrustGuaranteeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KX.canvasMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: KX.gold, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "All verification data is stored with AES-256 encryption. Raw biometric inputs are never shared or sold per DPDP Act 2023.",
              style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
