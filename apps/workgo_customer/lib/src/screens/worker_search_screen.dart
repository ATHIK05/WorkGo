import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
import 'booking_creation_screen.dart';

class WorkerSearchScreen extends StatefulWidget {
  const WorkerSearchScreen({
    super.key,
    required this.customerId,
    this.initialCategory,
  });

  final String customerId;
  final String? initialCategory;

  @override
  State<WorkerSearchScreen> createState() => _WorkerSearchScreenState();
}

class _WorkerSearchScreenState extends State<WorkerSearchScreen>
    with TickerProviderStateMixin {
  final WorkerService _workerService = WorkerService();
  late String _selectedCategory;
  double _radiusKm = 10.0;
  final _searchController = TextEditingController();
  late AnimationController _searchFocusCtrl;
  bool _searchFocused = false;
  final FocusNode _searchFocus = FocusNode();

  bool _onlineOnly = false;
  String _sortBy = "nearest"; // "nearest", "rating", "fare"
  bool _dismissedFloatingBanner = false;

  final List<({String key, String emoji, String title, Color color, LinearGradient gradient})> _categories = [
    (key: "All", emoji: "🌐", title: "All Trades", color: CX.cyan, gradient: CX.auroraVioletCyan),
    (key: "Plumbing", emoji: "🚰", title: "Plumbing", color: CX.cyan, gradient: CX.auroraVioletCyan),
    (key: "Electrical", emoji: "⚡", title: "Electrical", color: CX.amber, gradient: CX.auroraVioletAmber),
    (key: "Carpentry", emoji: "🪵", title: "Carpentry", color: const Color(0xFFF97316), gradient: const LinearGradient(colors: [Color(0xFF9A3412), Color(0xFFF97316)])),
    (key: "Cleaning", emoji: "🧹", title: "Cleaning", color: const Color(0xFF34D399), gradient: const LinearGradient(colors: [Color(0xFF065F46), Color(0xFF34D399)])),
    (key: "Painting", emoji: "🎨", title: "Painting", color: const Color(0xFFA78BFA), gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFFA78BFA)])),
    (key: "Appliance Repair", emoji: "❄️", title: "Appliance Repair", color: const Color(0xFFF43F5E), gradient: const LinearGradient(colors: [Color(0xFF9F1239), Color(0xFFF43F5E)])),
    (key: "Masonry", emoji: "🧱", title: "Masonry", color: const Color(0xFF94A3B8), gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF64748B)])),
    (key: "Gardening", emoji: "🪴", title: "Gardening", color: const Color(0xFF10B981), gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF10B981)])),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? "All";
    _searchFocusCtrl = AnimationController(vsync: this, duration: CAnim.normal);
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
      if (_searchFocus.hasFocus) {
        _searchFocusCtrl.forward();
      } else {
        _searchFocusCtrl.reverse();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'search_workers'.tr(),
          style: WorkGoFonts.heading(
            color: const Color(0xFF141416),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF141416)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "RADAR ${_radiusKm.toInt()}KM",
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
      body: SafeArea(
        child: Column(
          children: [
            // 1. Luxury Large Floating Search Capsule
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: _buildLuxurySearchBar(),
            ),

            // 2. Horizontal Quick Filters & Sort Strip
            SizedBox(
              height: 42,
              child: _buildQuickFiltersStrip(),
            ),
            const SizedBox(height: 12),

            // 3. Select Craft Rail Title + Pills (Image 1 Style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select craft specialty",
                    style: TextStyle(
                      color: Color(0xFF141416),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (_selectedCategory != "All")
                    GestureDetector(
                      onTap: () => setState(() => _selectedCategory = "All"),
                      child: const Text(
                        "Reset",
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: _buildCategoryPillsRail(),
            ),
            const SizedBox(height: 8),

            // 4. Workers Results Stream
            Expanded(
              child: _buildWorkersStream(),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  MODERN ANDROID SEARCH BAR (EXACT TEMPLATE IMPLEMENTATION)
  // ──────────────────────────────────────────
  Widget _buildLuxurySearchBar() {
    final hasActiveFilter = _onlineOnly || _sortBy != "nearest" || _radiusKm != 10.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchFocused
              ? const Color(0xFF94A3B8)
              : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Search Icon
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF6B7280),
            size: 22,
          ),
          const SizedBox(width: 14),

          // Central Input Field (Overrides theme borders to prevent nested yellow focus ring)
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
              cursorColor: const Color(0xFF111827),
              decoration: const InputDecoration(
                hintText: "Search...",
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Trailing Actions (Clear, Filter Sliders, Mic)
          if (_searchController.text.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() => _searchController.clear()),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Filter Sliders Icon (Tune)
          GestureDetector(
            onTap: () {
              setState(() {
                if (_sortBy == "nearest") {
                  _sortBy = "rating";
                } else if (_sortBy == "rating") {
                  _sortBy = "fare";
                } else {
                  _sortBy = "nearest";
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.tune_rounded,
                size: 22,
                color: hasActiveFilter
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Microphone Icon
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(
                Icons.mic_rounded,
                size: 22,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //  QUICK FILTERS & SORT STRIP (HORIZONTAL SCROLL)
  // ──────────────────────────────────────────
  Widget _buildQuickFiltersStrip() {
    final radiusOptions = [5.0, 10.0, 25.0, 50.0];

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Live Online Toggle Pill
        GestureDetector(
          onTap: () => setState(() => _onlineOnly = !_onlineOnly),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _onlineOnly ? const Color(0xFFECFDF5) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _onlineOnly ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                width: 1.1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x04000000),
                  blurRadius: 6,
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
                    color: _onlineOnly ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "Live Online",
                  style: TextStyle(
                    color: _onlineOnly ? const Color(0xFF065F46) : const Color(0xFF475569),
                    fontSize: 11.5,
                    fontWeight: _onlineOnly ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Radius Chips
        ...radiusOptions.map((r) {
          final isSelected = _radiusKm == r;
          return GestureDetector(
            onTap: () => setState(() {
              _radiusKm = r;
              _dismissedFloatingBanner = false;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF141416) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF141416) : const Color(0xFFE2E8F0),
                  width: 1.1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "${r.toInt()} km",
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),

        // Sort Options
        _buildSortChip("nearest", "⚡ Nearest"),
        _buildSortChip("rating", "★ Top Rated"),
        _buildSortChip("fare", "💰 Best Value"),
      ],
    );
  }

  Widget _buildSortChip(String sortKey, String label) {
    final isSelected = _sortBy == sortKey;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = sortKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1.1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF475569),
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  CATEGORY PILLS RAIL (Image 1 Style Dark Active Pill)
  // ──────────────────────────────────────────
  Widget _buildCategoryPillsRail() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final cat = _categories[index];
        final isSelected = cat.key == _selectedCategory;

        return GestureDetector(
          onTap: () => setState(() {
            _selectedCategory = cat.key;
            _dismissedFloatingBanner = false;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF141416) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF141416)
                    : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cat.emoji,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 6),
                Text(
                  cat.title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────
  //  WORKERS STREAM & DYNAMIC EMPTY COCKPIT
  // ──────────────────────────────────────────
  Widget _buildWorkersStream() {
    return StreamBuilder<List<Worker>>(
      stream: _workerService.streamAvailableWorkers(
        skill: _selectedCategory == "All" ? null : _selectedCategory,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, __) =>
                const AuroraShimmer(height: 180, borderRadius: 22),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFEE2E2),
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      color: Color(0xFFDC2626),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Connection Interrupted",
                    style: TextStyle(
                      color: Color(0xFF141416),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${snapshot.error}",
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        var workers = snapshot.data ?? [];

        // Search text filtering
        final query = _searchController.text.trim().toLowerCase();
        if (query.isNotEmpty) {
          workers = workers.where((w) {
            return w.name.toLowerCase().contains(query) ||
                w.skills.any((s) => s.toLowerCase().contains(query)) ||
                (w.phoneForCalling?.contains(query) ?? false) ||
                w.id.toLowerCase().contains(query);
          }).toList();
        }

        // Radius filtering
        workers = workers.where((w) {
          final effectiveDist = w.distanceKm > 0 ? w.distanceKm : 1.0;
          return effectiveDist <= _radiusKm + 2;
        }).toList();

        // Online filter
        if (_onlineOnly) {
          workers = workers
              .where((w) => w.availabilityStatus == AvailabilityStatus.online)
              .toList();
        }

        // Sorting
        if (_sortBy == "rating") {
          workers.sort((a, b) => b.avgRating.compareTo(a.avgRating));
        } else if (_sortBy == "fare") {
          workers.sort((a, b) => a.baseRate.compareTo(b.baseRate));
        } else {
          // Nearest
          workers.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        }

        // ── Empty State Experience (Perfect Center Alignment) ──────
        if (workers.isEmpty) {
          return _buildInteractiveEmptyCockpit();
        }

        // ── Results List + Floating Dismissible Expander ───────────
        return Stack(
          children: [
            Column(
              children: [
                // Results Summary Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Found ${workers.length} verified ${workers.length == 1 ? 'artisan' : 'artisans'}",
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _sortBy == "rating"
                              ? "Sorted by Rating"
                              : (_sortBy == "fare" ? "Sorted by Value" : "Sorted by Proximity"),
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    itemCount: workers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      return SlideFadeIn(
                        delay: Duration(milliseconds: index * 40),
                        child: _WorkerCard(
                          worker: workers[index],
                          selectedCategory: _selectedCategory,
                          customerId: widget.customerId,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Floating Dismissible Radius Expander Banner at bottom of list
            if (!_dismissedFloatingBanner && _radiusKm < 50)
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Dismissible(
                  key: ValueKey("floating_radius_banner_${_radiusKm}_$_selectedCategory"),
                  direction: DismissDirection.horizontal,
                  onDismissed: (_) {
                    setState(() => _dismissedFloatingBanner = true);
                  },
                  child: SlideFadeIn(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFEFF6FF),
                            ),
                            child: const Icon(
                              Icons.radar_rounded,
                              color: Color(0xFF2563EB),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Showing within ${_radiusKm.toInt()} km",
                              style: const TextStyle(
                                color: Color(0xFF141416),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _radiusKm = _radiusKm < 25 ? 25.0 : 50.0;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141416),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Scan ${_radiusKm < 25 ? '25 km' : '50 km'}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _dismissedFloatingBanner = true),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFF1F5F9),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ──────────────────────────────────────────
  //  NEXT-GEN INTERACTIVE EMPTY COCKPIT (PERFECTLY CENTERED)
  // ──────────────────────────────────────────
  Widget _buildInteractiveEmptyCockpit() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Radar Scanning Beacon
            _RadarScanningBeacon(
              category: _selectedCategory,
              radiusKm: _radiusKm,
            ),
            const SizedBox(height: 22),

            // 2. Expand Radius 1-Tap Recovery Button
            if (_radiusKm < 50) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFEFF6FF),
                      ),
                      child: const Icon(
                        Icons.travel_explore_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Widen Search Coverage",
                            style: TextStyle(
                              color: Color(0xFF141416),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            "Expand radar to ${_radiusKm < 25 ? '25 km' : '50 km'} to scan adjacent zones.",
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _radiusKm = _radiusKm < 25 ? 25.0 : 50.0;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Scan ${_radiusKm < 25 ? '25 km' : '50 km'}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Active Other Trades Available Nearby (Stream across all categories)
            StreamBuilder<List<Worker>>(
              stream: _workerService.streamAvailableWorkers(),
              builder: (context, snapshot) {
                final allWorkers = snapshot.data ?? [];
                if (allWorkers.isEmpty) return const SizedBox.shrink();

                // Group counts by category
                final Map<String, int> counts = {};
                for (final w in allWorkers) {
                  for (final s in w.skills) {
                    counts[s] = (counts[s] ?? 0) + 1;
                  }
                }

                // Filter out the currently selected empty category
                final availableTrades = counts.entries
                    .where((e) => e.key != _selectedCategory && e.value > 0)
                    .toList();

                if (availableTrades.isEmpty) return const SizedBox.shrink();

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 16),
                          SizedBox(width: 6),
                          Text(
                            "Active Trades Available Nearby Right Now",
                            style: TextStyle(
                              color: Color(0xFF141416),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableTrades.map((e) {
                          final meta = _categories.firstWhere(
                            (c) => c.key == e.key,
                            orElse: () => (
                              key: e.key,
                              emoji: "🔧",
                              title: e.key,
                              color: const Color(0xFF2563EB),
                              gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                            ),
                          );

                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = e.key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(meta.emoji, style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${meta.title} (${e.value})",
                                    style: const TextStyle(
                                      color: Color(0xFF141416),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  RADAR SCANNING BEACON ANIMATION WIDGET
// ──────────────────────────────────────────────────────
class _RadarScanningBeacon extends StatefulWidget {
  const _RadarScanningBeacon({
    required this.category,
    required this.radiusKm,
  });

  final String category;
  final double radiusKm;

  @override
  State<_RadarScanningBeacon> createState() => _RadarScanningBeaconState();
}

class _RadarScanningBeaconState extends State<_RadarScanningBeacon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple 1
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final progress = _ctrl.value;
                  return Container(
                    width: 140 * progress,
                    height: 140 * progress,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2563EB).withValues(alpha: (1.0 - progress) * 0.4),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              ),
              // Ripple 2
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final progress = (_ctrl.value + 0.5) % 1.0;
                  return Container(
                    width: 140 * progress,
                    height: 140 * progress,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: (1.0 - progress) * 0.35),
                        width: 1.2,
                      ),
                    ),
                  );
                },
              ),
              // Center Glowing Orb
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          widget.category == "All"
              ? "Scanning ${widget.radiusKm.toInt()} km Radar..."
              : "No ${widget.category} Artisans in ${widget.radiusKm.toInt()} km",
          style: const TextStyle(
            color: Color(0xFF141416),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          "All registered ${widget.category} specialists are currently on live job dispatches or beyond ${widget.radiusKm.toInt()} km.",
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────
//  PREMIUM WORKER CARD WITH RAPIDO-STYLE DYNAMIC PRICING
// ──────────────────────────────────────────────────────
class _WorkerCard extends StatelessWidget {
  const _WorkerCard({
    required this.worker,
    required this.selectedCategory,
    required this.customerId,
  });

  final Worker worker;
  final String selectedCategory;
  final String customerId;

  void _showFareBreakdownSheet(BuildContext context, FareBreakdown fare) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 24,
                offset: Offset(0, -4),
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
                    color: const Color(0xFFE2E8F0),
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
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFFD97706),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'fare_breakdown'.tr(),
                          style: WorkGoFonts.heading(
                            color: const Color(0xFF141416),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Transparent Co-op pricing • ${worker.name}",
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _fareRow(
                      'base_visit_fare'.tr(),
                      "₹${fare.baseVisitFare.toStringAsFixed(0)}",
                      subtitle: "${fare.category} inspection & basic labour",
                    ),
                    const Divider(color: Color(0xFFE2E8F0), height: 18),
                    _fareRow(
                      'transit_distance_fare'.tr(),
                      "₹${fare.distanceTransitFare.toStringAsFixed(0)}",
                      subtitle:
                          "${fare.distanceKm.toStringAsFixed(1)} km transit @ ₹${fare.perKmRate.toStringAsFixed(0)}/km",
                    ),
                    if (fare.experienceBonus > 0) ...[
                      const Divider(color: Color(0xFFE2E8F0), height: 18),
                      _fareRow(
                        'experience_bonus'.tr(),
                        "+₹${fare.experienceBonus.toStringAsFixed(0)}",
                        subtitle:
                            "Senior Master Artisan (${fare.experienceYears} yrs exp)",
                        isBonus: true,
                      ),
                    ],
                    const Divider(color: Color(0xFFE2E8F0), height: 18),
                    _fareRow(
                      "Cooperative Platform Cut",
                      "₹0 (0% Cut)",
                      subtitle: "100% of payment goes directly to artisan",
                      isFree: true,
                    ),
                    const Divider(color: Color(0xFFCBD5E1), height: 22, thickness: 1.2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Estimated Fare",
                          style: TextStyle(
                            color: Color(0xFF141416),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          "₹${fare.totalEstimatedFare.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: Color(0xFF141416),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.shield_rounded, color: Color(0xFF059669), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Guaranteed by Worker Co-operative • Zero Surge Pricing",
                        style: TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookingCreationScreen(
                        serviceCategory: fare.category,
                        customerId: customerId,
                        targetWorkerId: worker.id,
                        worker: worker,
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        "Book This Artisan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fareRow(String title, String value,
      {String? subtitle, bool isBonus = false, bool isFree = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF141416),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isFree ? const Color(0xFF059669) : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: isFree ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isFree
                ? const Color(0xFF059669)
                : (isBonus ? const Color(0xFFB45309) : const Color(0xFF141416)),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tradeCategory = worker.skills.isNotEmpty
        ? worker.skills.first
        : (selectedCategory != "All" ? selectedCategory : "Plumbing");

    final isOnline = worker.availabilityStatus == AvailabilityStatus.online;

    // Calculate Dynamic Fare using Cooperative Pricing Engine (Rapido-style)
    final fare = CooperativePricingEngine.instance.calculateFare(
      category: tradeCategory,
      distanceKm: worker.distanceKm > 0 ? worker.distanceKm : 1.2,
      experienceYears: worker.experienceYears,
      customBaseRate: worker.baseRate,
      customPerKmRate: worker.perKmRate,
    );

    final displayName = worker.name.isNotEmpty
        ? worker.name
        : (worker.isProxy ? "Artisan Partner" : "Co-op Artisan");

    final hasRatings = worker.totalRatings > 0 || worker.totalReviews > 0;
    final ratingDisplay = worker.avgRating > 0
        ? worker.avgRating.toStringAsFixed(1)
        : (hasRatings ? "5.0" : "New");
    final reviewCount = worker.totalReviews > 0
        ? worker.totalReviews
        : (worker.totalRatings > 0 ? worker.totalRatings : 0);

    final homesDisplay = worker.homesServiced > 0
        ? "${worker.homesServiced} homes"
        : (worker.totalRatings > 0 ? "${worker.totalRatings} jobs" : "New Member");

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Header: Avatar + Name + Verified Badge + Star Rating ───────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with online status
              Stack(
                children: [
                  WorkGoAvatar(
                    name: displayName,
                    avatarBase64: worker.verificationDetails?.selfieBase64,
                    radius: 26,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Info column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: WorkGoFonts.heading(
                              color: const Color(0xFF141416),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
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
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "${worker.skills.join(', ')} • ${worker.experienceYears} yrs exp (${worker.experienceYears >= 5 ? 'Master' : 'Senior'})",
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Star Rating Pill (Image 1 Style)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 14),
                    const SizedBox(width: 3),
                    Text(
                      ratingDisplay,
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (reviewCount > 0) ...[
                      const SizedBox(width: 2),
                      Text(
                        " ($reviewCount)",
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── 2. Trust & Social Proof Row ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Homes / Customers Serviced
                Row(
                  children: [
                    const Icon(
                      Icons.home_work_rounded,
                      color: Color(0xFF059669),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      homesDisplay,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 14, color: const Color(0xFFE2E8F0)),

                // Distance
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFF2563EB), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      worker.distanceKm > 0
                          ? "${worker.distanceKm.toStringAsFixed(1)} km away"
                          : "1.2 km away",
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 14, color: const Color(0xFFE2E8F0)),

                // Escrow Safety
                Row(
                  children: const [
                    Icon(Icons.shield_rounded, color: Color(0xFF7C3AED), size: 13),
                    SizedBox(width: 4),
                    Text(
                      "₹50k Cover",
                      style: TextStyle(
                        color: Color(0xFF7C3AED),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFFF1F5F9), height: 1),
          ),

          // ── 3. Price + Action Row (Image 1 Style Dark Pill Button) ────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Dynamic Fare Info
              GestureDetector(
                onTap: () => _showFareBreakdownSheet(context, fare),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'est_fare'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFD97706),
                          size: 12,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          "₹${fare.totalEstimatedFare.toStringAsFixed(0)}",
                          style: WorkGoFonts.numeric(
                            color: const Color(0xFF141416),
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "(${fare.formattedBase} + ${fare.formattedTransit})",
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Sleek Dark Pill Action Button (Image 1 Style)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => BookingCreationScreen(
                        serviceCategory: tradeCategory,
                        customerId: customerId,
                        targetWorkerId: worker.id,
                        worker: worker,
                      ),
                    ),
                  );
                },
                icon: const Text(
                  "Book Pro",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                label: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF141416),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize: const Size(0, 42),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
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
