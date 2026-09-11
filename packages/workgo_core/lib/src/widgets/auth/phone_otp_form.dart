import "dart:async";
import "package:easy_localization/easy_localization.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../../firebase/auth_service.dart";
import "../../models/app_user.dart";
import "../../theme/colors.dart";
import "auth_text_field.dart";

/// Keys used to persist the in-flight OTP session across process restarts.
const _kOtpSessionId = "wg_otp_session_id";
const _kOtpPhone = "wg_otp_phone";

/// Dedicated Phone OTP Form for WorkGo Authentication.
/// Communicates with 2Factor.in backend microservice.
///
/// Persists session state so if the OS kills the app (low RAM) and the user
/// returns, they land directly on the OTP entry step rather than having to
/// re-request the code.
class PhoneOtpForm extends StatefulWidget {
  const PhoneOtpForm({
    super.key,
    required this.role,
    required this.isLoading,
    required this.onSuccess,
    required this.onError,
    required this.onSwitchToEmail,
  });

  final UserRole role;
  final bool isLoading;
  final void Function(AppUser user) onSuccess;
  final void Function(String error) onError;
  final VoidCallback onSwitchToEmail;

  @override
  State<PhoneOtpForm> createState() => _PhoneOtpFormState();
}

class _PhoneOtpFormState extends State<PhoneOtpForm> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _authService = AuthService();

  bool _codeSent = false;
  String? _sessionId;
  bool _sending = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ── Session persistence ──────────────────────────────────────────────────

  /// Restore a pending OTP session if the app was killed mid-flow.
  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSession = prefs.getString(_kOtpSessionId);
    final savedPhone = prefs.getString(_kOtpPhone);
    if (savedSession != null && savedPhone != null && mounted) {
      setState(() {
        _sessionId = savedSession;
        _phoneController.text = savedPhone;
        _codeSent = true;
      });
    }
  }

  Future<void> _persistSession(String sessionId, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOtpSessionId, sessionId);
    await prefs.setString(_kOtpPhone, phone);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOtpSessionId);
    await prefs.remove(_kOtpPhone);
  }

  // ── Countdown ────────────────────────────────────────────────────────────

  void _startCountdown() {
    _countdown = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // ── OTP actions ──────────────────────────────────────────────────────────

  Future<void> _handleSendOtp() async {
    final rawPhone = _phoneController.text.trim();
    final cleanPhone = rawPhone.replaceAll(RegExp(r"\D"), "");
    if (cleanPhone.length < 10) {
      widget.onError("invalid_phone_error".tr());
      return;
    }

    final normalized = cleanPhone.length == 12 && cleanPhone.startsWith("91")
        ? cleanPhone.substring(2)
        : cleanPhone;

    setState(() => _sending = true);
    try {
      final res = await _authService.sendPhoneOtp(normalized);
      if (res["success"] == true && res["sessionId"] != null) {
        final sid = res["sessionId"] as String;
        await _persistSession(sid, normalized);
        if (mounted) {
          setState(() {
            _codeSent = true;
            _sessionId = sid;
          });
          _startCountdown();
        }
      } else {
        widget.onError(res["error"]?.toString() ?? "send_otp_failed".tr());
      }
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4 || _sessionId == null) {
      widget.onError("invalid_otp_error".tr());
      return;
    }

    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r"\D"), "");
    final normalized = rawPhone.length == 12 && rawPhone.startsWith("91")
        ? rawPhone.substring(2)
        : rawPhone;

    setState(() => _sending = true);
    try {
      final cred = await _authService.signInWithPhoneOtp(
        phone: normalized,
        otpCode: otp,
        sessionId: _sessionId!,
        role: widget.role.name,
      );

      await _clearSession();

      final uid = cred.user!.uid;
      var user = await _authService.fetchUser(uid);
      user ??= AppUser(
        uid: uid,
        email: "$normalized@phone.workgo.in",
        displayName: widget.role == UserRole.worker ? "Artisan" : "Customer",
        phoneNumber: "+91$normalized",
        role: widget.role,
        region: "IN-TN",
      );
      await _authService.upsertUser(user);
      widget.onSuccess(user);
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Reset back to phone-entry step and clear any saved session.
  Future<void> _handleChangeNumber() async {
    await _clearSession();
    if (!mounted) return;
    setState(() {
      _codeSent = false;
      _sessionId = null;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.isLoading || _sending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_codeSent) ...[
          // ── Step 1: Enter phone & request OTP ──────────────────────────
          AuthTextField(
            controller: _phoneController,
            labelText: "phone_otp_title".tr(),
            hintText: "phone_otp_sub".tr(),
            prefixIcon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            enabled: !isBusy,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: isBusy ? null : _handleSendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    "send_otp_btn".tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
          ),
        ] else ...[
          // ── Step 2: OTP already sent — enter code ───────────────────────
          // Subtle info row showing the destination phone
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${"otp_sent_to".tr()} +91 ${_phoneController.text}",
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          AuthTextField(
            controller: _otpController,
            labelText: "verify_otp_btn".tr(),
            hintText: "enter_otp_hint".tr(),
            prefixIcon: Icons.pin_rounded,
            keyboardType: TextInputType.number,
            enabled: !isBusy,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
          const SizedBox(height: 12),

          ElevatedButton(
            onPressed: isBusy ? null : _handleVerifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: WorkGoColors.primary,
              foregroundColor: const Color(0xFF1A1A1A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2),
                  )
                : Text(
                    "verify_otp_btn".tr(),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
          ),
          const SizedBox(height: 6),

          // Resend / Change Number row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: isBusy ? null : _handleChangeNumber,
                child: Text(
                  "change_number".tr(),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ),
              if (_countdown > 0)
                Text(
                  "${"resend_in".tr()} ${_countdown}s",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                )
              else
                TextButton(
                  onPressed: isBusy ? null : _handleSendOtp,
                  child: Text(
                    "resend_otp".tr(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],

        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: widget.onSwitchToEmail,
            icon: const Icon(Icons.mail_outline_rounded, size: 16, color: Color(0xFF4B5563)),
            label: Text(
              "auth_tab_email".tr(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
