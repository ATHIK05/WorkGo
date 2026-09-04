import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
import '../services/ml_translation_service.dart';
import '../services/voice_recognition_service.dart';
import '../widgets/translated_text.dart';
import 'booking_creation_screen.dart';
import 'symptom_triage_sheet.dart';

class WorkerSearchScreen extends StatefulWidget {
  const WorkerSearchScreen({
    super.key,
    required this.customerId,
    this.initialCategory,
    this.customerLat,
    this.customerLng,
  });

  final String customerId;
  final String? initialCategory;
  final double? customerLat;
  final double? customerLng;

  @override
  State<WorkerSearchScreen> createState() => _WorkerSearchScreenState();
}

class _WorkerSearchScreenState extends State<WorkerSearchScreen>
    with TickerProviderStateMixin {
  final WorkerService _workerService = WorkerService();
  late String _selectedCategory;
  double _radiusKm = -1.0; // -1.0 = All Distances
  final _searchController = TextEditingController();
  late AnimationController _searchFocusCtrl;
  bool _searchFocused = false;
  final FocusNode _searchFocus = FocusNode();

  String _sortBy = "nearest"; // "nearest", "rating", "fare_asc", "fare_desc"
  String _statusFilter = "all"; // "all", "checked_in", "checked_out"
  bool _dismissedFloatingBanner = false;
  double? _customerLat;
  double? _customerLng;
  double _minPrice = 99.0;
  double _maxPrice = 2000.0;

  bool get _hasActiveFilter =>
      _sortBy != "nearest" ||
      _radiusKm > 0 ||
      _statusFilter != "all" ||
      _minPrice > 99.0 ||
      _maxPrice < 2000.0;

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
    _customerLat = widget.customerLat;
    _customerLng = widget.customerLng;
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
    _loadCustomerLocation();
  }

  @override
  void didUpdateWidget(covariant WorkerSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customerLat != oldWidget.customerLat ||
        widget.customerLng != oldWidget.customerLng) {
      if (widget.customerLat != null && widget.customerLng != null && mounted) {
        setState(() {
          _customerLat = widget.customerLat;
          _customerLng = widget.customerLng;
        });
      }
    }
  }

  Future<void> _loadCustomerLocation() async {
    try {
      // 1. High-accuracy live hardware GPS (highest priority)
      final coords = await LocationService.instance.getCurrentCoordinates();
      final hardwareLat = (coords["latitude"] as num?)?.toDouble();
      final hardwareLng = (coords["longitude"] as num?)?.toDouble();
      if (hardwareLat != null && hardwareLng != null && hardwareLat > 1.0 && mounted) {
        setState(() {
          _customerLat = hardwareLat;
          _customerLng = hardwareLng;
        });
        return;
      }

      // If already have valid coordinates from parent, retain them
      if (_customerLat != null && _customerLng != null && _customerLat! > 1.0 && _customerLng! > 1.0) {
        return;
      }

      // 2. Saved user profile address
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.customerId)
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final currAddr = data["currentAddress"];
        final lat = (data["latitude"] as num?)?.toDouble() ??
            (currAddr is Map ? (currAddr["latitude"] as num?)?.toDouble() : null);
        final lng = (data["longitude"] as num?)?.toDouble() ??
            (currAddr is Map ? (currAddr["longitude"] as num?)?.toDouble() : null);
        if (lat != null && lng != null && lat > 1.0 && lng > 1.0 && mounted) {
          setState(() {
            _customerLat = lat;
            _customerLng = lng;
          });
          return;
        }
      }

      // 3. Saved addresses collection
      final addrSnap = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.customerId)
          .collection("addresses")
          .limit(1)
          .get();
      if (addrSnap.docs.isNotEmpty) {
        final d = addrSnap.docs.first.data();
        final lat = (d["latitude"] as num?)?.toDouble();
        final lng = (d["longitude"] as num?)?.toDouble();
        if (lat != null && lng != null && lat > 1.0 && lng > 1.0 && mounted) {
          setState(() {
            _customerLat = lat;
            _customerLng = lng;
          });
          return;
        }
      }

      // 4. Default cooperative regional hub fallback
      if ((_customerLat == null || _customerLat! <= 1.0) && mounted) {
        setState(() {
          _customerLat = 11.3445;
          _customerLng = 77.7327;
        });
      }
    } catch (_) {
      if ((_customerLat == null || _customerLat! <= 1.0) && mounted) {
        setState(() {
          _customerLat = 11.3445;
          _customerLng = 77.7327;
        });
      }
    }
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                  _radiusKm > 0
                      ? 'radar_km'.tr(args: [_radiusKm.toInt().toString()])
                      : 'radar_active'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

            const SizedBox(height: 6),

            // 3. Select Craft Rail Title + Pills (Image 1 Style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "select_craft_specialty".tr(),
                      style: const TextStyle(
                        color: Color(0xFF141416),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedCategory != "All") ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _selectedCategory = "All"),
                      child: Text(
                        "reset".tr(),
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
              decoration: InputDecoration(
                hintText: "search_hint".tr(),
                hintStyle: const TextStyle(
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

          // Filter Sliders Icon (Tune) - Opens Rich Filter & Cost Range Bottom Sheet
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showFilterBottomSheet();
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _hasActiveFilter
                    ? const Color(0xFFEFF6FF)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: _hasActiveFilter
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF6B7280),
                  ),
                  if (_hasActiveFilter)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Microphone Icon - Opens Interactive Voice Search Bottom Sheet
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showVoiceSearchBottomSheet();
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_rounded,
                size: 19,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
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
                  cat.key == "All" ? "all_trades".tr() : cat.title.toLocalizedTrade(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        onlineOnly: false,
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
                  Text(
                    'connection_interrupted'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF141416),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

        var workers = (snapshot.data ?? [])
            .map((w) => w.withCalculatedDistance(_customerLat, _customerLng))
            .toList();

        // 1. Search text filtering
        final query = _searchController.text.trim().toLowerCase();
        if (query.isNotEmpty) {
          workers = workers.where((w) {
            return w.name.toLowerCase().contains(query) ||
                w.skills.any((s) => s.toLowerCase().contains(query)) ||
                (w.phoneForCalling?.contains(query) ?? false) ||
                w.id.toLowerCase().contains(query);
          }).toList();
        }

        // 2. Cost / Visit Rate Range Filtering
        if (_minPrice > 99.0 || _maxPrice < 2000.0) {
          workers = workers.where((w) {
            final rate = w.baseRate;
            final matchMin = rate >= _minPrice;
            final matchMax = _maxPrice >= 2000.0 ? true : rate <= _maxPrice;
            return matchMin && matchMax;
          }).toList();
        }

        // 3. Check-In Status Filtering (All, Checked In, Checked Out)
        if (_statusFilter == "checked_in") {
          workers = workers.where((w) => w.isOnlineOrCheckedIn).toList();
        } else if (_statusFilter == "checked_out") {
          workers = workers.where((w) => !w.isOnlineOrCheckedIn).toList();
        }

        // 4. Radius filtering with real geodesic distance
        if (_radiusKm > 0) {
          final withinRadius = workers.where((w) {
            return w.distanceKm <= _radiusKm + 2.0;
          }).toList();
          if (withinRadius.isNotEmpty) {
            workers = withinRadius;
          }
        }

        // 5. Sorting (Proximity, Rating, Price: Low to High, Price: High to Low)
        if (_sortBy == "rating") {
          workers.sort((a, b) => b.avgRating.compareTo(a.avgRating));
        } else if (_sortBy == "fare" || _sortBy == "fare_asc") {
          // Low to High
          workers.sort((a, b) => a.baseRate.compareTo(b.baseRate));
        } else if (_sortBy == "fare_desc") {
          // High to Low
          workers.sort((a, b) => b.baseRate.compareTo(a.baseRate));
        } else {
          // Nearest: Online/Checked-in artisans prioritized, then closest distance
          workers.sort((a, b) {
            if (a.isOnlineOrCheckedIn != b.isOnlineOrCheckedIn) {
              return a.isOnlineOrCheckedIn ? -1 : 1;
            }
            return a.distanceKm.compareTo(b.distanceKm);
          });
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
                      Expanded(
                        child: Text(
                          'found_artisans_count'.tr(args: [
                            workers.length.toString(),
                            (workers.length == 1 ? 'artisan_singular'.tr() : 'artisan_plural'.tr()),
                          ]),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _sortBy == "rating"
                                ? 'sorted_by_rating'.tr()
                                : (_sortBy == "fare_asc" || _sortBy == "fare"
                                    ? 'sorted_by_price_low_high'.tr()
                                    : (_sortBy == "fare_desc"
                                        ? 'sorted_by_price_high_low'.tr()
                                        : 'sorted_by_proximity'.tr())),
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                          customerLat: _customerLat,
                          customerLng: _customerLng,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Floating Dismissible Radius Expander Banner at bottom of list
            if (!_dismissedFloatingBanner && _radiusKm > 0 && _radiusKm < 50)
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
                              _radiusKm > 0
                                  ? 'showing_within_km'.tr(args: [_radiusKm.toInt().toString()])
                                  : 'showing_all_distances'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF141416),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                                'scan_km'.tr(args: [_radiusKm < 25 ? '25 km' : '50 km']),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
  //  RICH FILTER & COST BOTTOM SHEET WITH RANGE SLIDER
  // ──────────────────────────────────────────
  void _showFilterBottomSheet() {
    double tempMin = _minPrice;
    double tempMax = _maxPrice;
    String tempSort = _sortBy;
    String tempStatus = _statusFilter;
    double tempRadius = _radiusKm;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeFiltersCount = (tempSort != "nearest" ? 1 : 0) +
                (tempRadius > 0 ? 1 : 0) +
                (tempStatus != "all" ? 1 : 0) +
                ((tempMin > 99.0 || tempMax < 2000.0) ? 1 : 0);

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Color(0xFF2563EB),
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
                                        'filters_and_sort'.tr(),
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (activeFiltersCount > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'filters_active_count'.tr(args: [activeFiltersCount.toString()]),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'tune_pricing_proximity'.tr(),
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setModalState(() {
                                tempMin = 99.0;
                                tempMax = 2000.0;
                                tempSort = "nearest";
                                tempStatus = "all";
                                tempRadius = -1.0;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'reset'.tr(),
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Scrollable Filter Sections
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.58,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 1. COST / PRICING FILTER (RANGER) ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'filter_cost_range'.tr(),
                                          style: const TextStyle(
                                            color: Color(0xFF1E293B),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'filter_base_visit_rate'.tr(),
                                          style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 11.5,
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFA7F3D0),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    "₹${tempMin.toInt()} - ${tempMax >= 2000.0 ? '₹2,000+' : '₹${tempMax.toInt()}'}",
                                    style: const TextStyle(
                                      color: Color(0xFF047857),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // RangeSlider Theme
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF10B981),
                                inactiveTrackColor: const Color(0xFFE2E8F0),
                                trackHeight: 5,
                                thumbColor: const Color(0xFF059669),
                                overlayColor: const Color(0x2210B981),
                                valueIndicatorColor: const Color(0xFF0F172A),
                                valueIndicatorTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: RangeSlider(
                                values: RangeValues(tempMin, tempMax),
                                min: 99.0,
                                max: 2000.0,
                                divisions: 38,
                                labels: RangeLabels(
                                  "₹${tempMin.toInt()}",
                                  tempMax >= 2000.0 ? "₹2000+" : "₹${tempMax.toInt()}",
                                ),
                                onChanged: (RangeValues vals) {
                                  setModalState(() {
                                    tempMin = vals.start.roundToDouble();
                                    tempMax = vals.end.roundToDouble();
                                  });
                                },
                              ),
                            ),

                            // Quick Price Preset Chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildModalFilterChip(
                                  label: 'filter_all_rates'.tr(),
                                  isSelected: tempMin <= 99.0 && tempMax >= 2000.0,
                                  onTap: () {
                                    setModalState(() {
                                      tempMin = 99.0;
                                      tempMax = 2000.0;
                                    });
                                  },
                                ),
                                _buildModalFilterChip(
                                  label: 'filter_under_299'.tr(),
                                  isSelected: tempMin <= 99.0 && tempMax == 299.0,
                                  onTap: () {
                                    setModalState(() {
                                      tempMin = 99.0;
                                      tempMax = 299.0;
                                    });
                                  },
                                ),
                                _buildModalFilterChip(
                                  label: "₹300 - ₹799",
                                  isSelected: tempMin == 300.0 && tempMax == 799.0,
                                  onTap: () {
                                    setModalState(() {
                                      tempMin = 300.0;
                                      tempMax = 799.0;
                                    });
                                  },
                                ),
                                _buildModalFilterChip(
                                  label: "₹800+",
                                  isSelected: tempMin == 800.0 && tempMax >= 2000.0,
                                  onTap: () {
                                    setModalState(() {
                                      tempMin = 800.0;
                                      tempMax = 2000.0;
                                    });
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // ── 2. SORTING (Pricing & Proximity) ──
                            Text(
                              'sort_by'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildModalFilterChip(
                                  label: 'sort_proximity'.tr(),
                                  isSelected: tempSort == "nearest",
                                  onTap: () => setModalState(() => tempSort = "nearest"),
                                ),
                                _buildModalFilterChip(
                                  label: 'sort_price_low_high'.tr(),
                                  isSelected: tempSort == "fare_asc" || tempSort == "fare",
                                  onTap: () => setModalState(() => tempSort = "fare_asc"),
                                ),
                                _buildModalFilterChip(
                                  label: 'sort_price_high_low'.tr(),
                                  isSelected: tempSort == "fare_desc",
                                  onTap: () => setModalState(() => tempSort = "fare_desc"),
                                ),
                                _buildModalFilterChip(
                                  label: 'sort_top_rated'.tr(),
                                  isSelected: tempSort == "rating",
                                  onTap: () => setModalState(() => tempSort = "rating"),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // ── 3. STATUS / AVAILABILITY ──
                            Text(
                              'filter_availability'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildModalFilterChip(
                                  label: 'filter_all_artisans'.tr(),
                                  isSelected: tempStatus == "all",
                                  onTap: () => setModalState(() => tempStatus = "all"),
                                ),
                                _buildModalFilterChip(
                                  label: 'filter_checked_in'.tr(),
                                  isSelected: tempStatus == "checked_in",
                                  onTap: () => setModalState(() => tempStatus = "checked_in"),
                                ),
                                _buildModalFilterChip(
                                  label: 'filter_checked_out'.tr(),
                                  isSelected: tempStatus == "checked_out",
                                  onTap: () => setModalState(() => tempStatus = "checked_out"),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // ── 4. MAXIMUM DISTANCE ──
                            Text(
                              'search_radius'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildModalFilterChip(
                                  label: 'all_distances'.tr(),
                                  isSelected: tempRadius <= 0,
                                  onTap: () => setModalState(() => tempRadius = -1.0),
                                ),
                                _buildModalFilterChip(
                                  label: 'within_10km'.tr(),
                                  isSelected: tempRadius == 10.0,
                                  onTap: () => setModalState(() => tempRadius = 10.0),
                                ),
                                _buildModalFilterChip(
                                  label: 'within_25km'.tr(),
                                  isSelected: tempRadius == 25.0,
                                  onTap: () => setModalState(() => tempRadius = 25.0),
                                ),
                                _buildModalFilterChip(
                                  label: 'within_50km'.tr(),
                                  isSelected: tempRadius == 50.0,
                                  onTap: () => setModalState(() => tempRadius = 50.0),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    // Apply Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _minPrice = tempMin;
                              _maxPrice = tempMax;
                              _sortBy = tempSort;
                              _statusFilter = tempStatus;
                              _radiusKm = tempRadius;
                              _dismissedFloatingBanner = false;
                            });
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF141416),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'apply_filters'.tr(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      },
    );
  }

  Widget _buildModalFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1.1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  VOICE SEARCH BOTTOM SHEET TRIGGER
  // ──────────────────────────────────────────
  void _showVoiceSearchBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _VoiceSearchSheet(
          customerId: widget.customerId,
          initialQuery: _searchController.text,
          customerLat: widget.customerLat,
          customerLng: widget.customerLng,
          onQuerySelected: (query) {
            setState(() {
              _searchController.text = query;
              _searchController.selection = TextSelection.fromPosition(
                TextPosition(offset: query.length),
              );
            });
          },
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
            // Active filters warning/recovery banner
            if (_hasActiveFilter || _searchController.text.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_alt_off_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _minPrice > 99.0 || _maxPrice < 2000.0
                            ? 'no_artisans_in_price_range'.tr(args: [
                                _minPrice.toInt().toString(),
                                _maxPrice >= 2000.0 ? '₹2000+' : '₹${_maxPrice.toInt()}',
                              ])
                            : 'active_filters_restricting'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _minPrice = 99.0;
                          _maxPrice = 2000.0;
                          _statusFilter = "all";
                          _radiusKm = -1.0;
                          _sortBy = "nearest";
                          _searchController.clear();
                        });
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'reset_all'.tr(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Radar Scanning Beacon
            _RadarScanningBeacon(
              category: _selectedCategory,
              radiusKm: _radiusKm,
            ),
            const SizedBox(height: 22),

            // 2. Expand Radius 1-Tap Recovery Button
            if (_radiusKm > 0 && _radiusKm < 50) ...[
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
                          Text(
                            'widen_search_coverage'.tr(),
                            style: const TextStyle(
                              color: Color(0xFF141416),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'expand_radar_scan'.tr(args: [_radiusKm < 25 ? '25 km' : '50 km']),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                          'scan_km'.tr(args: [_radiusKm < 25 ? '25 km' : '50 km']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'active_trades_nearby'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF141416),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                                    "${meta.key == 'All' ? 'all_trades'.tr() : meta.title.toLocalizedTrade()} (${e.value})",
                                    style: const TextStyle(
                                      color: Color(0xFF141416),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
//  VOICE SEARCH BOTTOM SHEET (PULSING MIC + WAVEFORM + POPULAR SHORTCUTS)
// ──────────────────────────────────────────────────────
class _VoiceSearchSheet extends StatefulWidget {
  const _VoiceSearchSheet({
    required this.customerId,
    required this.initialQuery,
    required this.onQuerySelected,
    this.customerLat,
    this.customerLng,
  });

  final String customerId;
  final String initialQuery;
  final ValueChanged<String> onQuerySelected;
  final double? customerLat;
  final double? customerLng;

  @override
  State<_VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<_VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  final VoiceRecognitionService _voiceService = VoiceRecognitionService.instance;

  bool _isListening = false;
  double _soundLevel = 0.0;
  String _spokenWords = '';
  bool _isSymptomDetected = false;
  String _statusText = 'listening_speak_trade'.tr();

  final List<({IconData icon, String label})> _popularPrompts = const [
    (icon: Icons.water_drop_rounded, label: "Plumber"),
    (icon: Icons.bolt_rounded, label: "Electrician"),
    (icon: Icons.ac_unit_rounded, label: "Appliance Repair"),
    (icon: Icons.carpenter_rounded, label: "Carpentry"),
    (icon: Icons.format_paint_rounded, label: "Painting"),
    (icon: Icons.cleaning_services_rounded, label: "Cleaning"),
    (icon: Icons.handyman_rounded, label: "Masonry"),
    (icon: Icons.yard_rounded, label: "Gardening"),
  ];

  final List<String> _popularSymptoms = const [
    'Water motor humming',
    'AC leaking water',
    'Geyser not heating',
    'MCB tripping repeatedly',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _voiceService.cancelListening();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _statusText = 'listening_speak_clearly'.tr();
      _soundLevel = 0.0;
    });

    final available = await _voiceService.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        final isSymptom = _voiceService.isLikelySymptomQuery(words);
        setState(() {
          _spokenWords = words;
          _isSymptomDetected = isSymptom;
        });

        if (isFinal && words.trim().isNotEmpty) {
          _handleFinalSpokenQuery(words.trim(), isSymptom);
        }
      },
      onSoundLevel: (level) {
        if (!mounted) return;
        setState(() {
          _soundLevel = level;
        });
      },
    );

    if (!available && mounted) {
      setState(() {
        _isListening = false;
        _statusText = 'mic_unavailable'.tr();
      });
    }
  }

  Future<void> _stopListening() async {
    await _voiceService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    }
  }

  void _handleFinalSpokenQuery(String query, bool isSymptom) {
    final isProblem = isSymptom ||
        _voiceService.isLikelySymptomQuery(query) ||
        SymptomCatalog.matchSymptom(query).confidence >= 0.65;

    if (isProblem) {
      setState(() {
        _statusText = 'problem_detected_triage'.tr();
      });
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _launchAiTriage(query);
      });
    } else {
      // Direct trade search query
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _selectQuery(query);
      });
    }
  }

  void _selectQuery(String query) {
    HapticFeedback.mediumImpact();
    _voiceService.stopListening();
    widget.onQuerySelected(query);
    Navigator.of(context).pop();
  }

  void _launchAiTriage(String query) {
    HapticFeedback.mediumImpact();
    _voiceService.stopListening();
    Navigator.of(context).pop();
    SymptomTriageSheet.show(
      context,
      customerId: widget.customerId,
      initialQuery: query,
      customerLat: widget.customerLat,
      customerLng: widget.customerLng,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CX.violet.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: CX.amberDark,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'voice_search_title'.tr(),
                                style: WorkGoFonts.heading(
                                  color: const Color(0xFF0F172A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'voice_search_subtitle'.tr(),
                                style: WorkGoFonts.body(
                                  color: const Color(0xFF64748B),
                                  fontSize: 12,
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
                  GestureDetector(
                    onTap: () {
                      _voiceService.stopListening();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF1F5F9),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pulsing Mic Beacon with concentric ripple waves reacting to decibels
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final val = _pulseCtrl.value;
                final soundScale = (_soundLevel * 25.0);
                return SizedBox(
                  height: 110,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Ripple Ring
                        Container(
                          width: 80 + (val * 30) + soundScale,
                          height: 80 + (val * 30) + soundScale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isListening ? CX.amberDark : const Color(0xFF94A3B8))
                                .withValues(alpha: (1.0 - val) * 0.18),
                          ),
                        ),
                        // Inner Ripple Ring
                        Container(
                          width: 66 + (val * 16) + (soundScale * 0.6),
                          height: 66 + (val * 16) + (soundScale * 0.6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isListening ? CX.amberDark : const Color(0xFF94A3B8))
                                .withValues(alpha: (1.0 - val) * 0.30),
                          ),
                        ),
                        // Central Core Mic
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            if (_isListening) {
                              _stopListening();
                            } else {
                              _startListening();
                            }
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isListening
                                    ? [CX.amberDark, const Color(0xFFB45309)]
                                    : [const Color(0xFF475569), const Color(0xFF334155)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening ? CX.amberDark : const Color(0xFF475569))
                                      .withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // Live Decibel Waveform Bars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(7, (i) {
                final baseSin = math.sin((_pulseCtrl.value * math.pi) + (i * 0.55)).abs();
                final dynamicH = 6.0 + (_soundLevel * 20.0) + (baseSin * (_isListening ? 10.0 : 2.0));
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: 4,
                  height: dynamicH.clamp(4.0, 24.0),
                  decoration: BoxDecoration(
                    color: _isListening ? CX.amberDark : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 10),

            // Live Transcribed Text or Status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _spokenWords.isNotEmpty ? '"$_spokenWords"' : _statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _spokenWords.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  fontSize: _spokenWords.isNotEmpty ? 15 : 13,
                  fontWeight: _spokenWords.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // AI Symptom Triage Action Banner (if symptom detected)
            if (_isSymptomDetected && _spokenWords.isNotEmpty) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CX.amberDark.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.troubleshoot_rounded,
                          color: CX.amberDark,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'household_problem_detected'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF78350F),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'diagnose_root_causes'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _launchAiTriage(_spokenWords),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CX.amberDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'ai_triage_btn'.tr(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            const SizedBox(height: 12),

            // Quick Symptom Suggestions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: CX.amberDark, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'common_problems_triage'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _popularSymptoms.map((symptom) {
                  return GestureDetector(
                    onTap: () => _launchAiTriage(symptom),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CX.amberDark.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 13, color: CX.amberDark),
                          const SizedBox(width: 4),
                          Text(
                            symptom,
                            style: const TextStyle(
                              color: Color(0xFF78350F),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // Quick Tap Trade Suggestions (Clean Material Icons, zero emojis)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'popular_trades'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: _popularPrompts.map((p) {
                  return GestureDetector(
                    onTap: () => _selectQuery(p.label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(p.icon, size: 14, color: const Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Text(
                            p.label,
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
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
              ? (widget.radiusKm > 0
                  ? 'scanning_km_radar'.tr(args: [widget.radiusKm.toInt().toString()])
                  : 'scanning_all_artisans'.tr())
              : (widget.radiusKm > 0
                  ? 'no_artisans_in_km'.tr(args: [widget.category, widget.radiusKm.toInt().toString()])
                  : 'no_artisans_online'.tr(args: [widget.category])),
          style: const TextStyle(
            color: Color(0xFF141416),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          widget.radiusKm > 0
              ? 'artisans_busy_km'.tr(args: [widget.category, widget.radiusKm.toInt().toString()])
              : 'artisans_busy'.tr(args: [widget.category]),
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
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
    this.customerLat,
    this.customerLng,
  });

  final Worker worker;
  final String selectedCategory;
  final String customerId;
  final double? customerLat;
  final double? customerLng;

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
                          'transparent_pricing_with_worker'.tr(args: [
                            MlTranslationService.instance.translateSync(
                              worker.name,
                              context.locale.languageCode,
                            ),
                          ]),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      subtitle: 'inspection_basic_labour'.tr(args: [fare.category]),
                    ),
                    const Divider(color: Color(0xFFE2E8F0), height: 18),
                    _fareRow(
                      'transit_distance_fare'.tr(),
                      "₹${fare.distanceTransitFare.toStringAsFixed(0)}",
                      subtitle: 'transit_km_rate'.tr(args: [fare.distanceKm.toStringAsFixed(1), fare.perKmRate.toStringAsFixed(0)]),
                    ),
                    if (fare.experienceBonus > 0) ...[
                      const Divider(color: Color(0xFFE2E8F0), height: 18),
                      _fareRow(
                        'experience_bonus'.tr(),
                        "+₹${fare.experienceBonus.toStringAsFixed(0)}",
                        subtitle: 'senior_master_artisan'.tr(args: [fare.experienceYears.toString()]),
                        isBonus: true,
                      ),
                    ],
                    const Divider(color: Color(0xFFE2E8F0), height: 18),
                    _fareRow(
                      'coop_platform_cut'.tr(),
                      'zero_cut'.tr(),
                      subtitle: 'direct_to_artisan_desc'.tr(),
                      isFree: true,
                    ),
                    const Divider(color: Color(0xFFCBD5E1), height: 22, thickness: 1.2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'total_estimated_fare'.tr(),
                            style: const TextStyle(
                              color: Color(0xFF141416),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                  children: [
                    const Icon(Icons.shield_rounded, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'coop_guarantee_badge'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                        worker: worker.withCalculatedDistance(customerLat, customerLng),
                        customerLat: customerLat,
                        customerLng: customerLng,
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
                    children: [
                      Flexible(
                        child: Text(
                          'book_this_artisan'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isFree ? const Color(0xFF059669) : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: isFree ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
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

    final isCheckedIn = worker.isOnlineOrCheckedIn;

    // Calculate Dynamic Fare using Cooperative Pricing Engine with REAL-TIME distance
    final realDist = worker.calculateDistanceKm(customerLat, customerLng);
    final fare = CooperativePricingEngine.instance.calculateFare(
      category: tradeCategory,
      distanceKm: realDist,
      experienceYears: worker.experienceYears,
      customBaseRate: worker.baseRate,
      customPerKmRate: worker.perKmRate,
    );

    final displayName = worker.name.isNotEmpty
        ? worker.name
        : (worker.isProxy ? 'artisan_partner'.tr() : 'coop_artisan'.tr());

    final hasRatings = worker.totalRatings > 0 || worker.totalReviews > 0;
    final ratingDisplay = worker.avgRating > 0
        ? worker.avgRating.toStringAsFixed(1)
        : (hasRatings ? "5.0" : 'badge_new'.trSafe("New"));
    final reviewCount = worker.totalReviews > 0
        ? worker.totalReviews
        : (worker.totalRatings > 0 ? worker.totalRatings : 0);

    final homesDisplay = worker.homesServiced > 0
        ? 'homes_count'.tr(args: [worker.homesServiced.toString()])
        : (worker.totalRatings > 0 ? 'jobs_count'.tr(args: [worker.totalRatings.toString()]) : 'verified_pro'.tr());

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
                    avatarBase64: worker.avatarBase64,
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
                          color: isCheckedIn ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
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
                          child: TranslatedText(
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
                      "${worker.skills.map((s) => s.toLocalizedTrade()).join(', ')} • ${'years_exp'.tr(args: [worker.experienceYears.toString()])}",
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCheckedIn ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCheckedIn ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.5,
                            height: 6.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCheckedIn ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                              boxShadow: isCheckedIn
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                        blurRadius: 3,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 4.5),
                          Flexible(
                            child: Text(
                              isCheckedIn ? 'filter_checked_in'.tr() : 'filter_checked_out'.tr(),
                              style: TextStyle(
                                color: isCheckedIn ? const Color(0xFF065F46) : const Color(0xFF475569),
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
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.home_work_rounded,
                        color: Color(0xFF059669),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          homesDisplay,
                          style: const TextStyle(
                            color: Color(0xFF334155),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(width: 1, height: 14, color: const Color(0xFFE2E8F0)),
                ),

                // Distance
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFF2563EB), size: 13),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          worker.formattedDistanceString(customerLat, customerLng),
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(width: 1, height: 14, color: const Color(0xFFE2E8F0)),
                ),

                // Escrow Safety
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded, color: Color(0xFF7C3AED), size: 13),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'k50_cover'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF7C3AED),
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
              Expanded(
                child: GestureDetector(
                  onTap: () => _showFareBreakdownSheet(context, fare),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'est_fare'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                          Flexible(
                            child: Text(
                              "(${fare.formattedBase} + ${fare.formattedTransit})",
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
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
              ),
              const SizedBox(width: 8),

              // Sleek Dark Pill Action Button (Image 1 Style)
              Flexible(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => BookingCreationScreen(
                          serviceCategory: tradeCategory,
                          customerId: customerId,
                          targetWorkerId: worker.id,
                          worker: worker.withCalculatedDistance(customerLat, customerLng),
                          customerLat: customerLat,
                          customerLng: customerLng,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCheckedIn ? const Color(0xFF141416) : const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    minimumSize: const Size(0, 42),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          isCheckedIn ? 'book_live'.tr() : 'book_artisan'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white24,
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
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
