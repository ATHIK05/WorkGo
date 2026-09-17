import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

/// Refer Dial Karya Member — Peer KYC Screen
///
/// Implements the 4-stage pipeline for a verified smartphone artisan
/// to KYC-verify a nearby feature-phone / dial worker in person.
///
/// Stage 1 — Face Photo Capture
/// Stage 2 — Trade & Tools Inspection Checklist
/// Stage 3 — Identity Document (Aadhaar/e-Shram) Photo
/// Stage 4 — OTP Handshake (spoken by Bhashini to dial worker's phone)
///
/// On completion: submits to /api/ivr/voice/peer-kyc/submit → ₹150 credited.

class ReferDialMemberScreen extends StatefulWidget {
  final Worker mitraWorker;
  final String dialWorkerId;
  final String dialWorkerName;
  final String dialWorkerPhone;
  final String dialWorkerTrade;
  final String? dialWorkerLocation;
  final String? dialWorkerTradeDescription;
  final String backendBaseUrl;

  const ReferDialMemberScreen({
    super.key,
    required this.mitraWorker,
    required this.dialWorkerId,
    required this.dialWorkerName,
    required this.dialWorkerPhone,
    required this.dialWorkerTrade,
    this.dialWorkerLocation,
    this.dialWorkerTradeDescription,
    required this.backendBaseUrl,
  });

  @override
  State<ReferDialMemberScreen> createState() => _ReferDialMemberScreenState();
}

