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
  State<ArtisanKeywordUpliftWidget> createState() => _ArtisanKeywordUpliftWidgetState();
}

class _ArtisanKeywordUpliftWidgetState extends State<ArtisanKeywordUpliftWidget> {
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
        .where((s) => !_equipmentTags.contains(s) && !_serviceKeywords.contains(s))
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
          SnackBar(
            content: Text('keywords_updated_toast'.tr()),
            backgroundColor: KX.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed_save_keywords_arg'.tr(args: [e.toString()])),
            backgroundColor: KX.rose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = _profileStrengthScore;
    final percent = (strength * 100).round();
    final suggestions = _availableSuggestions;

    return Container(
      padding: widget.isOffcanvasMode ? EdgeInsets.zero : const EdgeInsets.all(18),
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
          if (!widget.isOffcanvasMode) ...[
            // Header with AI icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: KX.violet.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: KX.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ai_match_equipment_tags_title'.tr(),
                        style: WorkGoFonts.heading(
                          color: KX.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'tag_machinery_desc'.tr(),
                        style: WorkGoFonts.body(
                          color: KX.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Strength Bar & Percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ai_triage_match_score'.tr(),
                style: WorkGoFonts.body(
                  color: KX.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'percent_strength_fmt'.tr(args: ['$percent']),
                style: WorkGoFonts.heading(
                  color: percent >= 80 ? KX.emerald : KX.amber,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: strength,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent >= 80 ? KX.emerald : KX.amber,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Active Tags & Keywords
          Text(
            'active_equipment_spec_count'.tr(args: ['${_equipmentTags.length + _serviceKeywords.length}']),
            style: WorkGoFonts.heading(
              color: KX.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),

          if (_equipmentTags.isEmpty && _serviceKeywords.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'no_tags_added_hint'.tr(),
                style: WorkGoFonts.body(
                  color: KX.textSecondary,
                  fontSize: 11.5,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._equipmentTags.map(
                  (tag) => Chip(
                    backgroundColor: KX.violet.withValues(alpha: 0.12),
                    side: BorderSide(color: KX.violet.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    label: Text(
                      tag,
                      style: WorkGoFonts.body(
                        color: KX.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14, color: KX.textSecondary),
                    onDeleted: () => _removeTag(tag),
                  ),
                ),
                ..._serviceKeywords.map(
                  (kw) => Chip(
                    backgroundColor: const Color(0xFFEFF6FF),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    label: Text(
                      kw,
                      style: WorkGoFonts.body(
                        color: const Color(0xFF1E40AF),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1E40AF)),
                    onDeleted: () => _removeTag(kw),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),

          // Quick Suggested Tags
          if (suggestions.isNotEmpty) ...[
            Text(
              'recommended_for_craft'.tr(),
              style: WorkGoFonts.body(
                color: KX.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: suggestions.take(6).map((s) {
                return ActionChip(
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: KX.dividerLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  avatar: const Icon(Icons.add_rounded, size: 14, color: KX.amber),
                  label: Text(
                    s,
                    style: WorkGoFonts.body(
                      color: KX.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _addSuggestion(s),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // Custom Keyword Input Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: KX.dividerLight),
                  ),
                  child: TextField(
                    controller: _customKeywordCtrl,
                    style: WorkGoFonts.body(color: KX.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'add_custom_tag_hint'.tr(),
                      hintStyle: WorkGoFonts.body(color: const Color(0xFF94A3B8), fontSize: 11.5),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _addCustomKeyword(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addCustomKeyword,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF141416),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveKeywords,
              style: ElevatedButton.styleFrom(
                backgroundColor: KX.violet,
                foregroundColor: const Color(0xFF141416),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF141416)),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                _isSaving ? 'saving_btn'.tr() : 'save_profile_specs_btn'.tr(),
                style: WorkGoFonts.body(
                  color: const Color(0xFF141416),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF9F6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Subtle Drag Handle
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),

              // Offcanvas Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141416),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: KX.gold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "specializations_tools_title".tr(),
                            style: WorkGoFonts.heading(
                              color: KX.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            "offcanvas_triage_manager".tr(),
                            style: WorkGoFonts.body(
                              color: KX.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: KX.textSecondary, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Scrollable Uplift Widget with keyboard safe padding
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    18,
                    16,
                    18,
                    MediaQuery.of(ctx).viewInsets.bottom + 28,
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
        );
      },
    );
  }
}

