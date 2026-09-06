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
  String _selectedMethod = "upi";
  bool _isProcessing = false;
  bool _isPaid = false;
  bool _showQrCode = false;

  bool _isRated = false;
  double _ratingValue = 5.0;
  String _reviewComment = "";
  List<String> _reviewTags = [];

  final TextEditingController _utrCtrl = TextEditingController();
  late String _effectiveWorkerName;

  @override
  void initState() {
    super.initState();
    _isPaid = widget.booking.paymentStatus == PaymentStatus.paid;

    _effectiveWorkerName = (widget.booking.genuineArtisanName ??
        (!Booking.isGenericArtisanName(widget.workerName) ? widget.workerName : "")).trim();
    if (_effectiveWorkerName.isEmpty) {
      _effectiveWorkerName = widget.workerName;
    }
    _resolveArtisanName();

    _isRated = widget.booking.isRated || widget.booking.rating != null;
    if (_isRated) {
      _ratingValue = widget.booking.rating ?? 5.0;
      _reviewComment = widget.booking.reviewComment ?? "";
      _reviewTags = List<String>.from(widget.booking.reviewTags);
    }

    _initGatewayConfig();
    _checkExistingRating();
  }

  Future<void> _resolveArtisanName() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final wId = widget.booking.workerId;
      if (wId == null || wId.isEmpty) return;

      // 1. Query 'workers' collection
      final workerDoc = await FirebaseFirestore.instance.collection("workers").doc(wId).get();
      if (workerDoc.exists) {
        final data = workerDoc.data() ?? {};
        final realName = (data["name"] ?? data["displayName"] ?? data["artisanName"] ?? "").toString().trim();
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
              // If active primary is a gateway and not direct upi, preselect gateway
              if (cfg.activeMetadata.category == PaymentCategory.indianGateway ||
                  cfg.activeMetadata.category == PaymentCategory.globalGateway) {
                _selectedMethod = "gateway";
              } else if (cfg.activePrimaryProvider == PaymentProviderId.cashHandover) {
                _selectedMethod = "cash";
              } else if (cfg.activePrimaryProvider == PaymentProviderId.sandboxMock) {
                _selectedMethod = "test";
              } else {
                _selectedMethod = "upi";
              }
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
    _utrCtrl.dispose();
    super.dispose();
  }

  String _getLocalizedPaymentMode(String method) {
    final m = method.trim().toLowerCase();
    if (m.contains('cash')) {
      return 'payment_mode_cash'.tr();
    } else if (m.contains('card') || m.contains('netbanking') || m.contains('gateway')) {
      return 'payment_mode_card'.tr();
    } else {
      return 'payment_mode_upi'.tr();
    }
  }

  Future<void> _processPayment(double totalAmount) async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final cfg = _gatewayConfig;
      final platformFee = totalAmount * (cfg.platformFeePercent / 100.0);
      final welfareFund = totalAmount * (cfg.welfareFundPercent / 100.0);
      final utrVal = _utrCtrl.text.trim();

      // If user selected Direct UPI, launch native UPI app chooser first if available
      if (_selectedMethod == "upi") {
        final upiUri = PaymentService.instance.generateUpiUri(
          vpa: cfg.cooperativeUpiVpa,
          payeeName: cfg.cooperativePayeeName,
          amount: totalAmount,
          note: "WorkGo ${widget.booking.id}",
          transactionRef: utrVal.isNotEmpty ? utrVal : null,
        );

        // Attempt launching external UPI application
        await PaymentService.instance.launchUpiIntent(upiUri);
        // Short delay for user context switch / confirmation
        await Future.delayed(const Duration(milliseconds: 800));
      } else {
        // Standard simulated processing delay
        await Future.delayed(const Duration(milliseconds: 1400));
      }

      // Record settlement in Firestore
      await PaymentService.instance.recordPaymentSettlement(
        bookingId: widget.booking.id,
        paymentMethod: _selectedMethod,
        providerId: cfg.activePrimaryProvider,
        referenceId: utrVal.isNotEmpty ? utrVal : null,
        platformFee: platformFee,
        welfareFund: welfareFund,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isPaid = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment error: $e"), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseAmount = widget.booking.amount > 0 ? widget.booking.amount : 450.0;
    final emergencyFee = widget.booking.isEmergency ? 150.0 : 0.0;
    final totalAmount = baseAmount + emergencyFee;
    final coopDividend = totalAmount * (_gatewayConfig.welfareFundPercent / 100.0);

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
              : _buildPaymentForm(context, baseAmount, emergencyFee, totalAmount),
        ),
      ),
    );
  }

  Widget _buildPaymentForm(
    BuildContext context,
    double baseAmount,
    double emergencyFee,
    double totalAmount,
  ) {
    final cfg = _gatewayConfig;
    final activeMeta = cfg.activeMetadata;
    final isGatewayActive = cfg.isProviderConfigured &&
        activeMeta.category != PaymentCategory.sovereignZeroFee &&
        cfg.activePrimaryProvider != PaymentProviderId.sandboxMock;

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
              ),
              const SizedBox(height: 4),
              SafeText(
                "₹${totalAmount.toStringAsFixed(0)}",
                style: const TextStyle(
                  color: WorkGoColors.accent,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
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

        // ── 2. Cost Breakdown Card ──
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
              _buildCostRow('platform_gst'.tr(), "₹${(totalAmount * (cfg.platformFeePercent / 100.0)).toStringAsFixed(0)}"),
              const Divider(color: Color(0xFFF0EDE6), height: 24),
              _buildCostRow(
                'total_amount'.tr(),
                "₹${totalAmount.toStringAsFixed(0)}",
                isBold: true,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.handshake_outlined, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SafeText(
                      'cooperative_dividend_note'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
        const SizedBox(height: WorkGoSpacing.lg),

        // ── 3. Dynamic Payment Method Selector ──
        SafeText(
          'payment_method'.tr(),
          style: const TextStyle(
            color: WorkGoColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: WorkGoSpacing.sm),

        // Option A: Direct Sovereign UPI (Always visible if active or fallback allowed)
        if (cfg.activePrimaryProvider == PaymentProviderId.directUpi ||
            cfg.activePrimaryProvider == PaymentProviderId.artisanDirectUpi ||
            cfg.allowDirectUpiFallback) ...[
          _buildPaymentOption(
            id: "upi",
            title: 'upi_payment_title'.tr(),
            subtitle: 'upi_payment_sub'.tr(),
            icon: Icons.qr_code_2_rounded,
            color: const Color(0xFF059669),
          ),
          const SizedBox(height: WorkGoSpacing.sm),
        ],

        // Option B: Active Commercial Gateway (Razorpay, Cashfree, PhonePe, Stripe)
        if (isGatewayActive) ...[
          _buildPaymentOption(
            id: "gateway",
            title: activeMeta.name,
            subtitle: activeMeta.feeDescription,
            icon: activeMeta.icon,
            color: activeMeta.brandColor,
          ),
          const SizedBox(height: WorkGoSpacing.sm),
        ],

        // Option C: Cash on Delivery (Artisan Handover)
        if (cfg.allowCashHandover) ...[
          _buildPaymentOption(
            id: "cash",
            title: 'cash_payment_title'.tr(),
            subtitle: 'cash_payment_sub'.tr(),
            icon: Icons.payments_rounded,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: WorkGoSpacing.sm),
        ],

        // Option D: Sandbox Test Mode (Visible when not in live mode or provider is sandboxMock)
        if (!cfg.isLiveMode || cfg.activePrimaryProvider == PaymentProviderId.sandboxMock) ...[
          _buildPaymentOption(
            id: "test",
            title: "Interactive Sandbox (Test Mode)",
            subtitle: "Simulated 1-Tap Instant Settle",
            icon: Icons.science_rounded,
            color: const Color(0xFFEA580C),
          ),
          const SizedBox(height: WorkGoSpacing.sm),
        ],

        // ── 4. Method Contextual Details Box ──
        if (_selectedMethod == "upi")
          _buildDirectUpiDetailBox(cfg, totalAmount)
        else if (_selectedMethod == "cash")
          _buildCashHandoverDetailBox(totalAmount)
        else if (_selectedMethod == "test")
          _buildSandboxDetailBox(),

        const SizedBox(height: WorkGoSpacing.xl),

        // ── 5. Dynamic Pay Button ──
        WorkGoButton(
          label: _getDynamicButtonLabel(totalAmount, activeMeta.name),
          variant: WorkGoButtonVariant.primary,
          isLoading: _isProcessing,
          onPressed: () => _processPayment(totalAmount),
        ),
      ],
    );
  }

  String _getDynamicButtonLabel(double amount, String gatewayName) {
    final amtStr = amount.toStringAsFixed(0);
    switch (_selectedMethod) {
      case "cash":
        return 'pay_via_cash_handover'.tr(args: [amtStr]);
      case "gateway":
        return 'pay_via_gateway_dynamic'.tr(args: [amtStr, gatewayName]);
      case "test":
        return 'pay_via_sandbox_test'.tr(args: [amtStr]);
      case "upi":
      default:
        return 'pay_via_upi_app'.tr(args: [amtStr]);
    }
  }

  Widget _buildDirectUpiDetailBox(PaymentGatewayConfig cfg, double totalAmount) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
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
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SafeText(
                        'sovereign_upi_active'.tr(),
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
                  Clipboard.setData(ClipboardData(text: cfg.cooperativeUpiVpa));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('vpa_copied_toast'.tr()),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                        cfg.cooperativeUpiVpa,
                        style: const TextStyle(color: Color(0xFF047857), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'scan_upi_qr_sub'.tr(),
            style: const TextStyle(color: Color(0xFF047857), fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          // App Quick Launchers
          Row(
            children: [
              _buildAppTile("GPay", const Color(0xFF4285F4), cfg, totalAmount),
              const SizedBox(width: 8),
              _buildAppTile("PhonePe", const Color(0xFF6739B7), cfg, totalAmount),
              const SizedBox(width: 8),
              _buildAppTile("Paytm", const Color(0xFF002E6E), cfg, totalAmount),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showQrCode = !_showQrCode),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF047857),
                    side: const BorderSide(color: Color(0xFF059669)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(_showQrCode ? Icons.expand_less : Icons.qr_code, size: 14),
                  label: Text(_showQrCode ? "Hide QR" : "QR Code", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
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
                      "https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent("upi://pay?pa=${cfg.cooperativeUpiVpa}&pn=${Uri.encodeComponent(cfg.cooperativePayeeName)}&am=${totalAmount.toStringAsFixed(2)}&cu=INR&tn=WorkGo")}",
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
                      "₹${totalAmount.toStringAsFixed(0)} · ${cfg.cooperativeUpiVpa}",
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
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

  Widget _buildAppTile(String name, Color color, PaymentGatewayConfig cfg, double totalAmount) {
    return InkWell(
      onTap: () async {
        final upiUri = PaymentService.instance.generateUpiUri(
          vpa: cfg.cooperativeUpiVpa,
          payeeName: cfg.cooperativePayeeName,
          amount: totalAmount,
          note: "WorkGo ${widget.booking.id}",
        );
        await PaymentService.instance.launchUpiIntent(upiUri);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          name,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildCashHandoverDetailBox(double totalAmount) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.handshake_rounded, color: Color(0xFF10B981), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Cash On Delivery Handshake",
                  style: TextStyle(color: Color(0xFF065F46), fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'cash_voucher_instruction'.tr(args: [totalAmount.toStringAsFixed(0)]),
                  style: const TextStyle(color: Color(0xFF047857), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSandboxDetailBox() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_rounded, color: Color(0xFFEA580C), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'demo_mode_active_badge'.tr(),
                  style: const TextStyle(color: Color(0xFF9A3412), fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Simulates instant bank settlement and generates an authentic C2PA invoice without actual charges.",
                  style: TextStyle(color: Color(0xFFC2410C), fontSize: 11),
                ),
              ],
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

              // Cooperative Worker Welfare Fund Callout
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
                        'coop_welfare_contribution'.tr(args: [
                          coopDividend.toStringAsFixed(1),
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
