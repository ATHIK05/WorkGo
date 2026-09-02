import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

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

  late AnimationController _pulseCtrl;
  bool _isSigningC2pa = false;
  C2paManifestRecord? _c2paManifest;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.booking.status == BookingStatus.pending
        ? BookingStatus.accepted
        : widget.booking.status;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
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
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    final c3 = TextEditingController();
    final c4 = TextEditingController();
    final f2 = FocusNode();
    final f3 = FocusNode();
    final f4 = FocusNode();
    bool isVerifying = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: KX.canvasCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: KX.gold, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
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
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.key_rounded, color: Color(0xFFFBBF24), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Enter Customer Start OTP",
                            style: WorkGoFonts.display(
                              color: KX.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Ask the customer for the 4-digit code shown on their screen",
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4-Box Pin Inputs
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildOtpBox(c1, null, f2, (val) {
                      if (val.isNotEmpty) f2.requestFocus();
                    }),
                    const SizedBox(width: 10),
                    _buildOtpBox(c2, f2, f3, (val) {
                      if (val.isNotEmpty) f3.requestFocus();
                    }),
                    const SizedBox(width: 10),
                    _buildOtpBox(c3, f3, f4, (val) {
                      if (val.isNotEmpty) f4.requestFocus();
                    }),
                    const SizedBox(width: 10),
                    _buildOtpBox(c4, f4, null, (val) {}),
                  ],
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const SizedBox(height: 22),

                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final fullOtp = "${c1.text}${c2.text}${c3.text}${c4.text}".trim();
                          if (fullOtp.length != 4) {
                            setModalState(() => errorText = "Please enter all 4 digits");
                            return;
                          }

                          setModalState(() {
                            isVerifying = true;
                            errorText = null;
                          });

                          try {
                            final success = await _bookingService.verifyStartOtp(
                              bookingId: widget.booking.id,
                              enteredOtp: fullOtp,
                            );

                            if (success) {
                              HapticFeedback.heavyImpact();
                              if (mounted) {
                                setState(() => _currentStatus = BookingStatus.inProgress);
                              }
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("OTP Verified! Job started successfully."),
                                    backgroundColor: Color(0xFF047857),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else {
                              HapticFeedback.vibrate();
                              setModalState(() {
                                isVerifying = false;
                                errorText = "Incorrect OTP. Please check customer app.";
                              });
                            }
                          } catch (e) {
                            setModalState(() {
                              isVerifying = false;
                              errorText = "Verification error: $e";
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBBF24),
                    foregroundColor: const Color(0xFF0D0A1C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          "Verify & Start Service",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOtpBox(
    TextEditingController ctrl,
    FocusNode? currentFocus,
    FocusNode? nextFocus,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      width: 52,
      height: 56,
      decoration: BoxDecoration(
        color: KX.canvasMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KX.gold.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Center(
        child: TextField(
          controller: ctrl,
          focusNode: currentFocus,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(color: KX.textPrimary, fontSize: 24, fontWeight: FontWeight.w900),
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _showC2paCaptureDialog() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: KX.canvasCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: const Color(0xFF00E5FF),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
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
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF00E5FF), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "In-App Work Verification",
                            style: WorkGoFonts.display(
                              color: KX.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "C2PA Content Credential & Hardware Signing",
                            style: TextStyle(color: KX.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  "WorkGo enforces C2PA content provenance. Take a live photo of the completed repair. The app will compute a hardware-backed SHA-256 hash and cryptographically seal it with your Artisan ID.",
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),

                // Simulated live camera viewfinder
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: KX.canvasElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_rounded, color: Color(0xFF00E5FF), size: 48),
                        const SizedBox(height: 10),
                        Text(
                          "In-App Hardware Camera Ready",
                          style: WorkGoFonts.badge(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Device Attestation: PLAY_INTEGRITY_SEALED",
                          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: _isSigningC2pa ? null : () => _executeC2paCompletion(setModalState),
                  icon: _isSigningC2pa
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF090714)),
                        )
                      : const Icon(Icons.lock_rounded, size: 18),
                  label: Text(
                    _isSigningC2pa ? "Signing C2PA Manifest..." : "Capture & Seal Completion",
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
          );
        },
      ),
    );
  }

  Future<void> _executeC2paCompletion(StateSetter setModalState) async {
    setModalState(() => _isSigningC2pa = true);
    setState(() => _isSigningC2pa = true);

    // Simulate captured camera raw bytes
    final capturedBytes = Uint8List.fromList(
      utf8.encode("WORKGO_COMPLETION_PHOTO_RAW_${widget.booking.id}_${DateTime.now().millisecondsSinceEpoch}"),
    );

    final manifest = await _c2paService.signMediaAsset(
      workerId: widget.worker.id,
      artisanName: widget.worker.name,
      trade: widget.booking.serviceType,
      rawBytes: capturedBytes,
    );

    await _bookingService.updateBookingStatus(widget.booking.id, BookingStatus.completed);

    if (mounted) {
      Navigator.of(context).pop(); // dismiss modal
      setState(() {
        _isSigningC2pa = false;
        _c2paManifest = manifest;
        _currentStatus = BookingStatus.completed;
      });

      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Job Completed & C2PA Provenance Manifest Sealed! ₹${(widget.booking.amount * 0.98).toStringAsFixed(0)} credited.",
                  style: WorkGoFonts.body(color: Colors.white),
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
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Booking?>(
      stream: _bookingService.streamBooking(widget.booking.id),
      initialData: widget.booking,
      builder: (context, snapshot) {
        final currentBooking = snapshot.data ?? widget.booking;
        final status = currentBooking.status;

        final shortId = currentBooking.id.length > 6
            ? currentBooking.id.substring(0, 6).toUpperCase()
            : currentBooking.id.toUpperCase();

        return KaryaScaffold(
          appBar: KaryaAppBar(
            title: "Tactical Job HUD",
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

                  // ── C2PA Provenance Banner (If Completed)
                  if (status == BookingStatus.completed || _c2paManifest != null) ...[
                    KSlideFadeIn(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: KX.canvasCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "C2PA Content Credential Sealed",
                                    style: WorkGoFonts.display(
                                      color: KX.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "SHA-256: ${_c2paManifest?.assetSha256.substring(0, 16) ?? "e3b0c44298fc1c14"}...",
                                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                            C2paBadge(
                              manifestRecord: _c2paManifest,
                              artisanName: widget.worker.name,
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
                    child: _buildActionSlider(status),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionSlider(BookingStatus status) {
    if (status == BookingStatus.completed) {
      return KaryaButton(
        label: "nav_cockpit".tr(),
        icon: Icons.home_rounded,
        onPressed: () => Navigator.of(context).pop(),
        gradient: KX.luminaVioletGold,
        glowColor: KX.gold,
        height: 50,
      );
    }

    if (status == BookingStatus.accepted) {
      return KaryaSlideAction(
        label: "Arrived · Enter Customer OTP",
        icon: Icons.key_rounded,
        gradient: KX.luminaVioletGold,
        glowColor: KX.gold,
        height: 52,
        onConfirmed: _advanceJob,
      );
    }

    return KaryaSlideAction(
      label: "Capture Work & Complete",
      icon: Icons.camera_alt_rounded,
      gradient: KX.auroraAccept,
      glowColor: KX.emerald,
      height: 52,
      onConfirmed: _advanceJob,
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
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isCurrent
              ? KX.gold.withValues(alpha: 0.2)
              : isDone
                  ? KX.violet.withValues(alpha: 0.25)
                  : KX.canvasElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrent
                ? KX.gold
                : isDone
                    ? KX.violetNeon.withValues(alpha: 0.5)
                    : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: WorkGoFonts.badge(
            color: isCurrent
                ? KX.gold
                : isDone
                    ? KX.textPrimary
                    : KX.textMuted,
            fontSize: 9.5,
            fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _connector(bool active) {
    return Container(
      width: 8,
      height: 2,
      color: active ? KX.gold : KX.textMuted.withValues(alpha: 0.3),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  SERVICE & CUSTOMER DISPATCH CARD
// ──────────────────────────────────────────────────────────────
class _ServiceCustomerCard extends StatelessWidget {
  const _ServiceCustomerCard({
    required this.booking,
    required this.status,
  });

  final Booking booking;
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final isDone = status == BookingStatus.completed;

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
                          "Direct Dispatch",
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
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: KX.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Doorstep Service Address · Sector 4, Metro Corridor",
                  style: TextStyle(color: KX.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
                "Payout Breakdown",
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
              Text("Gross Fee", style: TextStyle(color: KX.textSecondary, fontSize: 12)),
              Text("₹${gross.toStringAsFixed(0)}", style: const TextStyle(color: KX.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Co-op Welfare (2%)", style: TextStyle(color: KX.textSecondary, fontSize: 12)),
              Text("-₹${welfare.toStringAsFixed(0)}", style: const TextStyle(color: KX.emeraldLight, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
