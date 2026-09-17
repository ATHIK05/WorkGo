import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../services/ml_translation_service.dart';
import 'rating_review_screen.dart';

class PaymentReceiptScreen extends StatefulWidget {
  const PaymentReceiptScreen({
    super.key,
    required this.booking,
    this.workerName = "Cooperative Artisan",
    this.isReceiptOnly,
  });

  final Booking booking;
  final String workerName;
  final bool? isReceiptOnly;

  @override
  State<PaymentReceiptScreen> createState() => _PaymentReceiptScreenState();
}

class _PaymentReceiptScreenState extends State<PaymentReceiptScreen> {
  PaymentGatewayConfig _gatewayConfig = PaymentGatewayConfig.defaults();
  String _selectedMethod = "phonepe";
  bool _isProcessing = false;
  bool _isPaid = false;
  bool _isCustomerPaidAck = false;
  bool _isWorkerReceivedAck = false;
  bool _showQrCode = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _bookingSub;

  bool _isRated = false;
  double _ratingValue = 5.0;
  String _reviewComment = "";
  List<String> _reviewTags = [];

  final TextEditingController _utrCtrl = TextEditingController();
  late String _effectiveWorkerName;
  String _artisanUpiId = "workgo.artisan@upi";
  bool _artisanAcceptsCash = false;

  @override
  void initState() {
    super.initState();
    _isCustomerPaidAck = widget.booking.isCustomerPaid || widget.booking.customerPaidAck == true;
    _isWorkerReceivedAck = widget.booking.isWorkerReceived || widget.booking.workerReceivedAck == true;
    _isPaid = widget.booking.paymentStatus == PaymentStatus.paid || _isWorkerReceivedAck;

    _effectiveWorkerName = (widget.booking.genuineArtisanName ??
        (!Booking.isGenericArtisanName(widget.workerName) ? widget.workerName : "")).trim();
    if (_effectiveWorkerName.isEmpty) {
      _effectiveWorkerName = widget.workerName;
    }
    _resolveArtisanDetails();

    _isRated = widget.booking.isRated || widget.booking.rating != null;
    if (_isRated) {
      _ratingValue = widget.booking.rating ?? 5.0;
      _reviewComment = widget.booking.reviewComment ?? "";
      _reviewTags = List<String>.from(widget.booking.reviewTags);
    }

    _listenToBookingStatus();
    _initGatewayConfig();
    _checkExistingRating();
  }

  void _listenToBookingStatus() {
    try {
      if (Firebase.apps.isEmpty || widget.booking.id.isEmpty) return;
      _bookingSub = FirebaseFirestore.instance
          .collection("bookings")
          .doc(widget.booking.id)
          .snapshots()
          .listen((snap) {
        if (!snap.exists || snap.data() == null) return;
        final b = Booking.fromFirestore(snap);
        if (mounted) {
          setState(() {
            if (b.customerPaidAck == true || b.isCustomerPaid) {
              _isCustomerPaidAck = true;
            }
            if (b.workerReceivedAck == true ||
                b.paymentStatus == PaymentStatus.paid ||
                b.status == BookingStatus.completed) {
              _isWorkerReceivedAck = true;
              _isPaid = true;
            }
          });
        }
      });
    } catch (_) {}
  }

  Future<void> _resolveArtisanDetails() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final wId = widget.booking.workerId;
      if (wId == null || wId.isEmpty) return;

      // 1. Query 'workers' collection
      final workerDoc = await FirebaseFirestore.instance.collection("workers").doc(wId).get();
      if (workerDoc.exists) {
        final data = workerDoc.data() ?? {};
        final realName = (data["name"] ?? data["displayName"] ?? data["artisanName"] ?? "").toString().trim();
        final upi = (data["upiId"] ?? data["upi"] ?? "").toString().trim();
        final acceptsCash = data["acceptsCash"] == true;
        if (mounted) {
          setState(() {
            if (upi.isNotEmpty) _artisanUpiId = upi;
            _artisanAcceptsCash = acceptsCash;
            if ((upi.isEmpty || _artisanUpiId == "workgo.artisan@upi") && acceptsCash) {
              _selectedMethod = "cash";
            }
          });
        }
        if (realName.isNotEmpty && !Booking.isGenericArtisanName(realName)) {
          if (mounted) {
            setState(() => _effectiveWorkerName = realName);
          }
          _silentlyBackfillWorkerName(realName);
          return;
        }
      }

