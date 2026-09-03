import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
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
              Text("Fare boosted by +₹${extraBonus.toInt()}! Nearby Artisans alerted."),
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

        final currentTotal = booking?.totalAmount ?? widget.initialAmount;
        final currentBonus = booking?.urgencyBonus ?? 0.0;
        String address = booking?.customerAddressText ?? widget.pickupAddress;
        if (address.toLowerCase().contains("mumbai") ||
            address.toLowerCase().contains("bombay") ||
            address.trim().isEmpty) {
          address = "Current Live Location";
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
            title: "Finding Nearby ${widget.serviceCategory} Artisan",
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Real OSM map with nearby online worker markers and live My Location point
                  StreamBuilder<List<Worker>>(
                    stream: _bookingService.streamNearbyOnlineWorkers(widget.serviceCategory),
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
                                  Text(
                                    onlineWorkers.isNotEmpty
                                        ? "⚡ ${onlineWorkers.length} active ${widget.serviceCategory} artisan${onlineWorkers.length > 1 ? 's' : ''} online nearby"
                                        : "⚡ Broadcasting live to nearest artisans",
                                    style: WorkGoFonts.heading(
                                      color: CX.emerald,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Scanning 10 km live radius around ${address.split(',').first.trim()} for verified ${widget.serviceCategory} Artisans...",
                                style: WorkGoFonts.body(
                                  color: CX.textSecondary,
                                  fontSize: 12.5,
                                ),
                                textAlign: TextAlign.center,
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
                      "Cancel Broadcast",
                      style: WorkGoFonts.heading(
                        color: CX.rose,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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
                    "Artisan Service Fare",
                    style: WorkGoFonts.body(
                      color: CX.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
                            "+₹${currentBonus.toInt()} TIP INCLUDED",
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
                      "0% Commission",
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
                    "Direct to Artisan • Transparent Transit & Base Allowance",
                    style: WorkGoFonts.body(
                      color: CX.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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
              Text(
                "Need an Artisan Faster? Boost Fare",
                style: WorkGoFonts.heading(
                  color: CX.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Add an optional urgency tip to incentivize immediate acceptance by nearby trade artisans.",
            style: WorkGoFonts.body(color: CX.textSecondary, fontSize: 11.5),
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
    final artisanName = booking.acceptedWorkerName ?? "Certified Artisan";

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
            "⚡ Artisan Assigned!",
            style: WorkGoFonts.display(
              color: CX.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Artisan $artisanName has accepted your request and is en route.",
            style: WorkGoFonts.body(
              color: CX.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          GlowButton(
            label: "Track Artisan Live & View OTP",
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
