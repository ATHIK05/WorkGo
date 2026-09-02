import 'dart:async';
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
  int _secondsRemaining = 45;
  Timer? _countdownTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
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
              Text("Fare boosted by +₹${extraBonus.toInt()}! Captains alerted."),
            ],
          ),
          backgroundColor: const Color(0xFF1E1035),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  void _onCaptainAccepted(Booking booking) {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _countdownTimer?.cancel();

    // Play alert sound & haptics
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CaptainAcceptedCelebration(
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
            _onCaptainAccepted(booking);
          });
        }

        final currentTotal = booking?.totalAmount ?? widget.initialAmount;
        final currentBonus = booking?.urgencyBonus ?? 0.0;
        final address = booking?.customerAddressText ?? widget.pickupAddress;

        return AuroraScaffold(
          appBar: AuroraAppBar(
            title: "Broadcasting Dispatch (${widget.serviceCategory})",
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Real OSM map with nearby worker markers replacing the illustrated radar
                  LiveMapView(
                    serviceCategory: widget.serviceCategory,
                    mode: MapMode.broadcastScanning,
                    pickupAddress: address,
                    height: 280,
                    // Real pickup coords (customer location saved at booking creation)
                    pickupLatitude: booking?.customerLatitude,
                    pickupLongitude: booking?.customerLongitude,
                  ),
                  const SizedBox(height: 20),

                  // Broadcasting Status Text
                  StreamBuilder<int>(
                    stream: _bookingService
                        .streamNearbyCaptainsCount(widget.serviceCategory),
                    builder: (context, capSnap) {
                      final count = capSnap.data ?? 0;
                      final countText = count > 0
                          ? "⚡ $count verified artisans roaming nearby"
                          : "Broadcasting live to nearest artisans";
                      return Column(
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
                                countText,
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
                            "Scanning 10 km live radius in Thanjavur / Chennai for available ${widget.serviceCategory} Captains...",
                            style: WorkGoFonts.body(
                              color: CX.textSecondary,
                              fontSize: 12.5,
                            ),
                            textAlign: TextAlign.center,
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
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Dispatch Fare",
                style: WorkGoFonts.body(color: CX.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    "₹${currentTotal.toStringAsFixed(0)}",
                    style: WorkGoFonts.numeric(
                      color: CX.amber,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (currentBonus > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CX.emerald.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "+₹${currentBonus.toInt()} BOOST",
                        style: WorkGoFonts.badge(
                          color: CX.emerald,
                          fontSize: 9.5,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: CX.canvasMid,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CX.glassBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: CX.violetLight, size: 16),
                const SizedBox(width: 6),
                Text(
                  "$_secondsRemaining s",
                  style: WorkGoFonts.numeric(
                    color: CX.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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
                "Need Captain Faster? Boost Fare",
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
            "Raise your fare tip like Rapido to incentivize immediate pickup by nearby artisans.",
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
//  CAPTAIN ACCEPTED CELEBRATION MODAL
// ──────────────────────────────────────────────────────────────
class _CaptainAcceptedCelebration extends StatelessWidget {
  const _CaptainAcceptedCelebration({
    required this.booking,
    required this.onContinue,
  });

  final Booking booking;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final captainName = booking.acceptedWorkerName ?? "Certified Artisan";

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
            "⚡ Captain Assigned!",
            style: WorkGoFonts.display(
              color: CX.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Artisan $captainName has accepted your request and is en route.",
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
