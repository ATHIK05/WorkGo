import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';
import '../services/karya_tts_service.dart';
import '../widgets/translated_text.dart';
import 'active_job_screen.dart';

class IncomingRequestsScreen extends StatefulWidget {
  const IncomingRequestsScreen({
    super.key,
    required this.worker,
    this.requestsHubKey,
  });
  final Worker worker;
  final GlobalKey? requestsHubKey;

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen> {
  String _selectedFilter = "All";
  int _selectedRadiusKm = 10;
  bool _audioChimeEnabled = true;

  @override
  void initState() {
    super.initState();
    _selectedRadiusKm = widget.worker.serviceRadiusKm > 0
        ? widget.worker.serviceRadiusKm.toInt().clamp(5, 30)
        : 10;
  }

  @override
  Widget build(BuildContext context) {
    final bookingService = BookingService();

    final filterOptions = [
      "All",
      if (widget.worker.skills.isNotEmpty) ...widget.worker.skills,
    ];

    return Scaffold(
      backgroundColor: KX.canvas,
      appBar: AppBar(
        backgroundColor: KX.canvas,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF0EDE6)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: KX.textPrimary),
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'radar_cockpit_title'.tr(),
              style: WorkGoFonts.heading(
                color: KX.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'active_radius_km'.tr(args: ['$_selectedRadiusKm', '${widget.worker.skills.length}'] ),
              style: WorkGoFonts.body(
                color: KX.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _audioChimeEnabled ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _audioChimeEnabled ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFE5E0D8),
                ),
              ),
              child: Icon(
                _audioChimeEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                size: 16,
                color: _audioChimeEnabled ? const Color(0xFF047857) : const Color(0xFF9CA3AF),
              ),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _audioChimeEnabled = !_audioChimeEnabled);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_audioChimeEnabled ? 'audio_chime_enabled'.tr() : 'audio_chime_muted'.tr()),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: KeyedSubtree(
          key: widget.requestsHubKey,
          child: Column(
            children: [
              // ── Top Radar Scope & Radius Control HUD
              _buildRadarHUD(),
              const SizedBox(height: 8),

              // ── Trade Skill Filters Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: filterOptions.map((filter) {
                    final isSelected = _selectedFilter.toLowerCase() == filter.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedFilter = filter);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF141416) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF141416) : const Color(0xFFF0EDE6),
                              width: 1.2,
                            ),
                            boxShadow: isSelected
                                ? const [
                                    BoxShadow(
                                      color: Color(0x1A000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            filter == "All" ? 'all_channels'.tr() : filter.toLocalizedTrade(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),

              // ── Broadcasts Stream List
              Expanded(
                child: StreamBuilder<List<Booking>>(
                  stream: bookingService.streamWorkerIncomingRequests(
                    workerId: widget.worker.id,
                    skills: widget.worker.skills,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: 2,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, __) => const KaryaShimmer(height: 160, borderRadius: 24),
                      );
                    }

                    var requests = snapshot.data ?? [];

                    // Apply active trade filter
                    if (_selectedFilter != "All") {
                      requests = requests.where((b) => b.serviceType.toLowerCase() == _selectedFilter.toLowerCase()).toList();
                    }

                    // Play alert sound for new incoming broadcast if enabled
                    if (requests.isNotEmpty && _audioChimeEnabled) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        for (final req in requests) {
                          BroadcastAlertService.instance.playBroadcastAlert(req);
                        }
                      });
                    }

                    if (requests.isEmpty) {
                      return _buildEmptyRadarState(context);
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        return KSlideFadeIn(
                          delay: Duration(milliseconds: index * 40),
                          child: _LuminaRequestCard(
                            booking: requests[index],
                            worker: widget.worker,
                            service: bookingService,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  RADAR SCOPE & COVERAGE CONTROLLER HUD
  // ──────────────────────────────────────────────────────────────
  Widget _buildRadarHUD() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD6EBFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.radar_rounded, color: Color(0xFF1E3A8A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'broadcast_listener'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF141416),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'listening_skills_gps'.tr(args: ['${widget.worker.skills.length}']),
                        style: const TextStyle(
                          color: Color(0xFF6B6B6B),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    KPulsingDot(color: Color(0xFF10B981), size: 6),
                    SizedBox(width: 5),
                    Text(
                      "LIVE 0ms",
                      style: TextStyle(color: Color(0xFF065F46), fontSize: 9.5, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF0EDE6), height: 1),
          const SizedBox(height: 10),

          // Radius Selector Pills
          Row(
            children: [
              Text(
                'radius_label'.tr(),
                style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [5, 10, 15, 25].map((rad) {
                    final isSel = _selectedRadiusKm == rad;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedRadiusKm = rad);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF141416) : const Color(0xFFF9F6EE),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? const Color(0xFF141416) : const Color(0xFFE5E0D8)),
                        ),
                        child: Text(
                          "${rad}km",
                          style: TextStyle(
                            color: isSel ? Colors.white : const Color(0xFF4B5563),
                            fontSize: 10.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  EMPTY RADAR STATE (Hotspots + Pro Tips)
  // ──────────────────────────────────────────────────────────────
  Widget _buildEmptyRadarState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD6EBFF),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD6EBFF).withValues(alpha: 0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.radar_rounded, color: Color(0xFF1E3A8A), size: 30),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'radar_active_listening'.tr(),
                  style: WorkGoFonts.display(
                    color: KX.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'radar_active_desc'.tr(args: ['$_selectedRadiusKm']),
                  style: WorkGoFonts.body(
                    color: const Color(0xFF6B6B6B),
                    fontSize: 11.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Live Demand Hotspots Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFD97706), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'high_demand_hotspots'.tr(),
                      style: TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'hotspot_desc'.tr(),
                  style: TextStyle(color: Color(0xFF78350F), fontSize: 11.5, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pro Tip Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE8FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD4C7FF), width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF5B21B6), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'radar_online_tip'.tr(),
                    style: const TextStyle(color: Color(0xFF3B1E78), fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  LUMINA REQUEST CARD (High Utility & Actionable)
// ──────────────────────────────────────────────────────────────
class _LuminaRequestCard extends StatelessWidget {
  const _LuminaRequestCard({
    required this.booking,
    required this.worker,
    required this.service,
  });

  final Booking booking;
  final Worker worker;
  final BookingService service;

  void _showReferPeerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFF0EDE6), width: 1.2),
        ),
        title: Text(
          'refer_job_peer'.tr(),
          style: WorkGoFonts.heading(
            color: KX.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'transfer_job_desc'.tr(args: [booking.serviceType.toLocalizedTrade()]),
              style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: KX.textPrimary),
              decoration: InputDecoration(
                labelText: 'peer_name_contact_hint'.tr(),
                labelStyle: const TextStyle(color: KX.textSecondary),
                filled: true,
                fillColor: const Color(0xFFF9F6EE),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF0EDE6))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('cancel'.tr(), style: const TextStyle(color: Color(0xFF6B6B6B))),
          ),
          ElevatedButton(
            onPressed: () async {
              await service.referBookingToPeer(
                bookingId: booking.id,
                originalWorkerId: worker.id,
                targetWorkerId: "peer_${nameCtrl.text.trim()}",
              );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('job_referred_success'.tr()),
                    backgroundColor: KX.emerald,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF141416),
              foregroundColor: Colors.white,
            ),
            child: Text('transfer_job_btn'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmergency = booking.isEmergency;
    final hasUrgencyBonus = booking.urgencyBonus > 0;
    final totalPayout = booking.totalAmount;
    final netPayout = totalPayout * 0.98;

    final shortId = booking.id.length > 6
        ? booking.id.substring(0, 6).toUpperCase()
        : booking.id.toUpperCase();

    final address = booking.customerAddressText != null && booking.customerAddressText!.isNotEmpty
        ? booking.customerAddressText!
        : "Customer Premises · In Zone";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isEmergency ? const Color(0xFFFECDD3) : const Color(0xFFF0EDE6),
          width: isEmergency ? 1.5 : 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row (Badges & Price)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isEmergency ? const Color(0xFFFFF1F2) : const Color(0xFFEDE8FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isEmergency ? const Color(0xFFFECDD3) : const Color(0xFFD4C7FF),
                      ),
                    ),
                    child: Text(
                      isEmergency ? 'emergency_dispatch_caps'.tr() : 'priority_dispatch_caps'.tr(),
                      style: TextStyle(
                        color: isEmergency ? const Color(0xFFE11D48) : const Color(0xFF5B21B6),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "#$shortId",
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "₹${totalPayout.toStringAsFixed(0)}",
                    style: WorkGoFonts.numeric(
                      color: const Color(0xFF141416),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'net_amount'.tr(args: [netPayout.toStringAsFixed(0)]),
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            booking.serviceType.toLocalizedTrade(),
            style: WorkGoFonts.display(
              color: KX.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),

          // Location & Distance ETA
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFF6B6B6B), size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: TranslatedText(
                  address,
                  isAddress: true,
                  style: WorkGoFonts.body(
                    color: const Color(0xFF6B6B6B),
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasUrgencyBonus) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'urgency_bonus_tag'.tr(args: [booking.urgencyBonus.toInt().toString()]),
                    style: const TextStyle(color: Color(0xFF92400E), fontSize: 9.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ],
          ),
          // Customer Reported Issue & AI Equipment Advice Card (if diagnostic context present)
          if ((booking.equipmentTag?.isNotEmpty == true) ||
              (booking.symptomDescription?.isNotEmpty == true) ||
              (booking.customerIssueDetails?.isNotEmpty == true) ||
              booking.suggestedToolsNeeded.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Equipment Tag Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.precision_manufacturing_rounded,
                          color: Color(0xFFB45309),
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TranslatedText(
                          booking.equipmentTag?.isNotEmpty == true
                              ? 'target_equipment'.tr(args: [booking.equipmentTag!])
                              : 'diagnostic_dispatch'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF78350F),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (booking.isDiagnosticVisit)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            'diagnostic_caps'.tr(),
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Customer issue & observations description
                  if (booking.customerIssueDetails?.isNotEmpty == true ||
                      booking.symptomDescription?.isNotEmpty == true) ...[
                    Text(
                      booking.customerIssueDetails?.isNotEmpty == true
                          ? booking.customerIssueDetails!
                          : booking.symptomDescription!,
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],

                  // AI Gear Advice: Recommended tools to pack
                  if (booking.suggestedToolsNeeded.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.handyman_rounded, size: 12, color: Color(0xFFB45309)),
                        const SizedBox(width: 4),
                        Text(
                          'ai_gear_advice_tools'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: booking.suggestedToolsNeeded.map((tool) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.build_rounded, size: 10, color: Color(0xFFB45309)),
                              const SizedBox(width: 4),
                              TranslatedText(
                                tool,
                                style: const TextStyle(
                                  color: Color(0xFF78350F),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Action Buttons: Refer vs Instant Accept
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _showReferPeerDialog(context),
                icon: const Icon(Icons.people_outline_rounded, size: 15, color: Color(0xFF6B6B6B)),
                label: Text('refer_btn'.tr(), style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFF0EDE6), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await service.acceptBooking(
                      booking.id,
                      worker.id,
                      workerName: worker.name,
                      workerPhone: worker.phoneForCalling,
                    );
                    // Voice guidance announcement
                    KaryaTtsService.instance.announceJobAccepted(booking);
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (ctx) => ActiveJobScreen(
                            booking: booking,
                            worker: worker,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFFFFB800)),
                  label: Text(
                    'accept_job_amount'.tr(args: [totalPayout.toInt().toString()]),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141416),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


