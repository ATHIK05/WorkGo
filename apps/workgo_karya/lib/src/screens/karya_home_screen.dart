import 'dart:async';
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
import '../widgets/karya_spotlight_tour.dart';

class KaryaHomeScreen extends StatefulWidget {
  const KaryaHomeScreen({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onSignOut;

  static _KaryaHomeScreenState? _activeState;

  /// Launches the live interactive spotlight app tour on the live screen.
  static void launchLiveSpotlightTour(BuildContext context) {
    _activeState?.launchSpotlightTour(isManual: true);
  }

  @override
  State<KaryaHomeScreen> createState() => _KaryaHomeScreenState();
}

class _KaryaHomeScreenState extends State<KaryaHomeScreen>
    with TickerProviderStateMixin {
  final WorkerService _workerService = WorkerService();
  final BookingService _bookingService = BookingService();
  int _currentNavIndex = 0;
  int _selectedDayIndex = 3; // Today default
  late AnimationController _radarCtrl;
  static bool _hasPromptedThisSession = false;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _keyQuickShiftBar = GlobalKey();
  final GlobalKey _keyAvailabilitySwitch = GlobalKey();
  final GlobalKey _keyFuelGauge = GlobalKey();
  final GlobalKey _keyRadar = GlobalKey();
  final GlobalKey _keyBentoGrid = GlobalKey();
  final GlobalKey _keyBottomNav = GlobalKey();

  // Child Tab Keys for Multi-Page Guided App Tour
  final GlobalKey _keyRequestsHub = GlobalKey();
  final GlobalKey _keyEarningsHero = GlobalKey();
  final GlobalKey _keyWelfareShield = GlobalKey();
  final GlobalKey _keyProfileHub = GlobalKey();
  final GlobalKey _keyProfileKyc = GlobalKey();

  @override
  void initState() {
    super.initState();
    KaryaHomeScreen._activeState = this;
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _ensureWorkerProfileExists();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAndPromptWorkerLocation();
      if (mounted) {
        await _checkAndShowAppTour();
      }
    });
  }

  void _startLiveLocationBroadcasting(String workerId) {
    LocationService.instance.startRealtimeBroadcast(
      onLocationUpdate: (lat, lng) async {
        if (lat != 0.0 && lng != 0.0) {
          await _workerService.updateWorkerLocation(workerId, lat, lng);
        }
      },
    );
  }

  void _stopLiveLocationBroadcasting() {
    LocationService.instance.stopRealtimeBroadcast();
  }

