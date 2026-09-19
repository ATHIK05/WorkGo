import "dart:async";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:easy_localization/easy_localization.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../../firebase/auth_service.dart";
import "../../models/app_user.dart";
import "../../theme/colors.dart";
import "../../theme/typography.dart";
import "auth_text_field.dart";

/// Frictionless Authentication Sheet for Customers and Artisans.
/// Presents 1-Tap Google Sign-In as hero, backed by 2Factor SMS Phone OTP and Email.
class CustomerAuthSheet extends StatefulWidget {
  const CustomerAuthSheet({
    super.key,
    required this.onSuccess,
    this.role = UserRole.customer,
    this.initialTab = CustomerAuthTab.google,
    this.isSignUp = false,
  });

  final void Function(AppUser user) onSuccess;
  final UserRole role;
  final CustomerAuthTab initialTab;
  final bool isSignUp;

  @override
  State<CustomerAuthSheet> createState() => _CustomerAuthSheetState();
}

enum CustomerAuthTab { google, phone, email }

class _CustomerAuthSheetState extends State<CustomerAuthSheet> {
  final AuthService _authService = AuthService();
  late CustomerAuthTab _currentTab;

  bool _isLoading = false;
  String? _errorMessage;

  // Phone OTP state
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  String? _sessionId;
  int _countdown = 0;
  Timer? _timer;

  // Email state
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _isSignUp = widget.isSignUp;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  Future<bool> _isRoleConflicting(String uid, AppUser? user) async {
    if (widget.role == UserRole.customer) {
      if (user != null && user.role == UserRole.worker) return true;
      try {
        final workerDoc = await FirebaseFirestore.instance.collection("workers").doc(uid).get();
        if (workerDoc.exists) return true;
      } catch (_) {}
    } else if (widget.role == UserRole.worker) {
      if (user != null && user.role == UserRole.customer) return true;
    }
    return false;
  }

