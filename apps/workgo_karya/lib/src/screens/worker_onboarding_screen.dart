import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workgo_core/workgo_core.dart';

class _TradeItem {
  final String key;
  final String imagePath;
  final IconData icon;
  final Color tintColor;
  final Color bgTint;
  final String fallbackTitle;
  final String fallbackDesc;

  const _TradeItem({
    required this.key,
    required this.imagePath,
    required this.icon,
    required this.tintColor,
    required this.bgTint,
    required this.fallbackTitle,
    required this.fallbackDesc,
  });
}

class WorkerOnboardingScreen extends StatefulWidget {
  const WorkerOnboardingScreen({
    super.key,
    required this.worker,
    required this.onComplete,
  });

  final Worker worker;
  final VoidCallback onComplete;

  @override
  State<WorkerOnboardingScreen> createState() => _WorkerOnboardingScreenState();
}

class _WorkerOnboardingScreenState extends State<WorkerOnboardingScreen> {
  final _workerService = WorkerService();

  // Main flow step: 0 = Trades Selection (8 full screens), 1 = Location, 2 = Working Hours
  int _mainStep = 0;

  // Sub-page controller for the 8 Trade Walkthrough Screens
  final PageController _servicePageController = PageController();
  int _currentServiceIndex = 0;

  final Set<String> _selectedSkills = {};

  double _serviceRadiusKm = 10.0;
  String _selectedCity = "Chennai";
  final TextEditingController _streetAreaCtrl = TextEditingController();
  final TextEditingController _pincodeCtrl = TextEditingController();
  late final TextEditingController _phoneCtrl;
  double _latitude = 13.0827;
  double _longitude = 80.2707;
  String _formattedAddress = "";
  bool _isDetectingGps = false;
  String _workingHoursStart = "08:00";
  String _workingHoursEnd = "20:00";
  bool _isSaving = false;

  static const List<_TradeItem> _tradeItems = [
    _TradeItem(
      key: "Plumbing",
      imagePath: "assets/images/plumber.png",
      icon: Icons.plumbing_rounded,
      tintColor: Color(0xFFD97706),
      bgTint: Color(0xFFFEF3C7),
      fallbackTitle: "Plumbing",
      fallbackDesc:
          "Pipes, faucets, water heaters, leakage repairs and drainage lines.",
    ),
    _TradeItem(
      key: "Electrical",
      imagePath: "assets/images/electrian.png",
      icon: Icons.electric_bolt_rounded,
      tintColor: Color(0xFFD97706),
      bgTint: Color(0xFFFEF3C7),
      fallbackTitle: "Electrical",
      fallbackDesc:
          "Wiring, switchboards, lighting fixtures, circuit breakers and safety checks.",
    ),
    _TradeItem(
      key: "Carpentry",
      imagePath: "assets/images/carpentry.png",
      icon: Icons.carpenter_rounded,
      tintColor: Color(0xFFD97706),
      bgTint: Color(0xFFFEF3C7),
      fallbackTitle: "Carpentry",
      fallbackDesc:
          "Furniture assembly, wooden doors, locks, custom cabinetry and woodwork.",
    ),
    _TradeItem(
      key: "Cleaning",
      imagePath: "assets/images/cleaning.png",
      icon: Icons.cleaning_services_rounded,
      tintColor: Color(0xFFD97706),
      bgTint: Color(0xFFFEF3C7),
      fallbackTitle: "Cleaning",
      fallbackDesc:
          "Deep home sanitization, floor scrubbing, kitchen, bathroom and upholstery cleaning.",
    ),
    _TradeItem(
      key: "Painting",
      imagePath: "assets/images/painting.png",
      icon: Icons.format_paint_rounded,
      tintColor: Color(0xFFD97706),
      bgTint: Color(0xFFFEF3C7),
      fallbackTitle: "Painting",
      fallbackDesc:
          "Interior walls, exterior weatherproofing, enamel finishes and surface touchups.",
    ),
    _TradeItem(
      key: "Appliance Repair",
      imagePath: "assets/images/appliance_repair.png",
      icon: Icons.home_repair_service_rounded,
      tintColor: Color(0xFFD97706),
      bgTint: Color(0xFFFEF3C7),
      fallbackTitle: "Appliance Repair",
      fallbackDesc:
          "Air conditioners, refrigerators, washing machines, geysers and kitchen appliances.",
    ),
    _TradeItem(
      key: "Masonry",
      imagePath: "assets/images/masonry.png",
      icon: Icons.foundation_rounded,
      tintColor: Color(0xFFD97706),
      bgTint: Color(0xFFFEF3C7),
      fallbackTitle: "Masonry",
      fallbackDesc:
          "Brickwork, tile laying, concrete plastering, waterproofing and civil repairs.",
    ),
    _TradeItem(
      key: "Gardening",
      imagePath: "assets/images/gardening.png",
      icon: Icons.yard_rounded,
      tintColor: Color(0xFFD97706),
      bgTint: Color(0xFFFEF3C7),
      fallbackTitle: "Gardening",
      fallbackDesc:
          "Lawn trimming, plant maintenance, garden landscaping, pruning and soil fertilizing.",
    ),
  ];

