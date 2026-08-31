import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/worker_service.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'auth/auth_text_field.dart';
import 'glass_card.dart';
import 'safe_text.dart';
import 'workgo_button.dart';

class ProxyWorkerDialog extends StatefulWidget {
  const ProxyWorkerDialog({
    super.key,
    required this.referrerId,
    required this.referrerRole,
  });

  final String referrerId;
  final String referrerRole;

  static Future<void> show(
    BuildContext context, {
    required String referrerId,
    required String referrerRole,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => ProxyWorkerDialog(
        referrerId: referrerId,
        referrerRole: referrerRole,
      ),
    );
  }

  @override
  State<ProxyWorkerDialog> createState() => _ProxyWorkerDialogState();
}

class _ProxyWorkerDialogState extends State<ProxyWorkerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _experienceController = TextEditingController(text: "3");
  String _selectedSkill = "Plumbing";
  bool _isLoading = false;

  final List<String> _skills = [
    "Plumbing",
    "Electrical",
    "Carpentry",
    "Cleaning",
    "Painting",
    "Appliance Repair",
    "Masonry",
    "Gardening",
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final workerService = WorkerService();
      await workerService.referProxyWorker(
        name: _nameController.text.trim(),
        phoneForCalling: _phoneController.text.trim(),
        primarySkill: _selectedSkill,
        experienceYears: int.tryParse(_experienceController.text.trim()) ?? 1,
        referrerId: widget.referrerId,
        referrerRole: widget.referrerRole,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SafeText('proxy_submitted_success'.tr()),
            backgroundColor: WorkGoColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Submission error: $e"),
            backgroundColor: WorkGoColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(WorkGoSpacing.lg),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: WorkGoColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.phone_forwarded_rounded,
                        color: WorkGoColors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SafeText(
                            'proxy_dialog_title'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SafeText(
                            'proxy_dialog_subtitle'.tr(),
                            style: TextStyle(
                              color: WorkGoColors.textSecondary.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: WorkGoSpacing.lg),

                // Name
                AuthTextField(
                  controller: _nameController,
                  labelText: 'proxy_worker_name'.tr(),
                  hintText: 'e.g. Ramesh Kumar',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'error_name_empty'.tr() : null,
                ),
                const SizedBox(height: WorkGoSpacing.md),

                // Phone
                AuthTextField(
                  controller: _phoneController,
                  labelText: 'proxy_worker_phone'.tr(),
                  hintText: '+91 98765 43210',
                  prefixIcon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter valid phone number' : null,
                ),
                const SizedBox(height: WorkGoSpacing.md),

                // Skill dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
                      child: SafeText(
                        'proxy_worker_skill'.tr(),
                        style: TextStyle(
                          color: WorkGoColors.textSecondary.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131127).withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSkill,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1B1633),
                          icon: const Icon(Icons.arrow_drop_down, color: WorkGoColors.accent),
                          items: _skills.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(
                                s,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSkill = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: WorkGoSpacing.md),

                // Experience
                AuthTextField(
                  controller: _experienceController,
                  labelText: 'proxy_worker_experience'.tr(),
                  hintText: 'e.g. 5',
                  prefixIcon: Icons.history_rounded,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: WorkGoSpacing.xl),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: WorkGoButton(
                        label: 'Cancel',
                        variant: WorkGoButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: WorkGoSpacing.md),
                    Expanded(
                      flex: 2,
                      child: WorkGoButton(
                        label: 'submit_proxy'.tr(),
                        variant: WorkGoButtonVariant.primary,
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
