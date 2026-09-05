import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
import '../widgets/translated_text.dart';
import 'live_booking_tracker_screen.dart';
import 'rapido_live_broadcast_screen.dart';

class BookingCreationScreen extends StatefulWidget {
  const BookingCreationScreen({
    super.key,
    required this.serviceCategory,
    this.worker,
    this.targetWorkerId,
    required this.customerId,
    this.customerLat,
    this.customerLng,
    this.isEmergencyInitial = false,
  });

  final String serviceCategory;
  final Worker? worker;
  final String? targetWorkerId;
  final String customerId;
  final double? customerLat;
  final double? customerLng;
  final bool isEmergencyInitial;

  @override
  State<BookingCreationScreen> createState() => _BookingCreationScreenState();
}

class _BookingCreationScreenState extends State<BookingCreationScreen>
    with TickerProviderStateMixin {
  late bool _isEmergency;
  double _urgencyTip = 0.0;
  int _selectedDayIndex = 0;
  String _selectedSlot = "slot_morning";
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _customerName;
  String? _customerPhone;
  UserAddress? _selectedAddress;
  bool _isSubmitting = false;

  late AnimationController _emergencyCtrl;

  @override
  void initState() {
    super.initState();
    _isEmergency = widget.isEmergencyInitial;
    if (_isEmergency) _urgencyTip = 100.0;
    _emergencyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (_isEmergency) _emergencyCtrl.forward();

    // Pre-populate with live caller coordinates so distance calculation is immediate and correct
    if (widget.customerLat != null && widget.customerLng != null && widget.customerLat! > 1.0) {
      _selectedAddress = UserAddress(
        id: "passed_gps",
        formattedAddress: "current_location".tr(),
        latitude: widget.customerLat!,
        longitude: widget.customerLng!,
        createdAt: DateTime.now(),
      );
      _addressController.text = "current_location".tr();
    }

    _loadUserDefaultAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserDefaultAddress() async {
    try {
      // 0. Load customer phone & name from user document
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.customerId)
          .get();
      if (userDoc.exists) {
        final ud = userDoc.data() ?? {};
        _customerName = ud["displayName"] ?? ud["name"];
        _customerPhone = ud["phoneNumber"] ?? ud["phone"] ?? ud["mobile"];
        if (_customerPhone != null &&
            _customerPhone!.isNotEmpty &&
            _phoneController.text.isEmpty &&
            mounted) {
          setState(() {
            _phoneController.text = _customerPhone!;
          });
        }
      }

      // 1. Try user's saved addresses subcollection (UserAddress)
      final addrSnap = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.customerId)
          .collection("addresses")
          .orderBy("createdAt", descending: true)
          .get();

      if (addrSnap.docs.isNotEmpty && mounted) {
        final list = addrSnap.docs.map((d) => UserAddress.fromMap(d.data())).toList();
        final defaultAddr = list.firstWhere((a) => a.isDefault, orElse: () => list.first);

        // Sanitize coordinates: detect Mumbai cellular gateway APN or emulator coordinates
        final sanitized = await LocationService.instance.resolveSanitizedCoordinates(
          addressText: defaultAddr.fullDisplayAddress,
          latitude: defaultAddr.latitude,
          longitude: defaultAddr.longitude,
          fallbackLat: widget.customerLat,
          fallbackLng: widget.customerLng,
        );
        final validLat = sanitized["latitude"] ?? defaultAddr.latitude;
        final validLng = sanitized["longitude"] ?? defaultAddr.longitude;
        final effectiveAddr = defaultAddr.copyWith(latitude: validLat, longitude: validLng);

        // Self-heal: If coordinates were corrupted in Firestore, update the document
        if (LocationService.isMumbaiGatewayArtifact(defaultAddr.latitude, defaultAddr.longitude, defaultAddr.fullDisplayAddress) ||
            LocationService.isEmulatorOrOutOfBounds(defaultAddr.latitude, defaultAddr.longitude)) {
          FirebaseFirestore.instance
              .collection("users")
              .doc(widget.customerId)
              .collection("addresses")
              .doc(defaultAddr.id)
              .update({"latitude": validLat, "longitude": validLng}).catchError((_) {});
        }

        setState(() {
          _selectedAddress = effectiveAddr;
          _addressController.text = effectiveAddr.fullDisplayAddress;
        });
        return;
      }

      // 2. Try user doc fields (currentAddressObj or string)
      final doc = await FirebaseFirestore.instance.collection("users").doc(widget.customerId).get();
      final data = doc.data() ?? {};
      final currentAddrObj = data["currentAddressObj"] as Map<String, dynamic>?;
      if (currentAddrObj != null && mounted) {
        final addr = UserAddress.fromMap(currentAddrObj);
        final sanitized = await LocationService.instance.resolveSanitizedCoordinates(
          addressText: addr.fullDisplayAddress,
          latitude: addr.latitude,
          longitude: addr.longitude,
          fallbackLat: widget.customerLat,
          fallbackLng: widget.customerLng,
        );
        final validLat = sanitized["latitude"] ?? addr.latitude;
        final validLng = sanitized["longitude"] ?? addr.longitude;
        final effectiveAddr = addr.copyWith(latitude: validLat, longitude: validLng);
        setState(() {
          _selectedAddress = effectiveAddr;
          _addressController.text = effectiveAddr.fullDisplayAddress;
        });
        return;
      }

      final currentAddressStr = data["currentAddress"] as String?;
      final lat = (data["latitude"] as num?)?.toDouble() ?? (widget.customerLat ?? 0.0);
      final lng = (data["longitude"] as num?)?.toDouble() ?? (widget.customerLng ?? 0.0);
      if (currentAddressStr != null && currentAddressStr.isNotEmpty && mounted) {
        setState(() {
          _selectedAddress = UserAddress(
            id: "current",
            formattedAddress: currentAddressStr,
            latitude: lat,
            longitude: lng,
            createdAt: DateTime.now(),
          );
          _addressController.text = currentAddressStr;
        });
        return;
      }

      // 3. Fallback to passed GPS coords or real hardware GPS
      if (widget.customerLat != null && widget.customerLat! > 1.0 && mounted) {
        setState(() {
          _selectedAddress = UserAddress(
            id: "gps",
            formattedAddress: "current_location".tr(),
            latitude: widget.customerLat!,
            longitude: widget.customerLng ?? 0.0,
            createdAt: DateTime.now(),
          );
          _addressController.text = "current_location".tr();
        });
        return;
      }

      final coords = await LocationService.instance.getCurrentCoordinates();
      final hardwareLat = (coords["latitude"] as num?)?.toDouble() ?? 0.0;
      final hardwareLng = (coords["longitude"] as num?)?.toDouble() ?? 0.0;
      final addrName = coords["address"]?.toString() ?? "current_location".tr();
      if (mounted && hardwareLat > 1.0) {
        setState(() {
          _selectedAddress = UserAddress(
            id: "gps",
            formattedAddress: addrName,
            latitude: hardwareLat,
            longitude: hardwareLng,
            createdAt: DateTime.now(),
          );
          _addressController.text = addrName;
        });
      }
    } catch (_) {}
  }

  void _setEmergency(bool val) {
    setState(() {
      _isEmergency = val;
      if (val && _urgencyTip == 0.0) _urgencyTip = 100.0;
    });
    if (val) {
      _emergencyCtrl.forward();
    } else {
      _emergencyCtrl.reverse();
    }
  }

  Future<void> _submitBooking() async {
    setState(() => _isSubmitting = true);
    try {
      final worker = widget.worker;
      final custLatInit = (_selectedAddress != null && _selectedAddress!.latitude > 1.0)
          ? _selectedAddress!.latitude
          : widget.customerLat;
      final custLngInit = (_selectedAddress != null && _selectedAddress!.longitude > 1.0)
          ? _selectedAddress!.longitude
          : widget.customerLng;
      final realDist = worker?.calculateDistanceKm(custLatInit, custLngInit) ?? (worker?.distanceKm ?? 1.2);
      final fare = CooperativePricingEngine.instance.calculateFare(
        category: widget.serviceCategory,
        distanceKm: realDist,
        experienceYears: worker?.experienceYears ?? 3,
        isEmergency: _isEmergency,
        urgencyTip: _urgencyTip,
        customBaseRate: worker?.baseRate,
        customPerKmRate: worker?.perKmRate,
      );

      final totalAmount = fare.totalEstimatedFare;

      final bookingService = BookingService();
      final assignedWorkerId =
          widget.targetWorkerId ?? widget.worker?.id;
      String addressText = _addressController.text.trim();
      double custLat = (_selectedAddress != null && _selectedAddress!.latitude > 1.0)
          ? _selectedAddress!.latitude
          : (widget.customerLat ?? 0.0);
      double custLng = (_selectedAddress != null && _selectedAddress!.longitude > 1.0)
          ? _selectedAddress!.longitude
          : (widget.customerLng ?? 0.0);

      if (addressText.isEmpty) {
        addressText = _selectedAddress?.fullDisplayAddress ?? "";
      }

      // Ensure coordinates are authentic real coordinates (not Mumbai cellular gateway or emulator)
      if (LocationService.isEmulatorOrOutOfBounds(custLat, custLng) ||
          LocationService.isMumbaiGatewayArtifact(custLat, custLng, addressText) ||
          custLat <= 1.0) {
        final sanitized = await LocationService.instance.resolveSanitizedCoordinates(
          addressText: addressText,
          latitude: custLat,
          longitude: custLng,
          fallbackLat: widget.customerLat,
          fallbackLng: widget.customerLng,
        );
        custLat = sanitized["latitude"] ?? custLat;
        custLng = sanitized["longitude"] ?? custLng;
      }

      // Only if still missing coordinates and user typed a custom address, forward geocode
      if ((custLat <= 1.0 || custLng <= 1.0) &&
          addressText.isNotEmpty &&
          !addressText.toLowerCase().contains("mumbai")) {
        try {
          final geo = await LocationService.instance.forwardGeocode(addressText);
          if (geo != null && geo["latitude"] != null && geo["latitude"]! > 1.0) {
            custLat = geo["latitude"]!;
            custLng = geo["longitude"]!;
          }
        } catch (_) {}
      }

      if (addressText.isEmpty) {
        addressText = "current_location".tr();
      }

      final contactPhone = _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : _customerPhone;

      final bookingId = await bookingService.createBooking(
        customerId: widget.customerId,
        serviceType: widget.serviceCategory,
        workerId: assignedWorkerId,
        acceptedWorkerName: worker?.name,
        workerLatitude: worker?.latitude,
        workerLongitude: worker?.longitude,
        amount: totalAmount - _urgencyTip,
        urgencyBonus: _urgencyTip,
        isEmergency: _isEmergency,
        scheduledAt: DateTime.now().add(Duration(days: _selectedDayIndex)),
        customerAddressText: addressText,
        customerLatitude: custLat,
        customerLongitude: custLng,
        customerName: _customerName,
        customerPhone: contactPhone,
      );

      if (mounted) {
        if (assignedWorkerId != null && assignedWorkerId.isNotEmpty) {
          // Direct 1-to-1 Artisan Dispatch (Bypasses public 45s broadcast)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (ctx) => LiveBookingTrackerScreen(
                bookingId: bookingId,
              ),
            ),
          );
        } else {
          // Open broadcast dispatch to all nearby trade artisans
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (ctx) => RapidoLiveBroadcastScreen(
                bookingId: bookingId,
                serviceCategory: widget.serviceCategory,
                initialAmount: totalAmount,
                pickupAddress: addressText,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("booking_error".tr(args: [e.toString()])),
            backgroundColor: CX.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = widget.worker;
    double? custLat = (_selectedAddress != null && _selectedAddress!.latitude > 1.0)
        ? _selectedAddress!.latitude
        : widget.customerLat;
    double? custLng = (_selectedAddress != null && _selectedAddress!.longitude > 1.0)
        ? _selectedAddress!.longitude
        : widget.customerLng;

    // Safety guard: if coordinates are Mumbai cellular artifacts or emulator, fallback to live caller coords or regional hub
    if (LocationService.isMumbaiGatewayArtifact(custLat, custLng, _selectedAddress?.fullDisplayAddress) ||
        LocationService.isEmulatorOrOutOfBounds(custLat, custLng)) {
      custLat = (widget.customerLat != null && !LocationService.isEmulatorOrOutOfBounds(widget.customerLat, widget.customerLng))
          ? widget.customerLat
          : 11.3410;
      custLng = (widget.customerLng != null && !LocationService.isEmulatorOrOutOfBounds(widget.customerLat, widget.customerLng))
          ? widget.customerLng
          : 77.7172;
    }

    final realDist = worker?.calculateDistanceKm(custLat, custLng) ?? (worker?.distanceKm ?? 1.2);
    final fare = CooperativePricingEngine.instance.calculateFare(
      category: widget.serviceCategory,
      distanceKm: realDist,
      experienceYears: worker?.experienceYears ?? 3,
      isEmergency: _isEmergency,
      urgencyTip: _urgencyTip,
      customBaseRate: worker?.baseRate,
      customPerKmRate: worker?.perKmRate,
    );

    final catStyle = categoryStyle(widget.serviceCategory);

    return AuroraScaffold(
      appBar: AuroraAppBar(title: 'confirm_booking'.tr()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Service Hero Card with Artisan Profile
              SlideFadeIn(
                child: _ServiceHeroCard(
                  categoryName: widget.serviceCategory,
                  style: catStyle,
                  worker: widget.worker,
                  hasWorker: widget.targetWorkerId != null ||
                      widget.worker != null,
                  custLat: custLat,
                  custLng: custLng,
                ),
              ),
              const SizedBox(height: 16),

              // Emergency Toggle
              SlideFadeIn(
                delay: const Duration(milliseconds: 60),
                child: _EmergencyToggleCard(
                  isEmergency: _isEmergency,
                  onChanged: _setEmergency,
                  controller: _emergencyCtrl,
                ),
              ),
              const SizedBox(height: 20),

              // Date Selection
              SlideFadeIn(
                delay: const Duration(milliseconds: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('select_date'.tr()),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _DayChip(
                            index: 0,
                            selected: _selectedDayIndex == 0,
                            label: "date_today".tr(),
                            sub: "date_today_sub".tr(),
                            onTap: () =>
                                setState(() => _selectedDayIndex = 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DayChip(
                            index: 1,
                            selected: _selectedDayIndex == 1,
                            label: "date_tomorrow".tr(),
                            sub: "date_tomorrow_sub".tr(),
                            onTap: () =>
                                setState(() => _selectedDayIndex = 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DayChip(
                            index: 2,
                            selected: _selectedDayIndex == 2,
                            label: "date_scheduled".tr(),
                            sub: "date_scheduled_sub".tr(),
                            onTap: () =>
                                setState(() => _selectedDayIndex = 2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Time Slots
              SlideFadeIn(
                delay: const Duration(milliseconds: 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('select_slot'.tr()),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SlotChip(
                            slotKey: "slot_morning",
                            timeRange: "9 AM–12 PM",
                            icon: Icons.wb_sunny_rounded,
                            iconColor: CX.amber,
                            selected: _selectedSlot == "slot_morning",
                            onTap: () =>
                                setState(() => _selectedSlot = "slot_morning"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SlotChip(
                            slotKey: "slot_afternoon",
                            timeRange: "12–4 PM",
                            icon: Icons.wb_cloudy_rounded,
                            iconColor: CX.cyan,
                            selected: _selectedSlot == "slot_afternoon",
                            onTap: () => setState(
                                () => _selectedSlot = "slot_afternoon"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SlotChip(
                            slotKey: "slot_evening",
                            timeRange: "4–8 PM",
                            icon: Icons.nights_stay_rounded,
                            iconColor: CX.violetLight,
                            selected: _selectedSlot == "slot_evening",
                            onTap: () =>
                                setState(() => _selectedSlot = "slot_evening"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Dedicated Service Address Card with 1-Tap Switcher
              SlideFadeIn(
                delay: const Duration(milliseconds: 180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: _sectionLabel('address'.tr())),
                        Flexible(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              final chosen = await showAddressManagementSheet(
                                context,
                                userId: widget.customerId,
                                userRole: "customer",
                                selectedAddress: _selectedAddress,
                              );
                              if (chosen != null && mounted) {
                                final sanitized = await LocationService.instance.resolveSanitizedCoordinates(
                                  addressText: chosen.fullDisplayAddress,
                                  latitude: chosen.latitude,
                                  longitude: chosen.longitude,
                                  fallbackLat: widget.customerLat,
                                  fallbackLng: widget.customerLng,
                                );
                                final validLat = sanitized["latitude"] ?? chosen.latitude;
                                final validLng = sanitized["longitude"] ?? chosen.longitude;
                                final effectiveAddr = chosen.copyWith(latitude: validLat, longitude: validLng);
                                setState(() {
                                  _selectedAddress = effectiveAddr;
                                  _addressController.text = effectiveAddr.fullDisplayAddress;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.swap_horiz_rounded, color: Color(0xFFD97706), size: 15),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      _selectedAddress != null
                                          ? "change_address".tr(args: [_selectedAddress!.displayTitle])
                                          : "select_saved_address".tr(),
                                      style: const TextStyle(
                                        color: Color(0xFFB45309),
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
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ServiceAddressCard(
                      address: _selectedAddress,
                      onChangePressed: () async {
                        final chosen = await showAddressManagementSheet(
                          context,
                          userId: widget.customerId,
                          userRole: "customer",
                          selectedAddress: _selectedAddress,
                        );
                        if (chosen != null && mounted) {
                          final sanitized = await LocationService.instance.resolveSanitizedCoordinates(
                            addressText: chosen.fullDisplayAddress,
                            latitude: chosen.latitude,
                            longitude: chosen.longitude,
                            fallbackLat: widget.customerLat,
                            fallbackLng: widget.customerLng,
                          );
                          final validLat = sanitized["latitude"] ?? chosen.latitude;
                          final validLng = sanitized["longitude"] ?? chosen.longitude;
                          final effectiveAddr = chosen.copyWith(latitude: validLat, longitude: validLng);
                          setState(() {
                            _selectedAddress = effectiveAddr;
                            _addressController.text = effectiveAddr.fullDisplayAddress;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Contact Phone
              SlideFadeIn(
                delay: const Duration(milliseconds: 195),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('contact_phone'.tr()),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_android_rounded, color: Color(0xFF059669), size: 16),
                                SizedBox(width: 4),
                                Text(
                                  "+91",
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'phone_number_hint'.tr(),
                                hintStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Notes
              SlideFadeIn(
                delay: const Duration(milliseconds: 210),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('problem_notes'.tr()),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 3,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "notes_field_hint".tr(),
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Rapido-Style Urgency Boost Bidding
              SlideFadeIn(
                delay: const Duration(milliseconds: 230),
                child: AuroraCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: CX.amber, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "urgency_boost".tr(),
                              style: WorkGoFonts.heading(
                                color: CX.textPrimary,
                                fontSize: 13.5,
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
                        "urgency_tip_label".tr(),
                        style: WorkGoFonts.body(color: CX.textSecondary, fontSize: 11.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildUrgencyChip("urgency_standard".tr(), 0.0),
                          const SizedBox(width: 8),
                          _buildUrgencyChip("+₹50", 50.0),
                          const SizedBox(width: 8),
                          _buildUrgencyChip("+₹100", 100.0),
                          const SizedBox(width: 8),
                          _buildUrgencyChip("+₹200", 200.0),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Price Breakdown (Rapido-style Dynamic Breakdown)
              SlideFadeIn(
                delay: const Duration(milliseconds: 260),
                child: _PriceCard(
                  fare: fare,
                  isEmergency: _isEmergency,
                ),
              ),
              const SizedBox(height: 24),

              // Confirm CTA
              SlideFadeIn(
                delay: const Duration(milliseconds: 280),
                child: GlowButton(
                  label: 'confirm_booking'.tr(),
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _submitBooking,
                  gradient: _isEmergency
                      ? CX.auroraEmergency
                      : CX.auroraVioletCyan,
                  glowColor: _isEmergency ? CX.rose : CX.violet,
                  height: 54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrgencyChip(String label, double amount) {
    final isSelected = _urgencyTip == amount;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _urgencyTip = amount);
        },
        child: AnimatedContainer(
          duration: CAnim.fast,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF141416) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x04000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF334155),
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ──────────────────────────────────────────────────────
//  SERVICE ADDRESS CARD — Swiggy/Uber Dedicated Style
// ──────────────────────────────────────────────────────
class _ServiceAddressCard extends StatelessWidget {
  const _ServiceAddressCard({
    required this.address,
    required this.onChangePressed,
  });

  final UserAddress? address;
  final VoidCallback onChangePressed;

  @override
  Widget build(BuildContext context) {
    final title = address != null && address!.displayTitle.isNotEmpty
        ? address!.displayTitle
        : "current_location".tr();
    final fullText = address != null && address!.fullDisplayAddress.isNotEmpty
        ? address!.fullDisplayAddress
        : "current_location".tr();
    final icon = address?.label.icon ?? Icons.location_on_rounded;

    return GestureDetector(
      onTap: onChangePressed,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1),
              ),
              child: Icon(icon, color: const Color(0xFFD97706), size: 20),
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
                          title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (address?.isDefault == true) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                          ),
                          child: const Text(
                            "DEFAULT",
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    fullText,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
              ),
              child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  SERVICE HERO CARD
// ──────────────────────────────────────────────────────
class _ServiceHeroCard extends StatelessWidget {
  const _ServiceHeroCard({
    required this.categoryName,
    required this.style,
    required this.hasWorker,
    this.worker,
    this.custLat,
    this.custLng,
  });

  final String categoryName;
  final CategoryStyle style;
  final bool hasWorker;
  final Worker? worker;
  final double? custLat;
  final double? custLng;

  @override
  Widget build(BuildContext context) {
    final displayName = worker != null && worker!.name.isNotEmpty ? worker!.name : null;
    final totalReviews = worker != null && worker!.totalReviews > 0 ? worker!.totalReviews : (worker?.totalRatings ?? 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.7), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (worker != null) ...[
                WorkGoAvatar(
                  name: displayName ?? "artisan".trSafe("Artisan"),
                  avatarBase64: worker!.avatarBase64,
                  radius: 28,
                ),
              ] else ...[
                AuroraOrb(
                  icon: style.icon,
                  gradient: style.gradient,
                  size: 56,
                  iconSize: 28,
                  glowColor: style.glow,
                ),
              ],
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName.toLocalizedTrade(),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName != null
                                ? "artisan_assigned_name".tr(args: [displayName])
                                : "auto_dispatching".tr(),
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 12),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              worker != null ? "coop_certified_artisan".tr() : "cooperative_service".tr(),
                              style: const TextStyle(
                                color: Color(0xFF065F46),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
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
          if (worker != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(height: 1, color: const Color(0xFFF1F5F9)),
            ),
            Row(
              children: [
                // Rating Pill
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 14),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            worker!.avgRating > 0
                                ? worker!.avgRating.toStringAsFixed(1)
                                : (worker!.totalRatings > 0 ? "5.0" : 'badge_new'.trSafe("New")),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (totalReviews > 0) ...[
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              "($totalReviews)",
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Experience / Pro Pill (No emojis)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.handyman_rounded, color: Color(0xFF059669), size: 13),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            worker!.homesServiced > 0
                                ? 'homes_count'.tr(args: [worker!.homesServiced.toString()])
                                : (worker!.totalRatings > 0
                                    ? 'jobs_count'.tr(args: [worker!.totalRatings.toString()])
                                    : "verified_pro".tr()),
                            style: const TextStyle(
                              color: Color(0xFF065F46),
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
                ),
                const SizedBox(width: 6),

                // Distance Pill (No emojis)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.near_me_rounded, color: Color(0xFF2563EB), size: 13),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            worker!.formattedDistanceString(custLat, custLng),
                            style: const TextStyle(
                              color: Color(0xFF1D4ED8),
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
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  EMERGENCY TOGGLE CARD — Animated Elevated Card
// ──────────────────────────────────────────────────────
class _EmergencyToggleCard extends StatelessWidget {
  const _EmergencyToggleCard({
    required this.isEmergency,
    required this.onChanged,
    required this.controller,
  });

  final bool isEmergency;
  final ValueChanged<bool> onChanged;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Color.lerp(Colors.white, const Color(0xFFFFF1F2), t),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Color.lerp(const Color(0xFFFDE68A), const Color(0xFFF87171), t)!,
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(const Color(0x06000000), const Color(0x1DEF4444), t)!,
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Color.lerp(const Color(0xFFFEF3C7), const Color(0xFFFEE2E2), t),
                  border: Border.all(
                    color: Color.lerp(const Color(0xFFFDE68A), const Color(0xFFFCA5A5), t)!,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: Color.lerp(const Color(0xFFD97706), const Color(0xFFEF4444), t),
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
                        Flexible(
                          child: Text(
                            'emergency_booking'.tr(),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Color.lerp(const Color(0xFFFEF3C7), const Color(0xFFFEE2E2), t),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Color.lerp(const Color(0xFFFDE68A), const Color(0xFFFCA5A5), t)!,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            "+₹150",
                            style: TextStyle(
                              color: Color.lerp(const Color(0xFFB45309), const Color(0xFFDC2626), t),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "emergency_dispatch_note".tr(),
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => onChanged(!isEmergency),
                child: AnimatedContainer(
                  duration: CAnim.normal,
                  width: 48,
                  height: 28,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isEmergency ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AnimatedAlign(
                    duration: CAnim.normal,
                    curve: Curves.easeOutCubic,
                    alignment: isEmergency ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x28000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────
//  DAY CHIP — High-Contrast Segmented Selector
// ──────────────────────────────────────────────────────
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.index,
    required this.selected,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CAnim.normal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF141416) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
            width: selected ? 1.6 : 1.2,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x28000000),
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
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              sub,
              style: TextStyle(
                color: selected ? const Color(0xFFFBBF24) : const Color(0xFF64748B),
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  SLOT CHIP — Clean, Non-Truncating Time Range Selector
// ──────────────────────────────────────────────────────
class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slotKey,
    required this.timeRange,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String slotKey;
  final String timeRange;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fullLabel = slotKey.tr();
    final cleanTitle = fullLabel.contains("(") ? fullLabel.split("(").first.trim() : fullLabel;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CAnim.normal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? iconColor : const Color(0xFFE2E8F0),
            width: selected ? 2.0 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? iconColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
              ),
              child: Icon(
                icon,
                color: selected ? iconColor : const Color(0xFF64748B),
                size: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cleanTitle,
              style: TextStyle(
                color: selected ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: selected ? iconColor.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                timeRange,
                style: TextStyle(
                  color: selected ? iconColor : const Color(0xFF64748B),
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  AURORA TEXT FIELD
// ──────────────────────────────────────────────────────
class _AuroraTextField extends StatefulWidget {
  const _AuroraTextField({
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.prefixIconColor,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Color? prefixIconColor;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  State<_AuroraTextField> createState() => _AuroraTextFieldState();
}

class _AuroraTextFieldState extends State<_AuroraTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: CAnim.normal,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused
              ? (widget.prefixIconColor ?? CX.violet)
              : const Color(0xFFE2E8F0),
          width: _focused ? 1.5 : 1.2,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: (widget.prefixIconColor ?? CX.violet).withValues(alpha: 0.15),
                  blurRadius: 10,
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
      child: TextField(
        controller: widget.controller,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        onTap: () => setState(() => _focused = true),
        onTapOutside: (_) => setState(() => _focused = false),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, color: widget.prefixIconColor ?? CX.violet, size: 20)
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  PRICE BREAKDOWN CARD — Professional High-Contrast Card
// ──────────────────────────────────────────────────────
class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.fare,
    required this.isEmergency,
  });

  final FareBreakdown fare;
  final bool isEmergency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.8), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFFEF3C7),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFD97706), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'fare_breakdown'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "transparent_coop_pricing".tr(),
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Base Visit Fare
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'base_visit_fare'.tr(),
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fare.formattedBase,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Transit Allowance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${'transit_distance_fare'.tr()} (${fare.formattedDistance})",
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fare.formattedTransit,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          if (fare.experienceBonus > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "${'experience_bonus'.tr()} (${fare.experienceYears} yrs)",
                    style: const TextStyle(color: Color(0xFF059669), fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "+₹${fare.experienceBonus.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],

          if (fare.urgencyTip > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "urgency_priority_tip".tr(),
                    style: const TextStyle(color: Color(0xFFD97706), fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "+₹${fare.urgencyTip.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],

          AnimatedSize(
            duration: CAnim.slow,
            curve: Curves.easeOutCubic,
            child: isEmergency
                ? Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.bolt_rounded, color: Color(0xFFEF4444), size: 15),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "emergency_rush_label".tr(),
                                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "₹150",
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Total Highlight Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'total_amount'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        "transparent_fare_calc".trSafe("All-inclusive total"),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedCounter(
                  value: fare.totalEstimatedFare,
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
