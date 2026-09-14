import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
import '../../main.dart';
import 'booking_creation_screen.dart';
import 'live_booking_tracker_screen.dart';
import 'rapido_live_broadcast_screen.dart';
import 'payment_receipt_screen.dart';
import 'rating_review_screen.dart';
import 'worker_search_screen.dart';
import 'voice_ai_triage_screen.dart';
import '../services/ml_translation_service.dart';
import '../widgets/translated_text.dart';
import '../widgets/customer_emergency_sheet.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with TickerProviderStateMixin {
  int _currentNavIndex = 0;
  final BookingService _bookingService = BookingService();
  final AuthService _authService = AuthService();
  final WorkerService _workerService = WorkerService();
  late AnimationController _navIndicatorCtrl;
  String _bookingFilter = "all"; // 'all', 'active', 'completed', 'cancelled'
  String _selectedCategory =
      "All"; // Dynamic category filter for bento match cards
  static bool _hasPromptedThisSession = false;
  double? _customerLat;
  double? _customerLng;

  @override
  void initState() {
    super.initState();
    _customerLat = widget.user.latitude ?? widget.user.currentAddress?.latitude;
    _customerLng =
        widget.user.longitude ?? widget.user.currentAddress?.longitude;
    // Fallback to regional hub if coordinates not yet present on user profile
    if (_customerLat == null ||
        _customerLat! <= 1.0 ||
        _customerLng == null ||
        _customerLng! <= 1.0) {
      _customerLat = 11.3445;
      _customerLng = 77.7327;
    }
    _navIndicatorCtrl = AnimationController(
      vsync: this,
      duration: CAnim.normal,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptLocation();
      _loadCustomerLocation();
    });
  }

  @override
  void didUpdateWidget(covariant CustomerHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final userLat =
        widget.user.latitude ?? widget.user.currentAddress?.latitude;
    final userLng =
        widget.user.longitude ?? widget.user.currentAddress?.longitude;
    if (userLat != null &&
        userLng != null &&
        userLat > 1.0 &&
        userLng > 1.0 &&
        (userLat != _customerLat || userLng != _customerLng)) {
      setState(() {
        _customerLat = userLat;
        _customerLng = userLng;
      });
    }
  }

  Future<void> _loadCustomerLocation() async {
    try {
      // 1. High-precision live hardware GPS has top priority for customer radar
      final coords = await LocationService.instance.getCurrentCoordinates();
      final hardwareLat = (coords["latitude"] as num?)?.toDouble();
      final hardwareLng = (coords["longitude"] as num?)?.toDouble();

      if (hardwareLat != null &&
          hardwareLng != null &&
          !LocationService.isEmulatorOrOutOfBounds(hardwareLat, hardwareLng) &&
          mounted) {
        setState(() {
          _customerLat = hardwareLat;
          _customerLng = hardwareLng;
        });

        // Sync live GPS to Firestore user profile in background
        FirebaseFirestore.instance
            .collection("users")
            .doc(widget.user.uid)
            .set({
              "latitude": hardwareLat,
              "longitude": hardwareLng,
              "lastGpsUpdate": FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((_) {});
        return;
      }

      // 2. Saved user profile address
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final currAddr = data["currentAddress"];
        final lat =
            (data["latitude"] as num?)?.toDouble() ??
            (currAddr is Map
                ? (currAddr["latitude"] as num?)?.toDouble()
                : null);
        final lng =
            (data["longitude"] as num?)?.toDouble() ??
            (currAddr is Map
                ? (currAddr["longitude"] as num?)?.toDouble()
                : null);
        final addrText =
            (data["address"] as String?) ??
            (currAddr is Map
                ? (currAddr["formattedAddress"] as String?)
                : null) ??
            "";

        final sanitized = await LocationService.instance
            .resolveSanitizedCoordinates(
              addressText: addrText,
              latitude: lat,
              longitude: lng,
            );

        if (mounted) {
          setState(() {
            _customerLat = sanitized["latitude"];
            _customerLng = sanitized["longitude"];
          });
          return;
        }
      }

      // 3. Saved addresses collection
      final addrSnap = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.user.uid)
          .collection("addresses")
          .limit(1)
          .get();
      if (addrSnap.docs.isNotEmpty) {
        final d = addrSnap.docs.first.data();
        final lat = (d["latitude"] as num?)?.toDouble();
        final lng = (d["longitude"] as num?)?.toDouble();
        final addrText = (d["formattedAddress"] as String?) ?? "";

        final sanitized = await LocationService.instance
            .resolveSanitizedCoordinates(
              addressText: addrText,
              latitude: lat,
              longitude: lng,
            );

        if (mounted) {
          setState(() {
            _customerLat = sanitized["latitude"];
            _customerLng = sanitized["longitude"];
          });
          return;
        }
      }

      // 4. Default cooperative regional hub fallback
      if ((_customerLat == null ||
              LocationService.isEmulatorOrOutOfBounds(
                _customerLat,
                _customerLng,
              )) &&
          mounted) {
        setState(() {
          _customerLat = 11.3410;
          _customerLng = 77.7172;
        });
      }
    } catch (_) {
      if ((_customerLat == null ||
              LocationService.isEmulatorOrOutOfBounds(
                _customerLat,
                _customerLng,
              )) &&
          mounted) {
        setState(() {
          _customerLat = 11.3410;
          _customerLng = 77.7172;
        });
      }
    }
  }

  Future<void> _checkAndPromptLocation() async {
    if (_hasPromptedThisSession) return;
    _hasPromptedThisSession = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyConfigured =
          prefs.getBool("customer_loc_done_${widget.user.uid}") ?? false;
      if (alreadyConfigured) return;

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.user.uid)
          .get();
      final data = doc.data() ?? {};
      final currentAddress = data["currentAddress"];
      final lat = data["latitude"];

      final addrSnap = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.user.uid)
          .collection("addresses")
          .limit(1)
          .get();

      final hasLocation =
          addrSnap.docs.isNotEmpty || currentAddress != null || lat != null;

      if (!hasLocation && mounted) {
        await prefs.setBool("customer_loc_done_${widget.user.uid}", true);
        if (!mounted) return;
        await showLocationPromptSheet(
          context,
          userId: widget.user.uid,
          userRole: "customer",
        );
      } else {
        await prefs.setBool("customer_loc_done_${widget.user.uid}", true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _navIndicatorCtrl.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() => _currentNavIndex = index);
  }

  void _navigateToActiveBooking(BuildContext context, Booking booking) {
    HapticFeedback.lightImpact();
    // If the booking is pending and has no artisan assigned, it is an active broadcast!
    if (booking.status == BookingStatus.pending &&
        (booking.workerId == null || booking.workerId!.isEmpty)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RapidoLiveBroadcastScreen(
            bookingId: booking.id,
            serviceCategory: booking.serviceType,
            initialAmount: booking.totalAmount,
            pickupAddress: booking.customerAddressText ?? 'your_location'.tr(),
          ),
        ),
      );
    } else {
      // Booking is direct-assigned, accepted, or in progress
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveBookingTrackerScreen(
            bookingId: booking.id,
            initialBooking: booking,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: AuroraScaffold(
        extendBody: true,
        bottomNavigationBar: _buildFloatingDock(),
        body: IndexedStack(
          index: _currentNavIndex,
          children: [
            _buildHomeFeed(context),
            WorkerSearchScreen(
              customerId: widget.user.uid,
              customerLat: _customerLat,
              customerLng: _customerLng,
            ),
            _buildMyBookingsTab(context),
            _buildProfileTab(context),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  FLOATING OBSIDIAN DOCK (Template Standard)
  // ──────────────────────────────────────────
  Widget _buildFloatingDock() {
    final items = [
      (Icons.home_rounded, 'nav_home'.tr()),
      (Icons.grid_view_rounded, 'nav_explore'.tr()),
      (Icons.receipt_long_rounded, 'nav_orders'.tr()),
      (Icons.person_outline_rounded, 'nav_profile_tab'.tr()),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 10),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(items.length, (i) {
              final active = _currentNavIndex == i;
              final (icon, _) = items[i];

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _onNavTap(i);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: active ? 52 : 46,
                  height: active ? 52 : 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? Colors.white : Colors.transparent,
                    boxShadow: active
                        ? const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 22,
                      color: active
                          ? const Color(0xFF141416)
                          : const Color(0xFF8E8E93),
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

  // ──────────────────────────────────────────
  //  HOME FEED — WorkGo Luxury Customer Cockpit
  // ──────────────────────────────────────────
  Widget _buildHomeFeed(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Editorial Hero Card (Yellow & White Ambient Mesh Canvas)
            // Hosts: User Header + Address Selector + Safety SOS + Editorial Headline with Hand-Drawn Pen Marker Loop + Pill Search + Detached Obsidian Mic Button
            _buildEditorialHeroCard(),
            const SizedBox(height: 18),

            // 2. Interactive Category Filter Bar ("Category" horizontal pill strip)
            _buildCategoryFilterBar(),
            const SizedBox(height: 18),

            // 3. "Artisans matched with you" Bento Cards (Real Stream Data with Trade Watermark, Master title & Occupation Marker Loop)
            _buildArtisansMatchedWithYouSection(),
            const SizedBox(height: 20),

            // 4. Customer Live Order Radar & 1-Tap Rebook Hub
            _buildCustomerLiveHubAndRebookStrip(),
            const SizedBox(height: 16),

            // 5. Emergency Rapid 10-Min SOS Dispatch Row
            _buildEmergencyRapidDispatchBar(),
            const SizedBox(height: 16),

            // 6. Cooperative Fair-Pricing & Quality Guarantee Badges
            _buildCooperativeGuaranteeStrip(),
            const SizedBox(height: 22),

            // 7. "Active Bookings & Fast Action" Bento Grid (Real Stream Data)
            _buildCustomerWorkGoBentoGrid(),
            const SizedBox(height: 24),

            // 8. Section Header: Explore Craft Services
            _buildSectionHeader(
              title: 'explore_craft_services'.tr(),
              actionLabel: 'view_all'.tr(),
              onAction: () => _onNavTap(1),
            ),
            const SizedBox(height: 14),

            // 9. 8-Category Bento Grid
            _buildCategoryBentoGrid(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  1. EDITORIAL HERO CARD (Yellow & White Ambient Mesh Canvas)
  // ──────────────────────────────────────────
  Widget _buildEditorialHeroCard() {
    final name = widget.user.displayName.isNotEmpty
        ? widget.user.displayName.split(' ').first
        : widget.user.email.split('@').first;
    final now = DateTime.now();
    final dateStr =
        "${'today'.tr()} ${DateFormat('d MMM', context.locale.languageCode).format(now)}";

    return StreamBuilder<AppUser?>(
      stream: _authService.streamAppUser(widget.user.uid),
      initialData: widget.user,
      builder: (context, snap) {
        final liveUser = snap.data ?? widget.user;
        final avatar = liveUser.avatarBase64;
        final activeAddr = liveUser.currentAddress;
        final areaLabel = activeAddr != null
            ? "${activeAddr.displayTitle} · ${activeAddr.shortSummary}"
            : (liveUser.primaryArea ?? 'select_address'.tr());

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFDF0), Color(0xFFFEF9C3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header Inside Hero: Avatar + Greeting + Date + Address + SOS ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circular User Avatar (with halo border)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _onNavTap(3);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD97706).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        color: Colors.white,
                      ),
                      child: WorkGoAvatar(
                        avatarBase64: avatar,
                        name: name,
                        radius: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Greeting on top, Date below, and Address strictly below the date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'greeting_hello'.tr(args: [name]),
                          style: WorkGoFonts.heading(
                            color: const Color(0xFF141416),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          dateStr,
                          style: WorkGoFonts.body(
                            color: const Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        GestureDetector(
                          onTap: () async {
                            final selectedAddr =
                                await showAddressManagementSheet(
                                  context,
                                  userId: widget.user.uid,
                                  userRole: "customer",
                                  selectedAddress: activeAddr,
                                );
                            if (selectedAddr != null && mounted) {
                              setState(() {
                                _customerLat = selectedAddr.latitude;
                                _customerLng = selectedAddr.longitude;
                              });
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 12,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: TranslatedText(
                                  areaLabel,
                                  isAddress: true,
                                  style: const TextStyle(
                                    color: Color(0xFFB45309),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 16,
                                color: Color(0xFFD97706),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Safety / Emergency SOS Action Pill
                  InkWell(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      showCustomerEmergencySheet(
                        context,
                        myLat: _customerLat,
                        myLng: _customerLng,
                        onRefreshLocation: _loadCustomerLocation,
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFDC2626),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shield_rounded,
                            color: Color(0xFFDC2626),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'sos_action_btn'.tr(),
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Editorial Headline with Authentic Hand-Drawn Doodle Loop ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: WorkGoFonts.heading(
                        fontSize: 22,
                        letterSpacing: -0.4,
                        height: 1.25,
                      ),
                      children: const [
                        TextSpan(
                          text: "We ",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        TextSpan(
                          text: "connect you ",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF141416),
                          ),
                        ),
                        TextSpan(
                          text: "to your",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Transform.rotate(
                        angle: -0.03,
                        child: CustomPaint(
                          foregroundPainter: const _HandDrawnLoopPainter(
                            color: Color(0xFF141416),
                            strokeWidth: 2.2,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            child: Text(
                              "dream",
                              style: WorkGoFonts.heading(
                                color: const Color(0xFF141416),
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "artisan",
                        style: WorkGoFonts.heading(
                          color: const Color(0xFF6B7280),
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Search & Detached Obsidian Black Voice Mic Bar ──
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        VoiceAiTriageScreen.show(
                          context,
                          user: widget.user,
                          customerLat: _customerLat,
                          customerLng: _customerLng,
                          customerAddress:
                              widget.user.currentAddress?.shortSummary ??
                              widget.user.primaryArea,
                        );
                      },
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: const Color(0xFFFDE68A),
                            width: 1.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF141416),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'ai_search_placeholder'.tr(),
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
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
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      VoiceAiTriageScreen.show(
                        context,
                        user: widget.user,
                        customerLat: _customerLat,
                        customerLng: _customerLng,
                        customerAddress:
                            widget.user.currentAddress?.shortSummary ??
                            widget.user.primaryArea,
                      );
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF141416),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.mic_rounded,
                          color: Color(0xFFFBBF24),
                          size: 22,
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

  // ──────────────────────────────────────────
  //  2. HORIZONTAL CATEGORY FILTER PILL STRIP
  // ──────────────────────────────────────────
  Widget _buildCategoryFilterBar() {
    final categories = [
      (key: "All", label: "All", icon: Icons.tune_rounded),
      (
        key: "Plumbing",
        label: "cat_plumbing".tr(),
        icon: Icons.water_drop_rounded,
      ),
      (
        key: "Electrical",
        label: "cat_electrical".tr(),
        icon: Icons.bolt_rounded,
      ),
      (
        key: "Carpentry",
        label: "cat_carpentry".tr(),
        icon: Icons.carpenter_rounded,
      ),
      (
        key: "Cleaning",
        label: "cat_cleaning".tr(),
        icon: Icons.cleaning_services_rounded,
      ),
      (
        key: "Painting",
        label: "cat_painting".tr(),
        icon: Icons.format_paint_rounded,
      ),
      (
        key: "Appliance Repair",
        label: "cat_appliances".tr(),
        icon: Icons.kitchen_rounded,
      ),
      (key: "AC Repair", label: "AC Repair", icon: Icons.ac_unit_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'service_categories'.trSafe("Category"),
              style: WorkGoFonts.heading(
                color: const Color(0xFF141416),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () => _onNavTap(1),
              child: Text(
                'view_all'.tr(),
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = categories[i];
              final isSelected = _selectedCategory == cat.key;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = cat.key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF141416) : Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF141416)
                          : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
                              color: Color(0x24000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : const [
                            BoxShadow(
                              color: Color(0x05000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        color: isSelected
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF64748B),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF334155),
                          fontSize: 12.5,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getArtisanTradeDrawingIcon(String skill) {
    final s = skill.toLowerCase();
    if (s.contains('plumb')) return Icons.plumbing_rounded;
    if (s.contains('electr')) return Icons.bolt_rounded;
    if (s.contains('carpent')) return Icons.carpenter_rounded;
    if (s.contains('appliance') || s.contains('repair')) {
      return Icons.home_repair_service_rounded;
    }
    if (s.contains('ac') || s.contains('cool')) return Icons.ac_unit_rounded;
    if (s.contains('paint')) return Icons.format_paint_rounded;
    if (s.contains('clean')) return Icons.cleaning_services_rounded;
    return Icons.handyman_rounded;
  }

  String _getArtisanSpecialization(String skill) {
    final s = skill.toLowerCase();
    if (s.contains('plumb')) return "Sanitation & Pipe Specialist";
    if (s.contains('electr')) return "Power & Systems Specialist";
    if (s.contains('carpent')) return "Woodcraft & Joinery Specialist";
    if (s.contains('appliance') || s.contains('repair')) {
      return "Diagnostic & Hardware Specialist";
    }
    if (s.contains('ac') || s.contains('cool'))
      return "HVAC & Thermal Specialist";
    if (s.contains('paint')) return "Surface & Coating Specialist";
    if (s.contains('clean')) return "Hygiene & Detailing Specialist";
    return "Certified Cooperative Specialist";
  }

  // ──────────────────────────────────────────
  //  3. "ARTISANS MATCHED WITH YOU" BENTO CARDS (Real Stream Data)
  // ──────────────────────────────────────────
  Widget _buildArtisansMatchedWithYouSection() {
    return StreamBuilder<List<Worker>>(
      stream: _workerService.streamAvailableWorkers(
        skill: _selectedCategory == "All" ? "All" : _selectedCategory,
        onlineOnly: false,
      ),
      builder: (context, snap) {
        final rawWorkers = snap.data ?? [];
        if (rawWorkers.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "No active ${_selectedCategory.toLocalizedTrade()} artisans currently checked in nearby.",
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Real geodesic distance sorting
        final workers = rawWorkers
            .map((w) => w.withCalculatedDistance(_customerLat, _customerLng))
            .toList();
        workers.sort((a, b) {
          if (a.isOnlineOrCheckedIn != b.isOnlineOrCheckedIn) {
            return a.isOnlineOrCheckedIn ? -1 : 1;
          }
          return a.distanceKm.compareTo(b.distanceKm);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'top_verified_artisans'.tr(),
                    style: WorkGoFonts.heading(
                      color: const Color(0xFF141416),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _currentNavIndex = 1),
                  child: Text(
                    'see_all_count'.tr(args: ['${workers.length}']),
                    style: const TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 245,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: workers.length.clamp(0, 8),
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, idx) {
                  final worker = workers[idx];
                  final skill = worker.skills.isNotEmpty
                      ? worker.skills.first
                      : "Plumbing";
                  final fare = CooperativePricingEngine.instance
                      .getBaseVisitFare(skill)
                      .toInt();
                  final String trustText;
                  if (worker.homesServiced > 0) {
                    trustText = "${worker.homesServiced}+ Homes";
                  } else if (worker.totalRatings > 0) {
                    trustText = "${worker.totalRatings}+ Reviews";
                  } else if (worker.experienceYears > 0) {
                    trustText = "${worker.experienceYears}y Exp";
                  } else {
                    trustText = "verified_pro".tr();
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 285,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFFFFF), // Pure white on one side
                            Color(0xFFFFFBEB), // Soft warm cream
                            Color(
                              0xFFFDE68A,
                            ), // Luminous gold yellow over the other side
                          ],
                          stops: [0.0, 0.45, 1.0],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFFDE68A),
                          width: 1.4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Color(0x14F59E0B),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // ── Trade Drawing Watermark (Occupation Illustration) ──
                          Positioned(
                            right: -10,
                            top: 25,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: 0.07,
                                child: Icon(
                                  _getArtisanTradeDrawingIcon(skill),
                                  size: 130,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ),

                          // ── Card Foreground Content ──
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top Row: Avatar + Pro Status & Rating + Bookmark Button
                              Row(
                                children: [
                                  WorkGoAvatar(
                                    name: worker.name,
                                    avatarBase64: worker.avatarBase64,
                                    radius: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          worker.name,
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              color: Color(0xFFF59E0B),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              worker.avgRating > 0
                                                  ? worker.avgRating
                                                        .toStringAsFixed(1)
                                                  : "5.0",
                                              style: const TextStyle(
                                                color: Color(0xFF141416),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1.5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    worker.isOnlineOrCheckedIn
                                                    ? const Color(0xFFDCFCE7)
                                                    : const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                worker.isOnlineOrCheckedIn
                                                    ? "checked_in".tr()
                                                    : "verified_pro".tr(),
                                                style: TextStyle(
                                                  color:
                                                      worker.isOnlineOrCheckedIn
                                                      ? const Color(0xFF15803D)
                                                      : const Color(0xFF475569),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.bookmark_border_rounded,
                                        color: Color(0xFFD97706),
                                        size: 17,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Title: "Master" + Hand-Drawn Pen Marker Loop Drawing around Occupation
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Master ",
                                          style: WorkGoFonts.heading(
                                            color: const Color(0xFF141416),
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        Transform.rotate(
                                          angle: -0.03,
                                          child: CustomPaint(
                                            foregroundPainter:
                                                const _HandDrawnLoopPainter(
                                                  color: Color(0xFF141416),
                                                  strokeWidth: 2.2,
                                                ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 6,
                                                  ),
                                              child: Text(
                                                skill.toLocalizedTrade(),
                                                style: WorkGoFonts.heading(
                                                  color: const Color(
                                                    0xFF141416,
                                                  ),
                                                  fontSize: 16.5,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.3,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getArtisanSpecialization(skill),
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),

                              // Micro-Pills Badges Row
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.payments_outlined,
                                          size: 13,
                                          color: Color(0xFFB45309),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "₹$fare Base",
                                          style: const TextStyle(
                                            color: Color(0xFF92400E),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
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
                                          size: 13,
                                          color: Color(0xFFB45309),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          worker.distanceKm < 2.0
                                              ? "≤15 Min"
                                              : "${worker.distanceKm.toStringAsFixed(1)} km",
                                          style: const TextStyle(
                                            color: Color(0xFF92400E),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Bottom Row: Cooperative Trust Stack + Launcher Button
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Cooperative Trust Indicators Stack
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 44,
                                        height: 20,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Positioned(
                                              left: 0,
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: const Color(
                                                    0xFFF59E0B,
                                                  ),
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.verified_rounded,
                                                    size: 10,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 10,
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: const Color(
                                                    0xFF0284C7,
                                                  ),
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.shield_rounded,
                                                    size: 10,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 20,
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: const Color(
                                                    0xFF059669,
                                                  ),
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.handshake_rounded,
                                                    size: 10,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        trustText,
                                        style: const TextStyle(
                                          color: Color(0xFF1E293B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Quick Launch Arrow Button
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.mediumImpact();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => BookingCreationScreen(
                                            serviceCategory: skill,
                                            targetWorkerId: worker.id,
                                            worker: worker,
                                            customerId: widget.user.uid,
                                            customerLat: _customerLat,
                                            customerLng: _customerLng,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF141416),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0x33000000),
                                            blurRadius: 8,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.north_east_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ──────────────────────────────────────────
  //  TOP BAR (Avatar + Greeting + Date + Search)
  // ──────────────────────────────────────────
  Widget _buildSandraTopBar() {
    final name = widget.user.displayName.isNotEmpty
        ? widget.user.displayName.split(' ').first
        : widget.user.email.split('@').first;
    final now = DateTime.now();
    final dateStr =
        "${'today'.tr()} ${DateFormat('d MMM', context.locale.languageCode).format(now)}";

    return StreamBuilder<AppUser?>(
      stream: _authService.streamAppUser(widget.user.uid),
      initialData: widget.user,
      builder: (context, snap) {
        final liveUser = snap.data ?? widget.user;
        final avatar = liveUser.avatarBase64;
        final activeAddr = liveUser.currentAddress;
        final areaLabel = activeAddr != null
            ? "${activeAddr.displayTitle} · ${activeAddr.shortSummary}"
            : (liveUser.primaryArea ?? 'select_address'.tr());

        return Row(
          children: [
            // Circular User Avatar (with halo border)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _onNavTap(3);
              },
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF0EDE6),
                    width: 1.5,
                  ),
                  color: Colors.white,
                ),
                child: WorkGoAvatar(
                  avatarBase64: avatar,
                  name: name,
                  radius: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Greeting + Date & Address Bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'greeting_hello'.tr(args: [name]),
                    style: WorkGoFonts.heading(
                      color: const Color(0xFF141416),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  GestureDetector(
                    onTap: () async {
                      final selectedAddr = await showAddressManagementSheet(
                        context,
                        userId: widget.user.uid,
                        userRole: "customer",
                        selectedAddress: activeAddr,
                      );
                      if (selectedAddr != null && mounted) {
                        setState(() {
                          _customerLat = selectedAddr.latitude;
                          _customerLng = selectedAddr.longitude;
                        });
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            dateStr,
                            style: WorkGoFonts.body(
                              color: const Color(0xFF6B6B6B),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "•",
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: TranslatedText(
                            areaLabel,
                            isAddress: true,
                            style: const TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: Color(0xFFD97706),
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

  // ──────────────────────────────────────────
  //  AI SYMPTOM-FIRST SEARCH BAR
  // ──────────────────────────────────────────
  Widget _buildAiSymptomSearchBar() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        VoiceAiTriageScreen.show(
          context,
          user: widget.user,
          customerLat: _customerLat,
          customerLng: _customerLng,
          customerAddress:
              widget.user.currentAddress?.shortSummary ??
              widget.user.primaryArea,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CX.dividerLight),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: CX.violet.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.troubleshoot_rounded,
                color: CX.amberDark,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ai_search_placeholder'.tr(),
                    style: WorkGoFonts.body(
                      color: CX.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ai_search_subtitle'.tr(),
                    style: WorkGoFonts.body(
                      color: CX.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                VoiceAiTriageScreen.show(
                  context,
                  user: widget.user,
                  customerLat: _customerLat,
                  customerLng: _customerLng,
                  customerAddress:
                      widget.user.currentAddress?.shortSummary ??
                      widget.user.primaryArea,
                );
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: CX.violet.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CX.amberDark.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CX.amberDark.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.mic_rounded, color: CX.amberDark, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  WORKGO DISPATCH HERO CARD (Live Artisan Availability)
  // ──────────────────────────────────────────
  Widget _buildWorkGoDispatchHeroCard() {
    return StreamBuilder<List<Worker>>(
      stream: _workerService.streamAvailableWorkers(skill: "All"),
      builder: (context, snap) {
        final workers = snap.data ?? [];
        final totalCount = workers.isNotEmpty ? workers.length : 0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _onNavTap(1);
          },
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 156),
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEDE8FF), Color(0xFFDFD4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 18,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left Content: Title, Subtitle, and Live Available Pros
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'dispatch_hero_title'.tr(),
                            style: WorkGoFonts.heading(
                              color: const Color(0xFF141416),
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'dispatch_hero_subtitle'.tr(),
                            style: WorkGoFonts.body(
                              color: const Color(0xFF4B5563),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Avatar Stack: Live Available Workers + Verified Active Pill
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (workers.isNotEmpty)
                            SizedBox(
                              width: (workers.length.clamp(1, 3) * 20 + 14)
                                  .toDouble(),
                              height: 30,
                              child: Stack(
                                children: List.generate(
                                  workers.length.clamp(1, 3),
                                  (i) {
                                    final w = workers[i];
                                    return Positioned(
                                      left: (i * 20).toDouble(),
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          color: const Color(0xFF4F46E5),
                                        ),
                                        child: WorkGoAvatar(
                                          avatarBase64:
                                              w
                                                  .verificationDetails
                                                  ?.selfieBase64 ??
                                              w
                                                  .verificationDetails
                                                  ?.aadhaarPhotoBase64,
                                          name: w.name,
                                          radius: 13,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              width: 72,
                              height: 30,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    child: _miniAvatar(
                                      bg: const Color(0xFFFF6B6B),
                                      icon: Icons.handyman_rounded,
                                    ),
                                  ),
                                  Positioned(
                                    left: 18,
                                    child: _miniAvatar(
                                      bg: const Color(0xFF4ECDC4),
                                      icon: Icons.plumbing_rounded,
                                    ),
                                  ),
                                  Positioned(
                                    left: 36,
                                    child: _miniAvatar(
                                      bg: const Color(0xFFFFD93D),
                                      icon: Icons.bolt_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              totalCount > 0
                                  ? 'verified_active_count'.tr(
                                      args: ['$totalCount'],
                                    )
                                  : 'online_pros'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
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
                const SizedBox(width: 8),

                // Right Graphic: 3D Toy-style Geometric Orb Cluster
                SizedBox(
                  width: 88,
                  child: Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFB800).withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Yellow Ring
                          Positioned(
                            bottom: 10,
                            left: 8,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFFFB800),
                                  width: 8,
                                ),
                              ),
                            ),
                          ),
                          // Dark Cylinder
                          Positioned(
                            top: 6,
                            left: 12,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.flash_on_rounded,
                                  color: Color(0xFFFFB800),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          // Soft Violet/Grey Cushion
                          Positioned(
                            right: 8,
                            bottom: 20,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC4B5FD),
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1A000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.handyman_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniAvatar({required Color bg, required IconData icon}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(child: Icon(icon, color: Colors.white, size: 15)),
    );
  }

  // ──────────────────────────────────────────
  //  CUSTOMER LIVE HUB & REPEAT REBOOK STRIP
  // ──────────────────────────────────────────
  Widget _buildCustomerLiveHubAndRebookStrip() {
    return StreamBuilder<List<Booking>>(
      stream: _bookingService.streamCustomerBookings(widget.user.uid),
      builder: (context, snapshot) {
        final bookings = snapshot.data ?? [];
        final activeList = bookings
            .where(
              (b) =>
                  b.status == BookingStatus.paymentPending ||
                  b.status == BookingStatus.inProgress ||
                  b.status == BookingStatus.accepted ||
                  b.status == BookingStatus.pending,
            )
            .toList();
        final completedList = bookings
            .where((b) => b.status == BookingStatus.completed)
            .toList();

        // Active Order Live Radar
        if (activeList.isNotEmpty) {
          final active = activeList.first;
          return StreamBuilder<Worker?>(
            stream: (active.workerId != null && active.workerId!.isNotEmpty)
                ? _workerService.streamWorker(active.workerId!)
                : Stream.value(null),
            builder: (context, workerSnap) {
              final worker = workerSnap.data;
              String assignedName =
                  (active.acceptedWorkerName?.isNotEmpty == true &&
                      active.acceptedWorkerName!.toLowerCase() != 'artisan' &&
                      active.acceptedWorkerName!.toLowerCase() != 'partner' &&
                      active.acceptedWorkerName!.toLowerCase() != 'worker' &&
                      active.acceptedWorkerName!.toLowerCase() != 'artisian')
                  ? active.acceptedWorkerName!
                  : (worker?.name.isNotEmpty == true ? worker!.name : "");

              final String localizedAssignedName = assignedName.isNotEmpty
                  ? MlTranslationService.instance.translateSync(
                      assignedName,
                      context.locale.languageCode,
                    )
                  : "";
              final String statusLabel;
              if (active.status == BookingStatus.pending) {
                statusLabel = 'connecting_specialist'.tr();
              } else if (active.status == BookingStatus.accepted) {
                statusLabel = localizedAssignedName.isNotEmpty
                    ? 'assigned_en_route'.tr(args: [localizedAssignedName])
                    : 'artisan_en_route'.tr();
              } else {
                statusLabel = localizedAssignedName.isNotEmpty
                    ? 'worker_in_progress'.tr(args: [localizedAssignedName])
                    : 'service_in_progress'.tr();
              }

              return GestureDetector(
                onTap: () => _navigateToActiveBooking(context, active),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1035), Color(0xFF2E1065)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x282E1065),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                          border: Border.all(
                            color: const Color(0xFFFFB800),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: PulsingDot(color: Color(0xFFFFB800), size: 10),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB800),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'live_order_badge'.tr().toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF141416),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    active.serviceType.toLocalizedTrade(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              statusLabel,
                              style: const TextStyle(
                                color: Color(0xFFD8B4FE),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        // Repeat Recent Service Rebook Capsule
        if (completedList.isNotEmpty) {
          final last = completedList.first;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.history_rounded,
                      color: Color(0xFF059669),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'repeat_recent_service'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "${last.serviceType.toLocalizedTrade()} • ₹${last.totalAmount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Color(0xFF141416),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookingCreationScreen(
                          serviceCategory: last.serviceType,
                          customerId: widget.user.uid,
                          customerLat: _customerLat,
                          customerLng: _customerLng,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.replay_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                  label: Text(
                    'one_tap_book'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141416),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Default greeting if no prior bookings
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF059669),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'coop_trust_banner'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────
  //  EMERGENCY RAPID 10-MIN SOS DISPATCH BAR
  // ──────────────────────────────────────────
  Widget _buildEmergencyRapidDispatchBar() {
    final emergencies = [
      (
        trade: "Plumbing",
        label: 'em_pipe_burst'.tr(),
        icon: Icons.water_drop_rounded,
        color: const Color(0xFF0284C7),
      ),
      (
        trade: "Electrical",
        label: 'em_power_cut'.tr(),
        icon: Icons.bolt_rounded,
        color: const Color(0xFFD97706),
      ),
      (
        trade: "Appliance Repair",
        label: 'em_fridge_ac'.tr(),
        icon: Icons.kitchen_rounded,
        color: const Color(0xFFDC2626),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.flash_on_rounded,
                    color: Color(0xFFEF4444),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'rapid_sos_title'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF141416),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'priority_badge'.tr(),
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: emergencies.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final em = emergencies[i];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookingCreationScreen(
                        serviceCategory: em.trade,
                        customerId: widget.user.uid,
                        customerLat: _customerLat,
                        customerLng: _customerLng,
                        isEmergencyInitial: true,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 175,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: em.color.withValues(alpha: 0.3)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: em.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(em.icon, color: em.color, size: 15),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              em.trade.toLocalizedTrade(),
                              style: TextStyle(
                                color: em.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              em.label,
                              style: const TextStyle(
                                color: Color(0xFF141416),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //  COOPERATIVE TRUST & GUARANTEE STRIP
  // ──────────────────────────────────────────
  Widget _buildCooperativeGuaranteeStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniGuaranteeBadge('guarantee_100'.tr()),
          Container(width: 1, height: 14, color: const Color(0xFFD1D5DB)),
          _buildMiniGuaranteeBadge('guarantee_0cut'.tr()),
          Container(width: 1, height: 14, color: const Color(0xFFD1D5DB)),
          _buildMiniGuaranteeBadge('guarantee_live_pros'.tr()),
        ],
      ),
    );
  }

  Widget _buildMiniGuaranteeBadge(String text) {
    return Flexible(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF374151),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ──────────────────────────────────────────
  //  CUSTOMER-SIDE DELETE BOOKING DIALOG (Retains for Admin)
  // ──────────────────────────────────────────
  void _confirmDeleteBooking(Booking booking) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFDC2626),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'remove_booking_title'.tr(),
                style: const TextStyle(
                  color: Color(0xFF141416),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'remove_booking_body'.tr(
            args: [booking.serviceType.toLocalizedTrade()],
          ),
          style: const TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              await _bookingService.hideBookingForCustomer(booking.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('booking_removed_toast'.tr()),
                    backgroundColor: const Color(0xFF141416),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'remove_action'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //  ACTIVE BOOKINGS & FAST ACTION BENTO GRID (100% Real Stream-Driven)
  // ──────────────────────────────────────────
  Widget _buildCustomerWorkGoBentoGrid() {
    return StreamBuilder<List<Booking>>(
      stream: _bookingService.streamCustomerBookings(widget.user.uid),
      builder: (context, snapshot) {
        final allBookings = snapshot.data ?? [];
        final activeBookings = allBookings
            .where(
              (b) =>
                  b.status != BookingStatus.cancelled &&
                  b.status != BookingStatus.completed,
            )
            .toList();

        final active = activeBookings.isNotEmpty ? activeBookings.first : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    active != null
                        ? 'active_ongoing_order'.tr()
                        : 'fast_actions_radar'.tr(),
                    style: WorkGoFonts.heading(
                      color: const Color(0xFF141416),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (active != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PulsingDot(color: Color(0xFF10B981), size: 6),
                        const SizedBox(width: 4),
                        Text(
                          'live_badge'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF047857),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Asymmetrical Bento Grid: Tall Amber Card (Left) + 2 Stacked Cards (Right)
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  // ── LEFT TALL CARD (Warm Amber)
                  Expanded(
                    flex: 11,
                    child: GestureDetector(
                      onTap: () {
                        if (active != null) {
                          _navigateToActiveBooking(context, active);
                        } else {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => BookingCreationScreen(
                                serviceCategory: "Appliance Repair",
                                customerId: widget.user.uid,
                                customerLat: _customerLat,
                                customerLng: _customerLng,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD269),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0E000000),
                              blurRadius: 12,
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
                                // Top Pill Tag
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    active != null
                                        ? "STATUS: ${active.status.toLocalizedName().toUpperCase()}"
                                        : 'coop_promise'.tr(),
                                    style: const TextStyle(
                                      color: Color(0xFF141416),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  active != null
                                      ? active.serviceType.toLocalizedTrade()
                                      : 'instant_home_repairs'.tr(),
                                  style: WorkGoFonts.heading(
                                    color: const Color(0xFF141416),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  active != null
                                      ? (active.scheduledAt ?? DateTime.now())
                                            .to12HourDateTime()
                                      : 'zero_commission'.tr(),
                                  style: const TextStyle(
                                    color: Color(0xFF4B5563),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                if (active != null)
                                  TranslatedText(
                                    active.customerAddressText ??
                                        'your_location'.tr(),
                                    isAddress: true,
                                    style: const TextStyle(
                                      color: Color(0xFF4B5563),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else
                                  Text(
                                    'tap_to_book'.tr(),
                                    style: const TextStyle(
                                      color: Color(0xFF4B5563),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),

                            // Bottom Artisan Row or Quick Book CTA
                            if (active != null)
                              StreamBuilder<Worker?>(
                                stream:
                                    (active.workerId != null &&
                                        active.workerId!.isNotEmpty)
                                    ? _workerService.streamWorker(
                                        active.workerId!,
                                      )
                                    : Stream.value(null),
                                builder: (context, snap) {
                                  final worker = snap.data;
                                  String displayName =
                                      (active.acceptedWorkerName?.isNotEmpty ==
                                              true &&
                                          active.acceptedWorkerName!
                                                  .toLowerCase() !=
                                              'artisan' &&
                                          active.acceptedWorkerName!
                                                  .toLowerCase() !=
                                              'partner' &&
                                          active.acceptedWorkerName!
                                                  .toLowerCase() !=
                                              'worker' &&
                                          active.acceptedWorkerName!
                                                  .toLowerCase() !=
                                              'artisian')
                                      ? active.acceptedWorkerName!
                                      : (worker?.name.isNotEmpty == true
                                            ? worker!.name
                                            : (active.status ==
                                                      BookingStatus.pending
                                                  ? 'matching_pro'.tr()
                                                  : "${active.serviceType.toLocalizedTrade()} ${'specialist_assigned'.tr()}"));

                                  return Row(
                                    children: [
                                      if (worker?.avatarBase64 != null &&
                                          worker!.avatarBase64!.isNotEmpty)
                                        WorkGoAvatar(
                                          name: displayName,
                                          avatarBase64: worker.avatarBase64,
                                          radius: 16,
                                        )
                                      else
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF3B82F6),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.person_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'assigned_artisan_label'.tr(),
                                              style: const TextStyle(
                                                color: Color(0xFF4B5563),
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            TranslatedText(
                                              displayName,
                                              style: const TextStyle(
                                                color: Color(0xFF141416),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141416),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'book_pro_now'.tr(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ── RIGHT STACKED COLUMN (Sky Blue + Pastel Pink)
                  Expanded(
                    flex: 10,
                    child: Column(
                      children: [
                        // Top Sky Blue Card (Rapid Radar Broadcast)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _onNavTap(1);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCDE7FF),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Top Row: 30s MATCH badge on Left + 3D Radar Orb on Right
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.65,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Text(
                                          "30s MATCH",
                                          style: TextStyle(
                                            color: Color(0xFF1E40AF),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const RadialGradient(
                                            colors: [
                                              Color(0xFF60A5FA),
                                              Color(0xFF2563EB),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF2563EB,
                                              ).withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.radar_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Bottom Content: Title + Subtitle (full width, zero overlap)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'rapid_radar'.tr(),
                                        style: WorkGoFonts.heading(
                                          color: const Color(0xFF141416),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'broadcast_nearby'.tr(),
                                        style: const TextStyle(
                                          color: Color(0xFF334155),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bottom Pastel Pink Action Pill Card (3 Specialized Independent Actions)
                        Container(
                          height: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD6F4),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 1. 15-Min Instant Rush Dispatch
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _onNavTap(1);
                                },
                                child: _pinkActionIcon(
                                  Icons.electric_bolt_rounded,
                                  const Color(0xFF7C3AED),
                                ),
                              ),
                              // 2. Saved Addresses Manager
                              GestureDetector(
                                onTap: () => showAddressManagementSheet(
                                  context,
                                  userId: widget.user.uid,
                                  userRole: "customer",
                                ),
                                child: _pinkActionIcon(
                                  Icons.location_on_rounded,
                                  const Color(0xFFD97706),
                                ),
                              ),
                              // 3. 24/7 Co-op Helpline
                              GestureDetector(
                                onTap: () => _showHelplineDialog(context),
                                child: _pinkActionIcon(
                                  Icons.support_agent_rounded,
                                  const Color(0xFF2563EB),
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

  void _showSafetyGuaranteeSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 34),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
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
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF059669),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'safety_sheet_title'.tr(),
                        style: WorkGoFonts.heading(
                          color: const Color(0xFF141416),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'safety_sheet_subtitle'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
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
            const SizedBox(height: 20),
            _buildSafetyFeatureTile(
              icon: Icons.shield_rounded,
              color: const Color(0xFF10B981),
              title: 'safety_property_cover'.tr(),
              desc: 'safety_property_desc'.tr(),
            ),
            const SizedBox(height: 12),
            _buildSafetyFeatureTile(
              icon: Icons.lock_clock_rounded,
              color: const Color(0xFF3B82F6),
              title: 'safety_escrow_title'.tr(),
              desc: 'safety_escrow_desc'.tr(),
            ),
            const SizedBox(height: 12),
            _buildSafetyFeatureTile(
              icon: Icons.verified_user_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'safety_bgcheck_title'.tr(),
              desc: 'safety_bgcheck_desc'.tr(),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF141416),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'got_it_safe'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyFeatureTile({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF141416),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelplineDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 34),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'helpline_title'.tr(),
                        style: WorkGoFonts.heading(
                          color: const Color(0xFF141416),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'helpline_subtitle'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
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
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
              ),
              title: Text(
                'helpline_tollfree'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF141416),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text(
                "1800-419-WORK (9675) • 24/7",
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Dialing 1800-419-WORK..."),
                      backgroundColor: const Color(0xFF059669),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'helpline_call_action'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const Divider(color: Color(0xFFF3F4F6)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              title: Text(
                'helpline_whatsapp'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF141416),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'helpline_whatsapp_sub'.tr(),
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Opening WorkGo WhatsApp Support..."),
                      backgroundColor: const Color(0xFF2563EB),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'helpline_chat_action'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinkActionIcon(IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.85),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(child: Icon(icon, color: color, size: 18)),
    );
  }

  // ──────────────────────────────────────────
  //  SECTION HEADER
  // ──────────────────────────────────────────
  Widget _buildSectionHeader({
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: WorkGoFonts.heading(
              color: const Color(0xFF141416),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF141416).withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    color: Color(0xFF141416),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ──────────────────────────────────────────
  //  STAGGERED MASONRY CRAFT SHOWCASE (Pinterest / Dribbble Inspiration Style)
  // ──────────────────────────────────────────
  Widget _buildCategoryBentoGrid() {
    final craftItems = [
      // 0. Plumbing (Tall Dynamic Card with plumber.gif animated asset)
      const _CraftServiceItem(
        key: "cat_plumbing",
        name: "Plumbing",
        categoryName: "Plumbing",
        tagline: "Pipes, Taps & Leaks",
        taglineKey: "tagline_plumbing_fittings",
        description:
            "Precision pipe fittings, faucet repair & sanitary leak fixes.",
        icon: Icons.plumbing_rounded,
        assetPath: "assets/images/plumber.gif",
        isAnimatedAsset: true,
        price: "From ₹149",
        priceAmount: 149,
        meshColor1: Color(0xFFC7D2FE),
        meshColor2: Color(0xFFBAE6FD),
      ),
      // 1. Electrical (electrian.gif animated asset)
      const _CraftServiceItem(
        key: "cat_electrical",
        name: "Electrical",
        categoryName: "Electrical",
        tagline: "Wiring & Power",
        taglineKey: "tagline_wiring_power",
        description:
            "Licensed wiring, switches, breaker fixes & expert lighting.",
        icon: Icons.bolt_rounded,
        assetPath: "assets/images/electrian.gif",
        isAnimatedAsset: true,
        price: "From ₹149",
        priceAmount: 149,
        meshColor1: Color(0xFFDDD6FE),
        meshColor2: Color(0xFFFED7AA),
      ),
      // 2. Carpentry (carpentry.gif animated asset)
      const _CraftServiceItem(
        key: "cat_carpentry",
        name: "Carpentry",
        categoryName: "Carpentry",
        tagline: "Woodwork & Doors",
        taglineKey: "tagline_woodwork_doors",
        description:
            "Custom woodwork, door fixes, lock repair & furniture care.",
        icon: Icons.carpenter_rounded,
        assetPath: "assets/images/carpentry.gif",
        isAnimatedAsset: true,
        price: "From ₹199",
        priceAmount: 199,
        meshColor1: Color(0xFFFED7AA),
        meshColor2: Color(0xFFFDE68A),
      ),
      // 3. Cleaning (cleaning.gif animated asset)
      const _CraftServiceItem(
        key: "cat_cleaning",
        name: "Cleaning",
        categoryName: "Cleaning",
        tagline: "Deep Home Clean",
        taglineKey: "tagline_deep_clean",
        description: "Deep home sanitation, kitchen scrub & spotless hygiene.",
        icon: Icons.cleaning_services_rounded,
        assetPath: "assets/images/cleaning.gif",
        isAnimatedAsset: true,
        price: "From ₹129",
        priceAmount: 129,
        meshColor1: Color(0xFFA7F3D0),
        meshColor2: Color(0xFFBAE6FD),
      ),
      // 4. Painting (painting.gif animated asset)
      const _CraftServiceItem(
        key: "cat_painting",
        name: "Painting",
        categoryName: "Painting",
        tagline: "Walls & Primer",
        taglineKey: "tagline_walls_primer",
        description:
            "Interior wall coats, waterproof primer & smooth finishes.",
        icon: Icons.format_paint_rounded,
        assetPath: "assets/images/painting.gif",
        isAnimatedAsset: true,
        price: "From ₹249",
        priceAmount: 249,
        meshColor1: Color(0xFFFECDD3),
        meshColor2: Color(0xFFDDD6FE),
      ),
      // 5. Appliance Repair (home_appliances.gif animated asset)
      const _CraftServiceItem(
        key: "cat_appliance",
        name: "Appliance",
        categoryName: "Appliance Repair",
        tagline: "AC & Fridge Repair",
        taglineKey: "tagline_ac_fridge",
        description: "AC servicing, refrigerator care & precision diagnostics.",
        icon: Icons.kitchen_rounded,
        assetPath: "assets/images/home_appliances.gif",
        isAnimatedAsset: true,
        price: "From ₹179",
        priceAmount: 179,
        meshColor1: Color(0xFFE9D5FF),
        meshColor2: Color(0xFFFBCFE8),
      ),
      // 6. Masonry (Warm Terracotta & Sand)
      const _CraftServiceItem(
        key: "cat_masonry",
        name: "Masonry",
        categoryName: "Masonry",
        tagline: "Tiles & Grouting",
        taglineKey: "tagline_tiles_grouting",
        description:
            "Tile fixing, wall grouting, plastering & structural repair.",
        icon: Icons.foundation_rounded,
        assetPath: "packages/workgo_core/assets/images/crafts/masonry.jpg",
        isAnimatedAsset: false,
        price: "From ₹299",
        priceAmount: 299,
        meshColor1: Color(0xFFFFEDD5),
        meshColor2: Color(0xFFFED7AA),
      ),
      // 7. Gardening (Lush Emerald Botanic)
      const _CraftServiceItem(
        key: "cat_gardening",
        name: "Gardening",
        categoryName: "Gardening",
        tagline: "Lawn & Soil Care",
        taglineKey: "tagline_lawn_soil",
        description: "Lawn maintenance, organic soil care & terrace greenery.",
        icon: Icons.yard_rounded,
        assetPath: "packages/workgo_core/assets/images/crafts/gardening.jpg",
        isAnimatedAsset: false,
        price: "From ₹149",
        priceAmount: 149,
        meshColor1: Color(0xFFA7F3D0),
        meshColor2: Color(0xFFE9D5FF),
      ),
    ];

    return Column(
      children: craftItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _AlternatingCraftRowCard(
            item: item,
            index: index,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => BookingCreationScreen(
                  serviceCategory: item.categoryName,
                  customerId: widget.user.uid,
                  customerLat: _customerLat,
                  customerLng: _customerLng,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ──────────────────────────────────────────
  //  TOP VERIFIED ARTISANS SPOTLIGHT
  // ──────────────────────────────────────────
  Widget _buildTopArtisansSpotlight() {
    return StreamBuilder<List<Worker>>(
      stream: _workerService.streamAvailableWorkers(
        skill: "All",
        onlineOnly: false,
      ),
      builder: (context, snap) {
        final rawWorkers = snap.data ?? [];
        if (rawWorkers.isEmpty) return const SizedBox.shrink();

        // Calculate real geodesic distance and sort nearest artisans first
        final workers = rawWorkers
            .map((w) => w.withCalculatedDistance(_customerLat, _customerLng))
            .toList();
        workers.sort((a, b) {
          if (a.isOnlineOrCheckedIn != b.isOnlineOrCheckedIn) {
            return a.isOnlineOrCheckedIn ? -1 : 1;
          }
          return a.distanceKm.compareTo(b.distanceKm);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: CX.emerald,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'top_verified_artisans'.tr(),
                          style: WorkGoFonts.heading(
                            color: CX.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _currentNavIndex = 1),
                  child: Text(
                    'see_all_count'.tr(args: ['${workers.length}']),
                    style: const TextStyle(
                      color: CX.cyanLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 146,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: workers.length.clamp(0, 6),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, idx) {
                  final worker = workers[idx];
                  return _ArtisanSpotlightCard(
                    worker: worker,
                    customerLat: _customerLat,
                    customerLng: _customerLng,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => BookingCreationScreen(
                          serviceCategory: worker.skills.isNotEmpty
                              ? worker.skills.first
                              : "Plumbing",
                          worker: worker.withCalculatedDistance(
                            _customerLat,
                            _customerLng,
                          ),
                          targetWorkerId: worker.id,
                          customerId: widget.user.uid,
                          customerLat: _customerLat,
                          customerLng: _customerLng,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAvatarUpload() async {
    final result = await ImageUploadService.instance
        .showAvatarPickerBottomSheet(context, uid: widget.user.uid);
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'profile_updated_toast'.tr(),
                style: WorkGoFonts.body(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  // ──────────────────────────────────────────
  //  MY BOOKINGS TAB — WORLD CLASS LIVE PIPELINE
  // ──────────────────────────────────────────
  Widget _buildMyBookingsTab(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Booking>>(
        stream: _bookingService.streamCustomerBookings(widget.user.uid),
        builder: (context, snapshot) {
          final allBookings = snapshot.data ?? [];

          final allCount = allBookings.length;
          final activeBookings = allBookings
              .where(
                (b) =>
                    b.status == BookingStatus.paymentPending ||
                    b.status == BookingStatus.inProgress ||
                    b.status == BookingStatus.accepted ||
                    b.status == BookingStatus.pending,
              )
              .toList();
          final activeCount = activeBookings.length;
          final completedBookings = allBookings
              .where((b) => b.status == BookingStatus.completed)
              .toList();
          final completedCount = completedBookings.length;
          final unratedCount = completedBookings
              .where((b) => !b.isRated && b.rating == null)
              .length;
          final cancelledCount = allBookings
              .where((b) => b.status == BookingStatus.cancelled)
              .length;

          final filteredBookings = allBookings.where((b) {
            if (_bookingFilter == "active") {
              return b.status == BookingStatus.paymentPending ||
                  b.status == BookingStatus.inProgress ||
                  b.status == BookingStatus.accepted ||
                  b.status == BookingStatus.pending;
            }
            if (_bookingFilter == "completed") {
              return b.status == BookingStatus.completed;
            }
            if (_bookingFilter == "unrated") {
              return b.status == BookingStatus.completed &&
                  !b.isRated &&
                  b.rating == null;
            }
            if (_bookingFilter == "cancelled") {
              return b.status == BookingStatus.cancelled;
            }
            return true;
          }).toList();

          final latestActive = activeBookings.isNotEmpty
              ? activeBookings.first
              : null;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // 1. Header Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'my_bookings'.tr(),
                              style: WorkGoFonts.heading(
                                color: const Color(0xFF141416),
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'invoice_receipt'.tr(),
                              style: WorkGoFonts.body(
                                color: const Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _onNavTap(1);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141416),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'book_pro_now'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
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
                  ),
                ),
              ),

              // 2. Active Booking Spotlight HUD (If active order exists)
              if (latestActive != null &&
                  _bookingFilter != "completed" &&
                  _bookingFilter != "cancelled")
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _buildActiveBookingPipelineHUD(latestActive),
                  ),
                ),

              // 3. Segmented Filter Tabs
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildBookingFilterPill(
                        "all",
                        'filter_all'.tr(),
                        allCount,
                      ),
                      const SizedBox(width: 8),
                      _buildBookingFilterPill(
                        "active",
                        'filter_active'.tr(),
                        activeCount,
                      ),
                      const SizedBox(width: 8),
                      _buildBookingFilterPill(
                        "completed",
                        'filter_completed'.tr(),
                        completedCount,
                      ),
                      const SizedBox(width: 8),
                      _buildBookingFilterPill(
                        "unrated",
                        'filter_unrated'.tr(),
                        unratedCount,
                      ),
                      const SizedBox(width: 8),
                      _buildBookingFilterPill(
                        "cancelled",
                        'filter_cancelled'.tr(),
                        cancelledCount,
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // 4. Bookings List or Empty State
              if (snapshot.connectionState == ConnectionState.waiting)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: AuroraShimmer(height: 130, borderRadius: 20),
                      ),
                      childCount: 3,
                    ),
                  ),
                )
              else if (filteredBookings.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    child: _buildCenteredBookingsEmptyState(),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final b = filteredBookings[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _BookingListTile(
                          booking: b,
                          onTap: () => _navigateToActiveBooking(context, b),
                          onBookAgain: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BookingCreationScreen(
                                  serviceCategory: b.serviceType,
                                  customerId: widget.user.uid,
                                  customerLat: _customerLat,
                                  customerLng: _customerLng,
                                ),
                              ),
                            );
                          },
                          onDelete: () => _confirmDeleteBooking(b),
                        ),
                      );
                    }, childCount: filteredBookings.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveBookingPipelineHUD(Booking booking) {
    final otp = booking.startOtp ?? "9421";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Live Pulse + Status + OTP Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PulsingDot(color: Color(0xFFD97706), size: 6),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'live_status_indicator'.tr(
                            args: [
                              booking.status.toLocalizedName().toUpperCase(),
                            ],
                          ),
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
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

              // OTP Pill with 1-tap Copy (Strictly only when status is accepted)
              if (booking.status == BookingStatus.accepted)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: otp));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('otp_copied_toast'.tr(args: [otp])),
                        backgroundColor: const Color(0xFF047857),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'start_otp_label'.tr(),
                            style: const TextStyle(
                              color: Color(0xFF78350F),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          otp,
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.copy_rounded,
                          color: Color(0xFFD97706),
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                )
              else if (booking.status == BookingStatus.inProgress)
                _CustomerStopwatchBadge(
                  startedAt:
                      booking.startedAt ??
                      booking.scheduledAt ??
                      DateTime.now(),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.radar_rounded,
                        size: 12,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'broadcasting_badge'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Service Title + Location
          Text(
            booking.serviceType.toLocalizedTrade(),
            style: WorkGoFonts.heading(
              color: const Color(0xFF141416),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          TranslatedText(
            booking.customerAddressText ?? 'your_location'.tr(),
            isAddress: true,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 14),

          // Assigned Pro & GPS Tracker Button
          Row(
            children: [
              Expanded(
                child: StreamBuilder<Worker?>(
                  stream:
                      (booking.workerId != null && booking.workerId!.isNotEmpty)
                      ? _workerService.streamWorker(booking.workerId!)
                      : Stream.value(null),
                  builder: (context, snap) {
                    final worker = snap.data;
                    String proName =
                        (booking.acceptedWorkerName?.isNotEmpty == true &&
                            booking.acceptedWorkerName!.toLowerCase() !=
                                'artisan' &&
                            booking.acceptedWorkerName!.toLowerCase() !=
                                'partner' &&
                            booking.acceptedWorkerName!.toLowerCase() !=
                                'worker' &&
                            booking.acceptedWorkerName!.toLowerCase() !=
                                'artisian')
                        ? booking.acceptedWorkerName!
                        : (worker?.name.isNotEmpty == true
                              ? worker!.name
                              : (booking.status == BookingStatus.pending
                                    ? 'matching_pro'.tr()
                                    : "${booking.serviceType.toLocalizedTrade()} ${'specialist_assigned'.tr()}"));
                    if (proName.toLowerCase() == 'artisan' ||
                        proName.toLowerCase() == 'partner' ||
                        proName.toLowerCase() == 'worker' ||
                        proName.toLowerCase() == 'artisian') {
                      proName = worker?.name.isNotEmpty == true
                          ? worker!.name
                          : "${booking.serviceType.toLocalizedTrade()} ${'specialist_assigned'.tr()}";
                    }

                    return Row(
                      children: [
                        if (worker?.avatarBase64 != null &&
                            worker!.avatarBase64!.isNotEmpty)
                          WorkGoAvatar(
                            name: proName,
                            avatarBase64: worker.avatarBase64,
                            radius: 19,
                          )
                        else
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF3B82F6),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'assigned_artisan_label'.tr(),
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              TranslatedText(
                                proName,
                                style: const TextStyle(
                                  color: Color(0xFF141416),
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
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (booking.status == BookingStatus.pending &&
                        (booking.workerId == null ||
                            booking.workerId!.isEmpty)) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RapidoLiveBroadcastScreen(
                            bookingId: booking.id,
                            serviceCategory: booking.serviceType,
                            initialAmount: booking.totalAmount,
                            pickupAddress:
                                booking.customerAddressText ??
                                'your_location'.tr(),
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => LiveBookingTrackerScreen(
                            bookingId: booking.id,
                            initialBooking: booking,
                          ),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    (booking.status == BookingStatus.pending &&
                            (booking.workerId == null ||
                                booking.workerId!.isEmpty))
                        ? Icons.radar_rounded
                        : Icons.navigation_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  label: Text(
                    (booking.status == BookingStatus.pending &&
                            (booking.workerId == null ||
                                booking.workerId!.isEmpty))
                        ? 'view_radar'.tr()
                        : 'track_gps'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141416),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

  Widget _buildBookingFilterPill(String key, String label, int count) {
    final isSelected = _bookingFilter == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _bookingFilter = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF141416) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF141416)
                : const Color(0xFFF0EDE6),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x20000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFFB800)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF141416)
                        : const Color(0xFF6B7280),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredBookingsEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0EDE6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Center(
              child: Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFFD97706),
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _bookingFilter == "all"
                ? 'empty_bookings_title'.tr()
                : 'empty_bookings_filter_title'.tr(
                    args: ['filter_$_bookingFilter'.tr()],
                  ),
            style: WorkGoFonts.heading(
              color: const Color(0xFF141416),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            'empty_bookings_subtitle'.tr(),
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _onNavTap(1),
            icon: const Icon(
              Icons.search_rounded,
              size: 16,
              color: Colors.white,
            ),
            label: Text(
              'explore_craft_services'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF141416),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //  PROFILE TAB — KARYA LUXURY STANDARD
  // ──────────────────────────────────────────
  Widget _buildProfileTab(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<AppUser?>(
        stream: _authService.streamAppUser(widget.user.uid),
        initialData: widget.user,
        builder: (context, userSnap) {
          final liveUser = userSnap.data ?? widget.user;
          final rawName = liveUser.displayName.trim();
          final name = (rawName.isEmpty || rawName.toLowerCase() == 'customer')
              ? 'customer_role'.trSafe("Customer")
              : (rawName.isNotEmpty
                    ? rawName
                    : (liveUser.email.isNotEmpty
                          ? liveUser.email.split('@').first
                          : 'customer_role'.trSafe("Customer")));

          return StreamBuilder<List<Booking>>(
            stream: _bookingService.streamCustomerBookings(widget.user.uid),
            builder: (context, bookingSnap) {
              final bookings = bookingSnap.data ?? [];
              final totalBookings = bookings.length;
              final savings = (totalBookings * 65).toInt();

              return StreamBuilder<List<UserAddress>>(
                stream: LocationService().streamUserAddresses(
                  widget.user.uid,
                  collection: "users",
                ),
                builder: (context, addrSnap) {
                  final addresses = addrSnap.data ?? [];
                  final defaultAddr = addresses.isNotEmpty
                      ? addresses.firstWhere(
                          (a) => a.isDefault,
                          orElse: () => addresses.first,
                        )
                      : null;

                  return StreamBuilder<List<Worker>>(
                    stream: _workerService.streamAvailableWorkers(skill: "All"),
                    builder: (context, workerSnap) {
                      final workers = workerSnap.data ?? [];
                      final verifiedProsCount = workers.length;

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Profile Title Header
                            Text(
                              "customer_profile_title".tr(),
                              style: WorkGoFonts.heading(
                                color: const Color(0xFF141416),
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 16),

                            // 2. Profile Hero Card (Avatar with Camera Badge, Name, Verified Status)
                            _buildCustomerHeroCard(liveUser, name),
                            const SizedBox(height: 16),

                            // Profile Security & Trust Hub (Google Identity, Phone OTP, Backup Password)
                            ProfileTrustHubCard(
                              user: liveUser,
                              role: "customer",
                            ),
                            const SizedBox(height: 16),

                            // 3. 4-Metric Bento Chips (Orders, Savings, Addresses, Pros)
                            _buildCustomerMetricStatsRow(
                              totalBookings: totalBookings,
                              savingsAmount: savings,
                              addressCount: addresses.length,
                              prosCount: verifiedProsCount,
                            ),
                            const SizedBox(height: 20),

                            // 4. Menu Matrix List (Addresses, Escrow, Safety, Referral, Language, Helpline)
                            _buildCustomerMenuMatrix(
                              defaultAddr: defaultAddr,
                              addressCount: addresses.length,
                            ),
                            const SizedBox(height: 20),

                            // 5. Cooperative Member Impact Guarantee Card
                            _buildCoopImpactCard(),
                            const SizedBox(height: 24),

                            // 6. Secure Sign Out Button
                            OutlinedButton.icon(
                              onPressed: () async {
                                final confirmed =
                                    await showSignOutConfirmationSheet(context);
                                if (confirmed == true) {
                                  widget.onSignOut();
                                }
                              },
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFF43F5E),
                                size: 18,
                              ),
                              label: Text(
                                "sign_out".tr(),
                                style: WorkGoFonts.heading(
                                  color: const Color(0xFFF43F5E),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                side: const BorderSide(
                                  color: Color(0xFFFECDD3),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: const Color(0xFFFFF1F2),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 7. Delete Account CTA (DPDP Act 2023 §12 Right to Erasure)
                            TextButton.icon(
                              onPressed: () async {
                                final confirmed =
                                    await showDeleteAccountConfirmationSheet(
                                      context,
                                    );
                                if (confirmed == true) {
                                  if (context.mounted) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (ctx) => const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFE11D48),
                                        ),
                                      ),
                                    );
                                  }

                                  try {
                                    final authService = AuthService();
                                    await authService.deleteAccount(
                                      uid: widget.user.uid,
                                    );
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.clear();

                                    if (context.mounted) {
                                      customerNavigatorKey.currentState
                                          ?.popUntil((route) => route.isFirst);

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(
                                                Icons
                                                    .check_circle_outline_rounded,
                                                color: Color(0xFF10B981),
                                                size: 22,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  "dpdp_erased_toast".tr(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: const Color(
                                            0xFF0F0B24,
                                          ),
                                          duration: const Duration(seconds: 5),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFF10B981),
                                              width: 1.2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      if (Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).canPop()) {
                                        Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ).pop();
                                      }
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Error during erasure: $e",
                                          ),
                                          backgroundColor: const Color(
                                            0xFFE11D48,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.delete_forever_rounded,
                                color: Color(0xFF9CA3AF),
                                size: 16,
                              ),
                              label: Text(
                                "delete_account_dpdp".tr(),
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  int _calculateTrustScore(AppUser user) {
    int count = 0;
    final currentUser = FirebaseAuth.instance.currentUser;
    final hasPassword =
        (currentUser?.providerData.any((p) => p.providerId == "password") ??
            false) ||
        user.hasBackupPassword;
    final hasGoogle =
        currentUser?.providerData.any((p) => p.providerId == "google.com") ??
        false;
    final hasPhone =
        (currentUser?.providerData.any((p) => p.providerId == "phone") ??
            false) ||
        (currentUser?.phoneNumber != null &&
            currentUser!.phoneNumber!.trim().isNotEmpty) ||
        user.isPhoneVerified;

    if (hasPassword) count++;
    if (hasGoogle) count++;
    if (hasPhone) count++;
    if (count == 0 &&
        ((currentUser?.email?.isNotEmpty ?? false) || user.email.isNotEmpty))
      return 15;
    return ((count / 3.0) * 100).round();
  }

  Widget _buildCustomerHeroCard(AppUser user, String name) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
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
          // Avatar with Tinder-Style Verification Ring
          ProfileAvatarTrustRing(
            score: _calculateTrustScore(user),
            avatarRadius: 34,
            ringGap: 4.0,
            strokeWidth: 3.5,
            onTap: () => showProfileTrustHubSheet(
              context,
              user: user,
              role: "customer",
              onUpdated: () => setState(() {}),
            ),
            child: Stack(
              children: [
                WorkGoAvatar(
                  avatarBase64: user.avatarBase64,
                  name: name,
                  radius: 34,
                  onEditTap: _handleAvatarUpload,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _handleAvatarUpload,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF141416),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _showEditNameDialog(context, user, name),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: WorkGoFonts.heading(
                              color: const Color(0xFF141416),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF10B981),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                              width: 0.8,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 11,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                if (user.email.isNotEmpty) ...[
                  Text(
                    user.email,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                ],
                InkWell(
                  onTap: () => _showEditPhoneDialog(context, user),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.phone_iphone_rounded,
                          color: Color(0xFF10B981),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            user.phoneNumber?.isNotEmpty == true
                                ? user.phoneNumber!
                                : 'add_phone_number'.tr(),
                            style: TextStyle(
                              color: user.phoneNumber?.isNotEmpty == true
                                  ? const Color(0xFF374151)
                                  : const Color(0xFF2563EB),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF9CA3AF),
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    "⭐ ${"patron_tier_badge".tr()}",
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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
    );
  }

  void _showEditNameDialog(
    BuildContext context,
    AppUser user,
    String currentName,
  ) {
    final effectiveCurrent =
        (currentName.isNotEmpty && currentName.toLowerCase() != 'customer')
        ? currentName
        : '';
    final nameCtrl = TextEditingController(text: effectiveCurrent);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEF3C7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.badge_outlined,
                              color: Color(0xFFB45309),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Edit Full Name",
                                  style: WorkGoFonts.heading(
                                    color: const Color(0xFF111827),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Visible to service artisans on bookings and invoices",
                                  style: WorkGoFonts.body(
                                    color: const Color(0xFF6B7280),
                                    fontSize: 11.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: nameCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 40,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          labelText: "Full Name",
                          labelStyle: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                          hintText: "e.g. Ramesh Kumar",
                          hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          counterText: "",
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                            color: Color(0xFF9CA3AF),
                          ),
                          suffixIcon: nameCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  onPressed: () {
                                    nameCtrl.clear();
                                    setSheetState(() {});
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF10B981),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Please enter your name";
                          }
                          if (val.trim().length < 2) {
                            return "Name must be at least 2 characters";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(sheetCtx).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: WorkGoFonts.heading(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (formKey.currentState?.validate() ??
                                          false) {
                                        setSheetState(() => isSaving = true);
                                        final trimmed = nameCtrl.text.trim();
                                        try {
                                          final authUser =
                                              FirebaseAuth.instance.currentUser;
                                          if (authUser != null) {
                                            await authUser.updateDisplayName(
                                              trimmed,
                                            );
                                          }
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(user.uid)
                                              .set({
                                                'displayName': trimmed,
                                                'name': trimmed,
                                                'updatedAt':
                                                    FieldValue.serverTimestamp(),
                                              }, SetOptions(merge: true));
                                        } catch (_) {}

                                        if (sheetCtx.mounted)
                                          Navigator.of(sheetCtx).pop();
                                        if (context.mounted) {
                                          setState(() {});
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.check_circle_rounded,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'profile_updated_toast'
                                                          .tr(),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: const Color(
                                                0xFF059669,
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF141416),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      "Save Name",
                                      style: WorkGoFonts.heading(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditPhoneDialog(BuildContext context, AppUser user) {
    final phoneCtrl = TextEditingController(
      text: user.phoneNumber?.replaceFirst('+91', '') ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'edit_phone_number'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'contact_phone'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Text(
                          "+91",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                            fontSize: 15,
                          ),
                        ),
                      ),
                      hintText: 'phone_number_hint'.tr(),
                      hintStyle: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF10B981),
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'error_phone_empty'.tr();
                      }
                      final digits = val.replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 10) {
                        return 'error_phone_invalid'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState?.validate() ?? false) {
                        final raw = phoneCtrl.text.trim();
                        final normalized = raw.startsWith('+91')
                            ? raw
                            : '+91$raw';
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .update({'phoneNumber': normalized});
                        } catch (_) {}
                        if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'profile_updated_toast'.tr(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'save_phone_number'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerMetricStatsRow({
    required int totalBookings,
    required int savingsAmount,
    required int addressCount,
    required int prosCount,
  }) {
    return Row(
      children: [
        // 1. Total Orders
        Expanded(
          child: _metricStatTile(
            bg: const Color(0xFFEFF6FF),
            label: "stat_total_orders".tr(),
            value: "$totalBookings",
            icon: Icons.receipt_long_rounded,
            accent: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 10),

        // 2. Co-op Savings (₹)
        Expanded(
          child: _metricStatTile(
            bg: const Color(0xFFECFDF5),
            label: "stat_coop_saved".tr(),
            value: "₹$savingsAmount",
            icon: Icons.savings_rounded,
            accent: const Color(0xFF059669),
          ),
        ),
        const SizedBox(width: 10),

        // 3. Saved Addresses
        Expanded(
          child: _metricStatTile(
            bg: const Color(0xFFFFFBEB),
            label: "stat_addresses".tr(),
            value: "$addressCount",
            icon: Icons.location_on_rounded,
            accent: const Color(0xFFD97706),
          ),
        ),
      ],
    );
  }

  Widget _metricStatTile({
    required Color bg,
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: WorkGoFonts.heading(
              color: const Color(0xFF141416),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: accent.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerMenuMatrix({
    required UserAddress? defaultAddr,
    required int addressCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Saved Addresses
          _menuRowItem(
            icon: Icons.bookmark_rounded,
            iconColor: const Color(0xFFD97706),
            title: "menu_saved_addresses".tr(),
            subtitle: defaultAddr != null
                ? "${defaultAddr.displayTitle} ($addressCount)"
                : "menu_saved_addresses_sub".tr(),
            onTap: () => showAddressManagementSheet(
              context,
              userId: widget.user.uid,
              userRole: "customer",
              selectedAddress: defaultAddr,
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // 2. Payment Methods & Safety Escrow
          _menuRowItem(
            icon: Icons.lock_clock_rounded,
            iconColor: const Color(0xFF059669),
            title: "menu_payments_escrow".tr(),
            subtitle: "menu_payments_escrow_sub".tr(),
            onTap: () => _showSafetyGuaranteeSheet(context),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // 3. Co-op Safety & ₹50k Insurance
          _menuRowItem(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF6366F1),
            title: "menu_safety_insurance".tr(),
            subtitle: "menu_safety_insurance_sub".tr(),
            onTap: () => _showSafetyGuaranteeSheet(context),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // 4. Preferred Language Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.translate_rounded,
                    color: Color(0xFF2563EB),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    "menu_app_language".tr(),
                    style: const TextStyle(
                      color: Color(0xFF141416),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildLangPill(context),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // 6. 24/7 Helpline & Support Desk
          _menuRowItem(
            icon: Icons.support_agent_rounded,
            iconColor: const Color(0xFF2563EB),
            title: "menu_helpline".tr(),
            subtitle: "menu_helpline_sub".tr(),
            onTap: () => _showHelplineDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _menuRowItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF141416),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1.5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
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
              color: Color(0xFF9CA3AF),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  LANGUAGE PILL
  // ──────────────────────────────────────────
  Widget _buildLangPill(BuildContext context) {
    final currentLang = context.locale.languageCode;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: CX.glassCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CX.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langOption(context, "en", "EN", currentLang == "en"),
          _langOption(context, "hi", "HI", currentLang == "hi"),
          _langOption(context, "ta", "TA", currentLang == "ta"),
        ],
      ),
    );
  }

  Widget _langOption(
    BuildContext context,
    String code,
    String label,
    bool active,
  ) {
    return GestureDetector(
      onTap: () => context.setLocale(Locale(code)),
      child: AnimatedContainer(
        duration: CAnim.fast,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          gradient: active ? CX.auroraVioletCyan : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : CX.textMuted,
            fontSize: 11,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCoopImpactCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.handshake_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "coop_patron_advantage".tr(),
                  style: const TextStyle(
                    color: Color(0xFF065F46),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  "coop_patron_advantage_desc".tr(),
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  PULSING EMERGENCY BANNER
// ──────────────────────────────────────────────────────
class _PulsingEmergencyBanner extends StatefulWidget {
  const _PulsingEmergencyBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PulsingEmergencyBanner> createState() =>
      _PulsingEmergencyBannerState();
}

class _PulsingEmergencyBannerState extends State<_PulsingEmergencyBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      onTap: widget.onTap,
      glowColor: CX.rose,
      borderColor: const Color(0xFFFECDD3),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6), Color(0xFFFEE2E2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          // Pulsing bolt orb
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE11D48),
                boxShadow: [
                  BoxShadow(
                    color: CX.rose.withValues(alpha: _pulse.value * 0.6),
                    blurRadius: 20 * _pulse.value,
                    spreadRadius: 2 * _pulse.value,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'emergency_booking'.tr(),
                        style: WorkGoFonts.display(
                          color: const Color(0xFF9F1239),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const AuroraBadge(
                      label: "≤30 MIN",
                      style: AuroraBadgeStyle.rose,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'emergency_subtitle'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF881337),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE11D48).withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF9F1239),
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
//  HAND-DRAWN SCRIBBLE LOOP PAINTER
//  Mirrors authentic marker loop stroke from reference design (media_1789322811943.png)
// ──────────────────────────────────────────
class _HandDrawnLoopPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _HandDrawnLoopPainter({
    this.color = const Color(0xFF141416),
    this.strokeWidth = 2.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Traced directly from hand-drawn pen marker reference (media_1789322811943.png):
    // Starts at top-left (~11 o'clock), curves down around left side, sweeps under baseline,
    // loops up past right edge, curves over top, and overlaps across start point with a loose pen stroke flick.
    path.moveTo(w * 0.18, h * 0.08);

    // Left edge swooping down with organic hand-drawn curve
    path.cubicTo(w * 0.02, h * 0.22, -w * 0.06, h * 0.72, w * 0.14, h * 0.94);

    // Bottom edge curving under text
    path.cubicTo(w * 0.38, h * 1.07, w * 0.72, h * 1.05, w * 0.92, h * 0.88);

    // Right edge swooping up
    path.cubicTo(w * 1.06, h * 0.68, w * 1.05, h * 0.22, w * 0.84, h * 0.06);

    // Top edge sweeping back left over text
    path.cubicTo(w * 0.65, -h * 0.05, w * 0.35, -h * 0.06, w * 0.12, h * 0.06);

    // Natural overlapping marker stroke tail
    path.cubicTo(w * 0.01, h * 0.12, w * 0.06, h * 0.22, w * 0.28, h * 0.17);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HandDrawnLoopPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

// ──────────────────────────────────────────────────────
//  MASONRY STAGGERED CRAFT CARD (Pinterest / Dribbble Inspiration)
// ──────────────────────────────────────────────────────
class _CraftServiceItem {
  final String key;
  final String name;
  final String categoryName;
  final String tagline;
  final String taglineKey;
  final String description;
  final IconData icon;
  final String assetPath;
  final bool isAnimatedAsset;
  final String price;
  final int priceAmount;
  final Color meshColor1;
  final Color meshColor2;

  const _CraftServiceItem({
    required this.key,
    required this.name,
    required this.categoryName,
    required this.tagline,
    required this.taglineKey,
    required this.description,
    required this.icon,
    required this.assetPath,
    this.isAnimatedAsset = false,
    required this.price,
    required this.priceAmount,
    required this.meshColor1,
    required this.meshColor2,
  });
}

class _BlueprintGridPainter extends CustomPainter {
  const _BlueprintGridPainter({this.lineColor = const Color(0x60FFFFFF)});
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const cellSize = 22.0;
    for (double x = size.width; x >= 0; x -= cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintGridPainter oldDelegate) => false;
}

// ──────────────────────────────────────────────────────
//  TASKELLO-STYLE ASYMMETRICAL FOLDER TAB CLIPPER & PAINTER
// ──────────────────────────────────────────────────────
class _FolderTabClipper extends CustomClipper<Path> {
  final bool isLeftTab;
  final double tabHeightDelta;
  final double tabWidthFactor;
  final double cornerRadius;

  const _FolderTabClipper({
    this.isLeftTab = true,
    this.tabHeightDelta = 18.0,
    this.tabWidthFactor = 0.52,
    this.cornerRadius = 20.0,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final deltaH = tabHeightDelta;

    if (isLeftTab) {
      final tabEndX = w * tabWidthFactor;
      path.moveTo(0, h - r);
      path.lineTo(0, r);
      path.quadraticBezierTo(0, 0, r, 0);
      path.lineTo(tabEndX - 14, 0);
      path.cubicTo(
        tabEndX - 3,
        0,
        tabEndX,
        deltaH * 0.4,
        tabEndX + 6,
        deltaH * 0.7,
      );
      path.cubicTo(
        tabEndX + 11,
        deltaH,
        tabEndX + 16,
        deltaH,
        tabEndX + 24,
        deltaH,
      );
      path.lineTo(w - r, deltaH);
      path.quadraticBezierTo(w, deltaH, w, deltaH + r);
      path.lineTo(w, h - r);
      path.quadraticBezierTo(w, h, w - r, h);
      path.lineTo(r, h);
      path.quadraticBezierTo(0, h, 0, h - r);
    } else {
      final shelfEndX = w * (1.0 - tabWidthFactor);
      path.moveTo(0, h - r);
      path.lineTo(0, deltaH + r);
      path.quadraticBezierTo(0, deltaH, r, deltaH);
      path.lineTo(shelfEndX - 24, deltaH);
      path.cubicTo(
        shelfEndX - 16,
        deltaH,
        shelfEndX - 11,
        deltaH,
        shelfEndX - 6,
        deltaH * 0.7,
      );
      path.cubicTo(
        shelfEndX,
        deltaH * 0.4,
        shelfEndX + 3,
        0,
        shelfEndX + 14,
        0,
      );
      path.lineTo(w - r, 0);
      path.quadraticBezierTo(w, 0, w, r);
      path.lineTo(w, h - r);
      path.quadraticBezierTo(w, h, w - r, h);
      path.lineTo(r, h);
      path.quadraticBezierTo(0, h, 0, h - r);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _FolderTabClipper oldClipper) =>
      oldClipper.isLeftTab != isLeftTab ||
      oldClipper.tabHeightDelta != tabHeightDelta ||
      oldClipper.tabWidthFactor != tabWidthFactor;
}

class _FolderTabBorderPainter extends CustomPainter {
  final bool isLeftTab;
  final double tabHeightDelta;
  final double tabWidthFactor;
  final double cornerRadius;

  const _FolderTabBorderPainter({
    this.isLeftTab = true,
    this.tabHeightDelta = 18.0,
    this.tabWidthFactor = 0.52,
    this.cornerRadius = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = cornerRadius;
    final deltaH = tabHeightDelta;
    final strokePath = Path();

    if (isLeftTab) {
      final tabEndX = w * tabWidthFactor;
      strokePath.moveTo(0, r + 4);
      strokePath.quadraticBezierTo(0, 0, r, 0);
      strokePath.lineTo(tabEndX - 14, 0);
      strokePath.cubicTo(
        tabEndX - 3,
        0,
        tabEndX,
        deltaH * 0.4,
        tabEndX + 6,
        deltaH * 0.7,
      );
      strokePath.cubicTo(
        tabEndX + 11,
        deltaH,
        tabEndX + 16,
        deltaH,
        tabEndX + 24,
        deltaH,
      );
      strokePath.lineTo(w - r, deltaH);
      strokePath.quadraticBezierTo(w, deltaH, w, deltaH + r + 4);
    } else {
      final shelfEndX = w * (1.0 - tabWidthFactor);
      strokePath.moveTo(0, deltaH + r + 4);
      strokePath.quadraticBezierTo(0, deltaH, r, deltaH);
      strokePath.lineTo(shelfEndX - 24, deltaH);
      strokePath.cubicTo(
        shelfEndX - 16,
        deltaH,
        shelfEndX - 11,
        deltaH,
        shelfEndX - 6,
        deltaH * 0.7,
      );
      strokePath.cubicTo(
        shelfEndX,
        deltaH * 0.4,
        shelfEndX + 3,
        0,
        shelfEndX + 14,
        0,
      );
      strokePath.lineTo(w - r, 0);
      strokePath.quadraticBezierTo(w, 0, w, r + 4);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFFDE68A),
          Color(0xFFF59E0B),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(strokePath, paint);
  }

  @override
  bool shouldRepaint(covariant _FolderTabBorderPainter oldDelegate) =>
      oldDelegate.isLeftTab != isLeftTab ||
      oldDelegate.tabHeightDelta != tabHeightDelta;
}

class _AlternatingCraftRowCard extends StatefulWidget {
  const _AlternatingCraftRowCard({
    required this.item,
    required this.index,
    required this.onTap,
  });

  final _CraftServiceItem item;
  final int index;
  final VoidCallback onTap;

  @override
  State<_AlternatingCraftRowCard> createState() =>
      _AlternatingCraftRowCardState();
}

class _AlternatingCraftRowCardState extends State<_AlternatingCraftRowCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isEven = widget.index % 2 == 0;
    final localizedName = item.key.tr();
    final displayName = (localizedName.isNotEmpty && localizedName != item.key)
        ? localizedName
        : item.name;
    final localizedTagline = item.taglineKey.tr();
    final displayTagline =
        (localizedTagline.isNotEmpty && localizedTagline != item.taglineKey)
            ? localizedTagline
            : item.tagline;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          height: 235,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Color(0x14F59E0B),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22.6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. 3/4 Visual Zone (Top 73% height = 172px of 235px total)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 172,
                  child: _buildVisualZone(item, isEven: isEven),
                ),

                // 2. Floating Exposed Media Badge (Top shelf side)
                Positioned(
                  top: 10,
                  right: isEven ? 10 : null,
                  left: isEven ? null : 10,
                  child: _buildExposedMediaBadge(displayName, item.icon),
                ),

                // 3. Taskello-Style Folder Tab Overlay (White to Yellow Gradient)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 98,
                  child: ClipPath(
                    clipper: _FolderTabClipper(
                      isLeftTab: isEven,
                      tabHeightDelta: 18.0,
                      cornerRadius: 20.0,
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFFFFF), // Pure white
                            Color(0xFFFFFDF2), // Warm ivory
                            Color(0xFFFFFBEB), // Soft warm cream
                            Color(0xFFFDE68A), // Luminous gold yellow
                          ],
                          stops: [0.0, 0.25, 0.60, 1.0],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Ambient Golden Glow on elevated tab
                          Positioned(
                            top: 0,
                            left: isEven ? 0 : null,
                            right: isEven ? null : 0,
                            width: 130,
                            height: 50,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: isEven
                                        ? Alignment.topLeft
                                        : Alignment.topRight,
                                    radius: 1.1,
                                    colors: [
                                      const Color(0xFFFDE68A)
                                          .withValues(alpha: 0.35),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Metallic Golden Rim Stroke along folder cut
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _FolderTabBorderPainter(
                                isLeftTab: isEven,
                                tabHeightDelta: 18.0,
                                cornerRadius: 20.0,
                              ),
                            ),
                          ),

                          // Content within the tab
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Top: Title + Category Tagline
                                _buildTabHeader(
                                  displayName,
                                  displayTagline,
                                  item,
                                  isEven: isEven,
                                ),

                                // Bottom: Price Pill + Tactile Liquid-Gold Action Button
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildPricePill(item),
                                    _buildLaunchButton(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualZone(_CraftServiceItem item, {required bool isEven}) {
    if (item.assetPath.isNotEmpty) {
      return ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.black,
              Color(0xB0000000),
              Colors.transparent,
            ],
            stops: [0.0, 0.65, 0.85, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: Image.asset(
          item.assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) =>
              _buildFallbackVisual(item, isEven: isEven),
        ),
      );
    }

    return _buildFallbackVisual(item, isEven: isEven);
  }

  Widget _buildFallbackVisual(_CraftServiceItem item, {required bool isEven}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isEven
                  ? [
                      item.meshColor1,
                      item.meshColor2,
                      item.meshColor1.withValues(alpha: 0.45),
                    ]
                  : [
                      item.meshColor2,
                      item.meshColor1,
                      item.meshColor2.withValues(alpha: 0.45),
                    ],
              stops: const [0.0, 0.65, 1.0],
              begin: isEven ? Alignment.topLeft : Alignment.topRight,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.70),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: item.meshColor1.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                item.icon,
                size: 28,
                color: const Color(0xFFD97706),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExposedMediaBadge(String displayName, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFFD97706)),
          const SizedBox(width: 4),
          Text(
            displayName,
            style: const TextStyle(
              color: Color(0xFF141416),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 3.5,
            height: 3.5,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3.5),
          const Text(
            "Active Pro",
            style: TextStyle(
              color: Color(0xFF059669),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader(
    String displayName,
    String displayTagline,
    _CraftServiceItem item, {
    required bool isEven,
  }) {
    final iconOrb = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Icon(item.icon, size: 15, color: const Color(0xFFD97706)),
      ),
    );

    final titles = Column(
      crossAxisAlignment:
          isEven ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayName,
          style: const TextStyle(
            color: Color(0xFF141416),
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            height: 1.15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          displayTagline,
          style: const TextStyle(
            color: Color(0xFF92400E),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (isEven) {
      return Row(
        children: [
          iconOrb,
          const SizedBox(width: 8),
          Expanded(child: titles),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: titles),
          const SizedBox(width: 8),
          iconOrb,
        ],
      );
    }
  }

  Widget _buildPricePill(_CraftServiceItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 12,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 2.5),
          const Text(
            "15M",
            style: TextStyle(
              color: Color(0xFF141416),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 2.5,
            height: 2.5,
            decoration: const BoxDecoration(
              color: Color(0xFFD97706),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            "From ₹${item.priceAmount}",
            style: const TextStyle(
              color: Color(0xFFD97706),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaunchButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x25D97706),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "book_now".tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 11,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

typedef _MasonryCraftCard = _AlternatingCraftRowCard;

// ──────────────────────────────────────────────────────
//  QUICK SOLUTION CHIP (1-Tap Horizontal Rail)
// ──────────────────────────────────────────────────────
class _QuickSolutionChip extends StatefulWidget {
  const _QuickSolutionChip({
    required this.icon,
    required this.title,
    required this.price,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String price;
  final VoidCallback onTap;

  @override
  State<_QuickSolutionChip> createState() => _QuickSolutionChipState();
}

class _QuickSolutionChipState extends State<_QuickSolutionChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF0EDE6), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 7),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Color(0xFF141416),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.price,
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  ARTISAN SPOTLIGHT CARD (Nearby Co-op Stars)
// ──────────────────────────────────────────────────────
class _ArtisanSpotlightCard extends StatelessWidget {
  const _ArtisanSpotlightCard({
    required this.worker,
    required this.onTap,
    this.customerLat,
    this.customerLng,
  });
  final Worker worker;
  final VoidCallback onTap;
  final double? customerLat;
  final double? customerLng;

  @override
  Widget build(BuildContext context) {
    final trade = worker.skills.isNotEmpty ? worker.skills.first : "Artisan";
    final style = categoryStyle(trade);
    final distanceText = worker.formattedDistanceString(
      customerLat,
      customerLng,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                WorkGoAvatar(
                  name: worker.name.isNotEmpty ? worker.name : "Artisan",
                  avatarBase64: worker.avatarBase64,
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: TranslatedText(
                              worker.name.isNotEmpty
                                  ? worker.name
                                  : "artisan".trSafe("Artisan"),
                              style: WorkGoFonts.heading(
                                color: const Color(0xFF141416),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF10B981),
                            size: 14,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: worker.isOnlineOrCheckedIn
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: worker.isOnlineOrCheckedIn
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFFCBD5E1),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5.5,
                                    height: 5.5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: worker.isOnlineOrCheckedIn
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(width: 3.5),
                                  Flexible(
                                    child: Text(
                                      worker.isOnlineOrCheckedIn
                                          ? "checked_in".tr()
                                          : "checked_out".tr(),
                                      style: TextStyle(
                                        color: worker.isOnlineOrCheckedIn
                                            ? const Color(0xFF065F46)
                                            : const Color(0xFF475569),
                                        fontSize: 9,
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
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              trade.toLocalizedTrade(),
                              style: TextStyle(
                                color:
                                    style.accentColor ??
                                    const Color(0xFF2563EB),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF59E0B),
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        worker.avgRating > 0
                            ? worker.avgRating.toStringAsFixed(1)
                            : (worker.totalRatings > 0
                                  ? "5.0"
                                  : 'badge_new'.trSafe("New")),
                        style: const TextStyle(
                          color: Color(0xFF141416),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (worker.totalReviews > 0 || worker.totalRatings > 0)
                        Text(
                          " (${worker.totalReviews > 0 ? worker.totalReviews : worker.totalRatings})",
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    worker.homesServiced > 0
                        ? "🏡 ${worker.homesServiced} homes"
                        : (worker.totalRatings > 0
                              ? "🏡 ${worker.totalRatings} jobs"
                              : "🌟 ${"verified_pro".tr()}"),
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "📍 $distanceText",
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "book_action".tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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
    );
  }
}

// ──────────────────────────────────────────────────────
//  BOOKING LIST TILE — BIGSHOT BENTO CARD
// ──────────────────────────────────────────────────────
class _BookingListTile extends StatelessWidget {
  const _BookingListTile({
    required this.booking,
    required this.onTap,
    this.onBookAgain,
    this.onDelete,
  });

  final Booking booking;
  final VoidCallback onTap;
  final VoidCallback? onBookAgain;
  final VoidCallback? onDelete;

  AuroraBadgeStyle get _badgeStyle => switch (booking.status) {
    BookingStatus.completed => AuroraBadgeStyle.emerald,
    BookingStatus.paymentPending => AuroraBadgeStyle.amber,
    BookingStatus.inProgress => AuroraBadgeStyle.amber,
    BookingStatus.accepted => AuroraBadgeStyle.cyan,
    BookingStatus.cancelled => AuroraBadgeStyle.rose,
    _ => AuroraBadgeStyle.violet,
  };

  @override
  Widget build(BuildContext context) {
    final style = categoryStyle(booking.serviceType);
    final isPaymentPending = booking.status == BookingStatus.paymentPending;
    final isLive =
        booking.status == BookingStatus.inProgress ||
        booking.status == BookingStatus.accepted;
    final isPending = booking.status == BookingStatus.pending;
    final isCompleted = booking.status == BookingStatus.completed;

    String dateStr = "Recently";
    if (booking.scheduledAt != null) {
      final dt = booking.scheduledAt!;
      final now = DateTime.now();
      final isToday =
          dt.year == now.year && dt.month == now.month && dt.day == now.day;
      final timeStr =
          "${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
      dateStr = isToday
          ? "Today, $timeStr"
          : "${dt.day}/${dt.month} · $timeStr";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLive ? const Color(0xFFF59E0B) : const Color(0xFFF0EDE6),
          width: isLive ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isLive ? const Color(0x14F59E0B) : const Color(0x06000000),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Top Header Row: Orb + Title/Emergency + Status Badge ──
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: style.gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (style.accentColor ?? const Color(0xFF2563EB))
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(style.icon, color: Colors.white, size: 22),
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
                            booking.serviceType.toLocalizedTrade(),
                            style: const TextStyle(
                              color: Color(0xFF141416),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (booking.isEmergency) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "🚨 SOS",
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: AuroraBadge(
                        label: booking.status.toLocalizedName().toUpperCase(),
                        style: _badgeStyle,
                      ),
                    ),
                    if (onDelete != null &&
                        (isCompleted ||
                            booking.status == BookingStatus.cancelled)) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Color(0xFF9CA3AF),
                        ),
                        tooltip: "remove_from_history".tr(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: onDelete,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── 2. Artisan / Dispatch Info Strip ───────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: StreamBuilder<Worker?>(
              stream: (booking.workerId != null && booking.workerId!.isNotEmpty)
                  ? WorkerService().streamWorker(booking.workerId!)
                  : Stream.value(null),
              builder: (context, snap) {
                final worker = snap.data;
                String cleanName =
                    (booking.acceptedWorkerName != null &&
                        booking.acceptedWorkerName!.trim().isNotEmpty &&
                        booking.acceptedWorkerName!.toLowerCase() !=
                            'artisan' &&
                        booking.acceptedWorkerName!.toLowerCase() !=
                            'partner' &&
                        booking.acceptedWorkerName!.toLowerCase() != 'worker' &&
                        booking.acceptedWorkerName!.toLowerCase() != 'artisian')
                    ? booking.acceptedWorkerName!.trim()
                    : (worker?.name.isNotEmpty == true ? worker!.name : "");

                if (cleanName.isNotEmpty) {
                  return Row(
                    children: [
                      WorkGoAvatar(
                        name: cleanName,
                        avatarBase64: worker?.avatarBase64,
                        radius: 12,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TranslatedText(
                          cleanName,
                          style: const TextStyle(
                            color: Color(0xFF141416),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "verified_pro".tr(),
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                if (isPending) {
                  return Row(
                    children: [
                      const PulsingDot(color: Color(0xFFD97706), size: 7),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "broadcasting_specialists".tr(
                            args: [
                              booking.broadcastRadiusKm.toInt().toString(),
                            ],
                          ),
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF10B981),
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${booking.serviceType.toLocalizedTrade()} ${"specialist_assigned".tr()}",
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ── 3. Price & Action Button Strip ─────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "total_amount".tr(),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Text(
                          "₹${booking.totalAmount.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: Color(0xFF141416),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: booking.paymentStatus == PaymentStatus.paid
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              booking.paymentStatus
                                  .toLocalizedName()
                                  .toUpperCase(),
                              style: TextStyle(
                                color:
                                    booking.paymentStatus == PaymentStatus.paid
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF6B7280),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (isCompleted &&
                            (booking.isRated || booking.rating != null)) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFFDE68A),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFD97706),
                                    size: 11,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      booking.rating != null
                                          ? "${booking.rating!.toStringAsFixed(1)} ${'rated_badge_label'.tr().toUpperCase()}"
                                          : "rated_badge_label"
                                                .tr()
                                                .toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 9.5,
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
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              if (isPaymentPending)
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final receiptWorker =
                          booking.genuineArtisanName ??
                          (!Booking.isGenericArtisanName(
                                booking.acceptedWorkerName,
                              )
                              ? booking.acceptedWorkerName!
                              : "");
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PaymentReceiptScreen(
                            booking: booking,
                            workerName: receiptWorker.isNotEmpty
                                ? receiptWorker
                                : "Cooperative Artisan",
                            isReceiptOnly: false,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.payment_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    label: Text(
                      "${'pay_now'.tr()} • ₹${booking.totalAmount.toStringAsFixed(0)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else if (isLive || isPending)
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(
                      Icons.radar_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    label: Text(
                      "track_live".tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF141416),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else if (isCompleted)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // If unrated and paid, offer quick-action Rate button
                      if (booking.paymentStatus == PaymentStatus.paid &&
                          !booking.isRated &&
                          booking.rating == null) ...[
                        Flexible(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              final receiptWorker =
                                  booking.genuineArtisanName ??
                                  (!Booking.isGenericArtisanName(
                                        booking.acceptedWorkerName,
                                      )
                                      ? booking.acceptedWorkerName!
                                      : "");
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RatingReviewScreen(
                                    booking: booking,
                                    workerName: receiptWorker.isNotEmpty
                                        ? receiptWorker
                                        : "Cooperative Artisan",
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFD97706),
                              size: 13,
                            ),
                            label: Text(
                              "rate_service".tr(),
                              style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFDE68A)),
                              backgroundColor: const Color(0xFFFFFBEB),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              minimumSize: const Size(0, 34),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],

                      // Invoice & Receipt Button (Only for paid bookings)
                      if (booking.paymentStatus == PaymentStatus.paid)
                        Flexible(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              final receiptWorker =
                                  booking.genuineArtisanName ??
                                  (!Booking.isGenericArtisanName(
                                        booking.acceptedWorkerName,
                                      )
                                      ? booking.acceptedWorkerName!
                                      : "");
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PaymentReceiptScreen(
                                    booking: booking,
                                    workerName: receiptWorker.isNotEmpty
                                        ? receiptWorker
                                        : "Cooperative Artisan",
                                    isReceiptOnly: true,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.receipt_long_rounded,
                              color: Color(0xFF2563EB),
                              size: 13,
                            ),
                            label: Text(
                              "receipt".tr(),
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              backgroundColor: const Color(0xFFEFF6FF),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              minimumSize: const Size(0, 34),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      if (onBookAgain != null) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: ElevatedButton.icon(
                            onPressed: onBookAgain,
                            icon: const Icon(
                              Icons.replay_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            label: Text(
                              "book_again".tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF141416),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              minimumSize: const Size(0, 34),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
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

// ──────────────────────────────────────────────────────
//  CUSTOMER STOPWATCH BADGE (Live Service Progress)
// ──────────────────────────────────────────────────────
class _CustomerStopwatchBadge extends StatefulWidget {
  const _CustomerStopwatchBadge({this.startedAt});
  final DateTime? startedAt;

  @override
  State<_CustomerStopwatchBadge> createState() =>
      _CustomerStopwatchBadgeState();
}

class _CustomerStopwatchBadgeState extends State<_CustomerStopwatchBadge> {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.handyman_rounded,
            color: Color(0xFF34D399),
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            "working_timer_label".tr(),
            style: const TextStyle(
              color: Color(0xFF6EE7B7),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            formatted,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
