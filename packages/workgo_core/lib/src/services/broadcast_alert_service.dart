import 'package:flutter/services.dart';
import '../models/booking.dart';

/// Service that plays audible and physical alert signals when a new
/// Rapido-style service broadcast arrives for an artisan.
class BroadcastAlertService {
  BroadcastAlertService._();
  static final BroadcastAlertService instance = BroadcastAlertService._();

  final Set<String> _announcedBookingIds = {};

  /// Trigger audio and haptic alert for an incoming broadcast.
  Future<void> playBroadcastAlert(Booking booking) async {
    if (_announcedBookingIds.contains(booking.id)) return;
    _announcedBookingIds.add(booking.id);

    try {
      // Play multi-tone system alert chimes
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();

      // Second pulse for urgent attention
      await Future.delayed(const Duration(milliseconds: 220));
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();

      if (booking.isEmergency || booking.urgencyBonus > 0) {
        await Future.delayed(const Duration(milliseconds: 180));
        await HapticFeedback.vibrate();
      }
    } catch (_) {
      // System sound fallbacks gracefully
    }
  }

  /// Reset alert cache for tests / new sessions
  void clearCache() => _announcedBookingIds.clear();
}
