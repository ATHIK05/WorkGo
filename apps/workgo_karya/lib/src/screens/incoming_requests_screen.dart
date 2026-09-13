import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';
import '../services/karya_tts_service.dart';
import 'active_job_screen.dart';
import '../widgets/job_preparation_tools_sheet.dart';

class IncomingRequestsScreen extends StatefulWidget {
  const IncomingRequestsScreen({
    super.key,
    required this.worker,
    this.requestsHubKey,
  });

  final Worker worker;
  final GlobalKey? requestsHubKey;

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen> {
  static const List<int> _radiusSteps = [5, 10, 15, 25];

  String _selectedFilter = "All";
  int _selectedRadiusKm = 10;
  bool _audioChimeEnabled = true;

  /// True once the user has manually tapped +/− radius in this session.
  /// Prevents Firestore updates from overriding an in-session manual choice.
  bool _hasManuallyAdjustedRadius = false;

  /// Snap an arbitrary km value to the nearest step in [_radiusSteps].
  static int _snapToStep(int km) {
    return _radiusSteps.reduce(
      (a, b) => (a - km).abs() <= (b - km).abs() ? a : b,
    );
  }

  @override
  void initState() {
    super.initState();
    // Worker may still be the fallback default (serviceRadiusKm == 5.0)
    // if Firestore hasn't responded yet — didUpdateWidget handles the sync.
    final saved = widget.worker.serviceRadiusKm;
    _selectedRadiusKm = saved > 0 ? _snapToStep(saved.toInt()) : 10;
  }

  @override
  void didUpdateWidget(IncomingRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync radius from Firestore once real worker data arrives (or changes),
    // but ONLY if the user has not manually adjusted it this session.
    if (!_hasManuallyAdjustedRadius) {
      final oldRadius = oldWidget.worker.serviceRadiusKm;
      final newRadius = widget.worker.serviceRadiusKm;
      if (newRadius > 0 && newRadius != oldRadius) {
        final snapped = _snapToStep(newRadius.toInt());
        if (snapped != _selectedRadiusKm) {
          setState(() => _selectedRadiusKm = snapped);
        }
      }
    }
  }

  Future<void> _adjustRadius(int delta) async {
    final idx = _radiusSteps.indexOf(_selectedRadiusKm);
    final newIdx = (idx == -1 ? 1 : idx + delta).clamp(0, _radiusSteps.length - 1);
    final newRadius = _radiusSteps[newIdx];
    if (newRadius == _selectedRadiusKm) return;

    HapticFeedback.selectionClick();
    // Mark that the user has explicitly chosen a radius this session
    setState(() {
      _selectedRadiusKm = newRadius;
      _hasManuallyAdjustedRadius = true;
    });

    await BookingService().updateWorkerServiceRadius(
      widget.worker.id,
      newRadius.toDouble(),
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('radar_coverage_updated'.tr(args: [newRadius.toString()])),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _toggleAudioChime() {
    HapticFeedback.selectionClick();
    setState(() => _audioChimeEnabled = !_audioChimeEnabled);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _audioChimeEnabled
              ? "radar_chime_enabled".trSafe("Audio Broadcast Chime Enabled")
              : "radar_chime_muted".trSafe("Radar Audio Muted"),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingService = BookingService();
    final registeredSkills = widget.worker.skills;

    // Filter list: only channels the worker is registered for
    final filterOptions = [
      "All",
      if (registeredSkills.isNotEmpty) ...registeredSkills,
    ];

    return Scaffold(
      backgroundColor: KX.canvas,
      body: SafeArea(
        child: KeyedSubtree(
          key: widget.requestsHubKey,
          child: StreamBuilder<Booking?>(
            stream: bookingService.streamCurrentActiveJob(widget.worker.id),
            builder: (context, activeJobSnapshot) {
              final activeJob = activeJobSnapshot.data;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Top Neo-Editorial Greeting & Radar Controls
                  _buildTopHeader(context),

                  // ── 2. Upper Asymmetrical Hero Bento (Scanning Card + Theme Yellow Stepper)
                  _buildHeroBento(),
                  const SizedBox(height: 10),

                  // ── 2.5 Active Ongoing Service Banner (locks out new dispatches)
                  if (activeJob != null) ...[
                    _buildActiveJobBanner(context, activeJob),
                    const SizedBox(height: 10),
                  ],

                  // ── 3. Registered Trade Skills Filter Bar
                  if (registeredSkills.isNotEmpty)
                    _buildSkillFilterBar(filterOptions)
                  else
                    _buildNoRegisteredSkillsNotice(context),
                  const SizedBox(height: 8),

                  // ── 4. Broadcasts Stream: 3D Overlapping "Deck of Cards"
                  Expanded(
                    child: StreamBuilder<List<Booking>>(
                      stream: bookingService.streamWorkerIncomingRequests(
                        workerId: widget.worker.id,
                        skills: registeredSkills,
                        workerLat: widget.worker.latitude,
                        workerLng: widget.worker.longitude,
                        maxRadiusKm: _selectedRadiusKm.toDouble(),
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
                            itemCount: 2,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (_, __) => const KaryaShimmer(height: 170, borderRadius: 34),
                          );
                        }

                        // Strict safety check: only display bookings that match registered skills
                        var requests = (snapshot.data ?? []).where((b) {
                          return registeredSkills.any((s) => s.matchesTrade(b.serviceType));
                        }).toList();

                        // Apply selected trade channel filter
                        if (_selectedFilter != "All") {
                          requests = requests.where((b) => _selectedFilter.matchesTrade(b.serviceType)).toList();
                        }

                        // Audio chime alert for incoming broadcasts
                        if (requests.isNotEmpty && _audioChimeEnabled) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            for (final req in requests) {
                              BroadcastAlertService.instance.playBroadcastAlert(req);
                            }
                          });
                        }

                        if (requests.isEmpty) {
                          return _buildEmptyRadarState(context);
                        }

                        return _buildRequestCardsList(requests, bookingService, activeJob);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  1. TOP EDITORIAL GREETING (Inspired by Reference Screen)
  // ──────────────────────────────────────────────────────────────
  Widget _buildTopHeader(BuildContext context) {
    final firstName = widget.worker.name.trim().isNotEmpty
        ? widget.worker.name.trim().split(" ").first
        : (widget.worker.phoneForCalling ?? "Artisan");

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Avatar with live pulsing indicator
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFF0EDE6), width: 1.5),
                    ),
                    child: Center(
                      child: WorkGoAvatar(
                        avatarBase64: widget.worker.avatarBase64,
                        name: widget.worker.name,
                        radius: 20,
                      ),
                    ),
                  ),
                  const Positioned(
                    right: -1,
                    bottom: -1,
                    child: KPulsingDot(color: Color(0xFF10B981), size: 10),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "live_radar_greeting".trSafe("Glad you're online,"),
                    style: WorkGoFonts.body(
                      color: const Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    firstName,
                    style: WorkGoFonts.display(
                      color: const Color(0xFF141416),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Action Button: Audio Chime Toggle Squircle
          GestureDetector(
            onTap: _toggleAudioChime,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _audioChimeEnabled ? const Color(0xFF141416) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _audioChimeEnabled ? const Color(0xFF141416) : const Color(0xFFF0EDE6),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _audioChimeEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  size: 20,
                  color: _audioChimeEnabled ? const Color(0xFFFFDE59) : const Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  2. UPPER ASYMMETRICAL HERO BENTO (Scanning Card + Theme Yellow Stepper)
  // ──────────────────────────────────────────────────────────────
  Widget _buildHeroBento() {
    final registeredCount = widget.worker.skills.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Card: White Squircle with Exclamation Pill & Live Status
          Expanded(
            flex: 11,
            child: Transform.rotate(
              angle: -0.012,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
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
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFDE59),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.radar_rounded,
                          color: Color(0xFF141416),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "radar_scanning_active".trSafe("Live Dispatch"),
                      style: WorkGoFonts.heading(
                        color: const Color(0xFF141416),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      registeredCount > 0
                          ? "$registeredCount ${"trade_channels_active".trSafe("Trade Channels")}"
                          : "no_trade_channels".trSafe("No Skills Added"),
                      style: WorkGoFonts.body(
                        color: const Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Right Card: High-Contrast Theme Yellow Squircle (`#FFDE59`) with Steppers
          Expanded(
            flex: 12,
            child: Transform.rotate(
              angle: 0.015,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDE59),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE5C84C), width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18B45309),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          "$_selectedRadiusKm",
                          style: WorkGoFonts.numeric(
                            color: const Color(0xFF141416),
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "km",
                          style: TextStyle(
                            color: Color(0xFF141416),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "coverage_radius".trSafe("Radar Coverage"),
                      style: const TextStyle(
                        color: Color(0xFF141416),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tactile Stepper Buttons: [-] and [+]
                    Row(
                      children: [
                        _buildStepperButton(
                          icon: Icons.remove_rounded,
                          onTap: () => _adjustRadius(-1),
                        ),
                        const SizedBox(width: 8),
                        _buildStepperButton(
                          icon: Icons.add_rounded,
                          onTap: () => _adjustRadius(1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  3. REGISTERED SKILL FILTER PILLS
  // ──────────────────────────────────────────────────────────────
  Widget _buildSkillFilterBar(List<String> filterOptions) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        children: filterOptions.map((filter) {
          final isSelected = _selectedFilter.toLowerCase() == filter.toLowerCase();
          final label = filter == "All"
              ? "all_registered_channels".trSafe("All Registered")
              : filter.toLocalizedTrade();

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = filter);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF141416) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF141416) : const Color(0xFFF0EDE6),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF141416),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoRegisteredSkillsNotice(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "no_skills_registered_hint".trSafe("No trade skills configured. Add trade skills in Profile to receive job broadcasts."),
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  3.5 ACTIVE ONGOING SERVICE BANNER (Prevents duplicate job acceptance)
  // ──────────────────────────────────────────────────────────────
  Widget _buildActiveJobBanner(BuildContext context, Booking activeJob) {
    final customerName = activeJob.customerName?.trim().isNotEmpty == true
        ? activeJob.customerName!
        : "Customer";
    final trade = activeJob.serviceType.toLocalizedTrade();
    final amount = activeJob.totalAmount.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ActiveJobScreen(
                booking: activeJob,
                worker: widget.worker,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFDE59), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFDE59),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.engineering_rounded,
                    color: Color(0xFF141416),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDE59),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "ongoing_job_badge".trSafe("ONGOING JOB"),
                            style: GoogleFonts.urbanist(
                              color: const Color(0xFF141416),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "₹$amount · $trade",
                          style: GoogleFonts.urbanist(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "$customerName · ${'ongoing_job_hint'.trSafe('Finish current service to accept new dispatches')}",
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF9CA3AF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "View",
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFFFFDE59),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFFFDE59),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  4. CLEAN TACTILE REQUEST CARDS LIST (Glass Look, Non-Overlapping)
  // ──────────────────────────────────────────────────────────────
  Widget _buildRequestCardsList(
    List<Booking> requests,
    BookingService bookingService,
    Booking? activeJob,
  ) {
    final tilts = [-0.010, 0.012, -0.008, 0.010];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 95),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return KSlideFadeIn(
          delay: Duration(milliseconds: index * 40),
          child: Transform.rotate(
            angle: tilts[index % tilts.length],
            child: _OrganicDeckRequestCard(
              booking: requests[index],
              worker: widget.worker,
              service: bookingService,
              cardStyleIndex: index % 3,
              activeJob: activeJob,
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  5. EMPTY RADAR STATE (Inspired by Reference Left Screen)
  // ──────────────────────────────────────────────────────────────
  Widget _buildEmptyRadarState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Reference-Style Floating Setup Card
          Transform.rotate(
            angle: -0.014,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF9F7F2)],
                ),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "radar_tuning_title".trSafe("Complete Setup & Listen"),
                        style: WorkGoFonts.heading(
                          color: const Color(0xFF141416),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            KPulsingDot(color: Color(0xFF10B981), size: 6),
                            SizedBox(width: 5),
                            Text(
                              "SCANNING",
                              style: TextStyle(
                                color: Color(0xFF065F46),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tactile Radius Stepper Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EFE6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "search_radius".trSafe("Search Radius"),
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "$_selectedRadiusKm km",
                              style: WorkGoFonts.numeric(
                                color: const Color(0xFF141416),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildStepperButton(
                              icon: Icons.remove_rounded,
                              onTap: () => _adjustRadius(-1),
                            ),
                            const SizedBox(width: 8),
                            _buildStepperButton(
                              icon: Icons.add_rounded,
                              onTap: () => _adjustRadius(1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Audio Chime Switch Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "audio_broadcast_alerts".trSafe("Audio Broadcast Chime"),
                        style: const TextStyle(
                          color: Color(0xFF141416),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleAudioChime,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _audioChimeEnabled ? const Color(0xFF141416) : const Color(0xFFE5E0D8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _audioChimeEnabled ? "On" : "Off",
                                style: TextStyle(
                                  color: _audioChimeEnabled ? const Color(0xFFFFDE59) : const Color(0xFF6B7280),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Clean Hotspot Cards (Glass Style, Non-Overlapping)
          Text(
            "high_demand_hotspots".trSafe("High-Demand Hotspots"),
            style: WorkGoFonts.heading(
              color: const Color(0xFF141416),
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),

          // Hotspot 1: Pitch Black Glass Card (subtle tilt +0.010)
          Transform.rotate(
            angle: 0.010,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B1B1E), Color(0xFF101012)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1.6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Central Bazaar & Gandhipuram",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDE59),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "HIGH DEMAND",
                          style: TextStyle(
                            color: Color(0xFF141416),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "3x",
                    style: WorkGoFonts.numeric(
                      color: const Color(0xFFFFDE59),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Hotspot 2: Warm Theme Yellow Glass Card (subtle tilt -0.010)
          Transform.rotate(
            angle: -0.010,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFDE59), Color(0xFFFFCD4A)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1.6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB45309).withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Peelamedu Tech Zone",
                        style: TextStyle(
                          color: Color(0xFF141416),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "SURGE BONUS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "+₹250",
                    style: WorkGoFonts.numeric(
                      color: const Color(0xFF141416),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  4. ORGANIC DECK REQUEST CARD (The Glass & Overlapping Card Look)
// ──────────────────────────────────────────────────────────────
class _OrganicDeckRequestCard extends StatelessWidget {
  const _OrganicDeckRequestCard({
    required this.booking,
    required this.worker,
    required this.service,
    required this.cardStyleIndex,
    this.activeJob,
  });

  final Booking booking;
  final Worker worker;
  final BookingService service;
  final int cardStyleIndex; // 0: White Glass, 1: Pitch Black Glass, 2: Theme Yellow
  final Booking? activeJob;

  void _showReferPeerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFFF0EDE6), width: 1.2),
        ),
        title: Text(
          "refer_job_title".trSafe("Refer Job to Peer Artisan"),
          style: WorkGoFonts.heading(
            color: const Color(0xFF141416),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "refer_job_hint".trSafe("Transfer this dispatch to a verified co-op peer in your network."),
              style: WorkGoFonts.body(color: const Color(0xFF6B7280), fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Color(0xFF141416)),
              decoration: InputDecoration(
                labelText: "peer_contact_label".trSafe("Peer Name or Phone"),
                labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                filled: true,
                fillColor: const Color(0xFFF9F6EE),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFF0EDE6)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              "cancel".trSafe("Cancel"),
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
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
                    content: Text("job_referred_success".trSafe("Job referred to peer successfully.")),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF141416),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text("transfer_job".trSafe("Transfer Job")),
          ),
        ],
      ),
    );
  }

  void _showBusyActiveJobSheet(BuildContext context, Booking job) {
    final customerName = job.customerName?.trim().isNotEmpty == true
        ? job.customerName!
        : "Customer";
    final trade = job.serviceType.toLocalizedTrade();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1E000000),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFDE59),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_clock_rounded,
                      color: Color(0xFF141416),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "active_job_busy_title".trSafe("Active Job in Progress"),
                        style: GoogleFonts.urbanist(
                          color: const Color(0xFF141416),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$customerName · $trade (₹${job.totalAmount.toStringAsFixed(0)})",
                        style: GoogleFonts.urbanist(
                          color: const Color(0xFF6B7280),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "active_job_busy_desc".trSafe(
                        "You have an ongoing service in progress. Complete your current job before accepting new dispatches.",
                      ),
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF92400E),
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ActiveJobScreen(
                      booking: job,
                      worker: worker,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF141416),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFFDE59), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "resume_ongoing_job".trSafe("Resume Active Job"),
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Stay on Radar",
                style: GoogleFonts.urbanist(
                  color: const Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAccept(BuildContext context) async {
    // 1. Immediate UI validation: lock out if artisan already has an ongoing service
    if (activeJob != null) {
      HapticFeedback.heavyImpact();
      _showBusyActiveJobSheet(context, activeJob!);
      return;
    }

    try {
      await service.acceptBooking(
        booking.id,
        worker.id,
        workerName: worker.name,
        workerPhone: worker.phoneForCalling,
        initialWorkerLat: worker.latitude,
        initialWorkerLng: worker.longitude,
      );
      KaryaTtsService.instance.announceJobAccepted(booking);
      if (context.mounted) {
        await JobPreparationToolsSheet.show(
          context,
          booking: booking,
          worker: worker,
        );
        if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (ctx) => ActiveJobScreen(
                booking: booking,
                worker: worker,
              ),
            ),
          );
        }
      }
    } on WorkerHasActiveJobException catch (e) {
      HapticFeedback.heavyImpact();
      if (context.mounted) {
        final ongoing = await service.getWorkerActiveJob(worker.id);
        if (ongoing != null && context.mounted) {
          _showBusyActiveJobSheet(context, ongoing);
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: const Color(0xFF141416),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        }
      }
    } on BookingAlreadyAcceptedException catch (e) {
      HapticFeedback.heavyImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF141416),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Row(
              children: [
                const Icon(Icons.flash_off_rounded, color: Color(0xFFFFDE59), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "job_already_taken".trSafe(e.message),
                    style: GoogleFonts.urbanist(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not accept dispatch: $e"),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmergency = booking.isEmergency;
    final totalPayout = booking.totalAmount;
    final netPayout = totalPayout * 0.98;

    final shortId = booking.id.length > 6
        ? booking.id.substring(0, 6).toUpperCase()
        : booking.id.toUpperCase();

    final address = booking.customerAddressText != null && booking.customerAddressText!.isNotEmpty
        ? booking.customerAddressText!
        : "customer_premises".trSafe("Customer Premises · In Zone");

    // Palette & Glass Styling per Style:
    final isBlack = (cardStyleIndex == 1) || isEmergency;
    final isYellow = !isBlack && (cardStyleIndex == 2 || booking.urgencyBonus > 0);

    final Gradient gradient = isBlack
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1C20), Color(0xFF101012)],
          )
        : (isYellow
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFDE59), Color(0xFFFFCD4A)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF9F7F2)],
              ));

    final Color borderSheen = isBlack
        ? Colors.white.withValues(alpha: 0.16)
        : (isYellow ? Colors.white.withValues(alpha: 0.65) : Colors.white);

    final Color primaryTextColor = isBlack
        ? Colors.white
        : const Color(0xFF141416);

    final Color subTextColor = isBlack
        ? const Color(0xFF9CA3AF)
        : (isYellow ? const Color(0xFF141416).withValues(alpha: 0.85) : const Color(0xFF6B7280));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: borderSheen, width: 1.8),
        boxShadow: [
          // Deep diffused ambient floor shadow (rolls over the card beneath)
          BoxShadow(
            color: Colors.black.withValues(alpha: isBlack ? 0.40 : 0.20),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: -2,
          ),
          // Soft contact shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          if (isYellow)
            BoxShadow(
              color: const Color(0xFFB45309).withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top Row: Service Title & Big Numeric Price (Exact layout from reference crop)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Title
              Expanded(
                child: Text(
                  booking.serviceType.toLocalizedTrade(),
                  style: WorkGoFonts.heading(
                    color: primaryTextColor,
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),

              // Price Display: Big 30px bold number like "108 mg/dL"
              Text(
                "₹${totalPayout.toStringAsFixed(0)}",
                style: WorkGoFonts.numeric(
                  color: primaryTextColor,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),

          // ── Second Row: Status Pill Tag (left) + Net Payout (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pill Badge (matches "1h 30min" from the reference image)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isBlack
                      ? const Color(0xFFFFDE59)
                      : (isYellow ? const Color(0xFF141416) : const Color(0xFFFFDE59)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isEmergency
                          ? Icons.flash_on_rounded
                          : (booking.urgencyBonus > 0 ? Icons.stars_rounded : Icons.radar_rounded),
                      size: 12,
                      color: isBlack
                          ? const Color(0xFF141416)
                          : (isYellow ? const Color(0xFFFFDE59) : const Color(0xFF141416)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isEmergency
                          ? "emergency_badge".trSafe("EMERGENCY")
                          : (booking.urgencyBonus > 0
                              ? "+₹${booking.urgencyBonus.toInt()} BONUS"
                              : "#$shortId · Priority"),
                      style: TextStyle(
                        color: isBlack
                            ? const Color(0xFF141416)
                            : (isYellow ? const Color(0xFFFFDE59) : const Color(0xFF141416)),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Net Payout Subtitle (matches "mg/dL" position in reference)
              Text(
                "Net: ₹${netPayout.toStringAsFixed(0)}",
                style: TextStyle(
                  color: isBlack
                      ? const Color(0xFF10B981)
                      : (isYellow ? const Color(0xFF141416) : const Color(0xFF059669)),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Address Row
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: subTextColor, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: WorkGoFonts.body(
                    color: subTextColor,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Tactile Action Row
          Row(
            children: [
              // Minimal Refer Button
              GestureDetector(
                onTap: () => _showReferPeerDialog(context),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isBlack
                        ? const Color(0xFF26262A)
                        : (isYellow ? Colors.black.withValues(alpha: 0.08) : const Color(0xFFF3EFE6)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isBlack
                          ? const Color(0xFF333338)
                          : (isYellow ? Colors.black.withValues(alpha: 0.12) : const Color(0xFFE5E0D8)),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "refer".trSafe("Refer"),
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Accept Button with Circular Play / Locked Icon
              Expanded(
                child: GestureDetector(
                  onTap: () => _handleAccept(context),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: activeJob != null
                          ? (isBlack ? const Color(0xFF2C2C32) : const Color(0xFFE5E7EB))
                          : (isBlack
                              ? const Color(0xFFFFDE59)
                              : const Color(0xFF141416)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: activeJob != null
                          ? null
                          : const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: activeJob != null
                                ? (isBlack ? const Color(0xFF141416) : const Color(0xFF9CA3AF))
                                : (isBlack ? const Color(0xFF141416) : Colors.white),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              activeJob != null
                                  ? Icons.lock_clock_rounded
                                  : Icons.play_arrow_rounded,
                              size: 15,
                              color: activeJob != null
                                  ? (isBlack ? const Color(0xFFFFDE59) : Colors.white)
                                  : (isBlack ? const Color(0xFFFFDE59) : const Color(0xFF141416)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            activeJob != null
                                ? "finish_active_job_first".trSafe("Finish Active Job First")
                                : "accept_dispatch".trSafe("Accept Dispatch"),
                            style: GoogleFonts.urbanist(
                              color: activeJob != null
                                  ? (isBlack ? const Color(0xFFE5E7EB) : const Color(0xFF4B5563))
                                  : (isBlack ? const Color(0xFF141416) : Colors.white),
                              fontSize: activeJob != null ? 11 : 12.5,
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
