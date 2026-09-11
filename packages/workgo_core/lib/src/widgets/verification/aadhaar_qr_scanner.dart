import "package:easy_localization/easy_localization.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "../../services/aadhaar_qr_service.dart";
import "../../theme/colors.dart";

/// Aadhaar QR scanner widget.
///
/// Primary path: camera → parse → UIDAI RSA verify → success toast.
/// Worker sees only a checkmark — zero personal data reflected.
///
/// Falls back to [onFallback] after 2 consecutive scan failures or tap.
class AadhaarQrScanner extends StatefulWidget {
  const AadhaarQrScanner({
    super.key,
    required this.workerId,
    required this.onSuccess,
    required this.onFallback,
    required this.onError,
  });

  final String workerId;
  final VoidCallback onSuccess;
  final VoidCallback onFallback;
  final void Function(String error) onError;

  @override
  State<AadhaarQrScanner> createState() => _AadhaarQrScannerState();
}

class _AadhaarQrScannerState extends State<AadhaarQrScanner> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _processing = false;
  bool _succeeded = false;
  int _failCount = 0;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _succeeded) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _processing = true);
    HapticFeedback.mediumImpact();

    try {
      final result = AadhaarQrService.parseAndVerify(raw);

      if (!result.signatureValid) {
        _failCount++;
        if (mounted) setState(() => _processing = false);
        if (_failCount >= 2 && mounted) widget.onFallback();
        return;
      }

      await AadhaarQrService.submitToBackend(
        workerId: widget.workerId,
        result: result,
      );

      if (mounted) {
        setState(() => _succeeded = true);
        HapticFeedback.heavyImpact();
        widget.onSuccess();
      }
    } catch (e) {
      _failCount++;
      if (mounted) {
        setState(() => _processing = false);
        if (_failCount >= 2) widget.onFallback();
      }
    }
  }

  Future<void> _restartScanner() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _processing = false;
      _failCount = 0;
    });
    try {
      await _scanner.stop();
      if (mounted) {
        await _scanner.start();
      }
    } catch (_) {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_succeeded) {
      return _SuccessPanel();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Camera viewfinder
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    return Container(
                      color: const Color(0xFF141416),
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.videocam_off_rounded,
                              color: Color(0xFFEF4444),
                              size: 36,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              error.errorCode == MobileScannerErrorCode.permissionDenied
                                  ? "Camera permission is required to scan QR code."
                                  : "Unable to start camera. Please restart or check permissions.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _restartScanner,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text(
                                "Retry Camera",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB800),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Overlay guide
                Center(
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: WorkGoColors.primary,
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                // Camera Top Bar: Torch & Retry Icon Buttons
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Torch Toggle
                      Material(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            await _scanner.toggleTorch();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.flash_on_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),

                      // Retry Icon Button
                      Material(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _restartScanner,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  "Retry",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Retry prompt banner if scan encountered an issue
                if (_failCount > 0 && !_processing)
                  Positioned(
                    bottom: 12,
                    child: Material(
                      color: Colors.black.withAlpha(190),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _restartScanner,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFB800), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.replay_rounded, size: 14, color: Color(0xFFFFB800)),
                              SizedBox(width: 6),
                              Text(
                                "Tap to Retry Scan",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Processing overlay
                if (_processing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: WorkGoColors.primary,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Instruction row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_rounded,
                size: 14, color: WorkGoColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              "aadhaar_qr_scan_hint".tr(),
              style: const TextStyle(
                  fontSize: 12, color: WorkGoColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Fallback link
        Center(
          child: TextButton(
            onPressed: widget.onFallback,
            child: Text(
              "aadhaar_qr_failed_fallback".tr(),
              style: const TextStyle(
                  fontSize: 12,
                  color: WorkGoColors.textSecondary,
                  decoration: TextDecoration.underline),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded,
                color: Color(0xFF16A34A), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "aadhaar_verified_badge".tr(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF15803D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
