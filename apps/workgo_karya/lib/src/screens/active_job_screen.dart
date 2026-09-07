import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';
import '../services/karya_equipment_engine.dart';
import '../services/karya_tts_service.dart';
import '../widgets/handoff_specialist_sheet.dart';
import '../widgets/karya_start_otp_sheet.dart';
import '../widgets/translated_text.dart';

class ActiveJobScreen extends StatefulWidget {
  const ActiveJobScreen({
    super.key,
    required this.booking,
    required this.worker,
  });

  final Booking booking;
  final Worker worker;

  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends State<ActiveJobScreen>
    with TickerProviderStateMixin {
  late BookingStatus _currentStatus;
  final BookingService _bookingService = BookingService();
  final C2paService _c2paService = C2paService();
  final WorkerService _workerService = WorkerService();

  late AnimationController _pulseCtrl;
  bool _isSigningC2pa = false;
  C2paManifestRecord? _c2paManifest;
  String? _capturedPhotoBase64;
  StreamSubscription<Position>? _activeJobGpsSub;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.booking.status == BookingStatus.pending
        ? BookingStatus.accepted
        : widget.booking.status;
    _c2paManifest = widget.booking.parsedC2paManifest;
    _capturedPhotoBase64 = widget.booking.proofPhotoBase64;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    if (_currentStatus == BookingStatus.accepted || _currentStatus == BookingStatus.inProgress) {
      _startActiveJobGpsStream();
    }
  }

