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
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Select at least one trade skill"),
          backgroundColor: KX.rose,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final workerService = WorkerService();

    final updated = widget.worker.copyWith(
      skills: _selectedSkills.toList(),
      experienceYears: _experience.toInt(),
      serviceRadiusKm: _serviceRadius,
    );

    await workerService.upsertWorkerProfile(updated);

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
              const Text("Artisan profile & skills updated!"),
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
      appBar: const KaryaAppBar(
        title: "Artisan Skills & Coverage",
        subtitle: "Customize your trade dispatch matrix",
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    title: "Trade Experience",
                    value: _experience,
                    displayValue: "${_experience.toInt()} Years",
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
                    title: "Dispatch Service Radius",
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
                const SizedBox(height: 20),

                // Save CTA
                KSlideFadeIn(
                  delay: const Duration(milliseconds: 140),
                  child: KaryaButton(
                    label: "Save Artisan Matrix",
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
              Text(
                title,
                style: WorkGoFonts.heading(
                  color: KX.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
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
