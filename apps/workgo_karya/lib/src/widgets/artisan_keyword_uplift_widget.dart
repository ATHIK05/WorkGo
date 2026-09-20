import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

/// Artisan Keyword Uplift Widget
/// Enables artisans to add specialized equipment tags and service keywords,
/// boosting their AI matching score when customers use Symptom-First Triage.
class ArtisanKeywordUpliftWidget extends StatefulWidget {
  final Worker worker;
  final VoidCallback? onKeywordsUpdated;
  final bool isOffcanvasMode;

  const ArtisanKeywordUpliftWidget({
    super.key,
    required this.worker,
    this.onKeywordsUpdated,
    this.isOffcanvasMode = false,
  });

  /// Calculates real profile match strength (0.0 to 1.0)
  static double calculateMatchStrength(Worker worker) {
    double score = 0.25; // Base registration
    if (worker.isApproved) score += 0.25;
    if (worker.skills.isNotEmpty) score += 0.15;
    final tagBonus = (worker.equipmentTags.length * 0.05).clamp(0.0, 0.20);
    score += tagBonus;
    final kwBonus = (worker.serviceKeywords.length * 0.05).clamp(0.0, 0.15);
    score += kwBonus;
    return score.clamp(0.0, 1.0);
  }

  /// Opens an offcanvas bottom sheet for managing equipment tags & service keywords
  static Future<void> showOffcanvas({
    required BuildContext context,
    required Worker worker,
    VoidCallback? onKeywordsUpdated,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      builder: (ctx) => _ArtisanKeywordOffcanvasSheet(
        worker: worker,
        onKeywordsUpdated: onKeywordsUpdated,
      ),
    );
  }

  @override
  State<ArtisanKeywordUpliftWidget> createState() =>
      _ArtisanKeywordUpliftWidgetState();
}

