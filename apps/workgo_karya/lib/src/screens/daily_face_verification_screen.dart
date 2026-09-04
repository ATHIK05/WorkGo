import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

/// Full-screen Rapido/Uber-style 3D Face Verification before an artisan goes Online.
///
/// Verifies the artisan's live human face in real-time against their approved 3D KYC
/// selfie (`selfieCenterBase64`), preventing unauthorized account sharing or proxy dispatching.
class DailyFaceVerificationScreen extends StatefulWidget {
  final Worker worker;

  const DailyFaceVerificationScreen({
    super.key,
    required this.worker,
  });

  @override
  State<DailyFaceVerificationScreen> createState() => _DailyFaceVerificationScreenState();
}

class _DailyFaceVerificationScreenState extends State<DailyFaceVerificationScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  FaceDetector? _faceDetector;

  bool _isCameraInitialized = false;
  bool _hasCameraError = false;
  bool _isProcessingFrame = false;
  bool _isCapturing = false;
  bool _isVerifying = false;

  bool _isFaceAligned = false;
  String _alignmentPrompt = "Position your face in the oval";
  int _consecutiveAlignedFrames = 0;

  double _originalBrightness = 0.5;

  FaceComparisonResult? _comparisonResult;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initBrightnessBoost();
    _initDetector();
    _initCamera();
  }

  Future<void> _initBrightnessBoost() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        _originalBrightness = await ScreenBrightness().application;
        await ScreenBrightness().setApplicationScreenBrightness(1.0);
      }
    } catch (e) {
      debugPrint("[DailyFace] Brightness boost: $e");
    }
  }

  void _initDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        enableLandmarks: true,
        minFaceSize: 0.20,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _hasCameraError = true);
        return;
      }

      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() => _isCameraInitialized = true);

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _cameraController!.startImageStream(_processCameraFrame);
      }
    } catch (e) {
      debugPrint("[DailyFace] Camera error: $e");
      if (mounted) setState(() => _hasCameraError = true);
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _isCapturing || _isVerifying || _faceDetector == null) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _convertToInputImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) {
        _isProcessingFrame = false;
        return;
      }

      if (faces.isEmpty) {
        setState(() {
          _isFaceAligned = false;
          _alignmentPrompt = "No face detected. Look at the camera.";
          _consecutiveAlignedFrames = 0;
        });
        return;
      }

      if (faces.length > 1) {
        setState(() {
          _isFaceAligned = false;
          _alignmentPrompt = "Only 1 artisan should be in the frame!";
          _consecutiveAlignedFrames = 0;
        });
        return;
      }

      final face = faces.first;
      final headX = face.headEulerAngleX ?? 0.0;
      final headY = face.headEulerAngleY ?? 0.0;
      final headZ = face.headEulerAngleZ ?? 0.0;
      final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;

      bool aligned = true;
      String prompt = "Perfect! Hold still...";

      if (headY.abs() > 14.0) {
        aligned = false;
        prompt = headY > 0 ? "Turn head slightly to your LEFT" : "Turn head slightly to your RIGHT";
      } else if (headX.abs() > 14.0) {
        aligned = false;
        prompt = headX > 0 ? "Tilt your head slightly DOWN" : "Tilt your head slightly UP";
      } else if (headZ.abs() > 12.0) {
        aligned = false;
        prompt = "Keep your head upright";
      } else if (leftEyeOpen < 0.35 || rightEyeOpen < 0.35) {
        aligned = false;
        prompt = "Please keep both eyes open";
      }

      setState(() {
        _isFaceAligned = aligned;
        _alignmentPrompt = prompt;
      });

      if (aligned) {
        _consecutiveAlignedFrames++;
        if (_consecutiveAlignedFrames >= 3 && !_isCapturing && !_isVerifying) {
          _captureAndVerify();
        }
      } else {
        _consecutiveAlignedFrames = 0;
      }
    } catch (e) {
      debugPrint("[DailyFace] Frame processing error: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _convertToInputImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isAndroid || Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }
    rotation ??= InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _captureAndVerify() async {
    if (_isCapturing || _isVerifying || _cameraController == null || !_cameraController!.value.isInitialized) return;
    _isCapturing = true;
    setState(() => _isVerifying = true);
    HapticFeedback.heavyImpact();

    try {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }

      final XFile photo = await _cameraController!.takePicture();
      Uint8List bytes = await photo.readAsBytes();

      try {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 480,
          minHeight: 480,
          quality: 68,
          format: CompressFormat.jpeg,
        );
        if (compressed.isNotEmpty) {
          bytes = compressed;
        }
      } catch (_) {}

      final base64Live = base64Encode(bytes);
      await _executeFaceVerification(base64Live);
    } catch (e) {
      debugPrint("[DailyFace] Capture error: $e");
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = "Camera capture failed: $e";
        });
      }
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _executeFaceVerification(String liveBase64) async {
    final kycDetails = widget.worker.verificationDetails;
    final registeredKycFace = kycDetails?.selfieCenterBase64 ??
        kycDetails?.selfieBase64 ??
        kycDetails?.aadhaarPhotoBase64;

    // If no KYC face has been uploaded yet (e.g. test worker), enroll this capture as baseline
    if (registeredKycFace == null || registeredKycFace.trim().isEmpty) {
      debugPrint("[DailyFace] No registered KYC face found. Enrolling current capture as baseline.");
      await WorkerService().recordDailyFaceCheckIn(
        workerId: widget.worker.id,
        capturedFaceBase64: liveBase64,
        matchScore: 1.0,
      );

      if (!mounted) return;
      _onVerificationSuccess(1.0, "Initial reference face registered ✓");
      return;
    }

    // Perform live biometric comparison
    final result = await FaceComparisonService.instance.compareFaces(
      liveFaceBase64: liveBase64,
      registeredKycFaceBase64: registeredKycFace,
      threshold: 0.70,
    );

    if (!mounted) return;

    if (result.isMatch) {
      await WorkerService().recordDailyFaceCheckIn(
        workerId: widget.worker.id,
        capturedFaceBase64: liveBase64,
        matchScore: result.confidenceScore,
      );
      _onVerificationSuccess(result.confidenceScore, result.summary);
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _isVerifying = false;
        _comparisonResult = result;
        _errorMessage = "Face did not match approved 3D KYC profile (${result.confidencePercentage}% confidence). Please face the camera in good lighting.";
      });
    }
  }

  void _onVerificationSuccess(double score, String summary) {
    HapticFeedback.heavyImpact();
    setState(() {
      _isVerifying = false;
      _comparisonResult = FaceComparisonResult.match(confidence: score, summary: summary);
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  Future<void> _fallbackPickAndVerify() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() => _isVerifying = true);
        final bytes = await image.readAsBytes();
        final base64Live = base64Encode(bytes);
        await _executeFaceVerification(base64Live);
      }
    } catch (e) {
      debugPrint("[DailyFace] Photo picker error: $e");
    }
  }

  void _bypassForTesting() {
    Navigator.of(context).pop(true);
  }

  void _resumeCameraStream() async {
    setState(() {
      _errorMessage = null;
      _comparisonResult = null;
      _isFaceAligned = false;
      _consecutiveAlignedFrames = 0;
    });
    if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.startImageStream(_processCameraFrame);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _faceDetector?.close();
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream();
      }
      _cameraController!.dispose();
    }
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        ScreenBrightness().setApplicationScreenBrightness(_originalBrightness);
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = _comparisonResult != null && _comparisonResult!.isMatch;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            // ── 1. Top Header ───────────────────────────────────────────────
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Daily 3D Face Check",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          "Verifying identity against approved KYC profile",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 14),
                        SizedBox(width: 4),
                        Text(
                          "ANTI-PROXY",
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 2. Biometric Viewfinder Oval ────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) {
                      final scale = _isFaceAligned ? _pulseAnimation.value : 1.0;
                      Color borderColor = const Color(0xFFF59E0B);
                      if (isSuccess) {
                        borderColor = const Color(0xFF10B981);
                      } else if (_errorMessage != null) {
                        borderColor = const Color(0xFFEF4444);
                      } else if (_isFaceAligned) {
                        borderColor = const Color(0xFF10B981);
                      }

                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 250,
                          height: 330,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(140),
                            border: Border.all(color: borderColor, width: 3.5),
                            boxShadow: [
                              BoxShadow(
                                color: borderColor.withValues(alpha: 0.35),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(136),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_isCameraInitialized && _cameraController != null)
                                  CameraPreview(_cameraController!)
                                else
                                  Container(
                                    color: const Color(0xFF1E293B),
                                    child: const Center(
                                      child: CircularProgressIndicator(color: KaryaColors.brandYellow),
                                    ),
                                  ),

                                // Scanning Crosshair overlay
                                if (_isVerifying)
                                  Container(
                                    color: Colors.black45,
                                    child: const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 3),
                                          SizedBox(height: 14),
                                          Text(
                                            "Comparing with 3D KYC...",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Success Checkmark overlay
                                if (isSuccess)
                                  Container(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.85),
                                    child: const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 68),
                                          SizedBox(height: 10),
                                          Text(
                                            "IDENTITY VERIFIED ✓",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 22),

                  // Guidance Prompt Pill
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isFaceAligned
                          ? const Color(0xFF10B981).withValues(alpha: 0.18)
                          : (_errorMessage != null
                              ? const Color(0xFFEF4444).withValues(alpha: 0.18)
                              : const Color(0xFF1E293B)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isFaceAligned
                            ? const Color(0xFF10B981).withValues(alpha: 0.5)
                            : (_errorMessage != null
                                ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                                : Colors.white12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isFaceAligned
                              ? Icons.verified_rounded
                              : (_errorMessage != null
                                  ? Icons.error_outline_rounded
                                  : Icons.face_retouching_natural_rounded),
                          color: _isFaceAligned
                              ? const Color(0xFF10B981)
                              : (_errorMessage != null ? const Color(0xFFEF4444) : KaryaColors.brandYellow),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _errorMessage ?? _alignmentPrompt,
                            style: TextStyle(
                              color: _isFaceAligned
                                  ? const Color(0xFF10B981)
                                  : (_errorMessage != null ? const Color(0xFFEF4444) : Colors.white),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 3. Bottom Controls ──────────────────────────────────────────
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_errorMessage != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _resumeCameraStream,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text(
                          "Try Again",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: (_isCapturing || _isVerifying) ? null : _captureAndVerify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFaceAligned ? const Color(0xFF10B981) : KaryaColors.brandYellow,
                          foregroundColor: _isFaceAligned ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        icon: Icon(_isFaceAligned ? Icons.camera_alt_rounded : Icons.touch_app_rounded),
                        label: Text(
                          _isFaceAligned ? "Auto-Detecting... Or Tap to Verify" : "Verify My Face",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],

                  // Fallback options for testing / devices without cameras
                  if (_hasCameraError || kDebugMode) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _fallbackPickAndVerify,
                          icon: const Icon(Icons.photo_library_rounded, size: 16, color: Colors.white70),
                          label: const Text("Choose Photo", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _bypassForTesting,
                            icon: const Icon(Icons.developer_mode_rounded, size: 16, color: KaryaColors.brandYellow),
                            label: const Text("Bypass (Dev)", style: TextStyle(color: KaryaColors.brandYellow, fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
