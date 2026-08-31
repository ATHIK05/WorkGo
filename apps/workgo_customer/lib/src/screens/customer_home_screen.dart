import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
import 'booking_creation_screen.dart';
import 'live_booking_tracker_screen.dart';
import 'worker_search_screen.dart';

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
  static bool _hasPromptedThisSession = false;

  final List<Map<String, dynamic>> _categories = [
    {"name": "Plumbing", "key": "cat_plumbing"},
    {"name": "Electrical", "key": "cat_electrical"},
    {"name": "Carpentry", "key": "cat_carpentry"},
    {"name": "Cleaning", "key": "cat_cleaning"},
    {"name": "Painting", "key": "cat_painting"},
    {"name": "Appliance Repair", "key": "cat_appliance"},
    {"name": "Masonry", "key": "cat_masonry"},
    {"name": "Gardening", "key": "cat_gardening"},
  ];

  @override
  void initState() {
    super.initState();
    _navIndicatorCtrl = AnimationController(
      vsync: this,
      duration: CAnim.normal,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptLocation();
    });
  }

  Future<void> _checkAndPromptLocation() async {
    if (_hasPromptedThisSession) return;
    _hasPromptedThisSession = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyConfigured = prefs.getBool("customer_loc_done_${widget.user.uid}") ?? false;
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

      final hasLocation = addrSnap.docs.isNotEmpty || currentAddress != null || lat != null;

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
        bottomNavigationBar: _buildFloatingNav(),
        body: AnimatedSwitcher(
          duration: CAnim.normal,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(
            key: ValueKey(_currentNavIndex),
            child: switch (_currentNavIndex) {
              0 => _buildHomeFeed(context),
              1 => WorkerSearchScreen(customerId: widget.user.uid),
              2 => _buildMyBookingsTab(context),
              3 => _buildProfileTab(context),
              _ => _buildHomeFeed(context),
            },
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  FLOATING GLASS NAV BAR
  // ──────────────────────────────────────────
  Widget _buildFloatingNav() {
    final items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.search_rounded, Icons.search_rounded, 'search_workers'),
      (Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'my_bookings'),
      (Icons.person_rounded, Icons.person_outline_rounded, 'profile'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: CX.canvasCard.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: CX.glassBorderBright, width: 1.2),
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final isActive = _currentNavIndex == i;
              final item = items[i];
              final labelKey = item.$3;
              final label = labelKey == 'Home'
                  ? 'Home'
                  : labelKey == 'search_workers'
                  ? 'search_workers'.tr()
                  : labelKey == 'my_bookings'
                  ? 'my_bookings'.tr()
                  : 'profile'.tr();

              return Expanded(
                child: GestureDetector(
                  onTap: () => _onNavTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: CAnim.normal,
                    curve: Curves.easeOutCubic,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: CAnim.fast,
                          child: Icon(
                            isActive ? item.$1 : item.$2,
                            key: ValueKey(isActive),
                            size: 22,
                            color: isActive ? CX.amber : CX.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: CAnim.fast,
                          style: TextStyle(
                            color: isActive ? CX.amber : CX.textMuted,
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AnimatedContainer(
                          duration: CAnim.normal,
                          curve: Curves.easeOutCubic,
                          width: isActive ? 18 : 0,
                          height: 3,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: isActive ? CX.amber : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
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
      ),
    );
  }

  // ──────────────────────────────────────────
  //  HOME FEED — Swiggy / Rapido Style Bento Experience
  // ──────────────────────────────────────────
  Widget _buildHomeFeed(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Row (Greeting + Active Delivery Location + Lang)
            SlideFadeIn(child: _buildHeader()),
            const SizedBox(height: 16),

            // 2. Interactive Quick Search Bar (Swiggy / Blinkit style)
            SlideFadeIn(
              delay: const Duration(milliseconds: 30),
              child: _buildQuickSearchBar(),
            ),
            const SizedBox(height: 18),

            // 3. Instant 1-Tap Problem Fixes Rail
            SlideFadeIn(
              delay: const Duration(milliseconds: 60),
              child: _buildInstantSolutionsRail(),
            ),
            const SizedBox(height: 20),

            // 4. Kinetic Hero Bento Spotlight Deck (SOS Emergency + Titans Radar)
            SlideFadeIn(
              delay: const Duration(milliseconds: 90),
              child: _buildHeroBentoSpotlight(),
            ),
            const SizedBox(height: 18),

            // 5. Active Booking Pill (stream-driven)
            _buildActiveBookingsStream(),

            // 6. Section Header: Explore Craft Services
            SlideFadeIn(
              delay: const Duration(milliseconds: 120),
              child: _buildSectionHeader(
                title: "Explore Craft Services",
                actionLabel: "View All (8)",
                onAction: () => setState(() => _currentNavIndex = 1),
              ),
            ),
            const SizedBox(height: 14),

            // 7. World-Class Bento Category Grid (Rich Visual Depth)
            SlideFadeIn(
              delay: const Duration(milliseconds: 150),
              child: _buildCategoryBentoGrid(),
            ),
            const SizedBox(height: 24),

            // 8. Top Verified Artisans Spotlight Carousel
            SlideFadeIn(
              delay: const Duration(milliseconds: 180),
              child: _buildTopArtisansSpotlight(),
            ),
            const SizedBox(height: 24),

            // 9. Cooperative Advantage Trust & Proxy Referral
            SlideFadeIn(
              delay: const Duration(milliseconds: 210),
              child: _buildProxyBanner(),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
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
                "Profile photo updated successfully!",
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

  Widget _buildHeader() {
    final name = widget.user.displayName.isNotEmpty
        ? widget.user.displayName.split(' ').first
        : widget.user.email.split('@').first;

    return StreamBuilder<AppUser?>(
      stream: _authService.streamAppUser(widget.user.uid),
      initialData: widget.user,
      builder: (context, snap) {
        final liveUser = snap.data ?? widget.user;
        final activeAddr = liveUser.currentAddress;
        final areaLabel = activeAddr != null
            ? "${activeAddr.displayTitle} · ${activeAddr.shortSummary}"
            : (liveUser.primaryArea ?? "Select Service Address");

        return Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _currentNavIndex = 3),
              child: WorkGoAvatar(
                avatarBase64: liveUser.avatarBase64,
                name: name,
                radius: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${_getGreeting()}, $name",
                    style: const TextStyle(
                      color: CX.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Swiggy / Zomato style address picker bar
                  GestureDetector(
                    onTap: () => showAddressManagementSheet(
                      context,
                      userId: widget.user.uid,
                      userRole: "customer",
                      selectedAddress: activeAddr,
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Icon(
                          activeAddr?.label.icon ?? Icons.location_on_rounded,
                          size: 13,
                          color: CX.amber,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            areaLabel,
                            style: const TextStyle(
                              color: CX.amber,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 15,
                          color: CX.amber,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildLanguagePill(context),
          ],
        );
      },
    );
  }

  Widget _buildLanguagePill(BuildContext context) {
    final currentLang = context.locale.languageCode;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: CX.canvasCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CX.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langPill(context, "en", "EN", currentLang == "en"),
          _langPill(context, "hi", "HI", currentLang == "hi"),
          _langPill(context, "ta", "TA", currentLang == "ta"),
        ],
      ),
    );
  }

  Widget _langPill(BuildContext ctx, String code, String label, bool active) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ctx.setLocale(Locale(code));
      },
      child: AnimatedContainer(
        duration: CAnim.fast,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          gradient: active ? CX.auroraVioletCyan : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : CX.textMuted,
            fontSize: 9.5,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: WorkGoFonts.display(
            color: CX.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: CX.violet.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: CX.violetLight.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: CX.violetLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //  QUICK SEARCH BAR (Swiggy / Blinkit Style)
  // ──────────────────────────────────────────
  Widget _buildQuickSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => WorkerSearchScreen(customerId: widget.user.uid),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: CX.canvasCard.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CX.glassBorderBright, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: CX.auroraVioletCyan,
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Search 'Leak repair', 'AC service', 'Carpenter'...",
                style: TextStyle(
                  color: CX.textSecondary.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: CX.violet.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CX.violetLight.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.mic_none_rounded, color: CX.violetLight, size: 14),
                  SizedBox(width: 4),
                  Text(
                    "Voice",
                    style: TextStyle(
                      color: CX.violetLight,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  INSTANT 1-TAP PROBLEM FIXES RAIL
  // ──────────────────────────────────────────
  Widget _buildInstantSolutionsRail() {
    final quickPills = [
      {
        "icon": "🚰",
        "title": "Tap Leakage",
        "category": "Plumbing",
        "price": "₹149",
      },
      {
        "icon": "💡",
        "title": "Switch Spark",
        "category": "Electrical",
        "price": "₹149",
      },
      {
        "icon": "🚪",
        "title": "Door Lock Jam",
        "category": "Carpentry",
        "price": "₹199",
      },
      {
        "icon": "❄️",
        "title": "AC Not Cooling",
        "category": "Appliance Repair",
        "price": "₹249",
      },
      {
        "icon": "🧹",
        "title": "Kitchen Deep Clean",
        "category": "Cleaning",
        "price": "₹299",
      },
      {
        "icon": "⚡",
        "title": "Fan Regulator",
        "category": "Electrical",
        "price": "₹149",
      },
      {
        "icon": "🚿",
        "title": "Shower Drain Clog",
        "category": "Plumbing",
        "price": "₹149",
      },
      {
        "icon": "🪴",
        "title": "Lawn Trimming",
        "category": "Gardening",
        "price": "₹199",
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flash_on_rounded, color: CX.amber, size: 18),
            const SizedBox(width: 6),
            Text(
              "Instant 1-Tap Problem Fixes",
              style: WorkGoFonts.heading(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            const Text(
              "RAPID DISPATCH",
              style: TextStyle(
                color: CX.cyanLight,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: quickPills.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final pill = quickPills[idx];
              return _QuickSolutionChip(
                icon: pill["icon"]!,
                title: pill["title"]!,
                price: pill["price"]!,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => BookingCreationScreen(
                        serviceCategory: pill["category"]!,
                        customerId: widget.user.uid,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //  HERO BENTO SPOTLIGHT (Emergency + Radar)
  // ──────────────────────────────────────────
  Widget _buildHeroBentoSpotlight() {
    return StreamBuilder<int>(
      stream: _bookingService.streamNearbyCaptainsCount("All"),
      builder: (context, capSnap) {
        final titanCount = capSnap.data ?? 0;

        return Column(
          children: [
            // 🚨 Emergency SOS Priority Rush Card
            _PulsingEmergencyBanner(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => BookingCreationScreen(
                    serviceCategory: "Plumbing",
                    customerId: widget.user.uid,
                    isEmergencyInitial: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 📡 Live Titans Radar Cockpit Strip
            GestureDetector(
              onTap: () => setState(() => _currentNavIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E1B4B),
                      const Color(0xFF0F172A),
                      CX.canvasMid,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: CX.amber.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CX.amber.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Radar sweeping orb
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: CX.auroraVioletAmber,
                        boxShadow: [
                          BoxShadow(
                            color: CX.amber.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.radar_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PulsingDot(
                                color: titanCount > 0 ? CX.emerald : CX.amber,
                                size: 8,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                titanCount > 0
                                    ? "⚡ $titanCount Titans Live In Area"
                                    : "⚡ Titans Dispatch Radar",
                                style: WorkGoFonts.heading(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "Instant 1-tap broadcast dispatch to nearest checked-in specialists",
                            style: TextStyle(
                              color: CX.textSecondary.withValues(alpha: 0.85),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CX.amber.withValues(alpha: 0.15),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: CX.amber,
                        size: 13,
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

  // ──────────────────────────────────────────
  //  BENTO CATEGORY GRID (2-Column Rich Craft Cards)
  // ──────────────────────────────────────────
  Widget _buildCategoryBentoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.14,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final cat = _categories[index];
        final style = categoryStyle(cat["name"] as String);
        return _BentoCategoryCard(
          name: (cat["key"] as String).tr(),
          style: style,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => WorkerSearchScreen(
                customerId: widget.user.uid,
                initialCategory: cat["name"] as String,
              ),
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────
  //  TOP VERIFIED ARTISANS SPOTLIGHT
  // ──────────────────────────────────────────
  Widget _buildTopArtisansSpotlight() {
    return StreamBuilder<List<Worker>>(
      stream: _workerService.streamAvailableWorkers(skill: "All"),
      builder: (context, snap) {
        final workers = snap.data ?? [];
        if (workers.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: CX.emerald,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Top Verified Artisans Near You",
                      style: WorkGoFonts.heading(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() => _currentNavIndex = 1),
                  child: Text(
                    "See All (${workers.length})",
                    style: const TextStyle(
                      color: CX.cyanLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => BookingCreationScreen(
                          serviceCategory: worker.skills.isNotEmpty
                              ? worker.skills.first
                              : "Plumbing",
                          worker: worker,
                          targetWorkerId: worker.id,
                          customerId: widget.user.uid,
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

  // ──────────────────────────────────────────
  //  COOP TRUST & PROXY REFERRAL
  // ──────────────────────────────────────────

  Widget _buildProxyBanner() {
    return AuroraCard(
      borderColor: CX.emerald.withValues(alpha: 0.35),
      glowColor: CX.emerald,
      child: Row(
        children: [
          AuroraOrb(
            icon: Icons.group_add_rounded,
            gradient: CX.auroraSuccess,
            size: 46,
            iconSize: 22,
            glowColor: CX.emerald,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'add_someone_i_know'.tr(),
                  style: const TextStyle(
                    color: CX.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Know a local artisan without a smartphone? Refer them for direct bookings!",
                  style: TextStyle(
                    color: CX.textSecondary.withValues(alpha: 0.75),
                    fontSize: 11,
                    height: 1.4,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GlowButton(
            label: "Refer",
            onPressed: () => ProxyWorkerDialog.show(
              context,
              referrerId: widget.user.uid,
              referrerRole: "customer",
            ),
            gradient: CX.auroraSuccess,
            glowColor: CX.emerald,
            height: 38,
            isFullWidth: false,
            borderRadius: 12,
            fontSize: 13,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //  ACTIVE BOOKINGS STREAM
  // ──────────────────────────────────────────
  Widget _buildActiveBookingsStream() {
    return StreamBuilder<List<Booking>>(
      stream: _bookingService.streamCustomerBookings(widget.user.uid),
      builder: (context, snapshot) {
        final bookings = (snapshot.data ?? [])
            .where(
              (b) =>
                  b.status != BookingStatus.cancelled &&
                  b.status != BookingStatus.completed,
            )
            .toList();

        if (bookings.isEmpty) return const SizedBox.shrink();

        final b = bookings.first;
        return Column(
          children: [
            _ActiveBookingPill(
              booking: b,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => LiveBookingTrackerScreen(
                    bookingId: b.id,
                    initialBooking: b,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // ──────────────────────────────────────────
  //  MY BOOKINGS TAB — BIGSHOT STANDARD
  // ──────────────────────────────────────────
  Widget _buildMyBookingsTab(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row with Title + Quick Action
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'my_bookings'.tr(),
                      style: const TextStyle(
                        color: CX.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Live GPS updates & cooperative invoices",
                      style: TextStyle(
                        color: CX.textSecondary.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() => _currentNavIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: CX.auroraVioletCyan,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: CX.violet.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 5),
                        Text(
                          "New",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Stream & Status Filter Tabs
          Expanded(
            child: StreamBuilder<List<Booking>>(
              stream: _bookingService.streamCustomerBookings(widget.user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, __) =>
                        const AuroraShimmer(height: 120, borderRadius: 20),
                  );
                }

                final allBookings = snapshot.data ?? [];

                final allCount = allBookings.length;
                final activeCount = allBookings
                    .where(
                      (b) =>
                          b.status == BookingStatus.inProgress ||
                          b.status == BookingStatus.accepted ||
                          b.status == BookingStatus.pending,
                    )
                    .length;
                final completedCount = allBookings
                    .where((b) => b.status == BookingStatus.completed)
                    .length;
                final cancelledCount = allBookings
                    .where((b) => b.status == BookingStatus.cancelled)
                    .length;

                final filteredBookings = allBookings.where((b) {
                  if (_bookingFilter == "active") {
                    return b.status == BookingStatus.inProgress ||
                        b.status == BookingStatus.accepted ||
                        b.status == BookingStatus.pending;
                  }
                  if (_bookingFilter == "completed") {
                    return b.status == BookingStatus.completed;
                  }
                  if (_bookingFilter == "cancelled") {
                    return b.status == BookingStatus.cancelled;
                  }
                  return true;
                }).toList();

                return Column(
                  children: [
                    // Segmented Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _buildBookingFilterPill("all", "🌐 All", allCount),
                          const SizedBox(width: 8),
                          _buildBookingFilterPill(
                            "active",
                            "⚡ Active",
                            activeCount,
                          ),
                          const SizedBox(width: 8),
                          _buildBookingFilterPill(
                            "completed",
                            "✅ Completed",
                            completedCount,
                          ),
                          const SizedBox(width: 8),
                          _buildBookingFilterPill(
                            "cancelled",
                            "❌ Cancelled",
                            cancelledCount,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Results or Centered Empty State
                    Expanded(
                      child: filteredBookings.isEmpty
                          ? _buildCenteredBookingsEmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                100,
                              ),
                              itemCount: filteredBookings.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final b = filteredBookings[index];
                                return SlideFadeIn(
                                  delay: Duration(milliseconds: index * 40),
                                  child: _BookingListTile(
                                    booking: b,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (ctx) =>
                                            LiveBookingTrackerScreen(
                                              bookingId: b.id,
                                              initialBooking: b,
                                            ),
                                      ),
                                    ),
                                    onBookAgain: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => BookingCreationScreen(
                                            serviceCategory: b.serviceType,
                                            customerId: widget.user.uid,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingFilterPill(String key, String label, int count) {
    final isSelected = _bookingFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _bookingFilter = key),
      child: AnimatedContainer(
        duration: CAnim.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected ? CX.auroraVioletCyan : null,
          color: isSelected ? null : CX.canvasCard.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? CX.cyan.withValues(alpha: 0.8) : CX.glassBorder,
            width: 1.1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CX.violet.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
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
                color: isSelected ? Colors.white : CX.textSecondary,
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
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    color: isSelected ? Colors.white : CX.cyanLight,
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
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Booking Orb
            AuroraOrb(
              icon: Icons.receipt_long_rounded,
              gradient: CX.auroraVioletCyan,
              size: 76,
              iconSize: 36,
              glowColor: CX.violet,
            ),
            const SizedBox(height: 18),
            Text(
              _bookingFilter == "all"
                  ? "No Bookings Yet"
                  : "No ${_bookingFilter[0].toUpperCase()}${_bookingFilter.substring(1)} Bookings",
              style: const TextStyle(
                color: CX.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Book master plumbers, electricians or carpenters on-demand with zero middleman markup.",
              style: TextStyle(
                color: CX.textSecondary.withValues(alpha: 0.8),
                fontSize: 12.5,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            // Primary Book Button
            GlowButton(
              label: "Explore Verified Artisans",
              icon: Icons.search_rounded,
              onPressed: () => setState(() => _currentNavIndex = 1),
              gradient: CX.auroraVioletCyan,
              glowColor: CX.violet,
              height: 46,
              fontSize: 14,
            ),
            const SizedBox(height: 20),

            // 1-Tap Quick Problem Solutions Rail
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Popular Instant Repairs",
                style: TextStyle(
                  color: CX.textSecondary.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickEmptyBookingChip("🚰", "Tap Leak", "Plumbing", "₹149"),
                  const SizedBox(width: 8),
                  _quickEmptyBookingChip(
                    "💡",
                    "Switch Spark",
                    "Electrical",
                    "₹149",
                  ),
                  const SizedBox(width: 8),
                  _quickEmptyBookingChip("🚪", "Lock Jam", "Carpentry", "₹199"),
                  const SizedBox(width: 8),
                  _quickEmptyBookingChip(
                    "❄️",
                    "AC Service",
                    "Appliance Repair",
                    "₹249",
                  ),
                  const SizedBox(width: 8),
                  _quickEmptyBookingChip(
                    "🧹",
                    "Deep Clean",
                    "Cleaning",
                    "₹299",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickEmptyBookingChip(
    String emoji,
    String title,
    String category,
    String price,
  ) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingCreationScreen(
            serviceCategory: category,
            customerId: widget.user.uid,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: CX.canvasCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CX.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              "$title • $price",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  PROFILE TAB
  // ──────────────────────────────────────────
  Widget _buildProfileTab(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'profile'.tr(),
              style: const TextStyle(
                color: CX.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),

            // Profile hero card
            StreamBuilder<AppUser?>(
              stream: _authService.streamAppUser(widget.user.uid),
              initialData: widget.user,
              builder: (context, snap) {
                final liveUser = snap.data ?? widget.user;
                final displayName = liveUser.displayName.isNotEmpty
                    ? liveUser.displayName
                    : "Customer";

                return AuroraCard(
                  glowColor: CX.violet,
                  borderColor: CX.violetLight.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      WorkGoAvatar(
                        avatarBase64: liveUser.avatarBase64,
                        name: displayName,
                        radius: 32,
                        onEditTap: _handleAvatarUpload,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: CX.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              liveUser.email,
                              style: TextStyle(
                                color: CX.textSecondary.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const AuroraBadge(
                              label: "VERIFIED MEMBER",
                              style: AuroraBadgeStyle.violet,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Saved Service Addresses (Swiggy / Zomato Multi-Address Management)
            StreamBuilder<List<UserAddress>>(
              stream: LocationService().streamUserAddresses(
                widget.user.uid,
                collection: "users",
              ),
              builder: (context, snapshot) {
                final addresses = snapshot.data ?? [];
                final defaultAddr = addresses.isNotEmpty
                    ? addresses.firstWhere(
                        (a) => a.isDefault,
                        orElse: () => addresses.first,
                      )
                    : null;

                return AuroraCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.bookmark_rounded,
                                color: CX.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "saved_addresses_title".trSafe(
                                  "Saved Addresses",
                                ),
                                style: const TextStyle(
                                  color: CX.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () => showAddressManagementSheet(
                              context,
                              userId: widget.user.uid,
                              userRole: "customer",
                              selectedAddress: defaultAddr,
                            ),
                            icon: const Icon(
                              Icons.settings_rounded,
                              color: CX.amber,
                              size: 14,
                            ),
                            label: Text(
                              addresses.isNotEmpty
                                  ? "Manage (${addresses.length})"
                                  : "+ Add",
                              style: WorkGoFonts.heading(
                                color: CX.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (defaultAddr != null)
                        GestureDetector(
                          onTap: () => showAddressManagementSheet(
                            context,
                            userId: widget.user.uid,
                            userRole: "customer",
                            selectedAddress: defaultAddr,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CX.canvasMid,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: CX.glassBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: CX.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    defaultAddr.label.icon,
                                    color: CX.amber,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            defaultAddr.displayTitle
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "DEFAULT",
                                              style: TextStyle(
                                                color: Color(0xFF10B981),
                                                fontSize: 8,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        defaultAddr.fullDisplayAddress,
                                        style: const TextStyle(
                                          color: CX.textSecondary,
                                          fontSize: 11,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: CX.textSecondary,
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () => showAddAddressSheet(
                            context,
                            userId: widget.user.uid,
                            userRole: "customer",
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: CX.canvasMid,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: CX.glassBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add_location_alt_rounded,
                                  color: CX.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "No saved addresses yet. Tap to set your home / work location.",
                                    style: WorkGoFonts.body(
                                      color: CX.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Top Certified Artisans Available (100% Real-Time Firestore Stream)
            StreamBuilder<List<Worker>>(
              stream: _workerService.streamAvailableWorkers(),
              builder: (context, workerSnap) {
                final workers = workerSnap.data ?? [];

                return AuroraCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                color: CX.rose,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "favorite_artisans".tr(),
                                style: const TextStyle(
                                  color: CX.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          if (workers.isNotEmpty)
                            Text(
                              "${workers.length} Available",
                              style: WorkGoFonts.numeric(
                                color: CX.emerald,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (workers.isEmpty)
                        Text(
                          "No certified artisans online right now. Book a service and artisans will be broadcasted live!",
                          style: WorkGoFonts.body(
                            color: CX.textSecondary,
                            fontSize: 12,
                          ),
                        )
                      else
                        ...workers.take(3).map((w) {
                          final skill = w.skills.isNotEmpty
                              ? w.skills.first
                              : "General Repair";
                          final ratingStr = w.totalRatings > 0
                              ? "${w.avgRating.toStringAsFixed(1)} ★"
                              : "5.0 ★";
                          final jobsStr = "${w.totalRatings} jobs";
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildFavoriteArtisanTile(
                              w.id,
                              w.skills.isNotEmpty
                                  ? w.skills.join(", ")
                                  : "Certified Artisan",
                              skill,
                              ratingStr,
                              jobsStr,
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Preferred Language Switcher
            AuroraCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.translate_rounded, color: CX.cyan, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "App Language",
                      style: TextStyle(
                        color: CX.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _buildLangPill(context),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cooperative Impact Card
            AuroraCard(
              borderColor: CX.emerald.withValues(alpha: 0.3),
              glowColor: CX.emerald,
              gradient: LinearGradient(
                colors: [
                  CX.emerald.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuroraOrb(
                    icon: Icons.health_and_safety_rounded,
                    gradient: CX.auroraSuccess,
                    size: 44,
                    iconSize: 22,
                    glowColor: CX.emerald,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cooperative Member Advantage",
                          style: TextStyle(
                            color: CX.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "2% of every service fee directly funds accident & health insurance for local artisans.",
                          style: TextStyle(
                            color: CX.textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Sign Out CTA with Confirmation Bottom Sheet
            OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showSignOutConfirmationSheet(context);
                if (confirmed == true) {
                  widget.onSignOut();
                }
              },
              icon: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFF43F5E),
                size: 20,
              ),
              label: Text(
                'sign_out'.tr(),
                style: const TextStyle(
                  color: Color(0xFFF43F5E),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                side: BorderSide(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.5),
                  width: 1.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: const Color(
                  0xFFF43F5E,
                ).withValues(alpha: 0.06),
              ),
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

  Widget _buildFavoriteArtisanTile(
    String workerId,
    String name,
    String trade,
    String rating,
    String jobs,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CX.canvasMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CX.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: CX.auroraVioletAmber,
            ),
            child: const Center(
              child: Icon(
                Icons.handyman_rounded,
                color: Colors.white,
                size: 18,
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
                    Flexible(
                      child: Text(
                        name,
                        style: WorkGoFonts.heading(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      rating,
                      style: WorkGoFonts.numeric(
                        color: CX.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Text(
                  "$trade · $jobs",
                  style: WorkGoFonts.body(
                    color: CX.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => setState(() => _currentNavIndex = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: CX.violet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "Book",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
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
      borderColor: CX.rose.withValues(alpha: 0.5),
      gradient: const LinearGradient(
        colors: [Color(0xFF4A0A0A), Color(0xFF7F1D1D), Color(0xFF3B0101)],
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
                color: CX.rose.withValues(alpha: 0.2),
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
                    Text(
                      'emergency_booking'.tr(),
                      style: WorkGoFonts.display(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
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
                    color: Colors.white60,
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
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  ACTIVE BOOKING PILL
// ──────────────────────────────────────────────────────
class _ActiveBookingPill extends StatelessWidget {
  const _ActiveBookingPill({required this.booking, required this.onTap});
  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PulsingDot(color: CX.amber, size: 8),
            const SizedBox(width: 7),
            Text(
              "Active Booking in Progress",
              style: TextStyle(
                color: CX.amber.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AuroraCard(
          onTap: onTap,
          glowColor: CX.amber,
          borderColor: CX.amber.withValues(alpha: 0.4),
          child: Row(
            children: [
              AuroraOrb(
                icon: Icons.timelapse_rounded,
                gradient: CX.auroraVioletAmber,
                size: 44,
                iconSize: 22,
                glowColor: CX.amber,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceType,
                      style: const TextStyle(
                        color: CX.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Status: ${booking.status.name.toUpperCase()}",
                      style: const TextStyle(
                        color: CX.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const AuroraBadge(
                label: "TRACK LIVE",
                style: AuroraBadgeStyle.amber,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────
//  BENTO CATEGORY CARD (Swiggy / Rapido Style Visual Depth)
// ──────────────────────────────────────────────────────
class _BentoCategoryCard extends StatefulWidget {
  const _BentoCategoryCard({
    required this.name,
    required this.style,
    required this.onTap,
  });

  final String name;
  final CategoryStyle style;
  final VoidCallback onTap;

  @override
  State<_BentoCategoryCard> createState() => _BentoCategoryCardState();
}

class _BentoCategoryCardState extends State<_BentoCategoryCard>
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
      end: 0.95,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final accent = style.accentColor ?? style.glow;

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
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.14),
                CX.canvasCard.withValues(alpha: 0.88),
                CX.canvasMid,
              ],
              stops: const [0.0, 0.45, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: 3D Icon Container + Live Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: style.gradient,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(style.icon, color: Colors.white, size: 22),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      style.badge,
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),

              // Title & Subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: WorkGoFonts.heading(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    style.subtitle,
                    style: TextStyle(
                      color: CX.textSecondary.withValues(alpha: 0.85),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Bottom Row: Starting price + Explore Arrow
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      style.startingPrice,
                      style: const TextStyle(
                        color: CX.amber,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.18),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: accent,
                      size: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
            color: CX.canvasCard.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CX.glassBorderBright, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CX.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.price,
                  style: const TextStyle(
                    color: CX.amber,
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
  const _ArtisanSpotlightCard({required this.worker, required this.onTap});
  final Worker worker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trade = worker.skills.isNotEmpty ? worker.skills.first : "Artisan";
    final style = categoryStyle(trade);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [CX.canvasCard.withValues(alpha: 0.95), CX.canvasMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CX.glassBorderBright, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
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
                            child: Text(
                              worker.name.isNotEmpty ? worker.name : "Artisan",
                              style: WorkGoFonts.heading(
                                color: Colors.white,
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
                            color: CX.emerald,
                            size: 14,
                          ),
                        ],
                      ),
                      Text(
                        trade,
                        style: TextStyle(
                          color: style.accentColor ?? CX.cyanLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: CX.amber, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      worker.avgRating > 0
                          ? worker.avgRating.toStringAsFixed(1)
                          : "4.9",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      " (${worker.totalReviews > 0 ? worker.totalReviews : 24})",
                      style: const TextStyle(color: CX.textMuted, fontSize: 10),
                    ),
                  ],
                ),
                Text(
                  "🏡 ${worker.homesServiced > 0 ? worker.homesServiced : 38} homes",
                  style: const TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "📍 ${worker.distanceKm.toStringAsFixed(1)} km away",
                  style: const TextStyle(
                    color: CX.cyan,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: CX.auroraVioletCyan,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "Book",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
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
  });

  final Booking booking;
  final VoidCallback onTap;
  final VoidCallback? onBookAgain;

  AuroraBadgeStyle get _badgeStyle => switch (booking.status) {
    BookingStatus.completed => AuroraBadgeStyle.emerald,
    BookingStatus.inProgress => AuroraBadgeStyle.amber,
    BookingStatus.accepted => AuroraBadgeStyle.cyan,
    BookingStatus.cancelled => AuroraBadgeStyle.rose,
    _ => AuroraBadgeStyle.violet,
  };

  @override
  Widget build(BuildContext context) {
    final style = categoryStyle(booking.serviceType);
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

    return AuroraCard(
      onTap: onTap,
      glowColor: style.glow.withValues(alpha: isLive ? 0.4 : 0.2),
      borderColor: isLive ? style.glow.withValues(alpha: 0.4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Top Header Row: Orb + Title/Emergency + Status Badge ──
          Row(
            children: [
              AuroraOrb(
                icon: style.icon,
                gradient: style.gradient,
                size: 44,
                iconSize: 22,
                glowColor: style.glow,
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
                            booking.serviceType,
                            style: const TextStyle(
                              color: CX.textPrimary,
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
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              "🚨 SOS",
                              style: TextStyle(
                                color: Color(0xFFFCA5A5),
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
                      style: TextStyle(
                        color: CX.textSecondary.withValues(alpha: 0.7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              AuroraBadge(
                label: booking.status.name.toUpperCase(),
                style: _badgeStyle,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── 2. Artisan / Dispatch Info Strip ───────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                if (booking.acceptedWorkerName != null &&
                    booking.acceptedWorkerName!.isNotEmpty) ...[
                  WorkGoAvatar(name: booking.acceptedWorkerName!, radius: 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Artisan: ${booking.acceptedWorkerName}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else if (isPending) ...[
                  PulsingDot(color: CX.amber, size: 7),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Broadcasting to local specialists (${booking.broadcastRadiusKm.toInt()} km)...",
                      style: const TextStyle(
                        color: CX.amber,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.handyman_rounded,
                    color: CX.textSecondary,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "WorkGo Co-op Dispatch #${booking.id.substring(0, booking.id.length > 6 ? 6 : booking.id.length)}",
                      style: const TextStyle(
                        color: CX.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 3. Price & Action Button Strip ─────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Amount",
                    style: TextStyle(
                      color: CX.textMuted.withValues(alpha: 0.8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Text(
                        "₹${booking.totalAmount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: CX.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: booking.paymentStatus == PaymentStatus.paid
                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          booking.paymentStatus.name.toUpperCase(),
                          style: TextStyle(
                            color: booking.paymentStatus == PaymentStatus.paid
                                ? const Color(0xFF6EE7B7)
                                : CX.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (isLive || isPending)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: CX.auroraVioletCyan,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: CX.cyan.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.radar_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        "Track Live",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isCompleted && onBookAgain != null)
                GestureDetector(
                  onTap: onBookAgain,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: CX.violet.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CX.violetLight.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.replay_rounded,
                          color: CX.violetLight,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Book Again",
                          style: TextStyle(
                            color: CX.violetLight,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
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
    );
  }
}
