import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
import 'rapido_live_broadcast_screen.dart';

class BookingCreationScreen extends StatefulWidget {
  const BookingCreationScreen({
    super.key,
    required this.serviceCategory,
    this.worker,
    this.targetWorkerId,
    required this.customerId,
    this.isEmergencyInitial = false,
  });

  final String serviceCategory;
  final Worker? worker;
  final String? targetWorkerId;
  final String customerId;
  final bool isEmergencyInitial;

  @override
  State<BookingCreationScreen> createState() => _BookingCreationScreenState();
}

class _BookingCreationScreenState extends State<BookingCreationScreen>
    with TickerProviderStateMixin {
  late bool _isEmergency;
  double _urgencyTip = 0.0;
  int _selectedDayIndex = 0;
  String _selectedSlot = "slot_morning";
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  UserAddress? _selectedAddress;
  bool _isSubmitting = false;

  late AnimationController _emergencyCtrl;

  @override
  void initState() {
    super.initState();
    _isEmergency = widget.isEmergencyInitial;
    if (_isEmergency) _urgencyTip = 100.0;
    _emergencyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (_isEmergency) _emergencyCtrl.forward();
    _loadUserDefaultAddress();
  }

  Future<void> _loadUserDefaultAddress() async {
    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(widget.customerId).get();
      final data = doc.data() ?? {};
      final currentAddrMap = data["currentAddress"] as Map<String, dynamic>?;
      if (currentAddrMap != null && mounted) {
        final addr = UserAddress.fromMap(currentAddrMap);
        setState(() {
          _selectedAddress = addr;
          _addressController.text = addr.fullDisplayAddress;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  void _setEmergency(bool val) {
    setState(() {
      _isEmergency = val;
      if (val && _urgencyTip == 0.0) _urgencyTip = 100.0;
    });
    if (val) {
      _emergencyCtrl.forward();
    } else {
      _emergencyCtrl.reverse();
    }
  }

  Future<void> _submitBooking() async {
    setState(() => _isSubmitting = true);
    try {
      final worker = widget.worker;
      final fare = CooperativePricingEngine.instance.calculateFare(
        category: widget.serviceCategory,
        distanceKm: worker?.distanceKm ?? 2.4,
        experienceYears: worker?.experienceYears ?? 3,
        isEmergency: _isEmergency,
        urgencyTip: _urgencyTip,
        customBaseRate: worker?.baseRate,
        customPerKmRate: worker?.perKmRate,
      );

      final totalAmount = fare.totalEstimatedFare;

      final bookingService = BookingService();
      final assignedWorkerId =
          widget.targetWorkerId ?? widget.worker?.id;
      final addressText = _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : (_selectedAddress?.fullDisplayAddress ?? "1148 E Main St, Thanjavur");

      final bookingId = await bookingService.createBooking(
        customerId: widget.customerId,
        serviceType: widget.serviceCategory,
        workerId: assignedWorkerId,
        amount: totalAmount - _urgencyTip,
        urgencyBonus: _urgencyTip,
        isEmergency: _isEmergency,
        scheduledAt: DateTime.now().add(Duration(days: _selectedDayIndex)),
        customerAddressText: addressText,
        customerLatitude: _selectedAddress?.latitude ?? 10.7870,
        customerLongitude: _selectedAddress?.longitude ?? 79.1378,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => RapidoLiveBroadcastScreen(
              bookingId: bookingId,
              serviceCategory: widget.serviceCategory,
              initialAmount: totalAmount,
              pickupAddress: addressText,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Booking error: $e"),
            backgroundColor: CX.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = widget.worker;
    final fare = CooperativePricingEngine.instance.calculateFare(
      category: widget.serviceCategory,
      distanceKm: worker?.distanceKm ?? 2.4,
      experienceYears: worker?.experienceYears ?? 3,
      isEmergency: _isEmergency,
      urgencyTip: _urgencyTip,
      customBaseRate: worker?.baseRate,
      customPerKmRate: worker?.perKmRate,
    );

    final catStyle = categoryStyle(widget.serviceCategory);

    return AuroraScaffold(
      appBar: AuroraAppBar(title: 'confirm_booking'.tr()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Service Hero Card with Artisan Profile
              SlideFadeIn(
                child: _ServiceHeroCard(
                  categoryName: widget.serviceCategory,
                  style: catStyle,
                  worker: widget.worker,
                  hasWorker: widget.targetWorkerId != null ||
                      widget.worker != null,
                ),
              ),
              const SizedBox(height: 16),

              // Emergency Toggle
              SlideFadeIn(
                delay: const Duration(milliseconds: 60),
                child: _EmergencyToggleCard(
                  isEmergency: _isEmergency,
                  onChanged: _setEmergency,
                  controller: _emergencyCtrl,
                ),
              ),
              const SizedBox(height: 20),

              // Date Selection
              SlideFadeIn(
                delay: const Duration(milliseconds: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('select_date'.tr()),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _DayChip(
                            index: 0,
                            selected: _selectedDayIndex == 0,
                            label: "Today",
                            sub: "Immediate",
                            onTap: () =>
                                setState(() => _selectedDayIndex = 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DayChip(
                            index: 1,
                            selected: _selectedDayIndex == 1,
                            label: "Tomorrow",
                            sub: "Standard",
                            onTap: () =>
                                setState(() => _selectedDayIndex = 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DayChip(
                            index: 2,
                            selected: _selectedDayIndex == 2,
                            label: "Scheduled",
                            sub: "Flexible",
                            onTap: () =>
                                setState(() => _selectedDayIndex = 2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Time Slots
              SlideFadeIn(
                delay: const Duration(milliseconds: 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('select_slot'.tr()),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SlotChip(
                            slotKey: "slot_morning",
                            timeRange: "9 AM–12 PM",
                            icon: Icons.wb_sunny_rounded,
                            iconColor: CX.amber,
                            selected: _selectedSlot == "slot_morning",
                            onTap: () =>
                                setState(() => _selectedSlot = "slot_morning"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SlotChip(
                            slotKey: "slot_afternoon",
                            timeRange: "12–4 PM",
                            icon: Icons.wb_cloudy_rounded,
                            iconColor: CX.cyan,
                            selected: _selectedSlot == "slot_afternoon",
                            onTap: () => setState(
                                () => _selectedSlot = "slot_afternoon"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SlotChip(
                            slotKey: "slot_evening",
                            timeRange: "4–8 PM",
                            icon: Icons.nights_stay_rounded,
                            iconColor: CX.violetLight,
                            selected: _selectedSlot == "slot_evening",
                            onTap: () =>
                                setState(() => _selectedSlot = "slot_evening"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Address with 1-Tap Swiggy/Zomato Switcher
              SlideFadeIn(
                delay: const Duration(milliseconds: 180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionLabel('address'.tr()),
                        TextButton.icon(
                          onPressed: () async {
                            final chosen = await showAddressManagementSheet(
                              context,
                              userId: widget.customerId,
                              userRole: "customer",
                              selectedAddress: _selectedAddress,
                            );
                            if (chosen != null && mounted) {
                              setState(() {
                                _selectedAddress = chosen;
                                _addressController.text = chosen.fullDisplayAddress;
                              });
                            }
                          },
                          icon: const Icon(Icons.swap_horiz_rounded, color: CX.amber, size: 16),
                          label: Text(
                            _selectedAddress != null ? "Change (${_selectedAddress!.displayTitle})" : "Select Saved Address",
                            style: const TextStyle(color: CX.amber, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _AuroraTextField(
                      controller: _addressController,
                      prefixIcon: _selectedAddress?.label.icon ?? Icons.location_on_rounded,
                      prefixIconColor: CX.rose,
                      hintText: "Enter service address or select from saved",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Notes
              SlideFadeIn(
                delay: const Duration(milliseconds: 210),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('problem_notes'.tr()),
                    const SizedBox(height: 10),
                    _AuroraTextField(
                      controller: _notesController,
                      hintText: "E.g. Leaking kitchen sink pipe under the counter",
                      prefixIcon: Icons.notes_rounded,
                      prefixIconColor: CX.violetLight,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Rapido-Style Urgency Boost Bidding
              SlideFadeIn(
                delay: const Duration(milliseconds: 230),
                child: AuroraCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: CX.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "urgency_boost".tr(),
                            style: WorkGoFonts.heading(
                              color: CX.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Add a tip to incentivize nearby Captains to accept your request within minutes",
                        style: WorkGoFonts.body(color: CX.textSecondary, fontSize: 11.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildUrgencyChip("Standard", 0.0),
                          const SizedBox(width: 8),
                          _buildUrgencyChip("+₹50", 50.0),
                          const SizedBox(width: 8),
                          _buildUrgencyChip("+₹100", 100.0),
                          const SizedBox(width: 8),
                          _buildUrgencyChip("+₹200", 200.0),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Price Breakdown (Rapido-style Dynamic Breakdown)
              SlideFadeIn(
                delay: const Duration(milliseconds: 260),
                child: _PriceCard(
                  fare: fare,
                  isEmergency: _isEmergency,
                ),
              ),
              const SizedBox(height: 24),

              // Confirm CTA
              SlideFadeIn(
                delay: const Duration(milliseconds: 280),
                child: GlowButton(
                  label: 'confirm_booking'.tr(),
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _submitBooking,
                  gradient: _isEmergency
                      ? CX.auroraEmergency
                      : CX.auroraVioletCyan,
                  glowColor: _isEmergency ? CX.rose : CX.violet,
                  height: 54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrgencyChip(String label, double amount) {
    final isSelected = _urgencyTip == amount;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _urgencyTip = amount);
        },
        child: AnimatedContainer(
          duration: CAnim.fast,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? CX.amber.withValues(alpha: 0.25) : CX.canvasMid,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? CX.amber : CX.glassBorder,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: WorkGoFonts.heading(
                color: isSelected ? CX.amber : CX.textSecondary,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: CX.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  SERVICE HERO CARD
// ──────────────────────────────────────────────────────
class _ServiceHeroCard extends StatelessWidget {
  const _ServiceHeroCard({
    required this.categoryName,
    required this.style,
    required this.hasWorker,
    this.worker,
  });

  final String categoryName;
  final CategoryStyle style;
  final bool hasWorker;
  final Worker? worker;

  @override
  Widget build(BuildContext context) {
    final displayName = worker != null && worker!.name.isNotEmpty ? worker!.name : null;
    final totalReviews = worker != null && worker!.totalReviews > 0 ? worker!.totalReviews : (worker?.totalRatings ?? 0);
    final homesCount = worker != null && worker!.homesServiced > 0 ? worker!.homesServiced : ((worker?.totalRatings ?? 0) * 2 + 10);

    return AuroraCard(
      glowColor: style.glow,
      borderColor: style.glow.withValues(alpha: 0.35),
      gradient: LinearGradient(
        colors: [
          style.glow.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.04),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        children: [
          Row(
            children: [
              AuroraOrb(
                icon: style.icon,
                gradient: style.gradient,
                size: 56,
                iconSize: 28,
                glowColor: style.glow,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: const TextStyle(
                        color: CX.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName != null
                          ? "Assigned: $displayName"
                          : "Auto-Dispatching Nearest Verified Artisan",
                      style: const TextStyle(
                        color: CX.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AuroraBadge(
                      label: worker != null ? "CO-OP CERTIFIED ARTISAN" : "COOPERATIVE SERVICE",
                      style: worker != null ? AuroraBadgeStyle.emerald : AuroraBadgeStyle.violet,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (worker != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: CX.glassBorder, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: CX.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      worker!.avgRating > 0 ? worker!.avgRating.toStringAsFixed(1) : "4.9",
                      style: WorkGoFonts.numeric(
                        color: CX.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      "($totalReviews)",
                      style: WorkGoFonts.body(color: CX.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                Text(
                  "🏡 $homesCount homes",
                  style: WorkGoFonts.body(color: const Color(0xFF6EE7B7), fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  "📍 ${worker!.distanceKm.toStringAsFixed(1)} km",
                  style: WorkGoFonts.body(color: CX.cyan, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  EMERGENCY TOGGLE CARD — animated
// ──────────────────────────────────────────────────────
class _EmergencyToggleCard extends StatelessWidget {
  const _EmergencyToggleCard({
    required this.isEmergency,
    required this.onChanged,
    required this.controller,
  });

  final bool isEmergency;
  final ValueChanged<bool> onChanged;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        return AuroraCard(
          borderColor: Color.lerp(CX.glassBorder, CX.rose.withValues(alpha: 0.6), t),
          glowColor: isEmergency ? CX.rose : null,
          gradient: LinearGradient(
            colors: [
              Color.lerp(
                  Colors.white.withValues(alpha: 0.07),
                  CX.rose.withValues(alpha: 0.12),
                  t)!,
              Colors.white.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    Colors.white.withValues(alpha: 0.06),
                    CX.rose.withValues(alpha: 0.25),
                    t,
                  ),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: Color.lerp(CX.textMuted, CX.rose, t),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'emergency_booking'.tr(),
                      style: const TextStyle(
                        color: CX.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Guaranteed dispatch under 30 min (+₹150)",
                      style: const TextStyle(
                        color: CX.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Custom toggle switch
              GestureDetector(
                onTap: () => onChanged(!isEmergency),
                child: AnimatedContainer(
                  duration: CAnim.normal,
                  width: 50,
                  height: 28,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: isEmergency ? CX.auroraEmergency : null,
                    color: isEmergency
                        ? null
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isEmergency
                          ? CX.rose.withValues(alpha: 0.5)
                          : CX.glassBorder,
                    ),
                    boxShadow: isEmergency
                        ? [
                            BoxShadow(
                              color: CX.rose.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedAlign(
                    duration: CAnim.normal,
                    curve: Curves.easeOutCubic,
                    alignment: isEmergency
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
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

// ──────────────────────────────────────────────────────
//  DAY CHIP
// ──────────────────────────────────────────────────────
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.index,
    required this.selected,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CAnim.normal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? CX.auroraVioletCyan : null,
          color: selected ? null : CX.glassCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? CX.cyan.withValues(alpha: 0.5) : CX.glassBorder,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: CX.violet.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : CX.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.75)
                    : CX.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  SLOT CHIP
// ──────────────────────────────────────────────────────
class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slotKey,
    required this.timeRange,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String slotKey;
  final String timeRange;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CAnim.normal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? iconColor.withValues(alpha: 0.18)
              : CX.glassCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? iconColor.withValues(alpha: 0.6)
                : CX.glassBorder,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? iconColor : CX.textMuted, size: 18),
            const SizedBox(height: 4),
            Text(
              slotKey.tr(),
              style: TextStyle(
                color: selected ? CX.textPrimary : CX.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              timeRange,
              style: TextStyle(
                color: selected ? iconColor : CX.textMuted,
                fontSize: 9.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  AURORA TEXT FIELD
// ──────────────────────────────────────────────────────
class _AuroraTextField extends StatefulWidget {
  const _AuroraTextField({
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.prefixIconColor,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Color? prefixIconColor;
  final int maxLines;

  @override
  State<_AuroraTextField> createState() => _AuroraTextFieldState();
}

class _AuroraTextFieldState extends State<_AuroraTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: CAnim.normal,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused
              ? (widget.prefixIconColor ?? CX.violet).withValues(alpha: 0.6)
              : CX.glassBorder,
          width: 1.3,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: (widget.prefixIconColor ?? CX.violet).withValues(alpha: 0.15),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        maxLines: widget.maxLines,
        style: const TextStyle(color: CX.textPrimary, fontSize: 14),
        onTap: () => setState(() => _focused = true),
        onTapOutside: (_) => setState(() => _focused = false),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: CX.textMuted.withValues(alpha: 0.8), fontSize: 13),
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, color: widget.prefixIconColor ?? CX.violet, size: 20)
              : null,
          filled: true,
          fillColor: CX.glassCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  PRICE BREAKDOWN CARD — animated counter with Rapido-style Breakdown
// ──────────────────────────────────────────────────────
class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.fare,
    required this.isEmergency,
  });

  final FareBreakdown fare;
  final bool isEmergency;

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      glowColor: CX.amber,
      borderColor: CX.amber.withValues(alpha: 0.3),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              AuroraOrb(
                icon: Icons.receipt_long_rounded,
                gradient: CX.auroraVioletAmber,
                size: 36,
                iconSize: 18,
                glowColor: CX.amber,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'fare_breakdown'.tr(),
                      style: const TextStyle(
                        color: CX.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      "Transparent On-Demand Co-op Pricing",
                      style: TextStyle(color: CX.textSecondary.withValues(alpha: 0.8), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: CX.glassBorder, height: 1),
          const SizedBox(height: 12),

          // Base Visit Fare
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'base_visit_fare'.tr(),
                style: const TextStyle(color: CX.textSecondary, fontSize: 13),
              ),
              Text(
                fare.formattedBase,
                style: const TextStyle(
                  color: CX.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Transit Allowance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${'transit_distance_fare'.tr()} (${fare.formattedDistance})",
                style: const TextStyle(color: CX.textSecondary, fontSize: 13),
              ),
              Text(
                fare.formattedTransit,
                style: const TextStyle(
                  color: CX.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          if (fare.experienceBonus > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${'experience_bonus'.tr()} (${fare.experienceYears} yrs)",
                  style: const TextStyle(color: CX.amber, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  "+₹${fare.experienceBonus.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: CX.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],

          if (fare.urgencyTip > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Urgency Priority Tip",
                  style: TextStyle(color: CX.amber, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  "+₹${fare.urgencyTip.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: CX.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],

          AnimatedSize(
            duration: CAnim.slow,
            curve: Curves.easeOutCubic,
            child: isEmergency
                ? Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, color: CX.rose, size: 14),
                              const SizedBox(width: 4),
                              const Text(
                                "Emergency Rush (<30 min)",
                                style: TextStyle(color: CX.rose, fontSize: 13),
                              ),
                            ],
                          ),
                          const Text(
                            "₹150",
                            style: TextStyle(
                              color: CX.rose,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          Divider(color: CX.glassBorder, height: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'total_amount'.tr(),
                style: const TextStyle(
                  color: CX.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              AnimatedCounter(
                value: fare.totalEstimatedFare,
                style: const TextStyle(
                  color: CX.amber,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
