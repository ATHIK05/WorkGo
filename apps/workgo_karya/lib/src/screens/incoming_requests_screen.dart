import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';
import 'active_job_screen.dart';

class IncomingRequestsScreen extends StatelessWidget {
  const IncomingRequestsScreen({super.key, required this.worker});
  final Worker worker;

  @override
  Widget build(BuildContext context) {
    final bookingService = BookingService();

    return KaryaScaffold(
      appBar: KaryaAppBar(
        title: 'incoming_job_alerts'.tr(),
        subtitle: "${worker.skills.length} trade skills registered",
      ),
      body: SafeArea(
        child: StreamBuilder<List<Booking>>(
          stream: bookingService.streamWorkerIncomingRequests(
            workerId: worker.id,
            skills: worker.skills,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: 2,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, __) =>
                    const KaryaShimmer(height: 160, borderRadius: 20),
              );
            }

            final requests = snapshot.data ?? [];

            // Play alert sound for new incoming broadcast
            if (requests.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                for (final req in requests) {
                  BroadcastAlertService.instance.playBroadcastAlert(req);
                }
              });
            }

            if (requests.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: KX.auroraVioletNeon,
                          boxShadow: [
                            BoxShadow(
                              color: KX.violetNeon.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.radar_rounded,
                              color: Colors.white, size: 30),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        "Radar Active — Listening for Broadcasts",
                        style: WorkGoFonts.display(
                          color: KX.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "You're live on the cooperative network. When a customer posts a request in your trades (${worker.skills.join(', ')}), an audio chime and dispatch alert will appear here instantly.",
                        style: WorkGoFonts.body(
                          color: KX.textSecondary,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return KSlideFadeIn(
                  delay: Duration(milliseconds: index * 60),
                  child: _LuminaRequestCard(
                    booking: requests[index],
                    worker: worker,
                    service: bookingService,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  LUMINA REQUEST CARD (Cyber Violet + Rapido Broadcast Alert)
// ──────────────────────────────────────────────────────────────
class _LuminaRequestCard extends StatelessWidget {
  const _LuminaRequestCard({
    required this.booking,
    required this.worker,
    required this.service,
  });

  final Booking booking;
  final Worker worker;
  final BookingService service;

  void _showReferPeerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF130E2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFA855F7), width: 1.2),
        ),
        title: Text(
          "Refer Job to Peer Artisan",
          style: WorkGoFonts.heading(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Unable to take this ${booking.serviceType} job? Transfer the dispatch to a verified peer artisan.",
              style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Peer's Name or Contact",
                labelStyle: const TextStyle(color: KX.textSecondary),
                filled: true,
                fillColor: const Color(0xFF1C1536),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("Cancel", style: TextStyle(color: KX.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await service.referBookingToPeer(
                bookingId: booking.id,
                originalWorkerId: worker.id,
                targetWorkerId: "peer_${nameCtrl.text.trim()}",
              );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Job referred to peer! Dispatch transferred."),
                    backgroundColor: KX.emerald,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KX.violetNeon,
              foregroundColor: Colors.white,
            ),
            child: const Text("Transfer Job"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmergency = booking.isEmergency;
    final hasUrgencyBonus = booking.urgencyBonus > 0;
    final totalPayout = booking.totalAmount;
    final accentColor = isEmergency ? KX.rose : (hasUrgencyBonus ? KX.gold : KX.violetNeon);

    final shortId = booking.id.length > 6
        ? booking.id.substring(0, 6).toUpperCase()
        : booking.id.toUpperCase();

    return KaryaCard(
      glowColor: accentColor,
      borderColor: accentColor.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: isEmergency
                      ? KX.auroraDecline
                      : (hasUrgencyBonus ? KX.solarGold : KX.auroraVioletNeon),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(
                  isEmergency ? Icons.bolt_rounded : Icons.handyman_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceType.toLocalizedTrade(),
                      style: WorkGoFonts.display(
                        color: KX.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (hasUrgencyBonus)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: KX.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: KX.gold.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              "+₹${booking.urgencyBonus.toInt()} ${'urgency_tip'.tr().toUpperCase()}",
                              style: WorkGoFonts.badge(color: KX.gold, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          )
                        else
                          KaryaBadge(
                            label: isEmergency ? "emergency".tr().toUpperCase() : "RAPIDO BROADCAST",
                            style: isEmergency ? KaryaBadgeStyle.rose : KaryaBadgeStyle.violet,
                          ),
                        Text(
                          "#$shortId",
                          style: WorkGoFonts.badge(
                            color: KX.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "₹${totalPayout.toStringAsFixed(0)}",
                    style: WorkGoFonts.numeric(
                      color: KX.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  Text(
                    "Net: ₹${(totalPayout * 0.98).toStringAsFixed(0)}",
                    style: WorkGoFonts.numeric(
                      color: KX.emeraldLight,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Details strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: KX.canvasElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.radar_rounded, color: KX.violetLight, size: 14),
                const SizedBox(width: 6),
                Text(
                  "Broadcast in Area (Radius ~${booking.broadcastRadiusKm.toInt()} km)",
                  style: WorkGoFonts.body(
                    color: KX.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showReferPeerDialog(context),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, color: KX.gold, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        "refer_to_peer".tr(),
                        style: WorkGoFonts.heading(
                          color: KX.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Slide to Accept Action
          KaryaSlideAction(
            label: "${'slide_to_accept'.tr()} (₹${totalPayout.toInt()})",
            gradient: isEmergency ? KX.auroraDecline : KX.luminaVioletGold,
            glowColor: accentColor,
            height: 46,
            onConfirmed: () async {
              await service.acceptBooking(
                booking.id,
                worker.id,
                workerName: worker.phoneForCalling ?? "Artisan",
              );
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (ctx) => ActiveJobScreen(
                      booking: booking,
                      worker: worker,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
