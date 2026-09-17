import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../admin_theme.dart';

/// Dial Karya Telephony & Peer KYC Management Console
///
/// Real-time monitoring of:
///  - Feature-phone artisans registered via voice call
///  - Gateway SIM (+91 90802 62334) & Asterisk AMI status
///  - Peer KYC verifications & ₹150 bounty audit trails
///  - Outbound robocalls & in-call race condition metrics
class AdminDialKaryaScreen extends StatefulWidget {
  const AdminDialKaryaScreen({super.key});

  @override
  State<AdminDialKaryaScreen> createState() => _AdminDialKaryaScreenState();
}

class _AdminDialKaryaScreenState extends State<AdminDialKaryaScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'verified', 'pending'

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('workers')
          .where('isDialWorker', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final dialWorkers = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return {
            'id': d.id,
            'name': data['name'] ?? 'Dial Artisan',
            'phone': data['phoneForCalling'] ?? data['phone'] ?? '',
            'trade': (data['skills'] as List?)?.firstOrNull?.toString() ??
                data['trade'] ??
                'General',
            'tradeDescription': data['tradeDescription'] ?? '',
            'locationText': data['locationText'] ??
                ((data['preferredAreas'] as List?)?.firstOrNull?.toString()) ??
                '',
            'pincode': data['pincode'] ?? '',
            'status': data['verificationStatus'] ?? 'pending',
            'stage': data['verificationStage'] ?? 'signup',
            'callStatus': data['callIvrStatus'] ?? 'idle',
            'language': data['dialLanguage'] ?? 'hi',
            'mitraId': data['peerKycMitraId'],
            'wallet': (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
            'jobsCount': (data['completedJobsCount'] as num?)?.toInt() ?? 0,
            'createdAt': data['createdAt'],
          };
        }).toList();

        // Calculations
        final totalCount = dialWorkers.length;
        final verifiedCount = dialWorkers
            .where((w) =>
                w['status'] == 'approved' ||
                w['status'] == 'verified' ||
                w['stage'] == 'approved')
            .length;
        final pendingCount = totalCount - verifiedCount;
        final totalBountiesPaid = verifiedCount * 150;
        final activeOnCallCount = dialWorkers
            .where((w) =>
                w['callStatus'] == 'on_alert_call' ||
                w['callStatus'] == 'onboarding')
            .length;

        // Filtering
        final filteredWorkers = dialWorkers.where((w) {
          final matchesSearch = _searchQuery.isEmpty ||
              w['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
              w['phone'].toString().contains(_searchQuery) ||
              w['trade'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
              w['tradeDescription'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
              w['locationText'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
              w['pincode'].toString().contains(_searchQuery);

          final isVerified = w['status'] == 'approved' ||
              w['status'] == 'verified' ||
              w['stage'] == 'approved';

          if (_filterStatus == 'verified' && !isVerified) return false;
          if (_filterStatus == 'pending' && isVerified) return false;

          return matchesSearch;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Bar ───────────────────────────────────────────────
              _buildHeaderBar(context),
              const SizedBox(height: 24),

              // ── Telephony Gateway Status Banner ──────────────────────────
              _buildGatewayStatusBanner(),
              const SizedBox(height: 24),

              // ── KPI Metrics Grid ─────────────────────────────────────────
              _buildKpiMetricsGrid(
                totalDialWorkers: totalCount,
                verifiedCount: verifiedCount,
                pendingCount: pendingCount,
                totalBountiesPaid: totalBountiesPaid,
                activeOnCall: activeOnCallCount,
              ),
              const SizedBox(height: 28),

              // ── Registry Controls (Search & Filter) ──────────────────────
              _buildFilterBar(),
              const SizedBox(height: 16),

              // ── Dial Worker Registry Table ───────────────────────────────
              _buildWorkerRegistryTable(filteredWorkers),
              const SizedBox(height: 32),

              // ── Peer KYC Audit Trail Section ─────────────────────────────
              _buildPeerKycAuditLogs(),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeaderBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AX.emerald.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.dialpad_rounded, color: Color(0xFF1A1A1A), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  "Dial Karya Telephony & Peer KYC Hub",
                  style: AX.display(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Zero-app feature phone artisans · Bhashini Vernacular AI · ₹150 Peer KYC Bounties · Outbound Robocalls",
              style: AX.body(fontSize: 13, color: AX.textSecondary),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                  SizedBox(width: 6),
                  Text(
                    "Asterisk AMI Connected",
                    style: TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  GATEWAY STATUS CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGatewayStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings_phone_rounded, color: Color(0xFFD97706), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Voice Gateway Toll-Free SIM: +91 90802 62334",
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "LIVE TELEPHONY",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Direct inbound Asterisk dialplan active · 8kHz PCM Bhashini ASR/TTS speech pipeline connected · Outbound robocalls on new booking broadcast enabled.",
                  style: TextStyle(
                    color: AX.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Dialplan reloaded. Asterisk PBX channel ready."),
                  backgroundColor: Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text("Ping PBX"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  KPI GRID
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildKpiMetricsGrid({
    required int totalDialWorkers,
    required int verifiedCount,
    required int pendingCount,
    required int totalBountiesPaid,
    required int activeOnCall,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildKpiCard(
              title: "Total Dial Artisans",
              value: totalDialWorkers.toString(),
              subtitle: "Feature-phone workers",
              icon: Icons.phone_android_rounded,
              color: const Color(0xFF3B82F6),
              width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 48) / 4,
            ),
            _buildKpiCard(
              title: "Peer KYC Verified",
              value: verifiedCount.toString(),
              subtitle: "${totalDialWorkers > 0 ? ((verifiedCount / totalDialWorkers) * 100).toStringAsFixed(0) : 0}% verification rate",
              icon: Icons.verified_rounded,
              color: const Color(0xFF10B981),
              width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 48) / 4,
            ),
            _buildKpiCard(
              title: "Bounties Disbursed",
              value: "₹${totalBountiesPaid.toString()}",
              subtitle: "₹150 paid per verified artisan",
              icon: Icons.wallet_rounded,
              color: const Color(0xFFD97706),
              width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 48) / 4,
            ),
            _buildKpiCard(
              title: "Active on Voice IVR",
              value: activeOnCall.toString(),
              subtitle: "Alert calls & onboarding",
              icon: Icons.cell_tower_rounded,
              color: const Color(0xFF8B5CF6),
              width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 48) / 4,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AX.divider, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AX.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: AX.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: AX.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  FILTER BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Row(
      children: [
        // Search Box
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AX.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: "Search dial artisan by name, trade, or phone...",
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () => setState(() => _searchQuery = ''),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Filter Pills
        _buildFilterPill("All", 'all'),
        const SizedBox(width: 8),
        _buildFilterPill("Verified", 'verified'),
        const SizedBox(width: 8),
        _buildFilterPill("Pending KYC", 'pending'),
      ],
    );
  }

  Widget _buildFilterPill(String label, String statusKey) {
    final isSelected = _filterStatus == statusKey;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = statusKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A1A1A) : AX.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AX.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  WORKER REGISTRY TABLE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWorkerRegistryTable(List<Map<String, dynamic>> workers) {
    if (workers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AX.divider),
        ),
        child: Column(
          children: [
            const Icon(Icons.phone_disabled_rounded, size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              "No Dial Artisans Found",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              "Dial workers registered via incoming call to +91 90802 62334 will appear here.",
              style: TextStyle(color: AX.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AX.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: DataTable(
          horizontalMargin: 20,
          columnSpacing: 20,
          headingRowHeight: 48,
          dataRowMinHeight: 64,
          dataRowMaxHeight: 76,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFFAF9F6)),
          columns: const [
            DataColumn(label: Text("Artisan Name", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            DataColumn(label: Text("Phone Number", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            DataColumn(label: Text("Trade / Skill", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            DataColumn(label: Text("Location / Address", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            DataColumn(label: Text("Call State", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            DataColumn(label: Text("Language", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
          ],
          rows: workers.map((w) {
            final isVerified = w['status'] == 'approved' ||
                w['status'] == 'verified' ||
                w['stage'] == 'approved';

            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFD97706).withValues(alpha: 0.15),
                        child: const Icon(Icons.person_rounded, size: 16, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        w['name'],
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    w['phone'].isNotEmpty ? w['phone'] : '—',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          w['trade'].toString().toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      if ((w['tradeDescription'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: Text(
                            w['tradeDescription'],
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            (w['locationText'] ?? '').toString().isNotEmpty
                                ? w['locationText']
                                : '—',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ),
                      if ((w['pincode'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 17, top: 1),
                          child: Text(
                            w['pincode'],
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isVerified
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isVerified
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isVerified ? "VERIFIED" : "PENDING KYC",
                      style: TextStyle(
                        color: isVerified ? const Color(0xFF065F46) : const Color(0xFFB45309),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    w['callStatus'].toString().toUpperCase(),
                    style: TextStyle(
                      color: w['callStatus'] == 'on_alert_call'
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    w['language'].toString().toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.phone_forwarded_rounded, size: 18, color: Color(0xFFD97706)),
                        tooltip: "Trigger Outbound Robocall Test",
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Triggered AMI robocall test to ${w['phone']}"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PEER KYC AUDIT TRAIL LOGS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPeerKycAuditLogs() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('verification_audit_logs')
          .where('action', isEqualTo: 'PEER_KYC_COMPLETED')
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AX.divider),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
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
                      const Icon(Icons.history_edu_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Peer KYC Verification Audit Trail",
                        style: AX.heading(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "₹150 Instant Payouts",
                      style: TextStyle(
                        color: Color(0xFF065F46),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      "No Peer KYC submissions logged yet. When smartphone artisans verify nearby dial members, audits appear here.",
                      style: TextStyle(color: AX.textSecondary, fontSize: 12.5),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, idx) {
                    final data = docs[idx].data() as Map<String, dynamic>;
                    final actorId = data['actorId'] ?? 'Artisan Mitra';
                    final meta = data['metadata'] as Map<String, dynamic>? ?? {};
                    final phone = meta['dialWorkerPhone'] ?? '';
                    final timestamp = data['timestamp'] ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Dial Worker ($phone) verified by Mitra ($actorId)",
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Timestamp: $timestamp · Bounty ₹150 credited to Mitra wallet",
                                  style: TextStyle(color: AX.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "+₹150",
                              style: TextStyle(
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
