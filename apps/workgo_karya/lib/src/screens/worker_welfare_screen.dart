import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

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
              "Welfare & Insurance",
              style: WorkGoFonts.heading(
                color: KX.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              "Artisan Protection & Welfare Pool",
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

