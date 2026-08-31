import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
    return AuroraScaffold(
      appBar: AuroraAppBar(
        title: 'search_workers'.tr(),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: CX.cyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CX.cyan.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PulsingDot(color: CX.cyan, size: 6),
                const SizedBox(width: 6),
                Text(
                  "RADAR ${_radiusKm.toInt()}KM",
                  style: const TextStyle(
                    color: CX.cyanLight,
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
            // 1. Search + Dynamic Radius Cockpit
            SlideFadeIn(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: _buildDiscoveryCockpit(),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Vibrant Category Rail
            SlideFadeIn(
              delay: const Duration(milliseconds: 60),
              child: SizedBox(
                height: 44,
                child: _buildCategoryPillsRail(),
              ),
            ),
            const SizedBox(height: 10),

            // 3. Workers Results Stream
            Expanded(
              child: _buildWorkersStream(),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  DISCOVERY COCKPIT (SEARCH + RADIUS CHIPS + ONLINE TOGGLE)
  // ──────────────────────────────────────────
  Widget _buildDiscoveryCockpit() {
    final radiusOptions = [5.0, 10.0, 25.0, 50.0];

    return AnimatedContainer(
      duration: CAnim.normal,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CX.canvasCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _searchFocused
              ? CX.cyan.withValues(alpha: 0.7)
              : CX.glassBorder,
          width: 1.2,
        ),
        boxShadow: _searchFocused
            ? [
                BoxShadow(
                  color: CX.cyan.withValues(alpha: 0.18),
                  blurRadius: 22,
                  spreadRadius: -4,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          // Search Input Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: CX.auroraVioletCyan,
                  boxShadow: [
                    BoxShadow(
                      color: CX.violet.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  style: const TextStyle(
                    color: CX.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search artisan, trade or area...",
                    hintStyle: TextStyle(
                      color: CX.textMuted.withValues(alpha: 0.8),
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _searchController.clear()),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Radius Chips & Online Filter Row
          Row(
            children: [
              // Radius Label with Pulse
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.radar_rounded, color: CX.cyan, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "Radius:",
                    style: TextStyle(
                      color: CX.textSecondary.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Radius Chips (5, 10, 25, 50 km)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: radiusOptions.map((r) {
                      final isSelected = _radiusKm == r;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _radiusKm = r;
                          _dismissedFloatingBanner = false;
                        }),
                        child: AnimatedContainer(
                          duration: CAnim.fast,
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? CX.cyan.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: isSelected
                                  ? CX.cyan.withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.1),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            "${r.toInt()} km",
                            style: TextStyle(
                              color: isSelected ? CX.cyanLight : CX.textSecondary,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Online Only Toggle Chip
              GestureDetector(
                onTap: () => setState(() => _onlineOnly = !_onlineOnly),
                child: AnimatedContainer(
                  duration: CAnim.fast,
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _onlineOnly
                        ? CX.emerald.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: _onlineOnly
                          ? CX.emerald.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.1),
                      width: 1.0,
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
                          color: _onlineOnly ? CX.emerald : CX.textMuted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "Live Online",
                        style: TextStyle(
                          color: _onlineOnly ? const Color(0xFF6EE7B7) : CX.textSecondary,
                          fontSize: 11,
                          fontWeight: _onlineOnly ? FontWeight.w800 : FontWeight.w500,
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

  // ──────────────────────────────────────────
  //  VIBRANT CATEGORY PILLS RAIL
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
            duration: CAnim.normal,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected ? cat.gradient : null,
              color: isSelected ? null : CX.canvasCard.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? cat.color.withValues(alpha: 0.8)
                    : CX.glassBorder,
                width: 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: cat.color.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cat.emoji,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(width: 7),
                Text(
                  cat.title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : CX.textSecondary,
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
                  AuroraOrb(
                    icon: Icons.wifi_off_rounded,
                    gradient: LinearGradient(
                      colors: [CX.rose.withValues(alpha: 0.6), CX.rose],
                    ),
                    size: 56,
                    iconSize: 28,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Connection Interrupted",
                    style: TextStyle(
                      color: CX.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${snapshot.error}",
                    style: const TextStyle(color: CX.textSecondary, fontSize: 12),
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
                          color: CX.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            "Sort:",
                            style: TextStyle(
                              color: CX.textMuted.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          DropdownButton<String>(
                            value: _sortBy,
                            dropdownColor: const Color(0xFF161133),
                            underline: const SizedBox.shrink(),
                            icon: const Icon(Icons.arrow_drop_down, color: CX.cyan, size: 18),
                            style: const TextStyle(
                              color: CX.cyanLight,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                            items: const [
                              DropdownMenuItem(value: "nearest", child: Text("⚡ Nearest")),
                              DropdownMenuItem(value: "rating", child: Text("★ Top Rated")),
                              DropdownMenuItem(value: "fare", child: Text("💰 Low Fare")),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _sortBy = val);
                            },
                          ),
                        ],
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
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1C1542).withValues(alpha: 0.95),
                            const Color(0xFF0F0B24).withValues(alpha: 0.98),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: CX.cyan.withValues(alpha: 0.45),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: CX.cyan.withValues(alpha: 0.2),
                            ),
                            child: const Icon(
                              Icons.radar_rounded,
                              color: CX.cyanLight,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Showing within ${_radiusKm.toInt()} km",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
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
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                gradient: CX.auroraVioletCyan,
                                borderRadius: BorderRadius.circular(10),
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
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white70,
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CX.cyan.withValues(alpha: 0.15),
                      CX.violet.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: CX.cyan.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CX.cyan.withValues(alpha: 0.2),
                      ),
                      child: const Icon(
                        Icons.travel_explore_rounded,
                        color: CX.cyanLight,
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
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            "Expand radar to ${_radiusKm < 25 ? '25 km' : '50 km'} to scan adjacent zones.",
                            style: const TextStyle(
                              color: CX.textSecondary,
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
                          gradient: CX.auroraVioletCyan,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: CX.cyan.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CX.canvasCard.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: CX.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.bolt_rounded, color: CX.amber, size: 16),
                          SizedBox(width: 6),
                          Text(
                            "Active Trades Available Nearby Right Now",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
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
                              color: CX.cyan,
                              gradient: CX.auroraVioletCyan,
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
                                color: meta.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: meta.color.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(meta.emoji, style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${meta.title} (${e.value})",
                                    style: TextStyle(
                                      color: meta.color,
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
                        color: CX.cyan.withValues(alpha: (1.0 - progress) * 0.5),
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
                        color: CX.violet.withValues(alpha: (1.0 - progress) * 0.4),
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
                  gradient: CX.auroraVioletCyan,
                  boxShadow: [
                    BoxShadow(
                      color: CX.cyan.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 2,
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
        const SizedBox(height: 12),
        Text(
          widget.category == "All"
              ? "Scanning ${widget.radiusKm.toInt()} km Radar..."
              : "No ${widget.category} Artisans in ${widget.radiusKm.toInt()} km",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          "All registered ${widget.category} specialists are currently on live job dispatches or beyond ${widget.radiusKm.toInt()} km.",
          style: TextStyle(
            color: CX.textSecondary.withValues(alpha: 0.8),
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
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: const Color(0xFF140F2D),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: CX.glassBorderBright, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: CX.violet.withValues(alpha: 0.35),
                blurRadius: 30,
                spreadRadius: -4,
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
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CX.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: CX.amber,
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
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          "Transparent on-demand pricing • ${worker.name}",
                          style: WorkGoFonts.body(
                            color: CX.textSecondary,
                            fontSize: 12,
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
                  color: CX.canvasCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: CX.glassBorder),
                ),
                child: Column(
                  children: [
                    _fareRow(
                      'base_visit_fare'.tr(),
                      "₹${fare.baseVisitFare.toStringAsFixed(0)}",
                      subtitle: "${fare.category} inspection & basic labour",
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    _fareRow(
                      'transit_distance_fare'.tr(),
                      "₹${fare.distanceTransitFare.toStringAsFixed(0)}",
                      subtitle:
                          "${fare.distanceKm.toStringAsFixed(1)} km @ ₹${fare.perKmRate.toStringAsFixed(0)}/km",
                    ),
                    if (fare.experienceBonus > 0) ...[
                      const Divider(color: Colors.white12, height: 16),
                      _fareRow(
                        'experience_bonus'.tr(),
                        "+₹${fare.experienceBonus.toStringAsFixed(0)}",
                        subtitle:
                            "Senior Master Artisan (${fare.experienceYears} yrs)",
                        isBonus: true,
                      ),
                    ],
                    const Divider(color: Colors.white12, height: 16),
                    _fareRow(
                      "Cooperative Platform Cut",
                      "₹0 (0%)",
                      subtitle: "100% earnings go directly to artisan",
                      isFree: true,
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'total_amount'.tr(),
                          style: WorkGoFonts.heading(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          "₹${fare.totalEstimatedFare.toStringAsFixed(0)}",
                          style: WorkGoFonts.numeric(
                            color: CX.amber,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: CX.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CX.emerald.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded,
                        color: CX.emerald, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'transparent_pricing_note'.tr(),
                        style: WorkGoFonts.body(
                          color: const Color(0xFF6EE7B7),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GlowButton(
                label: 'book_now'.tr(),
                icon: Icons.calendar_month_rounded,
                onPressed: () {
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
                gradient: CX.auroraVioletCyan,
                glowColor: CX.violet,
                height: 48,
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
                style: WorkGoFonts.body(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: WorkGoFonts.body(
                    color: isFree ? const Color(0xFF6EE7B7) : CX.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: WorkGoFonts.numeric(
            color: isFree
                ? const Color(0xFF6EE7B7)
                : (isBonus ? CX.amber : Colors.white),
            fontSize: 14,
            fontWeight: FontWeight.w800,
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

    final style = categoryStyle(tradeCategory);
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

    final badgeLabel = worker.isProxy
        ? "PROXY"
        : (worker.verificationBadge.isNotEmpty
            ? worker.verificationBadge.toUpperCase()
            : (worker.isApproved ? "CO-OP CERTIFIED" : "PENDING"));

    return AuroraCard(
      glowColor: style.glow.withValues(alpha: 0.35),
      borderColor: style.glow.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Header: Avatar + Name + Verified Badge ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with online status
              Stack(
                children: [
                  WorkGoAvatar(
                    name: displayName,
                    radius: 26,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: CX.canvas,
                      ),
                      child: PulsingDot(
                        color: isOnline ? CX.success : CX.textMuted,
                        size: 8,
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
                              color: CX.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: worker.isProxy
                                ? CX.cyan.withValues(alpha: 0.2)
                                : (worker.isApproved
                                    ? CX.emerald.withValues(alpha: 0.2)
                                    : CX.amber.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: worker.isProxy
                                  ? CX.cyan.withValues(alpha: 0.5)
                                  : (worker.isApproved
                                      ? CX.emerald.withValues(alpha: 0.6)
                                      : CX.amber.withValues(alpha: 0.6)),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                worker.isApproved
                                    ? Icons.verified_rounded
                                    : Icons.hourglass_top_rounded,
                                size: 11,
                                color: worker.isProxy
                                    ? CX.cyan
                                    : (worker.isApproved
                                        ? const Color(0xFF6EE7B7)
                                        : CX.amber),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                badgeLabel,
                                style: TextStyle(
                                  color: worker.isProxy
                                      ? CX.cyan
                                      : (worker.isApproved
                                          ? const Color(0xFF6EE7B7)
                                          : CX.amber),
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
                    const SizedBox(height: 3),
                    Text(
                      "${worker.skills.join(', ')} • ${worker.experienceYears} yrs exp (${worker.experienceYears >= 5 ? 'Master' : 'Senior'})",
                      style: WorkGoFonts.body(
                        color: CX.textSecondary,
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

          const SizedBox(height: 12),

          // ── 2. Trust & Social Proof Row ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Star Rating & Review Count
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: CX.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      ratingDisplay,
                      style: WorkGoFonts.numeric(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (reviewCount > 0) ...[
                      const SizedBox(width: 3),
                      Text(
                        "($reviewCount)",
                        style: WorkGoFonts.body(
                          color: CX.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                Container(width: 1, height: 14, color: Colors.white12),

                // Homes / Customers Serviced
                Row(
                  children: [
                    const Icon(
                      Icons.home_work_rounded,
                      color: Color(0xFF6EE7B7),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      homesDisplay,
                      style: WorkGoFonts.body(
                        color: CX.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 14, color: Colors.white12),

                // Distance & ETA (Rapido-style)
                Row(
                  children: [
                    const Icon(Icons.near_me_rounded, color: CX.cyan, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      worker.distanceKm > 0
                          ? "${worker.distanceKm.toStringAsFixed(1)} km"
                          : "1.2 km",
                      style: WorkGoFonts.body(
                        color: CX.cyan,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: CX.glassBorder, height: 1),
          ),

          // ── 3. Price + Action Row ──────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Rapido-Style Dynamic Pricing
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
                          style: WorkGoFonts.body(
                            color: CX.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.info_outline_rounded,
                          color: CX.amber,
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
                            color: CX.amber,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "(${fare.formattedBase} + ${fare.formattedTransit})",
                          style: WorkGoFonts.body(
                            color: CX.textSecondary.withValues(alpha: 0.7),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (worker.isProxy)
                GlowButton(
                  label: 'call_to_book'.tr(),
                  icon: Icons.phone_rounded,
                  onPressed: () {
                    final phone = worker.phoneForCalling;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(phone != null && phone.isNotEmpty
                            ? "Calling ${worker.name} at $phone…"
                            : "Calling cooperative direct dispatch line…"),
                        backgroundColor: CX.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    );
                  },
                  gradient: CX.auroraSuccess,
                  glowColor: CX.emerald,
                  isFullWidth: false,
                  height: 38,
                  borderRadius: 12,
                  fontSize: 12,
                )
              else
                GlowButton(
                  label: 'book_now'.tr(),
                  icon: Icons.calendar_month_rounded,
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
                  gradient: CX.auroraVioletCyan,
                  glowColor: CX.violet,
                  isFullWidth: false,
                  height: 38,
                  borderRadius: 12,
                  fontSize: 12,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
