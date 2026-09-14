import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

class WorkerProfileSetupScreen extends StatefulWidget {
  const WorkerProfileSetupScreen({
    super.key,
    required this.worker,
    required this.onProfileUpdated,
  });

  final Worker worker;
  final VoidCallback onProfileUpdated;

  @override
  State<WorkerProfileSetupScreen> createState() =>
      _WorkerProfileSetupScreenState();
}

class _WorkerProfileSetupScreenState extends State<WorkerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late double _experience;
  late double _serviceRadius;
  late Set<String> _selectedSkills;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isSaving = false;

  final List<String> _availableSkills = [
    "Plumbing",
    "Electrical",
    "Carpentry",
    "Cleaning",
    "Painting",
    "Appliance Repair",
    "Masonry",
    "Gardening",
  ];

  final Map<String, IconData> _skillIcons = {
    "Plumbing": Icons.plumbing_rounded,
    "Electrical": Icons.electric_bolt_rounded,
    "Carpentry": Icons.carpenter_rounded,
    "Cleaning": Icons.cleaning_services_rounded,
    "Painting": Icons.format_paint_rounded,
    "Appliance Repair": Icons.home_repair_service_rounded,
    "Masonry": Icons.construction_rounded,
    "Gardening": Icons.yard_rounded,
  };

  @override
  void initState() {
    super.initState();
    _experience =
        widget.worker.experienceYears.toDouble().clamp(1.0, 30.0);
    _serviceRadius = widget.worker.serviceRadiusKm.clamp(1.0, 25.0);
    _selectedSkills = widget.worker.skills.isNotEmpty
        ? widget.worker.skills.toSet()
        : {"Plumbing", "Carpentry"};
    _nameController = TextEditingController(
      text: widget.worker.name != "Co-op Artisan" &&
              widget.worker.name != "Artisan Partner"
          ? widget.worker.name
          : "",
    );
    _phoneController = TextEditingController(
      text: widget.worker.phoneForCalling?.replaceFirst('+91', '') ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('select_at_least_one_skill'.trSafe('Select at least one trade skill')),
          backgroundColor: KX.rose,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final workerService = WorkerService();

    final nameRaw = _nameController.text.trim();
    final updatedName = nameRaw.isNotEmpty ? nameRaw : widget.worker.name;

    final phoneRaw = _phoneController.text.trim();
    final normalizedPhone = phoneRaw.startsWith('+91')
        ? phoneRaw
        : (phoneRaw.isNotEmpty ? '+91$phoneRaw' : null);

    final updated = widget.worker.copyWith(
      name: updatedName,
      skills: _selectedSkills.toList(),
      experienceYears: _experience.toInt(),
      serviceRadiusKm: _serviceRadius,
      phoneForCalling: normalizedPhone,
    );

    await workerService.upsertWorkerProfile(updated);

    if (nameRaw.isNotEmpty) {
      try {
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null) {
          await authUser.updateDisplayName(nameRaw);
        }
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.worker.userId)
            .set({
          'displayName': nameRaw,
          'name': nameRaw,
        }, SetOptions(merge: true));
        await FirebaseFirestore.instance
            .collection('workers')
            .doc(widget.worker.id)
            .set({
          'name': nameRaw,
          'displayName': nameRaw,
          'artisanName': nameRaw,
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    if (normalizedPhone != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.worker.userId)
            .set({
          'phoneNumber': normalizedPhone,
        }, SetOptions(merge: true));
        await FirebaseFirestore.instance
            .collection('workers')
            .doc(widget.worker.id)
            .set({
          'phoneForCalling': normalizedPhone,
          'phone': normalizedPhone,
          'phoneNumber': normalizedPhone,
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _isSaving = false);
      widget.onProfileUpdated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('profile_skills_updated'.trSafe("Artisan profile & skills updated!")),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return KaryaScaffold(
      appBar: KaryaAppBar(
        title: 'artisan_skills_coverage_title'.trSafe("Artisan Skills & Coverage"),
        subtitle: 'artisan_skills_coverage_sub'.trSafe("Customize your trade dispatch matrix"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Artisan Display Name Card ──
                KSlideFadeIn(
                  child: KaryaCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.badge_outlined,
                              color: Color(0xFFD97706),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'artisan_display_name_label'.trSafe("Artisan Display Name"),
                                style: WorkGoFonts.heading(
                                  color: KX.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 40,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: KX.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'enter_full_name_hint'.trSafe("Enter full name (e.g. Ramesh Kumar)"),
                            hintStyle: const TextStyle(
                              color: KX.textSecondary,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              size: 18,
                              color: KX.textSecondary,
                            ),
                            counterText: "",
                            filled: true,
                            fillColor: const Color(0xFFF9F6EE),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: KX.gold, width: 1.8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Skill Selection
                KSlideFadeIn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Registered Trade Skills",
                        style: WorkGoFonts.display(
                          color: KX.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Tap trades to activate incoming dispatch alerts",
                        style: WorkGoFonts.body(
                          color: KX.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSkillGrid(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Experience Slider
                KSlideFadeIn(
                  delay: const Duration(milliseconds: 60),
                  child: _SliderCard(
                    title: 'trade_experience_label'.trSafe("Trade Experience"),
                    value: _experience,
                    displayValue: "${_experience.toInt()} ${'years_abbr'.trSafe('Years')}",
                    min: 1.0,
                    max: 30.0,
                    divisions: 29,
                    color: KX.gold,
                    gradient: KX.luminaVioletGold,
                    icon: Icons.workspace_premium_rounded,
                    onChanged: (val) => setState(() => _experience = val),
                  ),
                ),
                const SizedBox(height: 12),

                // Radius Slider
                KSlideFadeIn(
                  delay: const Duration(milliseconds: 100),
                  child: _SliderCard(
                    title: 'dispatch_radius_label'.trSafe("Dispatch Service Radius"),
                    value: _serviceRadius,
                    displayValue: "${_serviceRadius.toInt()} km",
                    min: 1.0,
                    max: 25.0,
                    divisions: 24,
                    color: KX.violetNeon,
                    gradient: KX.auroraVioletNeon,
                    icon: Icons.radar_rounded,
                    onChanged: (val) => setState(() => _serviceRadius = val),
                  ),
                ),
                const SizedBox(height: 14),

                // Contact Phone Number Card
                KSlideFadeIn(
                  delay: const Duration(milliseconds: 120),
                  child: KaryaCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_android_rounded,
                              color: Color(0xFFD97706),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'contact_phone'.tr(),
                                style: WorkGoFonts.heading(
                                  color: KX.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: KX.textPrimary,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                "+91",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: KX.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            hintText: 'phone_number_hint'.tr(),
                            hintStyle: TextStyle(
                              color: KX.textMuted.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: KX.canvas,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFD97706),
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'error_phone_empty'.tr();
                            }
                            final digits = val.replaceAll(RegExp(r'\D'), '');
                            if (digits.length != 10) {
                              return 'error_phone_invalid'.tr();
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Save CTA
                KSlideFadeIn(
                  delay: const Duration(milliseconds: 140),
                  child: KaryaButton(
                    label: 'save_artisan_matrix_btn'.trSafe("Save Artisan Matrix"),
                    icon: Icons.save_rounded,
                    isLoading: _isSaving,
                    onPressed: _saveProfile,
                    gradient: KX.luminaVioletGold,
                    glowColor: KX.gold,
                    height: 50,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkillGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.84,
        crossAxisSpacing: 8,
        mainAxisSpacing: 10,
      ),
      itemCount: _availableSkills.length,
      itemBuilder: (context, index) {
        final skill = _availableSkills[index];
        final isSelected = _selectedSkills.contains(skill);
        final icon = _skillIcons[skill] ?? Icons.handyman_rounded;

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected && _selectedSkills.length > 1) {
                _selectedSkills.remove(skill);
              } else {
                _selectedSkills.add(skill);
              }
            });
          },
          child: AnimatedContainer(
            duration: KAnim.fast,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: isSelected ? KX.luminaVioletGold : null,
              color: isSelected ? null : KX.canvasCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? KX.gold.withValues(alpha: 0.7)
                    : KX.glassBorder,
                width: 1.1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: KX.violet.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20)
                else
                  Icon(icon,
                      color: KX.textMuted.withValues(alpha: 0.7), size: 20),
                const SizedBox(height: 5),
                Text(
                  skill,
                  style: WorkGoFonts.heading(
                    color: isSelected ? Colors.white : KX.textSecondary,
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────
//  SLIDER CARD — Lumina styled
// ──────────────────────────────────────────────────────
class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.title,
    required this.value,
    required this.displayValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.gradient,
    required this.icon,
    required this.onChanged,
  });

  final String title;
  final double value;
  final String displayValue;
  final double min;
  final double max;
  final int divisions;
  final Color color;
  final LinearGradient gradient;
  final IconData icon;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return KaryaCard(
      glowColor: color,
      borderColor: color.withValues(alpha: 0.25),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: WorkGoFonts.heading(
                    color: KX.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  displayValue,
                  style: WorkGoFonts.numeric(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3.5,
              activeTrackColor: color,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: Colors.white,
              overlayColor: color.withValues(alpha: 0.18),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
