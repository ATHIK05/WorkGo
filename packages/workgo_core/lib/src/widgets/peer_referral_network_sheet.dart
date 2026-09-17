import 'package:flutter/material.dart';
import '../models/worker.dart';
import 'dial_karya_gateway_sheet.dart';

/// Backward-compatible entrypoint replacing Peer Referral Guild with Dial Karya Voice Gateway
void showPeerReferralNetworkSheet(
  BuildContext context, {
  required Worker worker,
}) {
  showDialKaryaGatewaySheet(context, worker: worker);
}

/// Backward-compatible widget class wrapper
class PeerReferralNetworkSheet extends StatelessWidget {
  const PeerReferralNetworkSheet({
    super.key,
    required this.worker,
  });

  final Worker worker;

  @override
  Widget build(BuildContext context) {
    return DialKaryaGatewaySheet(worker: worker);
  }
}
