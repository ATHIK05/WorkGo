import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
import '../services/ml_translation_service.dart';
import 'live_booking_tracker_screen.dart';

class RapidoLiveBroadcastScreen extends StatefulWidget {
  const RapidoLiveBroadcastScreen({
    super.key,
    required this.bookingId,
    required this.serviceCategory,
    required this.initialAmount,
    this.pickupAddress = "1148 E Main St, Thanjavur",
  });

  final String bookingId;
  final String serviceCategory;
  final double initialAmount;
  final String pickupAddress;

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

  @override
  void initState() {
    super.initState();
    _initDeviceLocation();
  }

  void _initDeviceLocation() async {
    try {
      final coords = await LocationService.instance.getCurrentCoordinates();
      if (mounted) {
        setState(() {
          _myLat = coords["latitude"];
          _myLng = coords["longitude"];
        });
      }
    } catch (_) {}
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

        final currentTotal = booking?.totalAmount ?? widget.initialAmount;
        final currentBonus = booking?.urgencyBonus ?? 0.0;
        String address = booking?.customerAddressText ?? widget.pickupAddress;
        if (address.toLowerCase().contains("mumbai") ||
            address.toLowerCase().contains("bombay") ||
            address.trim().isEmpty) {
          address = 'current_live_location'.tr();
        }
        final custLat = booking?.customerLatitude;
        final custLng = booking?.customerLongitude;
        final effectivePickupLat = (_myLat != null && _myLat! > 1.0)
            ? _myLat
            : ((custLat != null && custLat > 1.0) ? custLat : null);
        final effectivePickupLng = (_myLng != null && _myLng! > 1.0)
            ? _myLng
            : ((custLng != null && custLng > 1.0) ? custLng : null);

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
                              if (onlineWorkers.isEmpty) ...[
                                const SizedBox(height: 16),
                                _buildExpandRadarSection(_selectedBroadcastRadius),
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
  Widget _buildExpandRadarSection(double currentRadius) {
    final expandOptions = [15.0, 20.0, 25.0, 35.0]
        .where((r) => r > currentRadius)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.radar_rounded, size: 16, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'expand_radius_prompt'.tr(args: [currentRadius.toInt().toString()]),
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (expandOptions.isNotEmpty) ...[
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
                              content: Text('searching_within_radius'.tr(args: [targetRad.toInt().toString()])),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
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
                            const Icon(Icons.zoom_out_map_rounded, size: 12, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              'expand_radar_to'.tr(args: [targetRad.toInt().toString()]),
                              style: const TextStyle(
                                color: Color(0xFFB45309),
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
        ],
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
    final rawArtisanName = booking.acceptedWorkerName ?? 'verified_pro'.tr();
    final artisanName = MlTranslationService.instance.translateSync(
      rawArtisanName,
      context.locale.languageCode,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CX.canvasCard,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: CX.emerald, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: CX.emerald.withValues(alpha: 0.4),
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
              gradient: CX.auroraSuccess,
              boxShadow: [
                BoxShadow(
                  color: CX.emerald.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'artisan_assigned_title'.tr(),
            style: WorkGoFonts.display(
              color: CX.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            'artisan_accepted_en_route'.tr(args: [artisanName]),
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
            gradient: CX.auroraSuccess,
            glowColor: CX.emerald,
            height: 52,
          ),
        ],
      ),
    );
  }
}
