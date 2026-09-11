import "dart:async";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:easy_localization/easy_localization.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../firebase/auth_service.dart";
import "../localization/trade_localization.dart";
import "../models/app_user.dart";
import "../theme/colors.dart";
import "../theme/typography.dart";
import "safe_text.dart";

/// Professional Account Security & Trust Hub Card.
/// Embeds directly in the Profile page or opens as a bottom sheet.
/// Actively checks whether the account is linked with Email/Password, Google Sign-In,
/// and Phone Auth (carrier SMS OTP verified).
class ProfileTrustHubCard extends StatefulWidget {
  const ProfileTrustHubCard({
    super.key,
    required this.user,
    this.role = "customer",
    this.onUpdated,
  });

  final AppUser user;
  final String role;
  final VoidCallback? onUpdated;

  @override
  State<ProfileTrustHubCard> createState() => _ProfileTrustHubCardState();
}

class _ProfileTrustHubCardState extends State<ProfileTrustHubCard> {
  final AuthService _authService = AuthService();

  // Password fields
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _savingPwd = false;
  String? _pwdError;
  bool _showPwdForm = false;

  // Phone fields
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _showPhoneForm = false;
  bool _sendingOtp = false;
  bool _otpSent = false;
  String? _sessionId;
  String? _phoneError;
  int _countdown = 0;
  Timer? _timer;

  // Google linking state
  bool _linkingGoogle = false;

  @override
  void dispose() {
    _timer?.cancel();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool _hasEmail(AppUser user) =>
      (FirebaseAuth.instance.currentUser?.email?.isNotEmpty ?? false) || user.email.isNotEmpty;

  bool _hasPassword(AppUser user) =>
      (FirebaseAuth.instance.currentUser?.providerData.any((p) => p.providerId == "password") ?? false) ||
      user.hasBackupPassword;

  bool get _hasGoogle =>
      FirebaseAuth.instance.currentUser?.providerData.any((p) => p.providerId == "google.com") ?? false;

  bool _isPhoneLinked(AppUser user) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final hasAuthPhone = currentUser?.providerData.any((p) => p.providerId == "phone") ?? false;
    final hasAuthPhoneNum = (currentUser?.phoneNumber != null && currentUser!.phoneNumber!.trim().isNotEmpty);
    final isFirestorePhoneVerified = user.isPhoneVerified;

    return hasAuthPhone || hasAuthPhoneNum || isFirestorePhoneVerified;
  }

  int _calculateScore(AppUser user) {
    int linkedCount = 0;
    if (_hasPassword(user)) linkedCount++;
    if (_hasGoogle) linkedCount++;
    if (_isPhoneLinked(user)) linkedCount++;

    if (linkedCount == 0 && _hasEmail(user)) return 15;
    return ((linkedCount / 3.0) * 100).round();
  }

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

  Future<void> _handleSavePassword() async {
    final pwd = _newPwdController.text;
    final confirm = _confirmPwdController.text;

    if (pwd.length < 6) {
      setState(() => _pwdError = "pwd_length_error".trSafe("Minimum 6 characters required"));
      return;
    }
    if (pwd != confirm) {
      setState(() => _pwdError = "pwd_mismatch_error".trSafe("Passwords do not match"));
      return;
    }

    setState(() {
      _savingPwd = true;
      _pwdError = null;
    });

    try {
      await _authService.linkBackupPassword(pwd);
      if (mounted) {
        setState(() {
          _showPwdForm = false;
          _newPwdController.clear();
          _confirmPwdController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  "pwd_saved_success".trSafe("Backup password active"),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pwdError = e.toString().replaceAll("Exception:", "").trim());
      }
    } finally {
      if (mounted) setState(() => _savingPwd = false);
    }
  }

  Future<void> _handleLinkGoogle() async {
    setState(() => _linkingGoogle = true);
    try {
      await _authService.linkGoogleAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  "google_linked_success".trSafe("Google account linked successfully"),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString().contains("credential-already-in-use")
            ? "account_already_linked_error".trSafe("This Google account is already linked to another WorkGo account")
            : e.toString().replaceAll("Exception:", "").replaceAll("FirebaseAuthException:", "").trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _linkingGoogle = false);
    }
  }

