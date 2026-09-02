import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:workgo_core/workgo_core.dart';
import 'rating_review_screen.dart';

class PaymentReceiptScreen extends StatefulWidget {
  const PaymentReceiptScreen({
    super.key,
    required this.booking,
    this.workerName = "Cooperative Artisan",
  });

  final Booking booking;
  final String workerName;

  @override
  State<PaymentReceiptScreen> createState() => _PaymentReceiptScreenState();
}

class _PaymentReceiptScreenState extends State<PaymentReceiptScreen> {
  String _selectedMethod = "upi";
  bool _isProcessing = false;
  bool _isPaid = false;

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
                label: widget.booking.serviceType.toUpperCase(),
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
                "Cost Breakdown",
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
              const SizedBox(height: 8),
              _buildCostRow("Platform / GST (5%)", "₹${(totalAmount * 0.05).toStringAsFixed(0)}"),
              const Divider(color: Color(0xFFF0EDE6), height: 24),
              _buildCostRow(
                'total_amount'.tr(),
                "₹${totalAmount.toStringAsFixed(0)}",
                isBold: true,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.handshake_outlined, size: 14, color: Color(0xFF34D399)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SafeText(
                      'cooperative_dividend_note'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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
          title: "Instant UPI (GPay, PhonePe, Paytm)",
          subtitle: "Zero fee instant transfer",
          icon: Icons.qr_code_2_rounded,
          color: const Color(0xFF38BDF8),
        ),
        const SizedBox(height: WorkGoSpacing.sm),
        _buildPaymentOption(
          id: "card",
          title: "Credit / Debit Card / NetBanking",
          subtitle: "Visa, Mastercard, RuPay",
          icon: Icons.credit_card_rounded,
          color: WorkGoColors.accent,
        ),
        const SizedBox(height: WorkGoSpacing.sm),
        _buildPaymentOption(
          id: "cash",
          title: "Cash to Artisan",
          subtitle: "Pay in cash upon completion",
          icon: Icons.money_rounded,
          color: const Color(0xFF34D399),
        ),
        const SizedBox(height: WorkGoSpacing.xl),

        // Pay Button
        WorkGoButton(
          label: "Pay ₹${totalAmount.toStringAsFixed(0)} via Razorpay",
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
                ),
                SafeText(
                  subtitle,
                  style: TextStyle(
                    color: WorkGoColors.textSecondary.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? color : const Color(0xFFE5E0D8), width: 2), color: isSelected ? color : Colors.transparent), child: isSelected ? const Icon(Icons.check, size: 14, color: Color(0xFF1C1B2E)) : null),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, String value, {bool isHighlight = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SafeText(
          label,
          style: TextStyle(
            color: isHighlight
                ? const Color(0xFFF87171)
                : (isBold ? WorkGoColors.textPrimary : WorkGoColors.textSecondary),
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        SafeText(
          value,
          style: TextStyle(
            color: isHighlight
                ? const Color(0xFFF87171)
                : (isBold ? WorkGoColors.accent : WorkGoColors.textPrimary),
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptView(BuildContext context, double totalAmount, double coopDividend) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Header
        GlassCard(
          padding: const EdgeInsets.all(WorkGoSpacing.xl),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WorkGoColors.success.withValues(alpha: 0.2),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: WorkGoColors.success,
                  size: 56,
                ),
              ),
              const SizedBox(height: WorkGoSpacing.md),
              SafeText(
                'payment_successful'.tr(),
                style: const TextStyle(
                  color: WorkGoColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              SafeText(
                'booking_id'.tr(args: [widget.booking.id.substring(0, 8).toUpperCase()]),
                style: TextStyle(
                  color: WorkGoColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
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
                  const SafeText(
                    "WorkGo Official Tax Invoice",
                    style: TextStyle(
                      color: WorkGoColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  WorkGoBadge(label: "PAID", type: BadgeType.success),
                ],
              ),
              const Divider(color: Color(0xFFF0EDE6), height: 24),
              _buildCostRow("Service Category", widget.booking.serviceType),
              const SizedBox(height: 6),
              _buildCostRow("Assigned Artisan", widget.workerName),
              const SizedBox(height: 6),
              _buildCostRow("Payment Mode", _selectedMethod.toUpperCase()),
              const SizedBox(height: 6),
              _buildCostRow("Transaction ID", "TXN-${DateTime.now().millisecondsSinceEpoch}"),
              const Divider(color: Color(0xFFF0EDE6), height: 24),
              _buildCostRow("Amount Paid", "₹${totalAmount.toStringAsFixed(0)}", isBold: true),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF34D399)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SafeText(
                        "₹${coopDividend.toStringAsFixed(1)} directly contributed to ${widget.workerName}'s Cooperative Welfare & Health Fund.",
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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

