import "package:flutter/material.dart";

/// Categories of payment providers supported by the WorkGo ecosystem.
enum PaymentCategory {
  sovereignZeroFee,
  indianGateway,
  globalGateway,
  cooperativeWallet,
  developerSandbox,
}

/// Identifiers for all supported payment providers.
enum PaymentProviderId {
  directUpi,
  artisanDirectUpi,
  cashHandover,
  razorpay,
  cashfree,
  phonepe,
  paytm,
  payu,
  stripe,
  paypal,
  coopWallet,
  sandboxMock,
}

/// Metadata descriptor for a payment provider in the catalog.
class PaymentProviderMetadata {
  final PaymentProviderId id;
  final String name;
  final String shortCode;
  final PaymentCategory category;
  final String feeDescription;
  final IconData icon;
  final Color brandColor;
  final bool requiresCredentials;
  final bool supportsSplitEscrow;
  final List<String> supportedRails;
  final String description;

  const PaymentProviderMetadata({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.category,
    required this.feeDescription,
    required this.icon,
    required this.brandColor,
    required this.requiresCredentials,
    required this.supportsSplitEscrow,
    required this.supportedRails,
    required this.description,
  });

  static const List<PaymentProviderMetadata> catalog = [
    // 1. Sovereign Zero-Fee
    PaymentProviderMetadata(
      id: PaymentProviderId.directUpi,
      name: "Direct Sovereign UPI",
      shortCode: "UPI-NPCI",
      category: PaymentCategory.sovereignZeroFee,
      feeDescription: "0% Platform Fee · Direct Bank",
      icon: Icons.qr_code_2_rounded,
      brandColor: Color(0xFF059669),
      requiresCredentials: false,
      supportsSplitEscrow: false,
      supportedRails: ["GPay", "PhonePe", "Paytm", "BHIM", "Cred", "QR"],
      description: "NPCI open protocol. Direct bank-to-bank transfer to cooperative VPA with zero merchant fees.",
    ),
    PaymentProviderMetadata(
      id: PaymentProviderId.artisanDirectUpi,
      name: "Artisan Direct VPA",
      shortCode: "P2P-UPI",
      category: PaymentCategory.sovereignZeroFee,
      feeDescription: "0% Fee · Direct to Worker",
      icon: Icons.person_pin_rounded,
      brandColor: Color(0xFF10B981),
      requiresCredentials: false,
      supportsSplitEscrow: false,
      supportedRails: ["Artisan UPI VPA", "Direct QR"],
      description: "Decentralized P2P payment directly to the assigned artisan's verified KYC UPI handle.",
    ),
    PaymentProviderMetadata(
      id: PaymentProviderId.cashHandover,
      name: "Cash on Delivery",
      shortCode: "COD",
      category: PaymentCategory.sovereignZeroFee,
      feeDescription: "0% Fee · Physical INR",
      icon: Icons.payments_rounded,
      brandColor: Color(0xFF16A34A),
      requiresCredentials: false,
      supportsSplitEscrow: false,
      supportedRails: ["Physical Cash", "On-Site Voucher"],
      description: "Traditional rupee handover directly to artisan upon job completion with digital voucher verification.",
    ),

    // 2. Indian Commercial Gateways
    PaymentProviderMetadata(
      id: PaymentProviderId.razorpay,
      name: "Razorpay Standard & Route",
      shortCode: "RZP",
      category: PaymentCategory.indianGateway,
      feeDescription: "1.9% + GST · Split Escrow",
      icon: Icons.credit_card_rounded,
      brandColor: Color(0xFF0284C7),
      requiresCredentials: true,
      supportsSplitEscrow: true,
      supportedRails: ["UPI", "Credit/Debit", "NetBanking", "Wallets"],
      description: "Full-stack Indian gateway with automated marketplace split routing to artisan accounts.",
    ),
    PaymentProviderMetadata(
      id: PaymentProviderId.cashfree,
      name: "Cashfree Payments",
      shortCode: "CF",
      category: PaymentCategory.indianGateway,
      feeDescription: "1.9% + GST · Easy Split",
      icon: Icons.account_balance_rounded,
      brandColor: Color(0xFF7C3AED),
      requiresCredentials: true,
      supportsSplitEscrow: true,
      supportedRails: ["UPI", "Cards", "NetBanking", "PayLater"],
      description: "Leading marketplace payments suite with automated split settlement and instant vendor payouts.",
    ),
    PaymentProviderMetadata(
      id: PaymentProviderId.phonepe,
      name: "PhonePe PG Enterprise",
      shortCode: "PPE",
      category: PaymentCategory.indianGateway,
      feeDescription: "1.8% + GST · UPI Switch",
      icon: Icons.mobile_friendly_rounded,
      brandColor: Color(0xFF673AB7),
      requiresCredentials: true,
      supportsSplitEscrow: true,
      supportedRails: ["PhonePe Switch", "UPI Intent", "Cards"],
      description: "High-throughput payment gateway by India's largest consumer UPI platform.",
    ),
    PaymentProviderMetadata(
      id: PaymentProviderId.paytm,
      name: "Paytm All-in-One Gateway",
      shortCode: "PTM",
      category: PaymentCategory.indianGateway,
      feeDescription: "1.99% + GST · Wallet & UPI",
      icon: Icons.wallet_rounded,
      brandColor: Color(0xFF002E6E),
      requiresCredentials: true,
      supportsSplitEscrow: true,
      supportedRails: ["Paytm Wallet", "UPI", "Postpaid", "Cards"],
      description: "All-in-one payment gateway with deep consumer wallet penetration across India.",
    ),
    PaymentProviderMetadata(
      id: PaymentProviderId.payu,
      name: "PayU India Enterprise",
      shortCode: "PAYU",
      category: PaymentCategory.indianGateway,
      feeDescription: "2.0% + GST · Multi-Bank",
      icon: Icons.domain_verification_rounded,
      brandColor: Color(0xFF84CC16),
      requiresCredentials: true,
      supportsSplitEscrow: true,
      supportedRails: ["100+ NetBanking", "Cards", "UPI", "EMI"],
      description: "Enterprise Indian gateway with extensive bank integrations and intelligent routing.",
    ),

    // 3. Global & International Gateways
    PaymentProviderMetadata(
      id: PaymentProviderId.stripe,
      name: "Stripe Connect & Global",
      shortCode: "STRIPE",
      category: PaymentCategory.globalGateway,
      feeDescription: "2.9% + 30¢ · Multi-Currency",
      icon: Icons.public_rounded,
      brandColor: Color(0xFF6366F1),
      requiresCredentials: true,
      supportsSplitEscrow: true,
      supportedRails: ["Global Cards", "Apple Pay", "Google Pay"],
      description: "Global standard for cross-border card acceptance and automated seller payouts.",
    ),
    PaymentProviderMetadata(
      id: PaymentProviderId.paypal,
      name: "PayPal Commerce Platform",
      shortCode: "PAYPAL",
      category: PaymentCategory.globalGateway,
      feeDescription: "3.4% + Fixed · Global Wallet",
      icon: Icons.language_rounded,
      brandColor: Color(0xFF003087),
      requiresCredentials: true,
      supportsSplitEscrow: true,
      supportedRails: ["PayPal Wallet", "International Cards"],
      description: "Trusted global wallet enabling tourists and NRI customers to book local artisans.",
    ),

    // 4. Cooperative Internal Ledger
    PaymentProviderMetadata(
      id: PaymentProviderId.coopWallet,
      name: "WorkGo Welfare Wallet",
      shortCode: "WALLET",
      category: PaymentCategory.cooperativeWallet,
      feeDescription: "0% Fee · Internal Balance",
      icon: Icons.savings_rounded,
      brandColor: Color(0xFFD97706),
      requiresCredentials: false,
      supportsSplitEscrow: true,
      supportedRails: ["Community Credits", "Corporate Account"],
      description: "Pre-funded corporate ledger and cooperative credit balance for instant 1-tap settlement.",
    ),

    // 5. Developer & Testing Sandbox
    PaymentProviderMetadata(
      id: PaymentProviderId.sandboxMock,
      name: "Interactive Sandbox Engine",
      shortCode: "SANDBOX",
      category: PaymentCategory.developerSandbox,
      feeDescription: "0% Fee · Test Mode Simulation",
      icon: Icons.science_rounded,
      brandColor: Color(0xFFEA580C),
      requiresCredentials: false,
      supportsSplitEscrow: true,
      supportedRails: ["Simulated UPI", "Test Cards", "Instant Settle"],
      description: "Frictionless test gateway allowing developers and reviewers to simulate checkouts without moving real money.",
    ),
  ];

