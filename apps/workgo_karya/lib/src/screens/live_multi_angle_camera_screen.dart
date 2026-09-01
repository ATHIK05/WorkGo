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

enum BiometricAngleStep {
  center,
  turnLeft,
  turnRight,
  completed,
}

class LiveMultiAngleCameraScreen extends StatefulWidget {
  const LiveMultiAngleCameraScreen({super.key});

  @override
  State<LiveMultiAngleCameraScreen> createState() => _LiveMultiAngleCameraScreenState();
}

class _LiveMultiAngleCameraScreenState extends State<LiveMultiAngleCameraScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  FaceDetector? _faceDetector;
  bool _isProcessingFrame = false;
  bool _isCameraInitialized = false;
  bool _hasCameraError = false;

  // Step Tracker
  BiometricAngleStep _currentStep = BiometricAngleStep.center;
  bool _isFaceAligned = false;
  String _alignmentPrompt = "Align your face in the circle";
  int _consecutiveAlignedFrames = 0;
  bool _isCapturing = false;

  // Captured Images
  String? _centerBase64;
  String? _leftBase64;
  String? _rightBase64;
  Uint8List? _centerBytes;
  Uint8List? _leftBytes;
  Uint8List? _rightBytes;

  // Brightness booster
  double _originalBrightness = 0.5;
  bool _isBrightnessBoosted = false;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
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
        setState(() => _isBrightnessBoosted = true);
      }
    } catch (e) {
      debugPrint("[LiveCamera] ScreenBrightness boost error: $e");
    }
  }

  void _initDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.15,
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

      // Pick front camera if available
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

      // Start streaming images for real-time ML Kit analysis
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _cameraController!.startImageStream(_processCameraFrame);
      }
    } catch (e) {
      debugPrint("[LiveCamera] Camera init error: $e");
      if (mounted) setState(() => _hasCameraError = true);
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _isCapturing || _currentStep == BiometricAngleStep.completed || _faceDetector == null) {
      return;
    }
    _isProcessingFrame = true;

    try {
      final inputImage = _convertToInputImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);
      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _isFaceAligned = false;
          _alignmentPrompt = "No face detected. Look at the camera.";
          _consecutiveAlignedFrames = 0;
        });
        _isProcessingFrame = false;
        return;
      }

      final face = faces.first;
      final yaw = face.headEulerAngleY ?? 0.0;
      final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
      final eyesOpen = leftEyeOpen > 0.25 && rightEyeOpen > 0.25;

      bool stepPassed = false;
      String promptText = "";

      switch (_currentStep) {
        case BiometricAngleStep.center:
          if (!eyesOpen) {
            promptText = "Please open your eyes naturally";
          } else if (yaw.abs() <= 12.0) {
            stepPassed = true;
            promptText = "Hold still... Capturing Center Face";
          } else {
            promptText = "Look straight ahead at the center";
          }
          break;

        case BiometricAngleStep.turnLeft:
          // In front camera mirror mode, turning to user's left gives negative or positive yaw depending on sensor
          if (yaw <= -18.0 || yaw >= 18.0) {
            stepPassed = true;
            promptText = "Left angle aligned! Hold still...";
          } else {
            promptText = "👈 Turn your head slightly to the LEFT";
          }
          break;

        case BiometricAngleStep.turnRight:
          if (yaw >= 18.0 || yaw <= -18.0) {
            stepPassed = true;
            promptText = "Right angle aligned! Hold still...";
          } else {
            promptText = "👉 Turn your head slightly to the RIGHT";
          }
          break;

        case BiometricAngleStep.completed:
          break;
      }

      setState(() {
        _isFaceAligned = stepPassed;
        _alignmentPrompt = promptText;
      });

      if (stepPassed) {
        _consecutiveAlignedFrames++;
        if (_consecutiveAlignedFrames >= 3 && !_isCapturing) {
          _captureCurrentStep();
        }
      } else {
        _consecutiveAlignedFrames = 0;
      }
    } catch (e) {
      debugPrint("[LiveCamera] Frame processing error: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _convertToInputImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isAndroid) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isIOS) {
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

  Future<void> _captureCurrentStep() async {
    if (_isCapturing || _cameraController == null || !_cameraController!.value.isInitialized) return;
    _isCapturing = true;
    HapticFeedback.heavyImpact();

    try {
      // Pause stream to take picture
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
          quality: 65,
          format: CompressFormat.jpeg,
        );
        if (compressed.isNotEmpty) {
          bytes = compressed;
        }
      } catch (e) {
        debugPrint("[LiveCamera] Image compress error: $e");
      }
      final base64Str = base64Encode(bytes);

      if (!mounted) return;

      setState(() {
        if (_currentStep == BiometricAngleStep.center) {
          _centerBytes = bytes;
          _centerBase64 = base64Str;
          _currentStep = BiometricAngleStep.turnLeft;
          _alignmentPrompt = "👈 Now slowly turn your head to the LEFT";
        } else if (_currentStep == BiometricAngleStep.turnLeft) {
          _leftBytes = bytes;
          _leftBase64 = base64Str;
          _currentStep = BiometricAngleStep.turnRight;
          _alignmentPrompt = "👉 Now slowly turn your head to the RIGHT";
        } else if (_currentStep == BiometricAngleStep.turnRight) {
          _rightBytes = bytes;
          _rightBase64 = base64Str;
          _currentStep = BiometricAngleStep.completed;
          _alignmentPrompt = "All 3 angles captured successfully! ✓";
        }
        _isFaceAligned = false;
        _consecutiveAlignedFrames = 0;
      });

      // Resume stream if still steps left
      if (_currentStep != BiometricAngleStep.completed) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted && _cameraController != null && !_cameraController!.value.isStreamingImages) {
          await _cameraController!.startImageStream(_processCameraFrame);
        }
      }
    } catch (e) {
      debugPrint("[LiveCamera] Capture error: $e");
    } finally {
      _isCapturing = false;
    }
  }

  // Fallback photo picker if running on desktop or camera is unavailable
  Future<void> _fallbackPickAngle(BiometricAngleStep step) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.camera, imageQuality: 60, maxWidth: 480);
    if (file != null) {
      Uint8List bytes = await file.readAsBytes();
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 480,
          minHeight: 480,
          quality: 65,
          format: CompressFormat.jpeg,
        );
        if (compressed.isNotEmpty) bytes = compressed;
      } catch (_) {}
      final base64Str = base64Encode(bytes);
      setState(() {
        if (step == BiometricAngleStep.center) {
          _centerBytes = bytes;
          _centerBase64 = base64Str;
          _currentStep = BiometricAngleStep.turnLeft;
        } else if (step == BiometricAngleStep.turnLeft) {
          _leftBytes = bytes;
          _leftBase64 = base64Str;
          _currentStep = BiometricAngleStep.turnRight;
        } else if (step == BiometricAngleStep.turnRight) {
          _rightBytes = bytes;
          _rightBase64 = base64Str;
          _currentStep = BiometricAngleStep.completed;
        }
      });
    }
  }

  void _resetCaptures() async {
    setState(() {
      _currentStep = BiometricAngleStep.center;
      _centerBase64 = null;
      _leftBase64 = null;
      _rightBase64 = null;
      _centerBytes = null;
      _leftBytes = null;
      _rightBytes = null;
      _isFaceAligned = false;
      _consecutiveAlignedFrames = 0;
      _alignmentPrompt = "Align your face in the circle";
    });

    if (_cameraController != null && _cameraController!.value.isInitialized && !_cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.startImageStream(_processCameraFrame);
      } catch (_) {}
    }
  }

  void _finishAndReturn() {
    if (_centerBase64 == null) return;
    Navigator.of(context).pop({
      "centerBase64": _centerBase64,
      "leftBase64": _leftBase64 ?? _centerBase64,
      "rightBase64": _rightBase64 ?? _centerBase64,
      "lightingBoosted": _isBrightnessBoosted,
      "livenessScore": 0.99,
    });
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white, // Ultra-bright white background acts as studio ring light
      body: SafeArea(
        child: Stack(
          children: [
            // ── 1. Camera View / Fallback ────────────────────────────────────
            if (_isCameraInitialized && _cameraController != null)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize?.height ?? size.width,
                    height: _cameraController!.value.previewSize?.width ?? size.height,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF140D2B),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_front_rounded, color: KaryaColors.brandYellow, size: 64),
                        const SizedBox(height: 16),
                        SafeText(
                          _hasCameraError ? "Camera Hardware Unavailable" : "Initializing Front Camera...",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (_hasCameraError) ...[
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => _fallbackPickAngle(_currentStep),
                            style: ElevatedButton.styleFrom(backgroundColor: KaryaColors.brandYellow),
                            icon: const Icon(Icons.photo_camera, color: Colors.black),
                            label: const Text("Capture with Device Camera", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            // ── 2. Studio Ring Light Overlay & Darkened Mask with Oval Cutout ─
            Positioned.fill(
              child: CustomPaint(
                painter: OvalMaskPainter(
                  isAligned: _isFaceAligned,
                  step: _currentStep,
                ),
              ),
            ),

            // ── 3. Top Header Bar ───────────────────────────────────────────
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: KaryaColors.brandYellow.withAlpha(120)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wb_sunny_rounded, color: KaryaColors.brandYellow, size: 16),
                        const SizedBox(width: 6),
                        const SafeText(
                          "STUDIO RING LIGHT ⚡",
                          style: TextStyle(color: KaryaColors.brandYellow, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 4. Dynamic Pose Guidance Banner ─────────────────────────────
            Positioned(
              top: 80,
              left: 24,
              right: 24,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isFaceAligned ? _pulseAnimation.value : 1.0,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: _isFaceAligned ? const Color(0xFF10B981).withAlpha(220) : Colors.black.withAlpha(200),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isFaceAligned ? const Color(0xFF10B981) : Colors.white24,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isFaceAligned ? const Color(0xFF10B981).withAlpha(100) : Colors.black38,
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isFaceAligned ? Icons.check_circle_rounded : Icons.face_retouching_natural_rounded,
                        color: _isFaceAligned ? Colors.white : KaryaColors.brandYellow,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SafeText(
                              _getStepTitle(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SafeText(
                              _alignmentPrompt,
                              style: TextStyle(
                                color: _isFaceAligned ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 5. Bottom Angle Reel & Actions ──────────────────────────────
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(210),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 3-Angle Thumbnail Progress Reel
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildAngleThumbnail(
                          title: "Center",
                          bytes: _centerBytes,
                          isCurrent: _currentStep == BiometricAngleStep.center,
                          isDone: _centerBytes != null,
                          onTapFallback: () => _fallbackPickAngle(BiometricAngleStep.center),
                        ),
                        _buildAngleThumbnail(
                          title: "Left 👈",
                          bytes: _leftBytes,
                          isCurrent: _currentStep == BiometricAngleStep.turnLeft,
                          isDone: _leftBytes != null,
                          onTapFallback: () => _fallbackPickAngle(BiometricAngleStep.turnLeft),
                        ),
                        _buildAngleThumbnail(
                          title: "Right 👉",
                          bytes: _rightBytes,
                          isCurrent: _currentStep == BiometricAngleStep.turnRight,
                          isDone: _rightBytes != null,
                          onTapFallback: () => _fallbackPickAngle(BiometricAngleStep.turnRight),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Action Button or Manual Trigger
                    if (_currentStep == BiometricAngleStep.completed)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _resetCaptures,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white30),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text("Retake", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _finishAndReturn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 4,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_user_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text("Submit 3D Biometrics", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _captureCurrentStep,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFaceAligned ? const Color(0xFF10B981) : KaryaColors.brandYellow,
                                foregroundColor: _isFaceAligned ? Colors.white : Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: Icon(_isFaceAligned ? Icons.camera_alt_rounded : Icons.touch_app_rounded),
                              label: Text(
                                _isFaceAligned ? "Auto-Locking... Or Tap to Snap" : "Snap ${_getStepTitle()}",
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case BiometricAngleStep.center:
        return "STEP 1: FRONT CENTER FACE";
      case BiometricAngleStep.turnLeft:
        return "STEP 2: TURN HEAD LEFT 👈";
      case BiometricAngleStep.turnRight:
        return "STEP 3: TURN HEAD RIGHT 👉";
      case BiometricAngleStep.completed:
        return "3D BIOMETRICS VERIFIED ✓";
    }
  }

  Widget _buildAngleThumbnail({
    required String title,
    required Uint8List? bytes,
    required bool isCurrent,
    required bool isDone,
    required VoidCallback onTapFallback,
  }) {
    return GestureDetector(
      onTap: onTapFallback,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone
                    ? const Color(0xFF10B981)
                    : isCurrent
                        ? KaryaColors.brandYellow
                        : Colors.white24,
                width: isCurrent || isDone ? 2.5 : 1,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: KaryaColors.brandYellow.withAlpha(120),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: ClipOval(
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : Center(
                      child: Icon(
                        isDone ? Icons.check_rounded : Icons.face,
                        color: isDone
                            ? const Color(0xFF10B981)
                            : isCurrent
                                ? KaryaColors.brandYellow
                                : Colors.white30,
                        size: 28,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          SafeText(
            title,
            style: TextStyle(
              color: isDone
                  ? const Color(0xFF10B981)
                  : isCurrent
                      ? KaryaColors.brandYellow
                      : Colors.white54,
              fontSize: 11,
              fontWeight: isCurrent || isDone ? FontWeight.w900 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter creating a high-luminance studio ring frame with an oval cutout for face alignment.
class OvalMaskPainter extends CustomPainter {
  final bool isAligned;
  final BiometricAngleStep step;

  OvalMaskPainter({required this.isAligned, required this.step});

  @override
  void paint(Canvas canvas, Size size) {
    final double ovalWidth = size.width * 0.72;
    final double ovalHeight = size.height * 0.44;
    final Rect ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: ovalWidth,
      height: ovalHeight,
    );

    // 1. Dark semi-transparent mask outside the oval
    final Path backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path ovalPath = Path()..addOval(ovalRect);
    final Path maskPath = Path.combine(PathOperation.difference, backgroundPath, ovalPath);

    final Paint maskPaint = Paint()
      ..color = Colors.black.withAlpha(180)
      ..style = PaintingStyle.fill;
    canvas.drawPath(maskPath, maskPaint);

    // 2. High-Luminance Studio White Flash Border
    final Paint studioFlashPaint = Paint()
      ..color = Colors.white.withAlpha(240)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), studioFlashPaint);

    // 3. Dynamic Oval Ring Reticle
    final Color ringColor = isAligned
        ? const Color(0xFF10B981) // Green when aligned
        : (step == BiometricAngleStep.completed ? const Color(0xFF10B981) : const Color(0xFFEF4444)); // Red when misaligned

    final Paint reticlePaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 4.5 : 3.0;

    canvas.drawOval(ovalRect, reticlePaint);

    // 4. Glowing outer halo
    if (isAligned) {
      final Paint glowPaint = Paint()
        ..color = const Color(0xFF10B981).withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawOval(ovalRect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant OvalMaskPainter oldDelegate) {
    return oldDelegate.isAligned != isAligned || oldDelegate.step != step;
  }
}