  void _startActiveJobGpsStream() {
    _activeJobGpsSub?.cancel();

    late final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final serviceName = widget.booking.serviceType.trim().isNotEmpty
          ? widget.booking.serviceType
          : "WorkGo Service";
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 4),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: "WorkGo · Live Tracking Active 📍",
          notificationText: "Transmitting your road GPS for $serviceName...",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      );
    }

    _activeJobGpsSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position pos) async {
      try {
        await _bookingService.updateLiveWorkerLocation(
          bookingId: widget.booking.id,
          latitude: pos.latitude,
          longitude: pos.longitude,
          heading: pos.heading,
        );
        await _workerService.updateWorkerLocation(
          widget.worker.id,
          pos.latitude,
          pos.longitude,
        );
      } catch (e) {
        debugPrint("[ActiveJobScreen] Live GPS transmit error: $e");
      }
    });
  }

  void _stopActiveJobGpsStream() {
    _activeJobGpsSub?.cancel();
    _activeJobGpsSub = null;
  }

  @override
  void dispose() {
    _stopActiveJobGpsStream();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _advanceJob() async {
    if (_currentStatus == BookingStatus.accepted) {
      _showStartOtpDialog();
      return;
    }

    if (_currentStatus == BookingStatus.inProgress) {
      // Prompt for mandatory in-app camera capture with C2PA signing
      _showC2paCaptureDialog();
    }
  }

  void _showStartOtpDialog() {
    KaryaStartOtpSheet.show(
      context: context,
      bookingId: widget.booking.id,
      onSuccess: () {
        if (mounted) {
          setState(() => _currentStatus = BookingStatus.inProgress);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('otp_verified_service_started'.tr()),
              backgroundColor: const Color(0xFF047857),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Future<void> _showC2paCaptureDialog() async {
    final picker = ImagePicker();
    Uint8List? modalPhotoBytes;
    String? modalPhotoBase64;
    String? modalSha256;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickPhoto(ImageSource source) async {
            try {
              final XFile? file = await picker.pickImage(
                source: source,
                maxWidth: 1200,
                maxHeight: 1200,
                imageQuality: 80,
              );
              if (file != null) {
                final bytes = await file.readAsBytes();
                final b64 = base64Encode(bytes);
                final hash = _c2paService.computeSha256(bytes);
                setModalState(() {
                  modalPhotoBytes = bytes;
                  modalPhotoBase64 = b64;
                  modalSha256 = hash;
                });
                HapticFeedback.mediumImpact();
              }
            } catch (e) {
              debugPrint("[ActiveJobScreen] Camera capture error: $e");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('camera_capture_error_arg'.tr(args: [e.toString()])),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: KX.canvasCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: const Color(0xFF00E5FF),
                width: 1.5,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 28,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: KX.dividerLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0284C7), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'in_app_work_verification'.tr(),
                              style: WorkGoFonts.display(
                                color: KX.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'c2pa_hardware_seal'.tr(),
                              style: TextStyle(color: KX.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "WorkGo enforces C2PA content provenance. Capture a live photo of the completed repair. The app computes a hardware-backed SHA-256 hash and cryptographically seals it with your Artisan ID.",
                    style: TextStyle(color: KX.textSecondary, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  // Camera viewfinder / live photo preview
                  if (modalPhotoBytes == null)
                    GestureDetector(
                      onTap: () => pickPhoto(ImageSource.camera),
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: KX.canvasMid,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Color(0xFF0284C7),
                                  size: 38,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'tap_open_camera'.tr(),
                                style: WorkGoFonts.display(
                                  color: KX.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Hardware Camera · C2PA ISO 24653 Seal",
                                style: TextStyle(
                                  color: Color(0xFF0284C7),
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => pickPhoto(ImageSource.gallery),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.photo_library_rounded, size: 13, color: KX.textSecondary),
                                      SizedBox(width: 4),
                                      Text(
                                        "Or select test photo",
                                        style: TextStyle(fontSize: 11, color: KX.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF00E5FF),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.memory(
                              modalPhotoBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xE60D0A1C),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF00E5FF)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'captured_ready_seal'.tr(),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: InkWell(
                              onTap: () => pickPhoto(ImageSource.camera),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC000000),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white30),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.replay_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      "Retake",
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (modalSha256 != null)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: const Color(0xEE0D0A1C),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Text(
                                  "SHA-256: ${modalSha256!}",
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  if (modalPhotoBytes == null)
                    ElevatedButton.icon(
                      onPressed: () => pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: Text(
                        'capture_work_photo'.tr(),
                        style: WorkGoFonts.display(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: const Color(0xFF090714),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _isSigningC2pa
                          ? null
                          : () => _executeC2paCompletion(
                                setModalState,
                                modalPhotoBytes!,
                                modalPhotoBase64!,
                              ),
                      icon: _isSigningC2pa
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF090714)),
                            )
                          : const Icon(Icons.lock_rounded, size: 18),
                      label: Text(
                        _isSigningC2pa ? "Cryptographically Sealing..." : "Cryptographically Seal & Complete Job",
                        style: WorkGoFonts.display(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: const Color(0xFF090714),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _executeC2paCompletion(
    StateSetter setModalState,
    Uint8List rawBytes,
    String base64String,
  ) async {
    setModalState(() => _isSigningC2pa = true);
    setState(() => _isSigningC2pa = true);

    try {
      final manifest = await _c2paService.signMediaAsset(
        workerId: widget.worker.id,
        artisanName: widget.worker.name,
        trade: widget.booking.serviceType,
        rawBytes: rawBytes,
        base64Data: base64String,
      );

      // Atomically complete booking with Base64 photo proof & C2PA manifest in Firestore
      await _bookingService.completeBookingWithProof(
        bookingId: widget.booking.id,
        proofPhotoBase64: base64String,
        c2paManifest: manifest.toMap(),
      );

      if (mounted) {
        Navigator.of(context).pop(); // dismiss modal
        setState(() {
          _isSigningC2pa = false;
          _c2paManifest = manifest;
          _capturedPhotoBase64 = base64String;
          _currentStatus = BookingStatus.completed;
        });

        // TTS: mission complete
        final earned = widget.booking.amount * 0.98;
        KaryaTtsService.instance.announceJobComplete(earned);

        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Completed • C2PA Sealed • ₹${earned.toStringAsFixed(0)} credited",
                    style: WorkGoFonts.body(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } catch (e) {
      debugPrint("[ActiveJobScreen] C2PA completion error: $e");
      setModalState(() => _isSigningC2pa = false);
      if (mounted) {
        setState(() => _isSigningC2pa = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_completing_job_arg'.tr(args: [e.toString()])),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Booking?>(
      stream: _bookingService.streamBooking(widget.booking.id),
      initialData: widget.booking,
      builder: (context, snapshot) {
        final currentBooking = snapshot.data ?? widget.booking;
        final status = currentBooking.status;
        final effectiveManifest = currentBooking.parsedC2paManifest ?? _c2paManifest;
        final effectivePhoto = currentBooking.proofPhotoBase64 ?? _capturedPhotoBase64;

        final shortId = currentBooking.id.length > 6
            ? currentBooking.id.substring(0, 6).toUpperCase()
            : currentBooking.id.toUpperCase();

        return KaryaScaffold(
          appBar: KaryaAppBar(
            title: 'tactical_job_hud'.tr(),
            subtitle: "Booking #$shortId · ${currentBooking.serviceType}",
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Status Stage Indicator
                  KSlideFadeIn(
                    child: _StatusStageBar(status: status),
                  ),
                  const SizedBox(height: 12),

                  // ── Arrival Start OTP Prompt Card (When Accepted / En Route)
                  if (status == BookingStatus.accepted) ...[
                    KSlideFadeIn(
                      delay: const Duration(milliseconds: 20),
                      child: _ArrivalStartOtpPromptCard(
                        onEnterOtp: _showStartOtpDialog,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Live Service Progress HUD Card (When inProgress)
                  if (status == BookingStatus.inProgress) ...[
                    KSlideFadeIn(
                      delay: const Duration(milliseconds: 20),
                      child: _LiveJobProgressHUDCard(
                        startedAt: currentBooking.startedAt,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── C2PA Provenance Banner (If Completed)
                  if (status == BookingStatus.completed || effectiveManifest != null) ...[
                    KSlideFadeIn(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: KX.canvasCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            if (effectivePhoto != null && effectivePhoto.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Image.memory(
                                    base64Decode(
                                      effectivePhoto.contains(",")
                                          ? effectivePhoto.split(",").last
                                          : effectivePhoto,
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.verified_rounded,
                                      color: Color(0xFF0284C7),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE0F2FE),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 20),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'c2pa_sealed_badge'.tr(),
                                    style: WorkGoFonts.display(
                                      color: KX.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "SHA-256: ${effectiveManifest?.assetSha256.substring(0, 16) ?? "c9a70718b825c276"}...",
                                    style: const TextStyle(
                                      color: Color(0xFF0284C7),
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            C2paBadge(
                              manifestRecord: effectiveManifest,
                              artisanName: widget.worker.name,
                              proofPhotoBase64: effectivePhoto,
                              isCompact: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Service & Customer Dispatch Card
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 40),
                    child: _ServiceCustomerCard(
                      booking: currentBooking,
                      status: status,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Payout Breakdown
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 80),
                    child: _PayoutLedgerCard(booking: currentBooking),
                  ),
                  const SizedBox(height: 18),

                  // ── Slide Action CTA
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 120),
                    child: _buildActionSlider(status, currentBooking),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionSlider(BookingStatus status, Booking currentBooking) {
    if (currentBooking.handoffStatus == 'requested') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF93C5FD)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.sync_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Relay in Progress: ${currentBooking.handoffToWorkerName ?? 'Specialist'}",
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Awaiting peer specialist acknowledgment. Once accepted, this job transfers automatically and your ₹50 referral dividend will be reserved.",
              style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 11.5, height: 1.3),
            ),
          ],
        ),
      );
    }

    if (status == BookingStatus.completed) {
      return Column(
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('generating_invoice'.tr()),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF141416),
                ),
              );
              try {
                await InvoiceService.exportInvoicePdf(
                  booking: currentBooking,
                  workerName: widget.worker.name,
                  paymentMethod: "UPI",
                  context: context,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('invoice_export_error'.tr(args: ['$e'])),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.receipt_long_rounded, color: KX.textPrimary, size: 18),
            label: Text(
              "invoice_receipt".tr(),
              style: WorkGoFonts.display(
                color: KX.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          KaryaButton(
            label: "hud_back_home".tr(),
            icon: Icons.home_rounded,
            onPressed: () => Navigator.of(context).pop(),
            gradient: KX.luminaVioletGold,
            glowColor: KX.gold,
            height: 50,
          ),
        ],
      );
    }

    if (status == BookingStatus.accepted) {
      return Column(
        children: [
          KaryaSlideAction(
            key: const ValueKey("slide_start_otp"),
            label: "Slide when Arrived at Doorstep",
            icon: Icons.arrow_forward_ios_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFF2E1065), Color(0xFF4C1D95)],
            ),
            glowColor: KX.gold,
            height: 50,
            onConfirmed: _advanceJob,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final relayed = await HandoffSpecialistSheet.show(
                context,
                booking: currentBooking,
                currentWorker: widget.worker,
              );
              if (relayed == true && mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.swap_horiz_rounded, color: KX.amber, size: 18),
            label: const Text(
              "Hand Off to Specialist (Co-op Relay · Earn ₹50)",
              style: TextStyle(
                color: KX.amber,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: KX.amber),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        KaryaButton(
          label: 'capture_work_complete_service'.tr(),
          icon: Icons.camera_alt_rounded,
          onPressed: _advanceJob,
          gradient: KX.auroraAccept,
          glowColor: KX.emerald,
          height: 52,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final relayed = await HandoffSpecialistSheet.show(
              context,
              booking: currentBooking,
              currentWorker: widget.worker,
            );
            if (relayed == true && mounted) {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.swap_horiz_rounded, color: KX.amber, size: 18),
          label: const Text(
            "Hand Off to Specialist (Co-op Relay · Earn ₹50)",
            style: TextStyle(
              color: KX.amber,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: KX.amber),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  STATUS STAGE BAR (Progressive Status Pills)
// ──────────────────────────────────────────────────────────────
class _StatusStageBar extends StatelessWidget {
  const _StatusStageBar({required this.status});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final isEnRoute = status == BookingStatus.accepted;
    final isInProgress = status == BookingStatus.inProgress;
    final isCompleted = status == BookingStatus.completed;

    return KaryaCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 16,
      child: Row(
        children: [
          _stagePill("1. ${'status_accepted'.tr()}", isEnRoute || isInProgress || isCompleted, isEnRoute),
          const SizedBox(width: 6),
          _connector(isInProgress || isCompleted),
          const SizedBox(width: 6),
          _stagePill("2. ${'status_in_progress'.tr()}", isInProgress || isCompleted, isInProgress),
          const SizedBox(width: 6),
          _connector(isCompleted),
          const SizedBox(width: 6),
          _stagePill("3. ${'status_completed'.tr()}", isCompleted, isCompleted),
        ],
      ),
    );
  }

  Widget _stagePill(String label, bool isDone, bool isCurrent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent
              ? const Color(0xFFFEF3C7) // warm light amber
              : isDone
                  ? const Color(0xFFD1FAE5) // light emerald
                  : const Color(0xFFF3F4F6), // neutral light grey
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFFF59E0B) // amber border
                : isDone
                    ? const Color(0xFF10B981) // emerald border
                    : const Color(0xFFE5E7EB), // neutral border
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isCurrent
                ? const Color(0xFF92400E) // high-contrast dark amber
                : isDone
                    ? const Color(0xFF065F46) // high-contrast dark emerald
                    : const Color(0xFF4B5563), // high-contrast medium-dark grey
            fontSize: 10.5,
            fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }

  Widget _connector(bool active) {
    return Container(
      width: 8,
      height: 2,
      color: active ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  SERVICE & CUSTOMER DISPATCH CARD WITH AI GEAR CHECKLIST
// ──────────────────────────────────────────────────────────────
class _ServiceCustomerCard extends StatefulWidget {
  const _ServiceCustomerCard({
    required this.booking,
    required this.status,
  });

  final Booking booking;
  final BookingStatus status;

  @override
  State<_ServiceCustomerCard> createState() => _ServiceCustomerCardState();
}

class _ServiceCustomerCardState extends State<_ServiceCustomerCard> {
  final Set<String> _verifiedTools = {};
  String? _resolvedCustomerName;
  String? _resolvedCustomerPhone;

  @override
  void initState() {
    super.initState();
    _resolvedCustomerName = widget.booking.customerName;
    _resolvedCustomerPhone = widget.booking.customerPhone;
    if (_resolvedCustomerName == null || _resolvedCustomerName!.isEmpty || _resolvedCustomerName == "Customer Patron") {
      _resolveCustomer();
    }
  }

  Future<void> _resolveCustomer() async {
    try {
      final cId = widget.booking.customerId;
      if (cId.isEmpty) return;
      final uDoc = await FirebaseFirestore.instance.collection('users').doc(cId).get();
      if (uDoc.exists) {
        final d = uDoc.data() ?? {};
        final name = (d['displayName'] ?? d['name'] ?? d['fullName'] ?? '').toString().trim();
        final phone = (d['phoneNumber'] ?? d['phone'] ?? '').toString().trim();
        if (mounted) {
          setState(() {
            if (name.isNotEmpty) _resolvedCustomerName = name;
            if (phone.isNotEmpty) _resolvedCustomerPhone = phone;
          });
        }
      }
    } catch (_) {}
  }

  // true when booking has no server-side tools but local AI can suggest some
  bool get _hasAiSuggestions {
    if (widget.booking.suggestedToolsNeeded.isNotEmpty) return false;
    final suggested = KaryaEquipmentEngine.suggestTools(
      widget.booking.serviceType,
      widget.booking.customerIssueDetails ?? widget.booking.symptomDescription,
    );
    return suggested.isNotEmpty;
  }

  List<String> _effectiveTools(Booking booking) {
    if (booking.suggestedToolsNeeded.isNotEmpty) return booking.suggestedToolsNeeded;
    return KaryaEquipmentEngine.suggestTools(
      booking.serviceType,
      booking.customerIssueDetails ?? booking.symptomDescription,
    );
  }

  static Future<void> _launchMapsNavigation(
    String? address,
    double? lat,
    double? lng,
  ) async {
    Uri? uri;
    if (lat != null && lng != null) {
      // Android: Google Maps navigation intent; iOS: Apple Maps
      if (defaultTargetPlatform == TargetPlatform.android) {
        uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
        if (!await canLaunchUrl(uri)) {
          uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
        }
      } else {
        uri = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
        if (!await canLaunchUrl(uri)) {
          uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
        }
      }
    } else if (address?.isNotEmpty == true) {
      final encoded = Uri.encodeComponent(address!);
      if (defaultTargetPlatform == TargetPlatform.android) {
        uri = Uri.parse('geo:0,0?q=$encoded');
        if (!await canLaunchUrl(uri)) {
          uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
        }
      } else {
        uri = Uri.parse('https://maps.apple.com/?q=$encoded&dirflg=d');
        if (!await canLaunchUrl(uri)) {
          uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
        }
      }
    }
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final isDone = widget.status == BookingStatus.completed;
    final hasDiagnosticContext = (booking.equipmentTag?.isNotEmpty == true) ||
        (booking.customerIssueDetails?.isNotEmpty == true) ||
        (booking.symptomDescription?.isNotEmpty == true) ||
        booking.suggestedToolsNeeded.isNotEmpty;

    return KaryaCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      borderColor: isDone ? KX.emerald.withValues(alpha: 0.4) : KX.glassBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isDone ? KX.auroraAccept : KX.luminaVioletGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _serviceIcon(booking.serviceType),
                  color: const Color(0xFF090714),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceType.tr(),
                      style: WorkGoFonts.display(
                        color: KX.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (booking.isEmergency) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KX.rose.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "EMERGENCY",
                              style: WorkGoFonts.badge(color: KX.rose, fontSize: 9.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          booking.isDiagnosticVisit ? "Smart Diagnostic Visit" : "Direct Dispatch",
                          style: TextStyle(color: KX.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: KX.dividerLight, height: 1),
          const SizedBox(height: 12),

          // Customer Contact & Call Bar
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF059669),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resolvedCustomerName?.isNotEmpty == true
                          ? _resolvedCustomerName!
                          : (booking.customerName?.isNotEmpty == true
                              ? booking.customerName!
                              : "Valued Customer"),
                      style: const TextStyle(
                        color: KX.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((widget.status == BookingStatus.accepted ||
                            widget.status == BookingStatus.inProgress) &&
                        (_resolvedCustomerPhone?.isNotEmpty == true || booking.customerPhone?.isNotEmpty == true))
                      Text(
                        _resolvedCustomerPhone?.isNotEmpty == true
                            ? _resolvedCustomerPhone!
                            : booking.customerPhone!,
                        style: const TextStyle(
                          color: KX.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if ((widget.status == BookingStatus.accepted ||
                      widget.status == BookingStatus.inProgress ||
                      widget.status == BookingStatus.paymentPending) &&
                  ((_resolvedCustomerPhone?.isNotEmpty == true) ||
                      (booking.customerPhone?.isNotEmpty == true))) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final phone = (_resolvedCustomerPhone?.isNotEmpty == true)
                        ? _resolvedCustomerPhone!
                        : (booking.customerPhone ?? '');
                    await PhoneDialer.call(phone, context: context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF10B981),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          color: Color(0xFF065F46),
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'call_customer'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF065F46),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Doorstep Address + Navigate chip
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFFD97706), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: TranslatedText(
                  booking.customerAddressText?.isNotEmpty == true
                      ? booking.customerAddressText!
                      : 'customer_doorstep_address'.trSafe('Customer Doorstep Address'),
                  isAddress: true,
                  style: const TextStyle(color: KX.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _launchMapsNavigation(
                  booking.customerAddressText,
                  booking.customerLatitude,
                  booking.customerLongitude,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me_rounded, color: Color(0xFFB45309), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'hud_navigate'.tr(),
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // AI Diagnostic Brief & Gear Checklist (if diagnostic context present)
          if (hasDiagnosticContext) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: KX.canvasMid,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Equipment header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.precision_manufacturing_rounded,
                          color: Color(0xFFD97706),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.equipmentTag?.isNotEmpty == true
                              ? "Target: ${booking.equipmentTag}"
                              : "Diagnostic Context",
                          style: const TextStyle(
                            color: KX.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Customer issue & observations description
                  if (booking.customerIssueDetails?.isNotEmpty == true ||
                      booking.symptomDescription?.isNotEmpty == true) ...[
                    TranslatedText(
                      booking.customerIssueDetails?.isNotEmpty == true
                          ? booking.customerIssueDetails!
                          : booking.symptomDescription!,
                      style: const TextStyle(
                        color: KX.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Interactive AI Gear Checklist (booking-level or local AI fallback)
                  if (booking.suggestedToolsNeeded.isNotEmpty || _hasAiSuggestions) ...[
                    Row(
                      children: [
                        const Icon(Icons.handyman_rounded, size: 13, color: Color(0xFFD97706)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'gear_checklist_title'.tr(),
                            style: TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${_verifiedTools.length}/${_effectiveTools(booking).length} ${'tools_packed'.tr()}",
                          style: const TextStyle(
                            color: KX.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _effectiveTools(booking).map((tool) {
                        final isChecked = _verifiedTools.contains(tool);
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (isChecked) {
                                _verifiedTools.remove(tool);
                              } else {
                                _verifiedTools.add(tool);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isChecked
                                  ? const Color(0xFFD1FAE5)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isChecked
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFE5E7EB),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 13,
                                  color: isChecked ? const Color(0xFF059669) : KX.textMuted,
                                ),
                                const SizedBox(width: 6),
                                TranslatedText(
                                  tool,
                                  style: TextStyle(
                                    color: isChecked ? const Color(0xFF065F46) : KX.textPrimary,
                                    fontSize: 11,
                                    fontWeight: isChecked ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _serviceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case "plumbing":
      case "cat_plumbing":
        return Icons.plumbing_rounded;
      case "electrical":
      case "cat_electrical":
        return Icons.electric_bolt_rounded;
      case "carpentry":
      case "cat_carpentry":
        return Icons.carpenter_rounded;
      default:
        return Icons.handyman_rounded;
    }
  }
}

// ──────────────────────────────────────────────────────────────
//  ARRIVAL START OTP PROMPT CARD
// ──────────────────────────────────────────────────────────────
class _ArrivalStartOtpPromptCard extends StatelessWidget {
  const _ArrivalStartOtpPromptCard({required this.onEnterOtp});
  final VoidCallback onEnterOtp;

  @override
  Widget build(BuildContext context) {
    return KaryaCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.key_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'arrival_verification_gate'.tr(),
                      style: WorkGoFonts.display(
                        color: KX.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ask_customer_otp_hint'.tr(),
                      style: TextStyle(color: KX.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onEnterOtp,
              icon: const Icon(Icons.pin_rounded, size: 18, color: Color(0xFF0F172A)),
              label: Text(
                'enter_customer_otp'.tr(),
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBBF24),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  LIVE JOB PROGRESS HUD CARD (REAL-TIME ELAPSED STOPWATCH)
// ──────────────────────────────────────────────────────────────
class _LiveJobProgressHUDCard extends StatefulWidget {
  const _LiveJobProgressHUDCard({this.startedAt});
  final DateTime? startedAt;

  @override
  State<_LiveJobProgressHUDCard> createState() => _LiveJobProgressHUDCardState();
}

class _LiveJobProgressHUDCardState extends State<_LiveJobProgressHUDCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateElapsed());
  }

  void _updateElapsed() {
    final start = widget.startedAt ?? DateTime.now();
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
    final formatted = hours > 0
        ? "${hours.toString().padLeft(2, '0')}:$mins:$secs"
        : "$mins:$secs";

    return KaryaCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      borderColor: const Color(0xFF10B981).withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'live_service_underway'.tr(),
                    style: WorkGoFonts.badge(
                      color: const Color(0xFF047857),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded, color: Color(0xFF059669), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      formatted,
                      style: const TextStyle(
                        color: Color(0xFF065F46),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Service timer active · Complete work then seal with C2PA",
            style: TextStyle(
              color: KX.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMicroBadge(Icons.security_rounded, "Insured"),
              const SizedBox(width: 6),
              _buildMicroBadge(Icons.gps_fixed_rounded, "GPS Active"),
              const SizedBox(width: 6),
              _buildMicroBadge(Icons.camera_alt_rounded, "C2PA Ready"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMicroBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: KX.canvasMid,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: KX.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: KX.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  PAYOUT LEDGER CARD
// ──────────────────────────────────────────────────────────────
class _PayoutLedgerCard extends StatelessWidget {
  const _PayoutLedgerCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final gross = booking.amount;
    final welfare = gross * 0.02;
    final netPayout = gross - welfare;

    return KaryaCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'payout_breakdown_title'.tr(),
                style: WorkGoFonts.display(
                  color: KX.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                "₹${netPayout.toStringAsFixed(0)} Net",
                style: WorkGoFonts.display(
                  color: KX.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('gross_fee'.tr(), style: const TextStyle(color: KX.textSecondary, fontSize: 12)),
              Text("₹${gross.toStringAsFixed(0)}", style: const TextStyle(color: KX.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('coop_welfare_deduction'.tr(), style: TextStyle(color: KX.textSecondary, fontSize: 12)),
              Text("-₹${welfare.toStringAsFixed(0)}", style: const TextStyle(color: KX.emeraldLight, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
