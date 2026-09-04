import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:workgo_core/workgo_core.dart';

/// Real-time speech recognition service for WorkGo Customer voice search & AI triage.
class VoiceRecognitionService {
  static final VoiceRecognitionService instance = VoiceRecognitionService._();
  VoiceRecognitionService._();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isAvailable = false;
  bool _isListening = false;

  final ValueNotifier<double> soundLevelNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> transcribedTextNotifier = ValueNotifier<String>('');

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  /// Initialize speech recognition with graceful error handling.
  Future<bool> initialize() async {
    if (_isInitialized) return _isAvailable;

    try {
      _isAvailable = await _speechToText.initialize(
        onError: (errorNotification) {
          debugPrint('[VoiceRecognitionService] Error: ${errorNotification.errorMsg}');
          _isListening = false;
          isListeningNotifier.value = false;
        },
        onStatus: (status) {
          debugPrint('[VoiceRecognitionService] Status: $status');
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
            isListeningNotifier.value = false;
          }
        },
      );
      _isInitialized = true;
      return _isAvailable;
    } catch (e) {
      debugPrint('[VoiceRecognitionService] Exception initializing SpeechToText: $e');
      _isAvailable = false;
      _isInitialized = true;
      return false;
    }
  }

  /// Start live microphone listening with real-time word streaming and decibel levels.
  Future<bool> startListening({
    required void Function(String recognizedWords, bool isFinal) onResult,
    void Function(double soundLevel)? onSoundLevel,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isAvailable) {
      debugPrint('[VoiceRecognitionService] Speech recognition is unavailable on this device/environment.');
      return false;
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      _isListening = true;
      isListeningNotifier.value = true;
      transcribedTextNotifier.value = '';

      // Determine best locale matching user device / app language
      final effectiveLocale = localeId ?? 'en_IN';

      await _speechToText.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          transcribedTextNotifier.value = words;
          onResult(words, result.finalResult);
        },
        onSoundLevelChange: (level) {
          // Normalize sound level into 0.0 - 1.0 range
          final normalized = ((level + 10.0) / 20.0).clamp(0.0, 1.0);
          soundLevelNotifier.value = normalized;
          onSoundLevel?.call(normalized);
        },
        listenOptions: SpeechListenOptions(
          localeId: effectiveLocale,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          autoPunctuation: true,
        ),
      );

      return true;
    } catch (e) {
      debugPrint('[VoiceRecognitionService] Failed to start listening: $e');
      _isListening = false;
      isListeningNotifier.value = false;
      return false;
    }
  }

  /// Stop listening and finalize result.
  Future<void> stopListening() async {
    try {
      if (_isListening) {
        await _speechToText.stop();
      }
    } catch (e) {
      debugPrint('[VoiceRecognitionService] Stop listening exception: $e');
    } finally {
      _isListening = false;
      isListeningNotifier.value = false;
      soundLevelNotifier.value = 0.0;
    }
  }

  /// Cancel current listening session immediately.
  Future<void> cancelListening() async {
    try {
      if (_isListening) {
        await _speechToText.cancel();
      }
    } catch (e) {
      debugPrint('[VoiceRecognitionService] Cancel listening exception: $e');
    } finally {
      _isListening = false;
      isListeningNotifier.value = false;
      soundLevelNotifier.value = 0.0;
    }
  }

  /// Intelligent intent analyzer: determines whether spoken text indicates an
  /// ambiguous multi-skill symptom requiring AI Diagnostic Triage vs a direct trade search.
  bool isLikelySymptomQuery(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return false;

    // Check against symptom catalog tokens
    for (final item in SymptomCatalog.items) {
      if (item.searchTokens.any((token) => lower.contains(token))) {
        return true;
      }
      if (item.title.toLowerCase().contains(lower)) return true;
    }

    // Common symptom indicators in Indian households
    const symptomKeywords = [
      'humming', 'noise', 'sound', 'vibrate', 'vibration', 'leak', 'leaking', 'dripping',
      'not working', 'not cooling', 'not heating', 'spark', 'sparking', 'trip', 'tripped',
      'breaker', 'smell', 'burning', 'cold water', 'hot water', 'overflow', 'choked',
      'drain', 'drainage', 'broken', 'repair', 'issue', 'problem', 'stuck', 'shaking',
      'slow', 'shock', 'current', 'airlock', 'pressure', 'tank', 'motor', 'pump', 'geyser', 'ac'
    ];

    return symptomKeywords.any((kw) => lower.contains(kw));
  }
}
