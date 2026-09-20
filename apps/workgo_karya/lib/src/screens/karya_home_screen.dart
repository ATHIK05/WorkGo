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
import '../widgets/karya_speedometer_gauge.dart';
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

  // Real-time customizable Daily Payout Goal (Persisted in SharedPreferences)
  double _dailyTarget = 2000.0;
  String? _loadedTargetWorkerId;

  Future<void> _loadDailyTarget(String workerId) async {
    if (_loadedTargetWorkerId == workerId) return;
    _loadedTargetWorkerId = workerId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble('karya_daily_target_$workerId');
      if (saved != null && saved > 0 && mounted) {
        setState(() {
          _dailyTarget = saved;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateDailyTarget(String workerId, double newTarget) async {
    setState(() {
      _dailyTarget = newTarget;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('karya_daily_target_$workerId', newTarget);
    } catch (_) {}
  }

  void _showSetDailyTargetDialog(BuildContext context, Worker worker) {
    final quickOptions = [1000.0, 1500.0, 2000.0, 2500.0, 3000.0, 5000.0];
    final customCtrl = TextEditingController(
      text: _dailyTarget.toInt().toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF8F5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4CEBA),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1035),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.speed_rounded,
                          color: Color(0xFF34D399),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'set_daily_goal_title'.trSafe(
                                'Set Daily Payout Goal',
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF1E1035),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'set_daily_goal_sub'.trSafe(
                                'Speedometer & target recalibrate in real time',
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF706757),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'quick_select_target'.trSafe('Quick Target Goals (₹)'),
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF1E1035),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: quickOptions.map((opt) {
                      final isSelected = (_dailyTarget - opt).abs() < 1.0;
                      return InkWell(
                        onTap: () {
                          setSheetState(() {
                            customCtrl.text = opt.toInt().toString();
                          });
                          _updateDailyTarget(worker.id, opt);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF1E1035),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF34D399),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Daily target set to ₹${opt.toInt()}!",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E1035)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1E1035)
                                  : const Color(0xFFE5DECE),
                              width: 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF1E1035,
                                      ).withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            "₹${opt.toInt()}",
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1E1035),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'or_custom_amount'.trSafe('Or Custom Goal (₹)'),
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF1E1035),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD4CEBA)),
                          ),
                          child: TextField(
                            controller: customCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E1035),
                            ),
                            decoration: const InputDecoration(
                              prefixText: '₹ ',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          final val = double.tryParse(customCtrl.text.trim());
                          if (val != null && val >= 100) {
                            _updateDailyTarget(worker.id, val);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF1E1035),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF34D399),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Daily target set to ₹${val.toInt()}!",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1035),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'save_btn'.trSafe('Save'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
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
          'Quick access to government Aadhaar & Video KYC, ₹2L welfare cover, and Dial Karya Voice Gateway & Peer KYC.',
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

      // Mandatory Payment Mode Check before going live (UPI or Cash on Delivery)
      if (!worker.canAcceptPayments) {
        HapticFeedback.heavyImpact();
        final success = await _showUpiRequiredModal(context, worker);
        if (success != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'payment_method_required_snack'.trSafe(
                    'Please configure a UPI code or enable Cash on Delivery before going live.',
                  ),
                ),
                backgroundColor: const Color(0xFFDC2626),
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

  void _openDialKaryaHub(BuildContext context, Worker worker) {
    showDialKaryaGatewaySheet(
      context,
      worker: worker,
      onInitiatePeerKyc: (dialWorker) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReferDialMemberScreen(
              mitraWorker: worker,
              dialWorkerId: dialWorker['id'] ?? '',
              dialWorkerName: dialWorker['name'] ?? 'Dial Worker',
              dialWorkerPhone: dialWorker['phone'] ?? '',
              dialWorkerTrade: dialWorker['trade'] ?? 'General',
              dialWorkerLocation: [
                dialWorker['locationText'] ?? '',
                if ((dialWorker['pincode'] ?? '').toString().isNotEmpty)
                  dialWorker['pincode'],
              ].where((s) => s.toString().isNotEmpty).join(' • '),
              dialWorkerTradeDescription: dialWorker['tradeDescription'],
              backendBaseUrl: 'https://workgo-api.onrender.com',
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showUpiRequiredModal(
    BuildContext context,
    Worker worker,
  ) async {
    final upiCtrl = TextEditingController(text: worker.upiId ?? "");
    String? errorText;
    bool isSaving = false;
    bool acceptsCash = worker.acceptsCash;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
            decoration: const BoxDecoration(
              color: KX.canvasCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: KX.borderMuted,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFD97706,
                          ).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(0xFFD97706),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'payment_setup_title'.trSafe(
                                "Choose How You Get Paid",
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: KX.textPrimary,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'payment_setup_sub'.trSafe(
                                "100% Direct P2P Earnings · Zero Commission",
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: KX.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFB45309),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'upi_setup_explanation'.trSafe(
                              "WorkGo operates on a 100% direct payment model. Customers pay you directly via PhonePe, Google Pay, or Cash on Delivery with zero platform fees.",
                            ),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF92400E),
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: upiCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.plusJakartaSans(
                      color: KX.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelText: 'enter_upi_id_label'.trSafe(
                        "UPI ID (Google Pay, PhonePe, Paytm)",
                      ),
                      hintText: "e.g. yourname@okhdfcbank or 9876543210@ybl",
                      errorText: errorText,
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(
                        Icons.alternate_email_rounded,
                        color: KX.gold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: KX.borderMuted),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: KX.gold,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        [
                          "@okaxis",
                          "@okhdfcbank",
                          "@ybl",
                          "@paytm",
                          "@upi",
                        ].map((handle) {
                          return InkWell(
                            onTap: () {
                              final current = upiCtrl.text.split('@').first;
                              if (current.isNotEmpty) {
                                upiCtrl.text = "$current$handle";
                              } else {
                                upiCtrl.text = handle;
                              }
                              upiCtrl.selection = TextSelection.fromPosition(
                                TextPosition(offset: upiCtrl.text.length),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                handle,
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF475569),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // ── OR Divider ─────────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'or_divider'.trSafe("OR"),
                          style: GoogleFonts.plusJakartaSans(
                            color: KX.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Cash on Delivery Option Toggle ─────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: acceptsCash
                          ? const Color(0xFFECFDF5)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: acceptsCash
                            ? const Color(0xFF10B981)
                            : KX.borderMuted,
                        width: acceptsCash ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: acceptsCash
                                ? const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.payments_rounded,
                            color: acceptsCash
                                ? const Color(0xFF059669)
                                : Colors.grey,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'accept_cod_title'.trSafe(
                                  "Accept Cash on Delivery",
                                ),
                                style: GoogleFonts.plusJakartaSans(
                                  color: KX.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'accept_cod_sub'.trSafe(
                                  "Customers can hand over physical cash directly upon completion",
                                ),
                                style: GoogleFonts.plusJakartaSans(
                                  color: KX.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: acceptsCash,
                          activeTrackColor: const Color(0xFF10B981),
                          onChanged: (val) {
                            setModalState(() {
                              acceptsCash = val;
                              errorText = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(null),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                          child: Text(
                            'cancel'.trSafe("Cancel"),
                            style: GoogleFonts.plusJakartaSans(
                              color: KX.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final text = upiCtrl.text.trim();
                                  final hasUpi =
                                      text.contains('@') && text.length >= 5;
                                  if (!hasUpi && !acceptsCash) {
                                    setModalState(() {
                                      errorText = 'select_payment_mode_error'
                                          .trSafe(
                                            'Please enter a valid UPI ID or enable Cash on Delivery',
                                          );
                                    });
                                    return;
                                  }
                                  setModalState(() => isSaving = true);
                                  try {
                                    await _workerService
                                        .updateWorkerPaymentPreferences(
                                          workerId: worker.id,
                                          upiId: hasUpi
                                              ? text
                                              : (worker.upiId ?? ""),
                                          acceptsCash: acceptsCash,
                                        );
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop(true);
                                    }
                                  } catch (e) {
                                    setModalState(() {
                                      isSaving = false;
                                      errorText = "Failed to save: $e";
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'save_payment_pref_btn'.trSafe(
                                    "Save & Go Live",
                                  ),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
        final dialWorkerDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isVerified =
              data['verificationStatus'] == 'approved' ||
              data['verificationStage'] == 'approved';
          return !isVerified;
        }).toList();

        if (dialWorkerDocs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: dialWorkerDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] as String? ?? 'Dial Worker';
            final trade =
                (data['skills'] as List?)?.firstOrNull?.toString() ?? 'General';
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
                      dialWorkerLocation:
                          (data['locationText'] as String?)?.isNotEmpty == true
                          ? (data['locationText'] as String)
                          : areas,
                      dialWorkerTradeDescription:
                          data['tradeDescription'] as String?,
                      backendBaseUrl: const String.fromEnvironment(
                        'BACKEND_BASE_URL',
                        defaultValue: 'https://workgo-api.onrender.com',
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
                  border: Border.all(
                    color: KX.brandAmber.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
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
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: Colors.white,
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
                              Expanded(
                                child: Text(
                                  'peer_kyc_alert_title'.trSafe(
                                    '⚡ Earn ₹150 — Verify $name',
                                    [name],
                                  ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
    final activeLocation =
        worker.baseAddress?.formattedAddress ??
        worker.baseArea ??
        (worker.preferredAreas.isNotEmpty
            ? worker.preferredAreas.first
            : 'erode_central_tamil_nadu'.trSafe("Erode Central, Tamil Nadu"));

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
                  radius: 19,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),

        // Greeting & Operating Base Address (Tappable - replaces Today date)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'greeting_hello'.trSafe('Hello, {}', [name]),
                style: GoogleFonts.plusJakartaSans(
                  color: KX.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  showAddressManagementSheet(
                    context,
                    userId: widget.user.uid,
                    userRole: "worker",
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: KX.gold,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        activeLocation.toLocalizedAddress(
                          context.locale.languageCode,
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          color: KX.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: KX.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Compact Language Switcher
        _buildCompactLangPill(context),
        const SizedBox(width: 6),

        // Titan Shift / Online Toggle Pill Button
        KeyedSubtree(
          key: _keyAvailabilitySwitch,
          child: GestureDetector(
            onTap: () => _toggleAvailability(worker),
            child: AnimatedContainer(
              duration: KAnim.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
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
                  const SizedBox(width: 5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 68),
                    child: Text(
                      isOnline
                          ? 'online_ready'.trSafe("Online")
                          : 'offline_status'.trSafe("Offline"),
                      style: GoogleFonts.plusJakartaSans(
                        color: isOnline ? Colors.white : KX.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            children: [
              Expanded(
                child: Text(
                  '${lang.nativeName} (${lang.englishName})',
                  style: TextStyle(
                    color: isSelected ? KX.violet : KX.textPrimary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_rounded, color: KX.violet, size: 16),
              ],
            ],
          ),
        );
      }).toList(),

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
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
              size: 13,
            ),
            const SizedBox(width: 3),
            Text(
              currentCode.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: KX.textPrimary,
                fontSize: 10,
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
    if (_loadedTargetWorkerId != worker.id) {
      _loadDailyTarget(worker.id);
    }

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

        final dailyGoal = _dailyTarget;
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
            : 'earnings_date_title'.trSafe("Earnings · {}", [
                DateFormat(
                  'EEE, d MMM',
                  context.locale.languageCode,
                ).format(_selectedDate),
              ]);

        final cardSubtitle = isToday
            ? 'payout_target_today'.trSafe("Payout target: ₹{} today", [
                dailyGoal.toInt().toString(),
              ])
            : isFuture
            ? 'target_planned_shift'.trSafe("Target: ₹{} · Planned shift", [
                dailyGoal.toInt().toString(),
              ])
            : 'target_shift_log'.trSafe("Target: ₹{} · Shift log", [
                dailyGoal.toInt().toString(),
              ]);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEDE8FF), Color(0xFFDFD4FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x147C3AED),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth;
                final isCompact = cardWidth < 370;
                final gaugeWidth = isCompact ? 76.0 : 88.0;
                final gaugeHeight = isCompact ? 50.0 : 58.0;
                final workerHeight = isCompact ? 136.0 : 158.0;
                final workerRight = isCompact ? -10.0 : -6.0;
                final gaugeRight = isCompact ? 116.0 : 136.0;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Ambient Background Pastel Shapes
                    Positioned(
                      bottom: -22,
                      left: -22,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFC4B5FD).withValues(alpha: 0.55),
                              const Color(0xFFC4B5FD).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 42,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF6EE7B7).withValues(alpha: 0.35),
                              const Color(0xFF6EE7B7).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. Top-Center Emerald Accent Dot
                    Positioned(
                      top: 24,
                      left: cardWidth * 0.52,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    // 3. Top-Right Mint Sparkle Star (✦)
                    const Positioned(
                      top: 20,
                      right: 28,
                      child: Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF34D399),
                        size: 26,
                      ),
                    ),

                    // 4. Dynamic Action Speed Streaks behind gauge
                    Positioned(
                      right: gaugeRight + 2,
                      bottom: 52,
                      child: const KaryaSpeedLines(
                        width: 40,
                        height: 32,
                        color: Color(0x351E1035),
                      ),
                    ),

                    // 5. Speedometer Gauge (Real-Time Animated Needle)
                    Positioned(
                      right: gaugeRight,
                      bottom: 16,
                      child: KaryaSpeedometerGauge(
                        progress: goalProgress,
                        width: gaugeWidth,
                        height: gaugeHeight,
                        minLabel: '0',
                      ),
                    ),

                    // 6. Worker Mascot Illustration
                    Positioned(
                      right: workerRight,
                      bottom: 0,
                      child: Image.asset(
                        'assets/images/karya_daily_worker.png',
                        height: workerHeight,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (ctx, _, __) => const SizedBox.shrink(),
                      ),
                    ),

                    // 7. Left Content Column (Title, Target Subtitle, Live Earnings & %)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        20,
                        gaugeRight + (gaugeWidth * 0.42),
                        20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cardTitle,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF1E1035),
                              fontSize: isCompact ? 19 : 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          InkWell(
                            onTap: isToday
                                ? () =>
                                      _showSetDailyTargetDialog(context, worker)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      cardSubtitle,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF5B4D7A),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isToday) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.edit_rounded,
                                      size: 12,
                                      color: Color(0xFF5B4D7A),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Text(
                                "₹${selectedDayEarnings.toInt()}",
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF1E1035),
                                  fontSize: isCompact ? 24 : 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.0,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1035),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  "${(goalProgress * 100).toInt()}% ${isFuture ? 'goal_target_label'.trSafe('Target') : 'goal_done_label'.trSafe('Target')}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                        "₹${(selectedDayEarnings / (DateTime.now().hour - 8).clamp(1, 10)).round()}/hr ${'earnings_velocity_label'.trSafe('pace')}",
                                        style: const TextStyle(
                                          color: Color(0xFF047857),
                                          fontSize: 10,
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
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
  //  TRADE CHIP BUILDER (Vibrant, tailored color micro-pills)
  // ──────────────────────────────────────────────────────────────
  Widget _buildTradeChip(String skill) {
    final lower = skill.toLowerCase();
    IconData icon = Icons.handyman_rounded;
    Color bg = const Color(0xFFF3EEDD);
    Color textCol = const Color(0xFF78350F);
    Color borderCol = const Color(0xFFE5DECE);

    if (lower.contains('plumb') || lower.contains('tap') || lower.contains('pipe')) {
      icon = Icons.plumbing_rounded;
      bg = const Color(0xFFEFF6FF);
      textCol = const Color(0xFF1D4ED8);
      borderCol = const Color(0xFFBFDBFE);
    } else if (lower.contains('electr') || lower.contains('wire') || lower.contains('power')) {
      icon = Icons.electric_bolt_rounded;
      bg = const Color(0xFFFEF3C7);
      textCol = const Color(0xFFB45309);
      borderCol = const Color(0xFFFDE68A);
    } else if (lower.contains('carpent') || lower.contains('wood') || lower.contains('furniture')) {
      icon = Icons.carpenter_rounded;
      bg = const Color(0xFFFFF7ED);
      textCol = const Color(0xFFC2410C);
      borderCol = const Color(0xFFFFEDD5);
    } else if (lower.contains('paint')) {
      icon = Icons.format_paint_rounded;
      bg = const Color(0xFFFDF2F8);
      textCol = const Color(0xFFBE185D);
      borderCol = const Color(0xFFFBCFE8);
    } else if (lower.contains('appliance') ||
        lower.contains('ac') ||
        lower.contains('repair') ||
        lower.contains('cool') ||
        lower.contains('refriger')) {
      icon = Icons.home_repair_service_rounded;
      bg = const Color(0xFFECFDF5);
      textCol = const Color(0xFF047857);
      borderCol = const Color(0xFFA7F3D0);
    } else if (lower.contains('clean')) {
      icon = Icons.cleaning_services_rounded;
      bg = const Color(0xFFF0FDFA);
      textCol = const Color(0xFF0F766E);
      borderCol = const Color(0xFF99F6E4);
    } else if (lower.contains('mason') || lower.contains('tile') || lower.contains('civil')) {
      icon = Icons.foundation_rounded;
      bg = const Color(0xFFF8FAFC);
      textCol = const Color(0xFF475569);
      borderCol = const Color(0xFFE2E8F0);
    } else if (lower.contains('garden')) {
      icon = Icons.yard_rounded;
      bg = const Color(0xFFF0FDF4);
      textCol = const Color(0xFF15803D);
      borderCol = const Color(0xFFBBF7D0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol, width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: textCol),
          const SizedBox(width: 4.5),
          Text(
            skill.toLocalizedTrade(),
            style: GoogleFonts.plusJakartaSans(
              color: textCol,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  "YOUR PLAN" UNIFIED HERO COCKPIT (Dynamic Selected Date)
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

        final hasMultiSkills = worker.skills.length > 1;
        final skillCount = worker.skills.length;

        final planTag = hasRequest
            ? 'priority_label'.trSafe("Priority")
            : (hasMultiSkills
                  ? "$skillCount TRADES READY"
                  : (isToday
                        ? 'standby_label'.trSafe("Standby")
                        : (isFuture
                              ? 'scheduled_label'.trSafe("Scheduled")
                              : 'shift_log_label'.trSafe("Shift Log"))));

        final planTitle = isToday
            ? (hasRequest
                  ? topReq!.serviceType.toLocalizedTrade()
                  : (hasMultiSkills
                        ? 'multi_trade_artisan_shift'.trSafe(
                            "Multi-Trade Shift",
                          )
                        : (worker.skills.isNotEmpty
                              ? "${worker.skills.first.toLocalizedTrade()} ${'shift_label'.trSafe('Shift')}"
                              : 'artisan_standby_label'.trSafe(
                                  "Artisan Standby",
                                ))))
            : isFuture
            ? (hasMultiSkills
                  ? 'planned_multi_shift'.trSafe("Planned Multi-Trade Shift")
                  : (worker.skills.isNotEmpty
                        ? "${worker.skills.first.toLocalizedTrade()} ${'shift_label'.trSafe('Shift')}"
                        : 'planned_standby_label'.trSafe("Planned Standby")))
            : (hasMultiSkills
                  ? 'multi_trade_completed'.trSafe("Multi-Trade Shift Completed")
                  : (worker.skills.isNotEmpty
                        ? "${worker.skills.first.toLocalizedTrade()} ${'completed_label'.trSafe('Completed')}"
                        : 'shift_logged_label'.trSafe("Shift Logged")));

        final planSubtitle = hasRequest
            ? 'incoming_request_sub'.trSafe("Doorstep dispatch required")
            : (hasMultiSkills
                  ? "$skillCount specializations active for direct booking"
                  : 'ready_for_dispatch'.trSafe(
                      "Ready for doorstep customer bookings",
                    ));

        final isOnline = worker.availabilityStatus == AvailabilityStatus.online;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'your_plan_header'.trSafe("Your plan · {}", [
                      planDateLabel,
                    ]),
                    style: GoogleFonts.plusJakartaSans(
                      color: KX.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

            // ── UNIFIED HERO COCKPIT CARD (Rich White & Yellowish Overlay + Mascot + Multi-Trade Active) ──
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFDF8),
                    Color(0xFFFEF9EB),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: hasRequest
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFF3E7C4),
                  width: hasRequest ? 2.0 : 1.4,
                ),
                boxShadow: [
                  if (hasRequest)
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.22),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                    )
                  else ...[
                    const BoxShadow(
                      color: Color(0x1DF59E0B),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                      spreadRadius: -2,
                    ),
                    const BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ],
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upper Hero Stage: Left details + Right Artisan Mascot + Rich Overlay
                    Stack(
                      children: [
                        // Ambient radial golden halo behind artisan mascot
                        Positioned(
                          right: -15,
                          top: -15,
                          child: Container(
                            width: 190,
                            height: 190,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  hasRequest
                                      ? const Color(0x28EF4444)
                                      : const Color(0x38FFDE59),
                                  const Color(0x18FFF3B0),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Artisan Mascot Illustration (From user attachment)
                        Positioned(
                          right: 4,
                          top: 6,
                          bottom: 0,
                          child: Image.asset(
                            'assets/images/karya_plan_artisan_transparent.png',
                            height: 168,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (ctx, _, __) =>
                                const SizedBox.shrink(),
                          ),
                        ),

                        // Rich White and Yellowish Specular Overlay (Enhances contrast & luxury feel)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  stops: const [0.0, 0.42, 0.72, 1.0],
                                  colors: [
                                    Colors.white.withValues(alpha: 0.94),
                                    const Color(0xFFFFFDF8).withValues(alpha: 0.75),
                                    const Color(0xFFFEF3C7).withValues(alpha: 0.22),
                                    const Color(0xFFFFDE59).withValues(alpha: 0.12),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Left Content Column (Protected from mascot overlap)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 125, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Tag & Radar mini indicator
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hasRequest
                                          ? const Color(0xFFFEE2E2)
                                          : (isOnline
                                                ? const Color(0xFFDCFCE7)
                                                : const Color(0xFFF3EEDD)),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: hasRequest
                                            ? const Color(0xFFFECACA)
                                            : (isOnline
                                                  ? const Color(0xFFBBF7D0)
                                                  : const Color(0xFFE5DECE)),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: hasRequest
                                                ? const Color(0xFFDC2626)
                                                : (isOnline
                                                      ? const Color(0xFF16A34A)
                                                      : const Color(0xFF854D0E)),
                                          ),
                                        ),
                                        const SizedBox(width: 4.5),
                                        Text(
                                          planTag,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: hasRequest
                                                ? const Color(0xFFDC2626)
                                                : (isOnline
                                                      ? const Color(0xFF15803D)
                                                      : const Color(0xFF854D0E)),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Rotating mini radar icon
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _currentNavIndex = 1);
                                    },
                                    child: RotationTransition(
                                      turns: _radarCtrl,
                                      child: Icon(
                                        Icons.radar_rounded,
                                        color: hasRequest
                                            ? const Color(0xFFEF4444)
                                            : (isOnline
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF9CA3AF)),
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Main Title
                              Text(
                                planTitle,
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF1E1035),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                  letterSpacing: -0.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),

                              // Subtitle
                              Text(
                                planSubtitle,
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF78716C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),

                              // Shift Schedule Timing Capsule (Warm Amber/Gold Accent)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 12,
                                      color: Color(0xFFB45309),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        "${DateFormat('EEE, d MMM').format(_selectedDate)} · ${worker.workingHoursStart.to12HourTime()} - ${worker.workingHoursEnd.to12HourTime()}",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF292524),
                                          fontSize: 10.5,
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
                          ),
                        ),
                      ],
                    ),

                    // ── Active Specializations Rail (All Selected Services!) ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFFDF9),
                              Color(0xFFFEF9EE),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFF3E8CE),
                            width: 1.1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0DF59E0B),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  size: 13,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'ACTIVE SPECIALIZATIONS (${worker.skills.length})',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF78716C),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    isOnline ? "ALL LIVE" : "READY",
                                    style: const TextStyle(
                                      color: Color(0xFF15803D),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (worker.skills.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: worker.skills
                                    .map((s) => _buildTradeChip(s))
                                    .toList(),
                              )
                            else
                              _buildTradeChip('General Service'),
                          ],
                        ),
                      ),
                    ),

                    // Callout: If hasRequest, show Accept Job Action Bar
                    if (hasRequest)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: GestureDetector(
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
                                    ModalRoute.of(context)?.isCurrent == true) {
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
                                    backgroundColor: const Color(0xFF141416),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    content: Text(
                                      e.message,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    action: SnackBarAction(
                                      label: 'go_to_job'.trSafe('Go to Job'),
                                      textColor: const Color(0xFFFFDE59),
                                      onPressed: () async {
                                        final ongoing = await _bookingService
                                            .getWorkerActiveJob(worker.id);
                                        if (ongoing != null && context.mounted) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (ctx) => ActiveJobScreen(
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
                                    backgroundColor: const Color(0xFF141416),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
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
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141416),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.flash_on_rounded,
                                      color: KX.gold,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "₹${topReq!.amount.toStringAsFixed(0)} • ${topReq.serviceType.toLocalizedTrade()}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: KX.gold,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'accept_job_btn'.trSafe("Accept Job"),
                                    style: const TextStyle(
                                      color: Color(0xFF141416),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Integrated Action Footer: WorkGo Co-op Status + SOS Emergency Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      child: Row(
                        children: [
                          // Left: WorkGo Co-op ready status pill
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFDF9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFF3E7C4),
                                ),
                              ),
                              child: Row(
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
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'workgo_coop_label'.trSafe("WorkGo Co-op"),
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF1E1035),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // SOS Emergency Beacon Button
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.heavyImpact();
                              _showSosBeaconSheet(context, worker);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.sos_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    "SOS",
                                    style: TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Dial Karya Telephony Gateway & Peer KYC Station Card
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _openDialKaryaHub(context, worker);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.settings_phone_rounded,
                    color: Color(0xFFB45309),
                    size: 22,
                  ),
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
                              'dial_karya_gateway_title'.trSafe(
                                "Dial Karya Voice Gateway",
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF141416),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  "ACTIVE",
                                  style: TextStyle(
                                    color: Color(0xFF15803D),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'dial_karya_gateway_sub'.trSafe(
                          "Telephony Gateway & Peer KYC Station",
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF78350F),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFFB45309),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
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
                            child: Text(
                              'enter_start_otp_btn'.trSafe(
                                "OTP மூலம் சரிபார்க்கவும்",
                              ),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                            builder: (ctx) => ActiveJobScreen(
                              booking: booking,
                              worker: worker,
                            ),
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
