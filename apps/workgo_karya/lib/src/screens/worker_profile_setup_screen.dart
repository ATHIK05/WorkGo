import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';

class _TradeSkillMeta {
  final String key;
  final String imagePath;
  final IconData icon;
  final String titleKey;
  final String shortDescKey;
  final String fallbackTitle;
  final String fallbackShortDesc;

  const _TradeSkillMeta({
    required this.key,
    required this.imagePath,
    required this.icon,
    required this.titleKey,
    required this.shortDescKey,
    required this.fallbackTitle,
    required this.fallbackShortDesc,
  });
}

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

  static const List<_TradeSkillMeta> _tradeMetas = [
    _TradeSkillMeta(
      key: "Plumbing",
      imagePath: "assets/images/plumber.png",
      icon: Icons.plumbing_rounded,
      titleKey: "cat_plumbing",
      shortDescKey: "trade_short_plumbing",
      fallbackTitle: "Plumbing",
      fallbackShortDesc: "Pipes, taps & water repair",
    ),
    _TradeSkillMeta(
      key: "Electrical",
      imagePath: "assets/images/electrian.png",
      icon: Icons.electric_bolt_rounded,
      titleKey: "cat_electrical",
      shortDescKey: "trade_short_electrical",
      fallbackTitle: "Electrical",
      fallbackShortDesc: "Wiring, switches & lights",
    ),
    _TradeSkillMeta(
      key: "Carpentry",
      imagePath: "assets/images/carpentry.png",
      icon: Icons.carpenter_rounded,
      titleKey: "cat_carpentry",
      shortDescKey: "trade_short_carpentry",
      fallbackTitle: "Carpentry",
      fallbackShortDesc: "Furniture, doors & woodwork",
    ),
    _TradeSkillMeta(
      key: "Cleaning",
      imagePath: "assets/images/cleaning.png",
      icon: Icons.cleaning_services_rounded,
      titleKey: "cat_cleaning",
      shortDescKey: "trade_short_cleaning",
      fallbackTitle: "Cleaning",
      fallbackShortDesc: "Deep home & floor cleaning",
    ),
    _TradeSkillMeta(
      key: "Painting",
      imagePath: "assets/images/painting.png",
      icon: Icons.format_paint_rounded,
      titleKey: "cat_painting",
      shortDescKey: "trade_short_painting",
      fallbackTitle: "Painting",
      fallbackShortDesc: "Wall painting & touchups",
    ),
    _TradeSkillMeta(
      key: "Appliance Repair",
      imagePath: "assets/images/appliance_repair.png",
      icon: Icons.home_repair_service_rounded,
      titleKey: "cat_appliance",
      shortDescKey: "trade_short_appliance",
      fallbackTitle: "Appliance Repair",
      fallbackShortDesc: "AC, fridge & machines",
    ),
    _TradeSkillMeta(
      key: "Masonry",
      imagePath: "assets/images/masonry.png",
      icon: Icons.construction_rounded,
      titleKey: "cat_masonry",
      shortDescKey: "trade_short_masonry",
      fallbackTitle: "Masonry",
      fallbackShortDesc: "Brickwork, tiles & cement",
    ),
    _TradeSkillMeta(
      key: "Gardening",
      imagePath: "assets/images/gardening.png",
      icon: Icons.yard_rounded,
      titleKey: "cat_gardening",
      shortDescKey: "trade_short_gardening",
      fallbackTitle: "Gardening",
      fallbackShortDesc: "Lawn, garden & plants",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _experience = widget.worker.experienceYears.toDouble().clamp(1.0, 30.0);
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

  String _getExperienceLevel(int years) {
    if (years <= 2) return 'experience_level_beginner'.trSafe("Starter");
    if (years <= 5) return 'experience_level_skilled'.trSafe("Skilled");
    if (years <= 10) return 'experience_level_master'.trSafe("Master");
    return 'experience_level_veteran'.trSafe("Veteran Expert");
  }

  String _getTravelEstimate(double km) {
    if (km <= 5) return "~10-15 min • Local neighborhood";
    if (km <= 10) return "~15-25 min • Local town & nearby areas";
    if (km <= 15) return "~25-40 min • Wider city coverage";
    if (km <= 20) return "~35-50 min • Metropolitan region";
    return "~45-60+ min • Extended perimeter reach";
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'select_at_least_one_skill'.trSafe('Select at least one trade skill'),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'profile_skills_updated'.trSafe("Artisan profile & skills updated!"),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'artisan_skills_coverage_title'.trSafe("Artisan Skills & Coverage"),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A),
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'artisan_skills_coverage_simple_sub'.trSafe(
                "Choose your trades and how far you can travel for jobs",
              ),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            physics: const BouncingScrollPhysics(),
            children: [
              // ── Top Real-Time Status Capsule Banner ──
              _buildRealtimeStatusBanner(),
              const SizedBox(height: 18),

              // ── Section 1: Registered Trade Skills (Visual 2-Column Asset Image Grid) ──
              _buildTradeSkillsSection(),
              const SizedBox(height: 22),

              // ── Section 2: Trade Experience (Years + Quick Presets + Level) ──
              _buildExperienceSection(),
              const SizedBox(height: 20),

              // ── Section 3: Work Coverage Distance (Travel Radius + Estimate) ──
              _buildCoverageDistanceSection(),
              const SizedBox(height: 20),

              // ── Section 4: Public Artisan Name ──
              _buildArtisanNameSection(),
              const SizedBox(height: 16),

              // ── Section 5: Direct Calling Mobile Number ──
              _buildContactPhoneSection(),
              const SizedBox(height: 26),

              // ── Bottom Save Action CTA ──
              _buildSaveButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOP REAL-TIME STATUS CAPSULE BANNER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRealtimeStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFFD97706),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_selectedSkills.length} / ${_tradeMetas.length} ${'skills_selected_count'.trSafe('skills selected')}",
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF78350F),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "${_serviceRadius.toInt()} km radius • ${_experience.toInt()} ${'years_abbr'.trSafe('Years')} exp",
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF92400E),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getExperienceLevel(_experience.toInt()),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION 1: REGISTERED TRADE SKILLS (2-Column Visual Asset Cards)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTradeSkillsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'registered_trade_skills'.trSafe("Registered Trade Skills"),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${_selectedSkills.length} / ${_tradeMetas.length}",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFB45309),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          'trade_skills_help'.trSafe(
            "Tap trade cards to select or remove the services you offer",
          ),
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF64748B),
            fontSize: 12,
            height: 1.35,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 14),

        // 2-Column Grid with Seamless Visual Image Assets & Bento Aesthetics
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.74,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _tradeMetas.length,
          itemBuilder: (context, index) {
            final meta = _tradeMetas[index];
            final isSelected = _selectedSkills.contains(meta.key);

            return InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  if (isSelected) {
                    if (_selectedSkills.length > 1) {
                      _selectedSkills.remove(meta.key);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'select_at_least_one_skill'.trSafe(
                              'Select at least one trade skill',
                            ),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } else {
                    _selectedSkills.add(meta.key);
                  }
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFFDF5) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFD97706)
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? const Color(0x20D97706)
                          : const Color(0x0A000000),
                      blurRadius: isSelected ? 14 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top: Recognizable Trade Artwork (Seamlessly blended on pure canvas)
                    Expanded(
                      flex: 64,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Subtle ambient background warmth for selected trade
                              if (isSelected)
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          const Color(0xFFFEF3C7).withValues(alpha: 0.65),
                                          const Color(0xFFFEF3C7).withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                              // Full Illustration with seamless edge-to-edge canvas fit
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                                child: Image.asset(
                                  meta.imagePath,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),

                              // Bottom subtle gradient fade into card body
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 26,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        isSelected
                                            ? const Color(0xFFFFFDF5)
                                            : Colors.white,
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Top-Right Floating Status Chip
                              Positioned(
                                top: 8,
                                right: 8,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: isSelected
                                      ? const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        )
                                      : const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFD97706)
                                        : Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(20),
                                    border: isSelected
                                        ? null
                                        : Border.all(
                                            color: const Color(0xFFCBD5E1),
                                            width: 1.4,
                                          ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected
                                            ? const Color(0x33D97706)
                                            : const Color(0x14000000),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 13,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'btn_accepted'.trSafe("Accepted"),
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              maxLines: 1,
                                            ),
                                          ],
                                        )
                                      : const Icon(
                                          Icons.add_rounded,
                                          color: Color(0xFF64748B),
                                          size: 15,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom: Localized Trade Title & Category Badge
                    Expanded(
                      flex: 36,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3.5),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    meta.icon,
                                    size: 12,
                                    color: isSelected
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    meta.titleKey.trSafe(meta.fallbackTitle),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: isSelected
                                          ? const Color(0xFF78350F)
                                          : const Color(0xFF0F172A),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              meta.shortDescKey.trSafe(meta.fallbackShortDesc),
                              style: GoogleFonts.plusJakartaSans(
                                color: isSelected
                                    ? const Color(0xFF92400E)
                                    : const Color(0xFF64748B),
                                fontSize: 10.5,
                                height: 1.25,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION 2: TRADE EXPERIENCE (Years + Presets + Level Status)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildExperienceSection() {
    final expYears = _experience.toInt();
    const presets = [1, 3, 5, 8, 12, 20];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'trade_experience_label'.trSafe("Years of Experience"),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF0F172A),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getExperienceLevel(expYears),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFB45309),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$expYears ${'years_abbr'.trSafe('Years')}",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1-Tap Quick Presets
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((preset) {
              final isPresetSelected = expYears == preset;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _experience = preset.toDouble());
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPresetSelected
                        ? const Color(0xFFD97706)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isPresetSelected
                          ? const Color(0xFFD97706)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Text(
                    "$preset ${'years_abbr'.trSafe('Years')}",
                    style: GoogleFonts.plusJakartaSans(
                      color: isPresetSelected
                          ? Colors.white
                          : const Color(0xFF334155),
                      fontSize: 11.5,
                      fontWeight:
                          isPresetSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4.5,
              activeTrackColor: const Color(0xFFD97706),
              inactiveTrackColor: const Color(0xFFFDE68A),
              thumbColor: const Color(0xFFD97706),
              overlayColor: const Color(0x22D97706),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: _experience,
              min: 1.0,
              max: 30.0,
              divisions: 29,
              onChanged: (val) => setState(() => _experience = val),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION 3: WORK COVERAGE DISTANCE (Travel Radius + Estimates)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCoverageDistanceSection() {
    final radiusKm = _serviceRadius.toInt();
    const radiusPresets = [3.0, 5.0, 10.0, 15.0, 20.0, 25.0];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.near_me_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'dispatch_radius_label'.trSafe("Travel Distance for Work"),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF0F172A),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'travel_distance_desc'.trSafe(
                        "Customer job requests within this distance will reach your phone",
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF64748B),
                        fontSize: 11,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$radiusKm km",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Real-time travel estimate banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_bike_rounded,
                  color: Color(0xFFB45309),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getTravelEstimate(_serviceRadius),
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF92400E),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 1-Tap Distance Presets
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: radiusPresets.map((rPreset) {
              final isPresetSelected = radiusKm == rPreset.toInt();
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _serviceRadius = rPreset);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPresetSelected
                        ? const Color(0xFFD97706)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isPresetSelected
                          ? const Color(0xFFD97706)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Text(
                    "${rPreset.toInt()} km",
                    style: GoogleFonts.plusJakartaSans(
                      color: isPresetSelected
                          ? Colors.white
                          : const Color(0xFF334155),
                      fontSize: 11.5,
                      fontWeight:
                          isPresetSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4.5,
              activeTrackColor: const Color(0xFFD97706),
              inactiveTrackColor: const Color(0xFFFDE68A),
              thumbColor: const Color(0xFFD97706),
              overlayColor: const Color(0x22D97706),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: _serviceRadius,
              min: 1.0,
              max: 25.0,
              divisions: 24,
              onChanged: (val) => setState(() => _serviceRadius = val),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION 4: ARTISAN DISPLAY NAME
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildArtisanNameSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
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
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF0F172A),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'artisan_name_desc'.trSafe(
              "Customers in your area will see this name on your profile",
            ),
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF64748B),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'enter_full_name_hint'.trSafe("Enter full name (e.g. Ramesh Kumar)"),
              hintStyle: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF94A3B8),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
              counterText: "",
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION 5: CONTACT PHONE NUMBER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildContactPhoneSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
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
                  'contact_phone'.trSafe("Direct Calling Mobile Number"),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF0F172A),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'direct_call_phone_desc'.trSafe(
              "Customers and Karya support will call this number for bookings",
            ),
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF64748B),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Text(
                  "+91",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                ),
              ),
              hintText: 'phone_number_hint'.trSafe("10-digit mobile number"),
              hintStyle: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF94A3B8),
                fontSize: 13,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.8),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'error_phone_empty'.trSafe("Please enter mobile number");
              }
              final digits = val.replaceAll(RegExp(r'\D'), '');
              if (digits.length != 10) {
                return 'error_phone_invalid'.trSafe("Enter a valid 10-digit number");
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM SAVE BUTTON
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x35D97706),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'save_skills_coverage_btn'.trSafe("Save Skills & Coverage"),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }
}
