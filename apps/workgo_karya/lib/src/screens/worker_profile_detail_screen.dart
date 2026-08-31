import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';
import 'document_upload_screen.dart';
import 'worker_profile_setup_screen.dart';
import 'worker_welfare_screen.dart';

class WorkerProfileDetailScreen extends StatefulWidget {
  const WorkerProfileDetailScreen({
    super.key,
    required this.user,
    required this.worker,
    required this.onSignOut,
  });

  final AppUser user;
  final Worker worker;
  final VoidCallback onSignOut;

  @override
  State<WorkerProfileDetailScreen> createState() => _WorkerProfileDetailScreenState();
}

class _WorkerProfileDetailScreenState extends State<WorkerProfileDetailScreen> {
  final _workerService = WorkerService();
  final _bookingService = BookingService();
  final _authService = AuthService();

  Future<void> _handleAvatarUpload() async {
    final result = await ImageUploadService.instance.showAvatarPickerBottomSheet(
      context,
      uid: widget.user.uid,
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                "Profile photo updated successfully!",
                style: WorkGoFonts.body(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  void _handleSignOut() async {
    final confirmed = await showSignOutConfirmationSheet(context);
    if (confirmed == true) {
      widget.onSignOut();
    }
  }

  void _showReferPeerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedTrade = widget.worker.skills.isNotEmpty ? widget.worker.skills.first : "Plumbing";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF130E2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFA855F7), width: 1.2),
        ),
        title: Text(
          "Refer a Fellow Artisan",
          style: WorkGoFonts.heading(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add a peer into your cooperative second-line dispatch network.",
              style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Peer's Full Name",
                labelStyle: const TextStyle(color: KX.textSecondary),
                filled: true,
                fillColor: const Color(0xFF1C1536),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Phone Number",
                labelStyle: const TextStyle(color: KX.textSecondary),
                filled: true,
                fillColor: const Color(0xFF1C1536),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("Cancel", style: TextStyle(color: KX.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                await _workerService.referProxyWorker(
                  name: nameCtrl.text.trim(),
                  phoneForCalling: phoneCtrl.text.trim(),
                  primarySkill: selectedTrade,
                  experienceYears: 2,
                  referrerId: widget.worker.id,
                  referrerRole: "worker",
                );
                // Increment worker's referral stats
                final updated = widget.worker.copyWith(
                  referralCount: widget.worker.referralCount + 1,
                  referralEarnings: widget.worker.referralEarnings + 100.0,
                );
                await _workerService.upsertWorkerProfile(updated);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Peer artisan registered in your second-line network!"),
                      backgroundColor: KX.emerald,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KX.violetNeon,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Add to Network"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.displayName.isNotEmpty ? widget.user.displayName : "Artisan Partner";

    return StreamBuilder<Worker?>(
      stream: _workerService.streamWorker(widget.worker.id),
      initialData: widget.worker,
      builder: (context, snapshot) {
        final worker = snapshot.data ?? widget.worker;
        final isOnline = worker.availabilityStatus == AvailabilityStatus.online;

        return KaryaScaffold(
          appBar: KaryaAppBar(
            title: "profile_matrix_title".trSafe("Artisan Profile & Matrix"),
            subtitle: "profile_matrix_subtitle".trSafe("Schedule, work hours, coverage and referral network"),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Artisan Avatar & Live Shift Card
                  _buildArtisanHero(name, worker, isOnline),
                  const SizedBox(height: 16),

                  // Metric Stats Bar (Hours Worked, Jobs, Rating, Referrals)
                  _buildMetricStatsRow(worker),
                  const SizedBox(height: 16),

                  // Working Hours & Shift Management
                  _buildWorkingHoursCard(worker),
                  const SizedBox(height: 16),

                  // Operating Base & Multi-Hub Locations
                  _buildOperatingBasesCard(worker),
                  const SizedBox(height: 16),

                  // Coverage Area & Trade Skills
                  _buildCoverageAndTradesCard(worker),
                  const SizedBox(height: 16),

                  // Referral Network & Second-Line Dispatch
                  _buildReferralNetworkCard(worker),
                  const SizedBox(height: 16),

                  // KYC & Welfare Links
                  _buildQuickNavigationLinks(worker),
                  const SizedBox(height: 24),

                  // Secure Sign Out CTA (With confirmation bottom sheet)
                  OutlinedButton.icon(
                    onPressed: _handleSignOut,
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFF43F5E), size: 20),
                    label: Text(
                      "sign_out".trSafe("Sign Out"),
                      style: WorkGoFonts.heading(
                        color: const Color(0xFFF43F5E),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      side: BorderSide(color: const Color(0xFFF43F5E).withValues(alpha: 0.5), width: 1.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: const Color(0xFFF43F5E).withValues(alpha: 0.06),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtisanHero(String name, Worker worker, bool isOnline) {
    final isTitan = worker.isTitan;
    final isPassion = worker.engagementMode == "passion" || worker.engagementMode == "hobby";

    return StreamBuilder<AppUser?>(
      stream: _authService.streamAppUser(widget.user.uid),
      initialData: widget.user,
      builder: (context, snap) {
        final liveUser = snap.data ?? widget.user;
        final avatar = liveUser.avatarBase64;

        return KaryaCard(
          gradient: KX.auroraVioletNeon,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              WorkGoAvatar(
                avatarBase64: avatar,
                name: name,
                radius: 30,
                onEditTap: _handleAvatarUpload,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: WorkGoFonts.display(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isTitan) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KX.gold,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "titan_badge".trSafe("⚡ TITAN"),
                              style: const TextStyle(
                                color: Color(0xFF1E1035),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      liveUser.email,
                      style: WorkGoFonts.body(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isTitan ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isTitan
                            ? (isPassion ? "live_passion_titan".trSafe("⚡ LIVE PASSION TITAN") : "live_on_dispatch".trSafe("⚡ LIVE ON DISPATCH"))
                            : "offline_ready_checkin".trSafe("OFFLINE · READY TO CHECK IN"),
                        style: WorkGoFonts.badge(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricStatsRow(Worker worker) {
    return StreamBuilder<List<Booking>>(
      stream: _bookingService.streamWorkerActiveJobs(worker.id),
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? [];
        final completedJobs = jobs.where((b) => b.status == BookingStatus.completed).toList();
        final actualHours = worker.totalHoursWorked > 0
            ? worker.totalHoursWorked
            : (completedJobs.length * 2.0);
        final totalJobsCount = completedJobs.isNotEmpty ? completedJobs.length : worker.totalRatings;

        return Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: "hours_worked".trSafe("Hours Worked"),
                value: "${actualHours.toStringAsFixed(1)}h",
                icon: Icons.timer_rounded,
                color: KX.gold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: "completed_jobs_stat".trSafe("Completed Jobs"),
                value: "$totalJobsCount",
                icon: Icons.check_circle_rounded,
                color: KX.emerald,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: "rating_stat".trSafe("Rating"),
                value: worker.totalRatings > 0 ? "${worker.avgRating.toStringAsFixed(1)} ★" : "5.0 ★",
                icon: Icons.star_rounded,
                color: KX.amber,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return KaryaCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: WorkGoFonts.numeric(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: WorkGoFonts.body(
              color: KX.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursCard(Worker worker) {
    final isPassion = worker.engagementMode == "passion" || worker.engagementMode == "hobby";
    final isCheckedIn = worker.isTitan;

    return KaryaCard(
      borderColor: isCheckedIn ? KX.gold.withValues(alpha: 0.6) : null,
      glowColor: isCheckedIn ? KX.gold : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on_rounded, color: KX.gold, size: 22),
              const SizedBox(width: 8),
              Text(
                "titan_hub_title".trSafe("Titan & Work Engagement Hub"),
                style: WorkGoFonts.heading(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showEngagementModeDialog(worker),
                child: Text("engagement_mode_btn".trSafe("Mode"), style: const TextStyle(color: KX.gold, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Live Titan Check-In / Check-Out Action Bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isCheckedIn ? KX.luminaVioletGold : null,
              color: isCheckedIn ? null : KX.canvasElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCheckedIn ? KX.gold : Colors.white.withValues(alpha: 0.1),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        KPulsingDot(
                          color: isCheckedIn ? const Color(0xFF10B981) : KX.textMuted,
                          size: 9,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCheckedIn ? "titan_checked_in".trSafe("TITAN CHECKED IN") : "titan_offline".trSafe("TITAN OFFLINE"),
                          style: WorkGoFonts.heading(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _toggleTitanCheckIn(worker),
                      icon: Icon(
                        isCheckedIn ? Icons.power_settings_new_rounded : Icons.flash_on_rounded,
                        size: 16,
                        color: isCheckedIn ? Colors.white : const Color(0xFF1E1035),
                      ),
                      label: Text(
                        isCheckedIn ? "check_out_btn".trSafe("Check Out") : "check_in_btn".trSafe("Check In"),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isCheckedIn ? Colors.white : const Color(0xFF1E1035),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCheckedIn ? const Color(0xFFE11D48) : KX.gold,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isCheckedIn
                      ? "titan_live_radar_desc".trSafe("⚡ Live on customer radar! Receiving broadcast dispatches for your registered trades.")
                      : "titan_offline_desc".trSafe("🌙 Checked out. Tap 'Check In' to go live and receive job requests instantly."),
                  style: WorkGoFonts.body(
                    color: isCheckedIn ? Colors.white.withValues(alpha: 0.9) : KX.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Current Engagement Mode Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: KX.canvasElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  isPassion ? Icons.auto_awesome_rounded : Icons.schedule_rounded,
                  color: KX.violetNeon,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPassion ? "passion_hobby_mode_title".trSafe("Passion & Hobby Mode") : "scheduled_shift_title".trSafe("Scheduled Shift Window"),
                        style: WorkGoFonts.heading(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPassion
                            ? "passion_hobby_mode_desc".trSafe("Flexible on-demand check-in (no rigid hours quota)")
                            : "scheduled_shift_desc".trSafe("${worker.workingHoursStart} — ${worker.workingHoursEnd} (Configured shift)", [worker.workingHoursStart, worker.workingHoursEnd]),
                        style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => WorkerProfileSetupScreen(
                        worker: worker,
                        onProfileUpdated: () => setState(() {}),
                      ),
                    ),
                  ),
                  child: Text("edit_hours".trSafe("Edit Hours"), style: const TextStyle(color: KX.gold, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEngagementModeDialog(Worker worker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF130E2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "select_engagement_mode".trSafe("Select Engagement Style"),
              style: WorkGoFonts.display(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              "engagement_dialog_subtitle".trSafe("Choose how you prefer to participate in the cooperative network."),
              style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 18),
            _buildModeOption(
              ctx,
              title: "passion_dialog_title".trSafe("🌟 Passion & Hobby Artisan"),
              subtitle: "passion_dialog_desc".trSafe("Work whenever you feel like it. Check in with 1-tap when entering the app to go live as a Titan. Perfect for DIY crafters and part-time enthusiasts."),
              isSelected: worker.engagementMode == "passion" || worker.engagementMode == "hobby",
              onTap: () async {
                await _workerService.updateEngagementMode(worker.id, "passion");
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
            const SizedBox(height: 12),
            _buildModeOption(
              ctx,
              title: "scheduled_dialog_title".trSafe("⏱️ Scheduled Shift Artisan"),
              subtitle: "scheduled_dialog_desc".trSafe("Follow a fixed daily working window (${worker.workingHoursStart} — ${worker.workingHoursEnd}) for full-time dispatch routine."),
              isSelected: worker.engagementMode == "scheduled",
              onTap: () async {
                await _workerService.updateEngagementMode(worker.id, "scheduled");
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext ctx, {
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KX.canvasElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? KX.gold : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: WorkGoFonts.heading(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 11.5, height: 1.4)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: KX.gold, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTitanCheckIn(Worker worker) async {
    final isCurrentlyCheckedIn = worker.isTitan;

    if (isCurrentlyCheckedIn) {
      // Artisan is checking out! Slide up the Motivational Bottom Sheet!
      final confirmedCheckOut = await showCheckOutMotivationSheet(
        context,
        worker: worker,
      );

      if (confirmedCheckOut != true) {
        // Worker clicked "Keep Working & Earn More"!
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: KX.gold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "stay_online_toast".trSafe("Awesome! You're live on customer radar. Dispatches incoming! ⚡"),
                      style: WorkGoFonts.body(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E1035),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: KX.gold.withValues(alpha: 0.6), width: 1.2),
              ),
            ),
          );
        }
        return;
      }
    }

    HapticFeedback.mediumImpact();
    await _workerService.checkInTitan(worker.id, !isCurrentlyCheckedIn);
    await _workerService.updateAvailability(
      worker.id,
      !isCurrentlyCheckedIn ? AvailabilityStatus.online : AvailabilityStatus.offline,
    );
  }

  Widget _buildOperatingBasesCard(Worker worker) {
    return StreamBuilder<List<UserAddress>>(
      stream: LocationService().streamUserAddresses(worker.id, collection: "workers"),
      builder: (context, snapshot) {
        final addresses = snapshot.data ?? [];
        final defaultBase = addresses.isNotEmpty
            ? addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first)
            : worker.baseAddress;

        return KaryaCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pin_drop_rounded, color: KX.gold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "operating_bases_title".trSafe("Operating Bases & Hubs"),
                        style: WorkGoFonts.heading(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => showAddressManagementSheet(
                      context,
                      userId: worker.id,
                      userRole: "worker",
                      selectedAddress: defaultBase,
                    ),
                    icon: const Icon(Icons.settings_rounded, color: KX.gold, size: 14),
                    label: Text(
                      addresses.isNotEmpty ? "Manage (${addresses.length})" : "+ Add",
                      style: WorkGoFonts.heading(color: KX.gold, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (defaultBase != null)
                GestureDetector(
                  onTap: () => showAddressManagementSheet(
                    context,
                    userId: worker.id,
                    userRole: "worker",
                    selectedAddress: defaultBase,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: KX.canvasElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: KX.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(defaultBase.label.icon, color: KX.gold, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    defaultBase.displayTitle.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "PRIMARY BASE",
                                      style: TextStyle(color: Color(0xFF10B981), fontSize: 8, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                defaultBase.fullDisplayAddress,
                                style: const TextStyle(color: KX.textSecondary, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: KX.textSecondary, size: 12),
                      ],
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => showAddAddressSheet(context, userId: worker.id, userRole: "worker"),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KX.canvasElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_location_alt_rounded, color: KX.gold, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "No operating base set. Tap to detect GPS or set your workshop address.",
                            style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 12),
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
    );
  }

  Widget _buildCoverageAndTradesCard(Worker worker) {
    final area = worker.preferredAreas.isNotEmpty ? worker.preferredAreas.join(', ') : "active_coverage_zone".trSafe("Active Coverage Zone");

    return KaryaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: KX.violetNeon, size: 20),
              const SizedBox(width: 8),
              Text(
                "coverage_trades_title".trSafe("Coverage & Trade Skills"),
                style: WorkGoFonts.heading(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "primary_base_area".trSafe("Primary Base Area: $area (${worker.serviceRadiusKm.toInt()} km radius)", [area, worker.serviceRadiusKm.toInt().toString()]),
            style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: worker.skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: KX.canvasElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: KX.violetNeon.withValues(alpha: 0.4)),
                ),
                child: Text(
                  skill.toLocalizedTrade(),
                  style: WorkGoFonts.heading(
                    color: KX.gold,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralNetworkCard(Worker worker) {
    final referralCount = worker.referralCount;
    final earnings = worker.referralEarnings;

    return KaryaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: KX.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                "second_line_referral_title".trSafe("Second-Line Referral Network"),
                style: WorkGoFonts.heading(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "second_line_referral_desc".trSafe("If you are unavailable for a job, you can forward it to your referred peers and earn cooperative credits."),
            style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KX.canvasElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text("members_referred".trSafe("Referred Peers"), style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      "$referralCount",
                      style: WorkGoFonts.numeric(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.15)),
                Column(
                  children: [
                    Text("referral_earnings".trSafe("Network Bonus"), style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      "₹${earnings.toInt()}",
                      style: WorkGoFonts.numeric(color: KX.gold, fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WorkGoButton(
            label: "refer_peer_btn".trSafe("Refer Another Artisan"),
            icon: Icons.person_add_alt_1_rounded,
            onPressed: _showReferPeerDialog,
            height: 44,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNavigationLinks(Worker worker) {
    return Column(
      children: [
        _buildNavTile(
          title: "upload_kyc".tr(),
          subtitle: worker.verificationStatus == VerificationStatus.approved ? "KYC Approved & Active" : "Pending Review",
          icon: Icons.verified_user_rounded,
          iconColor: KX.emerald,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => DocumentUploadScreen(
                workerId: worker.id,
                initialVerificationStatus: worker.verificationStatus,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildNavTile(
          title: "welfare_status".tr(),
          subtitle: "Cooperative Insurance & Welfare Fund",
          icon: Icons.shield_rounded,
          iconColor: KX.gold,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => WorkerWelfareScreen(worker: worker)),
          ),
        ),
      ],
    );
  }

  Widget _buildNavTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: KaryaCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: WorkGoFonts.heading(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: KX.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }
}
