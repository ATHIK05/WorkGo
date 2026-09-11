import "dart:async";
import "package:easy_localization/easy_localization.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../../firebase/auth_service.dart";
import "../../models/app_user.dart";
import "../../theme/colors.dart";
import "auth_text_field.dart";

// ── SharedPreferences keys ───────────────────────────────────────────────────
// Checkpoint 1: OTP has been sent — resume at code-entry step
const _kOtpSessionId = "wg_otp_session_id";
const _kOtpPhone = "wg_otp_phone";
// Checkpoint 2: Backend verified OTP and returned a customToken — resume at
// Firebase sign-in step (so the user never has to re-enter the OTP code)
const _kOtpCustomToken = "wg_otp_custom_token";
const _kOtpRole = "wg_otp_role";

/// Dedicated Phone OTP Form for WorkGo Authentication.
///
/// Two-checkpoint persistence model:
///   CP1 (sessionId + phone) → OTP sent, waiting for user code input
///   CP2 (customToken)       → OTP verified by backend, waiting for Firebase
///
/// If the OS kills the app (low RAM) at any point, the next launch detects the
/// furthest checkpoint and resumes silently from there — no re-entry needed.
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
  bool _sending = false;     // controls button spinner
  bool _resuming = false;    // silent auto-resume on restart
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

  // ── Checkpoint helpers ───────────────────────────────────────────────────

  Future<void> _persistSessionSent(String sessionId, String phone) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOtpSessionId, sessionId);
    await p.setString(_kOtpPhone, phone);
  }

  Future<void> _persistCustomToken(String token, String role) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOtpCustomToken, token);
    await p.setString(_kOtpRole, role);
  }

  Future<void> _clearAllCheckpoints() async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.remove(_kOtpSessionId),
      p.remove(_kOtpPhone),
      p.remove(_kOtpCustomToken),
      p.remove(_kOtpRole),
    ]);
  }

  /// On launch, detect the furthest saved checkpoint and resume from it.
  Future<void> _restoreSession() async {
    final p = await SharedPreferences.getInstance();

    // CP2: customToken saved — backend already verified the OTP.
    // Complete Firebase sign-in silently (no user input required).
    final savedToken = p.getString(_kOtpCustomToken);
    final savedRole = p.getString(_kOtpRole);
    if (savedToken != null && savedRole != null) {
      if (!mounted) return;
      setState(() => _resuming = true);
      try {
        await _completeFbSignIn(savedToken, savedRole);
        return;
      } catch (_) {
        // Token expired — fall through to CP1 or phone entry
        await _clearAllCheckpoints();
      } finally {
        if (mounted) setState(() => _resuming = false);
      }
    }

    // CP1: OTP was sent — user only needs to enter the code.
    final savedSession = p.getString(_kOtpSessionId);
    final savedPhone = p.getString(_kOtpPhone);
    if (savedSession != null && savedPhone != null && mounted) {
      setState(() {
        _sessionId = savedSession;
        _phoneController.text = savedPhone;
        _codeSent = true;
      });
    }
  }

  // ── Firebase completion (shared between new verify + CP2 recovery) ────────

  Future<void> _completeFbSignIn(String customToken, String role) async {
    final cred = await _authService.completePhoneOtpSignIn(customToken);
    await _clearAllCheckpoints();

    final uid = cred.user!.uid;
    final userRole = role == "worker" ? UserRole.worker : UserRole.customer;
    final phone = _phoneController.text.trim().replaceAll(RegExp(r"\D"), "");
    final normalized = phone.length == 12 && phone.startsWith("91")
        ? phone.substring(2)
        : phone;

    var user = await _authService.fetchUser(uid);
    user ??= AppUser(
      uid: uid,
      email: "$normalized@phone.workgo.in",
      displayName: userRole == UserRole.worker ? "Artisan" : "Customer",
      phoneNumber: "+91$normalized",
      role: userRole,
      region: "IN-TN",
    );
    await _authService.upsertUser(user);
    if (mounted) widget.onSuccess(user);
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
        // CP1 — persist before updating UI
        await _persistSessionSent(sid, normalized);
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
      // ── Step A: verify OTP with backend (returns customToken) ──────────
      final customToken = await _authService.verifyPhoneOtpGetToken(
        phone: normalized,
        otpCode: otp,
        sessionId: _sessionId!,
        role: widget.role.name,
      );

      // ── CP2: persist token BEFORE Firebase call ────────────────────────
      // If killed here, next launch completes sign-in without re-entering OTP.
      await _persistCustomToken(customToken, widget.role.name);

      // ── Step B: Firebase sign-in ───────────────────────────────────────
      await _completeFbSignIn(customToken, widget.role.name);
    } on FirebaseAuthException catch (e) {
      // customToken expired (e.g. device was off too long) — clear and restart
      if (e.code == "invalid-custom-token" || e.code == "custom-token-mismatch") {
        await _clearAllCheckpoints();
        if (mounted) {
          setState(() {
            _codeSent = false;
            _sessionId = null;
            _otpController.clear();
          });
          widget.onError("Session expired. Please request a new OTP.");
        }
      } else {
        widget.onError(e.message ?? e.toString());
      }
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _handleChangeNumber() async {
    await _clearAllCheckpoints();
    if (!mounted) return;
    setState(() {
      _codeSent = false;
      _sessionId = null;
      _otpController.clear();
    });
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Silent CP2 auto-resume: show spinner, no interaction needed
    if (_resuming) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(height: 12),
              Text(
                "Signing you in...",
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      );
    }

    final isBusy = widget.isLoading || _sending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_codeSent) ...[
          // ── Step 1: phone entry ─────────────────────────────────────────
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
          // ── Step 2: OTP code entry ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 14, color: Color(0xFF16A34A)),
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
                    child: CircularProgressIndicator(
                        color: Color(0xFF1A1A1A), strokeWidth: 2),
                  )
                : Text(
                    "verify_otp_btn".tr(),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
          ),
          const SizedBox(height: 6),
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
            icon: const Icon(Icons.mail_outline_rounded,
                size: 16, color: Color(0xFF4B5563)),
            label: Text(
              "auth_tab_email".tr(),
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