  static PaymentProviderMetadata getById(PaymentProviderId id) {
    return catalog.firstWhere(
      (m) => m.id == id,
      orElse: () => catalog.first,
    );
  }
}

/// Dynamic, real-time configuration for platform payment processing.
class PaymentGatewayConfig {
  final PaymentProviderId activePrimaryProvider;
  final bool isLiveMode;
  final bool allowDirectUpiFallback;
  final bool allowCashHandover;

  // Platform Fee & Welfare Split
  final double platformFeePercent;
  final double welfareFundPercent;
  /// Dynamic GST percentage configured by admin (e.g. 18.0%).
  /// If null or <= 0, GST is omitted from the invoice entirely.
  final double? gstPercent;

  // Sovereign Direct UPI Settings
  final String cooperativeUpiVpa;
  final String cooperativePayeeName;

  // Provider-specific credentials map: {providerId: {key: value}}
  final Map<String, Map<String, String>> credentials;

  final DateTime updatedAt;
  final String updatedBy;

  // ── Invoice Identity (plug-and-play, admin-filled) ────────────────────────
  // All are nullable — if null/empty the invoice section is omitted entirely.
  /// e.g. "workgo.in"
  final String? invoiceWebsite;
  /// e.g. "1800-419-WORK"
  final String? invoicePhone;
  /// e.g. "support@workgo.in"
  final String? invoiceEmail;
  /// Custom legal terms shown at the bottom of every invoice.
  final String? invoiceTerms;
  /// Name that appears on the Authorised Sign line, e.g. "WorkGo Trust"
  final String? invoiceAuthorisedSignatory;

