import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

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
  final Set<String> _selectedSkills = {};
  double _serviceRadiusKm = 10.0;
  String _selectedCity = "Chennai";
  final TextEditingController _streetAreaCtrl = TextEditingController();
  final TextEditingController _pincodeCtrl = TextEditingController();
  double _latitude = 13.0827;
  double _longitude = 80.2707;
  String _formattedAddress = "";
  bool _isDetectingGps = false;
  String _workingHoursStart = "08:00";
  String _workingHoursEnd = "20:00";
  bool _isSaving = false;

  final List<String> _availableSkills = [
    "Plumbing",
    "Electrical",
    "Carpentry",
    "Cleaning",
    "Painting",
    "Appliance Repair",
    "Masonry",
    "Gardening",
  ];

  final Map<String, IconData> _skillIcons = {
    "Plumbing": Icons.plumbing_rounded,
    "Electrical": Icons.electric_bolt_rounded,
    "Carpentry": Icons.carpenter_rounded,
    "Cleaning": Icons.cleaning_services_rounded,
    "Painting": Icons.format_paint_rounded,
    "Appliance Repair": Icons.home_repair_service_rounded,
    "Masonry": Icons.construction_rounded,
    "Gardening": Icons.yard_rounded,
  };

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
      _selectedSkills.addAll(["Plumbing", "Electrical"]);
    }
    _serviceRadiusKm = widget.worker.serviceRadiusKm.clamp(1.0, 30.0);
    _workingHoursStart = widget.worker.workingHoursStart;
    _workingHoursEnd = widget.worker.workingHoursEnd;

    // Detect GPS location on screen launch
    _autoDetectGps();
  }

  @override
  void dispose() {
    _streetAreaCtrl.dispose();
    _pincodeCtrl.dispose();
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

  Future<void> _completeOnboarding() async {
    if (_selectedSkills.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please select at least one trade skill you can do"),
          backgroundColor: KX.rose,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final streetText = _streetAreaCtrl.text.trim();
      final pincodeText = _pincodeCtrl.text.trim();
      final detailedAreaSummary = streetText.isNotEmpty ? "$streetText, $_selectedCity" : "$_selectedCity Central";
      final fullAddr = _formattedAddress.isNotEmpty ? _formattedAddress : "$detailedAreaSummary $pincodeText, Tamil Nadu";

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

      final updated = widget.worker.copyWith(
        skills: _selectedSkills.toList(),
        serviceRadiusKm: _serviceRadiusKm,
        preferredAreas: [_selectedCity, detailedAreaSummary],
        baseArea: detailedAreaSummary,
        baseAddress: defaultBaseAddress,
        addresses: [defaultBaseAddress],
        latitude: _latitude,
        longitude: _longitude,
        workingHoursStart: _workingHoursStart,
        workingHoursEnd: _workingHoursEnd,
        availabilityStatus: AvailabilityStatus.online,
      );

      await _workerService.upsertWorkerProfile(updated);

      // Save complete address to subcollection and top-level fields
      final locationService = LocationService();
      await locationService.saveAddress(widget.worker.userId, defaultBaseAddress, collection: "workers");

      // Save persistent anti-loop flags
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("worker_onboarding_done_${widget.worker.userId}", true);
      await prefs.setBool("worker_loc_done_${widget.worker.userId}", true);

      await FirebaseFirestore.instance.collection("workers").doc(widget.worker.id).set({
        "hasCompletedOnboarding": true,
        "skills": _selectedSkills.toList(),
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
            content: Text("Error saving profile: $e"),
            backgroundColor: KX.rose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KaryaScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: KX.violet.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: KX.violetNeon.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_rounded, color: KX.gold, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "COOPERATIVE ARTISAN ONBOARDING",
                        style: WorkGoFonts.badge(
                          color: KX.gold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                "Welcome to WorkGo Karya!",
                style: WorkGoFonts.display(
                  color: KX.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "Tell us what jobs you can do and where you'd like to receive incoming service requests.",
                style: WorkGoFonts.body(
                  color: KX.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Section 1: Jobs You Can Do
              _buildSectionCard(
                title: "1. Jobs / Trades You Can Do",
                subtitle: "Select all the services you are certified & ready to provide",
                icon: Icons.handyman_rounded,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _availableSkills.length,
                  itemBuilder: (context, index) {
                    final skill = _availableSkills[index];
                    final isSelected = _selectedSkills.contains(skill);
                    final icon = _skillIcons[skill] ?? Icons.handyman_rounded;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isSelected) {
                            if (_selectedSkills.length > 1) {
                              _selectedSkills.remove(skill);
                            }
                          } else {
                            _selectedSkills.add(skill);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: KAnim.fast,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? KX.violet.withValues(alpha: 0.35) : KX.canvasCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? KX.gold : KX.glassBorder,
                            width: isSelected ? 1.6 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: KX.violetNeon.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    spreadRadius: -2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              color: isSelected ? KX.gold : KX.textSecondary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                skill,
                                style: WorkGoFonts.heading(
                                  color: isSelected ? Colors.white : KX.textSecondary,
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: KX.gold, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Section 2: Work Location & Coverage Radius
              _buildSectionCard(
                title: "2. Your Location & Coverage Area",
                subtitle: "Set your exact operating workshop/base and coverage radius",
                icon: Icons.location_on_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1-Tap GPS Auto-Detect Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E1B4E), Color(0xFF1E1035)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: KX.violetNeon.withValues(alpha: 0.4)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: KX.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _isDetectingGps
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: KX.gold,
                                    ),
                                  )
                                : const Icon(Icons.my_location_rounded, color: KX.gold, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isDetectingGps ? "Detecting real-time GPS..." : "Live Hardware GPS Location",
                                  style: WorkGoFonts.heading(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formattedAddress.isNotEmpty
                                      ? _formattedAddress
                                      : "${_streetAreaCtrl.text}, $_selectedCity ${_pincodeCtrl.text}",
                                  style: WorkGoFonts.body(
                                    color: KX.textSecondary,
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
                              foregroundColor: KX.gold,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            child: Text(
                              "Re-detect",
                              style: WorkGoFonts.badge(
                                color: KX.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // District / City Selector Dropdown
                    Text(
                      "Operating District / City",
                      style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 11.5),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: KX.canvasElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: KX.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _tamilNaduDistricts.contains(_selectedCity) ? _selectedCity : _tamilNaduDistricts.first,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1B1438),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: KX.gold),
                          items: _tamilNaduDistricts.map((city) {
                            return DropdownMenuItem(
                              value: city,
                              child: Text(
                                city,
                                style: WorkGoFonts.body(
                                  color: KX.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCity = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Detailed Street / Area Text Input
                    Text(
                      "Street / Area / Landmark",
                      style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 11.5),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _streetAreaCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: "e.g. 20, Mosikeeranar Street, Indira Nagar",
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                        filled: true,
                        fillColor: KX.canvasElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: KX.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: KX.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: KX.gold, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Pincode Input
                    Text(
                      "Postal Pincode",
                      style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 11.5),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _pincodeCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: "e.g. 638001",
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                        filled: true,
                        fillColor: KX.canvasElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: KX.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: KX.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: KX.gold, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Radius Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Service Dispatch Radius",
                          style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 12.5),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: KX.violetNeon.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: KX.violetNeon.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            "${_serviceRadiusKm.toInt()} km",
                            style: WorkGoFonts.numeric(
                              color: KX.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: KX.gold,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                        thumbColor: Colors.white,
                        overlayColor: KX.gold.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _serviceRadiusKm,
                        min: 1.0,
                        max: 30.0,
                        divisions: 29,
                        onChanged: (val) => setState(() => _serviceRadiusKm = val),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Section 3: Available Hours
              _buildSectionCard(
                title: "3. Daily Available Working Hours",
                subtitle: "When would you like to receive service requests?",
                icon: Icons.access_time_filled_rounded,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTimeSlotBadge("Start Time", _workingHoursStart, () async {
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
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimeSlotBadge("End Time", _workingHoursEnd, () async {
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
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Complete CTA
              KaryaButton(
                label: "Activate Artisan Cockpit",
                icon: Icons.rocket_launch_rounded,
                isLoading: _isSaving,
                onPressed: _completeOnboarding,
                gradient: KX.luminaVioletGold,
                glowColor: KX.gold,
                height: 52,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return KaryaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: KX.auroraVioletNeon,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: WorkGoFonts.heading(
                        color: KX.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: WorkGoFonts.body(
                        color: KX.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildTimeSlotBadge(String label, String time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KX.canvasElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KX.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, color: KX.gold, size: 16),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: WorkGoFonts.numeric(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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
