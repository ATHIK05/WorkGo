import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

class WorkerWelfareScreen extends StatelessWidget {
  const WorkerWelfareScreen({super.key, required this.worker});
  final Worker worker;

  @override
  Widget build(BuildContext context) {
    final workerService = WorkerService();

    return KaryaScaffold(
      appBar: KaryaAppBar(
        title: 'welfare_status'.tr(),
        subtitle: "Tamil Nadu Cooperative Artisan Welfare Pool",
      ),
      body: SafeArea(
        child: StreamBuilder<Worker?>(
          stream: workerService.streamWorker(worker.id),
          initialData: worker,
          builder: (context, snapshot) {
            final liveWorker = snapshot.data ?? worker;
            final isEnrolled = liveWorker.insuranceStatus;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Digital Holographic ID Shield
                  KSlideFadeIn(
                    child: _DigitalArtisanShieldCard(
                      worker: liveWorker,
                      isEnrolled: isEnrolled,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Policy Specs Grid
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 40),
                    child: _PolicySpecsCard(isEnrolled: isEnrolled),
                  ),
                  const SizedBox(height: 14),

                  // ── Active Benefits Header
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      "Cooperative Artisan Protection",
                      style: WorkGoFonts.display(
                        color: KX.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Scheme 1: Accident (PMSBY)
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 100),
                    child: _SchemeBenefitCard(
                      title: "Accidental Disability Cover (PMSBY)",
                      subtitle: "₹2,00,000 on-duty emergency protection",
                      icon: Icons.security_rounded,
                      isEnrolled: isEnrolled,
                      gradient: KX.luminaVioletGold,
                      glowColor: KX.gold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Scheme 2: Life (PMJJBY)
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 120),
                    child: _SchemeBenefitCard(
                      title: "Life Insurance (PMJJBY)",
                      subtitle: "₹2,00,000 family protection with zero fees",
                      icon: Icons.favorite_rounded,
                      isEnrolled: isEnrolled,
                      gradient: KX.auroraVioletNeon,
                      glowColor: KX.violetNeon,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Scheme 3: Medical Relief
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 140),
                    child: _SchemeBenefitCard(
                      title: "Emergency Micro-Relief",
                      subtitle: "Instant zero-interest relief loan up to ₹25,000",
                      icon: Icons.medical_services_rounded,
                      isEnrolled: isEnrolled,
                      gradient: KX.solarGold,
                      glowColor: KX.gold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 24/7 Helpline
                  KSlideFadeIn(
                    delay: const Duration(milliseconds: 160),
                    child: _HelplineDeskCard(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  DIGITAL ARTISAN HOLOGRAPHIC SHIELD ID CARD
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

    return KaryaCard(
      glowColor: isEnrolled ? KX.gold : KX.violet,
      borderColor: (isEnrolled ? KX.gold : KX.violetNeon).withValues(alpha: 0.4),
      gradient: LinearGradient(
        colors: [
          KX.canvasCard,
          KX.violet.withValues(alpha: 0.20),
          KX.canvasElevated,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isEnrolled ? KX.luminaVioletGold : KX.auroraOffline,
                      boxShadow: isEnrolled
                          ? [
                              BoxShadow(
                                color: KX.gold.withValues(alpha: 0.5),
                                blurRadius: 16,
                                spreadRadius: -2,
                              ),
                            ]
                          : null,
                    ),
                    child: const Center(
                      child: Icon(Icons.shield_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnrolled
                            ? "Welfare Shield Active"
                            : "Enrollment Pending",
                        style: WorkGoFonts.display(
                          color: KX.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Member ID: #$shortId",
                        style: WorkGoFonts.badge(
                          color: KX.gold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              KaryaBadge(
                label: isEnrolled ? "COVERED ✓" : "PENDING",
                style: isEnrolled ? KaryaBadgeStyle.gold : KaryaBadgeStyle.violet,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: KX.glassBorder, height: 1),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Co-op Group Health & Accident Coverage",
                style: WorkGoFonts.body(
                  color: KX.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                "₹2,00,000",
                style: WorkGoFonts.numeric(
                  color: KX.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
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
//  POLICY SPECS CARD
// ──────────────────────────────────────────────────────────────
class _PolicySpecsCard extends StatelessWidget {
  const _PolicySpecsCard({required this.isEnrolled});
  final bool isEnrolled;

  @override
  Widget build(BuildContext context) {
    return KaryaCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      child: Row(
        children: [
          Expanded(
            child: _spec(
              "Max Coverage",
              "₹2.0 Lakhs",
              KX.gold,
            ),
          ),
          Container(width: 1, height: 26, color: KX.glassBorder),
          Expanded(
            child: _spec(
              "Worker Premium",
              "₹0 / Free",
              KX.emeraldLight,
            ),
          ),
          Container(width: 1, height: 26, color: KX.glassBorder),
          Expanded(
            child: _spec(
              "Deductible",
              "₹0 (Co-op)",
              KX.violetLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _spec(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: WorkGoFonts.numeric(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: WorkGoFonts.body(
            color: KX.textSecondary,
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  SCHEME BENEFIT CARD
// ──────────────────────────────────────────────────────────────
class _SchemeBenefitCard extends StatelessWidget {
  const _SchemeBenefitCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.isEnrolled,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final Color glowColor;
  final bool isEnrolled;

  @override
  Widget build(BuildContext context) {
    return KaryaCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      borderRadius: 14,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: WorkGoFonts.heading(
                    color: KX.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: WorkGoFonts.body(
                    color: KX.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          KaryaBadge(
            label: isEnrolled ? "ACTIVE" : "PENDING",
            style: isEnrolled ? KaryaBadgeStyle.gold : KaryaBadgeStyle.violet,
            fontSize: 8.5,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  HELPLINE DESK CARD
// ──────────────────────────────────────────────────────────────
class _HelplineDeskCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return KaryaCard(
      glowColor: KX.violet,
      borderColor: KX.violetNeon.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: KX.auroraVioletNeon,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cooperative Welfare Claim Desk",
                  style: WorkGoFonts.heading(
                    color: KX.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  "24/7 dedicated assistance for claims",
                  style: WorkGoFonts.body(
                    color: KX.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Connecting to Cooperative Claim Desk (1800-425-WORKGO)…"),
                  backgroundColor: KX.violet,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: KX.luminaVioletGold,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: KX.gold.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.phone_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
