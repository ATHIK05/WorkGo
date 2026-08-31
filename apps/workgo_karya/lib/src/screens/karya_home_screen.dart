import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../karya_theme.dart';
import 'active_job_screen.dart';
import 'document_upload_screen.dart';
import 'incoming_requests_screen.dart';
import 'worker_earnings_screen.dart';
import 'worker_profile_detail_screen.dart';
import 'worker_profile_setup_screen.dart';
import 'worker_welfare_screen.dart';
import '../widgets/karya_app_tour_dialog.dart';

class KaryaHomeScreen extends StatefulWidget {
  const KaryaHomeScreen({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<KaryaHomeScreen> createState() => _KaryaHomeScreenState();
}

class _KaryaHomeScreenState extends State<KaryaHomeScreen>
    with TickerProviderStateMixin {
  final WorkerService _workerService = WorkerService();
  final BookingService _bookingService = BookingService();
  int _currentNavIndex = 0;
  late AnimationController _radarCtrl;
  static bool _hasPromptedThisSession = false;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _ensureWorkerProfileExists();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptWorkerLocation();
      _checkAndShowAppTour();
    });
  }

  Future<void> _checkAndShowAppTour() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      await KaryaAppTourDialog.checkAndShowTour(context);
    }
  }

  Future<void> _checkAndPromptWorkerLocation() async {
    if (_hasPromptedThisSession) return;
    _hasPromptedThisSession = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyConfigured = prefs.getBool("worker_loc_done_${widget.user.uid}") ?? false;
      if (alreadyConfigured) return;

      final doc = await FirebaseFirestore.instance.collection("workers").doc(widget.user.uid).get();
      final data = doc.data() ?? {};
      final currentAddress = data["currentAddress"];
      final baseAddress = data["baseAddress"];
      final serviceLocation = data["serviceLocation"];
      final lat = data["latitude"];

      // Check addresses subcollection
      final addrSnap = await FirebaseFirestore.instance
          .collection("workers")
          .doc(widget.user.uid)
          .collection("addresses")
          .limit(1)
          .get();

      final hasLocation = addrSnap.docs.isNotEmpty ||
          currentAddress != null ||
          baseAddress != null ||
          serviceLocation != null ||
          lat != null;

      if (!hasLocation && mounted) {
        await prefs.setBool("worker_loc_done_${widget.user.uid}", true);
        if (!mounted) return;
        await showLocationPromptSheet(
          context,
          userId: widget.user.uid,
          userRole: "worker",
        );
      } else {
        await prefs.setBool("worker_loc_done_${widget.user.uid}", true);
      }
    } catch (_) {}
  }

  Future<void> _ensureWorkerProfileExists() async {
    final existing = await _workerService.fetchWorkerByUserId(widget.user.uid);
    if (existing == null) {
      final initialWorker = Worker(
        id: widget.user.uid,
        userId: widget.user.uid,
        name: widget.user.displayName.isNotEmpty ? widget.user.displayName : "Co-op Artisan",
        organizationId: widget.user.organizationId ?? "coop_tn_01",
        skills: ["Plumbing", "Electrical"],
        experienceYears: 2,
        verificationStatus: VerificationStatus.pending,
        availabilityStatus: AvailabilityStatus.online,
        avgRating: 0.0,
        totalRatings: 0,
        homesServiced: 0,
        totalReviews: 0,
        insuranceStatus: false,
      );
      await _workerService.upsertWorkerProfile(initialWorker);
    }
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleAvailability(Worker worker) async {
    final isCurrentlyOnline = worker.availabilityStatus == AvailabilityStatus.online;

    if (!isCurrentlyOnline) {
      // Worker is checking in / going online! Strictly enforce identity verification:
      if (worker.verificationStatus != VerificationStatus.approved) {
        HapticFeedback.heavyImpact();
        _showVerificationRequiredModal(context, worker);
        return;
      }
    }

    if (isCurrentlyOnline) {
      // Artisan is checking out / going offline! Slide up Motivational Bottom Sheet!
      final confirmedCheckOut = await showCheckOutMotivationSheet(
        context,
        worker: worker,
      );

      if (confirmedCheckOut != true) {
        // Worker opted to keep working!
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: KX.gold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Awesome! You're live on customer radar. Dispatches incoming! ⚡",
                      style: WorkGoFonts.body(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E1035),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: KX.gold.withValues(alpha: 0.6), width: 1.2),
              ),
            ),
          );
        }
        return;
      }
    }

    HapticFeedback.mediumImpact();
    final nextStatus = isCurrentlyOnline
        ? AvailabilityStatus.offline
        : AvailabilityStatus.online;
    await _workerService.updateAvailability(worker.id, nextStatus);
    await _workerService.checkInTitan(worker.id, nextStatus == AvailabilityStatus.online);
  }

  void _showVerificationRequiredModal(BuildContext context, Worker worker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: Color(0xFF0F0B1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0xFFF59E0B), width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Color(0xFFF59E0B), size: 36),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Identity Verification Required",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "To protect artisan earnings, guarantee direct wage payouts, and maintain cooperative trust, you must complete identity verification before going live on customer radar.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF191233),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: KX.gold, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Instant Co-op Badging",
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Status: ${worker.verificationStage.name.toUpperCase()} (Pending Review)",
                            style: const TextStyle(color: KX.gold, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (c) => DocumentUploadScreen(workerId: worker.id),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF1E1035),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Complete Verification Now", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("I'll do it later", style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Worker?>(
      stream: _workerService.streamWorker(widget.user.uid),
      builder: (context, snapshot) {
        final worker = snapshot.data ??
            Worker(
              id: widget.user.uid,
              userId: widget.user.uid,
              organizationId: widget.user.organizationId ?? "coop_tn_01",
              skills: [],
              experienceYears: 0,
              verificationStatus: VerificationStatus.pending,
              availabilityStatus: AvailabilityStatus.online,
              avgRating: 5.0,
              totalRatings: 0,
              insuranceStatus: false,
            );

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (_currentNavIndex != 0) {
              setState(() => _currentNavIndex = 0);
            } else {
              showExitConfirmationSheet(context);
            }
          },
          child: KaryaScaffold(
            bottomNavigationBar: _buildFloatingDock(worker),
            body: AnimatedSwitcher(
              duration: KAnim.normal,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: KeyedSubtree(
                key: ValueKey(_currentNavIndex),
                child: switch (_currentNavIndex) {
                  0 => _buildCockpit(context, worker),
                  1 => IncomingRequestsScreen(worker: worker),
                  2 => WorkerEarningsScreen(worker: worker),
                  3 => WorkerWelfareScreen(worker: worker),
                  4 => WorkerProfileDetailScreen(
                      user: widget.user,
                      worker: worker,
                      onSignOut: widget.onSignOut,
                    ),
                  _ => _buildCockpit(context, worker),
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  FLOATING LUMINA DOCK (Spacious 4-Tab Luxury Cyber Dock)
  // ──────────────────────────────────────────────────────────────
  Widget _buildFloatingDock(Worker worker) {
    final items = [
      (Icons.dashboard_rounded, "nav_cockpit", "Cockpit"),
      (Icons.radar_rounded, "nav_requests", "Requests"),
      (Icons.account_balance_wallet_rounded, "nav_earnings", "Earnings"),
      (Icons.health_and_safety_rounded, "nav_welfare", "Welfare"),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF120C28).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: KX.violetNeon.withValues(alpha: 0.35),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: KX.violet.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final isActive = _currentNavIndex == i;
              final item = items[i];
              final label = item.$2.trSafe(item.$3);
              final isRadar = i == 1;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _currentNavIndex = i);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isActive ? KX.luminaVioletGold : null,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: KX.gold.withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: -1,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedScale(
                              scale: isActive ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                item.$1,
                                size: 21,
                                color: isActive ? const Color(0xFF1E1035) : KX.textSecondary.withValues(alpha: 0.8),
                              ),
                            ),
                            if (isRadar)
                              StreamBuilder<List<Booking>>(
                                stream: _bookingService.streamWorkerIncomingRequests(
                                  workerId: worker.id,
                                  skills: worker.skills,
                                ),
                                builder: (context, snap) {
                                  final reqCount = snap.data?.length ?? 0;
                                  if (reqCount == 0) return const SizedBox.shrink();

                                  return Positioned(
                                    top: -4,
                                    right: -8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: KX.rose,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: KX.rose.withValues(alpha: 0.6),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        "$reqCount",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          style: TextStyle(
                            color: isActive ? const Color(0xFF1E1035) : KX.textSecondary.withValues(alpha: 0.85),
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  THE ARTISAN MISSION CONTROL COCKPIT (Ultra-Dense, Zero Waste)
  // ──────────────────────────────────────────────────────────────
  Widget _buildCockpit(BuildContext context, Worker worker) {
    final name = widget.user.displayName.isNotEmpty
        ? widget.user.displayName.split(' ').first
        : (worker.phoneForCalling ?? "Artisan");

    final isOnline = worker.availabilityStatus == AvailabilityStatus.online;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Quick-Shift Bar
            KSlideFadeIn(
              child: _buildTopQuickShiftBar(name, worker, isOnline, context),
            ),
            const SizedBox(height: 12),

            // ── Real Identity Verification Alert Banner (if unverified)
            if (worker.verificationStatus != VerificationStatus.approved)
              KSlideFadeIn(
                delay: const Duration(milliseconds: 20),
                child: _buildVerificationAlertBanner(context, worker),
              ),

            // ── Real-Time Daily Fuel Gauge Cockpit
            KSlideFadeIn(
              delay: const Duration(milliseconds: 40),
              child: _buildDailyFuelGauge(worker),
            ),
            const SizedBox(height: 12),

            // ── Live Radar & Incoming Job Stream
            KSlideFadeIn(
              delay: const Duration(milliseconds: 80),
              child: _buildLiveRadarSection(worker),
            ),
            const SizedBox(height: 14),

            // ── Action Matrix (High Density 2x2)
            KSlideFadeIn(
              delay: const Duration(milliseconds: 120),
              child: _buildTacticalActionGrid(context, worker),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationAlertBanner(BuildContext context, Worker worker) {
    final stage = worker.verificationStage;
    String stageText = "Start Aadhaar & Live Selfie verification";
    if (stage == VerificationStage.selfieCapture) {
      stageText = "Step 3/6: Capture your live front-camera selfie";
    } else if (stage == VerificationStage.liveVideoVerification) {
      stageText = "Step 4/6: Live Video KYC ready! Tap to enter waiting room";
    } else if (stage == VerificationStage.pccUpload || stage == VerificationStage.pccManualReview) {
      stageText = "Step 5/6: Upload Police Clearance Certificate for badging";
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => DocumentUploadScreen(workerId: worker.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD97706).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Identity Verification Required",
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stageText,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  TOP QUICK-SHIFT BAR (Instant Mode Shift + Language)
  // ──────────────────────────────────────────────────────────────
  Widget _buildTopQuickShiftBar(
      String name, Worker worker, bool isOnline, BuildContext context) {
    return KaryaCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      borderRadius: 18,
      child: Row(
        children: [
          // Holographic Avatar with Base64 Image decoding - Tap to view Profile
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => WorkerProfileDetailScreen(
                    user: widget.user,
                    worker: worker,
                    onSignOut: widget.onSignOut,
                  ),
                ),
              );
            },
            child: StreamBuilder<AppUser?>(
              stream: AuthService().streamAppUser(widget.user.uid),
              initialData: widget.user,
              builder: (context, snap) {
                final avatar = snap.data?.avatarBase64 ?? widget.user.avatarBase64;
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: KX.gold.withValues(alpha: 0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: KX.gold.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: WorkGoAvatar(
                    avatarBase64: avatar,
                    name: name,
                    radius: 20,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),

          // Name & Verification Pill - Tap to view Profile
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => WorkerProfileDetailScreen(
                      user: widget.user,
                      worker: worker,
                      onSignOut: widget.onSignOut,
                    ),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          "$name 🙏",
                          style: WorkGoFonts.display(
                            color: KX.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, color: KX.gold, size: 9),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      KPulsingDot(
                        color: isOnline ? KX.gold : KX.textMuted,
                        size: 6,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isOnline ? "titan_live".trSafe("TITAN LIVE") : "offline_status".trSafe("OFFLINE"),
                          style: WorkGoFonts.badge(
                            color: isOnline ? KX.gold : KX.textMuted,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Instant Titan Shift Mode Button (One-tap switch!)
          GestureDetector(
            onTap: () => _toggleAvailability(worker),
            child: AnimatedContainer(
              duration: KAnim.fast,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: isOnline ? KX.luminaVioletGold : KX.auroraOffline,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isOnline
                    ? [
                        BoxShadow(
                          color: KX.gold.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOnline ? Icons.flash_on_rounded : Icons.power_settings_new_rounded,
                    color: isOnline ? const Color(0xFF1E1035) : Colors.white,
                    size: 13,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isOnline ? "titan_checked_in".trSafe("CHECKED IN") : "check_in_btn".trSafe("CHECK IN"),
                    style: WorkGoFonts.badge(
                      color: isOnline ? const Color(0xFF1E1035) : Colors.white,
                      fontSize: 9.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Language Selector (EN, HI, TA)
          _buildCompactLangPill(context),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  LANGUAGE PILL (EN / HI / TA Compact Switcher)
  // ──────────────────────────────────────────────────────────────
  Widget _buildCompactLangPill(BuildContext context) {
    final currentCode = context.locale.languageCode;

    return PopupMenuButton<String>(
      onSelected: (code) async {
        await context.setLocale(Locale(code));
        setState(() {});
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: KX.violetNeon.withValues(alpha: 0.3)),
      ),
      color: const Color(0xFF16102E),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'en',
          child: Text('🇬🇧 English', style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
        const PopupMenuItem(
          value: 'hi',
          child: Text('🇮🇳 हिन्दी (Hindi)', style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
        const PopupMenuItem(
          value: 'ta',
          child: Text('🇮🇳 தமிழ் (Tamil)', style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: KX.canvasElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KX.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, color: KX.violetLight, size: 14),
            const SizedBox(width: 4),
            Text(
              currentCode.toUpperCase(),
              style: WorkGoFonts.badge(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  DAILY FUEL GAUGE (Real-Time Earnings & Goal Cockpit)
  // ──────────────────────────────────────────────────────────────
  Widget _buildDailyFuelGauge(Worker worker) {
    return StreamBuilder<List<Booking>>(
      stream: _bookingService.streamWorkerActiveJobs(worker.id),
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? [];
        final completed =
            jobs.where((b) => b.status == BookingStatus.completed).toList();

        final todayEarnings = completed.fold<double>(
          0.0,
          (total, b) => total + (b.totalAmount * 0.98),
        );

        const dailyGoal = 2000.0;
        final goalProgress = (todayEarnings / dailyGoal).clamp(0.0, 1.0);
        final welfareFund = todayEarnings * 0.02;

        return KaryaCard(
          padding: const EdgeInsets.all(16),
          glowColor: KX.gold,
          borderColor: KX.gold.withValues(alpha: 0.35),
          gradient: KX.auroraVioletNeon,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top metric row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "todays_earnings".trSafe("Today's Earnings"),
                        style: WorkGoFonts.heading(
                          color: KX.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      KAnimatedCounter(
                        value: todayEarnings,
                        style: WorkGoFonts.numeric(
                          color: KX.gold,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: KX.luminaVioletGold,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: KX.gold.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "daily_goal".trSafe("DAILY GOAL"),
                          style: WorkGoFonts.badge(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          "${(goalProgress * 100).toStringAsFixed(0)}%",
                          style: WorkGoFonts.numeric(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Linear Goal Meter
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: goalProgress,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(KX.gold),
                ),
              ),
              const SizedBox(height: 12),

              // Micro-metrics cluster
              Row(
                children: [
                  Expanded(
                    child: _microKpi(
                      "jobs_completed".trSafe("Jobs Completed"),
                      "${completed.length}",
                      Icons.task_alt_rounded,
                      KX.emeraldLight,
                    ),
                  ),
                  Container(width: 1, height: 24, color: KX.glassBorder),
                  Expanded(
                    child: _microKpi(
                      "rating_score_label".trSafe("Rating Score"),
                      worker.totalRatings > 0
                          ? "${worker.avgRating.toStringAsFixed(1)} ★"
                          : "5.0 ★",
                      Icons.star_rounded,
                      KX.gold,
                    ),
                  ),
                  Container(width: 1, height: 24, color: KX.glassBorder),
                  Expanded(
                    child: _microKpi(
                      "welfare_2pct".trSafe("Welfare (2%)"),
                      "₹${welfareFund.toStringAsFixed(0)}",
                      Icons.shield_rounded,
                      KX.violetLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _microKpi(
      String label, String value, IconData icon, Color accentColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accentColor, size: 13),
            const SizedBox(width: 4),
            Text(
              value,
              style: WorkGoFonts.numeric(
                color: KX.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: WorkGoFonts.body(
            color: KX.textSecondary.withValues(alpha: 0.7),
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  LIVE RADAR SECTION WITH INTERACTIVE SLIDE-TO-ACCEPT
  // ──────────────────────────────────────────────────────────────
  Widget _buildLiveRadarSection(Worker worker) {
    return StreamBuilder<List<Booking>>(
      stream: _bookingService.streamWorkerIncomingRequests(
        workerId: worker.id,
        skills: worker.skills,
      ),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return KaryaCard(
            glowColor: KX.violet,
            borderColor: KX.violetNeon.withValues(alpha: 0.25),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _radarCtrl,
                  builder: (_, __) => Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: KX.auroraVioletNeon,
                      boxShadow: [
                        BoxShadow(
                          color: KX.violetNeon
                              .withValues(alpha: 0.5 * _radarCtrl.value),
                          blurRadius: 12 * _radarCtrl.value,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.radar_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${'live_radar_title'.trSafe('Active Dispatch Radar')} (${worker.serviceRadiusKm.toInt()} km)",
                        style: WorkGoFonts.heading(
                          color: KX.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "radar_scanning".trSafe("Listening for direct dispatch calls in your zone…"),
                        style: WorkGoFonts.body(
                          color: KX.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const KaryaBadge(
                  label: "RADAR ON",
                  style: KaryaBadgeStyle.gold,
                ),
              ],
            ),
          );
        }

        final topReq = requests.first;
        final isEmergency = topReq.isEmergency;

        return KaryaCard(
          glowColor: isEmergency ? KX.rose : KX.gold,
          borderColor: (isEmergency ? KX.rose : KX.gold).withValues(alpha: 0.45),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: isEmergency ? KX.auroraDecline : KX.solarGold,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isEmergency ? KX.rose : KX.gold)
                              .withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      isEmergency
                          ? Icons.bolt_rounded
                          : Icons.handyman_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topReq.serviceType.toLocalizedTrade(),
                          style: WorkGoFonts.display(
                            color: KX.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            KaryaBadge(
                              label: isEmergency ? "emergency".tr().toUpperCase() : "STANDARD",
                              style: isEmergency
                                  ? KaryaBadgeStyle.rose
                                  : KaryaBadgeStyle.gold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "incoming_requests_badge".tr(args: [requests.length.toString()]),
                              style: WorkGoFonts.body(
                                color: KX.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "₹${topReq.amount.toStringAsFixed(0)}",
                    style: WorkGoFonts.numeric(
                      color: KX.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Slide-to-Accept Slider
              KaryaSlideAction(
                label: "slide_to_accept_job".trSafe("Slide to Accept Job"),
                gradient: isEmergency ? KX.auroraDecline : KX.luminaVioletGold,
                glowColor: isEmergency ? KX.rose : KX.gold,
                height: 48,
                onConfirmed: () async {
                  await _bookingService.acceptBooking(topReq.id, worker.id);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => ActiveJobScreen(
                           booking: topReq,
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
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  ULTRA-IMPRESSIVE BENTO QUICK ACCESS HUB (Pro Artisan Matrix)
  // ──────────────────────────────────────────────────────────────
  Widget _buildTacticalActionGrid(BuildContext context, Worker worker) {
    final activeLocation = worker.baseAddress?.formattedAddress ??
        worker.baseArea ??
        (worker.preferredAreas.isNotEmpty ? worker.preferredAreas.first : "Erode Central, Tamil Nadu");

    final isKycApproved = worker.verificationStatus == VerificationStatus.approved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: KX.luminaVioletGold,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: KX.gold.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.grid_view_rounded, color: Color(0xFF1E1035), size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  "quick_access_title".trSafe("Quick Access Hub"),
                  style: WorkGoFonts.display(
                    color: KX.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: KX.violet.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KX.violetNeon.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: KX.gold, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "PRO ARTISAN HUD",
                    style: WorkGoFonts.badge(
                      color: KX.gold,
                      fontSize: 9.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Hero Bento: Operating Base & Dispatch Radar Station
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            showAddressManagementSheet(
              context,
              userId: widget.user.uid,
              userRole: "worker",
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF261447), Color(0xFF160E2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: KX.violetNeon.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: KX.violet.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: KX.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: KX.gold.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: KX.gold, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "OPERATING BASE STATION",
                                style: WorkGoFonts.badge(
                                  color: KX.gold,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: KX.emerald.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: KX.emeraldLight.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: KX.emeraldLight,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${worker.serviceRadiusKm.toInt()} km Range",
                                      style: const TextStyle(
                                        color: KX.emeraldLight,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeLocation,
                            style: WorkGoFonts.heading(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Skills Rail Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...worker.skills.take(3).map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: KX.canvasElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: KX.glassBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.handyman_rounded, color: KX.violetLight, size: 11),
                                const SizedBox(width: 4),
                                Text(
                                  s,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: KX.luminaVioletGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.edit_location_alt_rounded, color: Color(0xFF1E1035), size: 11),
                          SizedBox(width: 3),
                          Text(
                            "Change Base",
                            style: TextStyle(color: Color(0xFF1E1035), fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── 2x2 Bento Action Tiles
        Row(
          children: [
            // Tile 1: Trade Skills Matrix
            Expanded(
              child: _ImpressiveBentoTile(
                title: "Trade Skills",
                subtitle: "${worker.skills.length} Active Trades",
                badgeText: "${worker.serviceRadiusKm.toInt()} KM",
                badgeColor: KX.violetLight,
                icon: Icons.construction_rounded,
                gradient: KX.auroraVioletNeon,
                glowColor: KX.violetNeon,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => WorkerProfileSetupScreen(
                        worker: worker,
                        onProfileUpdated: () => setState(() {}),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),

            // Tile 2: Earnings & Instant UPI Cashout
            Expanded(
              child: _ImpressiveBentoTile(
                title: "Earnings Vault",
                subtitle: "0% Fee · Direct UPI",
                badgeText: "INSTANT",
                badgeColor: KX.gold,
                icon: Icons.account_balance_wallet_rounded,
                gradient: KX.solarGold,
                glowColor: KX.gold,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentNavIndex = 2);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            // Tile 3: KYC & Cooperative Certification
            Expanded(
              child: _ImpressiveBentoTile(
                title: "KYC & Badging",
                subtitle: isKycApproved ? "Co-op Certified ✓" : "Review Pending",
                badgeText: isKycApproved ? "VERIFIED" : "SUBMIT",
                badgeColor: isKycApproved ? KX.emeraldLight : KX.gold,
                icon: Icons.verified_user_rounded,
                gradient: isKycApproved ? KX.luminaVioletGold : KX.auroraVioletNeon,
                glowColor: isKycApproved ? KX.gold : KX.violet,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => DocumentUploadScreen(workerId: worker.id),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),

            // Tile 4: ₹2L Welfare Shield
            Expanded(
              child: _ImpressiveBentoTile(
                title: "₹2L Welfare Cover",
                subtitle: worker.insuranceStatus ? "PMJJBY Active" : "Welfare Shield",
                badgeText: "PROTECTED",
                badgeColor: KX.cyanLight,
                icon: Icons.health_and_safety_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E7490), Color(0xFF4338CA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                glowColor: KX.cyanLight,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentNavIndex = 3);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Cooperative Referral Multi-Tier Bento Banner
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            ProxyWorkerDialog.show(
              context,
              referrerId: widget.user.uid,
              referrerRole: "worker",
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1035), Color(0xFF2B1055)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: KX.gold.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: KX.gold.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: KX.luminaVioletGold,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: KX.gold.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.groups_rounded, color: Color(0xFF1E1035), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Refer Artisan & Earn 2%",
                            style: WorkGoFonts.heading(
                              color: KX.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: KX.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "LIFETIME",
                              style: TextStyle(
                                color: KX.gold,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Refer smartphone or feature-phone artisans to earn bonus",
                        style: WorkGoFonts.body(
                          color: KX.textSecondary,
                          fontSize: 10.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: KX.gold,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  IMPRESSIVE BENTO TILE (Polished, tactile HUD element)
// ──────────────────────────────────────────────────────────────
class _ImpressiveBentoTile extends StatelessWidget {
  const _ImpressiveBentoTile({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final LinearGradient gradient;
  final Color glowColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KaryaCard(
      onTap: onTap,
      glowColor: glowColor,
      borderColor: glowColor.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(13),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: WorkGoFonts.heading(
              color: KX.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: WorkGoFonts.body(
              color: KX.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