      // 2. Query 'users' collection
      final userDoc = await FirebaseFirestore.instance.collection("users").doc(wId).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final realName = (data["displayName"] ?? data["name"] ?? data["fullName"] ?? "").toString().trim();
        final upi = (data["upiId"] ?? data["upi"] ?? "").toString().trim();
        if (upi.isNotEmpty && mounted) {
          setState(() => _artisanUpiId = upi);
        }
        if (realName.isNotEmpty && !Booking.isGenericArtisanName(realName)) {
          if (mounted) {
            setState(() => _effectiveWorkerName = realName);
          }
          _silentlyBackfillWorkerName(realName);
          return;
        }
      }
    } catch (_) {
      // Safe fallback for test/offline
    }
  }

  void _silentlyBackfillWorkerName(String realName) {
    if (widget.booking.id.isNotEmpty && widget.booking.acceptedWorkerName != realName) {
      FirebaseFirestore.instance
          .collection("bookings")
          .doc(widget.booking.id)
          .update({"acceptedWorkerName": realName})
          .catchError((_) {});
    }
  }

  Future<void> _checkExistingRating() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final snap = await FirebaseFirestore.instance
          .collection("reviews")
          .where("bookingId", isEqualTo: widget.booking.id)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty && mounted) {
        final data = snap.docs.first.data();
        final score = (data["rating"] as num?)?.toDouble() ?? 5.0;
        final comment = (data["comment"] as String?) ?? "";
        final tags = List<String>.from(data["tags"] ?? []);

        setState(() {
          _isRated = true;
          _ratingValue = score;
          _reviewComment = comment;
          _reviewTags = tags;
        });

        // Silently backfill booking doc so subsequent loads are immediate
        FirebaseFirestore.instance
            .collection("bookings")
            .doc(widget.booking.id)
            .update({
              "isRated": true,
              "rating": score,
              "reviewComment": comment,
              "reviewTags": tags,
              "ratedAt": FieldValue.serverTimestamp(),
            })
            .catchError((_) {});
      }
    } catch (_) {
      // Safe fallback for test/offline environments
    }
  }

  void _initGatewayConfig() {
    try {
      if (Firebase.apps.isNotEmpty) {
        PaymentService.instance.getGatewayConfig().then((cfg) {
          if (mounted) {
            setState(() {
              _gatewayConfig = cfg;
              _selectedMethod = "phonepe";
            });
          }
        });
      }
    } catch (_) {
      // Safe fallback for widget tests without Firebase
    }
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    _utrCtrl.dispose();
    super.dispose();
  }

  String _getLocalizedPaymentMode(String method) {
    final m = method.trim().toLowerCase();
    if (m.contains('phonepe')) {
      return 'PhonePe UPI';
    } else if (m.contains('gpay') || m.contains('google')) {
      return 'Google Pay (GPay)';
    } else if (m.contains('cash')) {
      return 'payment_mode_cash'.tr();
    } else {
      return 'Direct P2P UPI';
    }
  }

  Future<void> _launchSelectedUpiApp(double totalAmount) async {
    HapticFeedback.mediumImpact();
    final utrVal = _utrCtrl.text.trim();
    if (_selectedMethod == "phonepe") {
      await PaymentService.instance.launchPhonePe(
        vpa: _artisanUpiId,
        payeeName: _effectiveWorkerName,
        amount: totalAmount,
        note: "WorkGo ${widget.booking.id}",
        transactionRef: utrVal.isNotEmpty ? utrVal : null,
      );
    } else if (_selectedMethod == "gpay") {
      await PaymentService.instance.launchGPay(
        vpa: _artisanUpiId,
        payeeName: _effectiveWorkerName,
        amount: totalAmount,
        note: "WorkGo ${widget.booking.id}",
        transactionRef: utrVal.isNotEmpty ? utrVal : null,
      );
    } else {
      final upiUri = PaymentService.instance.generateUpiUri(
        vpa: _artisanUpiId,
        payeeName: _effectiveWorkerName,
        amount: totalAmount,
        note: "WorkGo ${widget.booking.id}",
        transactionRef: utrVal.isNotEmpty ? utrVal : null,
      );
      await PaymentService.instance.launchUpiIntent(upiUri);
    }
  }

  Future<void> _acknowledgeCustomerPaid(double totalAmount) async {
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    try {
      final utrVal = _utrCtrl.text.trim();
      final isCash = _selectedMethod == "cash";
      final appName = isCash
          ? "CASH"
          : (_selectedMethod == "phonepe"
              ? "PhonePe"
              : (_selectedMethod == "gpay" ? "Google Pay" : "UPI"));

      await BookingService().acknowledgeCustomerPaid(
        widget.booking.id,
        upiReference: isCash ? "CASH" : (utrVal.isNotEmpty ? utrVal : null),
        upiApp: appName,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isCustomerPaidAck = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'payment_marked_paid_toast'.tr(),
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
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
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _checkPaymentStatus() async {
    try {
      final doc = await FirebaseFirestore.instance.collection("bookings").doc(widget.booking.id).get();
      if (doc.exists && doc.data() != null) {
        final b = Booking.fromFirestore(doc);
        if (b.workerReceivedAck == true || b.paymentStatus == PaymentStatus.paid || b.status == BookingStatus.completed) {
          if (mounted) {
            setState(() {
              _isWorkerReceivedAck = true;
              _isPaid = true;
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('artisan_verifying_toast'.tr()),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final baseAmount = widget.booking.amount > 0 ? widget.booking.amount : 450.0;
    final emergencyFee = widget.booking.isEmergency ? 150.0 : 0.0;
    final totalAmount = baseAmount + emergencyFee;
    final coopDividend = 0.0;

    return Scaffold(
      backgroundColor: WorkGoColors.surfaceLight,
      appBar: AppBar(
        title: SafeText(_isPaid ? 'invoice_receipt'.tr() : 'pay_now'.tr()),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WorkGoSpacing.lg),
          child: _isPaid
              ? _buildReceiptView(context, totalAmount, coopDividend)
              : (_isCustomerPaidAck
                  ? _buildAwaitingArtisanCard(totalAmount)
                  : _buildPaymentForm(context, baseAmount, emergencyFee, totalAmount)),
        ),
      ),
    );
  }

  Widget _buildAwaitingArtisanCard(double totalAmount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14F59E0B),
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFEF3C7),
                ),
                child: const Center(
                  child: Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 34),
                ),
              ),
              const SizedBox(height: 16),
              SafeText(
                'awaiting_worker_ack_title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF141416),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              SafeText(
                'awaiting_worker_ack_desc'.tr(args: [
                  "₹${totalAmount.toStringAsFixed(0)}",
                  _effectiveWorkerName,
                ]),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 13,
                  height: 1.45,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: SafeText(
                        'customer_paid_verified_chip'.tr(args: ["₹${totalAmount.toStringAsFixed(0)}"]),
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFF3F4F6), height: 1),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SafeText(
                      'listening_for_artisan_sync'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: WorkGoSpacing.md),
        OutlinedButton.icon(
          onPressed: _checkPaymentStatus,
          icon: const Icon(Icons.sync_rounded, size: 18),
          label: SafeText(
            'check_payment_status'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: WorkGoColors.textPrimary,
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentForm(
    BuildContext context,
    double baseAmount,
    double emergencyFee,
    double totalAmount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. Amount Due Summary Card ──
        GlassCard(
          padding: const EdgeInsets.all(WorkGoSpacing.lg),
          child: Column(
            children: [
              SafeText(
                'total_amount'.tr(),
                style: TextStyle(
                  color: WorkGoColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              SafeText(
                "₹${totalAmount.toStringAsFixed(0)}",
                style: const TextStyle(
                  color: WorkGoColors.accent,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              WorkGoBadge(
                label: widget.booking.serviceType.toLocalizedTrade().toUpperCase(),
                type: BadgeType.accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: WorkGoSpacing.lg),

        // ── 2. Cost Breakdown Card (Zero Platform Commission) ──
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeText(
                'cost_breakdown'.tr(),
                style: const TextStyle(
                  color: WorkGoColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(color: Color(0xFFF0EDE6), height: 24),
              _buildCostRow('service_fee'.tr(), "₹${baseAmount.toStringAsFixed(0)}"),
              if (widget.booking.isEmergency) ...[
                const SizedBox(height: 8),
                _buildCostRow('emergency_rush_fee'.tr(), "+₹150", isHighlight: true),
              ],
              if (widget.booking.isDiagnosticVisit && widget.booking.isFeeCredited) ...[
                const SizedBox(height: 8),
                _buildCostRow(
                  'smart_diagnostic_credit'.tr(),
                  "-₹${widget.booking.diagnosticFee.toStringAsFixed(0)}",
                  isHighlight: true,
                ),
              ],
              const SizedBox(height: 8),
              _buildCostRow(
                'zero_platform_fee_badge'.tr(),
                "₹0 (0%)",
                valueColor: const Color(0xFF059669),
              ),
              const Divider(color: Color(0xFFF0EDE6), height: 24),
              _buildCostRow(
                'total_amount'.tr(),
                "₹${totalAmount.toStringAsFixed(0)}",
                isBold: true,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SafeText(
                        'zero_platform_fee_desc'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
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
        ),
        const SizedBox(height: WorkGoSpacing.lg),

        // ── 3. Direct P2P UPI Payment Selector ──
        SafeText(
          'direct_p2p_upi_title'.tr(),
          style: const TextStyle(
            color: WorkGoColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        SafeText(
          'direct_p2p_upi_sub'.tr(args: [_effectiveWorkerName]),
          style: TextStyle(
            color: WorkGoColors.textSecondary.withValues(alpha: 0.75),
            fontSize: 12,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: WorkGoSpacing.md),

        // Option 1: PhonePe
        _buildPaymentOption(
          id: "phonepe",
          title: "PhonePe",
          subtitle: 'pay_via_phonepe'.tr(),
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF6739B7),
        ),
        const SizedBox(height: WorkGoSpacing.sm),

        // Option 2: Google Pay (GPay)
        _buildPaymentOption(
          id: "gpay",
          title: "Google Pay (GPay)",
          subtitle: 'pay_via_gpay'.tr(),
          icon: Icons.g_mobiledata_rounded,
          color: const Color(0xFF1A73E8),
        ),
        const SizedBox(height: WorkGoSpacing.sm),

        // Option 3: UPI QR & Any UPI App
        _buildPaymentOption(
          id: "upi",
          title: 'pay_via_any_upi'.tr(),
          subtitle: 'scan_upi_qr_sub'.tr(),
          icon: Icons.qr_code_2_rounded,
          color: const Color(0xFF059669),
        ),
        const SizedBox(height: WorkGoSpacing.sm),

        // Option 4: Cash on Delivery (Cash Handover)
        if (_artisanAcceptsCash || _artisanUpiId == "workgo.artisan@upi") ...[
          _buildPaymentOption(
            id: "cash",
            title: 'pay_via_cash_title'.tr(),
            subtitle: 'pay_via_cash_sub'.tr(),
            icon: Icons.payments_rounded,
            color: const Color(0xFFD97706),
          ),
          const SizedBox(height: WorkGoSpacing.sm),
        ],

        // ── 4. Method Contextual Details & Quick Launch Station ──
        if (_selectedMethod == "cash")
          _buildCashHandoverDetailBox(totalAmount)
        else
          _buildDirectUpiDetailBox(totalAmount),

        const SizedBox(height: WorkGoSpacing.xl),

        // ── 5. "I Have Paid" Dual Acknowledgment CTA ──
        WorkGoButton(
          label: _selectedMethod == "cash"
              ? 'i_have_paid_cash_btn'.tr(args: [totalAmount.toStringAsFixed(0)])
              : 'i_have_paid_btn'.tr(args: [totalAmount.toStringAsFixed(0)]),
          icon: Icons.check_circle_rounded,
          variant: WorkGoButtonVariant.primary,
          isLoading: _isProcessing,
          onPressed: () => _acknowledgeCustomerPaid(totalAmount),
        ),
      ],
    );
  }

  Widget _buildCashHandoverDetailBox(double totalAmount) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_rounded, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'cash_handover_instructions'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF92400E),
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
          Text(
            'cash_handover_note'.tr(args: [totalAmount.toStringAsFixed(0), _effectiveWorkerName]),
            style: const TextStyle(color: Color(0xFFB45309), fontSize: 12, height: 1.4),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDirectUpiDetailBox(double totalAmount) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
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
                    const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SafeText(
                        _effectiveWorkerName,
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _artisanUpiId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('vpa_copied_toast'.tr()),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy_rounded, color: Color(0xFF047857), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        _artisanUpiId,
                        style: const TextStyle(color: Color(0xFF047857), fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // One-tap launch button
          ElevatedButton.icon(
            onPressed: () => _launchSelectedUpiApp(totalAmount),
            icon: Icon(
              _selectedMethod == "phonepe"
                  ? Icons.account_balance_wallet_rounded
                  : (_selectedMethod == "gpay" ? Icons.g_mobiledata_rounded : Icons.open_in_new_rounded),
              size: 18,
            ),
            label: Text(
              _selectedMethod == "phonepe"
                  ? "Open PhonePe (₹${totalAmount.toStringAsFixed(0)})"
                  : (_selectedMethod == "gpay"
                      ? "Open Google Pay (₹${totalAmount.toStringAsFixed(0)})"
                      : "Open Any UPI App (₹${totalAmount.toStringAsFixed(0)})"),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedMethod == "phonepe"
                  ? const Color(0xFF6739B7)
                  : (_selectedMethod == "gpay" ? const Color(0xFF1A73E8) : const Color(0xFF059669)),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          // Toggle QR Code Button
          OutlinedButton.icon(
            onPressed: () => setState(() => _showQrCode = !_showQrCode),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF047857),
              side: const BorderSide(color: Color(0xFF059669)),
              minimumSize: const Size(double.infinity, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(_showQrCode ? Icons.expand_less : Icons.qr_code_2_rounded, size: 16),
            label: Text(
              _showQrCode ? "Hide Artisan UPI QR Code" : "Show Artisan UPI QR Code",
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_showQrCode) ...[
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    Image.network(
                      "https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent("upi://pay?pa=$_artisanUpiId&pn=${Uri.encodeComponent(_effectiveWorkerName)}&am=${totalAmount.toStringAsFixed(2)}&cu=INR&tn=WorkGo")}",
                      width: 160,
                      height: 160,
                      errorBuilder: (_, __, ___) => Container(
                        width: 160,
                        height: 160,
                        alignment: Alignment.center,
                        child: const Text("Scan with any UPI App", style: TextStyle(fontSize: 11, color: Colors.black54)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "₹${totalAmount.toStringAsFixed(0)} · $_artisanUpiId",
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Optional UTR Input Field
          TextField(
            controller: _utrCtrl,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'enter_utr_optional'.tr(),
              hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF86EFAC))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedMethod == id;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: isSelected ? color : null,
      onTap: () => setState(() => _selectedMethod = id),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeText(
                  title,
                  style: const TextStyle(
                    color: WorkGoColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SafeText(
                  subtitle,
                  style: TextStyle(
                    color: WorkGoColors.textSecondary.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : const Color(0xFFE5E0D8),
                width: 2,
              ),
              color: isSelected ? color : Colors.transparent,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 14, color: Color(0xFF1C1B2E))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: SafeText(
            label,
            style: TextStyle(
              color: isHighlight
                  ? const Color(0xFFDC2626)
                  : (isBold ? WorkGoColors.textPrimary : WorkGoColors.textSecondary),
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: SafeText(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: isHighlight
                  ? const Color(0xFFDC2626)
                  : (valueColor ?? (isBold ? WorkGoColors.accent : WorkGoColors.textPrimary)),
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptView(BuildContext context, double totalAmount, double coopDividend) {
    final deterministicTxnId = (widget.booking.invoiceId != null && widget.booking.invoiceId!.isNotEmpty)
        ? widget.booking.invoiceId!
        : "TXN-${widget.booking.id.toUpperCase().replaceAll('-', '').padRight(12, '0').substring(0, 12)}";

    final safeBookingId = widget.booking.id.length >= 8
        ? widget.booking.id.substring(0, 8).toUpperCase()
        : widget.booking.id.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Header
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: WorkGoSpacing.lg, vertical: WorkGoSpacing.xl),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.16),
                ),
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: WorkGoSpacing.md),
              SafeText(
                'payment_successful'.tr(),
                style: const TextStyle(
                  color: WorkGoColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              SafeText(
                'booking_id'.tr(args: [safeBookingId]),
                style: TextStyle(
                  color: WorkGoColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: WorkGoSpacing.lg),

        // Receipt Card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SafeText(
                      'official_tax_invoice'.tr(),
                      style: const TextStyle(
                        color: WorkGoColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  WorkGoBadge(label: 'status_paid'.tr(), type: BadgeType.success),
                ],
              ),
              const Divider(color: Color(0xFFF0EDE6), height: 24),
              _buildCostRow('service_category_label'.tr(), widget.booking.serviceType.toLocalizedTrade()),
              const SizedBox(height: 10),
              _buildCostRow(
                'assigned_artisan_label'.tr(),
                !Booking.isGenericArtisanName(_effectiveWorkerName)
                    ? _effectiveWorkerName
                    : MlTranslationService.instance.translateSync(
                        _effectiveWorkerName,
                        context.locale.languageCode,
                      ),
              ),
              const SizedBox(height: 10),
              _buildCostRow(
                'payment_mode_label'.tr(),
                _getLocalizedPaymentMode(_selectedMethod),
              ),
              const SizedBox(height: 10),
              _buildCostRow('transaction_id_label'.tr(), deterministicTxnId),
              const Divider(color: Color(0xFFF0EDE6), height: 24),
              _buildCostRow(
                'amount_paid_label'.tr(),
                "₹${totalAmount.toStringAsFixed(0)}",
                isBold: true,
                valueColor: const Color(0xFFD97706),
              ),
              const SizedBox(height: 14),

              // Zero-Fee Direct P2P Settlement Callout
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.verified_user_rounded,
                        size: 18,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SafeText(
                        'direct_settlement_note'.tr(args: [
                          "₹${totalAmount.toStringAsFixed(0)}",
                          !Booking.isGenericArtisanName(_effectiveWorkerName)
                              ? _effectiveWorkerName
                              : MlTranslationService.instance.translateSync(
                                  _effectiveWorkerName,
                                  context.locale.languageCode,
                                ),
                        ]),
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: WorkGoSpacing.xl),

        // ── Export Invoice PDF ──────────────────────────────────────────────
        _buildExportInvoiceButton(context, totalAmount),
        const SizedBox(height: WorkGoSpacing.md),

        // Rating Section: If already rated, show verified Experience Rated Card; otherwise show CTA
        if (_isRated)
          _buildExperienceRatedCard()
        else
          WorkGoButton(
            label: 'rate_service'.tr(),
            icon: Icons.star_rounded,
            variant: WorkGoButtonVariant.primary,
            onPressed: () async {
              final rated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (ctx) => RatingReviewScreen(
                    booking: widget.booking,
                    workerName: _effectiveWorkerName,
                  ),
                ),
              );
              if (rated == true || mounted) {
                _checkExistingRating();
              }
            },
          ),
      ],
    );
  }

  bool _isExportingPdf = false;

  Widget _buildExportInvoiceButton(BuildContext context, double totalAmount) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isExportingPdf
            ? null
            : () async {
                setState(() => _isExportingPdf = true);
                HapticFeedback.lightImpact();
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('generating_invoice'.tr()),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    backgroundColor: const Color(0xFF1C1B2E),
                  ),
                );
                try {
                  await InvoiceService.exportInvoicePdf(
                    booking: widget.booking,
                    workerName: _effectiveWorkerName,
                    paymentMethod: _selectedMethod,
                    config: _gatewayConfig,
                    context: context,
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('invoice_export_error'.tr(args: ['$e'])),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _isExportingPdf = false);
                }
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1C1B2E),
          side: const BorderSide(color: Color(0xFF1C1B2E), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: Colors.white,
        ),
        icon: _isExportingPdf
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1C1B2E),
                ),
              )
            : const Icon(Icons.picture_as_pdf_rounded, size: 18),
        label: Text(
          'export_invoice_pdf'.tr(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildExperienceRatedCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Verified Icon + Title + Gold Rating Capsule
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF059669),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SafeText(
                        'experience_rated_title'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF141416),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFD97706),
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      "${_ratingValue.toStringAsFixed(1)} / 5.0",
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Star Rating Stars Display
          Row(
            children: List.generate(5, (index) {
              final starFilled = index < _ratingValue.round();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.star_rounded,
                  color: starFilled
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFE5E7EB),
                  size: 22,
                ),
              );
            }),
          ),

          const SizedBox(height: 6),
          Text(
            'experience_rated_subtitle'.tr(),
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          if (_reviewComment.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: Color(0xFFF59E0B), width: 3),
                ),
              ),
              child: Text(
                '"${_reviewComment.trim()}"',
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],

          if (_reviewTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _reviewTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    tag.tr(),
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 14),

          // Edit Rating Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final updated = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (ctx) => RatingReviewScreen(
                      booking: widget.booking.copyWith(
                        isRated: _isRated,
                        rating: _ratingValue,
                        reviewComment: _reviewComment,
                        reviewTags: _reviewTags,
                      ),
                      workerName: widget.workerName,
                    ),
                  ),
                );
                if (updated == true || mounted) {
                  _checkExistingRating();
                }
              },
              icon: const Icon(
                Icons.edit_note_rounded,
                color: Color(0xFFD97706),
                size: 16,
              ),
              label: Text(
                'edit_rating'.tr(),
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFDE68A), width: 1.2),
                backgroundColor: const Color(0xFFFFFBEB),
                padding: const EdgeInsets.symmetric(vertical: 10),
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