  Future<void> _handleSendPhoneOtp() async {
    final raw = _phoneController.text.trim().replaceAll(RegExp(r"\D"), "");
    if (raw.length < 10) {
      setState(() => _phoneError = "invalid_phone_error".trSafe("Enter a valid 10-digit mobile number"));
      return;
    }
    final clean = raw.length == 12 && raw.startsWith("91") ? raw.substring(2) : raw;

    setState(() {
      _sendingOtp = true;
      _phoneError = null;
    });

    try {
      final res = await _authService.sendPhoneOtp(clean);
      if (res["success"] == true && res["sessionId"] != null) {
        setState(() {
          _otpSent = true;
          _sessionId = res["sessionId"] as String;
        });
        _startCountdown();
      } else {
        setState(() => _phoneError = res["error"]?.toString() ?? "Failed to send OTP");
      }
    } catch (e) {
      setState(() => _phoneError = e.toString());
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _handleVerifyPhoneOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4 || _sessionId == null) {
      setState(() => _phoneError = "invalid_otp_error".trSafe("Enter a valid verification code"));
      return;
    }

    final raw = _phoneController.text.trim().replaceAll(RegExp(r"\D"), "");
    final clean = raw.length == 12 && raw.startsWith("91") ? raw.substring(2) : raw;

    setState(() {
      _sendingOtp = true;
      _phoneError = null;
    });

    try {
      final res = await _authService.linkPhoneNumberWithOtp(
        phone: clean,
        otpCode: otp,
        sessionId: _sessionId!,
        role: widget.role,
      );

      if (res["success"] == true) {
        if (mounted) {
          setState(() {
            _showPhoneForm = false;
            _otpSent = false;
            _phoneController.clear();
            _otpController.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    "phone_verified_badge".trSafe("Carrier Verified"),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          widget.onUpdated?.call();
        }
      } else {
        setState(() => _phoneError = res["error"]?.toString() ?? "Failed to verify OTP");
      }
    } catch (e) {
      setState(() => _phoneError = e.toString());
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _authService.streamAppUser(widget.user.uid),
      initialData: widget.user,
      builder: (context, snapshot) {
        final liveUser = snapshot.data ?? widget.user;
        final score = _calculateScore(liveUser);

        final progressColor = score == 100
            ? const Color(0xFF10B981)
            : (score >= 66 ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B));

        // Pre-populate unverified phone number in controller if user hasn't edited yet
        if (!_showPhoneForm && _phoneController.text.isEmpty && liveUser.phoneNumber != null) {
          final digits = liveUser.phoneNumber!.replaceAll(RegExp(r"\D"), "");
          final clean = digits.length == 12 && digits.startsWith("91") ? digits.substring(2) : digits;
          if (clean.length == 10) {
            _phoneController.text = clean;
          }
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header & Trust Meter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "security_hub_title".trSafe("Account Security"),
                        style: WorkGoFonts.heading(
                          color: const Color(0xFF141416),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "profile_trust_score".trSafe("Security Status"),
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "$score%",
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: score / 100.0,
                  backgroundColor: const Color(0xFFF3F4F6),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 16),

              // 3-Pillar Micro Badges Matrix (Email + Google + Phone)
              _buildPillarStatusMatrix(liveUser),
              const SizedBox(height: 18),

              // ── PILLAR 1: EMAIL & PASSWORD ──
              _buildPasswordPillar(liveUser),
              const Divider(height: 22, color: Color(0xFFF3F4F6)),

              // ── PILLAR 2: GOOGLE SIGN-IN ──
              _buildGooglePillar(liveUser),
              const Divider(height: 22, color: Color(0xFFF3F4F6)),

              // ── PILLAR 3: PHONE AUTHENTICATION (CARRIER OTP) ──
              _buildPhonePillar(liveUser),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPillarStatusMatrix(AppUser user) {
    final emailActive = _hasPassword(user);
    final googleLinked = _hasGoogle;
    final phoneLinked = _isPhoneLinked(user);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0EDE6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPillarBadge(
            label: "pillar_email_short".trSafe("Email"),
            isLinked: emailActive,
            activeText: "status_active".trSafe("Active"),
            inactiveText: "status_unlinked".trSafe("Unlinked"),
          ),
          Container(width: 1, height: 24, color: const Color(0xFFE5E7EB)),
          _buildPillarBadge(
            label: "pillar_google_short".trSafe("Google"),
            isLinked: googleLinked,
            activeText: "status_linked".trSafe("Linked"),
            inactiveText: "status_unlinked".trSafe("Unlinked"),
          ),
          Container(width: 1, height: 24, color: const Color(0xFFE5E7EB)),
          _buildPillarBadge(
            label: "pillar_phone_short".trSafe("Phone OTP"),
            isLinked: phoneLinked,
            activeText: "status_verified".trSafe("Verified"),
            inactiveText: "status_unverified".trSafe("Unverified"),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarBadge({
    required String label,
    required bool isLinked,
    required String activeText,
    required String inactiveText,
  }) {
    final color = isLinked ? const Color(0xFF10B981) : const Color(0xFF9CA3AF);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isLinked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: color,
          size: 13,
        ),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            Text(
              isLinked ? activeText : inactiveText,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPillarTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isVerified,
    VoidCallback? onAction,
    String? actionLabel,
    bool isLoading = false,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Icon(icon, color: iconColor, size: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (isVerified)
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18)
        else if (isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1F2937)),
          )
        else if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGooglePillar(AppUser user) {
    final hasGoogle = _hasGoogle;
    final googleEmail = FirebaseAuth.instance.currentUser?.providerData
            .where((p) => p.providerId == "google.com")
            .map((p) => p.email)
            .firstOrNull ??
        (hasGoogle ? user.email : null);

    final subtitle = hasGoogle
        ? ((googleEmail != null && googleEmail.isNotEmpty)
            ? "$googleEmail • ${"google_linked_badge".trSafe("Linked")}"
            : "google_linked_badge".trSafe("Linked"))
        : "google_not_linked".trSafe("Not linked (1-tap recovery)");

    return _buildPillarTile(
      icon: Icons.alternate_email_rounded,
      iconColor: const Color(0xFF4285F4),
      title: "google_account_title".trSafe("Google Sign-In"),
      subtitle: subtitle,
      isVerified: hasGoogle,
      actionLabel: "link_google_btn".trSafe("Link Google"),
      isLoading: _linkingGoogle,
      onAction: hasGoogle ? null : _handleLinkGoogle,
    );
  }

  Widget _buildPhonePillar(AppUser user) {
    final isLinked = _isPhoneLinked(user);
    final rawPhone = user.phoneNumber ?? FirebaseAuth.instance.currentUser?.phoneNumber ?? "";
    final displayPhone = rawPhone.isNotEmpty ? rawPhone : "";

    if (isLinked) {
      return _buildPillarTile(
        icon: Icons.phone_android_rounded,
        iconColor: const Color(0xFF4F46E5),
        title: "phone_auth_title".trSafe("Phone Authentication"),
        subtitle: displayPhone.isNotEmpty
            ? "$displayPhone • ${"phone_verified_badge".trSafe("Carrier Verified")}"
            : "phone_verified_badge".trSafe("Carrier Verified"),
        isVerified: true,
      );
    }

    final subtitle = displayPhone.isNotEmpty
        ? "$displayPhone • ${"phone_unverified_badge".trSafe("Unverified")}"
        : "phone_otp_sub".trSafe("Enter 10-digit mobile number");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPillarTile(
          icon: Icons.phone_android_rounded,
          iconColor: const Color(0xFF4F46E5),
          title: "phone_auth_title".trSafe("Phone Authentication"),
          subtitle: subtitle,
          isVerified: false,
          actionLabel: _showPhoneForm ? "Cancel" : "verify_phone_otp_btn".trSafe("Verify via OTP"),
          onAction: () {
            setState(() {
              _showPhoneForm = !_showPhoneForm;
              _phoneError = null;
            });
          },
        ),
        if (_showPhoneForm) ...[
          const SizedBox(height: 12),
          if (_phoneError != null) ...[
            Text(
              _phoneError!,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
          ],
          if (!_otpSent) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: "10-digit mobile number",
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendingOtp ? null : _handleSendPhoneOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F2937),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                  child: _sendingOtp
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _countdown > 0 ? "$_countdown s" : "send_otp_btn".trSafe("Send OTP"),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      hintText: "enter_otp_hint".trSafe("Enter 6-digit OTP"),
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendingOtp ? null : _handleVerifyPhoneOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                  child: _sendingOtp
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          "verify_otp_btn".trSafe("Verify & Link"),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPasswordPillar(AppUser user) {
    final hasPassword = _hasPassword(user);
    final email = FirebaseAuth.instance.currentUser?.email ?? user.email;

    final subtitle = hasPassword
        ? (email.isNotEmpty ? "$email • ${"badge_pwd_active".trSafe("Password Active")}" : "badge_pwd_active".trSafe("Password Active"))
        : (email.isNotEmpty ? "$email • ${"email_no_password".trSafe("No password set")}" : "backup_password_subtitle".trSafe("Configure a password"));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPillarTile(
          icon: Icons.lock_outline_rounded,
          iconColor: const Color(0xFFD97706),
          title: "email_pwd_title".trSafe("Email & Password"),
          subtitle: subtitle,
          isVerified: hasPassword,
          actionLabel: _showPwdForm
              ? "Cancel"
              : (hasPassword ? "change_password_btn".trSafe("Change") : "set_password_btn".trSafe("Set Password")),
          onAction: () {
            setState(() {
              _showPwdForm = !_showPwdForm;
              _pwdError = null;
            });
          },
        ),
        if (_showPwdForm) ...[
          const SizedBox(height: 14),
          if (_pwdError != null) ...[
            Text(
              _pwdError!,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
          ],
          // New Password Field
          TextField(
            controller: _newPwdController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: "field_new_password".trSafe("New Password"),
              labelStyle: const TextStyle(fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: const Color(0xFF6B7280),
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Confirm Password Field
          TextField(
            controller: _confirmPwdController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: "field_confirm_password".trSafe("Confirm Password"),
              labelStyle: const TextStyle(fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: const Color(0xFF6B7280),
                ),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: _savingPwd ? null : _handleSavePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: _savingPwd
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    "btn_save_password".trSafe("Save Password"),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ],
    );
  }
}

/// Helper to display Profile Trust Hub bottom sheet
Future<void> showProfileTrustHubSheet(
  BuildContext context, {
  required AppUser user,
  String role = "customer",
  VoidCallback? onUpdated,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ProfileTrustHubCard(
              user: user,
              role: role,
              onUpdated: () {
                onUpdated?.call();
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
