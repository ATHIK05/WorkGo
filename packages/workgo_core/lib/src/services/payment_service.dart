import "package:cloud_firestore/cloud_firestore.dart";
import "package:url_launcher/url_launcher.dart";
import "../models/payment_provider_model.dart";
import "booking_service.dart";

/// Universal Payment Service managing the Gateway Switchboard, NPCI UPI generation,
/// and settlement lifecycle across all WorkGo applications.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ??= FirebaseFirestore.instance;
  BookingService? _bookingSvc;
  BookingService get _bookingService => _bookingSvc ??= BookingService();

  static const String _configCollection = "system_configs";
  static const String _configDoc = "payment_gateways";

  /// Real-time stream of the active payment gateway configuration.
  Stream<PaymentGatewayConfig> streamGatewayConfig() {
    return _db
        .collection(_configCollection)
        .doc(_configDoc)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) {
        return PaymentGatewayConfig.defaults();
      }
      return PaymentGatewayConfig.fromMap(snap.data()!);
    });
  }

  /// One-time fetch of the current payment gateway configuration.
  Future<PaymentGatewayConfig> getGatewayConfig() async {
    try {
      final snap = await _db.collection(_configCollection).doc(_configDoc).get();
      if (!snap.exists || snap.data() == null) {
        return PaymentGatewayConfig.defaults();
      }
      return PaymentGatewayConfig.fromMap(snap.data()!);
    } catch (_) {
      return PaymentGatewayConfig.defaults();
    }
  }

  /// Saves or updates the payment switchboard configuration in Firestore.
  Future<void> saveGatewayConfig(PaymentGatewayConfig config) async {
    await _db.collection(_configCollection).doc(_configDoc).set(
          config.toMap(),
          SetOptions(merge: true),
        );
  }

  /// Builds a standard NPCI-compliant UPI payment URI:
  /// `upi://pay?pa={vpa}&pn={payeeName}&am={amount}&cu=INR&tn={note}&tr={ref}`
  Uri generateUpiUri({
    required String vpa,
    required String payeeName,
    required double amount,
    required String note,
    String? transactionRef,
  }) {
    final cleanVpa = vpa.trim();
    final cleanAmount = amount.toStringAsFixed(2);
    final params = <String, String>{
      "pa": cleanVpa,
      "pn": payeeName.trim(),
      "am": cleanAmount,
      "cu": "INR",
      "tn": note.trim(),
    };
    if (transactionRef != null && transactionRef.isNotEmpty) {
      params["tr"] = transactionRef.trim();
    }

    final queryString = params.entries
        .map((e) => "${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}")
        .join("&");

    return Uri.parse("upi://pay?$queryString");
  }

  /// Generates a PhonePe specific deep link URI:
  /// `phonepe://pay?pa={vpa}&pn={payeeName}&am={amount}&cu=INR&tn={note}`
  Uri generatePhonePeUri({
    required String vpa,
    required String payeeName,
    required double amount,
    required String note,
    String? transactionRef,
  }) {
    final cleanVpa = vpa.trim();
    final cleanAmount = amount.toStringAsFixed(2);
    final params = <String, String>{
      "pa": cleanVpa,
      "pn": payeeName.trim(),
      "am": cleanAmount,
      "cu": "INR",
      "tn": note.trim(),
    };
    if (transactionRef != null && transactionRef.isNotEmpty) {
      params["tr"] = transactionRef.trim();
    }
    final queryString = params.entries
        .map((e) => "${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}")
        .join("&");
    return Uri.parse("phonepe://pay?$queryString");
  }

  /// Generates a Google Pay (GPay / Tez) specific deep link URI:
  /// `tez://upi/pay?pa={vpa}&pn={payeeName}&am={amount}&cu=INR&tn={note}`
  Uri generateGPayUri({
    required String vpa,
    required String payeeName,
    required double amount,
    required String note,
    String? transactionRef,
  }) {
    final cleanVpa = vpa.trim();
    final cleanAmount = amount.toStringAsFixed(2);
    final params = <String, String>{
      "pa": cleanVpa,
      "pn": payeeName.trim(),
      "am": cleanAmount,
      "cu": "INR",
      "tn": note.trim(),
    };
    if (transactionRef != null && transactionRef.isNotEmpty) {
      params["tr"] = transactionRef.trim();
    }
    final queryString = params.entries
        .map((e) => "${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}")
        .join("&");
    return Uri.parse("tez://upi/pay?$queryString");
  }

  /// Launches PhonePe directly, falling back to standard UPI intent if PhonePe is not installed.
  Future<bool> launchPhonePe({
    required String vpa,
    required String payeeName,
    required double amount,
    required String note,
    String? transactionRef,
  }) async {
    final phonePeUri = generatePhonePeUri(
      vpa: vpa,
      payeeName: payeeName,
      amount: amount,
      note: note,
      transactionRef: transactionRef,
    );
    try {
      if (await canLaunchUrl(phonePeUri)) {
        return await launchUrl(phonePeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    // Fallback to standard UPI intent
    final upiUri = generateUpiUri(
      vpa: vpa,
      payeeName: payeeName,
      amount: amount,
      note: note,
      transactionRef: transactionRef,
    );
    return await launchUpiIntent(upiUri);
  }

  /// Launches Google Pay (GPay) directly, falling back to standard UPI intent if GPay is not installed.
  Future<bool> launchGPay({
    required String vpa,
    required String payeeName,
    required double amount,
    required String note,
    String? transactionRef,
  }) async {
    final gPayUri = generateGPayUri(
      vpa: vpa,
      payeeName: payeeName,
      amount: amount,
      note: note,
      transactionRef: transactionRef,
    );
    try {
      if (await canLaunchUrl(gPayUri)) {
        return await launchUrl(gPayUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    // Fallback to standard UPI intent
    final upiUri = generateUpiUri(
      vpa: vpa,
      payeeName: payeeName,
      amount: amount,
      note: note,
      transactionRef: transactionRef,
    );
    return await launchUpiIntent(upiUri);
  }

  /// Launches the native UPI application chooser (GPay, PhonePe, Paytm, BHIM, Cred)
  /// using external application mode.
  Future<bool> launchUpiIntent(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      // Fallback attempt
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  /// Completes payment settlement on Firestore for a booking, recording audit telemetry.
  Future<void> recordPaymentSettlement({
    required String bookingId,
    required String paymentMethod,
    PaymentProviderId? providerId,
    String? referenceId,
    String? invoiceId,
    double? platformFee,
    double? welfareFund,
  }) async {
    await _bookingService.markPaymentComplete(
      bookingId,
      invoiceId: invoiceId,
      paymentMethod: paymentMethod,
      paymentProvider: providerId?.name,
      paymentReference: referenceId,
      platformFeeAmount: platformFee,
      welfareFundAmount: welfareFund,
    );
  }
}
