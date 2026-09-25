import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

/// Cooperative Resolutions and AGM Voting Screen (SIH 26089).
///
/// Provides the fundamental democratic governance required by cooperative
/// federation standards: 1-member-1-vote on welfare allocation, floor wage
/// revisions, patronage dividend, and cooperative policy resolutions.
///
/// Security model:
///   - Votes are recorded with a cryptographic vote receipt (SHA-256 of
///     workerId + resolutionId + choice + timestamp).
///   - One vote per worker per resolution enforced at the Firestore document
///     level (workerId is a key in the votes subcollection).
///   - No vote can be changed once submitted (Firestore write-once on path
///     cooperative_resolutions/{id}/votes/{workerId}).
class CooperativeVotingScreen extends StatefulWidget {
  const CooperativeVotingScreen({super.key, required this.worker});
  final Worker worker;

  @override
  State<CooperativeVotingScreen> createState() =>
      _CooperativeVotingScreenState();
}

class _CooperativeVotingScreenState extends State<CooperativeVotingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isCasting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _generateVoteReceipt(String resolutionId, String choice) {
    final raw =
        '${widget.worker.id}|$resolutionId|$choice|${DateTime.now().millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 16).toUpperCase();
  }

  Future<void> _castVote(
    BuildContext ctx, {
    required String resolutionId,
    required String resolutionTitle,
    required String choice,
  }) async {
    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'coop_voting_cast_confirm_title'.tr(),
          style: WorkGoFonts.heading(
            color: KX.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resolutionTitle,
              style: WorkGoFonts.body(
                color: KX.textSecondary,
                fontSize: 13,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _choiceColor(choice).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _choiceColor(choice).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(_choiceIcon(choice),
                      color: _choiceColor(choice), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _choiceLabel(choice),
                      style: WorkGoFonts.heading(
                        color: _choiceColor(choice),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'coop_voting_cast_confirm_desc'.tr(),
              style: WorkGoFonts.body(
                color: KX.textMuted,
                fontSize: 11.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: Text(
              'cancel'.trSafe('Cancel'),
              style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 13),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _choiceColor(choice),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(
              'coop_voting_cast_btn'.tr(),
              style: WorkGoFonts.heading(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCasting = true);
    try {
      final receipt = _generateVoteReceipt(resolutionId, choice);
      await FirebaseFirestore.instance
          .collection('cooperative_resolutions')
          .doc(resolutionId)
          .collection('votes')
          .doc(widget.worker.id)
          .set({
        'workerId': widget.worker.id,
        'workerName': widget.worker.name,
        'choice': choice,
        'votedAt': FieldValue.serverTimestamp(),
        'voteReceipt': receipt,
      });

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF065F46),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              'coop_voting_vote_receipt'.tr(args: [receipt]),
              style: WorkGoFonts.body(color: Colors.white, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: KX.rose,
            content: Text(
              'error_unknown'.trSafe('Something went wrong. Please try again.'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCasting = false);
    }
  }

  Color _choiceColor(String choice) {
    switch (choice) {
      case 'for':
        return const Color(0xFF065F46);
      case 'against':
        return KX.rose;
      case 'abstain':
        return KX.textSecondary;
      default:
        return KX.gold;
    }
  }

  IconData _choiceIcon(String choice) {
    switch (choice) {
      case 'for':
        return Icons.thumb_up_rounded;
      case 'against':
        return Icons.thumb_down_rounded;
      case 'abstain':
        return Icons.remove_circle_outline_rounded;
      default:
        return Icons.how_to_vote_rounded;
    }
  }

  String _choiceLabel(String choice) {
    switch (choice) {
      case 'for':
        return 'coop_voting_for'.tr();
      case 'against':
        return 'coop_voting_against'.tr();
      case 'abstain':
        return 'coop_voting_abstain'.tr();
      default:
        return choice;
    }
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'welfare':
        return 'coop_voting_category_welfare'.tr();
      case 'wages':
        return 'coop_voting_category_wages'.tr();
      case 'dividend':
        return 'coop_voting_category_dividend'.tr();
      case 'policy':
        return 'coop_voting_category_policy'.tr();
      default:
        return cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KX.canvas,
      appBar: AppBar(
        backgroundColor: KX.canvas,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: KX.dividerLight),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: KX.textPrimary),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'coop_voting_title'.tr(),
              style: WorkGoFonts.heading(
                  color: KX.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'coop_voting_subtitle'.tr(),
              style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: KX.gold,
          labelColor: KX.gold,
          unselectedLabelColor: KX.textSecondary,
          labelStyle: WorkGoFonts.heading(
              fontSize: 12.5, fontWeight: FontWeight.w800),
          unselectedLabelStyle:
              WorkGoFonts.body(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [
            Tab(
              child: Text(
                'coop_voting_active_tab'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tab(
              child: Text(
                'coop_voting_history_tab'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveResolutionsTab(),
          _buildVotingHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildActiveResolutionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cooperative_resolutions')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _buildResolutionCard(
              context: ctx,
              resolutionId: docs[i].id,
              data: d,
              isHistory: false,
            );
          },
        );
      },
    );
  }

  Widget _buildVotingHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cooperative_resolutions')
          .where('status', whereIn: ['passed', 'rejected', 'closed'])
          .orderBy('closedAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _buildResolutionCard(
              context: ctx,
              resolutionId: docs[i].id,
              data: d,
              isHistory: true,
            );
          },
        );
      },
    );
  }

  Widget _buildResolutionCard({
    required BuildContext context,
    required String resolutionId,
    required Map<String, dynamic> data,
    required bool isHistory,
  }) {
    final title = data['title'] as String? ?? 'Cooperative Resolution';
    final description = data['description'] as String? ?? '';
    final category = data['category'] as String? ?? 'policy';
    final forVotes = (data['forVotes'] as num?)?.toInt() ?? 0;
    final againstVotes = (data['againstVotes'] as num?)?.toInt() ?? 0;
    final abstainVotes = (data['abstainVotes'] as num?)?.toInt() ?? 0;
    final totalMembers = (data['totalMembers'] as num?)?.toInt() ?? 1;
    final totalVoted = forVotes + againstVotes + abstainVotes;
    final status = data['status'] as String? ?? 'active';

    final closesAt = data['closesAt'];
    String? closesAtStr;
    if (closesAt is Timestamp) {
      closesAtStr = DateFormat('d MMM yyyy, hh:mm a').format(closesAt.toDate());
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cooperative_resolutions')
          .doc(resolutionId)
          .collection('votes')
          .doc(widget.worker.id)
          .snapshots(),
      builder: (ctx, voteSnap) {
        final hasVoted = voteSnap.data?.exists == true;
        final myVote = voteSnap.data?.exists == true
            ? (voteSnap.data!.data() as Map<String, dynamic>)['choice']
                as String?
            : null;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: KX.dividerLight),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge + status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3D6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: KX.gold.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        _categoryLabel(category),
                        style: WorkGoFonts.heading(
                            color: KX.amberDark,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (hasVoted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF065F46), size: 11),
                            const SizedBox(width: 4),
                            Text(
                              'coop_voting_voted_badge'.tr(),
                              style: WorkGoFonts.heading(
                                  color: const Color(0xFF065F46),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    if (!isHistory)
                      const Icon(Icons.how_to_vote_rounded,
                          color: KX.gold, size: 18),
                    if (isHistory)
                      Icon(
                        status == 'passed'
                            ? Icons.verified_rounded
                            : Icons.cancel_rounded,
                        color: status == 'passed'
                            ? const Color(0xFF065F46)
                            : KX.rose,
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  title,
                  style: WorkGoFonts.heading(
                      color: KX.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: WorkGoFonts.body(
                        color: KX.textSecondary, fontSize: 12.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),

                // Quorum progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'coop_voting_quorum_label'.tr(),
                            style: WorkGoFonts.body(
                                color: KX.textSecondary, fontSize: 11.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'coop_voting_quorum_value'
                              .tr(args: ['$totalVoted', '$totalMembers']),
                          style: WorkGoFonts.heading(
                              color: KX.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalMembers > 0
                            ? (totalVoted / totalMembers).clamp(0.0, 1.0)
                            : 0.0,
                        backgroundColor: const Color(0xFFF3F4F6),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(KX.gold),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Vote tallies
                Row(
                  children: [
                    Expanded(
                      child: _buildTallyChip(
                        'coop_voting_for_tally'.tr(args: ['$forVotes']),
                        const Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildTallyChip(
                        'coop_voting_against_tally'
                            .tr(args: ['$againstVotes']),
                        KX.rose,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildTallyChip(
                        'coop_voting_abstain_tally'
                            .tr(args: ['$abstainVotes']),
                        KX.textSecondary,
                      ),
                    ),
                  ],
                ),

                // Close date
                if (closesAtStr != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 12, color: KX.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'coop_voting_closes_at'.tr(args: [closesAtStr]),
                          style: WorkGoFonts.body(
                              color: KX.textMuted, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // My previous vote (if voted)
                if (hasVoted && myVote != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          _choiceColor(myVote).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              _choiceColor(myVote).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(_choiceIcon(myVote),
                            size: 13, color: _choiceColor(myVote)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _choiceLabel(myVote),
                            style: WorkGoFonts.heading(
                                color: _choiceColor(myVote),
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action buttons (only for active, unvoted)
                if (!isHistory && !hasVoted) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildVoteButton(
                          context: context,
                          resolutionId: resolutionId,
                          resolutionTitle: title,
                          choice: 'for',
                          isCasting: _isCasting,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildVoteButton(
                          context: context,
                          resolutionId: resolutionId,
                          resolutionTitle: title,
                          choice: 'against',
                          isCasting: _isCasting,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildVoteButton(
                        context: context,
                        resolutionId: resolutionId,
                        resolutionTitle: title,
                        choice: 'abstain',
                        isCasting: _isCasting,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTallyChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: WorkGoFonts.heading(
              color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildVoteButton({
    required BuildContext context,
    required String resolutionId,
    required String resolutionTitle,
    required String choice,
    required bool isCasting,
  }) {
    final isAbstain = choice == 'abstain';
    return ElevatedButton(
      onPressed: isCasting
          ? null
          : () => _castVote(
                context,
                resolutionId: resolutionId,
                resolutionTitle: resolutionTitle,
                choice: choice,
              ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isAbstain ? const Color(0xFFF3F4F6) : _choiceColor(choice),
        foregroundColor: isAbstain ? KX.textSecondary : Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          vertical: 10,
          horizontal: isAbstain ? 10 : 0,
        ),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isCasting
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_choiceIcon(choice), size: 13),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _choiceLabel(choice),
                    style: WorkGoFonts.heading(
                        fontSize: 11.5, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3D6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.how_to_vote_rounded,
                  color: KX.gold, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'coop_voting_title'.tr(),
              style: WorkGoFonts.heading(
                  color: KX.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'coop_voting_no_resolutions'.tr(),
              style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 13),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
