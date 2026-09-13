import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';
import '../services/karya_tts_service.dart';

/// Shows the high-priority Emergency SOS Beacon bottom sheet.
///
/// Prompts the artisan to enable Live GPS if turned off,
/// records 10-second ambient audio proof with a live countdown,
/// and broadcasts the distress beacon to nearby artisans and admin.
Future<void> showSosBeaconBottomSheet(
  BuildContext context, {
  required Worker worker,
  AppUser? user,
  String? bookingId,
  String? customerId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => SosBeaconBottomSheet(
      worker: worker,
      user: user,
      bookingId: bookingId,
      customerId: customerId,
    ),
  );
}

class SosBeaconBottomSheet extends StatefulWidget {
  final Worker worker;
  final AppUser? user;
  final String? bookingId;
  final String? customerId;

  const SosBeaconBottomSheet({
    super.key,
    required this.worker,
    this.user,
    this.bookingId,
    this.customerId,
  });

  @override
  State<SosBeaconBottomSheet> createState() => _SosBeaconBottomSheetState();
}

class _SosBeaconBottomSheetState extends State<SosBeaconBottomSheet>
    with SingleTickerProviderStateMixin {
  bool _isLocationEnabled = false;
  Position? _livePosition;
  String _liveAddress = '';
  bool _isAcquiringGps = false;

  // Audio recording state
  bool _isRecordingAudio = false;
  int _recordingSecondsRemaining = 10;
  Timer? _countdownTimer;
  bool _isBroadcasting = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _checkLocationAndAcquireGps();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    EmergencySosService.instance.cancelAudioRecording();
    super.dispose();
  }

  Future<void> _checkLocationAndAcquireGps() async {
    final enabled =
        await EmergencySosService.instance.isLocationServiceEnabled();
    if (!mounted) return;
    setState(() {
      _isLocationEnabled = enabled;
    });

    if (enabled) {
      await _lockLiveGps();
    }
  }

  Future<void> _lockLiveGps() async {
    setState(() => _isAcquiringGps = true);
    final pos = await EmergencySosService.instance.acquireLiveGps();
    if (!mounted) return;
    if (pos != null) {
      String address = widget.worker.baseArea ?? '';
      try {
        final decoded = await LocationService.instance.reverseGeocode(
          pos.latitude,
          pos.longitude,
        );
        if (decoded.formattedAddress.isNotEmpty) {
          address = decoded.formattedAddress;
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _livePosition = pos;
        _liveAddress = address;
        _isAcquiringGps = false;
        _isLocationEnabled = true;
      });
    } else {
      if (mounted) {
        setState(() => _isAcquiringGps = false);
      }
    }
  }

  Future<void> _promptTurnOnLocation() async {
    await EmergencySosService.instance.openLocationSettings();
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      await _checkLocationAndAcquireGps();
    }
  }

  Future<void> _start10sAudioAndDispatch() async {
    if (!_isLocationEnabled || _livePosition == null) {
      await _promptTurnOnLocation();
      if (!_isLocationEnabled) return;
    }

    HapticFeedback.heavyImpact();
    final micStarted = await EmergencySosService.instance.startAudioRecording();
    if (!micStarted && mounted) {
      // If mic cannot start, dispatch with Live GPS immediately
      await _dispatchFinalBeacon(audioBase64: null);
      return;
    }

    setState(() {
      _isRecordingAudio = true;
      _recordingSecondsRemaining = 10;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_recordingSecondsRemaining > 1) {
        if (mounted) {
          setState(() => _recordingSecondsRemaining--);
        }
      } else {
        timer.cancel();
        await _finishRecordingAndDispatch();
      }
    });
  }

  Future<void> _finishRecordingAndDispatch() async {
    if (_isBroadcasting) return;
    _countdownTimer?.cancel();
    setState(() => _isBroadcasting = true);

    String? audioBase64;
    try {
      audioBase64 = await EmergencySosService.instance.stopAudioRecording();
    } catch (_) {}

    await _dispatchFinalBeacon(audioBase64: audioBase64);
  }

  Future<void> _dispatchFinalBeacon({String? audioBase64}) async {
    setState(() => _isBroadcasting = true);

    final double effectiveLat =
        _livePosition?.latitude ?? widget.worker.latitude ?? 11.2743;
    final double effectiveLng =
        _livePosition?.longitude ?? widget.worker.longitude ?? 77.5866;
    final String effectiveAddress = _liveAddress.isNotEmpty
        ? _liveAddress
        : ((widget.worker.baseArea?.isNotEmpty ?? false)
            ? widget.worker.baseArea!
            : 'Live GPS: ${effectiveLat.toStringAsFixed(4)}, ${effectiveLng.toStringAsFixed(4)}');

    final workerName = (widget.user != null && widget.user!.displayName.trim().isNotEmpty)
        ? widget.user!.displayName.trim()
        : (widget.worker.name.trim().isNotEmpty
            ? widget.worker.name.trim()
            : 'Artisan');

    final workerPhone = (widget.user?.phoneNumber != null &&
            widget.user!.phoneNumber!.trim().isNotEmpty)
        ? widget.user!.phoneNumber!.trim()
        : (widget.worker.phoneForCalling ?? '');

    try {
      await EmergencySosService.instance.broadcastDistressBeacon(
        workerId: widget.worker.id,
        workerName: workerName,
        workerPhone: workerPhone,
        latitude: effectiveLat,
        longitude: effectiveLng,
        address: effectiveAddress,
        audioBase64: audioBase64,
        audioDurationSeconds:
            10 - _recordingSecondsRemaining > 0 ? (10 - _recordingSecondsRemaining) : 10,
        bookingId: widget.bookingId,
        customerId: widget.customerId,
      );
    } catch (e) {
      debugPrint('[SOS] Beacon broadcast error: $e');
    }

    KaryaTtsService.instance.announce(
      'Emergency alert sent. Help is notified.',
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.emergency_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'sos_beacon_sent'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
      decoration: BoxDecoration(
        color: KX.canvasCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KX.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = _isRecordingAudio
                    ? 1.0 + (_pulseController.value * 0.12)
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(
                        alpha: _isRecordingAudio ? 0.3 : 0.15,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFEF4444),
                        width: _isRecordingAudio ? 2.5 : 1.5,
                      ),
                    ),
                    child: Icon(
                      _isRecordingAudio ? Icons.mic_rounded : Icons.sos_rounded,
                      color: const Color(0xFFEF4444),
                      size: 36,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'sos_beacon_title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: KX.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          const Text(
            "Broadcast your live GPS coordinates to cooperative admins and active artisans within 5 km for immediate assistance.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KX.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // 1. LOCATION OFF URGENT BANNER & PROMPT
          if (!_isLocationEnabled) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_off_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'sos_turn_on_location_title'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 13,
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
                    'sos_turn_on_location_desc'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF7F1D1D),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _promptTurnOnLocation,
                          icon: const Icon(Icons.settings_rounded, size: 14),
                          label: Text(
                            'sos_turn_on_location_btn'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _checkLocationAndAcquireGps,
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF991B1B),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            // 2. LIVE GPS LOCKED PILL
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.gps_fixed_rounded,
                    color: Color(0xFF059669),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isAcquiringGps
                          ? 'sos_gps_acquiring'.tr()
                          : 'sos_gps_locked'.tr(args: [
                              _livePosition?.latitude.toStringAsFixed(4) ??
                                  widget.worker.latitude?.toStringAsFixed(4) ??
                                  '11.2743',
                              _livePosition?.longitude.toStringAsFixed(4) ??
                                  widget.worker.longitude?.toStringAsFixed(4) ??
                                  '77.5866',
                            ]),
                      style: const TextStyle(
                        color: Color(0xFF065F46),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 3. AUDIO RECORDING WAVE & COUNTDOWN UI
          if (_isRecordingAudio) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'sos_recording_audio_proof'.tr(
                          args: ['$_recordingSecondsRemaining'],
                        ),
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isBroadcasting ? null : _finishRecordingAndDispatch,
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      'sos_send_now_btn'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            // 4. CONFIRM BUTTON
            ElevatedButton.icon(
              onPressed: _isBroadcasting ? null : _start10sAudioAndDispatch,
              icon: const Icon(Icons.warning_amber_rounded, size: 18),
              label: Text(
                'sos_beacon_confirm'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'sos_beacon_cancelled'.tr(),
                style: const TextStyle(color: KX.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
