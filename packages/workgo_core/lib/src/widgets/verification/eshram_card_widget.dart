import "package:easy_localization/easy_localization.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";
import "../../services/aadhaar_qr_service.dart";
import "../../theme/colors.dart";

/// e-Shram UAN entry + optional QR scan widget.
///
/// Recommended — not mandatory. Shows benefit clearly.
/// Falls back gracefully to manual UAN entry if QR scan isn't available.
class EshramCardWidget extends StatefulWidget {
  const EshramCardWidget({
    super.key,
    required this.workerId,
    required this.declaredTrade,
    required this.onSuccess,
    required this.onSkip,
  });

  final String workerId;
  final String? declaredTrade;
  final void Function(int trustScore) onSuccess;
  final VoidCallback onSkip;

  @override
  State<EshramCardWidget> createState() => _EshramCardWidgetState();
}

class _EshramCardWidgetState extends State<EshramCardWidget> {
  final _uanController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _uanController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final uan = _uanController.text.trim().replaceAll(RegExp(r"\D"), "");
    if (uan.length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "eshram_uan_invalid".tr(),
            style: const TextStyle(fontSize: 13),
          ),
          backgroundColor: WorkGoColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      final score = await AadhaarQrService.submitEshram(
        workerId: widget.workerId,
        uan: uan,
        trade: widget.declaredTrade,
      );
      if (mounted) {
        setState(() => _submitted = true);
        HapticFeedback.heavyImpact();
        widget.onSuccess(score);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString(), style: const TextStyle(fontSize: 13)),
            backgroundColor: WorkGoColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _openEshramPortal() async {
    final uri = Uri.parse("https://eshram.gov.in");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7), shape: BoxShape.circle),
              child: const Icon(Icons.how_to_reg_rounded,
                  color: Color(0xFF16A34A), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              "eshram_verified_badge".tr(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF15803D),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Benefit callout — small, not loud
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFD966).withAlpha(180)),
          ),
          child: Row(
            children: [
              const Icon(Icons.trending_up_rounded,
                  size: 16, color: Color(0xFF92400E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "eshram_benefit_hint".tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF78350F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // UAN input
        TextField(
          controller: _uanController,
          keyboardType: TextInputType.number,
          enabled: !_submitting,
          maxLength: 12,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: WorkGoColors.textPrimary,
            letterSpacing: 1.5,
          ),
          decoration: InputDecoration(
            labelText: "eshram_uan_hint".tr(),
            labelStyle:
                const TextStyle(fontSize: 13, color: WorkGoColors.textSecondary),
            counterText: "",
            prefixIcon: const Icon(Icons.badge_rounded,
                size: 20, color: WorkGoColors.textSecondary),
            filled: true,
            fillColor: const Color(0xFFFFFBF2),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF0EDE6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: WorkGoColors.primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          ),
        ),
        const SizedBox(height: 10),

        // Submit button
        ElevatedButton(
          onPressed: _submitting ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: WorkGoColors.primary,
            foregroundColor: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.symmetric(vertical: 13),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.black, strokeWidth: 2))
              : Text(
                  "eshram_link_btn".tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                ),
        ),
        const SizedBox(height: 6),

        // Row: Register link + Skip
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _submitting ? null : _openEshramPortal,
              icon: const Icon(Icons.open_in_new_rounded,
                  size: 14, color: WorkGoColors.info),
              label: Text(
                "eshram_register_link".tr(),
                style: const TextStyle(
                    fontSize: 12,
                    color: WorkGoColors.info,
                    fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: _submitting ? null : widget.onSkip,
              child: Text(
                "eshram_skip_prompt".tr(),
                style: const TextStyle(
                    fontSize: 12, color: WorkGoColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
