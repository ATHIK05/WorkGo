import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'workgo_button.dart';

/// Shows an Obsidian Crimson styled Account Erasure confirmation bottom sheet
/// Compliant with DPDP Act 2023 §12 (Right to Erasure / Right to be Forgotten).
Future<bool?> showDeleteAccountConfirmationSheet(BuildContext context) {
  HapticFeedback.heavyImpact();
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _DeleteAccountSheetContent(),
  );
}

class _DeleteAccountSheetContent extends StatefulWidget {
  const _DeleteAccountSheetContent();

  @override
  State<_DeleteAccountSheetContent> createState() => _DeleteAccountSheetContentState();
}

class _DeleteAccountSheetContentState extends State<_DeleteAccountSheetContent> {
  bool _consentChecked = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFF0EDE6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 28,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle pill
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E0D8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header Icon & Title
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Delete Account & Wipe Data",
                      style: WorkGoFonts.display(
                        color: WorkGoColors.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "DPDP Act 2023 · Right to Erasure",
                      style: TextStyle(
                        color: Color(0xFFE11D48),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Detailed Erasure Notice Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWarningBullet(Icons.face_retouching_off_rounded, "All 3D facial biometric recordings, hashes, and liveness logs will be destroyed."),
                _buildWarningBullet(Icons.badge_outlined, "Aadhaar e-KYC records and Police Clearance documents will be permanently purged."),
                _buildWarningBullet(Icons.account_balance_wallet_outlined, "Earnings history, C2PA trust credentials, and artisan ratings will be irreversibly erased."),
                _buildWarningBullet(Icons.phonelink_erase_rounded, "Your phone/email login will be unlinked from the cooperative federation."),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Explicit Confirmation Checkbox
          Row(
            children: [
              Checkbox(
                value: _consentChecked,
                activeColor: const Color(0xFFE11D48),
                checkColor: Colors.white,
                onChanged: (val) => setState(() => _consentChecked = val ?? false),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _consentChecked = !_consentChecked),
                  child: Text(
                    "I acknowledge that this action is permanent and cannot be undone.",
                    style: TextStyle(
                      color: WorkGoColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: WorkGoButton(
                  label: "Cancel",
                  variant: WorkGoButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: !_consentChecked
                      ? null
                      : () {
                          Navigator.of(context).pop(true);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    disabledBackgroundColor: const Color(0xFFE5E0D8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 20),
                  label: const Text(
                    "Permanently Delete",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBullet(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFE11D48), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF9F1239),
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
