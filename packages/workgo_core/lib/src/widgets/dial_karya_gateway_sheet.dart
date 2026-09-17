import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../localization/trade_localization.dart';
import '../models/worker.dart';

/// Opens the Dial Karya Telephony Gateway & Peer KYC Sheet
void showDialKaryaGatewaySheet(
  BuildContext context, {
  required Worker worker,
  void Function(Map<String, dynamic> dialWorker)? onInitiatePeerKyc,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DialKaryaGatewaySheet(
      worker: worker,
      onInitiatePeerKyc: onInitiatePeerKyc,
    ),
  );
}

class DialKaryaGatewaySheet extends StatefulWidget {
  const DialKaryaGatewaySheet({
    super.key,
    required this.worker,
    this.onInitiatePeerKyc,
  });

  final Worker worker;
  final void Function(Map<String, dynamic> dialWorker)? onInitiatePeerKyc;

  @override
  State<DialKaryaGatewaySheet> createState() => _DialKaryaGatewaySheetState();
}

class _DialKaryaGatewaySheetState extends State<DialKaryaGatewaySheet> {
  static const String gatewayExtension = "1000";
  static const String gatewayHotline = "+91 90802 62334";

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse("tel:$cleanPhone");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      margin: const EdgeInsets.only(top: 36),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Handle Bar ──
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E0D8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header Title & Icon ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0A3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.settings_phone_rounded,
                      color: Color(0xFF92400E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'dial_karya_gateway_title'.trSafe('Dial Karya Voice Gateway'),
                          style: const TextStyle(
                            color: Color(0xFF141416),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'dial_karya_gateway_sub'.trSafe('Telephony Gateway & Peer KYC Station'),
                          style: const TextStyle(
                            color: Color(0xFF6B6B6B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6B6B)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── 1. Voice Gateway Telephony Hub Card (Obsidian Glass) ──
              _buildGatewayTelephonyCard(),
              const SizedBox(height: 14),

              // ── 2. Peer KYC Bounty Highlight Banner ──
              _buildBountyHighlightBanner(),
              const SizedBox(height: 16),

              // ── 3. Feature-Phone Dial Artisans Stream ──
              Text(
                'nearby_dial_artisans_title'.trSafe('Nearby Dial Artisans Awaiting KYC'),
                style: const TextStyle(
                  color: Color(0xFF141416),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'nearby_dial_artisans_sub'.trSafe('Verify feature-phone artisans in person to earn ₹150 bounty.'),
                style: const TextStyle(
                  color: Color(0xFF6B6B6B),
                  fontSize: 11.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              _buildDialArtisansStream(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Gateway Telephony Bento Card ──
  Widget _buildGatewayTelephonyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13111C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF10B981),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'gateway_status_live'.trSafe('WSL2 ASTERISK SIP GATEWAY • ACTIVE'),
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD97706)),
                ),
                child: Text(
                  "EXT $gatewayExtension",
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'dial_karya_gateway_desc'.trSafe(
              'Connect non-smartphone feature phones to Extension 1000 or MizuDroid. Spoken Bhashini AI voice dispatches customer bookings automatically in 22 languages.',
            ),
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 12,
              height: 1.35,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _makePhoneCall(gatewayExtension);
                  },
                  icon: const Icon(Icons.dialpad_rounded, size: 16),
                  label: Text(
                    'dial_ext_btn'.trSafe('Dial Ext 1000'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _makePhoneCall(gatewayHotline);
                  },
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: Text(
                    'call_hotline_btn'.trSafe('Call Hotline'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bounty Highlight Banner ──
  Widget _buildBountyHighlightBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.monetization_on_rounded, color: Color(0xFFB45309), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'peer_kyc_bounties_title'.trSafe('Dial Karya Peer KYC Bounties'),
                  style: const TextStyle(
                    color: Color(0xFF78350F),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'peer_kyc_bounty_hint'.trSafe(
                    'Verify nearby dial workers via home alerts to earn ₹150 instantly into your wallet.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stream of Dial Workers ──
  Widget _buildDialArtisansStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('workers')
          .where('isDialWorker', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E0D8)),
            ),
            child: Column(
              children: [
                const Icon(Icons.perm_phone_msg_rounded, color: Color(0xFF9CA3AF), size: 36),
                const SizedBox(height: 8),
                Text(
                  'no_dial_workers_pending'.trSafe('No Dial Workers Pending KYC'),
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'dial_worker_instruction'.trSafe(
                    'When a feature-phone worker dials 1000 to register, they will appear here for in-person KYC verification.',
                  ),
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final workerId = docs[i].id;
            final name = data['name'] ?? 'Dial Worker';
            final phone = data['phoneForCalling'] ?? data['phone'] ?? '';
            final trade = (data['skills'] as List?)?.firstOrNull?.toString() ??
                data['trade'] ??
                'General';
            final tradeDescription = (data['tradeDescription'] ?? '').toString();
            final locationText = (data['locationText'] ??
                ((data['preferredAreas'] as List?)?.firstOrNull?.toString()) ??
                '').toString();
            final pincode = (data['pincode'] ?? '').toString();
            final isVerified = data['verificationStatus'] == 'approved' ||
                data['verificationStage'] == 'approved';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isVerified ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isVerified ? Icons.verified_user_rounded : Icons.dialpad_rounded,
                      color: isVerified ? const Color(0xFF15803D) : const Color(0xFFEA580C),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Color(0xFF141416),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isVerified
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFFF3D6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isVerified
                                    ? 'kyc_verified_badge'.trSafe('KYC Verified')
                                    : 'kyc_pending_badge'.trSafe('Pending KYC'),
                                style: TextStyle(
                                  color: isVerified
                                      ? const Color(0xFF166534)
                                      : const Color(0xFFB45309),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$trade • $phone",
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (locationText.isNotEmpty || pincode.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFEA580C)),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  [locationText, if (pincode.isNotEmpty) pincode].where((s) => s.isNotEmpty).join(' • '),
                                  style: const TextStyle(
                                    color: Color(0xFF374151),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (tradeDescription.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            '"$tradeDescription"',
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isVerified)
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop();
                        if (widget.onInitiatePeerKyc != null) {
                          widget.onInitiatePeerKyc!({
                            'id': workerId,
                            'name': name,
                            'phone': phone,
                            'trade': trade,
                            'tradeDescription': tradeDescription,
                            'locationText': locationText,
                            'pincode': pincode,
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text(
                        'verify_kyc_btn'.trSafe('Verify (₹150)'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
