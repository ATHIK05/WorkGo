import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';

/// Displays the dedicated Customer Emergency Assistance bottom sheet.
Future<void> showCustomerEmergencySheet(
  BuildContext context, {
  Booking? booking,
  double? myLat,
  double? myLng,
  VoidCallback? onRefreshLocation,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => CustomerEmergencySheet(
      booking: booking,
      myLat: myLat,
      myLng: myLng,
      onRefreshLocation: onRefreshLocation,
    ),
  );
}

class CustomerEmergencySheet extends StatefulWidget {
  final Booking? booking;
  final double? myLat;
  final double? myLng;
  final VoidCallback? onRefreshLocation;

  const CustomerEmergencySheet({
    super.key,
    this.booking,
    this.myLat,
    this.myLng,
    this.onRefreshLocation,
  });

  @override
  State<CustomerEmergencySheet> createState() => _CustomerEmergencySheetState();
}

class _CustomerEmergencySheetState extends State<CustomerEmergencySheet> {
  bool _isBroadcasting = false;
  late PoliceStationInfo _policeStation;

  @override
  void initState() {
    super.initState();
    _policeStation = EmergencySosService.instance.getNearestPoliceStation(
      widget.myLat,
      widget.myLng,
      streetArea: widget.booking?.customerAddressText,
    );
  }

  Future<void> _makeCall(String number) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('[CustomerEmergencySheet] Call error: $e');
    }
  }

  Future<void> _broadcastDistress() async {
    if (_isBroadcasting) return;
    setState(() => _isBroadcasting = true);
    HapticFeedback.heavyImpact();

    try {
      await EmergencySosService.instance.broadcastDistressBeacon(
        workerId: widget.booking?.workerId ?? '',
        workerName: widget.booking?.acceptedWorkerName ?? 'Artisan Assigned',
        workerPhone: widget.booking?.workerPhone ?? '',
        latitude: widget.myLat ?? 0.0,
        longitude: widget.myLng ?? 0.0,
        address: widget.booking?.customerAddressText ?? 'Customer Location',
        senderType: 'customer',
        bookingId: widget.booking?.id,
        customerId: widget.booking?.customerId,
        policeStation: _policeStation,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'sos_customer_broadcast_sent'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
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
    } catch (e) {
      debugPrint('[CustomerEmergencySheet] Broadcast error: $e');
      if (mounted) {
        setState(() => _isBroadcasting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGps = widget.myLat != null && widget.myLng != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
      decoration: BoxDecoration(
        color: CX.canvasCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFFDC2626),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'sos_customer_sheet_title'.tr(),
                      style: const TextStyle(
                        color: CX.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'sos_customer_sheet_desc'.tr(),
                      style: const TextStyle(
                        color: CX.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Location Lock Status Check
          if (!hasGps) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_off_rounded,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'sos_turn_on_location_desc'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      await EmergencySosService.instance.openLocationSettings();
                      widget.onRefreshLocation?.call();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'sos_turn_on_location_btn'.tr(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'sos_gps_locked'.tr(args: [
                        widget.myLat!.toStringAsFixed(4),
                        widget.myLng!.toStringAsFixed(4),
                      ]),
                      style: const TextStyle(
                        color: Color(0xFF065F46),
                        fontSize: 11,
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

          // Quick Action 1: 112 National Police / ERSS
          InkWell(
            onTap: () => _makeCall(_policeStation.emergencyNumber),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_police_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'sos_call_police_112'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'sos_nearest_police_station'.tr(args: [
                            _policeStation.name,
                            _policeStation.distanceKm.toStringAsFixed(1),
                          ]),
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.call_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '112',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quick Action 2: 24/7 Cooperative Safety Desk
          InkWell(
            onTap: () => _makeCall('18002005555'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'sos_call_coop_helpline'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'WorkGo Cooperative Central Desk (Toll Free)',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFFD97706),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Primary Dispatch Broadcast Button
          ElevatedButton.icon(
            onPressed: _isBroadcasting ? null : _broadcastDistress,
            icon: _isBroadcasting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
            label: Text(
              'sos_customer_broadcast_btn'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
