import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../localization/trade_localization.dart';
import '../models/worker.dart';

/// Opens the Dial Karya Telephony Gateway & Peer KYC Sheet with smooth, rich aesthetics
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

class _DialKaryaGatewaySheetState extends State<DialKaryaGatewaySheet>
    with SingleTickerProviderStateMixin {
  static const String gatewayExtension = "1000";
  static const String gatewayHotline = "+91 90802 62334";

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phone) async {
    HapticFeedback.lightImpact();
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse("tel:$cleanPhone");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  void _copyToClipboard(String text, String label) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
            const SizedBox(width: 8),
            Text(
              "$label copied to clipboard",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1035),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  IconData _getTradeIcon(String trade) {
    final lower = trade.toLowerCase();
    if (lower.contains('plumb')) return Icons.plumbing_rounded;
    if (lower.contains('electr')) return Icons.electrical_services_rounded;
    if (lower.contains('carpent')) return Icons.carpenter_rounded;
    if (lower.contains('paint')) return Icons.format_paint_rounded;
    if (lower.contains('clean')) return Icons.cleaning_services_rounded;
    if (lower.contains('mason')) return Icons.foundation_rounded;
    if (lower.contains('weld')) return Icons.hardware_rounded;
    if (lower.contains('garden')) return Icons.yard_rounded;
    return Icons.construction_rounded;
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
        color: Color(0xFFFAF8F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 36,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Brass Handle Bar ──
              Center(
                child: Container(
                  width: 48,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCD6CC),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header Title & Icon ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF3D6), Color(0xFFFFE0A3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.35)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10B45309),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.settings_phone_rounded,
                      color: Color(0xFFB45309),
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
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF141416),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'dial_karya_gateway_sub'.trSafe('Telephony Gateway & Peer KYC Station'),
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF71717A),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5E0D8)),
                    ),
                    child: IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF71717A), size: 20),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── 1. Voice Gateway Telephony Hub Card (Obsidian Glass) ──
              _buildGatewayTelephonyCard(),
              const SizedBox(height: 14),

              // ── 2. Peer KYC Bounty Highlight Banner ──
              _buildBountyHighlightBanner(),
              const SizedBox(height: 20),

              // ── 3. Feature-Phone Dial Artisans Section Header ──
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'nearby_dial_artisans_title'.trSafe('Nearby Dial Artisans Awaiting KYC'),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF18181B),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'nearby_dial_artisans_sub'.trSafe('Verify feature-phone artisans in person to earn ₹150 bounty.'),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF71717A),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 14),

              // ── 4. Stream of Nearby Dial Artisans ──
              _buildDialArtisansStream(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Gateway Telephony Bento Card (Obsidian Glass) ──
  Widget _buildGatewayTelephonyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF181528), Color(0xFF0F0E17)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Gateway Status Bar with Breathing Radar Glow
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(
                            alpha: 0.3 + 0.5 * _pulseAnimation.value,
                          ),
                          blurRadius: 8 + 4 * _pulseAnimation.value,
                          spreadRadius: 1 + 2 * _pulseAnimation.value,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'gateway_status_live'.trSafe('WSL2 ASTERISK SIP GATEWAY • ACTIVE'),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF34D399),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => _copyToClipboard(gatewayExtension, "Extension"),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "EXT $gatewayExtension",
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFFBBF24),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, color: Color(0xFFFBBF24), size: 11),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            'dial_karya_gateway_desc'.trSafe(
              'Connect non-smartphone feature phones to Extension 1000 or MizuDroid. Spoken Bhashini AI voice dispatches customer bookings automatically in 22 languages.',
            ),
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFE4E4E7),
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Interactive Action Buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x35D97706),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _makePhoneCall(gatewayExtension),
                    icon: const Icon(Icons.dialpad_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'dial_ext_btn'.trSafe('Dial Ext 1000'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => _makePhoneCall(gatewayHotline),
                    onLongPress: () => _copyToClipboard(gatewayHotline, "Hotline number"),
                    icon: const Icon(Icons.call_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'call_hotline_btn'.trSafe('Call Hotline'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bounty Highlight Banner (Golden Guild Certificate) ──
  Widget _buildBountyHighlightBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20D97706),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.stars_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'peer_kyc_bounties_title'.trSafe('Dial Karya Peer KYC Bounties'),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF78350F),
                          fontSize: 13,
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
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        "₹150",
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF047857),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'peer_kyc_bounty_hint'.trSafe(
                    'Verify nearby dial workers via home alerts to earn ₹150 instantly into your wallet.',
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF92400E),
                    fontSize: 11,
                    height: 1.35,
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
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFF59E0B),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyRadarState();
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final workerId = docs[i].id;
            final name = (data['name'] ?? 'Dial Worker').toString();
            final phone = (data['phoneForCalling'] ?? data['phone'] ?? '').toString();
            final trade = (data['skills'] as List?)?.firstOrNull?.toString() ??
                data['trade']?.toString() ??
                'General';
            final tradeDescription = (data['tradeDescription'] ?? '').toString();
            final locationText = (data['locationText'] ??
                ((data['preferredAreas'] as List?)?.firstOrNull?.toString()) ??
                '').toString();
            final pincode = (data['pincode'] ?? '').toString();
            final isVerified = data['verificationStatus'] == 'approved' ||
                data['verificationStage'] == 'approved';

            final tradeIcon = _getTradeIcon(trade);
            final localizedLocation = locationText.toLocalizedAddress(
              Localizations.localeOf(context).languageCode,
            );

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isVerified ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Trade Avatar + Name + Badges
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isVerified ? const Color(0xFF86EFAC) : const Color(0xFFFFEDD5),
                          ),
                        ),
                        child: Icon(
                          tradeIcon,
                          color: isVerified ? const Color(0xFF15803D) : const Color(0xFFEA580C),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF18181B),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: isVerified
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFFF3D6),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isVerified
                                          ? const Color(0xFF86EFAC)
                                          : const Color(0xFFFDE68A),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isVerified
                                            ? Icons.verified_rounded
                                            : Icons.pending_actions_rounded,
                                        size: 10,
                                        color: isVerified
                                            ? const Color(0xFF166534)
                                            : const Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        isVerified
                                            ? 'kyc_verified_badge'.trSafe('KYC Verified')
                                            : 'kyc_pending_badge'.trSafe('Pending KYC'),
                                        style: GoogleFonts.plusJakartaSans(
                                          color: isVerified
                                              ? const Color(0xFF166534)
                                              : const Color(0xFFB45309),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F4F5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      trade,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF52525B),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (phone.isNotEmpty)
                        IconButton(
                          onPressed: () => _makePhoneCall(phone),
                          icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF2563EB), size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFEFF6FF),
                            padding: const EdgeInsets.all(8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                    ],
                  ),

                  // Location Row
                  if (localizedLocation.isNotEmpty || pincode.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFEA580C)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              localizedLocation,
                              if (pincode.isNotEmpty) pincode,
                            ].where((s) => s.isNotEmpty).join(' • '),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF52525B),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Spoken Voice Transcription Speech Bubble
                  if (tradeDescription.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.graphic_eq_rounded, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '"$tradeDescription"',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF475569),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Action Callout Button
                  if (!isVerified) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2EEA580C),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
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
                        icon: const Icon(Icons.verified_user_rounded, size: 16, color: Colors.white),
                        label: Text(
                          'verify_kyc_btn'.trSafe('Verify & Claim ₹150 Bounty'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            "Verified Dial Member • Activated on Marketplace",
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF15803D),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Live Radar Scanner Empty State ──
  Widget _buildEmptyRadarState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E0D8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 72 + 16 * _pulseAnimation.value,
                    height: 72 + 16 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFEF3C7).withValues(
                        alpha: 0.35 * (1.0 - _pulseAnimation.value),
                      ),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: const Icon(
                      Icons.sensors_rounded,
                      color: Color(0xFFEA580C),
                      size: 28,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'no_dial_workers_pending'.trSafe('No Dial Workers Pending KYC'),
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF18181B),
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            'dial_worker_instruction'.trSafe(
              'When a feature-phone worker dials Extension 1000 to register, they will appear here automatically for in-person KYC verification.',
            ),
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF71717A),
              fontSize: 11.5,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _makePhoneCall(gatewayExtension),
            icon: const Icon(Icons.phone_forwarded_rounded, size: 15, color: Color(0xFFB45309)),
            label: Text(
              "Test Call Ext $gatewayExtension",
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFB45309),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFDE68A), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFFFFFBEB),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
