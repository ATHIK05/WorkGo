import 'dart:convert';
import 'dart:io' show File;
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:http/http.dart' as http;
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';
import 'live_multi_angle_camera_screen.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({
    super.key,
    required this.workerId,
    this.initialVerificationStatus = VerificationStatus.pending,
    // Contextual parameters for Assisted Dial Peer-KYC:
    this.isPeerKyc = false,
    this.mitraWorker,
    this.dialWorkerName,
    this.dialWorkerPhone,
    this.dialWorkerTrade,
    this.dialWorkerLocation,
    this.dialWorkerTradeDescription,
    this.backendBaseUrl = const String.fromEnvironment(
      'BACKEND_BASE_URL',
      defaultValue: 'https://workgo-api.onrender.com',
    ),
  });

  final String workerId;
  final VerificationStatus initialVerificationStatus;
  final bool isPeerKyc;
  final Worker? mitraWorker;
  final String? dialWorkerName;
  final String? dialWorkerPhone;
  final String? dialWorkerTrade;
  final String? dialWorkerLocation;
  final String? dialWorkerTradeDescription;
  final String backendBaseUrl;

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
  // QR scan state (primary path)
  bool _aadhaarQrDone = false; // QR scan succeeded
  int _aadhaarTabIndex = 0; // 0 = QR Scan, 1 = Offline Zip, 2 = Card Photo
  bool _editingAadhaar = false;
  final TextEditingController _shareCodeCtrl = TextEditingController(
    text: "1234",
  );
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

  // ── Stage 5: e-Shram State ───────────────────────────────────────────────────
  bool _eshramDone = false;
  int _eshramTrustScore = 0;

  // ── Peer-KYC Specific State (Dial Feature-Phone Worker) ───────────────────
  final Map<String, bool> _toolsChecklist = {};
  static const Map<String, Map<String, List<String>>> _tradeTools = {
    'plumbing': {
      'tools': [
        'Pipe wrench',
        'Pipe cutter',
        'Teflon tape',
        'Basin wrench',
        'Plunger',
      ],
    },
    'electrical': {
      'tools': [
        'Multimeter',
        'Wire stripper',
        'Screwdriver set',
        'Electrical tape',
        'Circuit tester',
      ],
    },
    'carpentry': {
      'tools': ['Hammer', 'Chisel set', 'Hand saw', 'Tape measure', 'Level'],
    },
    'painting': {
      'tools': [
        'Paint roller',
        'Brushes',
        'Putty knife',
        'Masking tape',
        'Drop cloth',
      ],
    },
    'cleaning': {
      'tools': [
        'Mop & bucket',
        'Cleaning agents',
        'Scrub brush',
        'Gloves',
        'Vacuum/broom',
      ],
    },
    'general': {
      'tools': [
        'Basic hand tools',
        'Measuring tape',
        'Work gloves',
        'Safety shoes',
      ],
    },
  };

  String _getLocalizedToolName(String tool) {
    final clean = tool
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'tool_$clean'.trSafe(tool);
  }

  final TextEditingController _peerOtpCtrl = TextEditingController();
  bool _peerOtpCalling = false;
  bool _peerOtpSent = false;
  String? _receivedOtpCode;
  bool _peerKycCompleted = false;
  double _mitraNewBalance = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isPeerKyc) {
      final trade = (widget.dialWorkerTrade ?? 'general').toLowerCase();
      final tools =
          _tradeTools[trade]?['tools'] ?? _tradeTools['general']!['tools']!;
      for (final tool in tools) {
        _toolsChecklist[tool] = false;
      }
    }
  }

  @override
  void dispose() {
    _shareCodeCtrl.dispose();
    _peerOtpCtrl.dispose();
    super.dispose();
  }

  // ── Real Actions ────────────────────────────────────────────────────────────

  Future<void> _handleConsent() async {
    if (!_consentAgreed) {
      _showErrorSnackBar("Please check the consent box to proceed.");
      return;
    }

    // When in Peer-KYC mode: Mitra records informed in-person verbal & physical consent
    if (widget.isPeerKyc) {
      setState(() => _isLoading = true);
      HapticFeedback.mediumImpact();
      try {
        await _workerService.submitBiometricConsent(
          widget.workerId,
          consentVersion: "DPDP_2023_PEER_MITRA_WITNESSED_v1.0",
        );
        if (mounted) {
          _showSuccessSnackBar(
            "In-person DPDP consent recorded & witnessed by Mitra! ✓",
          );
        }
      } catch (e) {
        if (mounted) _showErrorSnackBar("Failed to record consent: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    // Native OS Biometric (Fingerprint / Face ID) hardware authentication prompt for Self-KYC
    final authenticated = await BiometricService().authenticate(
      reason:
          "Scan your fingerprint or face to authorize DPDP 2023 Biometric Consent.",
    );

    if (!authenticated) {
      if (mounted) {
        _showErrorSnackBar(
          "Biometric verification cancelled. Scan your fingerprint to record consent.",
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    try {
      await _workerService.submitBiometricConsent(widget.workerId);
      if (mounted) {
        _showSuccessSnackBar(
          "Biometric consent & fingerprint verified successfully! ✓",
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar("Failed to record consent: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Peer-KYC Flash Call & Completion Actions ──────────────────────────────
  Future<void> _requestPeerOtpCall() async {
    final phone = widget.dialWorkerPhone;
    if (phone == null || phone.isEmpty) {
      _showErrorSnackBar(
        "err_dial_worker_phone_missing".trSafe(
          "Dial worker phone number is missing.",
        ),
      );
      return;
    }

    setState(() => _peerOtpCalling = true);
    HapticFeedback.lightImpact();

    try {
      final uri = Uri.parse(
        '${widget.backendBaseUrl}/api/ivr/voice/peer-kyc/accept',
      );
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mitraWorkerId': widget.mitraWorker?.id ?? '',
          'dialWorkerPhone': phone,
          'language': context.locale.languageCode,
        }),
      );

      if (res.statusCode == 200) {
        String? otp;
        try {
          final data = jsonDecode(res.body);
          if (data is Map && data['otpCode'] != null) {
            otp = data['otpCode'].toString();
          }
        } catch (_) {}
        setState(() {
          _peerOtpSent = true;
          _receivedOtpCode = otp;
        });
        _showSuccessSnackBar(
          "voice_otp_robocall_placed".trSafe(
            "Voice OTP robocall placed! Dial worker's phone is ringing.",
          ),
        );
      } else {
        _showErrorSnackBar(
          "voice_otp_call_failed".trSafe(
            "Failed to trigger Voice OTP call. Ensure Asterisk is running.",
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar(
        "${'voice_otp_call_failed'.trSafe('Failed to trigger Voice OTP call. Ensure Asterisk is running.')}: $e",
      );
    } finally {
      if (mounted) setState(() => _peerOtpCalling = false);
    }
  }

  Future<void> _submitPeerKycCompletion() async {
    final enteredOtp = _peerOtpCtrl.text.trim();
    if (enteredOtp.length != 4) {
      _showErrorSnackBar(
        "err_enter_otp".trSafe(
          "Please enter the 4-digit OTP spoken on the dial worker's phone.",
        ),
      );
      return;
    }

    if (_centerBase64 == null) {
      _showErrorSnackBar(
        "err_complete_3d_face".trSafe(
          "Please complete 3D Face Liveness (Step 3) first.",
        ),
      );
      return;
    }

    final checkedTools = _toolsChecklist.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (checkedTools.isEmpty) {
      _showErrorSnackBar(
        "err_tools_minimum_1".trSafe(
          "Please physically verify at least 1 trade tool.",
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();

    try {
      final uri = Uri.parse(
        '${widget.backendBaseUrl}/api/ivr/voice/peer-kyc/submit',
      );
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mitraWorkerId': widget.mitraWorker?.id ?? '',
          'dialWorkerPhone': widget.dialWorkerPhone ?? '',
          'enteredOtp': enteredOtp,
          'photoBase64': _centerBase64,
          'toolsChecklist': checkedTools,
          'documentPhotoBase64': _aadhaarBase64 ?? _centerBase64,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _peerKycCompleted = true;
          _mitraNewBalance = (data['newMitraBalance'] as num?)?.toDouble() ?? 0;
        });
        _showSuccessSnackBar(
          "peer_kyc_approved_snack".trSafe(
            "Peer-KYC Approved! ₹150 Credited to your Mitra wallet! 🎉",
          ),
        );
      } else {
        final data = jsonDecode(res.body);
        _showErrorSnackBar(
          data['error'] ??
              "err_verification_failed".trSafe(
                "Verification failed. Check OTP and retry.",
              ),
        );
      }
    } catch (e) {
      _showErrorSnackBar("Failed to complete Peer-KYC: $e");
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
        final ext =
            file.extension?.toLowerCase() ??
            (nameLower.contains('.') ? nameLower.split('.').last : '');
        const validExts = ['zip', 'xml', 'pdf', 'jpg', 'jpeg', 'png', 'webp'];
        if (ext.isNotEmpty && !validExts.contains(ext)) {
          _showErrorSnackBar(
            "Please select a .zip, .xml, .pdf, or image file.",
          );
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
          final isZipOrXml =
              nameLower.endsWith('.zip') || nameLower.endsWith('.xml');
          final isImg =
              nameLower.endsWith('.jpg') ||
              nameLower.endsWith('.jpeg') ||
              nameLower.endsWith('.png') ||
              nameLower.endsWith('.webp');

          setState(() {
            _selectedAadhaarFileName = file.name;
            _selectedAadhaarFileSize =
                "${(bytes!.length / 1024).toStringAsFixed(1)} KB";
            _isAadhaarZip = isZipOrXml;
            _aadhaarPreviewBytes = isImg ? bytes : null;
            _aadhaarBase64 = base64Encode(bytes);
          });
          HapticFeedback.lightImpact();
        } else {
          _showErrorSnackBar(
            "Could not read file data. Please ensure the file is downloaded to your device.",
          );
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
          _selectedAadhaarFileName = file.name.isNotEmpty
              ? file.name
              : "aadhaar_card.jpg";
          _selectedAadhaarFileSize =
              "${(bytes.length / 1024).toStringAsFixed(1)} KB";
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
      _showErrorSnackBar(
        "Please select or capture your Aadhaar document first.",
      );
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
        fileName:
            _selectedAadhaarFileName ??
            (_aadhaarTabIndex == 0
                ? "offline_aadhaar.zip"
                : "aadhaar_card.jpg"),
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
        builder: (_) => LiveMultiAngleCameraScreen(
          initialLensDirection: widget.isPeerKyc
              ? CameraLensDirection.back
              : CameraLensDirection.front,
        ),
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
          _showErrorSnackBar(
            "Biometrics captured with scrutiny flags. Proceeding to Police Clearance.",
          );
        } else {
          _showSuccessSnackBar(
            "3D Biometric Liveness Verified Successfully! ✓",
          );
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
        final ext =
            file.extension?.toLowerCase() ??
            (nameLower.contains('.') ? nameLower.split('.').last : '');
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
          final isImg =
              nameLower.endsWith('.jpg') ||
              nameLower.endsWith('.jpeg') ||
              nameLower.endsWith('.png') ||
              nameLower.endsWith('.webp');

          setState(() {
            _selectedPccFileName = file.name;
            _selectedPccFileSize =
                "${(bytes!.length / 1024).toStringAsFixed(1)} KB";
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
          _selectedPccFileName = file.name.isNotEmpty
              ? file.name
              : "pcc_certificate.jpg";
          _selectedPccFileSize =
              "${(bytes.length / 1024).toStringAsFixed(1)} KB";
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
      _showErrorSnackBar(
        "Please select your Police Clearance Certificate first.",
      );
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
        _showSuccessSnackBar(
          "Police Clearance submitted for cooperative review!",
        );
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
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
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
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
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
      backgroundColor: KX.canvas,
      appBar: AppBar(
        backgroundColor: KX.canvas,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF0EDE6)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: KX.textPrimary,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeText(
              widget.isPeerKyc
                  ? "assisted_peer_kyc".trSafe("Assisted Peer-KYC")
                  : "verification_hub_title".tr(),
              style: WorkGoFonts.heading(
                color: KX.textPrimary,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.15,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.isPeerKyc
                    ? KX.brandAmber.withAlpha(25)
                    : const Color(0xFF10B981).withAlpha(16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.isPeerKyc
                      ? KX.brandAmber.withAlpha(90)
                      : const Color(0xFF10B981).withAlpha(45),
                  width: 0.7,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: widget.isPeerKyc
                          ? KX.brandAmber
                          : const Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      widget.isPeerKyc
                          ? "mitra_vouching_hub_sub".trSafe(
                              "Mitra Vouching Hub • ₹150 Bounty",
                            )
                          : "UIDAI & Cooperative Trust Hub",
                      style: WorkGoFonts.body(
                        color: widget.isPeerKyc
                            ? const Color(0xFFB45309)
                            : const Color(0xFF047857),
                        fontSize: 9.8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: KX.textSecondary),
            color: KX.canvasCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (val) async {
              if (val == "reset_step2") {
                await _workerService.resetVerificationStage(
                  widget.workerId,
                  stage: VerificationStage.aadhaarOfflineEkyc,
                );
                _showSuccessSnackBar(
                  "reset_step2_msg".trSafe(
                    "Reset to Step 2: UIDAI Offline e-KYC",
                  ),
                );
              } else if (val == "reset_all") {
                await _workerService.resetVerificationStage(
                  widget.workerId,
                  stage: VerificationStage.consent,
                );
                _showSuccessSnackBar(
                  "reset_step1_msg".trSafe("Reset to Step 1: Consent"),
                );
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: "reset_step2",
                child: Row(
                  children: [
                    const Icon(Icons.replay_rounded, color: KX.gold, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'redo_aadhaar_ekyc'.trSafe(
                          "Re-do Aadhaar eKYC (Step 2)",
                        ),
                        style: const TextStyle(
                          color: KX.textPrimary,
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: "reset_all",
                child: Row(
                  children: [
                    const Icon(
                      Icons.restart_alt_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'restart_verification_step1'.trSafe(
                          "Restart Verification (Step 1)",
                        ),
                        style: const TextStyle(
                          color: KX.textPrimary,
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
            final isApproved =
                worker?.verificationStatus == VerificationStatus.approved;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Dial Member Context Identity Card (When in Peer-KYC mode) ──
                  if (widget.isPeerKyc) _buildPeerKycHeaderCard(worker),

                  // ── 5-Signal Trust Index ─────────────────────────────────
                  if (worker != null) ...[
                    _buildTrustStatusCard(worker),
                    const SizedBox(height: 24),
                  ],

                  // ── Step 1: DPDP 2023 Biometric Consent ───────────────────────
                  _buildConsentCard(stage),
                  const SizedBox(height: 20),

                  // ── Step 2: Aadhaar Identity (QR primary + XML fallback) ──────
                  _buildAadhaarCard(stage, worker),
                  const SizedBox(height: 20),

                  // ── Step 2b: Trade & Tools Physical Inspection (Peer-KYC only) ─────
                  if (widget.isPeerKyc) ...[
                    _buildToolsInspectionCard(),
                    const SizedBox(height: 20),
                  ],

                  // ── Step 2c: e-Shram (recommended) ───────────────────────────
                  if (stage.index >= VerificationStage.selfieCapture.index)
                    _buildEshramCard(worker),
                  if (stage.index >= VerificationStage.selfieCapture.index)
                    const SizedBox(height: 20),

                  // ── Step 3: 3D Multi-Angle Biometric Liveness ────────────────
                  _build3DMultiAngleCard(stage, worker),
                  const SizedBox(height: 20),

                  // ── Step 4: Police Clearance Certificate (PCC) ───────────────
                  _buildPccCard(stage, worker),
                  const SizedBox(height: 20),

                  // ── Step 5: Verification & Co-op Certification / Peer-KYC Approval ─
                  if (widget.isPeerKyc)
                    _buildPeerKycActivationCard(stage, worker, isApproved)
                  else
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

  // ── Peer-KYC Header Banner Card ──────────────────────────────────────────
  Widget _buildPeerKycHeaderCard(Worker? worker) {
    final dialName =
        widget.dialWorkerName ??
        worker?.name ??
        'dial_karya_badge'.trSafe('Dial Worker');
    final dialTrade =
        widget.dialWorkerTrade ??
        worker?.skills.firstOrNull ??
        'artisan'.trSafe('Artisan');
    final dialPhone = widget.dialWorkerPhone ?? worker?.phoneForCalling ?? '';
    final dialLocation = widget.dialWorkerLocation ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: KX.brandAmber.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: KX.brandAmber.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.handshake_rounded,
                      color: KX.brandAmber,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'assisted_peer_kyc_badge'.trSafe('ASSISTED PEER-KYC'),
                      style: WorkGoFonts.body(
                        color: KX.brandAmber,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'mitra_bounty_badge'.trSafe('₹150 Mitra Bounty'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dialName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        dialTrade.toUpperCase(),
                        if (dialPhone.isNotEmpty) dialPhone,
                      ].join(' • '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (dialLocation.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        dialLocation,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (widget.dialWorkerTradeDescription != null &&
              widget.dialWorkerTradeDescription!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.record_voice_over_rounded,
                    color: KX.brandAmber,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${widget.dialWorkerTradeDescription}"',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Peer-KYC Tools Physical Inspection Card ──────────────────────────────
  Widget _buildToolsInspectionCard() {
    final checkedCount = _toolsChecklist.values.where((v) => v).length;
    final total = _toolsChecklist.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KX.canvasCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: checkedCount >= 1
              ? const Color(0xFF10B981).withAlpha(120)
              : const Color(0xFFF0EDE6),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: checkedCount >= 1
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.construction_rounded,
                  color: checkedCount >= 1
                      ? const Color(0xFF065F46)
                      : const Color(0xFF92400E),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'tools_inspection_title'.trSafe(
                        'Physical Tools Inspection',
                      ),
                      style: WorkGoFonts.heading(
                        color: KX.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      checkedCount >= 1
                          ? 'tools_verified_fraction'.trSafe(
                              '$checkedCount / $total Tools Verified ✓',
                              ['$checkedCount', '$total'],
                            )
                          : 'verify_artisan_equipment'.trSafe(
                              'Verify Artisan Equipment',
                            ),
                      style: TextStyle(
                        color: checkedCount >= 1
                            ? const Color(0xFF10B981)
                            : const Color(0xFFB45309),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'stage2_tools_sub'.trSafe(
              'Verify that ${widget.dialWorkerName ?? "artisan"} has the required tools. Check ✓ tools you can physically see.',
              [
                widget.dialWorkerName ?? 'artisan'.trSafe('the artisan'),
                widget.dialWorkerTrade ?? 'trade'.trSafe('trade'),
              ],
            ),
            style: const TextStyle(
              color: KX.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ..._toolsChecklist.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: entry.value
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: entry.value
                      ? const Color(0xFF10B981).withAlpha(100)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: CheckboxListTile(
                dense: true,
                value: entry.value,
                onChanged: (val) {
                  setState(() => _toolsChecklist[entry.key] = val ?? false);
                  HapticFeedback.selectionClick();
                },
                title: Text(
                  _getLocalizedToolName(entry.key),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: entry.value
                        ? const Color(0xFF065F46)
                        : KX.textPrimary,
                  ),
                ),
                activeColor: const Color(0xFF10B981),
                checkColor: Colors.white,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Peer-KYC Activation & Voice OTP Card ─────────────────────────────────
  Widget _buildPeerKycActivationCard(
    VerificationStage stage,
    Worker? worker,
    bool isApproved,
  ) {
    if (_peerKycCompleted || isApproved) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'peer_kyc_complete_title'.trSafe('Peer KYC Complete! 🎉'),
              style: WorkGoFonts.heading(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'peer_kyc_complete_sub'.trSafe(
                '${widget.dialWorkerName ?? "Dial artisan"} is now a verified Dial Karya member!',
                [
                  widget.dialWorkerName ??
                      'dial_karya_badge'.trSafe('Dial artisan'),
                ],
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: KX.brandAmber,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'bounty_credited'.trSafe('₹150 Credited!'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      if (_mitraNewBalance > 0)
                        Text(
                          'wallet_balance_prefix'.trSafe(
                            'Wallet balance: ₹${_mitraNewBalance.toStringAsFixed(0)}',
                            [_mitraNewBalance.toStringAsFixed(0)],
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: KX.brandAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                'back_to_home'.trSafe('Back to Home'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }

    final phone = widget.dialWorkerPhone ?? worker?.phoneForCalling ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KX.canvasCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: KX.brandAmber.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.dialpad_rounded,
                  color: Color(0xFFB45309),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'voice_otp_handshake_title'.trSafe(
                        'Voice OTP Handshake & ₹150 Bounty',
                      ),
                      style: WorkGoFonts.heading(
                        color: KX.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'voice_otp_handshake_step'.trSafe(
                        'Step 5 of 5 • Final Handshake',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFB45309),
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
          Text(
            'voice_otp_handshake_desc'.trSafe(
              'To prevent fraudulent profiles and confirm physical presence, an automated IVR call will speak a 4-digit verification code to $phone.',
              [phone],
            ),
            style: const TextStyle(
              color: KX.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (!_peerOtpSent) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _peerOtpCalling ? null : _requestPeerOtpCall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KX.brandAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _peerOtpCalling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.phone_in_talk_rounded),
                label: Text(
                  _peerOtpCalling
                      ? 'placing_voice_call'.trSafe('Placing Voice Call...')
                      : 'call_dial_worker_otp'.trSafe(
                          'Call Dial Worker with OTP',
                        ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.ring_volume_rounded,
                    color: Color(0xFF065F46),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'otp_call_placed'.trSafe(
                        'Call placed to $phone. Ask ${widget.dialWorkerName ?? "the artisan"} for the 4-digit code.',
                        [
                          phone,
                          widget.dialWorkerName ??
                              'artisan'.trSafe('the artisan'),
                        ],
                      ),
                      style: const TextStyle(
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _peerOtpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 10,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '• • • •',
                hintStyle: const TextStyle(
                  letterSpacing: 10,
                  color: Colors.black26,
                ),
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF10B981),
                    width: 2,
                  ),
                ),
              ),
            ),
            if (_receivedOtpCode != null && _receivedOtpCode!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    _peerOtpCtrl.text = _receivedOtpCode!;
                    setState(() {});
                  },
                  icon: const Icon(
                    Icons.verified_user_rounded,
                    size: 16,
                    color: Color(0xFF10B981),
                  ),
                  label: Text(
                    "Handshake Code: $_receivedOtpCode (Tap to autofill)",
                    style: const TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _peerOtpCalling ? null : _requestPeerOtpCall,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    'resend_otp_call'.trSafe('Didn\'t receive? Call again'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitPeerKycCompletion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_rounded),
                    label: Text(
                      'submit_claim_bounty_btn'.trSafe(
                        '✓ Approve & Claim ₹150',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── 1. DPDP 2023 Consent Card ───────────────────────────────────────────────
  Widget _buildConsentCard(VerificationStage stage) {
    final isDone = stage.index >= VerificationStage.aadhaarOfflineEkyc.index;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KX.canvasCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withAlpha(120)
              : const Color(0xFFF0EDE6),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
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
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDone ? Icons.verified_user_rounded : Icons.shield_rounded,
                  color: isDone
                      ? const Color(0xFF065F46)
                      : const Color(0xFF92400E),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      widget.isPeerKyc
                          ? "dpdp_consent_peer_title".trSafe(
                              "DPDP 2023 Informed Consent (In-Person)",
                            )
                          : "dpdp_consent_title".tr(),
                      style: const TextStyle(
                        color: KX.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SafeText(
                      isDone
                          ? "consent_accepted_badge".trSafe(
                              "Consent Accepted & Timestamped ✓",
                            )
                          : widget.isPeerKyc
                          ? "dpdp_consent_peer_step".trSafe(
                              "Step 1 of 5 • Mitra Witnessed",
                            )
                          : "step_1_of_4".trSafe("Step 1 of 4"),
                      style: TextStyle(
                        color: isDone
                            ? const Color(0xFF10B981)
                            : const Color(0xFFB45309),
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
            widget.isPeerKyc
                ? "dpdp_consent_peer_desc".trSafe(
                    "I confirm that {} was informed of data collection (UIDAI QR, face photo, tools) and provided in-person verbal consent under the DPDP Act 2023.",
                    [widget.dialWorkerName ?? 'artisan'.trSafe('the artisan')],
                  )
                : "dpdp_consent_desc".tr(),
            style: const TextStyle(
              color: KX.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Itemized Permission Points
          _buildConsentBullet(
            Icons.camera_alt_rounded,
            "dpdp_consent_item_camera".tr(),
          ),
          _buildConsentBullet(
            Icons.badge_rounded,
            "dpdp_consent_item_aadhaar".tr(),
          ),
          _buildConsentBullet(
            Icons.local_police_rounded,
            "dpdp_consent_item_pcc".tr(),
          ),

          if (!isDone) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Checkbox(
                  value: _consentAgreed,
                  activeColor: KaryaColors.brandYellow,
                  checkColor: Colors.black,
                  onChanged: (val) =>
                      setState(() => _consentAgreed = val ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _consentAgreed = !_consentAgreed),
                    child: SafeText(
                      widget.isPeerKyc
                          ? "dpdp_consent_peer_checkbox".trSafe(
                              "I certify that {} is physically present and gave informed consent.",
                              [
                                widget.dialWorkerName ??
                                    'worker_role'.trSafe('the worker'),
                              ],
                            )
                          : "dpdp_consent_checkbox".tr(),
                      style: const TextStyle(
                        color: KX.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : SafeText(
                        widget.isPeerKyc
                            ? "Record In-Person Consent (Witnessed by Mitra)"
                            : "accept_consent_btn".tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
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
          Icon(icon, color: const Color(0xFF6B6B6B), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: SafeText(
              text,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab helper ─────────────────────────────────────────────────────────────
  Widget _buildAadhaarTab(int index, String label) {
    final isSelected = _aadhaarTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _aadhaarTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? KaryaColors.brandYellow : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : const Color(0xFF4B5563),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ── Trust Status Card ────────────────────────────────────────────────────────
  Widget _buildTrustStatusCard(Worker worker) {
    final vd = worker.verificationDetails;
    final signals = TrustSignals(
      phone:
          worker.phoneForCalling != null && worker.phoneForCalling!.isNotEmpty,
      aadhaar:
          vd?.aadhaarQrVerified == true ||
          vd?.aadhaarVerifiedAt != null ||
          _aadhaarQrDone,
      liveness: vd?.livenessPassedAt != null,
      eshram:
          _eshramDone || (vd?.eshramUan != null && vd!.eshramUan!.isNotEmpty),
      pcc: vd?.pccDocumentId != null && vd?.pccReviewedAt != null,
    );
    final score = _eshramTrustScore > 0
        ? _eshramTrustScore
        : (worker.trustScore > 0
              ? worker.trustScore
              : [
                  signals.phone,
                  signals.aadhaar,
                  signals.liveness,
                  signals.eshram,
                  signals.pcc,
                ].where((b) => b).length);

    return TrustStatusCard(
      trustScore: score,
      signals: signals,
      workerName: widget.isPeerKyc
          ? (widget.dialWorkerName ?? worker.name)
          : worker.name,
    );
  }

  // ── e-Shram Recommended Card ──────────────────────────────────────────────────
  Widget _buildEshramCard(Worker? worker) {
    final vd = worker?.verificationDetails;
    final alreadyLinked =
        _eshramDone || (vd?.eshramUan != null && vd!.eshramUan!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KX.canvasCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: alreadyLinked
              ? const Color(0xFF10B981).withAlpha(120)
              : KX.dividerLight,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: alreadyLinked
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.how_to_reg_rounded,
                  color: alreadyLinked
                      ? const Color(0xFF065F46)
                      : const Color(0xFF92400E),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      "eshram_title".tr(),
                      style: const TextStyle(
                        color: KX.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SafeText(
                      alreadyLinked
                          ? "eshram_linked_status".tr()
                          : "eshram_recommended_status".tr(),
                      style: TextStyle(
                        color: alreadyLinked
                            ? const Color(0xFF10B981)
                            : const Color(0xFFB45309),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Recommended badge
              if (!alreadyLinked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SafeText(
                    "eshram_recommended_badge".tr(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
            ],
          ),
          if (!alreadyLinked) ...[
            const SizedBox(height: 16),
            EshramCardWidget(
              workerId: widget.workerId,
              declaredTrade: worker?.skills.isNotEmpty == true
                  ? worker!.skills.first
                  : null,
              onSuccess: (score) {
                setState(() {
                  _eshramDone = true;
                  _eshramTrustScore = score;
                });
              },
              onSkip: () {},
            ),
          ],
        ],
      ),
    );
  }

  // ── 3. Aadhaar Offline eKYC Card with Step-by-Step Guide ────────────────────
  Widget _buildAadhaarCard(VerificationStage stage, Worker? worker) {
    final isDone = stage.index > VerificationStage.aadhaarOfflineEkyc.index;
    final isCurrent = stage == VerificationStage.aadhaarOfflineEkyc;
    final maskedUid =
        worker?.verificationDetails?.aadhaarMaskedNumber ?? "XXXXXXXX4821";
    final verifiedName =
        worker?.verificationDetails?.aadhaarVerifiedName ?? worker?.name ?? "";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KX.canvasCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withAlpha(120)
              : isCurrent
              ? KX.gold.withAlpha(120)
              : const Color(0xFFF0EDE6),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
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
                      ? const Color(0xFFD1FAE5)
                      : isCurrent
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  color: isDone
                      ? const Color(0xFF065F46)
                      : isCurrent
                      ? const Color(0xFF92400E)
                      : const Color(0xFF9CA3AF),
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
                      style: const TextStyle(
                        color: KX.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
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
                            ? const Color(0xFFB45309)
                            : const Color(0xFF6B6B6B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDone)
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _editingAadhaar = !_editingAadhaar),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  icon: Icon(
                    _editingAadhaar ? Icons.close_rounded : Icons.edit_rounded,
                    size: 14,
                  ),
                  label: Text(
                    _editingAadhaar ? "Close" : "Change",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
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
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xFFB45309),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SafeText(
                          "aadhaar_guide_title".tr(),
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SafeText(
                    "aadhaar_guide_step1".tr(),
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SafeText(
                    "aadhaar_guide_step2".tr(),
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SafeText(
                    "aadhaar_guide_step3".tr(),
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SafeText(
                    "aadhaar_guide_step4".tr(),
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openUidaiPortal,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF92400E),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: SafeText(
                        "open_uidai_portal_btn".tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Method tabs: QR Scan / Offline Zip / Card Photo ─────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildAadhaarTab(0, "aadhaar_tab_qr".tr()),
                  const SizedBox(width: 6),
                  _buildAadhaarTab(1, "upload_zip_tab".tr()),
                  const SizedBox(width: 6),
                  _buildAadhaarTab(2, "upload_photo_tab".tr()),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Tab 0: QR Scan (primary) ─────────────────────────────────────
            if (_aadhaarTabIndex == 0) ...[
              if (_aadhaarQrDone)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF86EFAC),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "aadhaar_verified_badge".tr(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                )
              else
                AadhaarQrScanner(
                  workerId: widget.workerId,
                  onSuccess: () {
                    setState(() => _aadhaarQrDone = true);
                    HapticFeedback.heavyImpact();
                  },
                  onFallback: () {
                    setState(() {
                      _aadhaarTabIndex = 1;
                    });
                  },
                  onError: (e) => _showErrorSnackBar(e),
                ),
            ],

            // Share Code Input (only for XML / photo tabs)
            if (_aadhaarTabIndex > 0) ...[
              TextField(
                controller: _shareCodeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(
                  color: KX.textPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
                decoration: InputDecoration(
                  labelText: "share_code_label".tr(),
                  hintText: "share_code_hint".tr(),
                  labelStyle: const TextStyle(color: KX.textSecondary),
                  counterText: "",
                  filled: true,
                  fillColor: const Color(0xFFF9F6EE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFF0EDE6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: KX.gold, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // File / Photo Picker Trigger
            if (_aadhaarTabIndex == 1) ...[
              // ── Offline Zip Tab ──
              if (_selectedAadhaarFileName != null && _isAadhaarZip) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
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
                        child: const Icon(
                          Icons.folder_zip_rounded,
                          color: Color(0xFF065F46),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedAadhaarFileName!,
                              style: const TextStyle(
                                color: Color(0xFF065F46),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${_selectedAadhaarFileSize ?? 'UIDAI Zip'} · Ready for verification",
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _pickAadhaarFile,
                        child: Text(
                          'change_btn'.trSafe("Change"),
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.folder_zip_rounded, size: 20),
                    label: const Text(
                      "Select UIDAI Offline Zip (.zip / .xml)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ] else if (_aadhaarTabIndex == 2) ...[
              // ── Card Photo Tab ──
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickAadhaarImage(ImageSource.gallery),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        foregroundColor: const Color(0xFF1A1A1A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(
                        Icons.photo_library_rounded,
                        color: Color(0xFF4B5563),
                      ),
                      label: Text(
                        _selectedAadhaarFileName ?? "upload_aadhaar_file".tr(),
                        overflow: TextOverflow.ellipsis,
                      ),
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
                    child: Image.memory(
                      _aadhaarPreviewBytes!,
                      fit: BoxFit.cover,
                    ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : SafeText(
                        "verify_aadhaar_btn".tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
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
    final hasBiometricsInDb =
        details?.selfieCenterBase64 != null ||
        details?.selfieBase64 != null ||
        details?.livenessPassedAt != null ||
        stage.index >= VerificationStage.pccUpload.index;
    final isDone = hasBiometricsInDb;
    final isCurrent =
        !isDone &&
        (stage == VerificationStage.selfieCapture ||
            stage == VerificationStage.onDeviceLiveness ||
            stage == VerificationStage.multiAngleLiveness);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KX.canvasCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withAlpha(120)
              : isCurrent
              ? KX.gold.withAlpha(120)
              : const Color(0xFFF0EDE6),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
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
                      ? const Color(0xFFD1FAE5)
                      : isCurrent
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.face_retouching_natural_rounded,
                  color: isDone
                      ? const Color(0xFF065F46)
                      : isCurrent
                      ? const Color(0xFF92400E)
                      : const Color(0xFF9CA3AF),
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
                      style: const TextStyle(
                        color: KX.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
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
                            ? const Color(0xFFB45309)
                            : const Color(0xFF6B6B6B),
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
                    foregroundColor: const Color(0xFFB45309),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: Text(
                    'retake_btn'.trSafe("Retake"),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          if (isCurrent) ...[
            const SizedBox(height: 14),
            SafeText(
              "multi_angle_liveness_desc".tr(),
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),

            // Captured Photo Preview Grid (Center, Left, Right)
            if (_centerBytes != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPreviewThumb(
                    'biometric_angle_center'.trSafe("Center"),
                    _centerBytes!,
                  ),
                  _buildPreviewThumb(
                    'biometric_angle_left'.trSafe("Left"),
                    _leftBytes ?? _centerBytes!,
                  ),
                  _buildPreviewThumb(
                    'biometric_angle_right'.trSafe("Right"),
                    _rightBytes ?? _centerBytes!,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _start3DMultiAngleCamera,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A1A1A),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        'retake_btn'.trSafe("Retake"),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        'save_continue_btn'.trSafe("Save & Continue"),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.camera_front_rounded),
                  label: SafeText(
                    "start_liveness_btn".tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
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
          child: ClipOval(child: Image.memory(bytes, fit: BoxFit.cover)),
        ),
        const SizedBox(height: 4),
        SafeText(
          title,
          style: const TextStyle(
            color: Color(0xFF047857),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── 5. Police Clearance Certificate (PCC) Card ──────────────────────────────
  Widget _buildPccCard(VerificationStage stage, Worker? worker) {
    final isDone =
        stage == VerificationStage.approved ||
        stage == VerificationStage.pccManualReview;
    final isCurrent = stage == VerificationStage.pccUpload;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KX.canvasCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withAlpha(120)
              : isCurrent
              ? KX.gold.withAlpha(120)
              : const Color(0xFFF0EDE6),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
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
                      ? const Color(0xFFD1FAE5)
                      : isCurrent
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_police_rounded,
                  color: isDone
                      ? const Color(0xFF065F46)
                      : isCurrent
                      ? const Color(0xFF92400E)
                      : const Color(0xFF9CA3AF),
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
                      style: const TextStyle(
                        color: KX.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
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
                            ? const Color(0xFFB45309)
                            : const Color(0xFF6B6B6B),
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
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickPccFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      foregroundColor: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(
                      Icons.upload_file_rounded,
                      color: Color(0xFF4B5563),
                    ),
                    label: Text(
                      _selectedPccFileName ?? "upload_pcc_btn".tr(),
                      overflow: TextOverflow.ellipsis,
                    ),
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
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_rounded,
                      color: Color(0xFF065F46),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "${_selectedPccFileName!} (${_selectedPccFileSize ?? 'Document'})",
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : SafeText(
                        'submit_coop_cert_btn'.trSafe(
                          "Submit for Cooperative Certification",
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 6. Certification & C2PA Trust Status Card ───────────────────────────────
  Widget _buildCertificationStatusCard(
    VerificationStage stage,
    Worker? worker,
    bool isApproved,
  ) {
    if (!isApproved &&
        stage != VerificationStage.approved &&
        stage != VerificationStage.pccManualReview) {
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
                isApproved
                    ? Icons.verified_rounded
                    : Icons.hourglass_top_rounded,
                color: isApproved
                    ? const Color(0xFF10B981)
                    : KaryaColors.brandYellow,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      isApproved
                          ? "stage_approved_title".tr()
                          : "pcc_under_review".tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SafeText(
                      isApproved
                          ? "c2pa_badge_title".tr()
                          : "Cooperative Officer Audit in Progress",
                      style: TextStyle(
                        color: isApproved
                            ? const Color(0xFF34D399)
                            : KaryaColors.brandYellow,
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
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
