import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';
import 'cooperative_voting_screen.dart';
import 'welfare_claim_submission_screen.dart';

class WorkerWelfareScreen extends StatelessWidget {
  const WorkerWelfareScreen({
    super.key,
    required this.worker,
    this.welfareShieldKey,
  });
  final Worker worker;
  final GlobalKey? welfareShieldKey;

  @override
  Widget build(BuildContext context) {
    final workerService = WorkerService();

    return Scaffold(
      backgroundColor: KX.canvas,
      appBar: AppBar(
        backgroundColor: KX.canvas,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF0EDE6)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: KX.textPrimary),
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "welfare_insurance_title".trSafe("Welfare & Insurance"),
              style: WorkGoFonts.heading(
                color: KX.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              "welfare_insurance_subtitle".trSafe("Artisan Protection & Welfare Pool"),
              style: WorkGoFonts.body(
                color: KX.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, color: Color(0xFF047857), size: 13),
                SizedBox(width: 4),
                Text(
                  "ACTIVE",
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<Worker?>(
          stream: workerService.streamWorker(worker.id),
          initialData: worker,
          builder: (context, snapshot) {
            final liveWorker = snapshot.data ?? worker;
            final isEnrolled = liveWorker.insuranceStatus;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero Holographic ID Shield Card
                  KeyedSubtree(
                    key: welfareShieldKey,
                    child: _DigitalArtisanShieldCard(
                      worker: liveWorker,
                      isEnrolled: isEnrolled,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 3 Bento Metric Pills
                  _buildBentoSpecsRow(isEnrolled),
                  const SizedBox(height: 18),

                  // ── Protection Schemes Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Active Protection Schemes",
                        style: WorkGoFonts.display(
                          color: KX.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "GOVT. BACKED",
                          style: TextStyle(color: Color(0xFF92400E), fontSize: 9.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Scheme 1: Accident (PMSBY)
                  _SchemeBenefitCard(
                    title: "Accidental Disability Cover (PMSBY)",
                    subtitle: "24/7 on-duty emergency protection across all job dispatches",
                    amount: "₹2,00,000",
                    badgeColor: const Color(0xFFD6EBFF),
                    badgeTextColor: const Color(0xFF1E3A8A),
                    icon: Icons.security_rounded,
                    isEnrolled: isEnrolled,
                  ),
                  const SizedBox(height: 10),

                  // ── Scheme 2: Life (PMJJBY)
                  _SchemeBenefitCard(
                    title: "Artisan Life Insurance (PMJJBY)",
                    subtitle: "Zero-fee family security & nominee welfare disbursement",
                    amount: "₹2,00,000",
                    badgeColor: const Color(0xFFD1FAE5),
                    badgeTextColor: const Color(0xFF065F46),
                    icon: Icons.favorite_rounded,
                    isEnrolled: isEnrolled,
                  ),
                  const SizedBox(height: 10),

                  // ── Scheme 3: Medical Relief
                  _SchemeBenefitCard(
                    title: "Medical & Emergency Micro-Relief",
                    subtitle: "Instant 0% interest cooperative emergency advance",
                    amount: "₹25,000",
                    badgeColor: const Color(0xFFFFE0A3),
                    badgeTextColor: const Color(0xFF92400E),
                    icon: Icons.medical_services_rounded,
                    isEnrolled: isEnrolled,
                  ),

                  // ── File a Welfare Claim Hero Action Card
                  _FileClaimCard(worker: liveWorker),
                  const SizedBox(height: 14),

                  // ── Cooperative AGM Voting Entry Card
                  _CoopVotingEntryCard(worker: liveWorker),
                  const SizedBox(height: 16),

                  // ── Live Claims Tracking Section
                  _WorkerClaimsTrackingSection(workerId: liveWorker.id),
                  const SizedBox(height: 16),

                  // ── 24/7 Helpline & Claim Desk Card
                  _HelplineDeskCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBentoSpecsRow(bool isEnrolled) {
    return Row(
      children: [
        Expanded(
          child: _bentoSpec(
            "Worker Premium",
            "₹0 / Free",
            const Color(0xFFD1FAE5),
            const Color(0xFF065F46),
            Icons.money_off_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _bentoSpec(
            "Deductible",
            "₹0 (Co-op)",
            const Color(0xFFD6EBFF),
            const Color(0xFF1E3A8A),
            Icons.verified_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _bentoSpec(
            "Claim Time",
            "< 24 Hours",
            const Color(0xFFFFE0A3),
            const Color(0xFF92400E),
            Icons.bolt_rounded,
          ),
        ),
      ],
    );
  }

  Widget _bentoSpec(String label, String value, Color bgColor, Color textColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  DIGITAL ARTISAN HOLOGRAPHIC SHIELD ID CARD (Luxury White & Amber)
// ──────────────────────────────────────────────────────────────
class _DigitalArtisanShieldCard extends StatelessWidget {
  const _DigitalArtisanShieldCard({
    required this.worker,
    required this.isEnrolled,
  });

  final Worker worker;
  final bool isEnrolled;

  @override
  Widget build(BuildContext context) {
    final shortId = worker.id.length > 8
        ? worker.id.substring(0, 8).toUpperCase()
        : worker.id.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Shield Avatar + Member Info + Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFE0A3),
                      ),
                      child: const Center(
                        child: Icon(Icons.shield_rounded, color: Color(0xFF92400E), size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            worker.name.isNotEmpty ? worker.name : "Cooperative Artisan",
                            style: WorkGoFonts.display(
                              color: KX.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.badge_outlined, size: 11, color: Color(0xFF6B6B6B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "Policy #TN-COOP-$shortId",
                                  style: const TextStyle(
                                    color: Color(0xFF6B6B6B),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isEnrolled ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (isEnrolled ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.3)),
                ),
                child: Text(
                  isEnrolled ? "COVERED ✓" : "ENROLLING",
                  style: TextStyle(
                    color: isEnrolled ? const Color(0xFF065F46) : const Color(0xFF92400E),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF0EDE6), height: 1),
          const SizedBox(height: 14),

          // Total Coverage Amount Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Protective Shield",
                    style: WorkGoFonts.body(
                      color: const Color(0xFF6B6B6B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "₹2,00,000",
                    style: WorkGoFonts.numeric(
                      color: const Color(0xFF141416),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F6EE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF0EDE6)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.health_and_safety_rounded, color: Color(0xFF10B981), size: 14),
                    SizedBox(width: 4),
                    Text(
                      "PMSBY + PMJJBY",
                      style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  SCHEME BENEFIT CARD (24px Modern Card)
// ──────────────────────────────────────────────────────────────
class _SchemeBenefitCard extends StatelessWidget {
  const _SchemeBenefitCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.icon,
    required this.isEnrolled,
  });

  final String title;
  final String subtitle;
  final String amount;
  final Color badgeColor;
  final Color badgeTextColor;
  final IconData icon;
  final bool isEnrolled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: badgeTextColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: WorkGoFonts.heading(
                    color: KX.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: WorkGoFonts.body(
                    color: const Color(0xFF6B6B6B),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: WorkGoFonts.numeric(
                  color: const Color(0xFF141416),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "ACTIVE",
                  style: TextStyle(color: Color(0xFF065F46), fontSize: 8.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  HELPLINE & CLAIM DESK CARD (Obsidian Dark Luxury Pill)
// ──────────────────────────────────────────────────────────────
class _HelplineDeskCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF26262B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded, color: Color(0xFFFFB800), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Cooperative Welfare Desk",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "24/7 Toll-Free Claim Support",
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Connecting to Cooperative Claim Desk (1800-425-WORKGO)…"),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
            },
            icon: const Icon(Icons.phone_rounded, size: 14),
            label: const Text("Call Desk", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB800),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  FILE A WELFARE CLAIM ACTION CARD
// ──────────────────────────────────────────────────────────────
class _FileClaimCard extends StatelessWidget {
  const _FileClaimCard({required this.worker});
  final Worker worker;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x33FFB800),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFFFFB800), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "File Welfare / Insurance Claim",
                      style: WorkGoFonts.heading(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "PMSBY / PMJJBY on-duty accident or medical emergency claims",
                      style: WorkGoFonts.body(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Upload doctor certificates, incident photos, and corroborate with past bookings for expedited administrative settlement.",
            style: WorkGoFonts.body(
              color: const Color(0xFFCBD5E1),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => WelfareClaimSubmissionScreen(worker: worker),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: Text(
                "Submit Micro-Insurance Claim",
                style: WorkGoFonts.heading(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB800),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  WORKER CLAIMS TRACKING SECTION
// ──────────────────────────────────────────────────────────────
class _WorkerClaimsTrackingSection extends StatelessWidget {
  const _WorkerClaimsTrackingSection({required this.workerId});
  final String workerId;

  @override
  Widget build(BuildContext context) {
    final welfareService = WelfareService();

    return StreamBuilder<List<WelfareClaim>>(
      stream: welfareService.streamWorkerClaims(workerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final claims = snapshot.data ?? [];
        if (claims.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Color(0xFF9CA3AF), size: 36),
                const SizedBox(height: 10),
                Text(
                  "No Welfare Claims Submitted",
                  style: WorkGoFonts.heading(
                    color: KX.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "When you submit an emergency or disability claim, its review progress will be tracked here in real-time.",
                  textAlign: TextAlign.center,
                  style: WorkGoFonts.body(
                    color: KX.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "My Submitted Claims",
                  style: WorkGoFonts.display(
                    color: KX.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${claims.length} Filed",
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: claims.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final claim = claims[index];
                final statusLower = claim.status.toLowerCase();

                Color badgeBg;
                Color badgeFg;
                String statusLabel;
                IconData statusIcon;

                if (statusLower == "approved") {
                  badgeBg = const Color(0xFFD1FAE5);
                  badgeFg = const Color(0xFF065F46);
                  statusLabel = "Approved";
                  statusIcon = Icons.check_circle_rounded;
                } else if (statusLower == "rejected") {
                  badgeBg = const Color(0xFFFEE2E2);
                  badgeFg = const Color(0xFF991B1B);
                  statusLabel = "Rejected";
                  statusIcon = Icons.cancel_rounded;
                } else {
                  badgeBg = const Color(0xFFFEF3C7);
                  badgeFg = const Color(0xFF92400E);
                  statusLabel = "Under Review";
                  statusIcon = Icons.hourglass_top_rounded;
                }

                final shortId = claim.id.length > 8 ? claim.id.substring(0, 8).toUpperCase() : claim.id.toUpperCase();
                final submittedStr = "${claim.submittedAt.day.toString().padLeft(2, '0')}/${claim.submittedAt.month.toString().padLeft(2, '0')}/${claim.submittedAt.year}";

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF0EDE6)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
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
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(statusIcon, color: badgeFg, size: 14),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Claim #$shortId",
                                style: WorkGoFonts.heading(
                                  color: KX.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: badgeFg,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (claim.description.isNotEmpty) ...[
                        Text(
                          claim.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: WorkGoFonts.body(
                            color: const Color(0xFF4B5563),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Filed on $submittedStr",
                            style: WorkGoFonts.body(
                              color: KX.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          if (claim.bookingId != null && claim.bookingId!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Booking: #${claim.bookingId!.length > 6 ? claim.bookingId!.substring(0, 6).toUpperCase() : claim.bookingId!.toUpperCase()}",
                                style: WorkGoFonts.numeric(
                                  color: const Color(0xFF4B5563),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
      },
    );
  }
}

/// Navigation alias for WorkerWelfareScreen
typedef WorkerWelfareManagementScreen = WorkerWelfareScreen;

// ── Cooperative AGM Voting Entry Card ─────────────────────────────────────────
class _CoopVotingEntryCard extends StatelessWidget {
  const _CoopVotingEntryCard({required this.worker});
  final Worker worker;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CooperativeVotingScreen(worker: worker),
          ));
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: KX.gold.withValues(alpha: 0.35)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.how_to_vote_rounded,
                    color: KX.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'coop_voting_entry_btn'.tr(),
                      style: WorkGoFonts.heading(
                        color: KX.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'coop_voting_entry_desc'.tr(),
                      style: WorkGoFonts.body(
                          color: KX.textSecondary, fontSize: 11.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: KX.gold, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}


