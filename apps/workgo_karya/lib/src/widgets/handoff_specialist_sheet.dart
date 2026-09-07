import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

/// Handoff Specialist Sheet
/// Opened by on-site Artisan A when root cause requires another craft discipline.
/// Allows Artisan A to write diagnostic notes and transfer job to a specialist Artisan B.
class HandoffSpecialistSheet extends StatefulWidget {
  final Booking booking;
  final Worker currentWorker;

  const HandoffSpecialistSheet({
    super.key,
    required this.booking,
    required this.currentWorker,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Booking booking,
    required Worker currentWorker,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HandoffSpecialistSheet(
        booking: booking,
        currentWorker: currentWorker,
      ),
    );
  }

  @override
  State<HandoffSpecialistSheet> createState() => _HandoffSpecialistSheetState();
}

class _HandoffSpecialistSheetState extends State<HandoffSpecialistSheet> {
  final BookingService _bookingService = BookingService();
  final TextEditingController _notesCtrl = TextEditingController();

  late String _selectedTrade;
  Worker? _selectedSpecialist;
  bool _isSubmitting = false;

  final List<String> _tradeOptions = const [
    'Electrician',
    'Plumber',
    'Appliance Repair',
    'Carpenter',
    'Painter',
    'Welder / Metal',
    'Masonry',
  ];

  @override
  void initState() {
    super.initState();
    // Default to a trade other than the current worker's trade
    final currentTrade = widget.booking.serviceType;
    _selectedTrade = _tradeOptions.firstWhere(
      (t) => t != currentTrade,
      orElse: () => 'Plumber',
    );
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitHandoff() async {
    final notes = _notesCtrl.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('provide_diagnostic_findings_toast'.tr()),
          backgroundColor: KX.amberDark,
        ),
      );
      return;
    }

    if (_selectedSpecialist == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('select_specialist_artisan_toast'.tr()),
          backgroundColor: KX.amberDark,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      await _bookingService.requestBookingHandoff(
        bookingId: widget.booking.id,
        fromWorkerId: widget.currentWorker.id,
        fromWorkerName: widget.currentWorker.name,
        toWorkerId: _selectedSpecialist!.id,
        toWorkerName: _selectedSpecialist!.name,
        diagnosisNotes: notes,
        referralDividend: 50.0,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('relay_requested_success_arg'.tr(args: [_selectedSpecialist!.name])),
            backgroundColor: KX.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('handoff_failed_arg'.tr(args: [e.toString()])),
            backgroundColor: KX.rose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: KX.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6D1C7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: KX.violet.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: KX.amber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'coop_specialist_relay_title'.tr(),
                        style: WorkGoFonts.heading(
                          color: KX.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'coop_specialist_relay_subtitle'.tr(),
                        style: WorkGoFonts.body(
                          color: KX.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded, color: KX.textSecondary),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: KX.dividerLight),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Referral Dividend Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.handshake_rounded, color: Color(0xFF059669), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'peer_referral_dividend_title'.tr(),
                                style: const TextStyle(
                                  color: Color(0xFF065F46),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'peer_referral_dividend_desc'.tr(),
                                style: TextStyle(
                                  color: const Color(0xFF047857).withValues(alpha: 0.9),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Diagnostic Notes Input
                  Text(
                    'pre_inspection_diagnostic_notes_label'.tr(),
                    style: WorkGoFonts.heading(
                      color: KX.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: KX.dividerLight),
                    ),
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      style: WorkGoFonts.body(color: KX.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'pre_inspection_diagnostic_notes_hint'.tr(),
                        hintStyle: WorkGoFonts.body(color: const Color(0xFF94A3B8), fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Trade Selector
                  Text(
                    'select_craft_trade_label'.tr(),
                    style: WorkGoFonts.heading(
                      color: KX.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tradeOptions.map((trade) {
                      final isSelected = _selectedTrade == trade;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(trade),
                        selectedColor: KX.violet,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected ? KX.amber : KX.dividerLight,
                        ),
                        labelStyle: WorkGoFonts.body(
                          color: isSelected ? const Color(0xFF141416) : KX.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedTrade = trade;
                              _selectedSpecialist = null;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Real Available Artisans Stream
                  Text(
                    'select_peer_specialist_label'.tr(),
                    style: WorkGoFonts.heading(
                      color: KX.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<List<Worker>>(
                    stream: _bookingService.streamSpecializedWorkers(
                      primaryCategory: _selectedTrade,
                      equipmentTag: widget.booking.equipmentTag,
                    ),
                    builder: (context, snap) {
                      final allWorkers = snap.data ?? [];
                      // Filter out the current artisan
                      final workers = allWorkers.where((w) => w.id != widget.currentWorker.id).toList();

                      if (snap.connectionState == ConnectionState.waiting && workers.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(strokeWidth: 2, color: KX.amber),
                          ),
                        );
                      }

                      if (workers.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: KX.dividerLight),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: KX.textSecondary, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'no_specialists_online_arg'.tr(args: [_selectedTrade]),
                                  style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: workers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final worker = workers[index];
                          final isSelected = _selectedSpecialist?.id == worker.id;

                          return InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedSpecialist = worker);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? KX.amber : KX.dividerLight,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  WorkGoAvatar(
                                    avatarBase64: worker.avatarBase64,
                                    name: worker.name,
                                    radius: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          worker.name,
                                          style: WorkGoFonts.heading(
                                            color: KX.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          '${worker.skills.join(', ')} · ${worker.avgRating.toStringAsFixed(1)} ★',
                                          style: WorkGoFonts.body(
                                            color: KX.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? KX.amber : KX.textMuted,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom CTA
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: KX.dividerLight)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitHandoff,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KX.violet,
                    foregroundColor: const Color(0xFF141416),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF141416)),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting ? 'submitting_relay_btn'.tr() : 'send_relay_request_btn'.tr(),
                    style: WorkGoFonts.body(
                      color: const Color(0xFF141416),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