class _ReferDialMemberScreenState extends State<ReferDialMemberScreen>
    with SingleTickerProviderStateMixin {
  // ── Stage management ──────────────────────────────────────────────────────
  int _currentStage = 0; // 0–3 (4 stages)
  bool _isSubmitting = false;
  bool _isComplete = false;

  // ── Stage 1: Face photo ───────────────────────────────────────────────────
  String? _facePhotoBase64;
  CameraController? _cameraController;
  bool _cameraReady = false;

  // ── Stage 2: Tools checklist ──────────────────────────────────────────────
  final Map<String, bool> _toolsChecklist = {};
  static const Map<String, Map<String, List<String>>> _tradeTools = {
    'plumbing': {
      'tools': [
        'Pipe wrench',
        'Pipe cutter',
        'Teflon tape',
        'Basin wrench',
        'Plunger',
      ]
    },
    'electrical': {
      'tools': [
        'Multimeter',
        'Wire stripper',
        'Screwdriver set',
        'Electrical tape',
        'Circuit tester',
      ]
    },
    'carpentry': {
      'tools': ['Hammer', 'Chisel set', 'Hand saw', 'Tape measure', 'Level']
    },
    'painting': {
      'tools': ['Paint roller', 'Brushes', 'Putty knife', 'Masking tape', 'Drop cloth']
    },
    'cleaning': {
      'tools': ['Mop & bucket', 'Cleaning agents', 'Scrub brush', 'Gloves', 'Vacuum/broom']
    },
    'general': {
      'tools': ['Basic hand tools', 'Measuring tape', 'Work gloves', 'Safety shoes']
    },
  };

  // ── Stage 3: Document photo ───────────────────────────────────────────────
  String? _documentPhotoBase64;

  // ── Stage 4: OTP handshake ────────────────────────────────────────────────
  final _otpController = TextEditingController();
  bool _otpSent = false;

  // ── Submission state ──────────────────────────────────────────────────────
  String? _errorMessage;
  double _walletNewBalance = 0;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _successAnimCtrl;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _initTools();
    _successAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _successScale = CurvedAnimation(
      parent: _successAnimCtrl,
      curve: Curves.elasticOut,
    );
  }

  void _initTools() {
    final trade = widget.dialWorkerTrade.toLowerCase();
    final tools = _tradeTools[trade]?['tools'] ?? _tradeTools['general']!['tools']!;
    for (final tool in tools) {
      _toolsChecklist[tool] = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _otpController.dispose();
    _successAnimCtrl.dispose();
    super.dispose();
  }

  // ── Camera helpers ────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(
      front,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  Future<void> _capturePhoto({required bool isDocument}) async {
    try {
      if (_cameraController == null || !_cameraReady) {
        await _initCamera();
      }
      final image = await _cameraController!.takePicture();
      final bytes = await File(image.path).readAsBytes();
      final b64 = base64Encode(bytes);
      setState(() {
        if (isDocument) {
          _documentPhotoBase64 = b64;
        } else {
          _facePhotoBase64 = b64;
        }
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  // ── OTP: Request flash-call ───────────────────────────────────────────────
  Future<void> _requestOtpFlashCall() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final uri = Uri.parse('${widget.backendBaseUrl}/api/ivr/voice/peer-kyc/accept');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mitraWorkerId': widget.mitraWorker.id,
          'dialWorkerPhone': widget.dialWorkerPhone,
          'language': 'hi',
        }),
      );
      if (res.statusCode == 200) {
        setState(() {
          _otpSent = true;
          _errorMessage = null;
        });
      } else {
        setState(() => _errorMessage = 'Failed to send OTP. Try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ── Final submission ──────────────────────────────────────────────────────
  Future<void> _submitKyc() async {
    final enteredOtp = _otpController.text.trim();
    if (enteredOtp.length != 4) {
      setState(() => _errorMessage = 'err_enter_otp'.trSafe('Please enter the 4-digit OTP.'));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('${widget.backendBaseUrl}/api/ivr/voice/peer-kyc/submit');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mitraWorkerId': widget.mitraWorker.id,
          'dialWorkerPhone': widget.dialWorkerPhone,
          'enteredOtp': enteredOtp,
          'photoBase64': _facePhotoBase64,
          'toolsChecklist':
              _toolsChecklist.entries.where((e) => e.value).map((e) => e.key).toList(),
          'documentPhotoBase64': _documentPhotoBase64,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _walletNewBalance = (data['newMitraBalance'] as num?)?.toDouble() ?? 0;
          _isComplete = true;
        });
        _successAnimCtrl.forward();
      } else {
        final data = jsonDecode(res.body);
        setState(() => _errorMessage = data['error'] ?? 'err_verification_failed'.trSafe('Verification failed.'));
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _nextStage() {
    if (_currentStage == 3) {
      _submitKyc();
      return;
    }
    // Validation per stage
    if (_currentStage == 0 && _facePhotoBase64 == null) {
      setState(() => _errorMessage = 'err_face_photo_required'.trSafe('Please capture the dial worker\'s face photo first.'));
      return;
    }
    if (_currentStage == 1) {
      final checked = _toolsChecklist.values.where((v) => v).length;
      if (checked < 2) {
        setState(() => _errorMessage = 'err_tools_minimum'.trSafe('Please verify at least 2 tools to confirm trade skills.'));
        return;
      }
    }
    if (_currentStage == 2 && _documentPhotoBase64 == null) {
      setState(() => _errorMessage = 'err_doc_photo_required'.trSafe('Please capture the identity document photo.'));
      return;
    }

    setState(() {
      _currentStage++;
      _errorMessage = null;
    });
  }

  void _prevStage() {
    if (_currentStage > 0) setState(() => _currentStage--);
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KX.canvas,
      body: SafeArea(
        child: _isComplete ? _buildSuccessView() : _buildPipelineView(),
      ),
    );
  }

  // ── Success view ──────────────────────────────────────────────────────────
  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _successScale,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [KX.emerald, KX.emeraldLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: KX.emerald.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'peer_kyc_complete_title'.trSafe('Peer KYC Complete! 🎉'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: KX.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'peer_kyc_complete_sub'.trSafe(
                '${widget.dialWorkerName} is now a verified Dial Karya member!',
                [widget.dialWorkerName],
              ),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: KX.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: KX.luminaVioletGold,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: KX.brandAmber.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'bounty_credited'.trSafe('₹150 Credited!'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        'wallet_balance_prefix'.trSafe(
                          'Wallet balance: ₹${_walletNewBalance.toStringAsFixed(0)}',
                          [_walletNewBalance.toStringAsFixed(0)],
                        ),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home_rounded),
              label: Text('back_to_home'.trSafe('Back to Home')),
              style: FilledButton.styleFrom(
                backgroundColor: KX.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pipeline view ─────────────────────────────────────────────────────────
  Widget _buildPipelineView() {
    return Column(
      children: [
        _buildHeader(),
        _buildStageBreadcrumb(),
        Expanded(child: _buildCurrentStage()),
        if (_errorMessage != null) _buildErrorBanner(),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: KX.canvasCard,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _currentStage > 0 ? _prevStage() : Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: KX.canvasMid,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _currentStage > 0 ? Icons.arrow_back_ios_rounded : Icons.close_rounded,
                size: 20,
                color: KX.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'peer_kyc_verification_title'.trSafe('Peer KYC Verification'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: KX.textPrimary,
                  ),
                ),
                Text(
                  [
                    widget.dialWorkerName,
                    widget.dialWorkerTrade.toUpperCase(),
                    if (widget.dialWorkerLocation != null && widget.dialWorkerLocation!.isNotEmpty)
                      widget.dialWorkerLocation!,
                  ].join(' • '),
                  style: TextStyle(color: KX.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: KX.luminaVioletGold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '₹150',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageBreadcrumb() {
    final stageLabels = [
      'stage_face_photo'.trSafe('Face Photo'),
      'stage_tools_check'.trSafe('Tools Check'),
      'stage_document'.trSafe('Document'),
      'stage_otp'.trSafe('OTP'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: KX.canvasMid,
      child: Row(
        children: List.generate(4, (i) {
          final isActive = i == _currentStage;
          final isDone = i < _currentStage;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? KX.emerald
                              : isActive
                                  ? KX.violet
                                  : KX.canvasCard,
                          border: Border.all(
                            color: isActive ? KX.violet : KX.dividerLight,
                            width: isActive ? 2 : 1,
                          ),
                          boxShadow: isActive
                              ? [BoxShadow(color: KX.violet.withValues(alpha: 0.3), blurRadius: 8)]
                              : null,
                        ),
                        child: Icon(
                          isDone ? Icons.check_rounded : _stageIcon(i),
                          color: isDone || isActive ? Colors.white : KX.textMuted,
                          size: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stageLabels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                          color: isActive ? KX.violet : KX.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      color: i < _currentStage ? KX.emerald : KX.dividerLight,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  IconData _stageIcon(int stage) {
    switch (stage) {
      case 0:
        return Icons.face_retouching_natural_rounded;
      case 1:
        return Icons.construction_rounded;
      case 2:
        return Icons.badge_rounded;
      case 3:
        return Icons.dialpad_rounded;
      default:
        return Icons.circle;
    }
  }

  Widget _buildCurrentStage() {
    switch (_currentStage) {
      case 0:
        return _buildStage1FacePhoto();
      case 1:
        return _buildStage2ToolsChecklist();
      case 2:
        return _buildStage3DocumentPhoto();
      case 3:
        return _buildStage4OtpHandshake();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Stage 1: Face Photo ───────────────────────────────────────────────────
  Widget _buildStage1FacePhoto() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageTitle(
            icon: Icons.face_retouching_natural_rounded,
            title: 'stage1_face_photo_title'.trSafe('Capture Face Photo'),
            subtitle: 'stage1_face_photo_sub'.trSafe(
              'Ask ${widget.dialWorkerName} to look directly at the camera. Ensure good lighting.',
              [widget.dialWorkerName],
            ),
          ),
          const SizedBox(height: 20),
          if (_facePhotoBase64 != null) ...[
            // Preview captured photo
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(
                base64Decode(_facePhotoBase64!),
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            _buildPhotoApprovedBadge('stage1_face_photo_captured'.trSafe('Face photo captured ✓')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _capturePhoto(isDocument: false),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('retake_photo'.trSafe('Retake Photo')),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: KX.violet),
                foregroundColor: KX.violet,
              ),
            ),
          ] else ...[
            // Camera preview area
            if (_cameraReady && _cameraController != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 260,
                  child: CameraPreview(_cameraController!),
                ),
              ),
              const SizedBox(height: 16),
              _buildCaptureButton(
                label: 'stage1_face_photo_title'.trSafe('Capture Face Photo'),
                onTap: () => _capturePhoto(isDocument: false),
              ),
            ] else ...[
              _buildCameraPlaceholder(
                onTap: () async {
                  setState(() => _errorMessage = null);
                  await _initCamera();
                },
                label: 'open_camera'.trSafe('Open Camera'),
                icon: Icons.camera_alt_rounded,
              ),
            ],
          ],
          const SizedBox(height: 16),
          _buildInfoBox(
            'tips_face_photo'.trSafe('📸 Tips: Face should be clearly visible. Avoid shadows and blur.'),
          ),
        ],
      ),
    );
  }

  // ── Stage 2: Tools Checklist ──────────────────────────────────────────────
  Widget _buildStage2ToolsChecklist() {
    final checkedCount = _toolsChecklist.values.where((v) => v).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageTitle(
            icon: Icons.construction_rounded,
            title: 'stage2_tools_title'.trSafe('Tools & Skills Inspection'),
            subtitle: 'stage2_tools_sub'.trSafe(
              'Verify that ${widget.dialWorkerName} has the required ${widget.dialWorkerTrade} tools. Check ✓ tools you can physically see.',
              [widget.dialWorkerName, widget.dialWorkerTrade],
            ),
          ),
          if (widget.dialWorkerTradeDescription != null &&
              widget.dialWorkerTradeDescription!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.record_voice_over_rounded,
                    size: 16,
                    color: Color(0xFFB45309),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Artisan's Spoken Description:",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '"${widget.dialWorkerTradeDescription}"',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: checkedCount >= 2 ? KX.emerald : KX.violet,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'tools_verified_count'.trSafe(
                    '$checkedCount / ${_toolsChecklist.length} verified',
                    ['$checkedCount', '${_toolsChecklist.length}'],
                  ),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              if (checkedCount >= 2) ...[
                const SizedBox(width: 8),
                Text('tools_minimum_met'.trSafe('✓ Minimum met'), style: const TextStyle(color: KX.emerald, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          ..._toolsChecklist.entries.map((entry) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: entry.value ? KX.pastelMint : KX.canvasCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: entry.value ? KX.emerald.withValues(alpha: 0.4) : KX.dividerLight,
                ),
                boxShadow: entry.value
                    ? [BoxShadow(color: KX.emerald.withValues(alpha: 0.1), blurRadius: 8)]
                    : null,
              ),
              child: CheckboxListTile(
                value: entry.value,
                onChanged: (val) {
                  setState(() => _toolsChecklist[entry.key] = val ?? false);
                  HapticFeedback.selectionClick();
                },
                title: Text(
                  entry.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: entry.value ? KX.emerald : KX.textPrimary,
                  ),
                ),
                activeColor: KX.emerald,
                checkColor: Colors.white,
                controlAffinity: ListTileControlAffinity.leading,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Stage 3: Document Photo ───────────────────────────────────────────────
  Widget _buildStage3DocumentPhoto() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageTitle(
            icon: Icons.badge_rounded,
            title: 'stage3_doc_title'.trSafe('Identity Document Photo'),
            subtitle: 'stage3_doc_sub'.trSafe(
              'Photograph ${widget.dialWorkerName}\'s Aadhaar card, e-Shram card, or any Govt ID. Ensure all text is legible.',
              [widget.dialWorkerName],
            ),
          ),
          const SizedBox(height: 20),
          if (_documentPhotoBase64 != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(
                base64Decode(_documentPhotoBase64!),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            _buildPhotoApprovedBadge('stage3_doc_captured'.trSafe('Document photo captured ✓')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _capturePhoto(isDocument: true),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('retake_photo'.trSafe('Retake')),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: KX.violet),
                foregroundColor: KX.violet,
              ),
            ),
          ] else ...[
            if (_cameraReady && _cameraController != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 220,
                  child: CameraPreview(_cameraController!),
                ),
              ),
              const SizedBox(height: 16),
              _buildCaptureButton(
                label: 'capture_doc'.trSafe('Capture Document'),
                onTap: () => _capturePhoto(isDocument: true),
              ),
            ] else ...[
              _buildCameraPlaceholder(
                onTap: () async {
                  setState(() => _errorMessage = null);
                  await _initCamera();
                },
                label: 'open_camera_for_doc'.trSafe('Open Camera for Document'),
                icon: Icons.document_scanner_rounded,
              ),
            ],
          ],
          const SizedBox(height: 16),
          _buildInfoBox(
            'tips_identity_doc'.trSafe('🪪 Accepted: Aadhaar Card, e-Shram Card, Voter ID, PAN Card. All 4 corners must be visible.'),
          ),
        ],
      ),
    );
  }

  // ── Stage 4: OTP Handshake ────────────────────────────────────────────────
  Widget _buildStage4OtpHandshake() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageTitle(
            icon: Icons.dialpad_rounded,
            title: 'stage4_otp_title'.trSafe('OTP Handshake'),
            subtitle: 'stage4_otp_sub'.trSafe(
              'A 4-digit code will be spoken aloud on ${widget.dialWorkerPhone}. Ask ${widget.dialWorkerName} to tell you the code and enter it below.',
              [widget.dialWorkerPhone, widget.dialWorkerName],
            ),
          ),
          const SizedBox(height: 24),
          if (!_otpSent) ...[
            // Trigger OTP flash-call
            _buildPrimaryButton(
              label: 'call_with_otp_btn'.trSafe('📞 Call ${widget.dialWorkerPhone} with OTP', [widget.dialWorkerPhone]),
              onTap: _isSubmitting ? null : _requestOtpFlashCall,
              isLoading: _isSubmitting,
            ),
            const SizedBox(height: 12),
            _buildInfoBox(
              'call_with_otp_info'.trSafe(
                '📞 When you tap above, a call is placed to ${widget.dialWorkerName}\'s phone with a spoken 4-digit verification code. The caller hears it twice.',
                [widget.dialWorkerName],
              ),
            ),
          ] else ...[
            // OTP sent — show success indicator
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: KX.pastelMint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KX.emerald.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.call_made_rounded, color: KX.emerald),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'otp_call_placed'.trSafe(
                        'OTP call placed to ${widget.dialWorkerPhone}. Ask ${widget.dialWorkerName} for the code.',
                        [widget.dialWorkerPhone, widget.dialWorkerName],
                      ),
                      style: TextStyle(color: KX.emerald, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // OTP Entry field
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: KX.canvasCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'enter_4digit_otp'.trSafe('Enter 4-digit OTP'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: KX.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                      color: KX.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '• • • •',
                      hintStyle: TextStyle(color: KX.textMuted, letterSpacing: 12, fontSize: 28),
                      filled: true,
                      fillColor: KX.canvasMid,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Resend link
            GestureDetector(
              onTap: _isSubmitting ? null : _requestOtpFlashCall,
              child: Text(
                'resend_otp_call'.trSafe('Didn\'t receive? Call again'),
                style: TextStyle(
                  color: KX.violet,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────
  Widget _buildStageTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: KX.luminaVioletGold,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: KX.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: KX.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCameraPlaceholder({
    required VoidCallback onTap,
    required String label,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: KX.canvasMid,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KX.dividerLight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: KX.textMuted),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: KX.violet,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text('Tap to open camera', style: TextStyle(color: KX.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton({required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.camera_alt_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: KX.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildPhotoApprovedBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: KX.pastelMint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KX.emerald.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: KX.emerald, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: KX.emerald, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KX.canvasElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KX.brandAmber.withValues(alpha: 0.2)),
      ),
      child: Text(
        message,
        style: TextStyle(color: KX.textSecondary, fontSize: 13, height: 1.5),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onTap != null ? KX.luminaVioletGold : null,
          color: onTap == null ? KX.textMuted : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap != null
              ? [BoxShadow(color: KX.brandAmber.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KX.rose.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KX.rose.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: KX.rose, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: KX.rose, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: Icon(Icons.close_rounded, color: KX.rose, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final labels = [
      'next_tools_check'.trSafe('Next: Tools Check'),
      'next_document'.trSafe('Next: Document'),
      'next_otp'.trSafe('Next: OTP'),
      'submit_claim_bounty_btn'.trSafe('✓ Submit & Claim ₹150'),
    ];
    final isLastStage = _currentStage == 3;
    final canSubmit = isLastStage && _otpSent && _otpController.text.length == 4;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: _buildPrimaryButton(
        label: isLastStage ? 'submit_claim_bounty_btn'.trSafe('✓ Submit & Claim ₹150') : labels[_currentStage],
        onTap: (_isSubmitting || (isLastStage && !canSubmit)) ? null : _nextStage,
        isLoading: _isSubmitting,
      ),
    );
  }
}
