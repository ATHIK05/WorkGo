import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../localization/trade_localization.dart';
import '../models/user_address.dart';
import '../services/location_service.dart';
import 'address_management_sheet.dart';

/// Shows the Swiggy/Zomato style location access prompt if user has no saved addresses.
Future<UserAddress?> showLocationPromptSheet(
  BuildContext context, {
  required String userId,
  String userRole = "customer", // "customer" or "worker"
}) async {
  return showModalBottomSheet<UserAddress>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LocationPromptContent(
      userId: userId,
      userRole: userRole,
    ),
  );
}

class _LocationPromptContent extends StatefulWidget {
  final String userId;
  final String userRole;

  const _LocationPromptContent({
    required this.userId,
    required this.userRole,
  });

  @override
  State<_LocationPromptContent> createState() => _LocationPromptContentState();
}

class _LocationPromptContentState extends State<_LocationPromptContent>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _radarCtrl;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectGpsLocation() async {
    setState(() => _isLoading = true);
    final locationService = LocationService();

    try {
      // 1. Get GPS Lat/Long
      final coords = await locationService.getCurrentCoordinates();
      final lat = coords["latitude"]!;
      final lon = coords["longitude"]!;

      // 2. Decode Geolocation to Address components
      final decoded = await locationService.reverseGeocode(lat, lon);

      // 3. Create default address
      final newAddress = decoded.toUserAddress(
        label: widget.userRole == "worker" ? AddressLabel.work : AddressLabel.home,
        isDefault: true,
      );

      // 4. Save to Firestore
      final collection = widget.userRole == "worker" ? "workers" : "users";
      await locationService.saveAddress(widget.userId, newAddress, collection: collection);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop(newAddress);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "location_detected_success".trSafe("Location set to ${decoded.streetArea}, ${decoded.city}", [decoded.streetArea, decoded.city]),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Location detection failed: $e"),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _enterManually() async {
    Navigator.of(context).pop();
    final address = await showAddAddressSheet(
      context,
      userId: widget.userId,
      userRole: widget.userRole,
    );
    if (address != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Address saved: ${address.shortSummary}"),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWorker = widget.userRole == "worker";

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
        children: [
          // Drag handle
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E0D8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Animated Radar Map Icon
          AnimatedBuilder(
            animation: _radarCtrl,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90 + (_radarCtrl.value * 24),
                    height: 90 + (_radarCtrl.value * 24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFB800).withValues(alpha: 0.25 * (1 - _radarCtrl.value)),
                    ),
                  ),
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB800), Color(0xFFF59E0B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB800).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF1E1035),
                      size: 38,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Title & Subtitle
          Text(
            isWorker
                ? "set_base_location_title".trSafe("Set Your Operating Base")
                : "set_service_location_title".trSafe("Set Your Service Location"),
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF1A1A1A),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isWorker
                ? "worker_location_desc".trSafe("WorkGo uses your location to dispatch nearby repair requests and calculate distance fares transparently.")
                : "customer_location_desc".trSafe("Allow location access to discover certified cooperative artisans near your doorstep and calculate transparent fares."),
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF6B6B6B),
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Action 1: Use Current Location (GPS)
          ElevatedButton(
            onPressed: _isLoading ? null : _detectGpsLocation,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: const Color(0xFFFFB800),
              foregroundColor: const Color(0xFF1E1035),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF1E1035),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.my_location_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        "use_current_location_btn".trSafe("Use Current Location (GPS)"),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // Action 2: Enter Manually
          OutlinedButton(
            onPressed: _isLoading ? null : _enterManually,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Color(0xFFE5E0D8), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              "enter_address_manually_btn".trSafe("Enter Address Manually"),
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Action 3: Skip for now
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Text(
              "skip_for_now".trSafe("Skip for now"),
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
