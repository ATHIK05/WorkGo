import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
import '../services/ml_translation_service.dart';
import 'booking_creation_screen.dart';
import 'live_booking_tracker_screen.dart';

class RapidoLiveBroadcastScreen extends StatefulWidget {
  const RapidoLiveBroadcastScreen({
    super.key,
    required this.bookingId,
    required this.serviceCategory,
    required this.initialAmount,
    this.pickupAddress = "1148 E Main St, Thanjavur",
    this.customerId,
  });

  final String bookingId;
  final String serviceCategory;
  final double initialAmount;
  final String pickupAddress;
  final String? customerId;

  @override
  State<RapidoLiveBroadcastScreen> createState() =>
      _RapidoLiveBroadcastScreenState();
}

class _RapidoLiveBroadcastScreenState extends State<RapidoLiveBroadcastScreen>
    with TickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  bool _hasNavigated = false;
  double? _myLat;
  double? _myLng;
  double _selectedBroadcastRadius = 10.0;
  String? _realtimeAddress;
  bool _isResolvingAddress = false;
  bool _showArtisanList = true;
  Set<String> _previouslyBookedWorkerIds = {};
  String? _loadedCustomerHistoryId;

  void _loadCustomerPastBookings(String customerId) async {
    if (_loadedCustomerHistoryId == customerId || customerId.isEmpty) return;
    _loadedCustomerHistoryId = customerId;
    try {
      final snap = await FirebaseFirestore.instance
          .collection("bookings")
          .where("customerId", isEqualTo: customerId)
          .get();
      final ids = snap.docs
          .map((d) => d.data()["workerId"]?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      if (mounted) {
        setState(() {
          _previouslyBookedWorkerIds = ids;
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _initDeviceLocation();
  }

  void _initDeviceLocation() async {
    try {
      final coords = await LocationService.instance.getCurrentCoordinates();
      if (mounted) {
        final lat = coords["latitude"];
        final lng = coords["longitude"];
        setState(() {
          _myLat = lat;
          _myLng = lng;
        });
        if (lat != null && lng != null && lat > 1.0 && lng > 1.0) {
          _resolveRealtimeAddress(lat, lng);
        }
      }
    } catch (_) {}
  }

  void _resolveRealtimeAddress(double lat, double lng) async {
    if (_isResolvingAddress || _realtimeAddress != null) return;
    _isResolvingAddress = true;
    try {
      final decoded = await LocationService.instance.reverseGeocode(lat, lng);
      if (mounted) {
        final text = decoded.streetArea.isNotEmpty
            ? '${decoded.streetArea}, ${decoded.city}'
            : decoded.formattedAddress;
        if (text.isNotEmpty && !text.toLowerCase().contains('mumbai')) {
          setState(() {
            _realtimeAddress = text;
          });
        }
      }
    } catch (_) {
    } finally {
      _isResolvingAddress = false;
    }
  }

  void _raiseFare(double extraBonus) async {
    HapticFeedback.heavyImpact();
    await _bookingService.raiseUrgencyBonus(widget.bookingId, extraBonus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: CX.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'fare_boosted_toast'.tr(args: [extraBonus.toInt().toString()]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1035),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  void _onArtisanAccepted(Booking booking) {
    if (_hasNavigated) return;
    _hasNavigated = true;

    // Play alert sound & haptics
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ArtisanAcceptedCelebration(
        booking: booking,
        onContinue: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (c) => LiveBookingTrackerScreen(
                bookingId: booking.id,
                initialBooking: booking,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Booking?>(
      stream: _bookingService.streamBooking(widget.bookingId),
      builder: (context, snapshot) {
        final booking = snapshot.data;

        final effectiveCustId = widget.customerId ?? booking?.customerId;
        if (effectiveCustId != null && effectiveCustId.isNotEmpty) {
          _loadCustomerPastBookings(effectiveCustId);
        }

        // Trigger acceptance transition as soon as status changes to accepted
        if (booking != null &&
            booking.status == BookingStatus.accepted &&
            !_hasNavigated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onArtisanAccepted(booking);
          });
        }

        if (booking != null && booking.broadcastRadiusKm > _selectedBroadcastRadius) {
          _selectedBroadcastRadius = booking.broadcastRadiusKm;
        }

        final custLat = booking?.customerLatitude;
        final custLng = booking?.customerLongitude;
        final effectivePickupLat = (_myLat != null && _myLat! > 1.0)
            ? _myLat
            : ((custLat != null && custLat > 1.0) ? custLat : null);
        final effectivePickupLng = (_myLng != null && _myLng! > 1.0)
            ? _myLng
            : ((custLng != null && custLng > 1.0) ? custLng : null);

        if (_realtimeAddress == null &&
            !_isResolvingAddress &&
            effectivePickupLat != null &&
            effectivePickupLng != null &&
            effectivePickupLat > 1.0 &&
            effectivePickupLng > 1.0) {
          _resolveRealtimeAddress(effectivePickupLat, effectivePickupLng);
        }

        final currentTotal = booking?.totalAmount ?? widget.initialAmount;
        final currentBonus = booking?.urgencyBonus ?? 0.0;
        String address = _realtimeAddress ??
            booking?.customerAddressText ??
            widget.pickupAddress;
        if (address.toLowerCase().contains("mumbai") ||
            address.toLowerCase().contains("bombay") ||
            address.trim().isEmpty) {
          address = 'current_live_location'.tr();
        } else {
          address = MlTranslationService.instance.translateAddressSync(
            address,
            context.locale.languageCode,
          );
        }

        return AuroraScaffold(
          appBar: AuroraAppBar(
            title: 'finding_nearby_artisan'.tr(args: [
              widget.serviceCategory.toLocalizedTrade(),
            ]),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Real OSM map with nearby online worker markers and live My Location point
                  StreamBuilder<List<Worker>>(
                    stream: _bookingService.streamNearbyOnlineWorkers(
                      widget.serviceCategory,
                      customerLat: effectivePickupLat,
                      customerLng: effectivePickupLng,
                      customerSearchRadiusKm: _selectedBroadcastRadius,
                    ),
                    builder: (context, workersSnap) {
                      final onlineWorkers = workersSnap.data ?? [];
                      final coords = onlineWorkers
                          .where((w) => w.latitude != null && w.longitude != null)
                          .map((w) => LatLng(w.latitude!, w.longitude!))
                          .toList();

                      return Column(
                        children: [
                          LiveMapView(
                            serviceCategory: widget.serviceCategory,
                            mode: MapMode.broadcastScanning,
                            pickupAddress: address,
                            height: 360,
                            // Real pickup coords (customer location saved at booking creation or current GPS)
                            pickupLatitude: effectivePickupLat,
                            pickupLongitude: effectivePickupLng,
                            // Customer's live device location (Rapido pulsing blue dot)
                            myLocationLatitude: _myLat,
                            myLocationLongitude: _myLng,
                            nearbyWorkers: onlineWorkers,
                            nearbyWorkerLocations: coords,
                            broadcastRadiusKm: _selectedBroadcastRadius,
                            onRadiusChanged: (newRad) async {
                              HapticFeedback.lightImpact();
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _selectedBroadcastRadius = newRad);
                              await _bookingService.expandBroadcastRadius(
                                widget.bookingId,
                                newRad,
                              );
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('searching_within_radius'
                                        .tr(args: [newRad.toInt().toString()])),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          // Broadcasting Status Text
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: CX.emerald,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      onlineWorkers.isNotEmpty
                                          ? 'active_artisans_online_nearby'.tr(args: [
                                              onlineWorkers.length.toString(),
                                              widget.serviceCategory.toLocalizedTrade(),
                                            ])
                                          : 'broadcasting_live_nearest'.tr(),
                                      style: WorkGoFonts.heading(
                                        color: CX.emerald,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'scanning_radius_for_artisans'.tr(args: [
                                  address.split(',').first.trim(),
                                  widget.serviceCategory.toLocalizedTrade(),
                                ]),
                                style: WorkGoFonts.body(
                                  color: CX.textSecondary,
                                  fontSize: 12.5,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: const SizedBox(
                                  width: 140,
                                  height: 3,
                                  child: LinearProgressIndicator(
                                    backgroundColor: Color(0x1FFFFFFF),
                                    valueColor: AlwaysStoppedAnimation<Color>(CX.emerald),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildExpandRadarSection(
                                _selectedBroadcastRadius,
                                hasWorkers: onlineWorkers.isNotEmpty,
                              ),
                              const SizedBox(height: 16),
                              _buildArtisanListToggle(),
                              if (_showArtisanList) ...[
                                const SizedBox(height: 16),
                                _buildNearbyArtisansSection(
                                  onlineWorkers,
                                  effectivePickupLat,
                                  effectivePickupLng,
                                  booking,
                                ),
                              ],
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // Current Fare & Urgency Tip Card
                  _buildFareSummaryCard(currentTotal, currentBonus),
                  const SizedBox(height: 16),

                  // Rapido-Style "Raise Fare" Incentive Buttons
                  _buildRaiseFareSection(),
                  const SizedBox(height: 20),

                  // Cancel Dispatch Button
                  TextButton.icon(
                    onPressed: () async {
                      await _bookingService.updateBookingStatus(
                        widget.bookingId,
                        BookingStatus.cancelled,
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded, color: CX.rose, size: 18),
                    label: Text(
                      'cancel_broadcast'.tr(),
                      style: WorkGoFonts.heading(
                        color: CX.rose,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFareSummaryCard(double currentTotal, double currentBonus) {
    return AuroraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'artisan_service_fare'.tr(),
                    style: WorkGoFonts.body(
                      color: CX.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "₹${currentTotal.toStringAsFixed(0)}",
                        style: WorkGoFonts.numeric(
                          color: CX.amber,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (currentBonus > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: CX.emerald.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'tip_included_badge'.tr(args: [currentBonus.toInt().toString()]),
                            style: WorkGoFonts.badge(
                              color: CX.emerald,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: CX.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CX.emerald.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded, color: CX.emerald, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      'zero_commission_badge'.tr(),
                      style: WorkGoFonts.badge(
                        color: CX.emerald,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: CX.canvasMid,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: CX.cyan, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'direct_to_artisan_transit'.tr(),
                    style: WorkGoFonts.body(
                      color: CX.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRaiseFareSection() {
    return AuroraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: CX.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'boost_fare_title'.tr(),
                  style: WorkGoFonts.heading(
                    color: CX.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'boost_fare_desc'.tr(),
            style: WorkGoFonts.body(color: CX.textSecondary, fontSize: 11.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildFareBoostButton("+₹30", 30.0),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFareBoostButton("+₹50", 50.0),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFareBoostButton("+₹100", 100.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareBoostButton(String label, double amount) {
    return OutlinedButton(
      onPressed: () => _raiseFare(amount),
      style: OutlinedButton.styleFrom(
        foregroundColor: CX.amber,
        side: const BorderSide(color: CX.amber, width: 1.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        backgroundColor: CX.amber.withValues(alpha: 0.08),
      ),
      child: Text(
        label,
        style: WorkGoFonts.heading(
          color: CX.amber,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  EXPAND RADAR RADIUS ENLARGEMENT SECTION
  // ──────────────────────────────────────────────────────────────
  Widget _buildExpandRadarSection(double currentRadius, {bool hasWorkers = false}) {
    final expandOptions = [15.0, 20.0, 25.0, 35.0]
        .where((r) => r > currentRadius)
        .toList();

    if (expandOptions.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasWorkers
            ? const Color(0xFF150B28)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasWorkers
              ? const Color(0x408B5CF6)
              : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.radar_rounded,
                size: 16,
                color: hasWorkers
                    ? const Color(0xFFA78BFA)
                    : const Color(0xFFD97706),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  hasWorkers
                      ? '${'active_radius_coverage'.tr(args: [currentRadius.toInt().toString()])} · ${'expand_search_radius'.tr()}'
                      : 'expand_radius_prompt'.tr(args: [currentRadius.toInt().toString()]),
                  style: TextStyle(
                    color: hasWorkers
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF92400E),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: expandOptions.map((targetRad) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedBroadcastRadius = targetRad);
                      await _bookingService.expandBroadcastRadius(
                        widget.bookingId,
                        targetRad,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('searching_within_radius'
                                .tr(args: [targetRad.toInt().toString()])),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasWorkers
                            ? const Color(0xFF281545)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasWorkers
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFFF59E0B),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.zoom_out_map_rounded,
                            size: 12,
                            color: hasWorkers
                                ? const Color(0xFFA78BFA)
                                : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'expand_radar_to'
                                .tr(args: [targetRad.toInt().toString()]),
                            style: TextStyle(
                              color: hasWorkers
                                  ? Colors.white
                                  : const Color(0xFFB45309),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  ARTISAN SELECTION TOGGLE & LIST (UBER-STYLE)
  // ──────────────────────────────────────────────────────────────
  Widget _buildArtisanListToggle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF150B28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _showArtisanList
              ? CX.indigo.withValues(alpha: 0.5)
              : const Color(0x25FFFFFF),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _showArtisanList
                  ? CX.indigo.withValues(alpha: 0.2)
                  : const Color(0x15FFFFFF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_alt_rounded,
              size: 18,
              color: _showArtisanList ? CX.indigo : CX.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'broadcast_toggle_title'.tr(),
                  style: WorkGoFonts.heading(
                    color: CX.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'broadcast_toggle_desc'.tr(),
                  style: WorkGoFonts.body(
                    color: CX.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _showArtisanList,
            activeThumbColor: CX.indigo,
            activeTrackColor: CX.indigo.withValues(alpha: 0.4),
            onChanged: (val) {
              HapticFeedback.lightImpact();
              setState(() => _showArtisanList = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyArtisansSection(
    List<Worker> onlineWorkers,
    double? pickupLat,
    double? pickupLng,
    Booking? booking,
  ) {
    final verifiedOnlineWorkers = onlineWorkers.where((w) {
      final isKycApproved = w.verificationStatus == VerificationStatus.approved;
      final isOnline = w.availabilityStatus == AvailabilityStatus.online || w.isCheckedIn;
      return isKycApproved && isOnline;
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF130924),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x358B5CF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle indicator (Uber-style)
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'choose_artisan_heading'.tr(),
                  style: WorkGoFonts.heading(
                    color: CX.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CX.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CX.emerald.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: CX.emerald,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "${verifiedOnlineWorkers.length} online",
                      style: WorkGoFonts.badge(
                        color: CX.emerald,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (verifiedOnlineWorkers.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1035),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: CX.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'no_nearby_artisans_found'.tr(),
                      style: WorkGoFonts.body(
                        color: CX.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: verifiedOnlineWorkers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final w = verifiedOnlineWorkers[index];
                double dist = 1.0;
                if (pickupLat != null && pickupLng != null && w.latitude != null && w.longitude != null) {
                  dist = w.calculateDistanceKm(pickupLat, pickupLng);
                }
                final distStr = dist.toStringAsFixed(1);
                final bool isRecentlyBooked = _previouslyBookedWorkerIds.contains(w.id);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openArtisanDetailSheet(w, pickupLat, pickupLng, booking),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1038),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isRecentlyBooked
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.6)
                              : const Color(0x25FFFFFF),
                        ),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              WorkGoAvatar(
                                avatarBase64: w.verificationDetails?.selfieBase64 ??
                                    w.verificationDetails?.aadhaarPhotoBase64,
                                name: w.name,
                                radius: 24,
                              ),
                              Positioned(
                                bottom: -1,
                                right: -1,
                                child: Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: CX.emerald,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF1E1038),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2563EB),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified_rounded,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        w.name,
                                        style: WorkGoFonts.heading(
                                          color: CX.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isRecentlyBooked) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E3A8A),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFF3B82F6),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.history_rounded,
                                              size: 10,
                                              color: Color(0xFF93C5FD),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'artisan_booked_recently'.tr(),
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                color: Color(0xFFBFDBFE),
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 13,
                                      color: CX.amber,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      w.avgRating > 0
                                          ? w.avgRating.toStringAsFixed(1)
                                          : "5.0",
                                      style: WorkGoFonts.numeric(
                                        color: CX.textPrimary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      " · ",
                                      style: TextStyle(
                                        color: CX.textMuted.withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.near_me_outlined,
                                      size: 12,
                                      color: CX.cyan,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        'artisan_distance_km'.tr(args: [distStr]),
                                        style: WorkGoFonts.body(
                                          color: CX.textSecondary,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      " · ",
                                      style: TextStyle(
                                        color: CX.textMuted.withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.work_outline_rounded,
                                      size: 12,
                                      color: CX.emerald,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        'artisan_experience_years'.tr(args: [w.experienceYears.toString()]),
                                        style: WorkGoFonts.body(
                                          color: CX.textSecondary,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "₹${w.baseRate > 0 ? w.baseRate.toInt() : 199}",
                                style: WorkGoFonts.numeric(
                                  color: CX.amber,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: CX.textMuted,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  ARTISAN PROFILE DETAIL SHEET (IMAGE 3 STYLE)
  // ──────────────────────────────────────────────────────────────
  void _openArtisanDetailSheet(
    Worker worker,
    double? pickupLat,
    double? pickupLng,
    Booking? booking,
  ) {
    HapticFeedback.lightImpact();
    double dist = 1.0;
    if (pickupLat != null && pickupLng != null && worker.latitude != null && worker.longitude != null) {
      dist = worker.calculateDistanceKm(pickupLat, pickupLng);
    }
    final etaMin = max(2, (dist * 2.5).toInt());
    final address = _realtimeAddress ?? booking?.customerAddressText ?? widget.pickupAddress;
    final isRecentlyBooked = _previouslyBookedWorkerIds.contains(worker.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(sheetCtx).padding.bottom + 20),
          decoration: const BoxDecoration(
            color: Color(0xFF140A28),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: Color(0x408B5CF6))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pickup location & ETA bar (Image 3 style)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1038),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x25FFFFFF)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.near_me_rounded, color: CX.cyan, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'artisan_meet_pickup'.tr(),
                        style: WorkGoFonts.heading(
                          color: CX.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CX.emerald.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        "$etaMin min",
                        style: WorkGoFonts.heading(
                          color: CX.emerald,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Artisan Main Card (Image 3 style)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1038),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isRecentlyBooked
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.7)
                        : const Color(0x35FFFFFF),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            WorkGoAvatar(
                              avatarBase64: worker.verificationDetails?.selfieBase64 ??
                                  worker.verificationDetails?.aadhaarPhotoBase64,
                              name: worker.name,
                              radius: 34,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: CX.emerald,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF1E1038),
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      worker.name,
                                      style: WorkGoFonts.heading(
                                        color: CX.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isRecentlyBooked) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E3A8A),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF3B82F6),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        'artisan_booked_recently'.tr(),
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          color: Color(0xFFBFDBFE),
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${widget.serviceCategory.toLocalizedTrade()} · ${worker.verificationBadge.isNotEmpty ? worker.verificationBadge : 'artisan_safety_badge'.tr()}",
                                style: WorkGoFonts.body(
                                  color: CX.cyan,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 15,
                                    color: CX.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    worker.avgRating > 0
                                        ? worker.avgRating.toStringAsFixed(1)
                                        : "5.0",
                                    style: WorkGoFonts.numeric(
                                      color: CX.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "(${worker.totalRatings > 0 ? worker.totalRatings : 12} reviews)",
                                    style: WorkGoFonts.body(
                                      color: CX.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Metrics Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF130924),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildDetailStatPill(
                            Icons.work_outline_rounded,
                            "${worker.experienceYears} yrs",
                            "Experience",
                            CX.emerald,
                          ),
                          Container(width: 1, height: 26, color: Colors.white12),
                          _buildDetailStatPill(
                            Icons.near_me_outlined,
                            "${dist.toStringAsFixed(1)} km",
                            "Distance",
                            CX.cyan,
                          ),
                          Container(width: 1, height: 26, color: Colors.white12),
                          _buildDetailStatPill(
                            Icons.verified_user_outlined,
                            "${worker.trustScore}/5",
                            "Trust Score",
                            CX.amber,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons Row (Image 3 style: Safety, Share, Call)
              Row(
                children: [
                  Expanded(
                    child: _buildDetailActionButton(
                      Icons.shield_outlined,
                      'artisan_safety_badge'.tr(),
                      CX.cyan,
                      () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              "100% Aadhaar KYC & Police Clearance Verified Artisan",
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF1E1035),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailActionButton(
                      Icons.share_location_rounded,
                      'artisan_share_details'.tr(),
                      CX.emerald,
                      () {
                        HapticFeedback.lightImpact();
                        Clipboard.setData(ClipboardData(
                          text: "WorkGo Live Dispatch: ${worker.name} (${widget.serviceCategory})",
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("Artisan details copied to clipboard"),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF1E1035),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailActionButton(
                      Icons.phone_rounded,
                      'artisan_call_action'.tr(),
                      CX.amber,
                      () {
                        HapticFeedback.lightImpact();
                        final phone = worker.phoneForCalling;
                        if (phone != null && phone.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Direct artisan contact: $phone"),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF1E1035),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Audio calling enabled upon booking confirmation"),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF1E1035),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Address Row (Image 3 style)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1038),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x20FFFFFF)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_rounded, color: CX.rose, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        address,
                        style: WorkGoFonts.body(
                          color: CX.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Main Book Button (Redirects to Personalized BookingCreationScreen)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.heavyImpact();
                    Navigator.of(sheetCtx).pop();

                    // Cancel current broadcast dispatch to prevent orphaned pending jobs
                    try {
                      await _bookingService.updateBookingStatus(
                        widget.bookingId,
                        BookingStatus.cancelled,
                      );
                    } catch (_) {}

                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (ctx) => BookingCreationScreen(
                            customerId: booking?.customerId ?? widget.customerId ?? "",
                            serviceCategory: widget.serviceCategory,
                            worker: worker,
                            customerLat: pickupLat,
                            customerLng: pickupLng,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                  label: Text(
                    'artisan_direct_book_action'.tr(),
                    style: WorkGoFonts.heading(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CX.emerald,
                    elevation: 4,
                    shadowColor: CX.emerald.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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

  Widget _buildDetailStatPill(IconData icon, String val, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              val,
              style: WorkGoFonts.numeric(
                color: CX.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: WorkGoFonts.body(
            color: CX.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1038),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: WorkGoFonts.body(
                color: CX.textPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
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

// ──────────────────────────────────────────────────────────────
//  ARTISAN ACCEPTED CELEBRATION MODAL
// ──────────────────────────────────────────────────────────────
class _ArtisanAcceptedCelebration extends StatelessWidget {
  const _ArtisanAcceptedCelebration({
    required this.booking,
    required this.onContinue,
  });

  final Booking booking;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final isDialWorker = booking.isAssignedToDialWorker ||
        (booking.dialWorkerPhone != null && booking.dialWorkerPhone!.isNotEmpty);
    final rawArtisanName = booking.acceptedWorkerName ?? 'verified_pro'.tr();
    final artisanName = MlTranslationService.instance.translateSync(
      rawArtisanName,
      context.locale.languageCode,
    );

    final borderColor = isDialWorker ? const Color(0xFFF59E0B) : CX.emerald;
    final glowColor = isDialWorker ? const Color(0xFFF59E0B) : CX.emerald;
    final iconGradient = isDialWorker ? CX.auroraVioletAmber : CX.auroraSuccess;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CX.canvasCard,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.4),
            blurRadius: 36,
            spreadRadius: -4,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: iconGradient,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isDialWorker ? Icons.phone_in_talk_rounded : Icons.check_circle_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (isDialWorker) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                AuroraBadge(
                  label: 'dial_karya_badge'.trSafe('Dial Karya Artisan'),
                  style: AuroraBadgeStyle.amber,
                ),
                AuroraBadge(
                  label: 'dial_karya_subtitle'.trSafe('Voice IVR • Peer Verified'),
                  style: AuroraBadgeStyle.violet,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Text(
            isDialWorker
                ? 'dial_artisan_assigned_title'.trSafe('Dial Karya Artisan Assigned!')
                : 'artisan_assigned_title'.tr(),
            style: WorkGoFonts.display(
              color: CX.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            isDialWorker
                ? '$artisanName accepted your booking via Dial Karya Voice Telephony (Feature Phone). Direct call link is ready.'
                : 'artisan_accepted_en_route'.tr(args: [artisanName]),
            style: WorkGoFonts.body(
              color: CX.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 22),
          GlowButton(
            label: 'track_artisan_and_otp'.tr(),
            icon: Icons.navigation_rounded,
            onPressed: onContinue,
            gradient: iconGradient,
            glowColor: glowColor,
            height: 52,
          ),
        ],
      ),
    );
  }
}
