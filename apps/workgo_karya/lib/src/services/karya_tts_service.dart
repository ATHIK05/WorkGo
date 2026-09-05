// karya_tts_service.dart
// Voice announcement service for Karya artisans.
// Announces new jobs, job acceptance, service start, and completion.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:workgo_core/workgo_core.dart';

class KaryaTtsService {
  KaryaTtsService._();
  static final KaryaTtsService instance = KaryaTtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = true; // can be toggled by user

  // ── Initialise once per app session ─────────────────────────
  Future<void> init({String languageCode = 'en'}) async {
    if (_initialized) return;
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _tts.setVolume(0.9);
        await _tts.setSpeechRate(0.52);  // slightly slower for clarity
        await _tts.setPitch(1.0);
        await _setLanguage(languageCode);
        _initialized = true;
      }
    } catch (_) {}
  }

  Future<void> _setLanguage(String code) async {
    try {
      final lang = switch (code) {
        'ta' => 'ta-IN',
        'hi' => 'hi-IN',
        _ => 'en-IN',
      };
      final available = await _tts.isLanguageAvailable(lang);
      await _tts.setLanguage((available == true) ? lang : 'en-IN');
    } catch (_) {}
  }

  void setEnabled(bool value) => _enabled = value;

  // ── Core announce ────────────────────────────────────────────
  Future<void> announce(String text) async {
    if (!_enabled || !_initialized) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  // ── Specific announcement helpers ────────────────────────────

  /// Called when a new job request enters the radar.
  Future<void> announceNewJob(
    dynamic jobOrServiceType, {
    double? amount,
    double? distanceKm,
  }) async {
    if (jobOrServiceType is Booking) {
      final locPart = (jobOrServiceType.customerAddressText?.isNotEmpty == true)
          ? 'at ${jobOrServiceType.customerAddressText}.'
          : 'nearby.';
      await announce(
        'New ${jobOrServiceType.serviceType} job $locPart '
        'Payout: ${jobOrServiceType.amount.toStringAsFixed(0)} rupees. Accept now.',
      );
    } else {
      final serviceType = jobOrServiceType?.toString() ?? 'service';
      final distancePart = distanceKm != null
          ? '${distanceKm.toStringAsFixed(1)} kilometres away.'
          : 'nearby.';
      await announce(
        'New $serviceType job $distancePart '
        'Payout: ${(amount ?? 0).toStringAsFixed(0)} rupees. Accept now.',
      );
    }
  }

  /// Called when the artisan goes online.
  Future<void> announceOnline() async {
    await announce('You are now live on radar. Listening for nearby jobs.');
  }

  /// Called when the artisan goes offline.
  Future<void> announceOffline() async {
    await announce('You are now offline. Great work today.');
  }

  /// Called after job is accepted.
  Future<void> announceJobAccepted(dynamic jobOrServiceType, [String? address]) async {
    if (jobOrServiceType is Booking) {
      final addr = jobOrServiceType.customerAddressText;
      final addressPart = (addr?.isNotEmpty == true)
          ? 'Navigate to $addr.'
          : 'Check the job details.';
      await announce('${jobOrServiceType.serviceType} job accepted. $addressPart');
    } else {
      final serviceType = jobOrServiceType?.toString() ?? 'Service';
      final addressPart = (address?.isNotEmpty == true)
          ? 'Navigate to $address.'
          : 'Check the job details.';
      await announce('$serviceType job accepted. $addressPart');
    }
  }

  /// Called after OTP verified and service starts.
  Future<void> announceServiceStarted() async {
    await announce('Service started. Timer is running. Do your best.');
  }

  /// Called after job is completed.
  Future<void> announceJobComplete(double amount) async {
    await announce(
      'Mission complete! ${amount.toStringAsFixed(0)} rupees credited to your account.',
    );
  }

  /// Called when SOS is activated.
  Future<void> announceSos() async {
    await announce('Emergency alert sent. Help is on the way. Stay safe.');
  }

  /// Called when a peer artisan activates SOS nearby.
  Future<void> announcePeerSos(String name) async {
    await announce('Emergency alert: Fellow artisan $name requested assistance nearby.');
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
