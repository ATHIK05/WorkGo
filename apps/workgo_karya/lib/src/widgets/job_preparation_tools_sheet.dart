import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';
import '../screens/active_job_screen.dart';

/// Interactive modal sheet displaying domain-accurate tools, consumables, and PPE
/// immediately after an artisan accepts a service dispatch request.
class JobPreparationToolsSheet extends StatefulWidget {
  const JobPreparationToolsSheet({
    super.key,
    required this.booking,
    required this.worker,
  });

  final Booking booking;
  final Worker worker;

  static Future<void> show(
    BuildContext context, {
    required Booking booking,
    required Worker worker,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => JobPreparationToolsSheet(
        booking: booking,
        worker: worker,
      ),
    );
  }

  @override
  State<JobPreparationToolsSheet> createState() => _JobPreparationToolsSheetState();
}

class _JobPreparationToolsSheetState extends State<JobPreparationToolsSheet> {
  final Set<String> _checkedTools = {};
  late final TradeEquipmentKit _kit;

  @override
  void initState() {
    super.initState();
    _kit = TradeToolCatalog.getEquipmentKit(
      serviceType: widget.booking.serviceType,
      issueText: widget.booking.customerIssueDetails,
      symptomDescription: widget.booking.symptomDescription,
      equipmentTag: widget.booking.equipmentTag,
    );

    // If booking already had tools explicitly defined, merge them into primary tools
    if (widget.booking.suggestedToolsNeeded.isNotEmpty) {
      for (final tool in widget.booking.suggestedToolsNeeded) {
        if (!_kit.allTools.contains(tool)) {
          _kit.primaryTools.add(tool);
        }
      }
    }
  }

  Future<void> _launchMapsNavigation() async {
    final lat = widget.booking.customerLatitude;
    final lng = widget.booking.customerLongitude;
    final address = widget.booking.customerAddressText;

    Uri? uri;
    if (lat != null && lng != null) {
      // Prioritize exact coordinates
      final androidUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
      final fallbackUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
      );
      final appleUri = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d');

      if (Theme.of(context).platform == TargetPlatform.iOS) {
        uri = await canLaunchUrl(appleUri) ? appleUri : fallbackUri;
      } else {
        uri = await canLaunchUrl(androidUri) ? androidUri : fallbackUri;
      }
    } else if (address != null && address.isNotEmpty) {
      final encoded = Uri.encodeComponent(address);
      final searchUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encoded',
      );
      uri = searchUri;
    }

    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint("[JobPreparationToolsSheet] Map launch failed: $e");
      }
    }
  }

  void _proceedToActiveHud() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => ActiveJobScreen(
          booking: widget.booking,
          worker: widget.worker,
        ),
      ),
    );
  }

  String _formatAppointmentTime() {
    if (widget.booking.scheduledAt != null) {
      final dt = widget.booking.scheduledAt!;
      final dateStr = DateFormat('EEE, d MMM').format(dt);
      final timeStr = DateFormat('hh:mm a').format(dt);
      return "$dateStr · $timeStr";
    }
    return "booking_time_immediate".tr();
  }

  IconData _tradeIcon(String serviceType) {
    final lower = serviceType.toLowerCase();
    if (lower.contains('plumb')) return Icons.plumbing_rounded;
    if (lower.contains('electr') || lower.contains('wiring')) return Icons.bolt_rounded;
    if (lower.contains('carpent') || lower.contains('wood')) return Icons.carpenter_rounded;
    if (lower.contains('clean')) return Icons.cleaning_services_rounded;
    if (lower.contains('paint')) return Icons.format_paint_rounded;
    if (lower.contains('ac') || lower.contains('air condition')) return Icons.hvac_rounded;
    if (lower.contains('appliance') || lower.contains('washing') || lower.contains('fridge')) {
      return Icons.kitchen_rounded;
    }
    return Icons.build_rounded;
  }

  Widget _buildCheckablePill(String tool) {
    final isChecked = _checkedTools.contains(tool);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isChecked) {
            _checkedTools.remove(tool);
          } else {
            _checkedTools.add(tool);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isChecked ? const Color(0xFFD1FAE5) : KX.canvasCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isChecked ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
            width: isChecked ? 1.4 : 1.0,
          ),
          boxShadow: [
            if (!isChecked)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 15,
              color: isChecked ? const Color(0xFF065F46) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tool,
                style: TextStyle(
                  color: isChecked ? const Color(0xFF065F46) : KX.textPrimary,
                  fontSize: 12,
                  fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCategory({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: KX.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              "(${items.where((i) => _checkedTools.contains(i)).length}/${items.length})",
              style: TextStyle(
                color: KX.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map(_buildCheckablePill).toList(),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalTools = _kit.allTools.length;
    final checkedCount = _checkedTools.length;
    final customerName = widget.booking.customerName?.isNotEmpty == true
        ? widget.booking.customerName!
        : "Valued Customer";
    final addressText = widget.booking.customerAddressText?.isNotEmpty == true
        ? widget.booking.customerAddressText!
        : "Doorstep Location";

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: KX.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _tradeIcon(widget.booking.serviceType),
                      color: const Color(0xFFD97706),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "tools_preparation_title".tr(),
                          style: const TextStyle(
                            color: KX.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.booking.serviceType.tr(),
                          style: const TextStyle(
                            color: KX.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(color: KX.dividerLight, height: 1),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Job & Destination Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: KX.canvasCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF059669)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  customerName,
                                  style: const TextStyle(
                                    color: KX.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFFD97706)),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatAppointmentTime(),
                                      style: const TextStyle(
                                        color: Color(0xFFB45309),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  addressText,
                                  style: const TextStyle(
                                    color: KX.textSecondary,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (widget.booking.customerLatitude != null && widget.booking.customerLongitude != null) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(
                                "Doorstep GPS: ${widget.booking.customerLatitude!.toStringAsFixed(5)}, ${widget.booking.customerLongitude!.toStringAsFixed(5)}",
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Packing Progress Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Equipment Kit Checklist",
                          style: const TextStyle(
                            color: KX.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          "$checkedCount / $totalTools packed",
                          style: TextStyle(
                            color: checkedCount == totalTools
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalTools > 0 ? (checkedCount / totalTools) : 0,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          checkedCount == totalTools ? const Color(0xFF10B981) : const Color(0xFFFFB800),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Categorized Tools
                    _buildToolCategory(
                      title: "tools_primary".tr(),
                      icon: Icons.handyman_rounded,
                      color: const Color(0xFFD97706),
                      items: _kit.primaryTools,
                    ),

                    _buildToolCategory(
                      title: "tools_consumables".tr(),
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF2563EB),
                      items: _kit.consumables,
                    ),

                    _buildToolCategory(
                      title: "tools_safety".tr(),
                      icon: Icons.health_and_safety_outlined,
                      color: const Color(0xFF059669),
                      items: _kit.safetyGear,
                    ),
                  ],
                ),
              ),
            ),

            const Divider(color: KX.dividerLight, height: 1),

            // Bottom Actions Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Start Navigation Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _launchMapsNavigation,
                      icon: const Icon(Icons.near_me_rounded, size: 16, color: Color(0xFFB45309)),
                      label: Text(
                        "start_navigation_btn".tr(),
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                        backgroundColor: const Color(0xFFFEF3C7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Proceed to Active Job HUD
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _proceedToActiveHud,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF141416)),
                      label: Text(
                        "proceed_to_hud_btn".tr(),
                        style: const TextStyle(
                          color: Color(0xFF141416),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        backgroundColor: const Color(0xFFFFB800),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
