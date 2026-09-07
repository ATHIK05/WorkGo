import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:workgo_core/workgo_core.dart";
import "../admin_theme.dart";

/// Executive Payment Gateway Switchboard & Settlement Hub
/// Allows cooperative administrators to configure 12+ payment providers,
/// toggle between Direct Sovereign UPI (0% fee) and Commercial Gateways,
/// and dynamically adjust platform fee splits.
class PaymentGatewaysHubScreen extends StatefulWidget {
  const PaymentGatewaysHubScreen({super.key});

  @override
  State<PaymentGatewaysHubScreen> createState() => _PaymentGatewaysHubScreenState();
}

class _PaymentGatewaysHubScreenState extends State<PaymentGatewaysHubScreen> {
  final PaymentService _paymentService = PaymentService.instance;

  PaymentGatewayConfig? _config;
  bool _isLoading = true;
  bool _isSaving = false;
  PaymentCategory? _selectedCategoryFilter;

  // Controllers for Sovereign UPI
  final TextEditingController _vpaCtrl = TextEditingController();
  final TextEditingController _payeeCtrl = TextEditingController();

  // Controllers for Invoice Identity (plug-and-play)
  final TextEditingController _invWebsiteCtrl = TextEditingController();
  final TextEditingController _invPhoneCtrl = TextEditingController();
  final TextEditingController _invEmailCtrl = TextEditingController();
  final TextEditingController _invTermsCtrl = TextEditingController();
  final TextEditingController _invSignatoryCtrl = TextEditingController();
  final TextEditingController _invGstCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final cfg = await _paymentService.getGatewayConfig();
    if (mounted) {
      setState(() {
        _config = cfg;
        _vpaCtrl.text = cfg.cooperativeUpiVpa;
        _payeeCtrl.text = cfg.cooperativePayeeName;
        _invWebsiteCtrl.text = cfg.invoiceWebsite ?? '';
        _invPhoneCtrl.text = cfg.invoicePhone ?? '';
        _invEmailCtrl.text = cfg.invoiceEmail ?? '';
        _invTermsCtrl.text = cfg.invoiceTerms ?? '';
        _invSignatoryCtrl.text = cfg.invoiceAuthorisedSignatory ?? '';
        _invGstCtrl.text = cfg.gstPercent != null
            ? cfg.gstPercent!.toStringAsFixed(cfg.gstPercent! == cfg.gstPercent!.roundToDouble() ? 0 : 1)
            : '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfig(PaymentGatewayConfig newConfig) async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    try {
      final gstRaw = _invGstCtrl.text.trim();
      final gstVal = double.tryParse(gstRaw);
      final updated = newConfig.copyWith(
        cooperativeUpiVpa: _vpaCtrl.text.trim(),
        cooperativePayeeName: _payeeCtrl.text.trim(),
        gstPercent: (gstRaw.isEmpty || gstVal == null || gstVal <= 0) ? null : gstVal,
        invoiceWebsite: _invWebsiteCtrl.text.trim().isEmpty ? null : _invWebsiteCtrl.text.trim(),
        invoicePhone: _invPhoneCtrl.text.trim().isEmpty ? null : _invPhoneCtrl.text.trim(),
        invoiceEmail: _invEmailCtrl.text.trim().isEmpty ? null : _invEmailCtrl.text.trim(),
        invoiceTerms: _invTermsCtrl.text.trim().isEmpty ? null : _invTermsCtrl.text.trim(),
        invoiceAuthorisedSignatory: _invSignatoryCtrl.text.trim().isEmpty ? null : _invSignatoryCtrl.text.trim(),
        updatedAt: DateTime.now(),
        updatedBy: "admin@workgo.coop",
      );
      await _paymentService.saveGatewayConfig(updated);
      setState(() => _config = updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Text("Switchboard broadcast live: ${updated.activeMetadata.name} active! ✓"),
              ],
            ),
            backgroundColor: const Color(0xFF0F291E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save switchboard: $e"), backgroundColor: AX.rose),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openProviderCredentialsModal(PaymentProviderMetadata meta) {
    final currentCreds = _config?.credentials[meta.id.name] ?? {};
    final controllers = <String, TextEditingController>{};

    List<String> fieldKeys = [];
    switch (meta.id) {
      case PaymentProviderId.razorpay:
        fieldKeys = ["key_id", "key_secret", "webhook_secret", "route_account_id"];
        break;
      case PaymentProviderId.cashfree:
        fieldKeys = ["app_id", "secret_key", "client_version"];
        break;
      case PaymentProviderId.phonepe:
        fieldKeys = ["merchant_id", "salt_key", "salt_index"];
        break;
      case PaymentProviderId.paytm:
        fieldKeys = ["merchant_id", "merchant_key", "website_name"];
        break;
      case PaymentProviderId.payu:
        fieldKeys = ["merchant_key", "merchant_salt"];
        break;
      case PaymentProviderId.stripe:
        fieldKeys = ["publishable_key", "secret_key", "webhook_secret"];
        break;
      case PaymentProviderId.paypal:
        fieldKeys = ["client_id", "client_secret"];
        break;
      case PaymentProviderId.directUpi:
      case PaymentProviderId.artisanDirectUpi:
      case PaymentProviderId.cashHandover:
      case PaymentProviderId.coopWallet:
      case PaymentProviderId.sandboxMock:
        fieldKeys = ["notes", "settlement_tag"];
        break;
    }

    for (final k in fieldKeys) {
      controllers[k] = TextEditingController(text: currentCreds[k] ?? "");
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: meta.brandColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon, color: meta.brandColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.name, style: AX.heading(fontSize: 16)),
                  Text(meta.category.name.toUpperCase(), style: AX.mono(fontSize: 9.5, color: AX.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.description,
                  style: AX.body(fontSize: 12, color: AX.textSecondary),
                ),
                const SizedBox(height: 16),
                for (final key in fieldKeys) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllers[key],
                      obscureText: key.contains("secret") || key.contains("salt"),
                      style: AX.mono(fontSize: 12.5),
                      decoration: InputDecoration(
                        labelText: key.replaceAll("_", " ").toUpperCase(),
                        labelStyle: AX.mono(fontSize: 10, color: AX.textSecondary),
                        filled: true,
                        fillColor: const Color(0xFFF9F6EE),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('cancel'.trSafe("Cancel"), style: AX.body(color: AX.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final newCredsMap = Map<String, Map<String, String>>.from(_config?.credentials ?? {});
              final updatedForProvider = <String, String>{};
              for (final entry in controllers.entries) {
                updatedForProvider[entry.key] = entry.value.text.trim();
              }
              newCredsMap[meta.id.name] = updatedForProvider;

              final updated = _config!.copyWith(credentials: newCredsMap);
              Navigator.of(ctx).pop();
              _saveConfig(updated);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AX.emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('admin_payments_save_creds'.trSafe("Save Credentials"), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _vpaCtrl.dispose();
    _payeeCtrl.dispose();
    _invWebsiteCtrl.dispose();
    _invPhoneCtrl.dispose();
    _invEmailCtrl.dispose();
    _invTermsCtrl.dispose();
    _invSignatoryCtrl.dispose();
    _invGstCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _config == null) {
      return const Center(child: CircularProgressIndicator(color: AX.emerald));
    }

    final cfg = _config!;
    final activeMeta = cfg.activeMetadata;

    // Filter providers
    final catalog = _selectedCategoryFilter == null
        ? PaymentProviderMetadata.catalog
        : PaymentProviderMetadata.catalog.where((m) => m.category == _selectedCategoryFilter).toList();

    return Scaffold(
      backgroundColor: AX.bgCosmic,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Top Executive Cockpit Banner ──
            _buildExecutiveCockpitHeader(cfg, activeMeta),
            const SizedBox(height: 24),

            // ── 2. Platform Fee & Welfare Split Simulator ──
            _buildSplitEngineCard(cfg),
            const SizedBox(height: 24),

            // ── 3. Hybrid Routing & Sovereign VPA Settings ──
            _buildSovereignSettingsCard(cfg),
            const SizedBox(height: 24),

            // ── 4. Invoice Identity (Plug-and-Play) ──
            _buildInvoiceIdentityCard(cfg),
            const SizedBox(height: 24),

            // ── 5. Provider Catalog Switchboard ──
            _buildProviderCatalogSection(catalog, cfg),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveCockpitHeader(PaymentGatewayConfig cfg, PaymentProviderMetadata activeMeta) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AX.divider),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: activeMeta.brandColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(activeMeta.icon, color: activeMeta.brandColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'admin_payments_title'.trSafe("Cooperative Payment Switchboard & Settlement Hub"),
                        style: AX.display(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'admin_payments_subtitle'.trSafe("Direct Sovereign UPI (0% fee) & platform governance settlement"),
                        style: AX.body(fontSize: 12, color: AX.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              // Live Mode Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cfg.isLiveMode ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cfg.isLiveMode ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cfg.isLiveMode ? Icons.cloud_done_rounded : Icons.science_rounded,
                      color: cfg.isLiveMode ? const Color(0xFF047857) : const Color(0xFFB45309),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cfg.isLiveMode
                          ? 'admin_payments_production_live'.trSafe("PRODUCTION LIVE")
                          : 'admin_payments_sandbox_mode'.trSafe("SANDBOX TEST MODE"),
                      style: AX.mono(
                        fontSize: 10.5,
                        color: cfg.isLiveMode ? const Color(0xFF047857) : const Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: cfg.isLiveMode,
                      activeTrackColor: const Color(0xFF10B981),
                      onChanged: (val) {
                        _saveConfig(cfg.copyWith(isLiveMode: val));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: AX.divider),
          // Quick Status Indicators
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMetricPill('admin_payments_primary_provider'.trSafe("PRIMARY PROVIDER"), activeMeta.name, activeMeta.brandColor, activeMeta.icon),
              _buildMetricPill('admin_payments_platform_comm'.trSafe("PLATFORM COMMISSION"), "${cfg.platformFeePercent}%", const Color(0xFF3B82F6), Icons.pie_chart_rounded),
              _buildMetricPill('admin_payments_welfare_contrib'.trSafe("WELFARE CONTRIBUTION"), "${cfg.welfareFundPercent}%", const Color(0xFF8B5CF6), Icons.health_and_safety_rounded),
              _buildMetricPill(
                'admin_payments_sovereign_fallback'.trSafe("SOVEREIGN UPI FALLBACK"),
                cfg.allowDirectUpiFallback ? 'admin_payments_enabled'.trSafe("ENABLED") : 'admin_payments_disabled'.trSafe("DISABLED"),
                cfg.allowDirectUpiFallback ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                Icons.alt_route_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AX.mono(fontSize: 8.5, color: color)),
              Text(value, style: AX.heading(fontSize: 12, color: AX.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSplitEngineCard(PaymentGatewayConfig cfg) {
    const sampleJob = 500.0;
    final platformShare = (sampleJob * (cfg.platformFeePercent / 100.0));
    final welfareShare = (sampleJob * (cfg.welfareFundPercent / 100.0));
    final artisanTakeHome = sampleJob - platformShare - welfareShare;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AX.divider),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_rounded, color: AX.amberDark, size: 20),
              const SizedBox(width: 8),
              Text('admin_payments_split_engine_title'.trSafe("Platform Fee & Welfare Split Engine"), style: AX.heading(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Configure the percentage deductions automatically calculated on all customer payments.",
            style: AX.body(fontSize: 12, color: AX.textSecondary),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sliders Column
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Platform Fee Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('admin_payments_coop_fee'.trSafe("Cooperative Platform Fee"), style: AX.heading(fontSize: 13)),
                        Text("${cfg.platformFeePercent.toStringAsFixed(1)}%", style: AX.mono(fontSize: 13, color: const Color(0xFF3B82F6))),
                      ],
                    ),
                    Slider(
                      value: cfg.platformFeePercent,
                      min: 0.0,
                      max: 15.0,
                      divisions: 30,
                      activeColor: const Color(0xFF3B82F6),
                      onChanged: (val) {
                        setState(() {
                          _config = cfg.copyWith(platformFeePercent: val);
                        });
                      },
                      onChangeEnd: (val) {
                        _saveConfig(cfg.copyWith(platformFeePercent: val));
                      },
                    ),
                    const SizedBox(height: 12),
                    // Welfare Fund Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('admin_payments_welfare_fund'.trSafe("Artisan Welfare Fund (Medical & Safety)"), style: AX.heading(fontSize: 13)),
                        Text("${cfg.welfareFundPercent.toStringAsFixed(1)}%", style: AX.mono(fontSize: 13, color: const Color(0xFF8B5CF6))),
                      ],
                    ),
                    Slider(
                      value: cfg.welfareFundPercent,
                      min: 0.0,
                      max: 5.0,
                      divisions: 20,
                      activeColor: const Color(0xFF8B5CF6),
                      onChanged: (val) {
                        setState(() {
                          _config = cfg.copyWith(welfareFundPercent: val);
                        });
                      },
                      onChangeEnd: (val) {
                        _saveConfig(cfg.copyWith(welfareFundPercent: val));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Live Rupee Simulator Box
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F6EE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AX.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('admin_payments_job_sim'.trSafe("LIVE JOB SIMULATION"), style: AX.mono(fontSize: 9.5, color: AX.textSecondary)),
                          Text('admin_payments_sample'.trSafe("SAMPLE ₹500"), style: AX.mono(fontSize: 9.5, color: AX.textPrimary)),
                        ],
                      ),
                      const Divider(height: 16, color: AX.divider),
                      _buildSimRow('admin_payments_artisan_takehome'.trSafe("Artisan Net Earnings (Direct Cash/UPI):"), "₹${artisanTakeHome.toStringAsFixed(1)}", const Color(0xFF059669), isBold: true),
                      const SizedBox(height: 6),
                      _buildSimRow("${'admin_payments_coop_fee'.trSafe('Platform Operations')} (${cfg.platformFeePercent}%):", "₹${platformShare.toStringAsFixed(1)}", const Color(0xFF3B82F6)),
                      const SizedBox(height: 6),
                      _buildSimRow("${'admin_nav_welfare'.trSafe('Welfare Fund')} (${cfg.welfareFundPercent}%):", "₹${welfareShare.toStringAsFixed(1)}", const Color(0xFF8B5CF6)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AX.body(fontSize: 11.5, color: AX.textPrimary)),
        Text(value, style: AX.mono(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildSovereignSettingsCard(PaymentGatewayConfig cfg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AX.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 20),
              const SizedBox(width: 8),
              Text('admin_payments_sovereign_policies'.trSafe("Direct Sovereign UPI & Cash Handover Policies"), style: AX.heading(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vpaCtrl,
                  style: AX.mono(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'admin_payments_upi_vpa'.trSafe("COOPERATIVE UPI VPA"),
                    labelStyle: AX.mono(fontSize: 10, color: AX.textSecondary),
                    filled: true,
                    fillColor: const Color(0xFFF9F6EE),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _payeeCtrl,
                  style: AX.body(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'admin_payments_payee_name'.trSafe("REGISTERED PAYEE NAME"),
                    labelStyle: AX.mono(fontSize: 10, color: AX.textSecondary),
                    filled: true,
                    fillColor: const Color(0xFFF9F6EE),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveConfig(cfg),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.save_rounded, size: 16),
                label: Text('admin_payments_update_vpa'.trSafe("Update VPA"), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Fallback checkboxes
          Row(
            children: [
              Checkbox(
                value: cfg.allowDirectUpiFallback,
                activeColor: const Color(0xFF059669),
                onChanged: (val) {
                  _saveConfig(cfg.copyWith(allowDirectUpiFallback: val ?? true));
                },
              ),
              Text('admin_payments_allow_sovereign'.trSafe("Allow Direct Sovereign UPI alongside commercial gateways"), style: AX.body(fontSize: 12.5)),
              const SizedBox(width: 24),
              Checkbox(
                value: cfg.allowCashHandover,
                activeColor: const Color(0xFF059669),
                onChanged: (val) {
                  _saveConfig(cfg.copyWith(allowCashHandover: val ?? true));
                },
              ),
              Text('admin_payments_allow_cod'.trSafe("Allow Cash on Delivery (Artisan Handover)"), style: AX.body(fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceIdentityCard(PaymentGatewayConfig cfg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AX.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('admin_payments_invoice_identity'.trSafe("Invoice Identity"), style: AX.heading(fontSize: 15)),
                    Text(
                      "These fields appear on customer & worker invoices. Leave blank to omit the section.",
                      style: AX.body(fontSize: 11.5, color: AX.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Row 1: Website · Phone · Email ───────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _invField(
                  ctrl: _invWebsiteCtrl,
                  label: 'admin_payments_website'.trSafe("WEBSITE"),
                  hint: "e.g. workgo.in",
                  icon: Icons.language_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _invField(
                  ctrl: _invPhoneCtrl,
                  label: 'admin_payments_helpline'.trSafe("HELPLINE / PHONE"),
                  hint: "e.g. 1800-419-WORK",
                  icon: Icons.call_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _invField(
                  ctrl: _invEmailCtrl,
                  label: 'admin_payments_support_email'.trSafe("SUPPORT EMAIL"),
                  hint: "e.g. support@workgo.in",
                  icon: Icons.alternate_email_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Row 2: Signatory · GST % ─────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _invField(
                  ctrl: _invSignatoryCtrl,
                  label: 'admin_payments_signatory'.trSafe("AUTHORISED SIGNATORY NAME"),
                  hint: "e.g. WorkGo Trust (leave empty to omit)",
                  icon: Icons.verified_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: _invField(
                  ctrl: _invGstCtrl,
                  label: 'admin_payments_gst_rate'.trSafe("GST RATE (%)"),
                  hint: "e.g. 18.0 (leave empty/0 to omit)",
                  icon: Icons.percent_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Row 3: Terms ─────────────────────────────────────────────────
          TextField(
            controller: _invTermsCtrl,
            minLines: 2,
            maxLines: 4,
            style: AX.body(fontSize: 12.5),
            decoration: InputDecoration(
              labelText: 'admin_payments_invoice_terms'.trSafe("INVOICE TERMS"),
              hintText:
                  "e.g. Payment is final upon service completion. Governed by WorkGo Cooperative Terms. (Leave empty to omit)",
              hintStyle: AX.body(fontSize: 11, color: AX.textSecondary),
              labelStyle: AX.mono(fontSize: 10, color: AX.textSecondary),
              filled: true,
              fillColor: const Color(0xFFF9F6EE),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),

          // ── Live Preview strip ───────────────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([
              _invWebsiteCtrl,
              _invPhoneCtrl,
              _invEmailCtrl,
              _invSignatoryCtrl,
              _invGstCtrl,
              _invTermsCtrl,
            ]),
            builder: (context, _) {
              final contactParts = [
                _invWebsiteCtrl.text.trim(),
                _invPhoneCtrl.text.trim(),
                _invEmailCtrl.text.trim(),
              ].where((s) => s.isNotEmpty).toList();

              final signatoryText = _invSignatoryCtrl.text.trim();
              final gstText = _invGstCtrl.text.trim();
              final gstVal = double.tryParse(gstText);
              final termsText = _invTermsCtrl.text.trim();

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.preview_rounded, size: 15, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Text(
                          "LIVE INVOICE PLUG-AND-PLAY STATUS",
                          style: AX.mono(fontSize: 10, color: const Color(0xFF92400E)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        _statusPill("Footer Contact", contactParts.isEmpty ? "OMITTED" : contactParts.join(" | "), contactParts.isNotEmpty),
                        _statusPill("Digital Sign", signatoryText.isEmpty ? "OMITTED" : "✓ $signatoryText", signatoryText.isNotEmpty),
                        _statusPill("GST %", (gstText.isEmpty || gstVal == null || gstVal <= 0) ? "OMITTED" : "$gstText%", gstVal != null && gstVal > 0),
                        _statusPill("Terms", termsText.isEmpty ? "OMITTED" : "CONFIGURED", termsText.isNotEmpty),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── Save button ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _saveConfig(cfg),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF1C1B2E),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1C1B2E)),
                    )
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(
                _isSaving ? "Saving..." : "Save Invoice Identity",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, String value, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label: ", style: AX.mono(fontSize: 10, color: AX.textSecondary)),
          Text(
            value,
            style: AX.mono(
              fontSize: 10,
              color: isActive ? const Color(0xFF047857) : AX.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact single-line field helper for Invoice Identity section.
  Widget _invField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: ctrl,
      style: AX.body(fontSize: 12.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: AX.body(fontSize: 11, color: AX.textSecondary),
        labelStyle: AX.mono(fontSize: 10, color: AX.textSecondary),
        prefixIcon: Icon(icon, size: 16, color: AX.textSecondary),
        filled: true,
        fillColor: const Color(0xFFF9F6EE),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildProviderCatalogSection(List<PaymentProviderMetadata> catalog, PaymentGatewayConfig cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('admin_payments_registry_title'.trSafe("Payment Provider Registry (12 Rails)"), style: AX.display(fontSize: 17)),
                Text('admin_payments_registry_sub'.trSafe("Select an active provider or configure credentials for automated escrow"), style: AX.body(fontSize: 12)),
              ],
            ),
            // Category Filter Pills
            Wrap(
              spacing: 6,
              children: [
                _buildCategoryFilterChip(null, 'admin_payments_tab_all'.trSafe("All (12)")),
                _buildCategoryFilterChip(PaymentCategory.sovereignZeroFee, 'admin_payments_tab_sovereign'.trSafe("Sovereign (0% Fee)")),
                _buildCategoryFilterChip(PaymentCategory.indianGateway, 'admin_payments_tab_indian'.trSafe("Indian Gateways")),
                _buildCategoryFilterChip(PaymentCategory.globalGateway, 'admin_payments_tab_global'.trSafe("Global")),
                _buildCategoryFilterChip(PaymentCategory.cooperativeWallet, 'admin_nav_welfare'.trSafe("Wallet")),
                _buildCategoryFilterChip(PaymentCategory.developerSandbox, 'admin_payments_tab_sandbox'.trSafe("Sandbox")),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.55,
          ),
          itemCount: catalog.length,
          itemBuilder: (context, idx) {
            final meta = catalog[idx];
            final isActive = cfg.activePrimaryProvider == meta.id;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? meta.brandColor : AX.divider,
                  width: isActive ? 2.0 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isActive ? meta.brandColor.withValues(alpha: 0.12) : const Color(0x06000000),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: meta.brandColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(meta.icon, color: meta.brandColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(meta.name, style: AX.heading(fontSize: 13.5)),
                              Text(meta.feeDescription, style: AX.mono(fontSize: 9, color: AX.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: meta.brandColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('admin_payments_active_badge'.trSafe("ACTIVE"), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                  // Description
                  Text(
                    meta.description,
                    style: AX.body(fontSize: 11, color: AX.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Actions Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Rails tags
                      Flexible(
                        child: Text(
                          meta.supportedRails.join(" · "),
                          style: AX.mono(fontSize: 9.5, color: AX.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          if (meta.requiresCredentials)
                            IconButton(
                              tooltip: 'admin_payments_config_btn'.trSafe("Configure Credentials"),
                              splashRadius: 16,
                              icon: const Icon(Icons.settings_rounded, size: 16, color: AX.textSecondary),
                              onPressed: () => _openProviderCredentialsModal(meta),
                            ),
                          ElevatedButton(
                            onPressed: isActive
                                ? null
                                : () {
                                    _saveConfig(cfg.copyWith(activePrimaryProvider: meta.id));
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isActive ? const Color(0xFFE5E7EB) : meta.brandColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              minimumSize: const Size(0, 28),
                            ),
                            child: Text(
                              isActive ? 'admin_payments_active_badge'.trSafe("ACTIVE") : 'admin_payments_switch_btn'.trSafe("ACTIVATE"),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryFilterChip(PaymentCategory? cat, String label) {
    final isSelected = _selectedCategoryFilter == cat;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      selected: isSelected,
      selectedColor: AX.emerald.withValues(alpha: 0.2),
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? AX.emerald : AX.divider),
      onSelected: (_) {
        setState(() => _selectedCategoryFilter = cat);
      },
    );
  }
}
