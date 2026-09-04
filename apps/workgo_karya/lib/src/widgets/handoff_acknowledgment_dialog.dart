import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

/// Handoff Acknowledgment Dialog
/// Shown to the incoming specialist when reviewing a cooperative job relay from a peer.
class HandoffAcknowledgmentDialog extends StatefulWidget {
  final Booking booking;
  final Worker currentSpecialist;

  const HandoffAcknowledgmentDialog({
    super.key,
    required this.booking,
    required this.currentSpecialist,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Booking booking,
    required Worker currentSpecialist,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HandoffAcknowledgmentDialog(
        booking: booking,
        currentSpecialist: currentSpecialist,
      ),
    );
  }

  @override
  State<HandoffAcknowledgmentDialog> createState() => _HandoffAcknowledgmentDialogState();
}

class _HandoffAcknowledgmentDialogState extends State<HandoffAcknowledgmentDialog> {
  final BookingService _bookingService = BookingService();
  bool _hasReviewedNotes = false;
  bool _isAccepting = false;

  Future<void> _acceptRelay() async {
    if (!_hasReviewedNotes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check the acknowledgment box confirming you have reviewed the diagnosis notes.'),
          backgroundColor: KX.amberDark,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isAccepting = true);

    try {
      await _bookingService.acknowledgeAndAcceptHandoff(
        bookingId: widget.booking.id,
        specialistWorkerId: widget.currentSpecialist.id,
        specialistWorkerName: widget.currentSpecialist.name,
        initialWorkerLat: widget.currentSpecialist.latitude,
        initialWorkerLng: widget.currentSpecialist.longitude,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Specialist relay accepted! Customer is awaiting your arrival.'),
            backgroundColor: KX.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAccepting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not accept relay: $e'),
            backgroundColor: KX.rose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final referringArtisan = b.handoffFromWorkerName ?? 'Peer Artisan';
    final notes = b.handoffDiagnosisNotes ?? 'Pre-inspection diagnosis notes pending.';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Co-op Specialist Relay Alert',
                        style: WorkGoFonts.heading(
                          color: KX.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Direct job referral from $referringArtisan',
                        style: WorkGoFonts.body(
                          color: KX.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: KX.dividerLight),
            const SizedBox(height: 14),

            // Target Equipment Tag
            if (b.equipmentTag != null && b.equipmentTag!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: KX.violet.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.handyman_rounded, color: KX.amber, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Equipment: ${b.equipmentTag}',
                      style: WorkGoFonts.body(
                        color: KX.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Diagnostic Notes Box
            Text(
              'Pre-Inspection Diagnostic Findings:',
              style: WorkGoFonts.heading(
                color: KX.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                notes,
                style: WorkGoFonts.body(
                  color: const Color(0xFF334155),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Service Location
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: KX.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    b.customerAddressText ?? 'Registered Service Location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WorkGoFonts.body(
                      color: KX.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Mutual Acknowledgment Checkbox
            InkWell(
              onTap: () => setState(() => _hasReviewedNotes = !_hasReviewedNotes),
              borderRadius: BorderRadius.circular(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _hasReviewedNotes,
                    activeColor: KX.amber,
                    onChanged: (val) => setState(() => _hasReviewedNotes = val ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'I have reviewed the pre-inspection diagnosis and confirm I possess the necessary specialization & tools.',
                        style: WorkGoFonts.body(
                          color: KX.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isAccepting ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: KX.dividerLight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Decline',
                      style: WorkGoFonts.body(
                        color: KX.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isAccepting || !_hasReviewedNotes ? null : _acceptRelay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KX.violet,
                      foregroundColor: const Color(0xFF141416),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isAccepting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF141416)),
                          )
                        : Text(
                            'Acknowledge & Accept',
                            style: WorkGoFonts.body(
                              color: const Color(0xFF141416),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
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