  @override
  void dispose() {
    if (KaryaHomeScreen._activeState == this) {
      KaryaHomeScreen._activeState = null;
    }
    _stopLiveLocationBroadcasting();
    _radarCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkAndShowAppTour() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      await launchSpotlightTour(isManual: false);
    }
  }

  List<SpotlightTarget> _buildSpotlightTargets() {
    return [
      // ── PAGE 1: HOME COCKPIT (navIndex: 0)
      SpotlightTarget(
        key: _keyAvailabilitySwitch,
        navIndex: 0,
        pageTitle: "Home Cockpit",
        stepNumber: "1",
        title: "1. Autonomous Shift & Check-In Switch",
        description: "Tap here anytime to go live on customer radars across your district. Verification is required before your first check-in.",
        badgeText: "AVAILABILITY",
        icon: Icons.power_settings_new_rounded,
        bulletPoints: [
          "1-Tap Check-In toggles incoming job dispatch radar",
          "Automatic verification check protects artisan earnings",
        ],
      ),
      SpotlightTarget(
        key: _keyFuelGauge,
        navIndex: 0,
        pageTitle: "Home Cockpit",
        stepNumber: "2",
        title: "2. Daily Fuel Gauge & Earnings Cockpit",
        description: "Track today's jobs, total earnings, active hours, and performance incentives with a strict 0% commission guarantee.",
        badgeText: "0% COMMISSION",
        icon: Icons.speed_rounded,
        bulletPoints: [
          "Live progress tracker towards daily earning milestones",
          "Instant 1-tap UPI / Bank payout settlements",
        ],
      ),
      SpotlightTarget(
        key: _keyRadar,
        navIndex: 0,
        pageTitle: "Home Cockpit",
        stepNumber: "3",
        title: "3. Live Dispatch Radar & Job Match",
        description: "Nearby service requests flash in real time with distance, upfront pricing, and a 30-second priority acceptance countdown.",
        badgeText: "PRIORITY RADAR",
        icon: Icons.radar_rounded,
        bulletPoints: [
          "30s audio chime countdown to accept before others",
          "Upfront pricing and customer pickup distance shown",
        ],
      ),
      SpotlightTarget(
        key: _keyBentoGrid,
        navIndex: 0,
        pageTitle: "Home Cockpit",
        stepNumber: "4",
        title: "4. Tactical Action Matrix",
        description: "Quick access to government Aadhaar & Video KYC, ₹2L welfare cover, and peer referral network.",
        badgeText: "ACTION MATRIX",
        icon: Icons.grid_view_rounded,
        bulletPoints: [
          "Complete Video KYC to earn the trusted Co-op Certified badge",
          "₹2,00,000 accidental and disability insurance coverage",
        ],
      ),

      // ── PAGE 2: INCOMING REQUESTS & RADAR (navIndex: 1)
      SpotlightTarget(
        key: _keyRequestsHub,
        navIndex: 1,
        pageTitle: "Requests & Radar",
        stepNumber: "5",
        title: "5. Real-Time Dispatch Broadcast Hub",
        description: "Live radar listening for broadcasts in your trade skills. Instant cards alert you with customer location, price, and distance.",
        badgeText: "JOB ALERTS",
        icon: Icons.cell_tower_rounded,
        bulletPoints: [
          "30-second priority allocation before secondary dispatch",
          "1-tap Accept to claim job and start secure turn-by-turn navigation",
        ],
      ),

      // ── PAGE 3: EARNINGS & INSTANT PAYOUTS (navIndex: 2)
      SpotlightTarget(
        key: _keyEarningsHero,
        navIndex: 2,
        pageTitle: "Earnings Ledger",
        stepNumber: "6",
        title: "6. Direct Wage Payouts (0% Commission)",
        description: "All customer payments go 100% directly to you. WorkGo charges 0% platform commission with a tiny 2% allocated to your welfare fund.",
        badgeText: "ZERO DEDUCTIONS",
        icon: Icons.account_balance_wallet_rounded,
        bulletPoints: [
          "Instant 1-tap UPI transfer straight into your bank account",
          "Complete transaction receipt log for every serviced booking",
        ],
      ),

      // ── PAGE 4: WELFARE & INSURANCE SHIELD (navIndex: 3)
      SpotlightTarget(
        key: _keyWelfareShield,
        navIndex: 3,
        pageTitle: "Welfare & Insurance",
        stepNumber: "7",
        title: "7. ₹2 Lakh Welfare Shield & Protection",
        description: "Every verified cooperative artisan receives ₹2,00,000 accidental & disability cover (PMSBY / PMJJBY) on duty.",
        badgeText: "SAFETY SHIELD",
        icon: Icons.health_and_safety_rounded,
        bulletPoints: [
          "Digital Holographic ID Card with verified policy number",
          "24/7 Emergency SOS beacon and health claim support",
        ],
      ),

      // ── PAGE 4: PROFILE & OPERATIONAL SETTINGS (navIndex: 3)
      SpotlightTarget(
        key: _keyProfileHub,
        navIndex: 3,
        pageTitle: "Profile & Hub",
        stepNumber: "8",
        title: "8. Operating Bases & Service Radius",
        description: "Configure your workshop base, set coverage radius (1–30 km), manage trade skills, and customize working shift hours.",
        badgeText: "BASE & RADIUS",
        icon: Icons.location_on_rounded,
        bulletPoints: [
          "Set multiple operating bases (Primary Workshop & Home)",
          "Adjust radar dispatch radius to match your vehicle range",
        ],
      ),
      SpotlightTarget(
        key: _keyProfileKyc,
        navIndex: 3,
        pageTitle: "Profile & Hub",
        stepNumber: "9",
        title: "9. Identity Verification & Language Hub",
        description: "Access your government eKYC records, trigger Video KYC reviews, and switch app language instantly (தமிழ், हिंदी, English).",
        badgeText: "KYC & VERNACULAR",
        icon: Icons.verified_user_rounded,
        bulletPoints: [
          "Tamper-proof C2PA proof of work verification",
          "Full vernacular audio voice support for illiterate artisans",
        ],
      ),
    ];
  }

  Future<void> launchSpotlightTour({bool isManual = false}) async {
    if (!mounted) return;
    if (_currentNavIndex != 0) {
      setState(() => _currentNavIndex = 0);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (mounted) {
      await KaryaSpotlightTourOverlay.startTour(
        context: context,
        targets: _buildSpotlightTargets(),
        scrollController: _scrollController,
        onPageChange: (navIdx) {
          if (mounted) {
            setState(() => _currentNavIndex = navIdx);
          }
        },
        isManual: isManual,
      );
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
        availabilityStatus: AvailabilityStatus.offline,
        isCheckedIn: false,
        avgRating: 0.0,
        totalRatings: 0,
        homesServiced: 0,
        totalReviews: 0,
        insuranceStatus: false,
      );
      await _workerService.upsertWorkerProfile(initialWorker);
    }
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

      // Native Biometric Fingerprint/Face ID verification prompt
      final authenticated = await BiometricService().authenticate(
        reason: "Scan fingerprint or face to verify identity before going live on radar.",
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text("Biometric verification cancelled. Check-in aborted.")),
                ],
              ),
              backgroundColor: const Color(0xFFE11D48),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
        return;
      }
    }

    if (isCurrentlyOnline) {
      if (!mounted) return;
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

    double? lat;
    double? lng;
    if (nextStatus == AvailabilityStatus.online) {
      try {
        final coords = await LocationService.instance.getCurrentCoordinates();
        lat = coords["latitude"];
        lng = coords["longitude"];
      } catch (_) {}

      // If hardware GPS fix is pending, dynamically forward geocode the worker's base address via OpenStreetMap
      if (lat == null) {
        final baseText = "${worker.baseArea ?? ''} ${worker.baseAddress?.formattedAddress ?? ''}".trim();
        if (baseText.isNotEmpty) {
          try {
            final geo = await LocationService.instance.forwardGeocode(baseText);
            if (geo != null) {
              lat = geo["latitude"];
              lng = geo["longitude"];
            }
          } catch (_) {}
        }
      }

      _startLiveLocationBroadcasting(worker.id);
    } else {
      _stopLiveLocationBroadcasting();
    }

    await _workerService.updateAvailability(
      worker.id,
      nextStatus,
      latitude: lat,
      longitude: lng,
    );
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
          decoration: BoxDecoration(
            color: KX.canvasCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: KX.gold, width: 1.5),
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
                    color: KX.dividerLight,
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
                  color: KX.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "To protect artisan earnings, guarantee direct wage payouts, and maintain cooperative trust, you must complete identity verification before going live on customer radar.",
                textAlign: TextAlign.center,
                style: TextStyle(color: KX.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: KX.canvasMid,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: KX.glassBorder),
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
                            style: TextStyle(color: KX.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
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
                child: const Text("I'll do it later", style: TextStyle(color: KX.textSecondary)),
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
              availabilityStatus: AvailabilityStatus.offline,
              isCheckedIn: false,
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
            body: IndexedStack(
              index: _currentNavIndex,
              children: [
                _buildCockpit(context, worker),
                IncomingRequestsScreen(
                  worker: worker,
                  requestsHubKey: _keyRequestsHub,
                ),
                WorkerEarningsScreen(
                  worker: worker,
                  earningsHeroKey: _keyEarningsHero,
                ),
                WorkerProfileDetailScreen(
                  user: widget.user,
                  worker: worker,
                  onSignOut: widget.onSignOut,
                  profileHubKey: _keyProfileHub,
                  profileKycKey: _keyProfileKyc,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  FLOATING LUMINA DOCK (Reference Template Style - Luxury Dark Pill)
  // ──────────────────────────────────────────────────────────────
  Widget _buildFloatingDock(Worker worker) {
    final items = [
      (Icons.home_rounded, "Cockpit"),
      (Icons.grid_view_rounded, "Requests"),
      (Icons.bar_chart_rounded, "Earnings"),
      (Icons.person_outline_rounded, "Profile"),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: KeyedSubtree(
          key: _keyBottomNav,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(50),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (i) {
                final isActive = _currentNavIndex == i;
                final item = items[i];
                final isRadar = i == 1;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _currentNavIndex = i);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: isActive ? 52 : 46,
                    height: isActive ? 52 : 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? Colors.white : Colors.transparent,
                      boxShadow: isActive
                          ? const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            item.$1,
                            size: 22,
                            color: isActive ? const Color(0xFF141416) : const Color(0xFF8E8E93),
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
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: KX.rose,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      "$reqCount",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                );
                              },
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
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  THE ARTISAN MISSION CONTROL COCKPIT (Ultra-Clean, Production-Grade)
  // ──────────────────────────────────────────────────────────────
  Widget _buildCockpit(BuildContext context, Worker worker) {
    final name = widget.user.displayName.isNotEmpty
        ? widget.user.displayName.split(' ').first
        : (worker.phoneForCalling ?? "Artisan");

    final isOnline = worker.availabilityStatus == AvailabilityStatus.online;

    return SafeArea(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Top Header Bar (Avatar + Hello Sandra + Shift Switch)
            KSlideFadeIn(
              child: KeyedSubtree(
                key: _keyQuickShiftBar,
                child: _buildTopQuickShiftBar(name, worker, isOnline, context),
              ),
            ),
            const SizedBox(height: 16),

            // ── 2. Verification Alert Banner (if unverified)
            if (worker.verificationStatus != VerificationStatus.approved) ...[
              KSlideFadeIn(
                delay: const Duration(milliseconds: 20),
                child: _buildVerificationAlertBanner(context, worker),
              ),
              const SizedBox(height: 14),
            ],

            // ── 3. Daily Challenge / Earnings Hero Card (Reference-Inspired)
            KSlideFadeIn(
              delay: const Duration(milliseconds: 40),
              child: KeyedSubtree(
                key: _keyFuelGauge,
                child: _buildHeroDailyChallenge(worker),
              ),
            ),
            const SizedBox(height: 16),

            // ── 4. Weekly 7-Day Calendar Strip (Interactive Capsule Row)
            KSlideFadeIn(
              delay: const Duration(milliseconds: 60),
              child: _buildWeeklyCalendarStrip(),
            ),
            const SizedBox(height: 18),

            // ── 5. "Your Plan" Section & Bento Cockpit
            KSlideFadeIn(
              delay: const Duration(milliseconds: 80),
              child: KeyedSubtree(
                key: _keyRadar,
                child: _buildYourPlanSection(context, worker),
              ),
            ),
            const SizedBox(height: 18),

            // ── 6. Operating Base Station & Tactical Action Grid
            KSlideFadeIn(
              delay: const Duration(milliseconds: 100),
              child: KeyedSubtree(
                key: _keyBentoGrid,
                child: _buildTacticalActionGrid(context, worker),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  TOP HEADER BAR (Avatar, Greeting, Language & Status Switch)
  // ──────────────────────────────────────────────────────────────
  Widget _buildTopQuickShiftBar(
      String name, Worker worker, bool isOnline, BuildContext context) {
    final now = DateTime.now();
    final dateStr = "Today, ${DateFormat('d MMM').format(now)}";

    return Row(
      children: [
        // Circular Avatar with Halo
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentNavIndex = 3);
          },
          child: StreamBuilder<AppUser?>(
            stream: AuthService().streamAppUser(widget.user.uid),
            initialData: widget.user,
            builder: (context, snap) {
              final avatar = snap.data?.avatarBase64 ?? widget.user.avatarBase64;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E0D8), width: 1.8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
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
        const SizedBox(width: 12),

        // Greeting & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello, $name",
                style: GoogleFonts.plusJakartaSans(
                  color: KX.textPrimary,
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                dateStr,
                style: GoogleFonts.plusJakartaSans(
                  color: KX.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Compact Language Switcher
        _buildCompactLangPill(context),
        const SizedBox(width: 8),

        // Titan Shift / Online Toggle Pill Button
        KeyedSubtree(
          key: _keyAvailabilitySwitch,
          child: GestureDetector(
            onTap: () => _toggleAvailability(worker),
            child: AnimatedContainer(
              duration: KAnim.fast,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isOnline ? KX.dockBlack : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isOnline ? KX.dockBlack : const Color(0xFFE5E0D8),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? "Online" : "Offline",
                    style: GoogleFonts.plusJakartaSans(
                      color: isOnline ? Colors.white : KX.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
        side: BorderSide(color: KX.gold.withValues(alpha: 0.3)),
      ),
      color: Colors.white,
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'en',
          child: Text('🇬🇧 English', style: TextStyle(color: KX.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        const PopupMenuItem(
          value: 'hi',
          child: Text('🇮🇳 हिन्दी (Hindi)', style: TextStyle(color: KX.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        const PopupMenuItem(
          value: 'ta',
          child: Text('🇮🇳 தமிழ் (Tamil)', style: TextStyle(color: KX.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E0D8), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, color: Color(0xFF8E8E93), size: 14),
            const SizedBox(width: 4),
            Text(
              currentCode.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: KX.textPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  HERO CARD: DAILY CHALLENGE & EARNINGS (Inspired by Reference)
  // ──────────────────────────────────────────────────────────────
  Widget _buildHeroDailyChallenge(Worker worker) {
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

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEDE8FF), Color(0xFFDFD4FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x127C3AED),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left Content Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Daily challenge",
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF1E1035),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Payout target: ₹2,000 today",
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF5B4D7A),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          "₹${todayEarnings.toInt()}",
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF1E1035),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1035),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            "${(goalProgress * 100).toInt()}% Done",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right 3D Geometric Visual Composition
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB800), Color(0xFFFF9500)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB800).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF3B2D60), Color(0xFF1E1438)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.speed_rounded,
                          color: Color(0xFFFFD666),
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  WEEKLY 7-DAY CALENDAR STRIP (Exact Reference Match)
  // ──────────────────────────────────────────────────────────────
  Widget _buildWeeklyCalendarStrip() {
    final now = DateTime.now();
    final sunday = now.subtract(Duration(days: now.weekday % 7));
    final weekDays = List.generate(7, (i) => sunday.add(Duration(days: i)));
    final dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final date = weekDays[index];
          final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
          final isSelected = _selectedDayIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedDayIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? KX.dockBlack : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: isSelected
                      ? null
                      : Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x2B000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.white
                            : (isToday ? KX.gold : Colors.transparent),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayNames[index],
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? Colors.white70 : const Color(0xFF8E8E93),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${date.day}",
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? Colors.white : KX.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  "YOUR PLAN" BENTO GRID SECTION (Inspired by Reference Image 1 & 2)
  // ──────────────────────────────────────────────────────────────
  Widget _buildYourPlanSection(BuildContext context, Worker worker) {
    return StreamBuilder<List<Booking>>(
      stream: _bookingService.streamWorkerIncomingRequests(
        workerId: worker.id,
        skills: worker.skills,
      ),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        final hasRequest = requests.isNotEmpty;
        final topReq = hasRequest ? requests.first : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Your plan",
                  style: GoogleFonts.plusJakartaSans(
                    color: KX.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                if (hasRequest)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      "${requests.length} LIVE",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Bento Row (Left tall sunny card + Right split cards)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── LEFT TALL CARD: Next Job / Standby (Sunny Amber)
                  Expanded(
                    flex: 11,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: KX.pastelAmber, // #FFDE9C
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0C000000),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Pill Tag
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  hasRequest ? "Priority" : "Standby",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF92400E),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Title
                              Text(
                                hasRequest ? topReq!.serviceType.toLocalizedTrade() : (worker.skills.isNotEmpty ? "${worker.skills.first} Shift" : "Artisan Standby"),
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF1E1035),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),

                              // Date & Time
                              Text(
                                "${DateFormat('d MMM').format(DateTime.now())} · ${worker.workingHoursStart} - ${worker.workingHoursEnd}",
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF78350F),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),

                              // Location
                              Text(
                                worker.baseAddress?.formattedAddress ?? worker.baseArea ?? "Active Radius ~${worker.serviceRadiusKm.toInt()} km",
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF78350F),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Customer / Action Footer
                          if (hasRequest)
                            GestureDetector(
                              onTap: () async {
                                await _bookingService.acceptBooking(topReq!.id, worker.id);
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: KX.dockBlack,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.flash_on_rounded, color: KX.gold, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      "Accept Job",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF1E1035),
                                  ),
                                  child: const Icon(Icons.handyman_rounded, color: KX.gold, size: 14),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "WorkGo Co-op",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF1E1035),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        "Ready for jobs",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF78350F),
                                          fontSize: 9.5,
                                        ),
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
                  const SizedBox(width: 12),

                  // ── RIGHT COLUMN: Stacked Cards
                  Expanded(
                    flex: 10,
                    child: Column(
                      children: [
                        // Right Top: Radar / Dispatch Card (Soft Sky Blue)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _currentNavIndex = 1);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: KX.pastelSky, // #D6EBFF
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          "Radar",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: const Color(0xFF1D4ED8),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.radar_rounded, color: Color(0xFF1D4ED8), size: 16),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Live Radar",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF1E3A8A),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    "${worker.serviceRadiusKm.toInt()} km coverage\nListening...",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF3B82F6),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Right Bottom: Quick 3 Actions Row (Soft Pink)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                          decoration: BoxDecoration(
                            color: KX.pastelPink, // #FFD6EC
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _quickActionIconCircle(
                                icon: Icons.account_balance_wallet_rounded,
                                color: const Color(0xFF9D174D),
                                onTap: () => setState(() => _currentNavIndex = 2),
                              ),
                              _quickActionIconCircle(
                                icon: Icons.health_and_safety_rounded,
                                color: const Color(0xFF9D174D),
                                onTap: () => setState(() => _currentNavIndex = 3),
                              ),
                              _quickActionIconCircle(
                                icon: Icons.groups_rounded,
                                color: const Color(0xFF9D174D),
                                onTap: () => showPeerReferralNetworkSheet(
                                  context,
                                  worker: worker,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _quickActionIconCircle({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  VERIFICATION ALERT BANNER
  // ──────────────────────────────────────────────────────────────
  Widget _buildVerificationAlertBanner(BuildContext context, Worker worker) {
    final stage = worker.verificationStage;
    String stageText = "Start Aadhaar & 3D Face Biometric verification";
    if (stage == VerificationStage.consent) {
      stageText = "Step 1/4: Review & accept DPDP 2023 Biometric Consent";
    } else if (stage == VerificationStage.aadhaarOfflineEkyc) {
      stageText = "Step 2/4: Upload Aadhaar Offline ZIP or Card Photo";
    } else if (stage == VerificationStage.selfieCapture || stage == VerificationStage.onDeviceLiveness || stage == VerificationStage.multiAngleLiveness) {
      stageText = "Step 3/4: Start 3D Multi-Angle Face Biometrics";
    } else if (stage == VerificationStage.pccUpload || stage == VerificationStage.pccManualReview) {
      stageText = "Step 4/4: Upload Police Clearance Certificate for badging";
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3D6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KX.gold.withValues(alpha: 0.6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: KX.gold.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, color: Color(0xFFD97706), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Identity Verification Required",
                    style: GoogleFonts.plusJakartaSans(
                      color: KX.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stageText,
                    style: GoogleFonts.plusJakartaSans(
                      color: KX.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: KX.textPrimary, size: 13),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  TACTICAL ACTION MATRIX (Operating Base Station + Referral Banner)
  // ──────────────────────────────────────────────────────────────
  Widget _buildTacticalActionGrid(BuildContext context, Worker worker) {
    final activeLocation = worker.baseAddress?.formattedAddress ??
        worker.baseArea ??
        (worker.preferredAreas.isNotEmpty ? worker.preferredAreas.first : "Erode Central, Tamil Nadu");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Operating Base Card
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
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
                        color: const Color(0xFFFFF3D6),
                        borderRadius: BorderRadius.circular(12),
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
                                "OPERATING BASE",
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFB45309),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "${worker.serviceRadiusKm.toInt()} km Range",
                                  style: const TextStyle(
                                    color: Color(0xFF065F46),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeLocation,
                            style: GoogleFonts.plusJakartaSans(
                              color: KX.textPrimary,
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
                const SizedBox(height: 12),
                // Skills Rail Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...worker.skills.take(3).map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F6EE),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFF0EDE6)),
                            ),
                            child: Text(
                              s,
                              style: GoogleFonts.plusJakartaSans(
                                color: KX.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: KX.dockBlack,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_location_alt_rounded, color: Colors.white, size: 11),
                          SizedBox(width: 4),
                          Text(
                            "Change",
                            style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
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

        // ── Peer Referral Banner
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            showPeerReferralNetworkSheet(
              context,
              worker: worker,
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.groups_rounded, color: KX.gold, size: 20),
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
                            style: GoogleFonts.plusJakartaSans(
                              color: KX.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
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
                              "2% CUT",
                              style: TextStyle(
                                color: Color(0xFFB45309),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Refer peer artisans to earn direct co-op incentives",
                        style: GoogleFonts.plusJakartaSans(
                          color: KX.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF8E8E93),
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
