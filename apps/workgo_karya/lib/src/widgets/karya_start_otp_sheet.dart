import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../services/karya_tts_service.dart';

/// Premium high-contrast 4-digit Customer Start OTP verification bottom sheet.
/// Eliminates white-on-white text issues with high-contrast obsidian typography,
/// distinct amber focus borders, automatic focus navigation, backspace support,
/// and paste-to-fill capability.
class KaryaStartOtpSheet extends StatefulWidget {
  const KaryaStartOtpSheet({
    super.key,
    required this.bookingId,
    required this.onSuccess,
    this.onVerifyOtp,
  });

  final String bookingId;
  final VoidCallback onSuccess;
  final Future<bool> Function(String otp)? onVerifyOtp;

  /// Convenience launcher for showing the bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required String bookingId,
    required VoidCallback onSuccess,
    Future<bool> Function(String otp)? onVerifyOtp,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => KaryaStartOtpSheet(
        bookingId: bookingId,
        onSuccess: onSuccess,
        onVerifyOtp: onVerifyOtp,
      ),
    );
  }

  @override
  State<KaryaStartOtpSheet> createState() => _KaryaStartOtpSheetState();
}

class _KaryaStartOtpSheetState extends State<KaryaStartOtpSheet> {
  final TextEditingController _c1 = TextEditingController();
  final TextEditingController _c2 = TextEditingController();
  final TextEditingController _c3 = TextEditingController();
  final TextEditingController _c4 = TextEditingController();

  final FocusNode _f1 = FocusNode();
  final FocusNode _f2 = FocusNode();
  final FocusNode _f3 = FocusNode();
  final FocusNode _f4 = FocusNode();

  bool _isVerifying = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // Add focus listeners to trigger repaint for focused border styling
    _f1.addListener(_onFocusChange);
    _f2.addListener(_onFocusChange);
    _f3.addListener(_onFocusChange);
    _f4.addListener(_onFocusChange);

    // Auto-focus first digit on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _f1.requestFocus();
    });

    _f2.onKeyEvent = (node, event) => _onKey(_c2, _f1, event);
    _f3.onKeyEvent = (node, event) => _onKey(_c3, _f2, event);
    _f4.onKeyEvent = (node, event) => _onKey(_c4, _f3, event);
  }

  KeyEventResult _onKey(TextEditingController ctrl, FocusNode prevFocus, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        ctrl.text.isEmpty) {
      prevFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _f1.removeListener(_onFocusChange);
    _f2.removeListener(_onFocusChange);
    _f3.removeListener(_onFocusChange);
    _f4.removeListener(_onFocusChange);

    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    _c4.dispose();

    _f1.dispose();
    _f2.dispose();
    _f3.dispose();
    _f4.dispose();
    super.dispose();
  }

  String get _fullOtp => "${_c1.text}${_c2.text}${_c3.text}${_c4.text}".trim();

  /// Handle typing, paste, or clearing for a box
  void _onDigitChanged(
    String val,
    TextEditingController currentCtrl,
    FocusNode currentFocus,
    FocusNode? nextFocus,
    FocusNode? prevFocus,
  ) {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }

    // Check if user pasted a 4-digit code (e.g., "8492")
    if (val.length >= 4) {
      final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 4) {
        _c1.text = digits[0];
        _c2.text = digits[1];
        _c3.text = digits[2];
        _c4.text = digits[3];
        _f4.requestFocus();
        _verifyOtp();
        return;
      }
    }

    // Single digit entry
    if (val.isNotEmpty) {
      // If user typed more than 1 char (e.g. replacing existing), keep the last char
      if (val.length > 1) {
        currentCtrl.text = val[val.length - 1];
        currentCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: currentCtrl.text.length),
        );
      }
      HapticFeedback.selectionClick();
      if (nextFocus != null) {
        nextFocus.requestFocus();
      } else {
        // Last digit entered
        if (_fullOtp.length == 4) {
          _verifyOtp();
        }
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _fullOtp;
    if (otp.length != 4) {
      setState(() => _errorText = "otp_error_all_digits".tr());
      HapticFeedback.vibrate();
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      final bool success;
      if (widget.onVerifyOtp != null) {
        success = await widget.onVerifyOtp!(otp);
      } else {
        success = await BookingService().verifyStartOtp(
          bookingId: widget.bookingId,
          enteredOtp: otp,
        );
      }

      if (!mounted) return;

      if (success) {
        HapticFeedback.heavyImpact();
        KaryaTtsService.instance.announceServiceStarted();
        Navigator.of(context).pop();
        widget.onSuccess();
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _isVerifying = false;
          _errorText = "otp_error_incorrect".tr();
          _c1.clear();
          _c2.clear();
          _c3.clear();
          _c4.clear();
        });
        _f1.requestFocus();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorText = "otp_error_verification".tr(args: [e.toString()]);
      });
    }
  }

  Widget _buildDigitBox({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    FocusNode? prevFocus,
  }) {
    final hasFocus = focusNode.hasFocus;
    final isFilled = controller.text.isNotEmpty;

    return Container(
      width: 58,
      height: 64,
      decoration: BoxDecoration(
        color: hasFocus
            ? const Color(0xFFFFFBEB)
            : (isFilled ? Colors.white : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus
              ? const Color(0xFFF59E0B)
              : (isFilled ? const Color(0xFFD97706) : const Color(0xFFCBD5E1)),
          width: hasFocus ? 2.2 : (isFilled ? 1.8 : 1.4),
        ),
        boxShadow: hasFocus
            ? const [
                BoxShadow(
                  color: Color(0x33F59E0B),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0F172A), // Crisp high-contrast obsidian dark text
            fontSize: 26,
            fontWeight: FontWeight.w900,
            fontFamily: 'SpaceGrotesk',
            letterSpacing: 0,
          ),
          cursorColor: const Color(0xFFF59E0B),
          // EXPLICIT TRANSPARENT FILL: overrides theme's white/cream inputDecorationTheme
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          onChanged: (val) => _onDigitChanged(val, controller, focusNode, nextFocus, prevFocus),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 32,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header: Amber Icon + High-contrast titles
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                ),
                child: const Icon(
                  Icons.key_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "otp_sheet_title".tr(),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "otp_sheet_sub".tr(),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 4-Box Pin Inputs
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDigitBox(
                controller: _c1,
                focusNode: _f1,
                nextFocus: _f2,
                prevFocus: null,
              ),
              const SizedBox(width: 12),
              _buildDigitBox(
                controller: _c2,
                focusNode: _f2,
                nextFocus: _f3,
                prevFocus: _f1,
              ),
              const SizedBox(width: 12),
              _buildDigitBox(
                controller: _c3,
                focusNode: _f3,
                nextFocus: _f4,
                prevFocus: _f2,
              ),
              const SizedBox(width: 12),
              _buildDigitBox(
                controller: _c4,
                focusNode: _f4,
                nextFocus: null,
                prevFocus: _f3,
              ),
            ],
          ),

          // Error Banner
          if (_errorText != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDD3), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFBE123C),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Security Trust Shield
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFF059669), size: 14),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  "otp_sheet_trust".tr(),
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // CTA Action Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF0F172A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isVerifying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFF0F172A),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF0F172A)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "otp_sheet_verify_btn".tr(),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