class _ArtisanKeywordUpliftWidgetState
    extends State<ArtisanKeywordUpliftWidget> {
  final BookingService _bookingService = BookingService();
  final TextEditingController _customKeywordCtrl = TextEditingController();

  late List<String> _equipmentTags;
  late List<String> _serviceKeywords;
  bool _isSaving = false;

  // Curated equipment & tool suggestions categorized by trade
  static const Map<String, List<String>> _tradeEquipmentSuggestions = {
    'Electrician': [
      'Submersible Pump',
      'Inverter Battery',
      'MCB Tripping',
      'Motor Rewinding',
      'Water Heater / Geyser',
      'Earth Leakage',
      'Switchboard Arcing',
      'Capacitor Replacement',
      '3-Phase Starter',
      'Ceiling Fan Coil',
    ],
    'Plumber': [
      'Submersible Pump',
      'Foot Valve',
      'Concealed Pipe Leak',
      'Pressure Booster Pump',
      'Overhead Tank Float',
      'CPVC Wall Seepage',
      'Drain Blockage',
      'Ceramic Tap Spindle',
      'Borewell Piping',
      'Flush Cistern Valve',
    ],
    'Appliance Repair': [
      'Inverter Split AC',
      'AC Gas Leak / Flare Nut',
      'Outdoor Compressor',
      'Washing Machine Drum',
      'RO UV Membrane',
      'Refrigerator Thermostat',
      'Microwave Magnetron',
      'Drain Pump Motor',
    ],
    'Carpenter': [
      'Hydraulic Hinge',
      'Modular Kitchen Slider',
      'Door Lock Mortise',
      'Termite Wood Treatment',
      'Wardrobe Soft Close',
    ],
    'Painter': [
      'Dampness Waterproofing',
      'Texture Roller',
      'Airless Spray',
      'Putty Wall Sanding',
      'Anti-Fungal Primer',
    ],
  };

  @override
  void initState() {
    super.initState();
    _equipmentTags = List<String>.from(widget.worker.equipmentTags);
    _serviceKeywords = List<String>.from(widget.worker.serviceKeywords);
  }

  @override
  void didUpdateWidget(covariant ArtisanKeywordUpliftWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worker != widget.worker) {
      _equipmentTags = List<String>.from(widget.worker.equipmentTags);
      _serviceKeywords = List<String>.from(widget.worker.serviceKeywords);
    }
  }

  @override
  void dispose() {
    _customKeywordCtrl.dispose();
    super.dispose();
  }

  /// Calculates real profile match strength (0.0 to 1.0)
  double get _profileStrengthScore {
    double score = 0.25; // Base registration

    if (widget.worker.isApproved) score += 0.25;
    if (widget.worker.skills.isNotEmpty) score += 0.15;

    // Equipment tags weight (+20%)
    final tagBonus = (_equipmentTags.length * 0.05).clamp(0.0, 0.20);
    score += tagBonus;

    // Keywords weight (+15%)
    final kwBonus = (_serviceKeywords.length * 0.05).clamp(0.0, 0.15);
    score += kwBonus;

    return score.clamp(0.0, 1.0);
  }

  List<String> get _availableSuggestions {
    final suggestions = <String>{};
    for (final skill in widget.worker.skills) {
      final tags = _tradeEquipmentSuggestions[skill];
      if (tags != null) {
        suggestions.addAll(tags);
      }
    }
    // Also add general default suggestions if empty
    if (suggestions.isEmpty) {
      suggestions.addAll([
        'Submersible Pump',
        'Motor Rewinding',
        'Inverter Battery',
        'Concealed Leak',
        'MCB Tripping',
      ]);
    }
    // Exclude already added tags
    return suggestions
        .where(
          (s) => !_equipmentTags.contains(s) && !_serviceKeywords.contains(s),
        )
        .toList();
  }

  void _addSuggestion(String tag) {
    HapticFeedback.lightImpact();
    setState(() {
      if (!_equipmentTags.contains(tag)) {
        _equipmentTags.add(tag);
      }
    });
  }

  String _getLocalizedTag(String tag) {
    final key = switch (tag.trim().toLowerCase()) {
      'inverter split ac' => 'tag_inverter_split_ac',
      'ac gas leak / flare nut' => 'tag_ac_gas_leak',
      'outdoor compressor' => 'tag_outdoor_compressor',
      'washing machine drum' => 'tag_washing_machine_drum',
      'ro uv membrane' => 'tag_ro_uv_membrane',
      'refrigerator thermostat' => 'tag_refrigerator_thermostat',
      'microwave magnetron' => 'tag_microwave_magnetron',
      'drain pump motor' => 'tag_drain_pump_motor',
      'submersible pump' => 'tag_submersible_pump',
      'motor rewinding' => 'tag_motor_rewinding',
      'inverter battery' => 'tag_inverter_battery',
      'mcb tripping' => 'tag_mcb_tripping',
      _ => null,
    };
    if (key != null) {
      final trVal = key.tr();
      if (trVal.isNotEmpty && trVal != key) return trVal;
    }
    return tag;
  }

  void _removeTag(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      _equipmentTags.remove(tag);
      _serviceKeywords.remove(tag);
    });
  }

  void _addCustomKeyword() {
    final text = _customKeywordCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();

    setState(() {
      if (!_serviceKeywords.contains(text) && !_equipmentTags.contains(text)) {
        _serviceKeywords.add(text);
      }
      _customKeywordCtrl.clear();
    });
  }

  Future<void> _saveKeywords() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      await _bookingService.saveWorkerKeywords(
        workerId: widget.worker.id,
        equipmentTags: _equipmentTags,
        serviceKeywords: _serviceKeywords,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        widget.onKeywordsUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile keywords updated! AI dispatch match strength increased.',
            ),
            backgroundColor: KX.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save keywords: $e'),
            backgroundColor: KX.rose,
          ),
        );
      }
    }
  }

  void _showTriageInfo(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: Color(0xFF2A9D8F),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'symptom_triage_dispatch_title'.trSafe(
                      'Symptom-First Triage',
                    ),
                    style: WorkGoFonts.heading(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: KX.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'symptom_triage_dispatch_desc'.trSafe(
                'When customers report specific emergencies (such as Borewell pump failure, MCB tripping, or AC gas leak), our AI matches them with artisans carrying verified equipment.\n\nEquipping your verified tools increases your priority dispatch score so you receive top-tier job callouts.',
              ),
              style: WorkGoFonts.body(
                fontSize: 13,
                height: 1.5,
                color: KX.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF141416),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'got_it'.trSafe('Got it'),
                  style: WorkGoFonts.heading(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffcanvasHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Title and Subtitle exactly matching mockup
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'specializations_and_tools'.trSafe(
                      'Specializations\n& Tools',
                    ),
                    style: WorkGoFonts.heading(
                      color: const Color(0xFF1E293B),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'equipment_triage_manager'.trSafe(
                      'Offcanvas Equipment &\nTriage Manager',
                    ),
                    style: WorkGoFonts.body(
                      color: const Color(0xFF64748B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right: Space reserved for the 3D overhanging avatar
          const SizedBox(width: 140, height: 110),
        ],
      ),
    );
  }

  Widget _buildToolboxBentoCard(BuildContext context) {
    final totalCount = _equipmentTags.length + _serviceKeywords.length;
    final progress = (totalCount / 20.0).clamp(0.05, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFFDE68A).withValues(alpha: 0.7),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top right Info button with circle border
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _showTriageInfo(context),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
          ),
          // Content Row: Left Open Toolbox Artwork, Right Horseshoe Arc Counter
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Open Isometric Toolbox Artwork
              Expanded(
                flex: 12,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Image.asset(
                    'assets/images/toolbox_open_isometric.png',
                    height: 118,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.home_repair_service_rounded,
                      size: 80,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Right: Horseshoe Radial Gauge with warm amber/gold and cream track
              Expanded(
                flex: 9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Horseshoe Arc Gauge Custom Painted in Warm Amber/Gold
                          CustomPaint(
                            size: const Size(88, 88),
                            painter: _HorseshoeGaugePainter(
                              progress: progress,
                              trackColor: const Color(0xFFFEF3C7),
                              progressColor: const Color(0xFFF59E0B),
                              strokeWidth: 9.0,
                            ),
                          ),
                          // Inner Number & counts label
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$totalCount',
                                style: WorkGoFonts.heading(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1E293B),
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'counts'.trSafe('counts'),
                                style: WorkGoFonts.body(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'active_equipment_title'.trSafe('Active equipment'),
                      style: WorkGoFonts.heading(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInputPill() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _customKeywordCtrl,
              style: WorkGoFonts.body(color: KX.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'add_custom_tag_hint_short'.trSafe(
                  'Add tag (e.g. Borewell)',
                ),
                hintStyle: WorkGoFonts.body(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onSubmitted: (_) => _addCustomKeyword(),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _addCustomKeyword,
            child: const Icon(
              Icons.search_rounded,
              color: Color(0xFFD97706),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _addCustomKeyword,
            child: Image.asset(
              'assets/images/toolbox_mini_closed.png',
              height: 32,
              width: 38,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.work_rounded,
                size: 22,
                color: Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _availableSuggestions;
    final totalCount = _equipmentTags.length + _serviceKeywords.length;

    return Container(
      padding: widget.isOffcanvasMode
          ? EdgeInsets.zero
          : const EdgeInsets.all(18),
      decoration: widget.isOffcanvasMode
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KX.dividerLight),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Offcanvas Header with Mascot & Typography (Mockup exact)
          if (widget.isOffcanvasMode) ...[
            _buildOffcanvasHeader(context),
            const SizedBox(height: 6),
          ],

          // 2. Bento Card with Open Toolbox & Horseshoe Radial Gauge
          _buildToolboxBentoCard(context),
          const SizedBox(height: 14),

          // 3. Tactile Search / Add Input Pill with Mini Toolbox
          _buildSearchInputPill(),
          const SizedBox(height: 18),

          // 4. Active Equipment Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'active_equipment_count'.trSafe(
                  'Active Equipment & Specializations ($totalCount)',
                  ['$totalCount'],
                ),
                style: WorkGoFonts.heading(
                  color: const Color(0xFF1E293B),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (totalCount > 0)
                Text(
                  '${(_profileStrengthScore * 100).round()}% ${'match_score'.trSafe('Match')}',
                  style: WorkGoFonts.body(
                    color: const Color(0xFFD97706),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_equipmentTags.isEmpty && _serviceKeywords.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'no_equipment_tags_hint'.trSafe(
                  'No equipment tags added yet. Select recommended tools below or add your custom kit.',
                ),
                style: WorkGoFonts.body(
                  color: KX.textSecondary,
                  fontSize: 12,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._equipmentTags.map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getLocalizedTag(tag),
                          style: WorkGoFonts.body(
                            color: const Color(0xFF141416),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _removeTag(tag),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ..._serviceKeywords.map(
                  (kw) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEFCE8),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFFEF08A),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getLocalizedTag(kw),
                          style: WorkGoFonts.body(
                            color: const Color(0xFF141416),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _removeTag(kw),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Color(0xFF854D0E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),

          // 5. Quick Suggested Tags by Craft
          if (suggestions.isNotEmpty) ...[
            Text(
              'recommended_for_craft'.trSafe('Recommended for your Craft'),
              style: WorkGoFonts.body(
                color: const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: suggestions.take(8).map((s) {
                return GestureDetector(
                  onTap: () => _addSuggestion(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getLocalizedTag(s),
                          style: WorkGoFonts.body(
                            color: const Color(0xFF1E293B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // 6. Save Button (Sync to Firestore)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveKeywords,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF141416),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: Color(0xFFF59E0B),
                    ),
              label: Text(
                _isSaving
                    ? 'saving_btn'.trSafe('Saving...')
                    : 'Save Profile Specializations',
                style: WorkGoFonts.body(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Horseshoe Radial Gauge Painter matching the target mockup
class _HorseshoeGaugePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _HorseshoeGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 9.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    const startAngle = 0.75 * math.pi; // 135 degrees (bottom-left)
    const sweepTotal = 1.5 * math.pi; // 270 degrees sweep clockwise

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background track arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    // Active progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * progress.clamp(0.01, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HorseshoeGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.trackColor != trackColor;
}

/// Offcanvas Bottom Sheet for managing Artisan Equipment Tags & Service Keywords
class _ArtisanKeywordOffcanvasSheet extends StatelessWidget {
  final Worker worker;
  final VoidCallback? onKeywordsUpdated;

  const _ArtisanKeywordOffcanvasSheet({
    required this.worker,
    this.onKeywordsUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. The Bottom Sheet Canvas (padded from top by 50dp so avatar's head overhangs)
            Padding(
              padding: const EdgeInsets.only(top: 50),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF9F6),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  child: Stack(
                    children: [
                      // Top warm sunlight / cream gradient wash
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 200,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFEF3C7), Color(0xFFFAF9F6)],
                            ),
                          ),
                        ),
                      ),

                      // Main Content Column
                      Column(
                        children: [
                          // Pinned subtle Drag Handle
                          const SizedBox(height: 12),
                          Center(
                            child: Container(
                              width: 44,
                              height: 4.5,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF94A3B8,
                                ).withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Scrollable Uplift Widget with keyboard safe padding
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                2,
                                16,
                                MediaQuery.of(ctx).viewInsets.bottom + 32,
                              ),
                              child: ArtisanKeywordUpliftWidget(
                                worker: worker,
                                isOffcanvasMode: true,
                                onKeywordsUpdated: () {
                                  onKeywordsUpdated?.call();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. The 3D Pop-Out Hero Avatar Overhanging the Sheet Top
            Positioned(
              top: 0,
              right: 6,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/specialization_worker_header.png',
                  height: 175,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
