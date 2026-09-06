import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
import '../services/ml_translation_service.dart';
import '../widgets/translated_text.dart';
import 'payment_receipt_screen.dart';

class LiveBookingTrackerScreen extends StatefulWidget {
  const LiveBookingTrackerScreen({
    super.key,
    required this.bookingId,
    this.initialBooking,
  });

  final String bookingId;
  final Booking? initialBooking;

  @override
  State<LiveBookingTrackerScreen> createState() =>
      _LiveBookingTrackerScreenState();
}

class _LiveBookingTrackerScreenState extends State<LiveBookingTrackerScreen>
    with TickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final WorkerService _workerService = WorkerService();

  late AnimationController _headerCtrl;
  late Animation<double> _headerScale;

  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    _initDeviceLocation();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _headerScale = CurvedAnimation(
      parent: _headerCtrl,
      curve: Curves.elasticOut,
    );
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

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuroraScaffold(
      appBar: AuroraAppBar(title: 'my_bookings'.tr()),
      body: StreamBuilder<Booking?>(
        stream: _bookingService.streamBooking(widget.bookingId),
        initialData: widget.initialBooking,
        builder: (context, snapshot) {
          final booking = snapshot.data;
          if (booking == null) {
            return const Center(
              child: AuroraShimmer(width: 320, height: 400, borderRadius: 24),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Live Real-Time Map with Moving Artisan Vehicle (OSM tiles)
                  SlideFadeIn(
                    child: StreamBuilder<Worker?>(
                      stream: booking.workerId != null
                          ? _workerService.streamWorker(booking.workerId!)
                          : Stream.value(null),
                      builder: (context, workerSnap) {
                        final liveWorker = workerSnap.data;
                        final effectiveWorkerLat =
                            booking.workerLatitude ?? liveWorker?.latitude;
                        final effectiveWorkerLng =
                            booking.workerLongitude ?? liveWorker?.longitude;
                        String effectiveWorkerName = booking.genuineArtisanName ??
                            (liveWorker != null && liveWorker.name.isNotEmpty && !Booking.isGenericArtisanName(liveWorker.name)
                                ? liveWorker.name
                                : (!Booking.isGenericArtisanName(booking.acceptedWorkerName)
                                    ? booking.acceptedWorkerName!
                                    : "${booking.serviceType.toLocalizedTrade()} ${'specialist'.tr()}"));

                        String trackerAddress = booking.customerAddressText ?? 'current_live_location'.tr();
                        if (trackerAddress.toLowerCase().contains("mumbai") ||
                            trackerAddress.toLowerCase().contains("bombay") ||
                            trackerAddress.trim().isEmpty) {
                          trackerAddress = 'current_live_location'.tr();
                        } else {
                          trackerAddress = MlTranslationService.instance.translateAddressSync(
                            trackerAddress,
                            context.locale.languageCode,
                          );
                        }

                        return LiveMapView(
                          serviceCategory: booking.serviceType,
                          mode: MapMode.routeNavigation,
                          artisanName: MlTranslationService.instance.translateSync(
                            effectiveWorkerName,
                            context.locale.languageCode,
                          ),
                          pickupAddress: trackerAddress,
                          workerProgress: booking.status == BookingStatus.accepted
                              ? 0.55
                              : (booking.status == BookingStatus.inProgress ? 1.0 : 0.1),
                          etaMinutes: 0,
                          distanceKm: 0.0,
                          height: 380,
                          // Real-time GPS from Firestore (updated live by artisan in background)
                          partnerLatitude: effectiveWorkerLat,
                          partnerLongitude: effectiveWorkerLng,
                          partnerHeading: booking.workerHeading,
                          pickupLatitude: (_myLat != null && _myLat! > 1.0)
                              ? _myLat
                              : ((booking.customerLatitude != null && booking.customerLatitude! > 1.0)
                                  ? booking.customerLatitude!
                                  : null),
                          pickupLongitude: (_myLng != null && _myLng! > 1.0)
                              ? _myLng
                              : ((booking.customerLongitude != null && booking.customerLongitude! > 1.0)
                                  ? booking.customerLongitude!
                                  : null),
                          // Customer's live device location (Rapido pulsing blue dot)
                          myLocationLatitude: _myLat,
                          myLocationLongitude: _myLng,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start Service OTP Banner (Only when status is accepted)
                  if (booking.status == BookingStatus.accepted) ...[
                    SlideFadeIn(
                      delay: const Duration(milliseconds: 20),
                      child: _StartServiceOtpBanner(
                        otp: booking.startOtp ?? "8492",
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (booking.status == BookingStatus.inProgress) ...[
                    SlideFadeIn(
                      delay: const Duration(milliseconds: 20),
                      child: _LiveServiceProgressCard(
                        booking: booking,
                        workerService: _workerService,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Status Header
                  SlideFadeIn(
                    delay: const Duration(milliseconds: 40),
                    child: _StatusHeaderCard(
                      booking: booking,
                      scaleAnim: _headerScale,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // C2PA Cryptographic Provenance Card (If Completed)
                  if (booking.status == BookingStatus.completed) ...[
                    SlideFadeIn(
                      delay: const Duration(milliseconds: 40),
                      child: _CompletedWorkProvenanceCard(
                        booking: booking,
                        workerService: _workerService,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Smart Diagnostic 100% Credit Guarantee Banner
                  if (booking.isDiagnosticVisit) ...[
                    SlideFadeIn(
                      delay: const Duration(milliseconds: 45),
                      child: _SmartDiagnosticCreditBanner(booking: booking),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Specialist Co-op Relay Provenance Card
                  if (booking.hasActiveHandoff || booking.referredByWorkerId != null || booking.handoffLogs.isNotEmpty) ...[
                    SlideFadeIn(
                      delay: const Duration(milliseconds: 50),
                      child: _RelayProvenanceCard(booking: booking),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Timeline
                  SlideFadeIn(
                    delay: const Duration(milliseconds: 60),
                    child: _TimelineCard(booking: booking),
                  ),
                  const SizedBox(height: 16),

                  // Artisan Card
                  SlideFadeIn(
                    delay: const Duration(milliseconds: 120),
                    child: _ArtisanCard(
                      booking: booking,
                      workerService: _workerService,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Details Card
                  SlideFadeIn(
                    delay: const Duration(milliseconds: 160),
                    child: _BookingDetailsCard(booking: booking),
                  ),
                  const SizedBox(height: 24),

                  // CTA
                  SlideFadeIn(
                    delay: const Duration(milliseconds: 200),
                    child: _buildBottomAction(context, booking),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, Booking booking) {
    if (booking.status == BookingStatus.completed) {
      final isPaid = booking.paymentStatus == PaymentStatus.paid ||
          (booking.invoiceId != null && booking.invoiceId!.isNotEmpty);
      final workerName = booking.genuineArtisanName ??
          (!Booking.isGenericArtisanName(booking.acceptedWorkerName)
              ? booking.acceptedWorkerName!
              : "");

      return GlowButton(
        label: isPaid ? 'invoice_receipt'.tr() : 'pay_now'.tr(),
        icon: isPaid ? Icons.receipt_long_rounded : Icons.payment_rounded,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => PaymentReceiptScreen(
              booking: booking,
              workerName: workerName,
              isReceiptOnly: isPaid,
            ),
          ),
        ),
        gradient: CX.auroraSuccess,
        glowColor: CX.emerald,
        height: 54,
      );
    }

    if (booking.status == BookingStatus.inProgress) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'service_in_progress'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'artisan_onsite_work'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _showSafetyHelpModal(context, booking),
              icon: const Icon(Icons.support_agent_rounded, size: 15, color: Color(0xFF2563EB)),
              label: Text(
                'help'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                backgroundColor: const Color(0xFFEFF6FF),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    if (booking.status == BookingStatus.pending || booking.status == BookingStatus.accepted) {
      return GlowButton(
        label: 'cancel_booking'.tr(),
        onPressed: () async {
          await _bookingService.updateBookingStatus(
              booking.id, BookingStatus.cancelled);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('booking_cancelled_toast'.tr()),
                backgroundColor: CX.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            );
          }
        },
        gradient: const LinearGradient(
          colors: [Color(0xFF4A1010), Color(0xFFEF4444)],
        ),
        glowColor: CX.rose,
        height: 54,
      );
    }

    return const SizedBox.shrink();
  }

  void _showSafetyHelpModal(BuildContext context, Booking booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'support_safety_center'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'support_safety_desc'.tr(),
              style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF10B981)),
              title: Text('helpline_24_7'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('toll_free_desc'.tr(), style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('connecting_support'.tr()),
                    backgroundColor: const Color(0xFF047857),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: Color(0xFFEF4444)),
              title: Text('report_artisan'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFEF4444)), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('report_artisan_sub'.tr(), style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  STATUS HEADER CARD — color-reactive
// ──────────────────────────────────────────────────────
class _StatusHeaderCard extends StatelessWidget {
  const _StatusHeaderCard({
    required this.booking,
    required this.scaleAnim,
  });

  final Booking booking;
  final Animation<double> scaleAnim;

  (Gradient, Color, String, AuroraBadgeStyle) get _statusTheme =>
      switch (booking.status) {
        BookingStatus.pending => (
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFFFFBEB)],
            ),
            CX.warning,
            'status_pending'.tr(),
            AuroraBadgeStyle.amber,
          ),
        BookingStatus.accepted => (
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFEFF6FF)],
            ),
            CX.info,
            'status_accepted'.tr(),
            AuroraBadgeStyle.info,
          ),
        BookingStatus.inProgress => (
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFFAF5FF)],
            ),
            CX.violet,
            'status_in_progress'.tr(),
            AuroraBadgeStyle.violet,
          ),
        BookingStatus.paymentPending => (
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFFFFBEB)],
            ),
            CX.warning,
            'status_payment_pending'.trSafe('Payment Pending'),
            AuroraBadgeStyle.amber,
          ),
        BookingStatus.completed => (
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFECFDF5)],
            ),
            CX.emerald,
            'status_completed'.tr(),
            AuroraBadgeStyle.emerald,
          ),
        BookingStatus.cancelled => (
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFFFF1F2)],
            ),
            CX.rose,
            'status_cancelled'.tr(),
            AuroraBadgeStyle.rose,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (gradient, glow, statusText, badgeStyle) = _statusTheme;
    final shortId = booking.id.length >= 8
        ? booking.id.substring(0, 8).toUpperCase()
        : booking.id.toUpperCase();

    return ScaleTransition(
      scale: scaleAnim,
      child: AuroraCard(
        gradient: gradient,
        glowColor: glow,
        borderColor: glow.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.serviceType.toLocalizedTrade(),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'booking_id'.tr(args: [shortId]),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (booking.isEmergency) ...[
                      AuroraBadge(label: 'emergency'.tr(), style: AuroraBadgeStyle.rose),
                      const SizedBox(height: 6),
                    ],
                    if (booking.isDiagnosticVisit) ...[
                      AuroraBadge(label: 'smart_diagnostic'.tr(), style: AuroraBadgeStyle.amber),
                      const SizedBox(height: 6),
                    ],
                    AuroraBadge(label: statusText, style: badgeStyle),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                PulsingDot(color: glow, size: 8),
                const SizedBox(width: 8),
                Text(
                  "₹${booking.amount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: glow.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: glow.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Text(
                    booking.paymentStatus.toLocalizedName().toUpperCase(),
                    style: TextStyle(
                      color: glow,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  ANIMATED TIMELINE CARD
// ──────────────────────────────────────────────────────
class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.booking});
  final Booking booking;

  int get _currentStep => switch (booking.status) {
        BookingStatus.pending => 0,
        BookingStatus.accepted => 1,
        BookingStatus.inProgress => 2,
        BookingStatus.paymentPending => 2,
        BookingStatus.completed => 3,
        BookingStatus.cancelled => -1,
      };

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        Icons.send_rounded,
        'request_dispatched_title'.tr(),
        'request_dispatched_sub'.tr(),
      ),
      (
        Icons.directions_bike_rounded,
        'artisan_assigned_en_route_title'.tr(),
        'artisan_assigned_en_route_sub'.tr(),
      ),
      (
        Icons.handyman_rounded,
        'service_in_progress_title'.tr(),
        'service_in_progress_sub'.tr(),
      ),
      (
        Icons.check_circle_rounded,
        'job_completed_title'.tr(),
        'job_completed_sub'.tr(),
      ),
    ];

    return AuroraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'live_service_progress'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CX.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          ...List.generate(steps.length, (i) {
            return _TimelineStep(
              stepIndex: i,
              currentStep: _currentStep,
              icon: steps[i].$1,
              title: steps[i].$2,
              subtitle: steps[i].$3,
              isLast: i == steps.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatefulWidget {
  const _TimelineStep({
    required this.stepIndex,
    required this.currentStep,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLast,
  });

  final int stepIndex;
  final int currentStep;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  State<_TimelineStep> createState() => _TimelineStepState();
}

class _TimelineStepState extends State<_TimelineStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fill;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: CAnim.verySlow);
    _fill = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    final isPassed =
        widget.currentStep >= widget.stepIndex && widget.currentStep != -1;
    if (isPassed) {
      Future.delayed(
        Duration(milliseconds: widget.stepIndex * 180),
        () {
          if (mounted) _ctrl.forward();
        },
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPassed = widget.currentStep >= widget.stepIndex &&
        widget.currentStep != -1;
    final isCurrent = widget.currentStep == widget.stepIndex;

    final Color nodeColor = isPassed
        ? (isCurrent ? CX.amber : CX.emerald)
        : CX.textMuted.withValues(alpha: 0.3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Node + Connector
        Column(
          children: [
            // Icon node
            AnimatedBuilder(
              animation: _fill,
              builder: (_, __) {
                return Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isPassed
                        ? LinearGradient(
                            colors: isCurrent
                                ? [CX.amber, CX.amberDark]
                                : [CX.emerald, const Color(0xFF065F46)],
                          )
                        : null,
                    color: isPassed
                        ? null
                        : const Color(0xFFF1F5F9),
                    border: Border.all(
                      color: nodeColor,
                      width: isCurrent ? 2.5 : 1.5,
                    ),
                    boxShadow: isPassed
                        ? [
                            BoxShadow(
                              color: nodeColor.withValues(alpha: _fill.value * 0.5),
                              blurRadius: 14 * _fill.value,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    widget.icon,
                    size: 16,
                    color: isPassed ? Colors.white : const Color(0xFF94A3B8),
                  ),
                );
              },
            ),

            if (!widget.isLast)
              AnimatedBuilder(
                animation: _fill,
                builder: (_, __) => Container(
                  width: 2,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        isPassed && widget.currentStep > widget.stepIndex
                            ? CX.emerald.withValues(alpha: _fill.value * 0.8)
                            : const Color(0xFFCBD5E1),
                        const Color(0xFFE2E8F0),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),

        // Text
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 7),
                Text(
                  widget.title,
                  style: TextStyle(
                    color: isPassed ? CX.textPrimary : CX.textMuted,
                    fontSize: 14,
                    fontWeight:
                        isCurrent ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: const TextStyle(color: CX.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────
//  ARTISAN CARD — real-time stream
// ──────────────────────────────────────────────────────
class _ArtisanCard extends StatelessWidget {
  const _ArtisanCard({
    required this.booking,
    required this.workerService,
  });

  final Booking booking;
  final WorkerService workerService;

  @override
  Widget build(BuildContext context) {
    if (booking.workerId == null) {
      return AuroraCard(
        glowColor: CX.violet,
        child: Row(
          children: [
            _PulsingRadarOrb(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'auto_dispatching_artisan'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CX.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'finding_coop_artisan_zone'.tr(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: CX.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<Worker?>(
      stream: workerService.streamWorker(booking.workerId!),
      builder: (context, snapshot) {
        final worker = snapshot.data;
        String artisanName = (booking.acceptedWorkerName?.isNotEmpty == true)
            ? booking.acceptedWorkerName!
            : (worker?.name.isNotEmpty == true
                ? worker!.name
                : 'specialist_title'.tr(args: [booking.serviceType.toLocalizedTrade()]));
        if (artisanName.toLowerCase() == 'artisan' ||
            artisanName.toLowerCase() == 'partner' ||
            artisanName.toLowerCase() == 'worker') {
          artisanName = worker?.name.isNotEmpty == true
              ? worker!.name
              : 'specialist_title'.tr(args: [booking.serviceType.toLocalizedTrade()]);
        }
        // STRICT PRIVACY & ANTI-LEAKAGE GUARD:
        // Worker phone is ONLY revealed once the booking is formally ACCEPTED or IN-PROGRESS.
        // While pending acceptance or unassigned, neither party's number is shared.
        final isConfirmedJob = booking.status == BookingStatus.accepted ||
            booking.status == BookingStatus.inProgress ||
            booking.status == BookingStatus.paymentPending;
        final phone = isConfirmedJob
            ? (booking.workerPhone ?? worker?.phoneForCalling)
            : null;
        final style = worker?.skills.isNotEmpty == true
            ? categoryStyle(worker!.skills.first)
            : categoryStyle(booking.serviceType);

        return AuroraCard(
          glowColor: style.glow,
          borderColor: style.glow.withValues(alpha: 0.3),
          child: Row(
            children: [
              Stack(
                children: [
                  WorkGoAvatar(
                    name: artisanName,
                    avatarBase64: worker?.avatarBase64,
                    radius: 27,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: CX.canvas,
                      ),
                      child: const PulsingDot(color: CX.success, size: 9),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslatedText(
                      artisanName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CX.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: AuroraBadge(
                            label: 'verified_badge'.tr(),
                            style: AuroraBadgeStyle.emerald,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (worker != null && worker.avgRating > 0) ...[
                          AuroraStarRow(
                            rating: worker.avgRating,
                            starSize: 13,
                          ),
                          if (worker.totalReviews > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              "(${worker.totalReviews})",
                              style: WorkGoFonts.body(color: CX.textMuted, fontSize: 11),
                            ),
                          ],
                        ] else ...[
                          Flexible(
                            child: AuroraBadge(
                              label: 'coop_pro_badge'.tr(),
                              style: AuroraBadgeStyle.cyan,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (phone != null && phone.isNotEmpty) ...[
                GestureDetector(
                  onTap: () async {
                    await PhoneDialer.call(phone, context: context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: CX.auroraSuccess,
                      boxShadow: [
                        BoxShadow(
                          color: CX.emerald.withValues(alpha: 0.45),
                          blurRadius: 14,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.phone_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () => _showReportSafetyDialog(context, booking, worker),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CX.rose.withValues(alpha: 0.15),
                    border: Border.all(color: CX.rose.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.flag_outlined, color: CX.rose, size: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportSafetyDialog(BuildContext context, Booking booking, Worker? worker) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        actionsOverflowButtonSpacing: 8,
        actionsOverflowDirection: VerticalDirection.up,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFECDD3), width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CX.rose.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, color: CX.rose, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "report_artisan_title".tr(),
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "report_artisan_desc".tr(),
                style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'report_safety_concern_hint'.tr(),
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CX.rose, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'cancel'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (booking.workerId != null) {
                await workerService.reportAndSuspendWorker(
                  workerId: booking.workerId!,
                  reporterId: booking.customerId,
                  reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : "Safety complaint reported by customer",
                  bookingId: booking.id,
                );
              }
              if (context.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("worker_suspended_notice".tr()),
                    backgroundColor: CX.rose,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CX.rose,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              "report_submit_btn".tr(),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

}

class _PulsingRadarOrb extends StatefulWidget {
  @override
  State<_PulsingRadarOrb> createState() => _PulsingRadarOrbState();
}

class _PulsingRadarOrbState extends State<_PulsingRadarOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: CX.auroraVioletCyan,
          boxShadow: [
            BoxShadow(
              color: CX.violet.withValues(alpha: _pulse.value * 0.6),
              blurRadius: 20 * _pulse.value,
              spreadRadius: 2 * _pulse.value,
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.radar_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  BOOKING DETAILS CARD
// ──────────────────────────────────────────────────────
class _BookingDetailsCard extends StatelessWidget {
  const _BookingDetailsCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'service_location_details'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CX.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: CX.glassBorder, height: 1),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.location_on_rounded,
            iconColor: CX.rose,
            text: (booking.customerAddressText?.isNotEmpty == true)
                ? booking.customerAddressText!
                : 'direct_dispatch_customer'.tr(),
            isAddress: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  iconColor: CX.cyan,
                  text:
                      'scheduled_time'.tr(args: [(booking.scheduledAt ?? DateTime.now()).to12HourDateTime(separator: ', ')]),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: CX.auroraVioletAmber,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CX.amber.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Text(
                  "₹${booking.amount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.isAddress = false,
  });
  final IconData icon;
  final Color iconColor;
  final String text;
  final bool isAddress;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: isAddress
              ? TranslatedText(
                  text,
                  isAddress: true,
                  style: const TextStyle(
                    color: CX.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    color: CX.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────
//  COMPLETED WORK C2PA PROVENANCE CARD
// ──────────────────────────────────────────────────────
class _CompletedWorkProvenanceCard extends StatelessWidget {
  const _CompletedWorkProvenanceCard({
    required this.booking,
    required this.workerService,
  });

  final Booking booking;
  final WorkerService workerService;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CX.canvasCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'work_provenance_authenticated'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CX.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              C2paBadge(
                manifestRecord: booking.parsedC2paManifest,
                artisanName: MlTranslationService.instance.translateSync(
                  booking.acceptedWorkerName ?? 'verified_artisan'.tr(),
                  context.locale.languageCode,
                ),
                proofPhotoBase64: booking.proofPhotoBase64,
                isCompact: true,
              ),
            ],
          ),
          if (booking.hasProofPhoto) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Image.memory(
                    base64Decode(
                      booking.proofPhotoBase64!.contains(",")
                          ? booking.proofPhotoBase64!.split(",").last
                          : booking.proofPhotoBase64!,
                    ),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xE60D0A1C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 12),
                          SizedBox(width: 4),
                          Text(
                            "Verified In-App Photo Proof",
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'c2pa_provenance_desc'.tr(),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: CX.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Color(0xFF059669), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'sha256_attestation_verified'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
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
}

// ──────────────────────────────────────────────────────
//  START SERVICE OTP BANNER (Rapido-Style Verification)
// ──────────────────────────────────────────────────────
class _StartServiceOtpBanner extends StatelessWidget {
  const _StartServiceOtpBanner({required this.otp});
  final String otp;

  @override
  Widget build(BuildContext context) {
    final digits = otp.length == 4 ? otp.split("") : ["8", "4", "9", "2"];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CX.canvasCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CX.amber.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: CX.amber.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CX.amber.withValues(alpha: 0.2),
                      ),
                      child: const Icon(Icons.key_rounded, color: CX.amber, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'start_service_otp'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CX.amber,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: CX.amberDark, size: 18),
                tooltip: 'copy_otp'.tr(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: otp));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('otp_copied_toast'.tr(args: [otp])),
                      backgroundColor: CX.amberDark,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4-Digit Glowing OTP Boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: digits.map((d) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 48,
                height: 54,
                decoration: BoxDecoration(
                  color: CX.canvasMid,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CX.amber, width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: CX.amber.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      color: CX.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          Center(
            child: Text(
              'share_otp_desc'.tr(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: CX.textSecondary, fontSize: 12, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  LIVE SERVICE PROGRESS CARD (Work in Progress HUD)
// ──────────────────────────────────────────────────────
class _LiveServiceProgressCard extends StatefulWidget {
  const _LiveServiceProgressCard({
    required this.booking,
    required this.workerService,
  });

  final Booking booking;
  final WorkerService workerService;

  @override
  State<_LiveServiceProgressCard> createState() => _LiveServiceProgressCardState();
}

class _LiveServiceProgressCardState extends State<_LiveServiceProgressCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateElapsed());
  }

  void _updateElapsed() {
    final start = widget.booking.startedAt ?? widget.booking.scheduledAt ?? DateTime.now();
    final diff = DateTime.now().difference(start);
    if (mounted) {
      setState(() {
        _elapsed = diff.isNegative ? Duration.zero : diff;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _elapsed.inHours;
    final mins = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final formattedTime = hours > 0
        ? "${hours.toString().padLeft(2, '0')}:$mins:$secs"
        : "$mins:$secs";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CX.canvasCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CX.emerald.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: CX.emerald.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Pulsing Indicator + Active Work Badge + Stopwatch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CX.emerald.withValues(alpha: 0.15),
                      ),
                      child: const PulsingDot(color: CX.emerald, size: 8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'service_in_progress_upper'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CX.emerald,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Live Stopwatch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_rounded, color: Color(0xFF34D399), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Main Info Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CX.canvasMid,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CX.dividerLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Icon(
                    Icons.handyman_rounded,
                    color: Color(0xFF059669),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'service_active'.tr(args: [widget.booking.serviceType.toLocalizedTrade()]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CX.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'artisan_onsite_work'.tr(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CX.textSecondary,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Trust & C2PA Assurance Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'otp_verified_assurance'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF15803D),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
}

// ─────────────────────────────────────────────
//  SMART DIAGNOSTIC 100% CREDIT BANNER
// ─────────────────────────────────────────────
class _SmartDiagnosticCreditBanner extends StatelessWidget {
  final Booking booking;
  const _SmartDiagnosticCreditBanner({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'smart_diagnostic_visit_fee'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF78350F),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'credited_100'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  booking.equipmentTag != null
                      ? 'targeting_equipment_desc'.tr(args: [booking.equipmentTag!])
                      : 'diagnostic_risk_free_desc'.tr(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 11.5,
                    height: 1.35,
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

// ─────────────────────────────────────────────
//  SPECIALIST CO-OP RELAY PROVENANCE CARD
// ─────────────────────────────────────────────
class _RelayProvenanceCard extends StatelessWidget {
  final Booking booking;
  const _RelayProvenanceCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final fromName = MlTranslationService.instance.translateSync(
      booking.handoffFromWorkerName ?? 'diagnosing_artisan'.tr(),
      context.locale.languageCode,
    );
    final toName = MlTranslationService.instance.translateSync(
      booking.handoffToWorkerName ?? booking.acceptedWorkerName ?? 'specialist'.tr(),
      context.locale.languageCode,
    );
    final notes = booking.handoffDiagnosisNotes ?? 'pre_inspection_fallback_notes'.tr();
    final isAccepted = booking.handoffStatus == 'accepted';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'specialist_coop_relay'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isAccepted
                          ? 'relay_acknowledged'.tr()
                          : 'relay_awaiting'.tr(),
                      style: TextStyle(
                        color: isAccepted ? const Color(0xFF047857) : const Color(0xFFD97706),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAccepted ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isAccepted ? 'status_confirmed'.tr() : 'status_in_route'.tr(),
                    style: TextStyle(
                      color: isAccepted ? const Color(0xFF059669) : const Color(0xFFD97706),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Provenance path: Artisan A -> Artisan B
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'referred_from'.tr(),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      fromName,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'target_specialist'.tr(),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      toName,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Diagnostic Notes from First Responder (Dynamic ML Kit On-Device Translation)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'pre_inspection_notes'.tr(),
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FutureBuilder<String>(
                  future: MlTranslationService.instance.translate(notes, context.locale),
                  builder: (context, snapshot) {
                    final translatedNotes = snapshot.data ?? notes;
                    return Text(
                      translatedNotes,
                      style: const TextStyle(color: Color(0xFF334155), fontSize: 11.5, height: 1.3),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'peer_protocol_guarantee'.tr(),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontStyle: FontStyle.italic),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

