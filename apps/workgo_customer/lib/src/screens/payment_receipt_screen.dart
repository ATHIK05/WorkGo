import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
  String _selectedMethod = "upi";
  bool _isProcessing = false;
  bool _isPaid = false;

  @override
  void initState() {
    super.initState();
    _isPaid = widget.isReceiptOnly == true ||
        widget.booking.paymentStatus == PaymentStatus.paid ||
        (widget.booking.invoiceId != null && widget.booking.invoiceId!.isNotEmpty);
  }

  String _getLocalizedPaymentMode(String method) {
    final m = method.trim().toLowerCase();
    if (m.contains('cash')) {
      return 'payment_mode_cash'.tr();
    } else if (m.contains('card') || m.contains('netbanking')) {
      return 'payment_mode_card'.tr();
    } else {
      return 'payment_mode_upi'.tr();
    }
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 1500));

    final bookingService = BookingService();
    await bookingService.markPaymentComplete(widget.booking.id);

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isPaid = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseAmount = widget.booking.amount > 0 ? widget.booking.amount : 450.0;
    final emergencyFee = widget.booking.isEmergency ? 150.0 : 0.0;
    final totalAmount = baseAmount + emergencyFee;
    final coopDividend = totalAmount * 0.02;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Amount Due Summary Card
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

        // Breakdown Card
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
                _buildCostRow('smart_diagnostic_credit'.tr(), "-₹${widget.booking.diagnosticFee.toStringAsFixed(0)}", isHighlight: true),
              ],
              const SizedBox(height: 8),
              _buildCostRow('platform_gst'.tr(), "₹${(totalAmount * 0.05).toStringAsFixed(0)}"),
              if (widget.booking.isDiagnosticVisit && !widget.booking.isFeeCredited) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'diagnostic_guarantee_note'.tr(),
                          style: const TextStyle(color: Color(0xFF15803D), fontSize: 10.5, fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

        // Payment Method Selector
        SafeText(
          'payment_method'.tr(),
          style: const TextStyle(
            color: WorkGoColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: WorkGoSpacing.sm),
        _buildPaymentOption(
          id: "upi",
          title: 'upi_payment_title'.tr(),
          subtitle: 'upi_payment_sub'.tr(),
          icon: Icons.qr_code_2_rounded,
          color: const Color(0xFF38BDF8),
        ),
        const SizedBox(height: WorkGoSpacing.sm),
        _buildPaymentOption(
          id: "card",
          title: 'card_payment_title'.tr(),
          subtitle: 'card_payment_sub'.tr(),
          icon: Icons.credit_card_rounded,
          color: WorkGoColors.accent,
        ),
        const SizedBox(height: WorkGoSpacing.sm),
        _buildPaymentOption(
          id: "cash",
          title: 'cash_payment_title'.tr(),
          subtitle: 'cash_payment_sub'.tr(),
          icon: Icons.money_rounded,
          color: const Color(0xFF10B981),
        ),
        const SizedBox(height: WorkGoSpacing.xl),

        // Pay Button
        WorkGoButton(
          label: 'pay_via_razorpay'.tr(args: [totalAmount.toStringAsFixed(0)]),
          variant: WorkGoButtonVariant.primary,
          isLoading: _isProcessing,
          onPressed: _processPayment,
        ),
      ],
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
                MlTranslationService.instance.translateSync(
                  widget.workerName,
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
                          MlTranslationService.instance.translateSync(
                            widget.workerName,
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

        // Rate & Review CTA
        WorkGoButton(
          label: 'rate_service'.tr(),
          icon: Icons.star_rounded,
          variant: WorkGoButtonVariant.primary,
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (ctx) => RatingReviewScreen(
                  booking: widget.booking,
                  workerName: widget.workerName,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