  const PaymentGatewayConfig({
    required this.activePrimaryProvider,
    this.isLiveMode = false,
    this.allowDirectUpiFallback = true,
    this.allowCashHandover = true,
    this.platformFeePercent = 5.0,
    this.welfareFundPercent = 2.0,
    this.gstPercent,
    this.cooperativeUpiVpa = "workgo@upi",
    this.cooperativePayeeName = "WorkGo Cooperative Federation",
    this.credentials = const {},
    required this.updatedAt,
    this.updatedBy = "admin@workgo.coop",
    // Invoice identity — all optional
    this.invoiceWebsite,
    this.invoicePhone,
    this.invoiceEmail,
    this.invoiceTerms,
    this.invoiceAuthorisedSignatory,
  });

  factory PaymentGatewayConfig.defaults() {
    return PaymentGatewayConfig(
      activePrimaryProvider: PaymentProviderId.directUpi,
      isLiveMode: false,
      allowDirectUpiFallback: true,
      allowCashHandover: true,
      platformFeePercent: 5.0,
      welfareFundPercent: 2.0,
      gstPercent: 18.0,
      cooperativeUpiVpa: "workgo@upi",
      cooperativePayeeName: "WorkGo Cooperative Federation",
      credentials: {},
      updatedAt: DateTime.now(),
      updatedBy: "system_default",
    );
  }

  PaymentProviderMetadata get activeMetadata =>
      PaymentProviderMetadata.getById(activePrimaryProvider);

  /// Helper to get a credential for a specific provider.
  String? getCredential(PaymentProviderId provider, String key) {
    return credentials[provider.name]?[key];
  }

  /// Whether the active primary provider has the necessary credentials or is credential-free.
  bool get isProviderConfigured {
    final meta = activeMetadata;
    if (!meta.requiresCredentials) return true;
    final creds = credentials[activePrimaryProvider.name];
    if (creds == null || creds.isEmpty) return false;
    return creds.values.any((v) => v.trim().isNotEmpty);
  }

  Map<String, dynamic> toMap() {
    return {
      "activePrimaryProvider": activePrimaryProvider.name,
      "isLiveMode": isLiveMode,
      "allowDirectUpiFallback": allowDirectUpiFallback,
      "allowCashHandover": allowCashHandover,
      "platformFeePercent": platformFeePercent,
      "welfareFundPercent": welfareFundPercent,
      if (gstPercent != null) "gstPercent": gstPercent,
      "cooperativeUpiVpa": cooperativeUpiVpa,
      "cooperativePayeeName": cooperativePayeeName,
      "credentials": credentials,
      "updatedAt": updatedAt.toIso8601String(),
      "updatedBy": updatedBy,
      if (invoiceWebsite != null) "invoiceWebsite": invoiceWebsite,
      if (invoicePhone != null) "invoicePhone": invoicePhone,
      if (invoiceEmail != null) "invoiceEmail": invoiceEmail,
      if (invoiceTerms != null) "invoiceTerms": invoiceTerms,
      if (invoiceAuthorisedSignatory != null)
        "invoiceAuthorisedSignatory": invoiceAuthorisedSignatory,
    };
  }

  factory PaymentGatewayConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return PaymentGatewayConfig.defaults();

    PaymentProviderId provider = PaymentProviderId.directUpi;
    final providerStr = map["activePrimaryProvider"]?.toString();
    if (providerStr != null) {
      provider = PaymentProviderId.values.firstWhere(
        (e) => e.name == providerStr,
        orElse: () => PaymentProviderId.directUpi,
      );
    }

