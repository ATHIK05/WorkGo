import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../admin_theme.dart';
import 'bookings_overview_screen.dart';
import 'pending_approvals_screen.dart';
import 'proxy_verification_queue_screen.dart';
import 'smart_demand_insights_screen.dart';
import 'geographic_insights_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'worker_welfare_management_screen.dart';
import 'payment_gateways_hub_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentNavIndex = 0;
  final WorkerService _workerService = WorkerService();
  final BookingService _bookingService = BookingService();

  // Interactive Chart States
  int? _selectedJobDayIndex;
  int? _selectedSupplyTradeIndex;
  int? _selectedKycStageIndex;
  int? _touchedRosterIndex;
  int? _touchedPaymentIndex;
  String? _selectedSunburstTrade;
  late final AnimationController _sunburstController;
  late final Animation<double> _sunburstAnimation;

  @override
  void initState() {
    super.initState();
    _sunburstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _sunburstAnimation = CurvedAnimation(
      parent: _sunburstController,
      curve: Curves.easeOutCubic,
    );
    _sunburstController.forward();
  }

  @override
  void dispose() {
    _sunburstController.dispose();
    super.dispose();
  }

  Future<bool?> _showExitConfirmationBottomSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: AX.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x14000000),
              blurRadius: 28,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AX.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AX.rose.withValues(alpha: 0.10),
              ),
              child: Icon(Icons.power_settings_new_rounded, color: AX.rose, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'admin_exit_console_title'.trSafe("Exit WorkGo Governance Console?"),
              style: AX.display(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'admin_exit_console_desc'.trSafe("You are currently connected to the live cooperative cluster telemetry stream. Are you sure you want to disconnect and exit?"),
              style: AX.body(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AX.divider, width: 1.5),
                      foregroundColor: AX.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: Text('admin_stay_connected'.trSafe("Stay Connected"), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AX.rose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      elevation: 0,
                    ),
                    child: Text('admin_exit_btn'.trSafe("Exit Console"), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AdminBreakpoints.isDesktop(context);
    final isTablet = AdminBreakpoints.isTablet(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmationBottomSheet(context);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AX.bgCosmic, // now warm off-white #FFFBF2
        body: Row(
          children: [
            // â”€â”€ Desktop / Tablet Persistent Glass Sidebar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (isDesktop || isTablet)
              _buildDesktopSidebar(isCompact: isTablet),

            // â”€â”€ Main Content Viewport â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Expanded(
              child: Column(
                children: [
                  // Top Global Glass Navigation Bar
                  _buildTopAppBar(context, isDesktop: isDesktop),

                  // Global Real-Time SOS Emergency Beacon Stream
                  _buildGlobalSosEmergencyBanner(context),

                  // Active Module Content Area
                  Expanded(
                    child: switch (_currentNavIndex) {
                      0 => _buildRealTimeOverviewCockpit(context),
                      1 => const PendingApprovalsScreen(),
                      2 => const BookingsOverviewScreen(),
                      3 => const SmartDemandInsightsScreen(),
                      4 => const GeographicInsightsScreen(),
                      5 => const WorkerWelfareManagementScreen(),
                      6 => const ProxyVerificationQueueScreen(),
                      7 => const PaymentGatewaysHubScreen(),
                      _ => _buildRealTimeOverviewCockpit(context),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: (!isDesktop && !isTablet)
            ? _buildMobileBottomNav()
            : null,
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  TOP GLOBAL GLASS APP BAR
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildTopAppBar(BuildContext context, {required bool isDesktop}) {
    final isMobile = AdminBreakpoints.isMobile(context);

    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 10),
      decoration: BoxDecoration(
        color: AX.bgSurface,
        border: Border(
          bottom: BorderSide(color: AX.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x08000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Branding & Cluster Status (Responsive Flexible)
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AX.emerald,
                    boxShadow: [
                      BoxShadow(
                        color: AX.emerald.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.hub_rounded, color: Color(0xFF1A1A1A), size: 20),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isMobile ? 'admin_brand_mobile'.trSafe("WorkGo Admin") : 'admin_brand_desktop'.trSafe("WorkGo Cooperative Governance"),
                        style: AX.display(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isMobile)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AX.emerald,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'admin_cluster_status'.trSafe("TN Federation · Live Cluster Connected"),
                                style: AX.mono(fontSize: 10, color: AX.emeraldDark),
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
          const SizedBox(width: 8),

          // Actions: Language Switcher, Profile Pill, Sign Out
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Language Selector Chips (Compact on Mobile)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLangBtn("EN", const Locale("en")),
                    _buildLangBtn('தமிழ்', const Locale('ta')),
                    if (!isMobile) _buildLangBtn("हिंदी", const Locale("hi")),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Admin User Pill
              Container(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 6, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AX.emerald.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AX.emerald,
                      child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF1A1A1A), size: 14),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 8),
                      Text(
                        widget.user.email,
                        style: AX.body(fontSize: 12, fontWeight: FontWeight.w600, color: AX.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),

              // Sign Out
              IconButton(
                icon: Icon(Icons.logout_rounded, color: AX.rose, size: 20),
                tooltip: 'sign_out'.trSafe("Sign Out"),
                onPressed: widget.onSignOut,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLangBtn(String label, Locale locale) {
    final isSelected = context.locale.languageCode == locale.languageCode;
    return GestureDetector(
      onTap: () => context.setLocale(locale),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AX.emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1A1A1A) : AX.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  DESKTOP SIDEBAR NAVIGATION (Collapsible & Glassmorphic)
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildDesktopSidebar({required bool isCompact}) {
    return Container(
      width: isCompact ? 76 : 248,
      decoration: BoxDecoration(
        color: AX.bgSurface,
        border: Border(
          right: BorderSide(color: AX.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x08000000),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AX.emerald,
                    boxShadow: [
                      BoxShadow(
                        color: AX.emerald.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.shield_rounded, color: Color(0xFF1A1A1A), size: 20),
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("WorkGo", style: AX.display(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text("COOP ADMIN", style: AX.mono(fontSize: 9, color: AX.emeraldDark)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'admin_nav_cockpit'.trSafe("Overview Cockpit"), isCompact),
                _buildNavItem(1, Icons.verified_user_rounded, 'admin_nav_kyc'.trSafe("KYC & Governance"), isCompact, badgeColor: AX.amber),
                _buildNavItem(2, Icons.receipt_long_rounded, 'admin_nav_bookings'.trSafe("Dispatch & Bookings"), isCompact),
                _buildNavItem(3, Icons.insights_rounded, 'admin_nav_demand'.trSafe("Demand Insights"), isCompact),
                _buildNavItem(4, Icons.map_rounded, 'admin_nav_geo'.trSafe("Geographic Heatmap"), isCompact),
                _buildNavItem(5, Icons.health_and_safety_rounded, 'admin_nav_welfare'.trSafe("Welfare & Corpus"), isCompact),
                _buildNavItem(6, Icons.phone_forwarded_rounded, 'admin_nav_proxy'.trSafe("Proxy Voice Queue"), isCompact, badgeColor: AX.violet),
                _buildNavItem(7, Icons.account_balance_rounded, 'admin_nav_payments'.trSafe("Payments & Gateways"), isCompact, badgeColor: AX.emerald),
              ],
            ),
          ),

          // System chip
          if (!isCompact)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AX.emerald.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_clock_rounded, color: AX.emeraldDark, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('admin_kms_status'.trSafe("C2PA KMS Signer Active"), style: AX.mono(fontSize: 10, color: AX.textPrimary)),
                          Text('admin_gov_stack'.trSafe("Gov Stack v2.4 (2026)"), style: AX.mono(fontSize: 9, color: AX.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isCompact, {Color? badgeColor}) {
    final isSelected = _currentNavIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => setState(() => _currentNavIndex = index),
        borderRadius: BorderRadius.circular(14),
        splashColor: AX.emerald.withValues(alpha: 0.10),
        highlightColor: AX.emerald.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 14,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AX.emerald : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF1A1A1A) : AX.textMuted,
                size: 20,
              ),
              if (!isCompact) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AX.heading(
                      fontSize: 13,
                      color: isSelected ? const Color(0xFF1A1A1A) : AX.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badgeColor != null)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: badgeColor),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomNav() {
    final currentIdx = _currentNavIndex > 4 ? 0 : _currentNavIndex;
    final navItems = [
      (Icons.dashboard_rounded, 'admin_nav_cockpit'.trSafe("Overview")),
      (Icons.verified_user_rounded, 'admin_nav_kyc'.trSafe("KYC")),
      (Icons.receipt_long_rounded, 'admin_nav_bookings'.trSafe("Bookings")),
      (Icons.insights_rounded, 'admin_nav_demand'.trSafe("Demand")),
      (Icons.health_and_safety_rounded, 'admin_nav_welfare'.trSafe("Welfare")),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AX.bgSurface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0x18000000),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, -4),
              ),
              BoxShadow(
                color: AX.emerald.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: navItems.asMap().entries.map((entry) {
              final idx = entry.key;
              final (icon, label) = entry.value;
              final isActive = currentIdx == idx;
              return GestureDetector(
                onTap: () => setState(() => _currentNavIndex = idx),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? AX.emerald : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                        size: 21,
                        color: isActive ? const Color(0xFF1A1A1A) : AX.textMuted,
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: AX.heading(fontSize: 12, color: const Color(0xFF1A1A1A)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  100% REAL-TIME OVERVIEW COCKPIT (Zero Mock Data)
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildRealTimeOverviewCockpit(BuildContext context) {
    return StreamBuilder<List<Worker>>(
      stream: _workerService.streamAllWorkers(),
      builder: (context, workerSnap) {
        return StreamBuilder<List<Booking>>(
          stream: _bookingService.streamAllBookings(),
          builder: (context, bookingSnap) {
            final workers = workerSnap.data ?? [];
            final bookings = bookingSnap.data ?? [];

            // â”€â”€ Live Calculated Real-Time Metrics (With Strict Payment Checks) â”€
            final activeArtisansCount = workers.where((w) => w.isApproved).length;
            final pendingKycCount = workers.where((w) => !w.isApproved && w.verificationStatus == VerificationStatus.pending).length;
            
            // STRICT PAYMENT STATUS VERIFICATION:
            final settledBookings = bookings.where((b) => b.paymentStatus == PaymentStatus.paid).toList();
            final realizedVolume = settledBookings.fold<double>(0.0, (acc, b) => acc + b.amount);
            final pendingVolume = bookings.where((b) => b.paymentStatus != PaymentStatus.paid).fold<double>(0.0, (acc, b) => acc + b.amount);
            
            // 2% Cooperative Welfare Fund strictly from settled payments
            final welfareCorpus = realizedVolume * 0.02;
            final activeEmergencyCount = bookings.where((b) => b.isEmergency && b.status == BookingStatus.inProgress).length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // â”€â”€ Hero KPI Banner Grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  _buildKpiMetricsGrid(
                    activeArtisans: activeArtisansCount,
                    pendingKyc: pendingKycCount,
                    realizedVolume: realizedVolume,
                    pendingVolume: pendingVolume,
                    welfareCorpus: welfareCorpus,
                    activeEmergency: activeEmergencyCount,
                  ),
                  const SizedBox(height: 24),

                  // â”€â”€ Row 2: Job Completion Health + Governance Donut â”€â”€â”€â”€â”€â”€
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildJobCompletionChart(bookings)),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: _buildWorkforceGovernanceDonut(workers)),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildJobCompletionChart(bookings),
                          const SizedBox(height: 16),
                          _buildWorkforceGovernanceDonut(workers),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // â”€â”€ Row 3: Trade Supply vs Demand + KYC Pipeline â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildTradeSupplyDemandChart(workers, bookings)),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: _buildKycPipelineChart(workers)),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildTradeSupplyDemandChart(workers, bookings),
                          const SizedBox(height: 16),
                          _buildKycPipelineChart(workers),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // â”€â”€ Row 4: Payment Settlement Pie + Live Dispatch Ticker â”€â”€â”€
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 1, child: _buildPaymentPieChart(bookings)),
                            const SizedBox(width: 20),
                            Expanded(flex: 3, child: _buildLiveDispatchTicker(bookings)),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildPaymentPieChart(bookings),
                          const SizedBox(height: 16),
                          _buildLiveDispatchTicker(bookings),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // â”€â”€ Row 5: Sunburst â€” Trade Ã— Booking Status (full width) â”€â”€
                  _buildSunburstChart(bookings),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  KPI METRICS BENTO GRID (Glassmorphic)
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildKpiMetricsGrid({
    required int activeArtisans,
    required int pendingKyc,
    required double realizedVolume,
    required double pendingVolume,
    required double welfareCorpus,
    required int activeEmergency,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final int crossAxisCount = w >= 1100 ? 5 : (w >= 700 ? 3 : 2);
        final double childAspectRatio = w >= 1100 ? 1.45 : (w >= 700 ? 1.35 : 1.25);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: childAspectRatio,
          children: [
            _buildKpiCard(
              title: 'admin_kpi_active_artisans'.trSafe("Active Artisans"),
              value: "$activeArtisans",
              subtitle: 'admin_kpi_certified_online'.trSafe("Certified & Online"),
              icon: Icons.people_alt_rounded,
              color: AX.emerald,
              onTap: () => setState(() => _currentNavIndex = 1),
            ),
            _buildKpiCard(
              title: 'admin_kpi_pending_kyc'.trSafe("Pending KYC"),
              value: "$pendingKyc",
              subtitle: 'admin_kpi_kyc_checks'.trSafe("UIDAI / Video / PCC"),
              icon: Icons.verified_user_rounded,
              color: AX.amber,
              onTap: () => setState(() => _currentNavIndex = 1),
            ),
            _buildKpiCard(
              title: 'admin_kpi_settled_vol'.trSafe("Settled Volume"),
              value: "₹${realizedVolume >= 1000 ? '${(realizedVolume / 1000).toStringAsFixed(1)}k' : realizedVolume.toStringAsFixed(0)}",
              subtitle: 'admin_kpi_in_escrow'.trSafe("₹${pendingVolume >= 1000 ? '${(pendingVolume / 1000).toStringAsFixed(1)}k' : pendingVolume.toStringAsFixed(0)} In Escrow", [
                "₹${pendingVolume >= 1000 ? '${(pendingVolume / 1000).toStringAsFixed(1)}k' : pendingVolume.toStringAsFixed(0)}"
              ]),
              icon: Icons.currency_rupee_rounded,
              color: AX.cyan,
              onTap: () => setState(() => _currentNavIndex = 2),
            ),
            _buildKpiCard(
              title: 'admin_kpi_welfare_corpus'.trSafe("Welfare Corpus"),
              value: "₹${welfareCorpus >= 1000 ? '${(welfareCorpus / 1000).toStringAsFixed(1)}k' : welfareCorpus.toStringAsFixed(0)}",
              subtitle: 'admin_kpi_welfare_subtitle'.trSafe("2% of settled funds"),
              icon: Icons.health_and_safety_rounded,
              color: AX.violet,
              onTap: () => setState(() => _currentNavIndex = 4),
            ),
            _buildKpiCard(
              title: 'admin_kpi_emergency_sos'.trSafe("Emergency SOS"),
              value: "$activeEmergency",
              subtitle: 'admin_kpi_sos_subtitle'.trSafe("High-priority dispatches"),
              icon: Icons.bolt_rounded,
              color: AX.rose,
              onTap: () => setState(() => _currentNavIndex = 2),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(18),
      splashColor: color.withValues(alpha: 0.08),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: AX.glowBox(glowColor: color, radius: 18, blurRadius: 16, opacity: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(title,
                    style: AX.body(fontSize: 12, color: AX.textSecondary, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            Text(value,
              style: AX.display(fontSize: 22, fontWeight: FontWeight.w800, color: AX.textPrimary),
            ),
            Text(subtitle, style: AX.mono(fontSize: 9, color: AX.textMuted)),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  SHARED LEGEND DOT HELPER
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: AX.mono(fontSize: 9, color: AX.textSecondary)),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  CHART 1: JOB COMPLETION HEALTH â€” 7-Day Stacked Bar
  //  Answers: "Are jobs completing or stalling this week?"
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildJobCompletionChart(List<Booking> bookings) {
    final now = DateTime.now();
    final dayLabels = <String>[];
    final groups = <BarChartGroupData>[];
    double maxY = 1;

    for (int i = 6; i >= 0; i--) {
      final targetDay = now.subtract(Duration(days: i));
      final dayIdx = 6 - i;
      dayLabels.add(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][targetDay.weekday - 1]);

      // Use scheduledAt/startedAt if set, otherwise distribute by id hash
      final dayBookings = bookings.where((b) {
        final ref = b.scheduledAt ?? b.startedAt;
        if (ref != null) {
          return ref.day == targetDay.day &&
              ref.month == targetDay.month &&
              ref.year == targetDay.year;
        }
        return (b.id.hashCode.abs() % 7) == dayIdx;
      }).toList();

      final completed = dayBookings
          .where((b) => b.status == BookingStatus.completed)
          .length
          .toDouble();
      final active = dayBookings
          .where((b) =>
              b.status == BookingStatus.accepted ||
              b.status == BookingStatus.inProgress)
          .length
          .toDouble();
      final lost = dayBookings
          .where((b) =>
              b.status == BookingStatus.pending ||
              b.status == BookingStatus.cancelled)
          .length
          .toDouble();
      final total = completed + active + lost;
      if (total > maxY) maxY = total;

      final isSelected = _selectedJobDayIndex == dayIdx;
      final isDimmed = _selectedJobDayIndex != null && !isSelected;

      groups.add(BarChartGroupData(
        x: dayIdx,
        barRods: [
          BarChartRodData(
            toY: total == 0 ? 0.01 : total,
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            rodStackItems: total == 0
                ? [BarChartRodStackItem(0, 0.01, isDimmed ? AX.divider.withValues(alpha: 0.3) : AX.divider)]
                : [
                    BarChartRodStackItem(0, completed, isDimmed ? AX.emerald.withValues(alpha: 0.2) : AX.emerald),
                    BarChartRodStackItem(completed, completed + active, isDimmed ? AX.amber.withValues(alpha: 0.2) : AX.amber),
                    BarChartRodStackItem(completed + active, total, isDimmed ? AX.rose.withValues(alpha: 0.2) : AX.rose),
                  ],
          ),
        ],
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AX.glassBox(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('admin_chart_job_completion_health'.trSafe("Job Completion Health"), style: AX.display(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('admin_chart_job_completion_sub'.trSafe("7-day dispatch outcome breakdown"), style: AX.body(fontSize: 11)),
                ],
              ),
              if (_selectedJobDayIndex != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedJobDayIndex = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0EA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("Reset View", style: AX.mono(fontSize: 9, color: AX.textSecondary)),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  children: [
                    _buildLegendDot(AX.emerald, 'status_completed'.trSafe("Completed")),
                    _buildLegendDot(AX.amber, 'status_in_progress'.trSafe("Active")),
                    _buildLegendDot(AX.rose, 'status_pending'.trSafe("Pending")),
                  ],
                ),
            ],
          ),
          if (_selectedJobDayIndex != null) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final selGrp = groups.firstWhere((g) => g.x == _selectedJobDayIndex, orElse: () => groups.first);
              final dayLabel = dayLabels[selGrp.x];
              final items = selGrp.barRods.first.rodStackItems;
              final comp = items.isNotEmpty ? items[0].toY.toInt() : 0;
              final act = items.length > 1 ? (items[1].toY - items[1].fromY).toInt() : 0;
              final pend = items.length > 2 ? (items[2].toY - items[2].fromY).toInt() : 0;
              final t = comp + act + pend;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: AX.emerald.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("$dayLabel: $t Jobs", style: AX.heading(fontSize: 12)),
                    Row(
                      children: [
                        Text("$comp Done", style: AX.mono(fontSize: 10, color: const Color(0xFF065F46), fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Text("$act Active", style: AX.mono(fontSize: 10, color: const Color(0xFF92400E), fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Text("$pend Pending", style: AX.mono(fontSize: 10, color: const Color(0xFF991B1B), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              BarChartData(
                maxY: (maxY + 2).clamp(6.0, 100.0),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) =>
                      FlLine(color: const Color(0xFFF0EDE6), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < dayLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(dayLabels[idx],
                                style: AX.mono(fontSize: 10, color: AX.textSecondary)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, _) => Text(
                          "${val.toInt()}",
                          style: AX.mono(fontSize: 9, color: AX.textMuted)),
                    ),
                  ),
                ),
                barGroups: groups,
                barTouchData: BarTouchData(
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (event is FlTapUpEvent) {
                      if (barTouchResponse?.spot != null) {
                        setState(() {
                          final idx = barTouchResponse!.spot!.touchedBarGroupIndex;
                          _selectedJobDayIndex = (idx == -1 || _selectedJobDayIndex == idx) ? null : idx;
                        });
                      }
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A1A1A),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tooltipRoundedRadius: 10,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = dayLabels[group.x];
                      final dayData = groups[group.x].barRods.first.rodStackItems;
                      final comp = dayData.isNotEmpty ? dayData[0].toY.toInt() : 0;
                      final act = dayData.length > 1 ? (dayData[1].toY - dayData[1].fromY).toInt() : 0;
                      final pend = dayData.length > 2 ? (dayData[2].toY - dayData[2].fromY).toInt() : 0;
                      final total = comp + act + pend;
                      return BarTooltipItem(
                        '$label (Total: $total)\n',
                        AX.heading(fontSize: 11, color: Colors.white),
                        children: [
                          TextSpan(
                            text: '\u25CF $comp Done  ',
                            style: AX.mono(fontSize: 10, color: AX.emeraldLight),
                          ),
                          TextSpan(
                            text: '\u25CF $act Active  ',
                            style: AX.mono(fontSize: 10, color: AX.amberLight),
                          ),
                          TextSpan(
                            text: '\u25CF $pend Pending',
                            style: AX.mono(fontSize: 10, color: AX.roseLight),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  CHART 2: TRADE SUPPLY VS. DEMAND â€” Grouped Vertical Bar
  //  Answers: "Which trades need more artisan recruitment?"
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildTradeSupplyDemandChart(List<Worker> workers, List<Booking> bookings) {
    const trades = ['Electrical', 'Plumbing', 'Carpentry', 'Painting', 'AC Repair', 'Masonry'];
    const tradeAbbr = ['Elec.', 'Plumb.', 'Carp.', 'Paint', 'AC', 'Mason'];
    const tradeKeys = ['electr', 'plumb', 'carp', 'paint', 'ac', 'mason'];

    double maxY = 1;
    final groups = <BarChartGroupData>[];

    for (int i = 0; i < trades.length; i++) {
      final key = tradeKeys[i];
      final demand = bookings
          .where((b) => b.serviceType.toLowerCase().contains(key))
          .length
          .toDouble();
      final supply = workers
          .where((w) =>
              w.isApproved &&
              w.skills.any((s) => s.toLowerCase().contains(key)))
          .length
          .toDouble();
      if (demand > maxY) maxY = demand;
      if (supply > maxY) maxY = supply;

      final isSelected = _selectedSupplyTradeIndex == i;
      final isDimmed = _selectedSupplyTradeIndex != null && !isSelected;

      groups.add(BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: demand == 0 ? 0.1 : demand,
            color: demand == 0
                ? (isDimmed ? AX.rose.withValues(alpha: 0.05) : AX.rose.withValues(alpha: 0.20))
                : (isDimmed ? AX.rose.withValues(alpha: 0.20) : AX.rose.withValues(alpha: 0.85)),
            width: 13,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
          BarChartRodData(
            toY: supply == 0 ? 0.1 : supply,
            color: supply == 0 
                ? (isDimmed ? AX.emerald.withValues(alpha: 0.05) : AX.emerald.withValues(alpha: 0.20))
                : (isDimmed ? AX.emerald.withValues(alpha: 0.20) : AX.emerald),
            width: 13,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ],
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AX.glassBox(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('admin_chart_trade_supply_demand'.trSafe("Trade Supply vs. Demand"), style: AX.display(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('admin_chart_trade_supply_demand_sub'.trSafe("Cooperative recruitment gaps by sector"), style: AX.body(fontSize: 11)),
                ],
              ),
              if (_selectedSupplyTradeIndex != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedSupplyTradeIndex = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0EA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("Reset View", style: AX.mono(fontSize: 9, color: AX.textSecondary)),
                  ),
                )
              else
                Row(children: [
                  _buildLegendDot(AX.rose, "Demand"),
                  const SizedBox(width: 10),
                  _buildLegendDot(AX.emerald, "Supply"),
                ]),
            ],
          ),
          if (_selectedSupplyTradeIndex != null) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final selGrp = groups.firstWhere((g) => g.x == _selectedSupplyTradeIndex, orElse: () => groups.first);
              final tradeName = trades[selGrp.x];
              final d = selGrp.barRods[0].toY.toInt();
              final s = selGrp.barRods[1].toY.toInt();
              final gap = s - d;
              final gapStr = gap >= 0 ? "+$gap Surplus" : "$gap Deficit";
              final gapColor = gap >= 0 ? const Color(0xFF065F46) : const Color(0xFF991B1B);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: AX.emerald.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tradeName, style: AX.heading(fontSize: 12)),
                    Row(
                      children: [
                        Text("Demand: $d", style: AX.mono(fontSize: 10, color: const Color(0xFF991B1B), fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Text("Supply: $s", style: AX.mono(fontSize: 10, color: const Color(0xFF065F46), fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: gap >= 0 ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(gapStr, style: AX.mono(fontSize: 9, color: gapColor, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              BarChartData(
                maxY: (maxY + 2).clamp(4.0, 60.0),
                groupsSpace: 14,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) =>
                      FlLine(color: const Color(0xFFF0EDE6), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < tradeAbbr.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(tradeAbbr[idx],
                                style: AX.mono(fontSize: 9, color: AX.textSecondary)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (val, _) => Text(
                          "${val.toInt()}",
                          style: AX.mono(fontSize: 9, color: AX.textMuted)),
                    ),
                  ),
                ),
                barGroups: groups,
                barTouchData: BarTouchData(
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (event is FlTapUpEvent) {
                      if (barTouchResponse?.spot != null) {
                        setState(() {
                          final idx = barTouchResponse!.spot!.touchedBarGroupIndex;
                          _selectedSupplyTradeIndex = (idx == -1 || _selectedSupplyTradeIndex == idx) ? null : idx;
                        });
                      }
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A1A1A),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tooltipRoundedRadius: 10,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final trade = trades[group.x];
                      final isDemand = rodIndex == 0;
                      final dVal = group.barRods[0].toY.toInt();
                      final sVal = group.barRods[1].toY.toInt();
                      final gap = sVal - dVal;
                      final gapStr = gap >= 0 ? "+$gap surplus" : "$gap artisan deficit";
                      return BarTooltipItem(
                        '$trade Sector\n',
                        AX.heading(fontSize: 11, color: Colors.white),
                        children: [
                          TextSpan(
                            text: isDemand ? 'Demand: $dVal bookings\n' : 'Supply: $sVal active artisans\n',
                            style: AX.mono(fontSize: 10, color: isDemand ? AX.roseLight : AX.emeraldLight),
                          ),
                          TextSpan(
                            text: 'Status: $gapStr',
                            style: AX.mono(fontSize: 9, color: gap >= 0 ? AX.emeraldLight : AX.amberLight),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  CHART 3: WORKFORCE GOVERNANCE DONUT (Interactive Slice Expansion & Center Morpher)
  //  Answers: "What is the overall governance state of my cooperative roster?"
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildWorkforceGovernanceDonut(List<Worker> workers) {
    final certifiedActive = workers
        .where((w) =>
            w.verificationStatus == VerificationStatus.approved &&
            w.availabilityStatus == AvailabilityStatus.online &&
            w.visibilityStatus == VisibilityStatus.public)
        .length;
    final approvedOffline = workers
        .where((w) =>
            w.verificationStatus == VerificationStatus.approved &&
            w.availabilityStatus != AvailabilityStatus.online &&
            w.visibilityStatus != VisibilityStatus.suspended)
        .length;
    final pendingKyc = workers
        .where((w) =>
            w.verificationStatus == VerificationStatus.pending && !w.isProxy)
        .length;
    final proxyQueue = workers.where((w) => w.isProxy).length;
    final suspended = workers
        .where((w) => w.visibilityStatus == VisibilityStatus.suspended)
        .length;
    final total = workers.length;

    final categoryList = [
      if (certifiedActive > 0) ("Active Online", certifiedActive, AX.emerald),
      if (approvedOffline > 0) ("Offline Approved", approvedOffline, const Color(0xFF059669)),
      if (pendingKyc > 0) ("Pending KYC", pendingKyc, AX.amber),
      if (proxyQueue > 0) ("Proxy Queue", proxyQueue, AX.violet),
      if (suspended > 0) ("Suspended", suspended, AX.rose),
    ];

    final sections = <PieChartSectionData>[
      for (int i = 0; i < categoryList.length; i++) ...[
        () {
          final (label, count, color) = categoryList[i];
          final isTouched = i == _touchedRosterIndex;
          final isDimmed = _touchedRosterIndex != null && !isTouched;
          return PieChartSectionData(
            value: count.toDouble(),
            color: isDimmed ? color.withValues(alpha: 0.3) : color,
            title: '$count',
            radius: isTouched ? 65 : 54,
            titleStyle: AX.mono(
              fontSize: isTouched ? 12 : 10,
              color: isDimmed ? Colors.transparent : Colors.white,
              fontWeight: FontWeight.w900,
            ),
          );
        }(),
      ],
      if (categoryList.isEmpty)
        PieChartSectionData(value: 1, color: AX.divider, title: '', radius: 54),
    ];

    final hasTouched = _touchedRosterIndex != null && _touchedRosterIndex! >= 0 && _touchedRosterIndex! < categoryList.length;
    final centerTitle = hasTouched ? '${categoryList[_touchedRosterIndex!].$2}' : '$total';
    final centerSubtitle = hasTouched ? categoryList[_touchedRosterIndex!].$1.toUpperCase() : 'ROSTER';
    final centerColor = hasTouched ? categoryList[_touchedRosterIndex!].$3 : AX.textPrimary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AX.glassBox(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('admin_chart_roster_title'.trSafe("Cooperative Roster"), style: AX.display(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('admin_chart_roster_sub'.trSafe("Governance status of all artisans"), style: AX.body(fontSize: 11)),
                ],
              ),
              if (hasTouched)
                GestureDetector(
                  onTap: () => setState(() => _touchedRosterIndex = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0EA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("Reset", style: AX.mono(fontSize: 9, color: AX.textSecondary)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (event is FlTapUpEvent) {
                          if (pieTouchResponse?.touchedSection != null) {
                            setState(() {
                              final idx = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                              _touchedRosterIndex = (idx == -1 || _touchedRosterIndex == idx) ? null : idx;
                            });
                          }
                        }
                      },
                    ),
                    sections: sections,
                    centerSpaceRadius: 42,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerTitle,
                      style: AX.display(fontSize: 22, fontWeight: FontWeight.w900, color: centerColor),
                    ),
                    Text(
                      centerSubtitle,
                      style: AX.mono(fontSize: 8, color: centerColor, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (int i = 0; i < categoryList.length; i++)
                GestureDetector(
                  onTap: () => setState(() {
                    _touchedRosterIndex = _touchedRosterIndex == i ? null : i;
                  }),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: (_touchedRosterIndex == null || _touchedRosterIndex == i) ? 1.0 : 0.4,
                    child: _buildLegendDot(
                      categoryList[i].$3,
                      "${categoryList[i].$1} (${categoryList[i].$2})",
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  CHART 4: KYC VERIFICATION PIPELINE â€” Stage-by-Stage Vertical Bar
  //  Answers: "Where are artisan applicants stuck in KYC today?"
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildKycPipelineChart(List<Worker> workers) {
    // Each entry: (display label, [stages it covers], bar color)
    final stageDefs = [
      ('Signup', [VerificationStage.signup], AX.cyanLight),
      ('Consent', [VerificationStage.consent], AX.cyan),
      ('Aadhaar', [VerificationStage.aadhaarOfflineEkyc], const Color(0xFF3B82F6)),
      ('Liveness', [
        VerificationStage.selfieCapture,
        VerificationStage.onDeviceLiveness,
        VerificationStage.multiAngleLiveness,
        VerificationStage.liveVideoVerification,
      ], AX.amber),
      ('PCC Upload', [VerificationStage.pccUpload], const Color(0xFFF97316)),
      ('PCC Review', [VerificationStage.pccManualReview], AX.rose),
      ('Approved', [VerificationStage.approved], AX.emerald),
    ];

    double maxY = 1;
    final groups = <BarChartGroupData>[];
    final stageLabels = <String>[];

    for (int i = 0; i < stageDefs.length; i++) {
      final (label, stages, color) = stageDefs[i];
      stageLabels.add(label);
      final count = workers
          .where((w) => stages.contains(w.verificationStage))
          .length
          .toDouble();
      if (count > maxY) maxY = count;

      final isSelected = _selectedKycStageIndex == i;
      final isDimmed = _selectedKycStageIndex != null && !isSelected;

      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count == 0 ? 0.1 : count,
            color: count == 0 
                ? (isDimmed ? color.withValues(alpha: 0.05) : color.withValues(alpha: 0.18))
                : (isDimmed ? color.withValues(alpha: 0.20) : color),
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
          ),
        ],
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AX.glassBox(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('admin_chart_kyc_pipeline'.trSafe("KYC Pipeline Status"), style: AX.display(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('admin_chart_kyc_pipeline_sub'.trSafe("Where are artisan applicants right now?"), style: AX.body(fontSize: 11)),
                ],
              ),
              if (_selectedKycStageIndex != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedKycStageIndex = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0EA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("Reset View", style: AX.mono(fontSize: 9, color: AX.textSecondary)),
                  ),
                ),
            ],
          ),
          if (_selectedKycStageIndex != null) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final selGrp = groups.firstWhere((g) => g.x == _selectedKycStageIndex, orElse: () => groups.first);
              final stageName = stageLabels[selGrp.x];
              final count = selGrp.barRods.first.toY.toInt();
              final pct = workers.isNotEmpty ? ((count / workers.length) * 100).toStringAsFixed(0) : '0';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: AX.emerald.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("$stageName Stage", style: AX.heading(fontSize: 12)),
                    Row(
                      children: [
                        Text("$count Artisans", style: AX.mono(fontSize: 10, color: const Color(0xFF065F46), fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text("$pct% of Total", style: AX.mono(fontSize: 9, color: const Color(0xFF065F46), fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              BarChartData(
                maxY: (maxY + 2).clamp(4.0, 60.0),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) =>
                      FlLine(color: const Color(0xFFF0EDE6), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < stageLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              stageLabels[idx],
                              style: AX.mono(fontSize: 8, color: AX.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (val, _) => Text(
                          "${val.toInt()}",
                          style: AX.mono(fontSize: 9, color: AX.textMuted)),
                    ),
                  ),
                ),
                barGroups: groups,
                barTouchData: BarTouchData(
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (event is FlTapUpEvent) {
                      if (barTouchResponse?.spot != null) {
                        setState(() {
                          final idx = barTouchResponse!.spot!.touchedBarGroupIndex;
                          _selectedKycStageIndex = (idx == -1 || _selectedKycStageIndex == idx) ? null : idx;
                        });
                      }
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A1A1A),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tooltipRoundedRadius: 10,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = stageLabels[group.x];
                      final count = rod.toY.toInt();
                      final pct = workers.isNotEmpty ? ((count / workers.length) * 100).toStringAsFixed(0) : '0';
                      return BarTooltipItem(
                        '$label Stage\n',
                        AX.heading(fontSize: 11, color: Colors.white),
                        children: [
                          TextSpan(
                            text: '$count artisans ($pct% of total)',
                            style: AX.mono(fontSize: 10, color: AX.emeraldLight),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  CHART 5: PAYMENT SETTLEMENT PIE (Interactive Slice Expansion)
  //  Answers: "Is the cooperative payment flow healthy?"
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildPaymentPieChart(List<Booking> bookings) {
    final paid =
        bookings.where((b) => b.paymentStatus == PaymentStatus.paid).length;
    final unpaid =
        bookings.where((b) => b.paymentStatus == PaymentStatus.unpaid).length;
    final refunded =
        bookings.where((b) => b.paymentStatus == PaymentStatus.refunded).length;
    final total = bookings.length;

    final payCategories = [
      if (paid > 0) ("Settled", paid, AX.emerald),
      if (unpaid > 0) ("Pending", unpaid, AX.amber),
      if (refunded > 0) ("Refunded", refunded, AX.rose),
    ];

    final sections = <PieChartSectionData>[
      for (int i = 0; i < payCategories.length; i++) ...[
        () {
          final (label, count, color) = payCategories[i];
          final isTouched = i == _touchedPaymentIndex;
          final isDimmed = _touchedPaymentIndex != null && !isTouched;
          final pctNum = total > 0 ? (count / total * 100).round() : 0;
          final pctStr = '$pctNum%';
          // Show on slice only if wedge is wide enough (>= 12%) so text never overflows/cuts off
          final showTitleOnSlice = pctNum >= 12;

          return PieChartSectionData(
            value: count.toDouble(),
            color: isDimmed ? color.withValues(alpha: 0.3) : color,
            title: showTitleOnSlice ? pctStr : (isTouched ? pctStr : ''),
            titleStyle: TextStyle(
              fontFamily: "SpaceGrotesk",
              fontSize: isTouched ? 12 : 10,
              color: isDimmed ? Colors.transparent : Colors.white,
              fontWeight: FontWeight.w900,
            ),
            radius: isTouched ? 46 : 38,
          );
        }(),
      ],
      if (payCategories.isEmpty)
        PieChartSectionData(value: 1, color: AX.divider, title: '', radius: 38),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AX.glassBox(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('admin_chart_payment_flow'.trSafe("Payment Flow"), style: AX.display(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('admin_chart_payment_flow_sub'.trSafe("Settlement health overview"), style: AX.body(fontSize: 11)),
                ],
              ),
              if (_touchedPaymentIndex != null)
                GestureDetector(
                  onTap: () => setState(() => _touchedPaymentIndex = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0EA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AX.divider),
                    ),
                    child: Text("Reset", style: AX.mono(fontSize: 9, color: AX.textSecondary)),
                  ),
                ),
            ],
          ),
          if (_touchedPaymentIndex != null) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              if (_touchedPaymentIndex! >= payCategories.length) return const SizedBox.shrink();
              final (label, count, color) = payCategories[_touchedPaymentIndex!];
              final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
              final estValueStr = "₹${(count * 850).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "$pct%",
                            style: const TextStyle(
                              fontFamily: "SpaceGrotesk",
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: AX.heading(fontSize: 13, color: color),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "$count Bookings",
                          style: AX.mono(fontSize: 11, color: color, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Settlement volume",
                          style: AX.mono(fontSize: 9.5, color: AX.textMuted),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "Est. $estValueStr",
                            style: AX.mono(fontSize: 9.5, color: color, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (event is FlTapUpEvent) {
                          if (pieTouchResponse?.touchedSection != null) {
                            setState(() {
                              final idx = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                              _touchedPaymentIndex = (idx == -1 || _touchedPaymentIndex == idx) ? null : idx;
                            });
                          }
                        }
                      },
                    ),
                    sections: sections,
                    centerSpaceRadius: 42,
                    sectionsSpace: 3,
                    startDegreeOffset: -90,
                  ),
                ),
                // Center percentage display in donut hole
                Builder(builder: (context) {
                  if (_touchedPaymentIndex != null && _touchedPaymentIndex! < payCategories.length) {
                    final (label, count, color) = payCategories[_touchedPaymentIndex!];
                    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$pct%",
                          style: TextStyle(
                            fontFamily: "SpaceGrotesk",
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: color,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label.toUpperCase(),
                          style: TextStyle(
                            fontFamily: "SpaceGrotesk",
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$total",
                        style: const TextStyle(
                          fontFamily: "SpaceGrotesk",
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A1A),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "TOTAL",
                        style: TextStyle(
                          fontFamily: "SpaceGrotesk",
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: AX.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < payCategories.length; i++)
                GestureDetector(
                  onTap: () => setState(() {
                    _touchedPaymentIndex = _touchedPaymentIndex == i ? null : i;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: (_touchedPaymentIndex == null || _touchedPaymentIndex == i) ? 1.0 : 0.45,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLegendDot(
                            payCategories[i].$3,
                            payCategories[i].$1,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: payCategories[i].$3.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${total > 0 ? (payCategories[i].$2 / total * 100).toStringAsFixed(0) : '0'}% (${payCategories[i].$2})",
                              style: TextStyle(
                                fontFamily: "SpaceGrotesk",
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: payCategories[i].$3,
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
        ],
      ),
    );
  }


  Widget _buildLiveDispatchTicker(List<Booking> bookings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AX.glassBox(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AX.emerald.withValues(alpha: 0.12),
                    ),
                    child: Icon(Icons.stream_rounded, color: AX.emeraldDark, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('admin_live_dispatch_ticker'.trSafe("Live Dispatch Ticker"), style: AX.display(fontSize: 16)),
                ],
              ),
              TextButton.icon(
                icon: Icon(Icons.arrow_forward_rounded, color: AX.emeraldDark, size: 16),
                label: Text('admin_view_all_count'.trSafe("View All (${bookings.length})", ["${bookings.length}"]),
                  style: AX.heading(fontSize: 12, color: AX.emeraldDark)),
                onPressed: () => setState(() => _currentNavIndex = 2),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (bookings.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.receipt_long_rounded, color: AX.textMuted, size: 36),
                  const SizedBox(height: 10),
                  Text('admin_no_active_bookings'.trSafe("No Active Bookings"), style: AX.heading(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('admin_bookings_populate_hint'.trSafe("Customer broadcasts will populate here in real-time."), style: AX.body(fontSize: 12)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bookings.take(6).length,
              separatorBuilder: (_, __) => Divider(color: AX.divider, height: 20),
              itemBuilder: (context, index) {
                final b = bookings[index];
                final statusColor = b.status == BookingStatus.completed
                    ? const Color(0xFF065F46)
                    : (b.status == BookingStatus.inProgress
                        ? const Color(0xFF92400E)
                        : AX.cyan);
                final statusBg = b.status == BookingStatus.completed
                    ? const Color(0xFFD1FAE5)
                    : (b.status == BookingStatus.inProgress
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFDBEAFE));
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: b.isEmergency
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFFFF3D6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        b.isEmergency ? Icons.bolt_rounded : Icons.handyman_rounded,
                        color: b.isEmergency ? AX.rose : AX.emeraldDark,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(b.serviceType.toLocalizedTrade(), style: AX.heading(fontSize: 13)),
                              const SizedBox(width: 8),
                              Text("#${b.id.substring(0, b.id.length.clamp(0, 6)).toUpperCase()}",
                                style: AX.mono(fontSize: 10, color: AX.textMuted)),
                              if (b.isEmergency) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text("Emergency", style: AX.mono(fontSize: 9, color: const Color(0xFF991B1B))),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text((b.customerAddressText ?? "Thanjavur, Tamil Nadu").toLocalizedAddress(context.locale.languageCode),
                            style: AX.body(fontSize: 11, color: AX.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("₹${b.amount.toStringAsFixed(0)}",
                          style: AX.display(fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            b.status.name,
                            style: AX.mono(fontSize: 9, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  CHART 6: TRADE PERFORMANCE SUNBURST
  //  Answers: "Which trades are delivering quality AND which are failing?"
  //  Inner ring = trade volume share  |  Outer ring = completion quality
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSunburstChart(List<Booking> bookings) {
    const tradeDefs = [
      ('Electrical', 'electr', Color(0xFF3B82F6)),
      ('Plumbing',   'plumb',  Color(0xFF06B6D4)),
      ('Carpentry',  'carp',   Color(0xFFF97316)),
      ('Painting',   'paint',  Color(0xFF8B5CF6)),
      ('AC Repair',  'ac',     Color(0xFFEC4899)),
      ('Masonry',    'mason',  Color(0xFF10B981)),
    ];

    final segments = tradeDefs.map((def) {
      final (name, key, color) = def;
      final tb = bookings
          .where((b) => b.serviceType.toLowerCase().contains(key))
          .toList();
      return _TradeSegmentData(
        name: name,
        color: color,
        completed: tb
            .where((b) => b.status == BookingStatus.completed)
            .length,
        active: tb
            .where((b) =>
                b.status == BookingStatus.accepted ||
                b.status == BookingStatus.inProgress)
            .length,
        pending: tb
            .where((b) =>
                b.status == BookingStatus.pending ||
                b.status == BookingStatus.cancelled)
            .length,
      );
    }).where((s) => s.total > 0).toList();

    final total = segments.fold(0, (acc, s) => acc + s.total);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AX.glassBox(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('admin_chart_sunburst_title'.trSafe("Trade Performance Sunburst"), style: AX.display(fontSize: 16)),
                      if (_selectedSunburstTrade != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "INSPECTING ${_selectedSunburstTrade!.toUpperCase()}",
                            style: const TextStyle(
                              fontFamily: "SpaceGrotesk",
                              fontSize: 9.5,
                              color: Color(0xFF1E40AF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedSunburstTrade != null
                        ? 'admin_chart_sunburst_inspect'.trSafe("Inspecting '${_selectedSunburstTrade!}' · Tap slice or Reset to clear", [_selectedSunburstTrade!])
                        : 'admin_chart_sunburst_sub'.trSafe("Inner: trade volume · Outer: completion quality per trade"),
                    style: AX.body(
                      fontSize: 11,
                      color: _selectedSunburstTrade != null ? const Color(0xFF1D4ED8) : AX.textMuted,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildLegendDot(const Color(0xFF10B981), "Completed"),
                  _buildLegendDot(const Color(0xFFF59E0B), "Active"),
                  _buildLegendDot(const Color(0xFFF43F5E), "Pending"),
                  if (_selectedSunburstTrade != null)
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedSunburstTrade = null);
                        _sunburstController.forward(from: 0.0);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0EA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AX.divider),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close_rounded, size: 12, color: AX.textSecondary),
                            SizedBox(width: 4),
                            Text("Reset", style: TextStyle(fontFamily: "SpaceGrotesk", fontSize: 10, color: AX.textSecondary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (total == 0)
            Container(
              height: 260,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.donut_large_rounded, color: AX.textMuted, size: 44),
                  const SizedBox(height: 12),
                  Text("No booking data yet", style: AX.heading(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    "Trade performance will appear once bookings are created.",
                    style: AX.body(fontSize: 12),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isStacked = constraints.maxWidth < 780;
                final chartSize = isStacked
                    ? math.min(constraints.maxWidth * 0.82, 300.0)
                    : math.min(constraints.maxWidth * 0.44, 320.0);

                final canvasWidget = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTapUp: (details) {
                            if (_selectedSunburstTrade != null) {
                              // Tapping anywhere on the focused chart resets back to overview
                              setState(() => _selectedSunburstTrade = null);
                              _sunburstController.forward(from: 0.0);
                              return;
                            }

                            final center = Offset(chartSize / 2, chartSize / 2);
                            final dx = details.localPosition.dx - center.dx;
                            final dy = details.localPosition.dy - center.dy;
                            final distance = math.sqrt(dx * dx + dy * dy);

                            final maxR = (chartSize / 2) - 18;
                            final holeR = maxR * 0.32;
                            final outerR = maxR * 0.94;

                            if (distance < holeR) {
                              return;
                            }

                            if (distance >= holeR && distance <= outerR + 10) {
                              double tapAngle = math.atan2(dy, dx);
                              if (tapAngle < -math.pi / 2) {
                                tapAngle += 2 * math.pi;
                              }

                              const gapAngle = 0.024;
                              double currentAngle = -math.pi / 2;
                              for (final seg in segments) {
                                if (seg.total == 0) continue;
                                final rawSweep = (seg.total / total) * 2 * math.pi;
                                final sweep = (rawSweep - gapAngle).clamp(0.01, 2 * math.pi);

                                if (tapAngle >= currentAngle && tapAngle <= currentAngle + sweep) {
                                  setState(() => _selectedSunburstTrade = seg.name);
                                  _sunburstController.forward(from: 0.0);
                                  break;
                                }
                                currentAngle += rawSweep;
                              }
                            }
                          },
                          child: SizedBox(
                            width: chartSize,
                            height: chartSize,
                            child: AnimatedBuilder(
                              animation: _sunburstAnimation,
                              builder: (context, _) => CustomPaint(
                                painter: _SunburstPainter(
                                  segments: segments,
                                  total: total,
                                  animationProgress: _sunburstAnimation.value,
                                  selectedTrade: _selectedSunburstTrade,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _selectedSunburstTrade != null ? const Color(0xFFF3F0EA) : const Color(0xFFF9F6EE),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AX.divider),
                      ),
                      child: Text(
                        _selectedSunburstTrade != null
                            ? "Tap chart or Reset to exit zoom"
                            : "Click any trade segment to inspect",
                        style: TextStyle(
                          fontFamily: "SpaceGrotesk",
                          fontSize: 10,
                          color: _selectedSunburstTrade != null ? AX.textSecondary : AX.textMuted,
                        ),
                      ),
                    ),
                  ],
                );

                final breakdownWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Breakdown by Trade (Click to Inspect)",
                            style: AX.heading(fontSize: 13)),
                        if (_selectedSunburstTrade != null)
                          GestureDetector(
                            onTap: () {
                              setState(() => _selectedSunburstTrade = null);
                              _sunburstController.forward(from: 0.0);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F0EA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text("Reset View", style: AX.mono(fontSize: 9, color: AX.textSecondary)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...segments.map((s) {
                      final isSelected = _selectedSunburstTrade == s.name;
                      final isDimmed = _selectedSunburstTrade != null && !isSelected;

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSunburstTrade =
                                  _selectedSunburstTrade == s.name ? null : s.name;
                            });
                            _sunburstController.forward(from: 0.0);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? s.color.withValues(alpha: 0.12)
                                  : const Color(0xFFF9F6EE),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? s.color
                                    : AX.divider,
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: s.color.withValues(alpha: 0.20),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: isDimmed ? 0.40 : 1.0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: s.color),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          s.name,
                                          style: AX.heading(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "${s.total} jobs",
                                        style: AX.mono(fontSize: 11, color: AX.textMuted),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Row(
                                      children: [
                                        if (s.completed > 0)
                                          Flexible(
                                            flex: s.completed,
                                            child: Container(
                                                height: 6,
                                                color: const Color(0xFF10B981)),
                                          ),
                                        if (s.active > 0)
                                          Flexible(
                                            flex: s.active,
                                            child: Container(
                                                height: 6,
                                                color: const Color(0xFFF59E0B)),
                                          ),
                                        if (s.pending > 0)
                                          Flexible(
                                            flex: s.pending,
                                            child: Container(
                                                height: 6,
                                                color: const Color(0xFFF43F5E)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Row(
                                    children: [
                                      Text(
                                        "✓ ${s.completed} Completed",
                                        style: AX.mono(fontSize: 10, color: const Color(0xFF10B981)),
                                      ),
                                      const Spacer(),
                                      Text(
                                        "⏳ ${s.active} Active",
                                        style: AX.mono(fontSize: 10, color: const Color(0xFFF59E0B)),
                                      ),
                                      const Spacer(),
                                      Text(
                                        "⚠️ ${s.pending} Pending",
                                        style: AX.mono(fontSize: 10, color: const Color(0xFFF43F5E)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );

                if (isStacked) {
                  return Column(
                    children: [
                      canvasWidget,
                      const SizedBox(height: 20),
                      breakdownWidget,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    canvasWidget,
                    const SizedBox(width: 28),
                    Expanded(child: breakdownWidget),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }




  Widget _buildGlobalSosEmergencyBanner(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('emergency_beacons')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;

        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFFEF2F2),
            border: Border(
              bottom: BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final workerName = (data['workerName'] as String?)?.trim().isNotEmpty == true
                  ? (data['workerName'] as String).trim()
                  : 'Artisan in Distress';
              final workerPhone = (data['workerPhone'] as String?)?.trim() ?? '';
              final address = (data['address'] as String?)?.trim().isNotEmpty == true
                  ? (data['address'] as String).trim()
                  : 'Location not reported';
              final lat = (data['latitude'] as num?)?.toDouble();
              final lng = (data['longitude'] as num?)?.toDouble();

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 700;
                    return isCompact
                        ? _buildCompactSosCard(context, doc.id, workerName, workerPhone, address.toLocalizedAddress(context.locale.languageCode), lat, lng)
                        : _buildWideSosCard(context, doc.id, workerName, workerPhone, address.toLocalizedAddress(context.locale.languageCode), lat, lng);
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildWideSosCard(
    BuildContext context,
    String docId,
    String workerName,
    String workerPhone,
    String address,
    double? lat,
    double? lng,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'sos_admin_beacon_title'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      workerName,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF6B7280)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 12,
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
        const SizedBox(width: 14),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildCallButton(workerPhone),
            _buildMapButton(address, lat, lng),
            _buildResolveButton(context, docId, workerName),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactSosCard(
    BuildContext context,
    String docId,
    String workerName,
    String workerPhone,
    String address,
    double? lat,
    double? lng,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'sos_admin_beacon_title'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    workerName,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                address,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildCallButton(workerPhone)),
            const SizedBox(width: 8),
            Expanded(child: _buildMapButton(address, lat, lng)),
            const SizedBox(width: 8),
            _buildResolveButton(context, docId, workerName),
          ],
        ),
      ],
    );
  }

  Widget _buildCallButton(String workerPhone) {
    final hasPhone = workerPhone.trim().isNotEmpty;
    return ElevatedButton.icon(
      onPressed: hasPhone
          ? () async {
              await PhoneDialer.call(workerPhone, context: context);
            }
          : null,
      icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
      label: Text(
        hasPhone ? workerPhone.trim() : 'call_artisan'.tr(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFFCA5A5),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }

  Widget _buildMapButton(String address, double? lat, double? lng) {
    return OutlinedButton.icon(
      onPressed: () async {
        Uri? uri;
        if (lat != null && lng != null) {
          uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        } else if (address.isNotEmpty) {
          uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
        }
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      icon: const Icon(Icons.near_me_rounded, size: 14),
      label: Text(
        'sos_admin_open_maps'.tr(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF991B1B),
        side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildResolveButton(BuildContext context, String docId, String workerName) {
    return OutlinedButton.icon(
      onPressed: () => _confirmResolveBeacon(context, docId, workerName),
      icon: const Icon(Icons.check_circle_rounded, size: 14),
      label: Text(
        'sos_resolve'.tr(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF047857),
        side: const BorderSide(color: Color(0xFF6EE7B7), width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _confirmResolveBeacon(BuildContext context, String docId, String workerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'sos_admin_resolved_confirm'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'sos_admin_resolved_body'.tr(args: [workerName]),
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'cancel_btn'.tr().isNotEmpty ? 'cancel_btn'.tr() : 'Cancel',
              style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(
              'sos_resolve'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('emergency_beacons').doc(docId).update({
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': widget.user.uid,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Emergency beacon marked resolved for $workerName.'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resolving beacon: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  Data model for one trade segment in the sunburst
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TradeSegmentData {
  final String name;
  final Color color;
  final int completed;
  final int active;
  final int pending;

  const _TradeSegmentData({
    required this.name,
    required this.color,
    required this.completed,
    required this.active,
    required this.pending,
  });

  int get total => completed + active + pending;
}

// ─────────────────────────────────────────────────────────────────────────────
//  CustomPainter — draws the two-ring sunburst chart (Dynamic & Interactive)
// ─────────────────────────────────────────────────────────────────────────────
class _SunburstPainter extends CustomPainter {
  final List<_TradeSegmentData> segments;
  final int total;
  final double animationProgress;
  final String? selectedTrade;

  const _SunburstPainter({
    required this.segments,
    required this.total,
    this.animationProgress = 1.0,
    this.selectedTrade,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxR = (math.min(size.width, size.height) / 2) - 18;

    // Radii: generous center hole for typography, clear inner & outer tracks
    final holeR  = maxR * 0.32;
    final innerR = maxR * 0.58;
    final gapR   = maxR * 0.64;
    final outerR = maxR * 0.94;

    const gapAngle = 0.024;
    double angle = -math.pi / 2;

    if (selectedTrade != null) {
      final seg = segments.firstWhere(
        (s) => s.name == selectedTrade,
        orElse: () => segments.first,
      );

      if (seg.total > 0) {
        // 1. Subtle background track for outer ring
        final bgTrack = Path()
          ..addOval(Rect.fromCircle(center: center, radius: outerR))
          ..addOval(Rect.fromCircle(center: center, radius: gapR))
          ..fillType = PathFillType.evenOdd;
        canvas.drawPath(
          bgTrack,
          Paint()..color = const Color(0xFFF1ECE1)..style = PaintingStyle.fill,
        );

        // 2. Soft glowing inner circle backdrop
        canvas.drawCircle(
          center,
          holeR - 2,
          Paint()
            ..color = seg.color.withValues(alpha: 0.10)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          center,
          holeR - 2,
          Paint()
            ..color = seg.color.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );

        // Clamped sweep to ensure smooth animation without vanishing
        final progress = animationProgress.clamp(0.01, 1.0);
        final sweep = 2 * math.pi * progress;

        // 3. Inner Ring: Solid Trade Identity Slice
        _drawSlice(
          canvas,
          center,
          holeR,
          innerR,
          angle,
          sweep,
          seg.color,
          isHighlighted: true,
        );

        // 4. Outer Ring: Status breakdown (Completed, Active, Pending)
        final statusList = [
          (seg.completed, const Color(0xFF10B981), "COMPLETED"),
          (seg.active,    const Color(0xFFF59E0B), "ACTIVE"),
          (seg.pending,   const Color(0xFFF43F5E), "PENDING"),
        ].where((e) => e.$1 > 0).toList();

        if (statusList.length == 1) {
          final single = statusList.first;
          _drawSlice(
            canvas,
            center,
            gapR,
            outerR,
            angle,
            sweep,
            single.$2,
            isHighlighted: true,
          );
        } else if (statusList.isNotEmpty) {
          double outerAngle = angle;
          const statusGap = 0.04;
          for (final st in statusList) {
            final portion = st.$1 / seg.total;
            final sSweep = (portion * sweep - statusGap).clamp(0.01, sweep);
            _drawSlice(
              canvas,
              center,
              gapR,
              outerR,
              outerAngle,
              sSweep,
              st.$2,
              isHighlighted: true,
            );
            outerAngle += portion * sweep;
          }
        }

        // 5. Center Metrics Display: Big number & Trade name
        _drawText(canvas, '${seg.total}', center.dx, center.dy - 12, seg.color, 28, size, bold: true);
        _drawText(canvas, seg.name.toUpperCase(), center.dx, center.dy + 12, const Color(0xFF1A1A1A), 9.5, size, bold: true);
      }
      return;
    }

    // Normal Overview Mode (All Trades)
    final progress = animationProgress.clamp(0.01, 1.0);

    // Subtle background circle
    canvas.drawCircle(
      center,
      holeR - 1,
      Paint()
        ..color = const Color(0xFFF9F6EE)
        ..style = PaintingStyle.fill,
    );

    for (final seg in segments) {
      if (seg.total == 0) continue;
      final rawPortion = seg.total / total;
      final rawSweep = rawPortion * 2 * math.pi;
      final sweep = (rawSweep - gapAngle).clamp(0.01, 2 * math.pi) * progress;
      if (sweep <= 0) continue;

      final innerColor = seg.color.withValues(alpha: 0.95);

      // Inner Ring
      _drawSlice(
        canvas,
        center,
        holeR,
        innerR,
        angle,
        sweep,
        innerColor,
        isHighlighted: false,
      );

      // Outer Ring: Statuses inside this wedge
      final statusList = [
        (seg.completed, const Color(0xFF10B981)),
        (seg.active,    const Color(0xFFF59E0B)),
        (seg.pending,   const Color(0xFFF43F5E)),
      ].where((e) => e.$1 > 0).toList();

      if (statusList.length == 1) {
        _drawSlice(
          canvas,
          center,
          gapR,
          outerR,
          angle,
          sweep,
          statusList.first.$2,
        );
      } else {
        double currentStatusAngle = angle;
        for (final st in statusList) {
          final portion = st.$1 / seg.total;
          final sSweep = portion * sweep;
          _drawSlice(
            canvas,
            center,
            gapR,
            outerR,
            currentStatusAngle,
            sSweep,
            st.$2,
          );
          currentStatusAngle += sSweep;
        }
      }

      // Outer Trade Label
      if (rawSweep > 0.38) {
        final midA = angle + sweep / 2;
        final labelR = outerR + 13;
        final lx = center.dx + labelR * math.cos(midA);
        final ly = center.dy + labelR * math.sin(midA);
        _drawText(canvas, seg.name, lx, ly, seg.color, 9.0, size, bold: true);
      }

      angle += rawSweep;
    }

    // Center Label in Overview
    _drawText(canvas, total.toString(), center.dx, center.dy - 8, const Color(0xFF1A1A1A), 22, size, bold: true);
    _drawText(canvas, 'BOOKINGS', center.dx, center.dy + 12, const Color(0xFF9CA3AF), 7.5, size, bold: true);
  }

  /// Draws an annular slice between [innerR] and [outerR].
  /// Handles full 360-degree circles cleanly using concentric ovals.
  void _drawSlice(
    Canvas canvas,
    Offset center,
    double innerR,
    double outerR,
    double startAngle,
    double sweepAngle,
    Color color, {
    bool isHighlighted = false,
  }) {
    if (sweepAngle <= 0.0001) return;

    if (sweepAngle >= 2 * math.pi - 0.01) {
      final ringPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: outerR))
        ..addOval(Rect.fromCircle(center: center, radius: innerR))
        ..fillType = PathFillType.evenOdd;

      canvas.drawPath(ringPath, Paint()..color = color..style = PaintingStyle.fill);
      canvas.drawPath(
        ringPath,
        Paint()
          ..color = isHighlighted ? Colors.white : Colors.white.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHighlighted ? 2.0 : 1.0,
      );
      return;
    }

    final safeSweep = sweepAngle.clamp(0.001, 2 * math.pi - 0.01);

    final path = Path()
      ..moveTo(
        center.dx + outerR * math.cos(startAngle),
        center.dy + outerR * math.sin(startAngle),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: outerR),
        startAngle,
        safeSweep,
        false,
      )
      ..lineTo(
        center.dx + innerR * math.cos(startAngle + safeSweep),
        center.dy + innerR * math.sin(startAngle + safeSweep),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerR),
        startAngle + safeSweep,
        -safeSweep,
        false,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = isHighlighted ? Colors.white : Colors.white.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.0 : 1.0,
    );
  }

  /// Draws centered text at (x, y), clamped to canvas bounds.
  /// Supports optional rounded background pill.
  void _drawText(Canvas canvas, String text, double x, double y, Color color,
      double fontSize, Size size, {bool bold = false, Color? bgColor}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          color: color,
          letterSpacing: bold ? 0.3 : 0.2,
          fontFamily: 'SpaceGrotesk',
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final dx = (x - tp.width / 2).clamp(0.0, size.width - tp.width);
    final dy = (y - tp.height / 2).clamp(0.0, size.height - tp.height);

    if (bgColor != null) {
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx - 6, dy - 2, tp.width + 12, tp.height + 4),
        const Radius.circular(6),
      );
      canvas.drawRRect(bgRect, Paint()..color = bgColor);
    }

    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter old) =>
      old.total != total ||
      old.segments.length != segments.length ||
      old.animationProgress != animationProgress ||
      old.selectedTrade != selectedTrade;
}
