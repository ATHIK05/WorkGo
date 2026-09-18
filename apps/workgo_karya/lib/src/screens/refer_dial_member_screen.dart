import 'package:flutter/material.dart';
import 'package:workgo_core/workgo_core.dart';
import 'document_upload_screen.dart';

/// Refer Dial Karya Member — Unified Peer KYC Screen
///
/// Seamlessly delegates to the unified [DocumentUploadScreen] in Peer-KYC mode.
/// This ensures Dial workers pass through the exact same 5-stage verification procedure
/// (5-Signal Trust Index, DPDP Consent, UIDAI Aadhaar QR, e-Shram UAN,
/// 3D Multi-Angle Liveness with Google MLKit, Tools Inspection,
/// and Asterisk Voice OTP handshake with ₹150 Mitra bounty).
class ReferDialMemberScreen extends StatelessWidget {
  final Worker mitraWorker;
  final String dialWorkerId;
  final String dialWorkerName;
  final String dialWorkerPhone;
  final String dialWorkerTrade;
  final String? dialWorkerLocation;
  final String? dialWorkerTradeDescription;
  final String backendBaseUrl;

  const ReferDialMemberScreen({
    super.key,
    required this.mitraWorker,
    required this.dialWorkerId,
    required this.dialWorkerName,
    required this.dialWorkerPhone,
    required this.dialWorkerTrade,
    this.dialWorkerLocation,
    this.dialWorkerTradeDescription,
    required this.backendBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    return DocumentUploadScreen(
      workerId: dialWorkerId,
      isPeerKyc: true,
      mitraWorker: mitraWorker,
      dialWorkerName: dialWorkerName,
      dialWorkerPhone: dialWorkerPhone,
      dialWorkerTrade: dialWorkerTrade,
      dialWorkerLocation: dialWorkerLocation,
      dialWorkerTradeDescription: dialWorkerTradeDescription,
      backendBaseUrl: backendBaseUrl,
    );
  }
}