    final rawCreds = map["credentials"];
    final Map<String, Map<String, String>> parsedCreds = {};
    if (rawCreds is Map) {
      rawCreds.forEach((k, v) {
        if (v is Map) {
          parsedCreds[k.toString()] = v.map((ik, iv) => MapEntry(ik.toString(), iv.toString()));
        }
      });
    }

    String? readStr(String key) {
      final v = map[key]?.toString();
      return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
    }

    return PaymentGatewayConfig(
      activePrimaryProvider: provider,
      isLiveMode: map["isLiveMode"] == true,
      allowDirectUpiFallback: map["allowDirectUpiFallback"] ?? true,
      allowCashHandover: map["allowCashHandover"] ?? true,
      platformFeePercent: (map["platformFeePercent"] as num?)?.toDouble() ?? 5.0,
      welfareFundPercent: (map["welfareFundPercent"] as num?)?.toDouble() ?? 2.0,
      gstPercent: (map["gstPercent"] as num?)?.toDouble(),
      cooperativeUpiVpa: map["cooperativeUpiVpa"]?.toString() ?? "workgo@upi",
      cooperativePayeeName: map["cooperativePayeeName"]?.toString() ?? "WorkGo Cooperative Federation",
      credentials: parsedCreds,
      updatedAt: DateTime.tryParse(map["updatedAt"]?.toString() ?? "") ?? DateTime.now(),
      updatedBy: map["updatedBy"]?.toString() ?? "admin",
      invoiceWebsite: readStr("invoiceWebsite"),
      invoicePhone: readStr("invoicePhone"),
      invoiceEmail: readStr("invoiceEmail"),
      invoiceTerms: readStr("invoiceTerms"),
      invoiceAuthorisedSignatory: readStr("invoiceAuthorisedSignatory"),
    );
  }

  PaymentGatewayConfig copyWith({
    PaymentProviderId? activePrimaryProvider,
    bool? isLiveMode,
    bool? allowDirectUpiFallback,
    bool? allowCashHandover,
    double? platformFeePercent,
    double? welfareFundPercent,
    Object? gstPercent = _sentinel,
    String? cooperativeUpiVpa,
    String? cooperativePayeeName,
    Map<String, Map<String, String>>? credentials,
    DateTime? updatedAt,
    String? updatedBy,
    // Use Object? sentinel to allow explicit null-clearing
    Object? invoiceWebsite = _sentinel,
    Object? invoicePhone = _sentinel,
    Object? invoiceEmail = _sentinel,
    Object? invoiceTerms = _sentinel,
    Object? invoiceAuthorisedSignatory = _sentinel,
  }) {
    return PaymentGatewayConfig(
      activePrimaryProvider: activePrimaryProvider ?? this.activePrimaryProvider,
      isLiveMode: isLiveMode ?? this.isLiveMode,
      allowDirectUpiFallback: allowDirectUpiFallback ?? this.allowDirectUpiFallback,
      allowCashHandover: allowCashHandover ?? this.allowCashHandover,
      platformFeePercent: platformFeePercent ?? this.platformFeePercent,
      welfareFundPercent: welfareFundPercent ?? this.welfareFundPercent,
      gstPercent: identical(gstPercent, _sentinel)
          ? this.gstPercent
          : gstPercent as double?,
      cooperativeUpiVpa: cooperativeUpiVpa ?? this.cooperativeUpiVpa,
      cooperativePayeeName: cooperativePayeeName ?? this.cooperativePayeeName,
      credentials: credentials ?? this.credentials,
      updatedAt: updatedAt ?? DateTime.now(),
      updatedBy: updatedBy ?? this.updatedBy,
      invoiceWebsite: identical(invoiceWebsite, _sentinel)
          ? this.invoiceWebsite
          : invoiceWebsite as String?,
      invoicePhone: identical(invoicePhone, _sentinel)
          ? this.invoicePhone
          : invoicePhone as String?,
      invoiceEmail: identical(invoiceEmail, _sentinel)
          ? this.invoiceEmail
          : invoiceEmail as String?,
      invoiceTerms: identical(invoiceTerms, _sentinel)
          ? this.invoiceTerms
          : invoiceTerms as String?,
      invoiceAuthorisedSignatory: identical(invoiceAuthorisedSignatory, _sentinel)
          ? this.invoiceAuthorisedSignatory
          : invoiceAuthorisedSignatory as String?,
    );
  }

  static const Object _sentinel = Object();
}
