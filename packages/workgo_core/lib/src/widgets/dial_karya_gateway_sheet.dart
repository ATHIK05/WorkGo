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
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  int _selectedTab = 0; // 0 = Awaiting KYC, 1 = Verified by You

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      if (timestamp is Timestamp) {
        final dt = timestamp.toDate();
        return '${dt.day}/${dt.month}/${dt.year}';
      }
      final str = timestamp.toString();
      if (str.isNotEmpty) {
        final dt = DateTime.parse(str).toLocal();
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {}
    return '';
  }

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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── 1. Main Bottom Sheet Container with 50dp Top Clearance for Pop-Out Avatar ──
        Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          margin: const EdgeInsets.only(top: 50),
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
                  const SizedBox(height: 12),

                  // ── Header: Title, Live Pulse Badge, and Reserved Space for Overhanging Avatar ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Close Pill, Live Badge, and Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Circular Close Button
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE5E0D8)),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x08000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Color(0xFF71717A),
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Live Pulsing Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF86EFAC).withValues(alpha: 0.8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FadeTransition(
                                        opacity: _pulseAnimation,
                                        child: Container(
                                          width: 6.5,
                                          height: 6.5,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF16A34A),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4.5),
                                      Text(
                                        "LIVE IVR",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF15803D),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'dial_karya_gateway_title'.trSafe('Dial Karya\nVoice Gateway'),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF1E293B),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'dial_karya_gateway_sub'.trSafe('Telephony Gateway & Peer KYC Station'),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF64748B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right: Reserved clearance area for the 3D Pop-Out Avatar
                      const SizedBox(width: 145, height: 115),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── 1. Peer KYC Bounty Highlight Banner ──
                  _buildBountyHighlightBanner(),
                  const SizedBox(height: 20),

                  // ── 2. Stream of Nearby Dial Artisans with Scope-Aware Tabs ──
                  _buildDialArtisansStream(),
                ],
              ),
            ),
          ),
        ),

        // ── 2. The 3D Pop-Out Hero Avatar Overhanging the Sheet Top Edge ──
        Positioned(
          top: 0,
          right: 6,
          child: IgnorePointer(
            child: Image.asset(
              'assets/images/dial_karya_voice_avatar.png',
              height: 175,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'packages/workgo_core/assets/images/dial_karya_voice_avatar.png',
                height: 175,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
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

  // ── Stream of Dial Workers (Scope-Aware: Pending vs Verified by You) ──
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

        final allDocs = snapshot.data?.docs ?? [];
        final pendingDocs = <QueryDocumentSnapshot>[];
        final myVerifiedDocs = <QueryDocumentSnapshot>[];

        for (final doc in allDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final isVerified = data['verificationStatus'] == 'approved' ||
              data['verificationStage'] == 'approved';
          final mitraId = (data['peerKycMitraId'] ?? data['mitraWorkerId'] ?? '').toString();

          if (!isVerified) {
            // Awaiting KYC: visible to all nearby workers to verify & claim bounty
            pendingDocs.add(doc);
          } else if (mitraId.isNotEmpty && mitraId == widget.worker.id) {
            // Verified by this worker: visible ONLY to this dedicated member
            myVerifiedDocs.add(doc);
          }
          // Note: If isVerified && mitraId != widget.worker.id,
          // the worker was verified by someone else and is strictly HIDDEN from this worker!
        }

        final activeDocs = _selectedTab == 0 ? pendingDocs : myVerifiedDocs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Segmented Tab Switcher (Awaiting KYC vs Verified by You)
            _buildSegmentedTabSelector(pendingDocs.length, myVerifiedDocs.length),
            const SizedBox(height: 18),

            // Dynamic Tab Header
            _buildTabHeader(_selectedTab, activeDocs.length),
            const SizedBox(height: 14),

            // Tab Content
            if (activeDocs.isEmpty)
              _selectedTab == 0
                  ? _buildEmptyRadarState()
                  : _buildEmptyVerifiedState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeDocs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final data = activeDocs[i].data() as Map<String, dynamic>;
                  final workerId = activeDocs[i].id;
                  return _selectedTab == 0
                      ? _buildPendingArtisanCard(data, workerId)
                      : _buildVerifiedByMeCard(data, workerId);
                },
              ),
          ],
        );
      },
    );
  }

  // ── Segmented Tab Selector ──
  Widget _buildSegmentedTabSelector(int pendingCount, int verifiedCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFECE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2DDD5)),
      ),
      child: Row(
        children: [
          // Tab 0: Awaiting KYC
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedTab != 0) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = 0);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _selectedTab == 0
                      ? Border.all(color: const Color(0xFFFDE68A), width: 1.2)
                      : null,
                  boxShadow: _selectedTab == 0
                      ? const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 15,
                      color: _selectedTab == 0 ? const Color(0xFFB45309) : const Color(0xFF71717A),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'tab_awaiting_kyc'.trSafe('Awaiting KYC'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: _selectedTab == 0 ? FontWeight.w800 : FontWeight.w600,
                          color: _selectedTab == 0 ? const Color(0xFF18181B) : const Color(0xFF71717A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? const Color(0xFFFFF3D6) : const Color(0xFFE4E0D8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _selectedTab == 0 ? const Color(0xFFB45309) : const Color(0xFF71717A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Tab 1: Verified by You
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedTab != 1) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = 1);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _selectedTab == 1
                      ? Border.all(color: const Color(0xFFA7F3D0), width: 1.2)
                      : null,
                  boxShadow: _selectedTab == 1
                      ? const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 15,
                      color: _selectedTab == 1 ? const Color(0xFF047857) : const Color(0xFF71717A),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'tab_verified_by_you'.trSafe('Verified by You'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: _selectedTab == 1 ? FontWeight.w800 : FontWeight.w600,
                          color: _selectedTab == 1 ? const Color(0xFF18181B) : const Color(0xFF71717A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? const Color(0xFFDCFCE7) : const Color(0xFFE4E0D8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$verifiedCount',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _selectedTab == 1 ? const Color(0xFF047857) : const Color(0xFF71717A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dynamic Tab Header ──
  Widget _buildTabHeader(int tabIndex, int count) {
    final isPending = tabIndex == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isPending
                    ? 'nearby_dial_artisans_title'.trSafe('Nearby Dial Artisans Awaiting KYC')
                    : 'my_verified_artisans_title'.trSafe('Artisans Verified by You'),
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
            isPending
                ? 'nearby_dial_artisans_sub'.trSafe('Verify feature-phone artisans in person to earn ₹150 bounty.')
                : 'my_verified_artisans_sub'.trSafe('Feature-phone artisans you personally verified. ₹150 bounty credited to your wallet.'),
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF71717A),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Pending Artisan Card (Awaiting KYC) ──
  Widget _buildPendingArtisanCard(Map<String, dynamic> data, String workerId) {
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
          color: const Color(0xFFFED7AA),
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
          // Top Row: Trade Avatar + Name + Badges + Phone Call
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Icon(
                  tradeIcon,
                  color: const Color(0xFFEA580C),
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
                            color: const Color(0xFFFFF3D6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.pending_actions_rounded,
                                size: 10,
                                color: Color(0xFFB45309),
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                'kyc_pending_badge'.trSafe('Pending KYC'),
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFB45309),
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
        ],
      ),
    );
  }

  // ── Verified By Me Card (Visible ONLY to the Dedicated Mitra) ──
  Widget _buildVerifiedByMeCard(Map<String, dynamic> data, String workerId) {
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
    final completedDate = _formatDate(data['peerKycCompletedAt'] ?? data['updatedAt']);

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
          color: const Color(0xFFBBF7D0),
          width: 1.3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C059669),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Trade Avatar + Name + Badges + Direct Call
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Icon(
                  tradeIcon,
                  color: const Color(0xFF15803D),
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
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF86EFAC),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 10,
                                color: Color(0xFF166534),
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                'verified_by_you_badge'.trSafe('Verified by You'),
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF166534),
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
                const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF059669)),
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

          // Spoken Voice Transcription Speech Bubble (if present)
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
                  const Icon(Icons.graphic_eq_rounded, size: 14, color: Color(0xFF059669)),
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

          // Mitra Verification & Bounty Status Banner
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: Color(0xFF16A34A),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'bounty_credited_tag'.trSafe('₹150 Peer KYC Bounty Credited'),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF14532D),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        completedDate.isNotEmpty
                            ? '${'verified_artisan_active'.trSafe('Active on Marketplace')} • $completedDate'
                            : 'verified_artisan_active'.trSafe('Active on Marketplace • Receiving Bookings'),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF15803D),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Live Radar Scanner Empty State (Awaiting KYC) ──
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
              'When a feature-phone artisan registers via the Dial Karya voice line, they will appear here automatically for peer KYC verification.',
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
        ],
      ),
    );
  }

  // ── Empty State for "Verified by You" ──
  Widget _buildEmptyVerifiedState() {
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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14059669),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFF15803D),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'no_verified_by_you'.trSafe('No Dial Artisans Verified Yet'),
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
            'no_verified_by_you_sub'.trSafe(
              'When you verify a feature-phone artisan awaiting KYC, they will appear here as your verified referral with ₹150 bounty credited to your wallet.',
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
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedTab = 0);
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFFB45309)),
            label: Text(
              'btn_view_awaiting'.trSafe('View Artisans Awaiting KYC'),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFB45309),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFFFBEB),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFFDE68A)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
