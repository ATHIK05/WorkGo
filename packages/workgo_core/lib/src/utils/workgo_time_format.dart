import 'package:intl/intl.dart';

/// Centralized time formatting utilities for converting 24-hour ("railway") timing
/// to standard user-friendly 12-hour AM/PM timing across Customer and Karya apps.
class WorkGoTimeFormat {
  /// Converts a 24-hour time string like "08:00", "20:00", "14:30" to standard 12-hour time like "8:00 AM", "8:00 PM", "2:30 PM".
  /// If the string is already formatted with AM/PM or cannot be parsed, returns it as-is.
  static String formatTimeStringTo12Hour(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return "";
    final trimmed = timeStr.trim();
    if (trimmed.toUpperCase().contains("AM") || trimmed.toUpperCase().contains("PM")) {
      return trimmed;
    }

    final parts = trimmed.split(":");
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        final period = hour >= 12 ? "PM" : "AM";
        final hour12 = hour % 12 == 0 ? 12 : hour % 12;
        final minuteStr = minute.toString().padLeft(2, '0');
        return "$hour12:$minuteStr $period";
      }
    }
    return trimmed;
  }

  /// Formats a [DateTime] into standard 12-hour time, e.g. "2:30 PM".
  static String format12Hour(DateTime dt) {
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minuteStr = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? "PM" : "AM";
    return "$hour12:$minuteStr $period";
  }

  /// Formats a [DateTime] into "d MMM · h:mm a", e.g. "3 Sep · 2:30 PM".
  static String formatDateTime12Hour(DateTime dt, {String separator = " · "}) {
    final local = dt.toLocal();
    final datePart = DateFormat('d MMM').format(local);
    final timePart = format12Hour(local);
    return "$datePart$separator$timePart";
  }
}

extension WorkGoTimeStringExtension on String {
  /// Converts this 24-hour time string (e.g. "20:00") to standard 12-hour time (e.g. "8:00 PM").
  String to12HourTime() => WorkGoTimeFormat.formatTimeStringTo12Hour(this);
}

extension WorkGoDateTimeExtension on DateTime {
  /// Formats to "h:mm a" (e.g. "2:30 PM").
  String to12HourTime() => WorkGoTimeFormat.format12Hour(this);

  /// Formats to "d MMM · h:mm a" (e.g. "3 Sep · 2:30 PM").
  String to12HourDateTime({String separator = " · "}) =>
      WorkGoTimeFormat.formatDateTime12Hour(this, separator: separator);
}
