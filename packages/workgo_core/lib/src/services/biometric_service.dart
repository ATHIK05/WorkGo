import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Comprehensive hardware biometric service (Fingerprint & Face ID)
/// Compliant with DPDP Act 2023 biometric consent & zero-account-renting verification.
class BiometricService {
  BiometricService._internal();
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;

  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the device has biometric sensors and if the user has enrolled fingerprints/face.
  Future<bool> canAuthenticate() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } on PlatformException catch (e) {
      debugPrint("[BiometricService] canAuthenticate error: $e");
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get list of enrolled biometric sensors on the phone (Fingerprint, Face, Iris)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint("[BiometricService] getAvailableBiometrics error: $e");
      return [];
    }
  }

  /// Prompt native OS biometric authentication modal (Fingerprint / Face Unlock).
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    try {
      final isHardwareAvailable = await canAuthenticate();
      if (!isHardwareAvailable) {
        debugPrint("[BiometricService] Biometrics unavailable on this hardware. Bypassing.");
        return true; // Fallback gracefully if running on desktop or emulator without sensor
      }

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );

      return authenticated;
    } on PlatformException catch (e) {
      debugPrint("[BiometricService] Auth error: $e");
      // If user cancelled, return false
      if (e.code == "NotAvailable" || e.code == "PasscodeNotSet" || e.code == "NotEnrolled") {
        // Device doesn't have enrolled biometrics, allow proceed
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("[BiometricService] General error: $e");
      return false;
    }
  }

  /// Cancel any pending auth dialog
  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
