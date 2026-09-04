import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../localization/trade_localization.dart';
import '../models/user_address.dart';
import '../services/location_service.dart';

/// Opens the Swiggy/Zomato style Address Management sheet.
Future<UserAddress?> showAddressManagementSheet(
  BuildContext context, {
  required String userId,
  String userRole = "customer",
  UserAddress? selectedAddress,
}) async {
  return showModalBottomSheet<UserAddress>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddressManagementSheetContent(
      userId: userId,
      userRole: userRole,
      selectedAddress: selectedAddress,
    ),
  );
}

class _AddressManagementSheetContent extends StatelessWidget {
  final String userId;
  final String userRole;
  final UserAddress? selectedAddress;

  const _AddressManagementSheetContent({
    required this.userId,
    required this.userRole,
    this.selectedAddress,
  });

  @override
  Widget build(BuildContext context) {
    final locationService = LocationService();
    final collection = userRole == "worker" ? "workers" : "users";

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFFF0EDE6), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 28,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E0D8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row with "+ Add Address"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userRole == "worker" ? "operating_bases_title".trSafe("Operating Bases & Hubs") : "saved_addresses_title".trSafe("Saved Addresses"),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF1A1A1A),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "select_address_subtitle".trSafe("Tap to select active location"),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF6B6B6B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final newAddr = await showAddAddressSheet(
                      context,
                      userId: userId,
                      userRole: userRole,
                    );
                    if (newAddr != null && context.mounted) {
                      Navigator.of(context).pop(newAddr);
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF1E1035)),
                  label: Text(
                    "add_new_btn".trSafe("Add New"),
                    style: const TextStyle(
                      color: Color(0xFF1E1035),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB800),
                    foregroundColor: const Color(0xFF1E1035),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Address Stream List
          Flexible(
            child: StreamBuilder<List<UserAddress>>(
              stream: locationService.streamUserAddresses(userId, collection: collection),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: Color(0xFFFFB800)),
                    ),
                  );
                }

                final addresses = snapshot.data ?? [];

                if (addresses.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF0EDE6)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off_rounded, color: Color(0xFF9CA3AF), size: 36),
                        const SizedBox(height: 10),
                        Text(
                          "no_addresses_yet".trSafe("No Saved Addresses Yet"),
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF1A1A1A),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "no_addresses_desc".trSafe("Add an address using GPS detection or manual input to easily set dispatch zones."),
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF6B6B6B),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => showAddAddressSheet(context, userId: userId, userRole: userRole),
                          icon: const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFFB45309)),
                          label: Text(
                            "detect_current_location".trSafe("Detect Current Location"),
                            style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFFB800)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: addresses.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final addr = addresses[index];
                    final isSelected = selectedAddress?.id == addr.id || (selectedAddress == null && addr.isDefault);

                    return _AddressCard(
                      address: addr,
                      isSelected: isSelected,
                      onTap: () => Navigator.of(context).pop(addr),
                      onSetDefault: () => locationService.setDefaultAddress(userId, addr.id, collection: collection),
                      onEdit: () => showAddAddressSheet(context, userId: userId, userRole: userRole, existingAddress: addr),
                      onDelete: () => _confirmDelete(context, locationService, addr, collection),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, LocationService service, UserAddress addr, String collection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("delete_address_title".trSafe("Delete Address"), style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.bold)),
        content: Text("delete_address_confirm".trSafe("Are you sure you want to remove '{}'?", [addr.displayTitle]), style: GoogleFonts.plusJakartaSans(color: const Color(0xFF6B6B6B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("cancel_btn".trSafe("Cancel"), style: const TextStyle(color: Color(0xFF6B6B6B))),
          ),
          ElevatedButton(
            onPressed: () {
              service.deleteAddress(userId, addr.id, collection: collection);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: Text("delete_btn".trSafe("Delete"), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final UserAddress address;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.isSelected,
    required this.onTap,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF3D6) : const Color(0xFFF9F6EE),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFB800) : const Color(0xFFF0EDE6),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Address Label Icon Container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFB800).withValues(alpha: 0.25) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                address.label.icon,
                color: isSelected ? const Color(0xFFB45309) : const Color(0xFF6B6B6B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          (address.label == AddressLabel.other && address.customLabel.trim().isNotEmpty
                                  ? address.customLabel.trim()
                                  : 'address_label_${address.label.name}'.trSafe(address.displayTitle))
                              .toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF1A1A1A),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (address.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            "default_badge".trSafe("DEFAULT"),
                            style: const TextStyle(
                              color: Color(0xFF065F46),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFFFFB800), size: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.fullDisplayAddress.toLocalizedAddress(context.locale.languageCode),
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF6B6B6B),
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Action Buttons
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!address.isDefault) ...[
                        GestureDetector(
                          onTap: onSetDefault,
                          child: Text(
                            "set_as_default_btn".trSafe("Set as Default"),
                            style: const TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      GestureDetector(
                        onTap: onEdit,
                        child: Text(
                          "edit_btn".trSafe("Edit"),
                          style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 11, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onDelete,
                        child: Text(
                          "delete_btn".trSafe("Delete"),
                          style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 11, fontWeight: FontWeight.w700),
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
      ),
    );
  }
}

/// Bottom Sheet for Adding / Editing a Single Address
Future<UserAddress?> showAddAddressSheet(
  BuildContext context, {
  required String userId,
  String userRole = "customer",
  UserAddress? existingAddress,
}) async {
  return showModalBottomSheet<UserAddress>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddAddressSheetContent(
      userId: userId,
      userRole: userRole,
      existingAddress: existingAddress,
    ),
  );
}

class _AddAddressSheetContent extends StatefulWidget {
  final String userId;
  final String userRole;
  final UserAddress? existingAddress;

  const _AddAddressSheetContent({
    required this.userId,
    required this.userRole,
    this.existingAddress,
  });

  @override
  State<_AddAddressSheetContent> createState() => _AddAddressSheetContentState();
}

class _AddAddressSheetContentState extends State<_AddAddressSheetContent> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _flatCtrl;
  late TextEditingController _streetCtrl;
  late TextEditingController _landmarkCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _pincodeCtrl;
  late TextEditingController _customLabelCtrl;

  AddressLabel _selectedLabel = AddressLabel.home;
  double _latitude = 13.0827;
  double _longitude = 80.2707;
  String _formattedAddress = "";
  bool _isDefault = false;
  bool _isDetectingGps = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existingAddress;
    _flatCtrl = TextEditingController(text: a?.flatBuilding ?? "");
    _streetCtrl = TextEditingController(text: a?.streetArea ?? "");
    _landmarkCtrl = TextEditingController(text: a?.landmark ?? "");
    _cityCtrl = TextEditingController(text: a?.city ?? "");
    _pincodeCtrl = TextEditingController(text: a?.pincode ?? "");
    _customLabelCtrl = TextEditingController(text: a?.customLabel ?? "");
    _selectedLabel = a?.label ?? (widget.userRole == "worker" ? AddressLabel.work : AddressLabel.home);
    _latitude = a?.latitude ?? 11.3410;
    _longitude = a?.longitude ?? 77.7172;
    _formattedAddress = a?.formattedAddress ?? "";
    _isDefault = a?.isDefault ?? false;

    if (a == null) {
      _autoDetectGps();
    }
  }

  @override
  void dispose() {
    _flatCtrl.dispose();
    _streetCtrl.dispose();
    _landmarkCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _customLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoDetectGps() async {
    setState(() => _isDetectingGps = true);
    try {
      final locationService = LocationService();
      final coords = await locationService.getCurrentCoordinates();
      final lat = coords["latitude"]!;
      final lon = coords["longitude"]!;

      final decoded = await locationService.reverseGeocode(lat, lon);

      setState(() {
        _latitude = lat;
        _longitude = lon;
        _streetCtrl.text = decoded.streetArea;
        _cityCtrl.text = decoded.city;
        _pincodeCtrl.text = decoded.pincode;
        _formattedAddress = decoded.formattedAddress;
        _isDetectingGps = false;
      });
    } catch (_) {
      setState(() => _isDetectingGps = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final fullFormatted = _formattedAddress.isNotEmpty
        ? _formattedAddress
        : "${_flatCtrl.text.trim()}, ${_streetCtrl.text.trim()}, ${_cityCtrl.text.trim()} ${_pincodeCtrl.text.trim()}";

    double saveLat = _latitude;
    double saveLng = _longitude;
    try {
      final geo = await LocationService().forwardGeocode(fullFormatted);
      if (geo != null) {
        saveLat = geo["latitude"] ?? saveLat;
        saveLng = geo["longitude"] ?? saveLng;
      }
    } catch (_) {}

    final newAddress = UserAddress(
      id: widget.existingAddress?.id ?? "addr_${DateTime.now().millisecondsSinceEpoch}",
      label: _selectedLabel,
      customLabel: _customLabelCtrl.text.trim(),
      flatBuilding: _flatCtrl.text.trim(),
      streetArea: _streetCtrl.text.trim(),
      landmark: _landmarkCtrl.text.trim(),
      city: _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : "Erode",
      state: "Tamil Nadu",
      pincode: _pincodeCtrl.text.trim(),
      formattedAddress: fullFormatted,
      latitude: saveLat,
      longitude: saveLng,
      isDefault: _isDefault,
      createdAt: widget.existingAddress?.createdAt ?? DateTime.now(),
    );

    final collection = widget.userRole == "worker" ? "workers" : "users";
    await LocationService().saveAddress(widget.userId, newAddress, collection: collection);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop(newAddress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFFF0EDE6), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 28,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E0D8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.existingAddress != null ? "edit_address_title".trSafe("Edit Address") : "add_new_address_title".trSafe("Add New Address"),
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1A1A1A), fontSize: 18, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: TextButton.icon(
                      onPressed: _isDetectingGps ? null : _autoDetectGps,
                      icon: _isDetectingGps
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFB800)))
                          : const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFFB45309)),
                      label: Text(
                        _isDetectingGps ? "detecting_gps_btn".trSafe("Detecting...") : "detect_gps_btn".trSafe("Detect GPS"),
                        style: const TextStyle(color: Color(0xFFB45309), fontSize: 12, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Address Label Selector Pills
              Text(
                "save_as_label".trSafe("Save As"),
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1A1A1A), fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AddressLabel.values.map((lbl) {
                  final isSelected = _selectedLabel == lbl;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(lbl.icon, size: 14, color: isSelected ? const Color(0xFF1E1035) : const Color(0xFF6B6B6B)),
                        const SizedBox(width: 6),
                        Text(
                          'address_label_${lbl.name}'.trSafe(lbl.displayName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFFB800),
                    backgroundColor: const Color(0xFFF9F6EE),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF1E1035) : const Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    onSelected: (val) => setState(() => _selectedLabel = lbl),
                  );
                }).toList(),
              ),

              if (_selectedLabel == AddressLabel.other) ...[
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _customLabelCtrl,
                  label: "custom_name_hint".trSafe("Custom Name (e.g. Mom's House, Workshop Hub)"),
                  icon: Icons.tag_rounded,
                ),
              ],
              const SizedBox(height: 14),

              // House / Flat / Block
              _buildTextField(
                controller: _flatCtrl,
                label: "house_flat_floor_label".trSafe("House / Flat / Block No. / Floor *"),
                icon: Icons.apartment_rounded,
                validator: (val) => val == null || val.trim().isEmpty ? "required_field".trSafe("Required") : null,
              ),
              const SizedBox(height: 10),

              // Street / Area
              _buildTextField(
                controller: _streetCtrl,
                label: "street_colony_area_label".trSafe("Street, Colony, Area *"),
                icon: Icons.signpost_rounded,
                validator: (val) => val == null || val.trim().isEmpty ? "required_field".trSafe("Required") : null,
              ),
              const SizedBox(height: 10),

              // Landmark
              _buildTextField(
                controller: _landmarkCtrl,
                label: "landmark_optional_label".trSafe("Nearby Landmark (Optional)"),
                icon: Icons.flag_rounded,
              ),
              const SizedBox(height: 10),

              // City & Pincode Row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _cityCtrl,
                      label: "city_required_label".trSafe("City *"),
                      icon: Icons.location_city_rounded,
                      validator: (val) => val == null || val.trim().isEmpty ? "required_field".trSafe("Required") : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _pincodeCtrl,
                      label: "pincode_required_label".trSafe("Pincode *"),
                      icon: Icons.pin_drop_rounded,
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.trim().isEmpty ? "required_field".trSafe("Required") : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Set as Default Checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                activeColor: const Color(0xFFFFB800),
                checkColor: const Color(0xFF1E1035),
                onChanged: (val) => setState(() => _isDefault = val ?? false),
                title: Text(
                  "set_as_default_service_address".trSafe("Set as default service address"),
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1A1A1A), fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: const Color(0xFF1E1035),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF1E1035),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              "save_address_btn".trSafe("Save Address"),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
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
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13.5, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB800), size: 18),
        filled: true,
        fillColor: const Color(0xFFF9F6EE),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF0EDE6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF0EDE6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFFB800), width: 1.5),
        ),
      ),
    );
  }
}