  final List<String> _tamilNaduDistricts = [
    "Erode",
    "Coimbatore",
    "Tirupur",
    "Salem",
    "Madurai",
    "Trichy",
    "Chennai",
    "Namakkal",
    "Karur",
    "Dindigul",
    "Thanjavur",
    "Vellore",
    "Tirunelveli",
    "Kanchipuram",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.worker.skills.isNotEmpty) {
      _selectedSkills.addAll(widget.worker.skills);
    } else {
      _selectedSkills.add("Plumbing");
    }

    _serviceRadiusKm = widget.worker.serviceRadiusKm.clamp(1.0, 30.0);
    _workingHoursStart = widget.worker.workingHoursStart;
    _workingHoursEnd = widget.worker.workingHoursEnd;
    _phoneCtrl = TextEditingController(
      text: widget.worker.phoneForCalling?.replaceFirst('+91', '') ?? '',
    );

    // Detect GPS location on screen launch
    _autoDetectGps();
  }

  @override
  void dispose() {
    _servicePageController.dispose();
    _streetAreaCtrl.dispose();
    _pincodeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoDetectGps() async {
    if (!mounted) return;
    setState(() => _isDetectingGps = true);

    try {
      final locationService = LocationService();
      final coords = await locationService.getCurrentCoordinates();
      final lat = coords["latitude"]!;
      final lon = coords["longitude"]!;

      final decoded = await locationService.reverseGeocode(lat, lon);

      if (mounted) {
        setState(() {
          _latitude = lat;
          _longitude = lon;
          if (decoded.streetArea.isNotEmpty) {
            _streetAreaCtrl.text = decoded.streetArea;
          }
          if (decoded.pincode.isNotEmpty) {
            _pincodeCtrl.text = decoded.pincode;
          }
          if (_tamilNaduDistricts.contains(decoded.city)) {
            _selectedCity = decoded.city;
          } else if (decoded.city.isNotEmpty) {
            _selectedCity = decoded.city;
            if (!_tamilNaduDistricts.contains(_selectedCity)) {
              _tamilNaduDistricts.insert(0, _selectedCity);
            }
          }
          _formattedAddress = decoded.formattedAddress;
          _isDetectingGps = false;
        });
      }
    } catch (e) {
      debugPrint("WorkerOnboarding: GPS detection note: $e");
      if (mounted) setState(() => _isDetectingGps = false);
    }
  }

  String _getLocalizedSkill(String skill) {
    final key = switch (skill.toLowerCase()) {
      'plumbing' => 'cat_plumbing',
      'electrical' => 'cat_electrical',
      'carpentry' => 'cat_carpentry',
      'cleaning' => 'cat_cleaning',
      'painting' => 'cat_painting',
      'appliance repair' || 'air conditioner' => 'cat_appliance',
      'masonry' => 'cat_masonry',
      'gardening' => 'cat_gardening',
      _ => null,
    };
    if (key != null) {
      final trVal = key.trSafe(skill);
      if (trVal.isNotEmpty && trVal != key) return trVal;
    }
    return skill;
  }

  String _getLocalizedTradeDesc(String skill, String fallback) {
    final key = switch (skill.toLowerCase()) {
      'plumbing' => 'trade_desc_plumbing',
      'electrical' => 'trade_desc_electrical',
      'carpentry' => 'trade_desc_carpentry',
      'cleaning' => 'trade_desc_cleaning',
      'painting' => 'trade_desc_painting',
      'appliance repair' || 'air conditioner' => 'trade_desc_appliance',
      'masonry' => 'trade_desc_masonry',
      'gardening' => 'trade_desc_gardening',
      _ => null,
    };
    if (key != null) {
      final trVal = key.trSafe(fallback);
      if (trVal.isNotEmpty && trVal != key) return trVal;
    }
    return fallback;
  }

  int _calculateDailyHours() {
    try {
      final startParts = _workingHoursStart.split(':').map(int.parse).toList();
      final endParts = _workingHoursEnd.split(':').map(int.parse).toList();
      final startMinutes = startParts[0] * 60 + startParts[1];
      final endMinutes = endParts[0] * 60 + endParts[1];
      final diff = (endMinutes - startMinutes) / 60;
      return diff > 0 ? diff.round() : (24 + diff.round());
    } catch (_) {
      return 12;
    }
  }

  String _getCurrentLanguageName() {
    final code = context.locale.languageCode;
    final lang = WorkGoLocale.allLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => const WorkGoLanguageInfo(
        code: 'en',
        englishName: 'English',
        nativeName: 'English',
        region: 'India',
        bcp47: 'en-IN',
      ),
    );
    return lang.nativeName;
  }

  Future<void> _completeOnboarding() async {
    if (_selectedSkills.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'select_at_least_one_skill_onboarding'.trSafe(
              "Please select at least one trade skill you can do",
            ),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final streetText = _streetAreaCtrl.text.trim();
      final pincodeText = _pincodeCtrl.text.trim();
      final detailedAreaSummary = streetText.isNotEmpty
          ? "$streetText, $_selectedCity"
          : "$_selectedCity Central";
      final fullAddr = _formattedAddress.isNotEmpty
          ? _formattedAddress
          : "$detailedAreaSummary $pincodeText, Tamil Nadu";

      final defaultBaseAddress = UserAddress(
        id: "addr_${DateTime.now().millisecondsSinceEpoch}",
        label: AddressLabel.work,
        customLabel: "Base Workshop",
        flatBuilding: "",
        streetArea: streetText,
        city: _selectedCity,
        state: "Tamil Nadu",
        pincode: pincodeText,
        formattedAddress: fullAddr,
        latitude: _latitude,
        longitude: _longitude,
        isDefault: true,
        createdAt: DateTime.now(),
      );

      final phoneRaw = _phoneCtrl.text.trim();
      final normalizedPhone = phoneRaw.startsWith('+91')
          ? phoneRaw
          : (phoneRaw.isNotEmpty
                ? '+91$phoneRaw'
                : widget.worker.phoneForCalling);

      final updated = widget.worker.copyWith(
        skills: _selectedSkills.toList(),
        serviceRadiusKm: _serviceRadiusKm,
        phoneForCalling: normalizedPhone,
        preferredAreas: [_selectedCity, detailedAreaSummary],
        baseArea: detailedAreaSummary,
        baseAddress: defaultBaseAddress,
        addresses: [defaultBaseAddress],
        latitude: _latitude,
        longitude: _longitude,
        workingHoursStart: _workingHoursStart,
        workingHoursEnd: _workingHoursEnd,
        availabilityStatus: AvailabilityStatus.offline,
        isCheckedIn: false,
      );

      await _workerService.upsertWorkerProfile(updated);

      if (normalizedPhone != null) {
        try {
          await FirebaseFirestore.instance
              .collection("users")
              .doc(widget.worker.userId)
              .set({"phoneNumber": normalizedPhone}, SetOptions(merge: true));
        } catch (_) {}
      }

      // Save complete address to subcollection and top-level fields
      final locationService = LocationService();
      await locationService.saveAddress(
        widget.worker.userId,
        defaultBaseAddress,
        collection: "workers",
      );

      // Save persistent anti-loop flags
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        "worker_onboarding_done_${widget.worker.userId}",
        true,
      );
      await prefs.setBool("worker_loc_done_${widget.worker.userId}", true);

      await FirebaseFirestore.instance
          .collection("workers")
          .doc(widget.worker.id)
          .set({
            "hasCompletedOnboarding": true,
            "skills": _selectedSkills.toList(),
            "phoneForCalling": normalizedPhone,
            "phone": normalizedPhone,
            "phoneNumber": normalizedPhone,
            "serviceLocation": detailedAreaSummary,
            "primaryArea": detailedAreaSummary,
            "baseAddress": defaultBaseAddress.toMap(),
            "latitude": _latitude,
            "longitude": _longitude,
          }, SetOptions(merge: true));

      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${'error_saving_profile'.trSafe('Error saving profile')}: $e",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showLanguageSelectionSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.72,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
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
                            'select_language_title'.trSafe('Select Language'),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'official_languages_count'.trSafe(
                              "22 Official Indian Languages",
                            ),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF64748B),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: WorkGoLocale.allLanguages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final lang = WorkGoLocale.allLanguages[index];
                    final isSelected = lang.code == context.locale.languageCode;
                    return InkWell(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await context.setLocale(Locale(lang.code));
                        WorkGoLocale.setLocaleCode(lang.code);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFFBEB)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.nativeName,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: isSelected
                                          ? const Color(0xFF92400E)
                                          : const Color(0xFF0F172A),
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    "${lang.englishName} • ${lang.region}",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF64748B),
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFFF59E0B),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _buildCurrentMainStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentMainStep() {
    switch (_mainStep) {
      case 0:
        return _buildStep1Walkthrough8Services();
      case 1:
        return _buildStep2LocationView();
      case 2:
        return _buildStep3WorkingHoursView();
      default:
        return _buildStep1Walkthrough8Services();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 1: 8 SCREENS WITH FULL IMAGE + SKIP & ACCEPT (Matching Reference Template)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildStep1Walkthrough8Services() {
    final currentTrade = _tradeItems[_currentServiceIndex];
    final isSelected = _selectedSkills.contains(currentTrade.key);

    return Column(
      key: const ValueKey("step1_walkthrough"),
      children: [
        // ── Top Bar: Discreet Back Arrow & 22-Language Switcher (Yellow & White Theme) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentServiceIndex > 0)
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _servicePageController.previousPage(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Color(0xFF78350F),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'prev_service_tooltip'.trSafe("Previous service"),
                )
              else
                const SizedBox(width: 24),

              // Optional shortcut pill if at least 1 trade is already selected (Yellow & White)
              if (_selectedSkills.isNotEmpty)
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _mainStep = 1);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${_selectedSkills.length} ${'onboarding_skills_selected'.trSafe('selected')} ➔",
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFB45309),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(width: 24),

              // 22-Language Selector Chip (Yellow & White Accent)
              InkWell(
                onTap: () => _showLanguageSelectionSheet(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08D97706),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.translate_rounded,
                        size: 14,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getCurrentLanguageName(),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF78350F),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: Color(0xFFB45309),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Main Walkthrough Area: Swiping Image & Text + FIXED Stationary Dots ──
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalHeight = constraints.maxHeight;
              const dotsHeight = 20.0;
              const textHeight = 76.0;
              // Maximize hero image to fill the screen and eliminate unwanted whitespace
              final imageHeight = totalHeight - textHeight - dotsHeight;

              return Stack(
                children: [
                  // 1. PageView: ONLY the Image and Title/Subtitle swipe horizontally together
                  PageView.builder(
                    controller: _servicePageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _tradeItems.length,
                    onPageChanged: (idx) {
                      setState(() => _currentServiceIndex = idx);
                    },
                    itemBuilder: (context, index) {
                      final trade = _tradeItems[index];
                      final isSkillSelected = _selectedSkills.contains(
                        trade.key,
                      );

                      return Column(
                        children: [
                          // Top: Large Service Illustration (Movable)
                          SizedBox(
                            height: imageHeight,
                            width: double.infinity,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [

                                // Large, full-scale illustration with polished curved edges (eliminating sharp rectangle corners)
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    child: Center(
                                      child: AspectRatio(
                                        aspectRatio: 1788 / 2400,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(18),
                                          child: Image.asset(
                                            trade.imagePath,
                                            fit: BoxFit.cover,
                                            alignment: Alignment.center,
                                            filterQuality: FilterQuality.high,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // If accepted, show status pill at top right (tap to remove)
                                if (isSkillSelected)
                                  Positioned(
                                    top: 10,
                                    right: 18,
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(
                                          () =>
                                              _selectedSkills.remove(trade.key),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFDE68A),
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x18D97706),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.check_rounded,
                                              color: Color(0xFFD97706),
                                              size: 13,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'trade_accepted_badge'.trSafe(
                                                "Added to Profile",
                                              ),
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    color: const Color(
                                                      0xFF92400E,
                                                    ),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Transparent reserved gap where the stationary dots sit
                          const SizedBox(height: dotsHeight),

                          // Bottom: Service Title & Subtitle Scope Description (Movable)
                          SizedBox(
                            height: textHeight,
                            width: double.infinity,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Text(
                                    _getLocalizedSkill(trade.key),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF0F172A),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    _getLocalizedTradeDesc(
                                      trade.key,
                                      trade.fallbackDesc,
                                    ),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF64748B),
                                      fontSize: 13,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // 2. Stationary Static 8-Dot Row (NOT MOVABLE ON SWIPE)
                  Positioned(
                    top: imageHeight,
                    left: 0,
                    right: 0,
                    height: dotsHeight,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_tradeItems.length, (dotIdx) {
                          final isCurrent = dotIdx == _currentServiceIndex;
                          final isTradeAccepted = _selectedSkills.contains(
                            _tradeItems[dotIdx].key,
                          );

                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _servicePageController.animateToPage(
                                dotIdx,
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeInOutCubic,
                              );
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 3.5,
                              ),
                              width: isCurrent ? 24 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFFD97706) // Rich Warm Amber
                                    : (isTradeAccepted
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFFDE68A)), // Warm Sunny Yellow
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // ── Bottom Fixed Action Bar: Skip & Accept (Yellow & White Theme) ──
        _buildStep1BottomActions(currentTrade, isSelected),
      ],
    );
  }

  Widget _buildStep1BottomActions(_TradeItem currentTrade, bool isSelected) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── SKIP BUTTON (Yellow/Amber & White theme) ──
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (_currentServiceIndex < _tradeItems.length - 1) {
                _servicePageController.nextPage(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                );
              } else {
                // On 8th screen: proceed to Location if at least 1 trade chosen
                if (_selectedSkills.isNotEmpty) {
                  setState(() => _mainStep = 1);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'select_at_least_one_skill_onboarding'.trSafe(
                          "Please select at least one trade skill you can do",
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      backgroundColor: const Color(0xFFD97706),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              'btn_skip'.trSafe("Skip"),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFD97706),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── ACCEPT BUTTON (Solid Warm Yellow/Amber button with crisp white text) ──
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _selectedSkills.add(currentTrade.key);
              });

              if (_currentServiceIndex < _tradeItems.length - 1) {
                _servicePageController.nextPage(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                );
              } else {
                // Last trade accepted: advance directly to Location
                setState(() => _mainStep = 1);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected
                  ? const Color(0xFFD97706)
                  : const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: const Color(0x35F59E0B),
              padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              isSelected
                  ? 'btn_accepted'.trSafe("Accepted ✓")
                  : 'btn_accept'.trSafe("Accept"),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 2: LOCATION & COVERAGE RADIUS
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildStep2LocationView() {
    return Column(
      key: const ValueKey("step2_location"),
      children: [
        // Top Header
        _buildStepHeader(
          badgeText: 'onboarding_step_2_badge'.trSafe("Step 2 of 3 • Location"),
          onBack: () => setState(() => _mainStep = 0),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero Banner ──
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14B45309),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFEA580C),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'onboarding_step2_title'.trSafe(
                                "Operating Base & Coverage",
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF78350F),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'onboarding_step2_sub'.trSafe(
                                "Set your workshop location and customer dispatch radius",
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF92400E),
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── 1-Tap Live Hardware GPS Card ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: _isDetectingGps
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF16A34A),
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: Color(0xFF16A34A),
                                size: 20,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isDetectingGps
                                  ? 'detecting_gps'.trSafe(
                                      "Detecting real-time GPS...",
                                    )
                                  : 'live_hardware_gps_loc'.trSafe(
                                      "Live Hardware GPS Location",
                                    ),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF0F172A),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formattedAddress.isNotEmpty
                                  ? _formattedAddress
                                  : "${_streetAreaCtrl.text}, $_selectedCity ${_pincodeCtrl.text}",
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF64748B),
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _isDetectingGps ? null : _autoDetectGps,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        child: Text(
                          'redetect_btn'.trSafe("Re-detect"),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Operating District / City ──
                Text(
                  'operating_district_city'.trSafe("Operating District / City"),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _tamilNaduDistricts.contains(_selectedCity)
                          ? _selectedCity
                          : _tamilNaduDistricts.first,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF64748B),
                      ),
                      items: _tamilNaduDistricts.map((city) {
                        return DropdownMenuItem(
                          value: city,
                          child: Text(
                            city == "Other" ? 'district_other'.trSafe("Other") : city,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCity = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Street / Area / Landmark ──
                Text(
                  'street_area_landmark'.trSafe("Street / Area / Landmark"),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _streetAreaCtrl,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'address_hint_eg'.trSafe(
                      "e.g. 20, Anna Nagar Central",
                    ),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFD97706),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Postal Pincode ──
                Text(
                  'postal_pincode'.trSafe("Postal Pincode"),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _pincodeCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'pincode_hint'.trSafe("e.g. 600001"),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFD97706),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Contact Phone Number (+91) ──
                Text(
                  'contact_phone'.trSafe("Contact Phone Number"),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Text(
                        "+91",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    hintText: 'phone_number_hint'.trSafe(
                      "10-digit mobile number",
                    ),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFD97706),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Service Dispatch Radius ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'service_dispatch_radius'.trSafe(
                                "Service Dispatch Radius",
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Text(
                              "${_serviceRadiusKm.toInt()} ${'unit_km'.trSafe('km')}",
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFB45309),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: const Color(0xFFF59E0B),
                          inactiveTrackColor: const Color(0xFFE2E8F0),
                          thumbColor: const Color(0xFFD97706),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 9,
                            elevation: 3,
                          ),
                          overlayColor: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          value: _serviceRadiusKm,
                          min: 1.0,
                          max: 30.0,
                          divisions: 29,
                          onChanged: (val) =>
                              setState(() => _serviceRadiusKm = val),
                        ),
                      ),
                      Text(
                        'dispatch_radius_desc'.trSafe(
                          "You will receive customer booking requests within {} km of your base workshop.",
                          ['${_serviceRadiusKm.toInt()}'],
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF64748B),
                          fontSize: 11,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Bottom Fixed Action Bar ──
        _buildStandardBottomBar(
          onBack: () => setState(() => _mainStep = 0),
          onContinue: () => setState(() => _mainStep = 2),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 3: DAILY AVAILABLE WORKING HOURS
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildStep3WorkingHoursView() {
    return Column(
      key: const ValueKey("step3_schedule"),
      children: [
        // Top Header
        _buildStepHeader(
          badgeText: 'onboarding_step_3_badge'.trSafe("Step 3 of 3 • Schedule"),
          onBack: () => setState(() => _mainStep = 1),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero Banner ──
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14B45309),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: Color(0xFFD97706),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'onboarding_step3_title'.trSafe(
                                "Daily Available Working Hours",
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF78350F),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'onboarding_step3_sub'.trSafe(
                                "Specify the hours when you are available to accept incoming jobs",
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF92400E),
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Schedule Window Summary ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
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
                      const Icon(
                        Icons.access_time_filled_rounded,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${_workingHoursStart.to12HourTime()}  —  ${_workingHoursEnd.to12HourTime()}",
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF0F172A),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${_calculateDailyHours()} ${'hours_daily_label'.trSafe('Hours Daily Availability')}",
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF64748B),
                                fontSize: 11.5,
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
                const SizedBox(height: 16),

                // ── Interactive Time Slots (Start / End Time) ──
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeSlotTile(
                        label: 'start_time_label'.trSafe("Start Time"),
                        time: _workingHoursStart,
                        icon: Icons.wb_sunny_rounded,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 8, minute: 0),
                          );
                          if (picked != null) {
                            setState(() {
                              _workingHoursStart =
                                  "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimeSlotTile(
                        label: 'end_time_label'.trSafe("End Time"),
                        time: _workingHoursEnd,
                        icon: Icons.nightlight_round,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 20, minute: 0),
                          );
                          if (picked != null) {
                            setState(() {
                              _workingHoursEnd =
                                  "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Quick Presets ──
                Text(
                  'quick_shift_presets'.trSafe("Quick Shift Presets"),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPresetChip(
                      'preset_full_day'.trSafe("Full Day (8 AM - 8 PM)"),
                      "08:00",
                      "20:00",
                    ),
                    _buildPresetChip(
                      'preset_morning'.trSafe("Morning Shift (7 AM - 3 PM)"),
                      "07:00",
                      "15:00",
                    ),
                    _buildPresetChip(
                      'preset_evening'.trSafe("Evening Shift (12 PM - 9 PM)"),
                      "12:00",
                      "21:00",
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Cooperative Dispatch Guarantee Card ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF16A34A),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'coop_guarantee_title'.trSafe(
                                "Cooperative Dispatch Guarantee",
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF14532D),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'coop_guarantee_sub'.trSafe(
                                "Direct customer bookings are dispatched with 0% middleman deduction.",
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF166534),
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
        ),

        // ── Bottom Fixed Action Bar: Activate Artisan Cockpit ──
        _buildStep3BottomBar(),
      ],
    );
  }

  // ── Reusable Step Header for Steps 2 & 3 ──
  Widget _buildStepHeader({
    required String badgeText,
    required VoidCallback onBack,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onBack();
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF475569),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'btn_back'.trSafe("Back"),
          ),

          // Step Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF334155),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 22-Language Switcher
          InkWell(
            onTap: () => _showLanguageSelectionSheet(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.translate_rounded,
                    size: 14,
                    color: Color(0xFF475569),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getCurrentLanguageName(),
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF1E293B),
                      fontSize: 11.5,
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
      ),
    );
  }

  Widget _buildStandardBottomBar({
    required VoidCallback onBack,
    required VoidCallback onContinue,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              onBack();
            },
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color: Color(0xFF475569),
            ),
            label: Text(
              'btn_back'.trSafe('Back'),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onContinue();
              },
              icon: const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                'btn_continue'.trSafe('Continue'),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0x35F59E0B),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3BottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _mainStep = 1);
            },
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color: Color(0xFF475569),
            ),
            label: Text(
              'btn_back'.trSafe('Back'),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _completeOnboarding,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.rocket_launch_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
              label: Text(
                _isSaving
                    ? 'activating_status'.trSafe('Activating...')
                    : 'activate_artisan_cockpit_btn'.trSafe(
                        'Activate Artisan Cockpit',
                      ),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: const Color(0x35F59E0B),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotTile({
    required String label,
    required String time,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
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
                Icon(icon, size: 14, color: const Color(0xFFD97706)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              time.to12HourTime(),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String start, String end) {
    final isSelected = _workingHoursStart == start && _workingHoursEnd == end;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _workingHoursStart = start;
          _workingHoursEnd = end;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF59E0B)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected
                ? const Color(0xFF92400E)
                : const Color(0xFF334155),
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

