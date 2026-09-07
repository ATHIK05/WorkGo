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
import '../widgets/translated_text.dart';
import '../services/ml_translation_service.dart';

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
      KaryaTtsService.instance.setLanguage(context.locale.languageCode);
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
        pageTitle: 'tour_page_home_cockpit'.tr(),
        stepNumber: "1",
        title: 'tour_target_shift_title'.tr(),
        description: 'tour_target_shift_desc'.tr(),
        badgeText: 'tour_badge_availability'.tr(),
        icon: Icons.power_settings_new_rounded,
        bulletPoints: [
          'tour_bullet_shift_1'.tr(),
          'tour_bullet_shift_2'.tr(),
        ],
      ),
      SpotlightTarget(
        key: _keyFuelGauge,
        navIndex: 0,
        pageTitle: 'tour_page_home_cockpit'.tr(),
        stepNumber: "2",
        title: 'tour_target_fuel_title'.tr(),
        description: 'tour_target_fuel_desc'.tr(),
        badgeText: 'tour_badge_zero_commission'.tr(),
        icon: Icons.speed_rounded,
        bulletPoints: [
          'tour_bullet_fuel_1'.tr(),
          'tour_bullet_fuel_2'.tr(),
        ],
      ),
      SpotlightTarget(
        key: _keyRadar,
        navIndex: 0,
        pageTitle: 'tour_page_home_cockpit'.tr(),
        stepNumber: "3",
        title: 'tour_target_radar_title'.tr(),
        description: 'tour_target_radar_desc'.tr(),
        badgeText: 'tour_badge_priority_radar'.tr(),
        icon: Icons.radar_rounded,
        bulletPoints: [
          'tour_bullet_radar_1'.tr(),
          'tour_bullet_radar_2'.tr(),
        ],
      ),
      SpotlightTarget(
        key: _keyBentoGrid,
        navIndex: 0,
        pageTitle: 'tour_page_home_cockpit'.tr(),
        stepNumber: "4",
        title: 'tour_target_matrix_title'.tr(),
        description: 'tour_target_matrix_desc'.tr(),
        badgeText: 'tour_badge_action_matrix'.tr(),
        icon: Icons.grid_view_rounded,
        bulletPoints: [
          'tour_bullet_matrix_1'.tr(),
          'tour_bullet_matrix_2'.tr(),
        ],
      ),

      // ── PAGE 2: INCOMING REQUESTS & RADAR (navIndex: 1)
      SpotlightTarget(
        key: _keyRequestsHub,
        navIndex: 1,
        pageTitle: 'tour_page_requests_radar'.tr(),
        stepNumber: "5",
        title: 'tour_target_broadcast_title'.tr(),
        description: 'tour_radar_desc'.tr(),
        badgeText: 'tour_badge_job_alerts'.tr(),
        icon: Icons.cell_tower_rounded,
        bulletPoints: [
          'tour_bullet_broadcast_1'.tr(),
          'tour_bullet_broadcast_2'.tr(),
        ],
      ),

      // ── PAGE 3: EARNINGS & INSTANT PAYOUTS (navIndex: 2)
      SpotlightTarget(
        key: _keyEarningsHero,
        navIndex: 2,
        pageTitle: 'tour_page_earnings_ledger'.tr(),
        stepNumber: "6",
        title: 'tour_target_payouts_title'.tr(),
        description: 'tour_target_payouts_desc'.tr(),
        badgeText: 'tour_badge_zero_deductions'.tr(),
        icon: Icons.account_balance_wallet_rounded,
        bulletPoints: [
          'tour_bullet_payouts_1'.tr(),
          'tour_bullet_payouts_2'.tr(),
        ],
      ),

      // ── PAGE 4: WELFARE & INSURANCE SHIELD (navIndex: 3)
      SpotlightTarget(
        key: _keyWelfareShield,
        navIndex: 3,
        pageTitle: 'tour_page_welfare_insurance'.tr(),
        stepNumber: "7",
        title: 'tour_target_welfare_title'.tr(),
        description: 'tour_target_welfare_desc'.tr(),
        badgeText: 'tour_badge_safety_shield'.tr(),
        icon: Icons.health_and_safety_rounded,
        bulletPoints: [
          'tour_bullet_welfare_1'.tr(),
          'tour_bullet_welfare_2'.tr(),
        ],
      ),

      // ── PAGE 4: PROFILE & OPERATIONAL SETTINGS (navIndex: 3)
      SpotlightTarget(
        key: _keyProfileHub,
        navIndex: 3,
        pageTitle: 'tour_page_profile_hub'.tr(),
        stepNumber: "8",
        title: 'tour_target_bases_title'.tr(),
        description: 'tour_target_bases_desc'.tr(),
        badgeText: 'tour_badge_base_radius'.tr(),
        icon: Icons.location_on_rounded,
        bulletPoints: [
          'tour_bullet_bases_1'.tr(),
          'tour_bullet_bases_2'.tr(),
        ],
      ),
      SpotlightTarget(
        key: _keyProfileKyc,
        navIndex: 3,
        pageTitle: 'tour_page_profile_hub'.tr(),
        stepNumber: "9",
        title: 'tour_target_identity_title'.tr(),
        description: 'tour_target_identity_desc'.tr(),
        badgeText: 'tour_badge_kyc_vernacular'.tr(),
        icon: Icons.verified_user_rounded,
        bulletPoints: [
          'tour_bullet_identity_1'.tr(),
          'tour_bullet_identity_2'.tr(),
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
              content: Row(
                children: [
                  const Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'biometric_checkin_cancel'.tr(),
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
                content: Row(
                  children: [
                    const Icon(
                      Icons.face_retouching_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'face_checkin_cancel'.tr(),
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
              Text(
                'identity_verification_required'.tr(),
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
  //  SOS EMERGENCY BEACON SHEET
  // ──────────────────────────────────────────────────────────────
  void _showSosBeaconSheet(BuildContext context, Worker worker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
          decoration: BoxDecoration(
            color: KX.canvasCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
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
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEF4444),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.sos_rounded,
                    color: Color(0xFFEF4444),
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'sos_beacon_title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: KX.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Broadcast your live GPS coordinates to cooperative admins and active artisans within 5 km for immediate assistance.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KX.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.heavyImpact();
                  try {
                    await FirebaseFirestore.instance
                        .collection('emergency_beacons')
                        .add({
                          'workerId': worker.id,
                          'workerName': widget.user.displayName.trim().isNotEmpty
                              ? widget.user.displayName.trim()
                              : (worker.name.trim().isNotEmpty ? worker.name.trim() : 'Artisan'),
                          'workerPhone': (widget.user.phoneNumber != null && widget.user.phoneNumber!.trim().isNotEmpty)
                              ? widget.user.phoneNumber!.trim()
                              : (worker.phoneForCalling ?? ''),
                          'createdAt': FieldValue.serverTimestamp(),
                          'status': 'active',
                          'latitude': worker.latitude,
                          'longitude': worker.longitude,
                          'address': worker.baseArea,
                        });
                  } catch (_) {}
                  KaryaTtsService.instance.announce(
                    'Emergency alert sent. Help is notified.',
                  );
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.emergency_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'sos_beacon_sent'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFFDC2626),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: Text(
                  'sos_beacon_confirm'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                child: Text(
                  'sos_beacon_cancelled'.tr(),
                  style: const TextStyle(color: KX.textSecondary),
                ),
              ),
            ],
          ),
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

        // Voice announce peer SOS if online and not yet announced
        if (worker.availabilityStatus == AvailabilityStatus.online &&
            topDoc.id != _lastAnnouncedPeerSosId) {
          _lastAnnouncedPeerSosId = topDoc.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            KaryaTtsService.instance.announcePeerSos(peerName);
          });
        }

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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF6B7280)),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  if (peerPhone != null && peerPhone.isNotEmpty) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await PhoneDialer.call(peerPhone, context: context);
                        },
                        icon: const Icon(Icons.phone_rounded, size: 14),
                        label: Text(
                          'sos_call_peer'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Uri? uri;
                        if (lat != null && lng != null) {
                          uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
                        } else if (address.isNotEmpty) {
                          uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
                        }
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.near_me_rounded, size: 14),
                      label: Text(
                        'sos_nav_peer'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF991B1B),
                        side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                            StreamBuilder<List<Booking>>(
                              stream: _bookingService
                                  .streamWorkerIncomingRequests(
                                    workerId: worker.id,
                                    skills: worker.skills,
                                  ),
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

            // ── 1.5 Peer Artisan SOS Distress Beacon Alert (Live Stream)
            _buildPeerSosBeaconAlerts(context, worker),

            // ── 2. Verification Alert Banner (if unverified)
            if (worker.verificationStatus != VerificationStatus.approved) ...[
              KSlideFadeIn(
                delay: const Duration(milliseconds: 20),
                child: _buildVerificationAlertBanner(context, worker),
              ),
              const SizedBox(height: 14),
            ],

            // ── 2.5 Live Active Mission Card (If artisan has an accepted or in-progress booking)
            StreamBuilder<Booking?>(
              stream: _bookingService.streamCurrentActiveJob(worker.id),
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
            ),

            // ── 2.6 Incoming Specialist Co-op Relay Alert (Mutual Acknowledgment)
            StreamBuilder<List<Booking>>(
              stream: _bookingService.streamWorkerHandoffRequests(worker.id),
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
    final dateStr = "${'today'.tr()}, ${DateFormat('d MMM', context.locale.languageCode).format(now)}";

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
              Text(
                'greeting_hello'.tr(args: [name.isNotEmpty ? name.split(' ').first : 'Artisan']),
                style: GoogleFonts.plusJakartaSans(
                  color: KX.textPrimary,
                  fontSize: 16.5,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
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
                    isOnline ? 'online'.tr() : 'offline'.tr(),
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
        await KaryaTtsService.instance.setLanguage(code);
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
          child: Text(
            '🇬🇧 English',
            style: TextStyle(
              color: KX.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'hi',
          child: Text(
            '🇮🇳 हिन्दी (Hindi)',
            style: TextStyle(
              color: KX.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'ta',
          child: Text(
            '🇮🇳 தமிழ் (Tamil)',
            style: TextStyle(
              color: KX.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
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
            ? 'daily_challenge'.tr()
            : isYesterday
            ? 'yesterdays_earnings'.tr()
            : isTomorrow
            ? 'tomorrows_target'.tr()
            : isFuture
            ? "${'forecast_label'.tr()} · ${DateFormat('EEE, d MMM').format(_selectedDate)}"
            : "${'earnings_label'.tr()} · ${DateFormat('EEE, d MMM').format(_selectedDate)}";

        final cardSubtitle = isToday
            ? 'payout_target_today'.tr()
            : isFuture
            ? "Target: ₹2,000 · ${'planned_shift'.tr()}"
            : "Target: ₹2,000 · ${'shift_log'.tr()}";

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
                            "${(goalProgress * 100).toInt()}% ${isFuture ? 'target_label'.tr() : 'done_label'.tr()}",
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
    final lang = context.locale.languageCode;
    final List<String> dayNames;
    if (lang == 'ta') {
      dayNames = ["ஞா", "தி", "செ", "பு", "வி", "வெ", "ச"];
    } else if (lang == 'hi') {
      dayNames = ["रवि", "सोम", "मंगल", "बुध", "गुरु", "शुक्र", "शनि"];
    } else {
      dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    }

    final monthNumber = weekDays[3].month;
    final year = weekDays[3].year;
    final String monthLabel;
    if (lang == 'ta') {
      const tamilMonths = [
        "ஜனவரி", "பிப்ரவரி", "மார்ச்", "ஏப்ரல்", "மே", "ஜூன்",
        "ஜூலை", "ஆகஸ்ட்", "செப்டம்பர்", "அக்டோபர்", "நவம்பர்", "டிசம்பர்"
      ];
      monthLabel = "${tamilMonths[monthNumber - 1]} $year";
    } else if (lang == 'hi') {
      const hindiMonths = [
        "जनवरी", "फ़रवरी", "मार्च", "अप्रैल", "मई", "जून",
        "जुलाई", "अगस्त", "सितंबर", "अक्टूबर", "नवंबर", "दिसंबर"
      ];
      monthLabel = "${hindiMonths[monthNumber - 1]} $year";
    } else {
      monthLabel = DateFormat('MMMM yyyy').format(weekDays[3]);
    }

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
                              SizedBox(width: 4),
                              Text(
                                'btn_today'.tr(),
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
            ? 'btn_today'.tr()
            : isTomorrow
            ? 'tomorrow'.tr()
            : isYesterday
            ? 'yesterday'.tr()
            : _selectedDate.toLocalizedDate(context.locale.languageCode);

        final planTag = isToday
            ? (hasRequest ? 'plan_priority'.tr() : 'plan_standby'.tr())
            : isFuture
            ? 'plan_scheduled'.tr()
            : 'plan_shift_log'.tr();

        final planTitle = isToday
            ? (hasRequest
                  ? topReq!.serviceType.toLocalizedTradeClean()
                  : (worker.skills.isNotEmpty
                        ? "${worker.skills.first.toLocalizedTradeClean()} ${'shift_suffix'.tr()}"
                        : 'artisan_standby'.tr()))
            : isFuture
            ? (worker.skills.isNotEmpty
                  ? "${worker.skills.first.toLocalizedTradeClean()} ${'shift_suffix'.tr()}"
                  : 'plan_scheduled'.tr())
            : (worker.skills.isNotEmpty
                  ? "${worker.skills.first.toLocalizedTradeClean()} ${'done_label'.tr()}"
                  : 'plan_shift_log'.tr());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${ 'your_plan'.tr() } · $planDateLabel",
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
                                "${_selectedDate.toLocalizedDate(context.locale.languageCode)} · ${worker.workingHoursStart.to12HourTime()} - ${worker.workingHoursEnd.to12HourTime()}",
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
                                await _bookingService.acceptBooking(
                                  topReq!.id,
                                  worker.id,
                                  workerName: worker.name,
                                  workerPhone: worker.phoneForCalling,
                                );
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: KX.dockBlack,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.flash_on_rounded,
                                      color: KX.gold,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'accept_job'.tr(),
                                      style: const TextStyle(
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
                                        "WorkGo Co-op",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF1E1035),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        'ready_for_jobs'.tr(),
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
                                              : 'radar_tag'.trSafe('Radar'),
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
                                        : 'live_radar'.tr(),
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
                                        ? "₹${topReq!.amount.toStringAsFixed(0)} • ${(topReq.customerAddressText?.isNotEmpty == true ? MlTranslationService.instance.translateSync(topReq.customerAddressText!, context.locale.languageCode, isAddress: true) : 'nearby_label'.tr())}"
                                        : (worker.availabilityStatus ==
                                                  AvailabilityStatus.online
                                              ? 'radar_coverage_listening'.tr(args: [worker.serviceRadiusKm.toInt().toString()])
                                              : 'radar_standby_tap'.tr()),
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
    String stageText = 'start_aadhaar_face'.tr();
    if (stage == VerificationStage.consent) {
      stageText = 'step_1_of_4'.tr();
    } else if (stage == VerificationStage.aadhaarOfflineEkyc) {
      stageText = 'step_2_of_4'.tr();
    } else if (stage == VerificationStage.selfieCapture ||
        stage == VerificationStage.onDeviceLiveness ||
        stage == VerificationStage.multiAngleLiveness) {
      stageText = 'step_3_of_4'.tr();
    } else if (stage == VerificationStage.pccUpload ||
        stage == VerificationStage.pccManualReview) {
      stageText = 'step_4_of_4'.tr();
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
                    'identity_verification_required'.tr(),
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
                                'operating_base'.tr(),
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
                                  'active_range_km'.tr(args: ['${worker.serviceRadiusKm.toInt()}']),
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
                              s.toLocalizedTradeClean(),
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
                            'btn_change'.tr(),
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

        // ── Peer Referral Banner
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            showPeerReferralNetworkSheet(context, worker: worker);
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
                  child: const Icon(
                    Icons.groups_rounded,
                    color: KX.gold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'refer_artisan_title'.tr(),
                              style: GoogleFonts.plusJakartaSans(
                                color: KX.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
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
                        'refer_artisan_desc'.tr(),
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
    final address = booking.customerAddressText ?? "Customer Doorstep Address";

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
                        isAccepted ? 'arrival_enter_otp'.tr() : 'service_in_progress'.tr(),
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
              "$tradeTitle ${ 'shift_suffix'.tr() }",
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
                  child: TranslatedText(
                    address,
                    isAddress: true,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.key_rounded,
                            size: 16,
                            color: Color(0xFF0F172A),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'enter_otp'.tr(),
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      onPressed: () => _launchMapsNavigation(
                        booking.customerAddressText,
                        booking.customerLatitude,
                        booking.customerLongitude,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            size: 15,
                            color: Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'hud_navigate'.tr(),
                                style: const TextStyle(
                                  color: Color(0xFFFBBF24),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              ActiveJobScreen(booking: booking, worker: worker),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.navigation_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "HUD",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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
                      label: Text(
                        'complete_service_c2pa'.tr(),
                        style: const TextStyle(
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
              content: Text('service_started_success'.tr()),
              backgroundColor: Color(0xFF047857),
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