  Future<void> _handleRoleConflict() async {
    await _authService.signOut(role: widget.role);
    if (mounted) {
      setState(() {
        _errorMessage = widget.role == UserRole.customer
            ? "error_karya_member_cannot_access_customer".tr()
            : "error_customer_cannot_access_karya".tr();
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = await _authService.signInWithGoogle(role: widget.role);
      final uid = cred.user!.uid;
      var appUser = await _authService.fetchUser(uid);

      if (await _isRoleConflicting(uid, appUser)) {
        await _handleRoleConflict();
        return;
      }

      appUser ??= AppUser(
        uid: uid,
        email: cred.user?.email ?? "",
        displayName: cred.user?.displayName ?? (widget.role == UserRole.worker ? "Artisan" : "Customer"),
        photoUrl: cred.user?.photoURL,
        role: widget.role,
        region: "IN-TN",
      );
      await _authService.upsertUser(appUser);
      if (widget.role == UserRole.worker) {
        try {
          await FirebaseFirestore.instance.collection('workers').doc(uid).set({
            'userId': uid,
            'name': appUser.displayName,
            'phoneForCalling': appUser.phoneNumber ?? "",
          }, SetOptions(merge: true));
        } catch (_) {}
      }
      if (mounted) {
        widget.onSuccess(appUser);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == "ERROR_ABORTED_BY_USER") {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (mounted) {
        setState(() => _errorMessage = e.message ?? "error_unknown".tr());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll("Exception:", "").trim());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendPhoneOtp() async {
    final raw = _phoneController.text.trim().replaceAll(RegExp(r"\D"), "");
    if (raw.length < 10) {
      setState(() => _errorMessage = "invalid_phone_error".tr());
      return;
    }
    final clean = raw.length == 12 && raw.startsWith("91") ? raw.substring(2) : raw;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
        setState(() => _errorMessage = res["error"]?.toString() ?? "Failed to send OTP");
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyPhoneOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4 || _sessionId == null) {
      setState(() => _errorMessage = "invalid_otp_error".tr());
      return;
    }

    final raw = _phoneController.text.trim().replaceAll(RegExp(r"\D"), "");
    final clean = raw.length == 12 && raw.startsWith("91") ? raw.substring(2) : raw;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = await _authService.signInWithPhoneOtp(
        phone: clean,
        otpCode: otp,
        sessionId: _sessionId!,
        role: widget.role.name,
      );

      final uid = cred.user!.uid;
      var user = await _authService.fetchUser(uid);

      if (await _isRoleConflicting(uid, user)) {
        await _handleRoleConflict();
        return;
      }

      user ??= AppUser(
        uid: uid,
        email: "$clean@phone.workgo.in",
        displayName: widget.role == UserRole.worker ? "Artisan" : "Customer",
        phoneNumber: "+91$clean",
        role: widget.role,
        region: "IN-TN",
      );
      await _authService.upsertUser(user);
      if (widget.role == UserRole.worker) {
        try {
          await FirebaseFirestore.instance.collection('workers').doc(uid).set({
            'userId': uid,
            'name': user.displayName,
            'phoneForCalling': clean,
            'phone': clean,
          }, SetOptions(merge: true));
        } catch (_) {}
      }
      if (mounted) {
        widget.onSuccess(user);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceAll("Exception:", "").trim());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final pwd = _passwordController.text;

    if (email.isEmpty || !email.contains("@")) {
      setState(() => _errorMessage = "error_email_invalid".tr());
      return;
    }
    if (pwd.length < 6) {
      setState(() => _errorMessage = "error_password_short".tr());
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential cred;
      if (_isSignUp) {
        cred = await _authService.signUp(email: email, password: pwd);
      } else {
        cred = await _authService.signIn(email: email, password: pwd);
      }

      final uid = cred.user!.uid;
      var user = await _authService.fetchUser(uid);

      if (await _isRoleConflicting(uid, user)) {
        await _handleRoleConflict();
        return;
      }

      user ??= AppUser(
        uid: uid,
        email: email,
        displayName: email.split("@").first,
        role: widget.role,
        region: "IN-TN",
      );
      await _authService.upsertUser(user);
      if (widget.role == UserRole.worker) {
        try {
          await FirebaseFirestore.instance.collection('workers').doc(uid).set({
            'userId': uid,
            'name': user.displayName,
          }, SetOptions(merge: true));
        } catch (_) {}
      }
      if (mounted) {
        widget.onSuccess(user);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message ?? "error_unknown".tr());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll("Exception:", "").trim());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pull bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header
            Text(
              widget.role == UserRole.worker
                  ? "welcome_worker_title".tr()
                  : "welcome_consumer_title".tr(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: WorkGoFonts.heading(
                color: const Color(0xFF141416),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.role == UserRole.worker
                  ? "welcome_worker_sub".tr()
                  : "welcome_consumer_sub".tr(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),

            // Error Banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFBE123C), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── HERO ACTION: 1-TAP GOOGLE SIGN-IN ──
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF141416),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading && _currentTab == CustomerAuthTab.google
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Center(
                              child: Text(
                                "G",
                                style: TextStyle(
                                  color: Color(0xFF4285F4),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              "continue_with_google".tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),

            // Divider
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    "or_continue_with".tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Selector: Phone OTP vs Email
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _currentTab = CustomerAuthTab.phone;
                        _errorMessage = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _currentTab == CustomerAuthTab.phone ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: _currentTab == CustomerAuthTab.phone
                              ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone_android_rounded,
                              size: 16,
                              color: _currentTab == CustomerAuthTab.phone
                                  ? const Color(0xFF141416)
                                  : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "auth_tab_phone".tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _currentTab == CustomerAuthTab.phone ? FontWeight.w800 : FontWeight.w600,
                                  color: _currentTab == CustomerAuthTab.phone
                                      ? const Color(0xFF141416)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _currentTab = CustomerAuthTab.email;
                        _errorMessage = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _currentTab == CustomerAuthTab.email ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: _currentTab == CustomerAuthTab.email
                              ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mail_outline_rounded,
                              size: 16,
                              color: _currentTab == CustomerAuthTab.email
                                  ? const Color(0xFF141416)
                                  : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "auth_tab_email".tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _currentTab == CustomerAuthTab.email ? FontWeight.w800 : FontWeight.w600,
                                  color: _currentTab == CustomerAuthTab.email
                                      ? const Color(0xFF141416)
                                      : const Color(0xFF6B7280),
                                ),
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
            const SizedBox(height: 16),

            // ── BODY: PHONE OTP OR EMAIL ──
            if (_currentTab == CustomerAuthTab.phone) ...[
              // Phone Input
              if (!_otpSent) ...[
                AuthTextField(
                  controller: _phoneController,
                  labelText: "phone_otp_title".tr(),
                  hintText: "phone_otp_sub".tr(),
                  prefixIcon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  enabled: !_isLoading,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSendPhoneOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F2937),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text("send_otp_btn".tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ] else ...[
                AuthTextField(
                  controller: _otpController,
                  labelText: "verify_otp_btn".tr(),
                  hintText: "enter_otp_hint".tr(),
                  prefixIcon: Icons.pin_rounded,
                  keyboardType: TextInputType.number,
                  enabled: !_isLoading,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyPhoneOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WorkGoColors.primary,
                      foregroundColor: const Color(0xFF141416),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Color(0xFF141416), strokeWidth: 2),
                          )
                        : Text("verify_otp_btn".tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                  _otpSent = false;
                                  _otpController.clear();
                                }),
                        child: Text(
                          "change_number".tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _countdown > 0
                          ? Text(
                              "${'resend_in'.tr()} ${_countdown}s",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                            )
                          : TextButton(
                              onPressed: _isLoading ? null : _handleSendPhoneOtp,
                              child: Text(
                                "resend_otp".tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // Email & Password
              AuthTextField(
                controller: _emailController,
                labelText: "invoice_email".tr(),
                hintText: "user@example.com",
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 10),
              AuthTextField(
                controller: _passwordController,
                labelText: "backup_password_title".tr(),
                hintText: "••••••••",
                prefixIcon: Icons.lock_outline_rounded,
                isPassword: true,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F2937),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isSignUp
                              ? (widget.role == UserRole.worker
                                  ? "btn_get_started_artisan".tr()
                                  : "btn_get_started".tr())
                              : "sign_in".tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _isSignUp = !_isSignUp;
                    _errorMessage = null;
                  }),
                  child: Text(
                    _isSignUp
                        ? "btn_already_have_account".tr()
                        : "new_user_create_account".tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Helper to display CustomerAuthSheet as a modern bottom modal
Future<void> showCustomerAuthSheet(
  BuildContext context, {
  required void Function(AppUser user) onSuccess,
  UserRole role = UserRole.customer,
  CustomerAuthTab initialTab = CustomerAuthTab.google,
  bool isSignUp = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CustomerAuthSheet(
      role: role,
      isSignUp: isSignUp,
      onSuccess: (user) {
        Navigator.of(ctx).pop();
        onSuccess(user);
      },
      initialTab: initialTab,
    ),
  );
}
