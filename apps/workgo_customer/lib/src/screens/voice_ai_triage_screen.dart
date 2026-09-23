import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
import '../services/voice_recognition_service.dart';
import 'symptom_triage_sheet.dart';

/// Next-Generation Light-Themed Voice AI Triage Screen.
/// Features sound-reactive multi-layered parametric acoustic ribbons that surge high
/// with user speech pitch/volume and sink low into a calm harmonic ripple during silence.
class VoiceAiTriageScreen extends StatefulWidget {
  final AppUser user;
  final double? customerLat;
  final double? customerLng;
  final String? customerAddress;

  const VoiceAiTriageScreen({
    super.key,
    required this.user,
    this.customerLat,
    this.customerLng,
    this.customerAddress,
  });

  static Future<void> show(
    BuildContext context, {
    required AppUser user,
    double? customerLat,
    double? customerLng,
    String? customerAddress,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, anim, secondaryAnim) => FadeTransition(
          opacity: anim,
          child: VoiceAiTriageScreen(
            user: user,
            customerLat: customerLat,
            customerLng: customerLng,
            customerAddress: customerAddress,
          ),
        ),
      ),
    );
  }

  @override
  State<VoiceAiTriageScreen> createState() => _VoiceAiTriageScreenState();
}

class _VoiceAiTriageScreenState extends State<VoiceAiTriageScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveAnimCtrl;
  final VoiceRecognitionService _voiceService = VoiceRecognitionService.instance;
  final AiDiagnosticService _aiService = AiDiagnosticService.instance;

  double _currentSoundLevel = 0.0;
  double _smoothedSoundLevel = 0.0;

  String _transcribedWords = '';
  bool _isListening = false;
  bool _isAnalyzing = false;
  bool _isKeyboardMode = false;

  Timer? _silenceTimer;
  final TextEditingController _textInputCtrl = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  final List<String> _samplePrompts = const [
    'Tap is leaking in kitchen',
    'AC blowing room air not cooling',
    'Water motor humming no pressure',
    'Main MCB switch tripping',
  ];

  @override
  void initState() {
    super.initState();
    _waveAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addListener(_onWaveTick);
    _waveAnimCtrl.repeat();

    _voiceService.soundLevelNotifier.addListener(_onSoundLevelUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      MultilingualSemanticFallback.instance.warmUp();
      _startVoiceListening();
    });
  }

  void _onWaveTick() {
    // Exponential smoothing for natural organic fluid reaction
    setState(() {
      _smoothedSoundLevel = lerpDouble(
        _smoothedSoundLevel,
        _currentSoundLevel,
        0.18,
      ) ?? 0.0;
    });
  }

  void _onSoundLevelUpdate() {
    _currentSoundLevel = _voiceService.soundLevelNotifier.value;
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _waveAnimCtrl.removeListener(_onWaveTick);
    _waveAnimCtrl.dispose();
    _voiceService.soundLevelNotifier.removeListener(_onSoundLevelUpdate);
    _voiceService.cancelListening();
    _textInputCtrl.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  Future<void> _startVoiceListening() async {
    if (_isKeyboardMode) return;
    HapticFeedback.lightImpact();

    setState(() {
      _isListening = true;
      _transcribedWords = '';
    });

    // ── Resolve BCP-47 locale from active app language ──────────────────────
    // WorkGoLocale.getInfo() maps ISO-639-1 code → BCP-47 tag stored in locale_config.dart
    // Examples: 'ta' → 'ta-IN', 'hi' → 'hi-IN', 'te' → 'te-IN', 'ml' → 'ml-IN'
    final langCode = context.locale.languageCode;
    final bcp47 = WorkGoLocale.getInfo(langCode).bcp47;

    final success = await _voiceService.startListening(
      localeId: bcp47, // Solution A: native script transcription
      onError: (errorMsg) {
        // Speech error (e.g. error_speech_timeout, error_no_match):
        // Cancel the silence timer immediately so stale _transcribedWords
        // from a previous session cannot be re-submitted to diagnosis.
        _silenceTimer?.cancel();
        if (mounted) {
          setState(() {
            _transcribedWords = '';
            _isListening = false;
          });
        }
        debugPrint('[VoiceAITriageScreen] Speech error: $errorMsg — cleared stale text');
      },
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _transcribedWords = words;
        });

        _silenceTimer?.cancel();

        if (words.trim().isNotEmpty) {
          // If speech pauses for 1.4 seconds, auto-proceed to diagnosis
          _silenceTimer = Timer(const Duration(milliseconds: 1400), () {
            if (mounted && _transcribedWords.trim().isNotEmpty && !_isAnalyzing) {
              _proceedToDiagnosis(_transcribedWords.trim());
            }
          });
        }
      },
      onSoundLevel: (level) {
        _currentSoundLevel = level;
      },
    );

    if (!success && mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _stopVoiceListening() async {
    _silenceTimer?.cancel();
    await _voiceService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _currentSoundLevel = 0.0;
      });
    }
  }

  void _toggleMic() {
    HapticFeedback.mediumImpact();
    if (_isListening) {
      // Cancel silence timer FIRST — prevents double-trigger race where
      // both the timer and _toggleMic call _proceedToDiagnosis simultaneously.
      _silenceTimer?.cancel();
      _stopVoiceListening();
      if (_transcribedWords.trim().isNotEmpty) {
        _proceedToDiagnosis(_transcribedWords.trim());
      }
    } else {
      _startVoiceListening();
    }
  }

  Future<void> _proceedToDiagnosis(String rawQuery) async {
    if (_isAnalyzing || rawQuery.trim().isEmpty) return;

    // Capture languageCode synchronously at the TOP, before any await.
    // context must never be accessed after an async gap (use_build_context_synchronously).
    final langCode = context.locale.languageCode;

    _silenceTimer?.cancel();
    await _voiceService.stopListening();

    setState(() {
      _isAnalyzing = true;
      _isListening = false;
    });

    HapticFeedback.heavyImpact();

    try {
      final diagResult = await _aiService.diagnoseSymptom(
        rawQuery.trim(),
        languageCode: langCode, // hint for Tier 3 Gemini prompt
      );

      if (!mounted) return;

      // Close this voice triage screen and open standard SymptomTriageSheet
      Navigator.of(context).pop();

      SymptomTriageSheet.show(
        context,
        customerId: widget.user.uid,
        customerLat: widget.customerLat,
        customerLng: widget.customerLng,
        customerAddress: widget.customerAddress,
        initialQuery: rawQuery.trim(),
        initialDiagnosis: diagResult,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      SymptomTriageSheet.show(
        context,
        customerId: widget.user.uid,
        customerLat: widget.customerLat,
        customerLng: widget.customerLng,
        customerAddress: widget.customerAddress,
        initialQuery: rawQuery.trim(),
      );
    }
  }

  void _toggleKeyboardMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isKeyboardMode = !_isKeyboardMode;
    });

    if (_isKeyboardMode) {
      _stopVoiceListening();
      _textInputCtrl.text = _transcribedWords;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _textFocusNode.requestFocus();
      });
    } else {
      _textFocusNode.unfocus();
      _startVoiceListening();
    }
  }

  String get _customerFirstName {
    final raw = widget.user.displayName.trim();
    if (raw.isEmpty) return 'there';
    return raw.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF2),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Background Ambient Radial Glow
          Positioned(
            left: 0,
            right: 0,
            bottom: screenHeight * 0.12,
            height: screenHeight * 0.55,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.2),
                  radius: 0.85,
                  colors: [
                    CX.amberDark.withValues(alpha: 0.16),
                    CX.violet.withValues(alpha: 0.08),
                    const Color(0x00FFFBF2),
                  ],
                ),
              ),
            ),
          ),

          // ── Sound-Reactive Multi-Layered Acoustic Ribbons
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: HarmonicAcousticWavePainter(
                  phase: _waveAnimCtrl.value * 2 * math.pi,
                  soundLevel: _smoothedSoundLevel,
                ),
              ),
            ),
          ),

          // ── Content Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Navigation Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: CX.dividerLight),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x08000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isListening ? CX.emerald : CX.amberDark,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isAnalyzing
                                  ? 'diagnosing_ellipsis'.tr()
                                  : (_isListening ? 'ai_listening'.tr() : 'workgo_ai_voice'.tr()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: WorkGoFonts.body(
                                color: CX.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: CX.dividerLight),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: CX.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Personalized Greeting Header
                  Text(
                    'hello_user'.tr(args: [_customerFirstName]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WorkGoFonts.heading(
                      color: CX.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'what_seems_problem'.tr(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: WorkGoFonts.body(
                      color: CX.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Real-Time Live Streaming Transcript
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isAnalyzing) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: CX.amberDark.withValues(alpha: 0.3)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: CX.amberDark,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'analyzing_fault_trees'.tr(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: WorkGoFonts.body(
                                        color: CX.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_transcribedWords.isNotEmpty) ...[
                            Text(
                              _transcribedWords,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: WorkGoFonts.heading(
                                color: CX.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ] else if (!_isKeyboardMode) ...[
                            Text(
                              _isListening
                                  ? 'speak_clearly_hint'.tr()
                                  : 'tap_mic_hint'.tr(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: WorkGoFonts.body(
                                color: CX.textMuted,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          // Keyboard Direct Text Mode
                          if (_isKeyboardMode) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: CX.amberDark, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x08000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _textInputCtrl,
                                focusNode: _textFocusNode,
                                maxLines: 3,
                                style: WorkGoFonts.body(
                                  color: CX.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'type_problem_hint'.tr(),
                                  hintStyle: WorkGoFonts.body(
                                    color: CX.textMuted,
                                    fontSize: 14,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.arrow_forward_rounded, color: CX.amberDark),
                                    onPressed: () {
                                      if (_textInputCtrl.text.trim().isNotEmpty) {
                                        _proceedToDiagnosis(_textInputCtrl.text.trim());
                                      }
                                    },
                                  ),
                                ),
                                onSubmitted: (val) {
                                  if (val.trim().isNotEmpty) {
                                    _proceedToDiagnosis(val.trim());
                                  }
                                },
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Quick Prompts Chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _samplePrompts.map((prompt) {
                              return InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _proceedToDiagnosis(prompt);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: CX.dividerLight),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.north_west_rounded,
                                        size: 13,
                                        color: CX.amberDark,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        prompt,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: WorkGoFonts.body(
                                          color: CX.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Dock Controls
                  Padding(
                    padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 8 : 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Left: Keyboard Switch
                        GestureDetector(
                          onTap: _toggleKeyboardMode,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isKeyboardMode ? CX.amberDark : Colors.white,
                              border: Border.all(
                                color: _isKeyboardMode ? CX.amberDark : CX.dividerLight,
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isKeyboardMode ? Icons.mic_rounded : Icons.keyboard_alt_outlined,
                              color: _isKeyboardMode ? Colors.white : CX.textPrimary,
                              size: 22,
                            ),
                          ),
                        ),

                        // Center: Sound-Reactive Illuminated Mic Button
                        GestureDetector(
                          onTap: _toggleMic,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Radiant pulse ring scaling with speech soundLevel
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                width: 80 + (_smoothedSoundLevel * 36.0),
                                height: 80 + (_smoothedSoundLevel * 36.0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: CX.amberDark.withValues(
                                    alpha: (0.10 + (_smoothedSoundLevel * 0.25)).clamp(0.05, 0.40),
                                  ),
                                ),
                              ),
                              // Solid Mic Core
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: _isListening
                                        ? [const Color(0xFFFFB800), const Color(0xFFE8A500)]
                                        : [Colors.white, const Color(0xFFFBF8F1)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: _isListening ? CX.amberDark : CX.dividerLight,
                                    width: 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _isListening
                                          ? CX.amberDark.withValues(alpha: 0.35)
                                          : const Color(0x0C000000),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                    color: _isListening ? Colors.white : CX.textPrimary,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right: Confirm / Direct Action
                        GestureDetector(
                          onTap: () {
                            if (_transcribedWords.trim().isNotEmpty) {
                              _proceedToDiagnosis(_transcribedWords.trim());
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _transcribedWords.trim().isNotEmpty
                                  ? CX.emerald
                                  : Colors.white,
                              border: Border.all(
                                color: _transcribedWords.trim().isNotEmpty
                                  ? CX.emerald
                                  : CX.dividerLight,
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              _transcribedWords.trim().isNotEmpty
                                  ? Icons.arrow_forward_rounded
                                  : Icons.tune_rounded,
                              color: _transcribedWords.trim().isNotEmpty
                                  ? Colors.white
                                  : CX.textPrimary,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter rendering multi-layered sinusoidal parametric acoustic ribbons.
/// Dynamically expands amplitude and crests high with user speech pitch/volume,
/// sinking low into a calm, gentle harmonic idle flow during silence.
class HarmonicAcousticWavePainter extends CustomPainter {
  final double phase;
  final double soundLevel; // 0.0 (silence) to 1.0 (loud speech)

  HarmonicAcousticWavePainter({
    required this.phase,
    required this.soundLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Center wave position (vertically situated around 62% of screen)
    final yCenter = h * 0.62;

    // Amplitude dynamics:
    // Silence/idle: base amplitude ~10px (gentle breathing)
    // Active speech: surges up to ~75px based on soundLevel
    final surge = soundLevel.clamp(0.0, 1.0);
    final primaryAmp = 10.0 + (surge * 68.0);
    final secondaryAmp = 8.0 + (surge * 48.0);
    final tertiaryAmp = 6.0 + (surge * 36.0);

    // Wave layers configuration with harmonious color palettes
    final layers = [
      _WaveLayerConfig(
        color: const Color(0xFFFFB800), // Amber Gold
        amplitude: primaryAmp,
        frequency: 0.012 + (surge * 0.005),
        phaseOffset: 0.0,
        strokeWidth: 3.2,
        opacity: 0.90,
      ),
      _WaveLayerConfig(
        color: const Color(0xFFF59E0B), // Honey Warm
        amplitude: secondaryAmp * 1.15,
        frequency: 0.015 + (surge * 0.004),
        phaseOffset: 0.65,
        strokeWidth: 2.6,
        opacity: 0.75,
      ),
      _WaveLayerConfig(
        color: const Color(0xFF10B981), // Emerald Accent
        amplitude: tertiaryAmp * 1.25,
        frequency: 0.018 + (surge * 0.006),
        phaseOffset: 1.30,
        strokeWidth: 2.2,
        opacity: 0.65,
      ),
      _WaveLayerConfig(
        color: const Color(0xFFFFCD4A), // Light Gold Highlight
        amplitude: primaryAmp * 0.75,
        frequency: 0.010 + (surge * 0.003),
        phaseOffset: 2.10,
        strokeWidth: 1.8,
        opacity: 0.50,
      ),
    ];

    for (final layer in layers) {
      final path = Path();
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = layer.strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = layer.color.withValues(alpha: layer.opacity);

      bool isFirst = true;

      for (double x = 0; x <= w; x += 3.0) {
        // Horizontal window envelope: smoothly tapers wave to 0 at left and right edges
        final envelope = math.sin((x / w) * math.pi);

        // Composite harmonic wave: fundamental + octave overtone
        final wave1 = math.sin((x * layer.frequency) + phase + layer.phaseOffset);
        final wave2 = math.cos((x * layer.frequency * 1.8) - (phase * 0.7) + layer.phaseOffset);

        final y = yCenter + ((wave1 * 0.75 + wave2 * 0.25) * layer.amplitude * envelope);

        if (isFirst) {
          path.moveTo(x, y);
          isFirst = false;
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant HarmonicAcousticWavePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.soundLevel != soundLevel;
  }
}

class _WaveLayerConfig {
  final Color color;
  final double amplitude;
  final double frequency;
  final double phaseOffset;
  final double strokeWidth;
  final double opacity;

  const _WaveLayerConfig({
    required this.color,
    required this.amplitude,
    required this.frequency,
    required this.phaseOffset,
    required this.strokeWidth,
    required this.opacity,
  });
}
