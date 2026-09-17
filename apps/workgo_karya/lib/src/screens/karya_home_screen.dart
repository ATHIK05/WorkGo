import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../karya_theme.dart';
import '../services/karya_equipment_engine.dart';
import '../services/karya_tts_service.dart';
import 'active_job_screen.dart';
import 'document_upload_screen.dart';
import 'incoming_requests_screen.dart';
import 'worker_earnings_screen.dart';
import 'worker_profile_detail_screen.dart';
import 'daily_face_verification_screen.dart';
import '../widgets/karya_spotlight_tour.dart';
import '../widgets/handoff_acknowledgment_dialog.dart';
import '../widgets/karya_start_otp_sheet.dart';
import '../widgets/sos_beacon_bottom_sheet.dart';
import '../widgets/job_preparation_tools_sheet.dart';
import 'refer_dial_member_screen.dart';

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
  int _weekOffset = 0;
  DateTime _selectedDate = DateTime.now();
  late AnimationController _radarCtrl;
  static bool _hasPromptedThisSession = false;
  String? _lastAnnouncedRequestId; // TTS dedup tracker
  String? _lastAnnouncedPeerSosId; // Peer SOS TTS dedup tracker
  String? _playingPeerSosAudioDocId; // Active SOS audio proof playback tracker

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

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

  // Location broadcasting throttling to prevent frequent Firestore document updates & root rebuilds
  double? _lastBroadcastLat;
  double? _lastBroadcastLng;
  DateTime? _lastBroadcastTime;

  // Cached streams for dock badge & cockpit active jobs to eliminate rebuild lag
  Stream<List<Booking>>? _dockIncomingStream;
  String? _dockWorkerId;
  Stream<Booking?>? _cachedActiveJobStream;
  Stream<List<Booking>>? _cachedHandoffStream;
  String? _cachedActiveJobWorkerId;

  @override
  void initState() {
    super.initState();
    KaryaHomeScreen._activeState = this;
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _ensureWorkerProfileExists();
    // Init TTS for voice radar
    KaryaTtsService.instance.init(
      languageCode: 'en', // will be updated per locale at runtime
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await KaryaTtsService.instance.updateLanguage(
          context.locale.languageCode,
          announceChange: false,
        );
      }
      await _checkAndPromptWorkerLocation();
      try {
        final worker = await _workerService.fetchWorkerByUserId(
          widget.user.uid,
        );
        if (worker != null &&
            worker.availabilityStatus == AvailabilityStatus.online) {
          _startLiveLocationBroadcasting(worker.id);
        }
      } catch (_) {}
      if (mounted) {
        await _checkAndShowAppTour();
      }
    });
  }

  void _startLiveLocationBroadcasting(String workerId) {
    LocationService.instance.startRealtimeBroadcast(
      onLocationUpdate: (lat, lng) async {
        if (lat != 0.0 && lng != 0.0) {
          final now = DateTime.now();
          final hasMoved =
              _lastBroadcastLat == null ||
              _lastBroadcastLng == null ||
              LocationService().calculateDistanceKm(
                    _lastBroadcastLat!,
                    _lastBroadcastLng!,
                    lat,
                    lng,
                  ) >=
                  0.035; // Moved at least 35 meters
          final timeElapsed =
              _lastBroadcastTime == null ||
              now.difference(_lastBroadcastTime!).inSeconds >= 45;

          if (hasMoved || timeElapsed) {
            _lastBroadcastLat = lat;
            _lastBroadcastLng = lng;
            _lastBroadcastTime = now;
            await _workerService.updateWorkerLocation(workerId, lat, lng);
          }
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
    EmergencySosService.instance.stopAudioPlayback();
    _stopLiveLocationBroadcasting();
    _radarCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkAndShowAppTour() async {
    await Future.delayed(const Duration(milliseconds: 1500));
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
        pageTitle: 'spotlight_page_cockpit'.trSafe('Home Cockpit'),
        stepNumber: "1",
        title: 'spotlight_title_1'.trSafe(
          '1. Autonomous Shift & Check-In Switch',
        ),
        description: 'spotlight_desc_1'.trSafe(
          'Tap here anytime to go live on customer radars across your district. Verification is required before your first check-in.',
        ),
        badgeText: 'spotlight_badge_availability'.trSafe('AVAILABILITY'),
        icon: Icons.power_settings_new_rounded,
        bulletPoints: [
          'spotlight_bullet_1_1'.trSafe(
            '1-Tap Check-In toggles incoming job dispatch radar',
          ),
          'spotlight_bullet_1_2'.trSafe(
            'Automatic verification check protects artisan earnings',
          ),
        ],
      ),
      SpotlightTarget(
        key: _keyFuelGauge,
        navIndex: 0,
        pageTitle: 'spotlight_page_cockpit'.trSafe('Home Cockpit'),
        stepNumber: "2",
        title: 'spotlight_title_2'.trSafe(
          '2. Daily Fuel Gauge & Earnings Cockpit',
        ),
        description: 'spotlight_desc_2'.trSafe(
          "Track today's jobs, total earnings, active hours, and performance incentives with a strict 0% commission guarantee.",
        ),
        badgeText: 'spotlight_badge_zero_commission'.trSafe('0% COMMISSION'),
        icon: Icons.speed_rounded,
        bulletPoints: [
          'spotlight_bullet_2_1'.trSafe(
            'Live progress tracker towards daily earning milestones',
          ),
          'spotlight_bullet_2_2'.trSafe(
            'Instant 1-tap UPI / Bank payout settlements',
          ),
        ],
      ),
      SpotlightTarget(
        key: _keyRadar,
        navIndex: 0,
        pageTitle: 'spotlight_page_cockpit'.trSafe('Home Cockpit'),
        stepNumber: "3",
        title: 'spotlight_title_3'.trSafe('3. Live Dispatch Radar & Job Match'),
        description: 'spotlight_desc_3'.trSafe(
          'Nearby service requests flash in real time with distance, upfront pricing, and a 30-second priority acceptance countdown.',
        ),
        badgeText: 'spotlight_badge_priority_radar'.trSafe('PRIORITY RADAR'),
        icon: Icons.radar_rounded,
        bulletPoints: [
          'spotlight_bullet_3_1'.trSafe(
            '30s audio chime countdown to accept before others',
          ),
          'spotlight_bullet_3_2'.trSafe(
            'Upfront pricing and customer pickup distance shown',
          ),
        ],
      ),
      SpotlightTarget(
        key: _keyBentoGrid,
        navIndex: 0,
        pageTitle: 'spotlight_page_cockpit'.trSafe('Home Cockpit'),
        stepNumber: "4",
        title: 'spotlight_title_4'.trSafe('4. Tactical Action Matrix'),
        description: 'spotlight_desc_4'.trSafe(
          'Quick access to government Aadhaar & Video KYC, ₹2L welfare cover, and peer referral network.',
        ),
        badgeText: 'spotlight_badge_action_matrix'.trSafe('ACTION MATRIX'),
        icon: Icons.grid_view_rounded,
        bulletPoints: [
          'spotlight_bullet_4_1'.trSafe(
            'Complete Video KYC to earn the trusted Co-op Certified badge',
          ),
          'spotlight_bullet_4_2'.trSafe(
            '₹2,00,000 accidental and disability insurance coverage',
          ),
        ],
      ),

      // ── PAGE 2: INCOMING REQUESTS & RADAR (navIndex: 1)
      SpotlightTarget(
        key: _keyRequestsHub,
        navIndex: 1,
        pageTitle: 'spotlight_page_requests'.trSafe('Requests & Radar'),
        stepNumber: "5",
        title: 'spotlight_title_5'.trSafe(
          '5. Real-Time Dispatch Broadcast Hub',
        ),
        description: 'spotlight_desc_5'.trSafe(
          'Live radar listening for broadcasts in your trade skills. Instant cards alert you with customer location, price, and distance.',
        ),
        badgeText: 'spotlight_badge_job_alerts'.trSafe('JOB ALERTS'),
        icon: Icons.cell_tower_rounded,
        bulletPoints: [
          'spotlight_bullet_5_1'.trSafe(
            '30-second priority allocation before secondary dispatch',
          ),
          'spotlight_bullet_5_2'.trSafe(
            '1-tap Accept to claim job and start secure turn-by-turn navigation',
          ),
        ],
      ),

      // ── PAGE 3: EARNINGS & INSTANT PAYOUTS (navIndex: 2)
      SpotlightTarget(
        key: _keyEarningsHero,
        navIndex: 2,
        pageTitle: 'spotlight_page_earnings'.trSafe('Earnings Ledger'),
        stepNumber: "6",
        title: 'spotlight_title_6'.trSafe(
          '6. Direct Wage Payouts (0% Commission)',
        ),
        description: 'spotlight_desc_6'.trSafe(
          'All customer payments go 100% directly to you. WorkGo charges 0% platform commission with a tiny 2% allocated to your welfare fund.',
        ),
        badgeText: 'spotlight_badge_zero_deductions'.trSafe('ZERO DEDUCTIONS'),
        icon: Icons.account_balance_wallet_rounded,
        bulletPoints: [
          'spotlight_bullet_6_1'.trSafe(
            'Instant 1-tap UPI transfer straight into your bank account',
          ),
          'spotlight_bullet_6_2'.trSafe(
            'Complete transaction receipt log for every serviced booking',
          ),
        ],
      ),

      // ── PAGE 4: WELFARE & INSURANCE SHIELD (navIndex: 3)
      SpotlightTarget(
        key: _keyWelfareShield,
        navIndex: 3,
        pageTitle: 'spotlight_page_welfare'.trSafe('Welfare & Insurance'),
        stepNumber: "7",
        title: 'spotlight_title_7'.trSafe(
          '7. ₹2 Lakh Welfare Shield & Protection',
        ),
        description: 'spotlight_desc_7'.trSafe(
          'Every verified cooperative artisan receives ₹2,00,000 accidental & disability cover (PMSBY / PMJJBY) on duty.',
        ),
        badgeText: 'spotlight_badge_safety_shield'.trSafe('SAFETY SHIELD'),
        icon: Icons.health_and_safety_rounded,
        bulletPoints: [
          'spotlight_bullet_7_1'.trSafe(
            'Digital Holographic ID Card with verified policy number',
          ),
          'spotlight_bullet_7_2'.trSafe(
            '24/7 Emergency SOS beacon and health claim support',
          ),
        ],
      ),

      // ── PAGE 4: PROFILE & OPERATIONAL SETTINGS (navIndex: 3)
      SpotlightTarget(
        key: _keyProfileHub,
        navIndex: 3,
        pageTitle: 'spotlight_page_profile'.trSafe('Profile & Hub'),
        stepNumber: "8",
        title: 'spotlight_title_8'.trSafe(
          '8. Operating Bases & Service Radius',
        ),
        description: 'spotlight_desc_8'.trSafe(
          'Configure your workshop base, set coverage radius (1–30 km), manage trade skills, and customize working shift hours.',
        ),
        badgeText: 'spotlight_badge_base_radius'.trSafe('BASE & RADIUS'),
        icon: Icons.location_on_rounded,
        bulletPoints: [
          'spotlight_bullet_8_1'.trSafe(
            'Set multiple operating bases (Primary Workshop & Home)',
          ),
          'spotlight_bullet_8_2'.trSafe(
            'Adjust radar dispatch radius to match your vehicle range',
          ),
        ],
      ),
      SpotlightTarget(
        key: _keyProfileKyc,
        navIndex: 3,
        pageTitle: 'spotlight_page_profile'.trSafe('Profile & Hub'),
        stepNumber: "9",
        title: 'spotlight_title_9'.trSafe(
          '9. Identity Verification & Language Hub',
        ),
        description: 'spotlight_desc_9'.trSafe(
          'Access your government eKYC records, trigger Video KYC reviews, and switch app language instantly (தமிழ், हिंदी, English).',
        ),
        badgeText: 'spotlight_badge_kyc_vernacular'.trSafe('KYC & VERNACULAR'),
        icon: Icons.verified_user_rounded,
        bulletPoints: [
          'spotlight_bullet_9_1'.trSafe(
            'Tamper-proof C2PA proof of work verification',
          ),
          'spotlight_bullet_9_2'.trSafe(
            'Full vernacular audio voice support for illiterate artisans',
          ),
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
      final alreadyConfigured =
          prefs.getBool("worker_loc_done_${widget.user.uid}") ?? false;
      if (alreadyConfigured) return;

      final doc = await FirebaseFirestore.instance
          .collection("workers")
          .doc(widget.user.uid)
          .get();
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

      final hasLocation =
          addrSnap.docs.isNotEmpty ||
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
        name: widget.user.displayName.isNotEmpty
            ? widget.user.displayName
            : "Co-op Artisan",
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
    final isCurrentlyOnline =
        worker.availabilityStatus == AvailabilityStatus.online;

    if (!isCurrentlyOnline) {
      // Worker is checking in / going online! Strictly enforce identity verification:
      if (worker.verificationStatus != VerificationStatus.approved) {
        HapticFeedback.heavyImpact();
        _showVerificationRequiredModal(context, worker);
        return;
      }

      // 1. Native Biometric Fingerprint/Face ID verification prompt
      final authenticated = await BiometricService().authenticate(
        reason:
            "Scan fingerprint or face to verify identity before going live on radar.",
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Biometric verification cancelled. Check-in aborted.",
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFE11D48),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }
        return;
      }

      // 2. Mandatory Daily 3D Face Verification against registered KYC selfie
      if (mounted) {
        final faceVerified = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => DailyFaceVerificationScreen(worker: worker),
          ),
        );

        if (faceVerified != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(
                      Icons.face_retouching_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "3D Face verification cancelled or failed. Check-in aborted.",
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFE11D48),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            );
          }
          return;
        }
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
                      style: WorkGoFonts.body(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E1035),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: KX.gold.withValues(alpha: 0.6),
                  width: 1.2,
                ),
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
        final baseText =
            "${worker.baseArea ?? ''} ${worker.baseAddress?.formattedAddress ?? ''}"
                .trim();
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
    await _workerService.checkInTitan(
      worker.id,
      nextStatus == AvailabilityStatus.online,
    );
    // TTS: announce online / offline
    if (nextStatus == AvailabilityStatus.online) {
      KaryaTtsService.instance.announceOnline();
      if (mounted) {
        _showPreShiftGearAdvisor(context, worker);
      }
    } else {
      KaryaTtsService.instance.announceOffline();
    }
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
                    border: Border.all(
                      color: const Color(0xFFF59E0B),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFF59E0B),
                    size: 36,
                  ),
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
                style: TextStyle(
                  color: KX.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
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
                    const Icon(
                      Icons.verified_user_rounded,
                      color: KX.gold,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Instant Co-op Badging",
                            style: TextStyle(
                              color: KX.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Status: ${worker.verificationStage.name.toUpperCase()} (Pending Review)",
                            style: const TextStyle(
                              color: KX.gold,
                              fontSize: 11,
                            ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Complete Verification Now",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  "I'll do it later",
                  style: TextStyle(color: KX.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  MAP NAVIGATION LAUNCHER
  // ──────────────────────────────────────────────────────────────
  static Future<void> _launchMapsNavigation(
    String? address,
    double? lat,
    double? lng,
  ) async {
    Uri? uri;
    if (lat != null && lng != null) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
        if (!await canLaunchUrl(uri)) {
          uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
          );
        }
      } else {
        uri = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
        if (!await canLaunchUrl(uri)) {
          uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
          );
        }
      }
    } else if (address?.isNotEmpty == true) {
      final encoded = Uri.encodeComponent(address!);
      if (defaultTargetPlatform == TargetPlatform.android) {
        uri = Uri.parse('geo:0,0?q=$encoded');
        if (!await canLaunchUrl(uri)) {
          uri = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$encoded',
          );
        }
      } else {
        uri = Uri.parse('https://maps.apple.com/?q=$encoded&dirflg=d');
        if (!await canLaunchUrl(uri)) {
          uri = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$encoded',
          );
        }
      }
    }
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  SOS EMERGENCY BEACON SHEET WITH LIVE GPS & 10S AUDIO RECORDING
  // ──────────────────────────────────────────────────────────────
  void _showSosBeaconSheet(
    BuildContext context,
    Worker worker, {
    String? bookingId,
    String? customerId,
  }) {
    showSosBeaconBottomSheet(
      context,
      worker: worker,
      user: widget.user,
      bookingId: bookingId,
      customerId: customerId,
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  PEER KYC BOUNTY ALERT — Dial Karya (₹150 per verified member)
  // ──────────────────────────────────────────────────────────────
  Widget _buildPeerKycBountyAlerts(BuildContext context, Worker worker) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('workers')
          .where('isDialWorker', isEqualTo: true)
          .where('verificationStage', isEqualTo: 'pending_peer_kyc')
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final dialWorkerDocs = snapshot.data!.docs;

        return Column(
          children: dialWorkerDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] as String? ?? 'Dial Worker';
            final trade = (data['skills'] as List?)?.firstOrNull?.toString() ?? 'General';
            final phone = data['phoneForCalling'] as String? ?? '';
            final areas = (data['preferredAreas'] as List?)?.join(', ') ?? '';

            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReferDialMemberScreen(
                      mitraWorker: worker,
                      dialWorkerId: doc.id,
                      dialWorkerName: name,
                      dialWorkerPhone: phone,
                      dialWorkerTrade: trade,
                      backendBaseUrl: const String.fromEnvironment(
                        'BACKEND_BASE_URL',
                        defaultValue: 'https://workgo-backend.onrender.com',
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      KX.pastelAmber.withValues(alpha: 0.95),
                      KX.canvasElevated,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: KX.brandAmber.withValues(alpha: 0.45), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: KX.brandAmber.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: KX.luminaVioletGold,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: KX.brandAmber.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'peer_kyc_alert_title'.trSafe('⚡ Earn ₹150 — Verify $name', [name]),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: KX.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$trade${areas.isNotEmpty ? " • $areas" : ""}',
                            style: TextStyle(
                              color: KX.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: KX.luminaVioletGold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'peer_kyc_btn'.trSafe('KYC →'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  PEER ARTISAN SOS DISTRESS ALERT CARD RECEIVER
  // ──────────────────────────────────────────────────────────────
  Widget _buildPeerSosBeaconAlerts(BuildContext context, Worker worker) {

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('emergency_beacons')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // Filter out beacons created by this worker
        final peerBeacons = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          return data['workerId'] != worker.id;
        }).toList();

        if (peerBeacons.isEmpty) return const SizedBox.shrink();

        final topDoc = peerBeacons.first;
        final data = topDoc.data() as Map<String, dynamic>;
        final peerName = data['workerName'] as String? ?? 'Fellow Artisan';
        final peerPhone = data['workerPhone'] as String?;
        final address = data['address'] as String? ?? 'Nearby service location';
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        final audioBase64 = (data['audioBase64'] as String?) ?? '';
        final hasAudio =
            (data['hasAudio'] as bool? ?? false) && audioBase64.isNotEmpty;
        final policeMap = data['nearestPoliceStation'] as Map<String, dynamic>?;
        final policeInfo = PoliceStationInfo.fromMap(policeMap);

        // Voice announce peer SOS if online and not yet announced
        if (worker.availabilityStatus == AvailabilityStatus.online &&
            topDoc.id != _lastAnnouncedPeerSosId) {
          _lastAnnouncedPeerSosId = topDoc.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            KaryaTtsService.instance.announcePeerSos(peerName);
          });
        }

        final isPlayingThisAudio = _playingPeerSosAudioDocId == topDoc.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
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
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.emergency_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'sos_peer_alert_title'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Text(
                      "LIVE SOS",
                      style: TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'sos_peer_alert_desc'.tr(args: [peerName]),
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 13,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (policeInfo.name.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFCA5A5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_police_rounded,
                        size: 12,
                        color: Color(0xFFB91C1C),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'sos_nearest_police_station'.tr(
                            args: [
                              policeInfo.name,
                              policeInfo.distanceKm.toStringAsFixed(1),
                            ],
                          ),
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (hasAudio) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (isPlayingThisAudio) {
                        await EmergencySosService.instance.stopAudioPlayback();
                        if (mounted) {
                          setState(() => _playingPeerSosAudioDocId = null);
                        }
                      } else {
                        setState(() => _playingPeerSosAudioDocId = topDoc.id);
                        await EmergencySosService.instance.playAudioBase64(
                          audioBase64,
                          onComplete: () {
                            if (mounted) {
                              setState(() => _playingPeerSosAudioDocId = null);
                            }
                          },
                        );
                      }
                    },
                    icon: Icon(
                      isPlayingThisAudio
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_filled_rounded,
                      size: 16,
                      color: const Color(0xFFB91C1C),
                    ),
                    label: Text(
                      isPlayingThisAudio
                          ? 'sos_stop_audio_proof'.tr()
                          : 'sos_play_audio_proof'.tr(),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB91C1C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFFEF4444),
                        width: 1.2,
                      ),
                      backgroundColor: isPlayingThisAudio
                          ? const Color(0xFFFEE2E2)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (peerPhone != null && peerPhone.isNotEmpty) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse('tel:$peerPhone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        icon: const Icon(Icons.phone_rounded, size: 14),
                        label: Text(
                          'sos_call_peer'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Uri? uri;
                        if (lat != null && lng != null) {
                          uri = Uri.parse(
                            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                          );
                        } else if (address.isNotEmpty) {
                          uri = Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
                          );
                        }
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.near_me_rounded, size: 14),
                      label: Text(
                        'sos_nav_peer'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF991B1B),
                        side: const BorderSide(
                          color: Color(0xFFFCA5A5),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse('tel:112');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      icon: const Icon(Icons.local_police_rounded, size: 14),
                      label: Text(
                        'sos_call_police_112'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
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

  // ──────────────────────────────────────────────────────────────
  //  SMART PRE-SHIFT GEAR ADVISOR SHEET
  // ──────────────────────────────────────────────────────────────
  void _showPreShiftGearAdvisor(BuildContext context, Worker worker) {
    final skill = worker.skills.isNotEmpty ? worker.skills.first : 'General';
    final tools = KaryaEquipmentEngine.suggestTools(skill, null);
    if (tools.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final checkedTools = <String>{...tools.take(2)};
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
              decoration: BoxDecoration(
                color: KX.canvasCard,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: KX.gold.withValues(alpha: 0.6),
                  width: 1.5,
                ),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: KX.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.handyman_rounded,
                          color: KX.gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'preshiftadvisor_title'.tr(),
                              style: const TextStyle(
                                color: KX.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "$skill \u2022 Confirm essentials",
                              style: const TextStyle(
                                color: KX.textSecondary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tools.map((tool) {
                      final isChecked = checkedTools.contains(tool);
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setModalState(() {
                            if (isChecked) {
                              checkedTools.remove(tool);
                            } else {
                              checkedTools.add(tool);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isChecked
                                ? KX.gold.withValues(alpha: 0.2)
                                : KX.canvasMid,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isChecked ? KX.gold : KX.glassBorder,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isChecked
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 14,
                                color: isChecked ? KX.gold : KX.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tool,
                                style: TextStyle(
                                  color: isChecked ? KX.gold : KX.textPrimary,
                                  fontSize: 12,
                                  fontWeight: isChecked
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(sheetCtx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KX.gold,
                      foregroundColor: const Color(0xFF1E1035),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'preshiftadvisor_ready'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Worker?>(
      stream: _workerService.streamWorker(widget.user.uid),
      builder: (context, snapshot) {
        final worker =
            snapshot.data ??
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
                            color: isActive
                                ? const Color(0xFF141416)
                                : const Color(0xFF8E8E93),
                          ),
                          if (isRadar)
                            () {
                              if (_dockIncomingStream == null ||
                                  _dockWorkerId != worker.id) {
                                _dockWorkerId = worker.id;
                                _dockIncomingStream = _bookingService
                                    .streamWorkerIncomingRequests(
                                      workerId: worker.id,
                                      skills: worker.skills,
                                    );
                              }
                              return StreamBuilder<List<Booking>>(
                                stream: _dockIncomingStream,
                                builder: (context, snap) {
                                  final reqCount = snap.data?.length ?? 0;
                                  if (reqCount == 0) {
                                    return const SizedBox.shrink();
                                  }

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
                              );
                            }(),
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
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 130),
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

            // ── 1.5 Peer Artisan SOS Distress Beacon Alert (Live Stream)
            _buildPeerSosBeaconAlerts(context, worker),

            // ── 1.6 Peer KYC Bounty Alert (Dial Karya — Live Stream)
            if (worker.verificationStatus == VerificationStatus.approved)
              _buildPeerKycBountyAlerts(context, worker),

            // ── 2. Verification Alert Banner (if unverified)
            if (worker.verificationStatus != VerificationStatus.approved) ...[
              KSlideFadeIn(
                delay: const Duration(milliseconds: 20),
                child: _buildVerificationAlertBanner(context, worker),
              ),
              const SizedBox(height: 14),
            ],


            // ── 2.5 Live Active Mission Card (If artisan has an accepted or in-progress booking)
            () {
              if (_cachedActiveJobStream == null ||
                  _cachedActiveJobWorkerId != worker.id) {
                _cachedActiveJobWorkerId = worker.id;
                _cachedActiveJobStream = _bookingService.streamCurrentActiveJob(
                  worker.id,
                );
                _cachedHandoffStream = _bookingService
                    .streamWorkerHandoffRequests(worker.id);
              }
              return StreamBuilder<Booking?>(
                stream: _cachedActiveJobStream,
                builder: (context, activeSnap) {
                  final activeBooking = activeSnap.data;
                  if (activeBooking == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: KSlideFadeIn(
                      child: _buildActiveMissionCockpitCard(
                        context,
                        activeBooking,
                        worker,
                      ),
                    ),
                  );
                },
              );
            }(),

            // ── 2.6 Incoming Specialist Co-op Relay Alert (Mutual Acknowledgment)
            StreamBuilder<List<Booking>>(
              stream: _cachedHandoffStream,
              builder: (context, handoffSnap) {
                final requests = handoffSnap.data ?? [];
                if (requests.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: requests.map((b) {
                      return _buildSpecialistRelayAlertCard(context, b, worker);
                    }).toList(),
                  ),
                );
              },
            ),

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
  //  SPECIALIST RELAY ALERT CARD (Mutual Acknowledgment Action)
  // ──────────────────────────────────────────────────────────────
  Widget _buildSpecialistRelayAlertCard(
    BuildContext context,
    Booking booking,
    Worker worker,
  ) {
    final fromName = booking.handoffFromWorkerName ?? 'Peer Artisan';
    final notes =
        booking.handoffDiagnosisNotes ?? 'Pre-inspection findings attached.';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
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
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Specialist Relay Alert',
                      style: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Referred by $fromName · Awaiting your mutual acknowledgment',
                      style: const TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ACTION REQ',
                  style: TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Diagnosis: "$notes"',
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final accepted = await HandoffAcknowledgmentDialog.show(
                  context,
                  booking: booking,
                  currentSpecialist: worker,
                );
                if (accepted == true && context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ActiveJobScreen(
                        booking: booking.copyWith(
                          workerId: worker.id,
                          acceptedWorkerName: worker.name,
                          handoffStatus: 'accepted',
                          status: BookingStatus.accepted,
                        ),
                        worker: worker,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.rate_review_rounded, size: 16),
              label: const Text(
                'Review Pre-Inspection & Acknowledge',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  TOP HEADER BAR (Avatar, Greeting, Language & Status Switch)
  // ──────────────────────────────────────────────────────────────
  Widget _buildTopQuickShiftBar(
    String name,
    Worker worker,
    bool isOnline,
    BuildContext context,
  ) {
    final now = DateTime.now();
    final dateStr =
        "${'today_label'.trSafe('Today')}, ${DateFormat('d MMM', context.locale.languageCode).format(now)}";

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
              final avatar =
                  snap.data?.avatarBase64 ?? widget.user.avatarBase64;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE5E0D8),
                    width: 1.8,
                  ),
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
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'greeting_hello'.trSafe('Hello, {}', [name]),
                  style: GoogleFonts.plusJakartaSans(
                    color: KX.textPrimary,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                ),
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
                      color: isOnline
                          ? const Color(0xFF10B981)
                          : const Color(0xFF9CA3AF),
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
        WorkGoLocale.setLocaleCode(code);
        await context.setLocale(Locale(code));
        await KaryaTtsService.instance.updateLanguage(
          code,
          announceChange: true,
        );
        setState(() {});
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: KX.gold.withValues(alpha: 0.3)),
      ),
      color: Colors.white,
      itemBuilder: (ctx) => WorkGoLocale.allLanguages.map((lang) {
        final isSelected = lang.code == currentCode;
        return PopupMenuItem<String>(
          value: lang.code,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${lang.nativeName} (${lang.englishName})',
                style: TextStyle(
                  color: isSelected ? KX.violet : KX.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_rounded, color: KX.violet, size: 16),
            ],
          ),
        );
      }).toList(),

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
            const Icon(
              Icons.language_rounded,
              color: Color(0xFF8E8E93),
              size: 14,
            ),
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
        final completed = jobs
            .where((b) => b.status == BookingStatus.completed)
            .toList();

        // Dynamically filter jobs for the selected calendar date
        final isToday = _isSameDay(_selectedDate, DateTime.now());
        final isYesterday = _isSameDay(
          _selectedDate,
          DateTime.now().subtract(const Duration(days: 1)),
        );
        final isTomorrow = _isSameDay(
          _selectedDate,
          DateTime.now().add(const Duration(days: 1)),
        );
        final isFuture = _selectedDate.isAfter(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        );

        final selectedDayCompleted = completed.where((b) {
          final dt = b.completedAt ?? b.scheduledAt;
          if (dt != null) {
            return _isSameDay(dt, _selectedDate);
          }
          return isToday;
        }).toList();

        final selectedDayEarnings = selectedDayCompleted.fold<double>(
          0.0,
          (total, b) => total + (b.totalAmount * 0.98),
        );

        const dailyGoal = 2000.0;
        final goalProgress = (selectedDayEarnings / dailyGoal).clamp(0.0, 1.0);

        final cardTitle = isToday
            ? 'daily_challenge_title'.trSafe("Daily challenge")
            : isYesterday
            ? 'yesterdays_earnings_title'.trSafe("Yesterday's earnings")
            : isTomorrow
            ? 'tomorrows_target_title'.trSafe("Tomorrow's target")
            : isFuture
            ? 'forecast_title'.trSafe("Forecast · {}", [
                DateFormat(
                  'EEE, d MMM',
                  context.locale.languageCode,
                ).format(_selectedDate),
              ])
            : 'earnings_title'.trSafe("Earnings · {}", [
                DateFormat(
                  'EEE, d MMM',
                  context.locale.languageCode,
                ).format(_selectedDate),
              ]);

        final cardSubtitle = isToday
            ? 'payout_target_today'.trSafe("Payout target: ₹2,000 today")
            : isFuture
            ? 'target_planned_shift'.trSafe("Target: ₹2,000 · Planned shift")
            : 'target_shift_log'.trSafe("Target: ₹2,000 · Shift log");

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
                      cardTitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF1E1035),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cardSubtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF5B4D7A),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          "₹${selectedDayEarnings.toInt()}",
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF1E1035),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1035),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            "${(goalProgress * 100).toInt()}% ${isFuture ? 'goal_target_label'.trSafe('Target') : 'goal_done_label'.trSafe('Done')}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isToday && selectedDayEarnings > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF10B981),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  size: 12,
                                  color: Color(0xFF047857),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  "₹${(selectedDayEarnings / (DateTime.now().hour - 8).clamp(1, 10)).round()}/hr ${'earnings_velocity_label'.tr()}",
                                  style: const TextStyle(
                                    color: Color(0xFF047857),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
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
                            color: const Color(
                              0xFFFFB800,
                            ).withValues(alpha: 0.4),
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
  //  WEEKLY 7-DAY CALENDAR STRIP (Dynamic Shifting & Interactive)
  // ──────────────────────────────────────────────────────────────
  Widget _buildWeeklyCalendarStrip() {
    final now = DateTime.now();
    final anchor = now.add(Duration(days: _weekOffset * 7));
    final sunday = DateTime(
      anchor.year,
      anchor.month,
      anchor.day,
    ).subtract(Duration(days: anchor.weekday % 7));
    final weekDays = List.generate(7, (i) => sunday.add(Duration(days: i)));
    final dayNames = List.generate(7, (i) {
      try {
        return DateFormat('E', context.locale.languageCode).format(weekDays[i]);
      } catch (_) {
        const fallbacks = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        return fallbacks[i];
      }
    });
    final monthLabel = DateFormat(
      'MMMM yyyy',
      context.locale.languageCode,
    ).format(weekDays[3]);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar Navigation Header (Month & Shifts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2, right: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      monthLabel,
                      style: GoogleFonts.plusJakartaSans(
                        color: KX.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_weekOffset != 0) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _weekOffset = 0;
                            _selectedDate = DateTime.now();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: KX.dockBlack,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.today_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'today_label'.trSafe("Today"),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // Navigation Chevrons
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _weekOffset--;
                          _selectedDate = _selectedDate.subtract(
                            const Duration(days: 7),
                          );
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF0EDE6),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: KX.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _weekOffset++;
                          _selectedDate = _selectedDate.add(
                            const Duration(days: 7),
                          );
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF0EDE6),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: KX.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 7-Day Capsule Strip with Horizontal Gesture Swiping
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -180) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _weekOffset++;
                    _selectedDate = _selectedDate.add(const Duration(days: 7));
                  });
                } else if (details.primaryVelocity! > 180) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _weekOffset--;
                    _selectedDate = _selectedDate.subtract(
                      const Duration(days: 7),
                    );
                  });
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final date = weekDays[index];
                final isToday = _isSameDay(date, now);
                final isSelected = _isSameDay(date, _selectedDate);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedDate = date);
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
                            : Border.all(
                                color: const Color(0xFFF0EDE6),
                                width: 1.2,
                              ),
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
                              color: isSelected
                                  ? Colors.white70
                                  : const Color(0xFF8E8E93),
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
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  "YOUR PLAN" BENTO GRID SECTION (Dynamic Selected Date)
  // ──────────────────────────────────────────────────────────────
  Widget _buildYourPlanSection(BuildContext context, Worker worker) {
    return StreamBuilder<List<Booking>>(
      stream: _bookingService.streamWorkerIncomingRequests(
        workerId: worker.id,
        skills: worker.skills,
        workerLat: worker.latitude,
        workerLng: worker.longitude,
        maxRadiusKm: worker.serviceRadiusKm,
      ),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        final hasRequest = requests.isNotEmpty;
        final topReq = hasRequest ? requests.first : null;

        // Voice Radar TTS: announce new incoming job when online
        if (hasRequest &&
            worker.availabilityStatus == AvailabilityStatus.online) {
          final top = requests.first;
          if (top.id != _lastAnnouncedRequestId) {
            _lastAnnouncedRequestId = top.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              KaryaTtsService.instance.announceNewJob(top);
            });
          }
        }

        final isToday = _isSameDay(_selectedDate, DateTime.now());
        final isTomorrow = _isSameDay(
          _selectedDate,
          DateTime.now().add(const Duration(days: 1)),
        );
        final isYesterday = _isSameDay(
          _selectedDate,
          DateTime.now().subtract(const Duration(days: 1)),
        );
        final isFuture = _selectedDate.isAfter(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        );

        final planDateLabel = isToday
            ? 'today_label'.trSafe("Today")
            : isTomorrow
            ? 'tomorrow_label'.trSafe("Tomorrow")
            : isYesterday
            ? 'yesterday_label'.trSafe("Yesterday")
            : DateFormat(
                'EEE, d MMM',
                context.locale.languageCode,
              ).format(_selectedDate);

        final planTag = isToday
            ? (hasRequest
                  ? 'priority_label'.trSafe("Priority")
                  : 'standby_label'.trSafe("Standby"))
            : isFuture
            ? 'scheduled_label'.trSafe("Scheduled")
            : 'shift_log_label'.trSafe("Shift Log");

        final planTitle = isToday
            ? (hasRequest
                  ? topReq!.serviceType.toLocalizedTrade()
                  : (worker.skills.isNotEmpty
                        ? "${worker.skills.first.toLocalizedTrade()} ${'shift_label'.trSafe('Shift')}"
                        : 'artisan_standby_label'.trSafe("Artisan Standby")))
            : isFuture
            ? (worker.skills.isNotEmpty
                  ? "${worker.skills.first.toLocalizedTrade()} ${'shift_label'.trSafe('Shift')}"
                  : 'planned_standby_label'.trSafe("Planned Standby"))
            : (worker.skills.isNotEmpty
                  ? "${worker.skills.first.toLocalizedTrade()} ${'completed_label'.trSafe('Completed')}"
                  : 'shift_logged_label'.trSafe("Shift Logged"));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'your_plan_header'.trSafe("Your plan · {}", [planDateLabel]),
                  style: GoogleFonts.plusJakartaSans(
                    color: KX.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                if (hasRequest && isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  planTag,
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
                                planTitle,
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
                                "${DateFormat('EEE, d MMM').format(_selectedDate)} · ${worker.workingHoursStart.to12HourTime()} - ${worker.workingHoursEnd.to12HourTime()}",
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF78350F),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),

                              // Location
                              Text(
                                worker.baseAddress?.formattedAddress ??
                                    worker.baseArea ??
                                    "Active Radius ~${worker.serviceRadiusKm.toInt()} km",
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
                                try {
                                  await _bookingService.acceptBooking(
                                    topReq!.id,
                                    worker.id,
                                    workerName: worker.name,
                                    workerPhone: worker.phoneForCalling,
                                  );
                                  if (context.mounted) {
                                    await JobPreparationToolsSheet.show(
                                      context,
                                      booking: topReq,
                                      worker: worker,
                                    );
                                    if (context.mounted &&
                                        ModalRoute.of(context)?.isCurrent ==
                                            true) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (ctx) => ActiveJobScreen(
                                            booking: topReq,
                                            worker: worker,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } on WorkerHasActiveJobException catch (e) {
                                  HapticFeedback.heavyImpact();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(
                                          0xFF141416,
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        content: Text(
                                          e.message,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        action: SnackBarAction(
                                          label: 'go_to_job'.trSafe(
                                            'Go to Job',
                                          ),
                                          textColor: const Color(0xFFFFDE59),
                                          onPressed: () async {
                                            final ongoing =
                                                await _bookingService
                                                    .getWorkerActiveJob(
                                                      worker.id,
                                                    );
                                            if (ongoing != null &&
                                                context.mounted) {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (ctx) =>
                                                      ActiveJobScreen(
                                                        booking: ongoing,
                                                        worker: worker,
                                                      ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                } on BookingAlreadyAcceptedException catch (e) {
                                  HapticFeedback.heavyImpact();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(
                                          0xFF141416,
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.flash_off_rounded,
                                              color: Color(0xFFFFDE59),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                e.message,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "${'error_prefix'.trSafe('Error')}: $e",
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: KX.dockBlack,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.flash_on_rounded,
                                      color: KX.gold,
                                      size: 14,
                                    ),
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
                                  child: const Icon(
                                    Icons.handyman_rounded,
                                    color: KX.gold,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'workgo_coop_label'.trSafe(
                                          "WorkGo Co-op",
                                        ),
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF1E1035),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        'ready_for_jobs_label'.trSafe(
                                          "Ready for jobs",
                                        ),
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
                        // Right Top: Radar / Dispatch Card (Reactive & Animated)
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
                                color: hasRequest
                                    ? const Color(0xFFEFF6FF)
                                    : KX.pastelSky,
                                borderRadius: BorderRadius.circular(24),
                                border: hasRequest
                                    ? Border.all(
                                        color: const Color(0xFF3B82F6),
                                        width: 1.5,
                                      )
                                    : null,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: hasRequest
                                              ? const Color(0xFFEF4444)
                                              : Colors.white.withValues(
                                                  alpha: 0.8,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          hasRequest
                                              ? "${requests.length} LIVE"
                                              : "Radar",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: hasRequest
                                                ? Colors.white
                                                : const Color(0xFF1D4ED8),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      RotationTransition(
                                        turns: _radarCtrl,
                                        child: Icon(
                                          Icons.radar_rounded,
                                          color: hasRequest
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF1D4ED8),
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    hasRequest
                                        ? topReq!.serviceType.toLocalizedTrade()
                                        : 'live_radar'.trSafe('Live Radar'),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF1E3A8A),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    hasRequest
                                        ? "₹${topReq!.amount.toStringAsFixed(0)} • ${(topReq.customerAddressText?.isNotEmpty == true ? topReq.customerAddressText!.toLocalizedAddress(context.locale.languageCode) : 'nearby_label'.trSafe('Nearby'))}"
                                        : (worker.availabilityStatus ==
                                                  AvailabilityStatus.online
                                              ? "${worker.serviceRadiusKm.toInt()} km ${'coverage_abbr'.trSafe('coverage')}\n${'listening_radar'.trSafe('Listening...')}"
                                              : "${'radar_standby'.trSafe('Radar Standby')}\n${'tap_to_go_live'.trSafe('Tap to go live')}"),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: hasRequest
                                          ? const Color(0xFF1D4ED8)
                                          : const Color(0xFF3B82F6),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Right Bottom: Quick Actions Row (Soft Pink with SOS Beacon)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: KX.pastelPink,
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
                                onTap: () =>
                                    setState(() => _currentNavIndex = 2),
                              ),
                              _quickActionIconCircle(
                                icon: Icons.sos_rounded,
                                color: const Color(0xFFDC2626),
                                onTap: () =>
                                    _showSosBeaconSheet(context, worker),
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
    } else if (stage == VerificationStage.selfieCapture ||
        stage == VerificationStage.onDeviceLiveness ||
        stage == VerificationStage.multiAngleLiveness) {
      stageText = "Step 3/4: Start 3D Multi-Angle Face Biometrics";
    } else if (stage == VerificationStage.pccUpload ||
        stage == VerificationStage.pccManualReview) {
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
              child: const Icon(
                Icons.shield_rounded,
                color: Color(0xFFD97706),
                size: 18,
              ),
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
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: KX.textPrimary,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  TACTICAL ACTION MATRIX (Operating Base Station + Referral Banner)
  // ──────────────────────────────────────────────────────────────
  Widget _buildTacticalActionGrid(BuildContext context, Worker worker) {
    final activeLocation =
        worker.baseAddress?.formattedAddress ??
        worker.baseArea ??
        (worker.preferredAreas.isNotEmpty
            ? worker.preferredAreas.first
            : "Erode Central, Tamil Nadu");

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
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: KX.gold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'operating_base_header'.trSafe(
                                  "OPERATING BASE",
                                ),
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFB45309),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'km_range_label'.trSafe(
                                    "${worker.serviceRadiusKm.toInt()} km Range",
                                    ["${worker.serviceRadiusKm.toInt()}"],
                                  ),
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
                    ...worker.skills
                        .take(3)
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F6EE),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFF0EDE6),
                              ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: KX.dockBlack,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_location_alt_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'btn_change'.trSafe("Change"),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
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
        const SizedBox(height: 12),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  ACTIVE MISSION COCKPIT CARD & START OTP ENTRY
  // ──────────────────────────────────────────────────────────────
  Widget _buildActiveMissionCockpitCard(
    BuildContext context,
    Booking booking,
    Worker worker,
  ) {
    final isAccepted = booking.status == BookingStatus.accepted;
    final isInProgress = booking.status == BookingStatus.inProgress;

    final tradeTitle = booking.serviceType.toLocalizedTrade();
    final address = (booking.customerAddressText?.isNotEmpty == true)
        ? booking.customerAddressText!.toLocalizedAddress(
            context.locale.languageCode,
          )
        : 'customer_doorstep_address'.trSafe('Customer Doorstep Address');

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => ActiveJobScreen(booking: booking, worker: worker),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isAccepted ? const Color(0xFF13111C) : const Color(0xFF091E16),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isAccepted
                ? const Color(0xFFF59E0B)
                : const Color(0xFF10B981),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isAccepted
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981))
                      .withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Status Badge + Live Timer or Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isAccepted
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981))
                            .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isAccepted
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAccepted
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAccepted
                            ? 'arrival_enter_otp_status'.trSafe(
                                "📍 ARRIVAL · ENTER OTP",
                              )
                            : 'service_in_progress_status'.trSafe(
                                "🟢 SERVICE IN PROGRESS",
                              ),
                        style: TextStyle(
                          color: isAccepted
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFFA7F3D0),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isInProgress)
                  _KaryaStopwatchBadge(startedAt: booking.startedAt)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "₹${booking.totalAmount.toStringAsFixed(0)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Trade Title
            Text(
              "${tradeTitle.toLocalizedTrade()} ${'mission_suffix'.trSafe('Mission')}",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),

            // Address + Direct Navigate Chip
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white60,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _launchMapsNavigation(
                    booking.customerAddressText,
                    booking.customerLatitude,
                    booking.customerLongitude,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.near_me_rounded,
                          color: Color(0xFFFBBF24),
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'hud_navigate'.tr(),
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if ((booking.equipmentTag?.isNotEmpty == true) ||
                (booking.customerIssueDetails?.isNotEmpty == true) ||
                booking.suggestedToolsNeeded.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.precision_manufacturing_rounded,
                      size: 13,
                      color: Color(0xFFFDE68A),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        booking.equipmentTag?.isNotEmpty == true
                            ? "${booking.equipmentTag} · ${booking.suggestedToolsNeeded.isNotEmpty ? '${booking.suggestedToolsNeeded.length} Tools Advised' : (booking.customerIssueDetails ?? booking.symptomDescription ?? 'Inspection Scheduled')}"
                            : (booking.customerIssueDetails ??
                                  booking.symptomDescription ??
                                  "Inspection Scheduled"),
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                if (isAccepted) ...[
                  Expanded(
                    flex: 5,
                    child: ElevatedButton(
                      onPressed: () => _showStartOtpDialogForBooking(
                        context,
                        booking,
                        worker,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.key_rounded,
                            size: 16,
                            color: Color(0xFF0F172A),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'enter_start_otp_btn'.trSafe("OTP மூலம் சரிபார்க்கவும்"),
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.1,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) =>
                                ActiveJobScreen(booking: booking, worker: worker),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.navigation_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        'view_hud_action'.trSafe("Details"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => ActiveJobScreen(
                              booking: booking,
                              worker: worker,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.camera_alt_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Complete Service & Seal C2PA",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStartOtpDialogForBooking(
    BuildContext context,
    Booking booking,
    Worker worker,
  ) {
    KaryaStartOtpSheet.show(
      context: context,
      bookingId: booking.id,
      onSuccess: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'otp_verified_started'.trSafe(
                  'OTP Verified! Service started successfully.',
                ),
              ),
              backgroundColor: const Color(0xFF047857),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (c) => ActiveJobScreen(
                booking: booking.copyWith(
                  status: BookingStatus.inProgress,
                  startedAt: DateTime.now(),
                ),
                worker: worker,
              ),
            ),
          );
        }
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  KARYA LIVE STOPWATCH BADGE (FOR IN-PROGRESS MISSIONS)
// ──────────────────────────────────────────────────────────────
class _KaryaStopwatchBadge extends StatefulWidget {
  const _KaryaStopwatchBadge({this.startedAt});
  final DateTime? startedAt;

  @override
  State<_KaryaStopwatchBadge> createState() => _KaryaStopwatchBadgeState();
}

class _KaryaStopwatchBadgeState extends State<_KaryaStopwatchBadge> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateElapsed(),
    );
  }

  void _updateElapsed() {
    final start = widget.startedAt ?? DateTime.now();
    final diff = DateTime.now().difference(start);
    if (mounted) {
      setState(() {
        _elapsed = diff.isNegative ? Duration.zero : diff;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _elapsed.inHours;
    final mins = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final formatted = hours > 0
        ? "${hours.toString().padLeft(2, '0')}:$mins:$secs"
        : "$mins:$secs";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF10B981), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_rounded, color: Color(0xFF34D399), size: 12),
          const SizedBox(width: 4),
          Text(
            formatted,
            style: const TextStyle(
              color: Color(0xFF34D399),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
