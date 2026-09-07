import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Centralized robust phone dialing helper for WorkGo Customer, Karya, and Admin Console.
class PhoneDialer {
  PhoneDialer._();

  /// Sanitize phone number string by removing spaces, brackets, hyphens, and converting
  /// mnemonic letters (e.g. 1800-419-WORK -> 18004199675) to valid telephone digits.
  static String sanitize(String rawPhone) {
    if (rawPhone.isEmpty) return '';

    final buffer = StringBuffer();
    for (int i = 0; i < rawPhone.length; i++) {
      final char = rawPhone[i].toUpperCase();
      if (RegExp(r'[0-9+]').hasMatch(char)) {
        buffer.write(char);
      } else if (RegExp(r'[A-C]').hasMatch(char)) {
        buffer.write('2');
      } else if (RegExp(r'[D-F]').hasMatch(char)) {
        buffer.write('3');
      } else if (RegExp(r'[G-I]').hasMatch(char)) {
        buffer.write('4');
      } else if (RegExp(r'[J-L]').hasMatch(char)) {
        buffer.write('5');
      } else if (RegExp(r'[M-O]').hasMatch(char)) {
        buffer.write('6');
      } else if (RegExp(r'[P-S]').hasMatch(char)) {
        buffer.write('7');
      } else if (RegExp(r'[T-V]').hasMatch(char)) {
        buffer.write('8');
      } else if (RegExp(r'[W-Z]').hasMatch(char)) {
        buffer.write('9');
      }
    }
    return buffer.toString();
  }

  /// Launches the native phone dialer with [phoneNumber] prefilled.
  /// Returns true if successfully launched, false otherwise.
  static Future<bool> call(String phoneNumber, {BuildContext? context}) async {
    final clean = sanitize(phoneNumber);
    if (clean.length < 3) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('invalid_phone_number'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final uri = Uri(scheme: 'tel', path: clean);

    try {
      HapticFeedback.lightImpact();
      // On Android/iOS, LaunchMode.externalApplication opens the native Phone app directly
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;

      // Fallback to platform default if externalApplication returns false
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('[PhoneDialer] Error launching $uri: $e');
      try {
        return await launchUrl(uri);
      } catch (_) {}

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('unable_open_dialer_arg'.tr(args: [clean])),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }
}
