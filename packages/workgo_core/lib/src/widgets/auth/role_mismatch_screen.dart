import "package:easy_localization/easy_localization.dart";
import "package:flutter/material.dart";
import "../../models/app_user.dart";
import "../safe_text.dart";

/// Screen displayed when an authenticated user's role does not match
/// the current application (e.g. a Karya Member attempting to access
/// the Customer app, or a Customer attempting to access the Karya app).
class RoleMismatchScreen extends StatelessWidget {
  const RoleMismatchScreen({
    super.key,
    required this.targetRole,
    required this.user,
    required this.onSignOut,
  });

  /// The role that this specific app expects.
  final UserRole targetRole;

  /// The active user whose role mismatches [targetRole].
  final AppUser user;

  /// Callback to sign out and return to the login interface.
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final isCustomerApp = targetRole == UserRole.customer;

    final titleKey = isCustomerApp
        ? "karya_member_detected_title"
        : "customer_account_detected_title";
    final descKey = isCustomerApp
        ? "karya_member_detected_desc"
        : "customer_account_detected_desc";

    final roleBadgeText = user.role == UserRole.worker
        ? "Karya Member"
        : (user.role == UserRole.customer ? "Customer" : "Admin");

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon badge container
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF261D1A),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.switch_account_rounded,
                        color: Color(0xFFFFB800),
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Headline
                  SafeText(
                    titleKey.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    enableAutoShrink: true,
                    minFontSize: 16,
                  ),
                  const SizedBox(height: 12),

                  // Explanatory description
                  SafeText(
                    descKey.tr(),
                    style: const TextStyle(
                      color: Color(0xFF9E9EA7),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    enableAutoShrink: true,
                    minFontSize: 12,
                  ),
                  const SizedBox(height: 28),

                  // Account card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1A24),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2E2D3D),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Avatar / initial badge
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2A2938),
                            border: Border.all(
                              color: const Color(0xFF3E3D4F),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: SafeText(
                              user.displayName.isNotEmpty
                                  ? user.displayName.substring(0, 1).toUpperCase()
                                  : "U",
                              style: const TextStyle(
                                color: Color(0xFFFFB800),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Account details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SafeText(
                                user.displayName.isNotEmpty
                                    ? user.displayName
                                    : "User",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                enableAutoShrink: true,
                                minFontSize: 12,
                              ),
                              const SizedBox(height: 3),
                              SafeText(
                                user.email.isNotEmpty
                                    ? user.email
                                    : (user.phoneNumber ?? ""),
                                style: const TextStyle(
                                  color: Color(0xFF7E7D8F),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                enableAutoShrink: true,
                                minFontSize: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E2416),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: SafeText(
                            roleBadgeText,
                            style: const TextStyle(
                              color: Color(0xFFFFB800),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            enableAutoShrink: true,
                            minFontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Button: Use Different Account
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        await onSignOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB800),
                        foregroundColor: const Color(0xFF0F0E17),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            size: 18,
                            color: Color(0xFF0F0E17),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: SafeText(
                              "btn_use_different_account".tr(),
                              style: const TextStyle(
                                color: Color(0xFF0F0E17),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              enableAutoShrink: true,
                              minFontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
