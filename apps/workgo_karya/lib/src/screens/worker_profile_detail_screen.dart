import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';
import 'document_upload_screen.dart';
import 'karya_home_screen.dart';
import 'worker_profile_setup_screen.dart';
import 'worker_welfare_screen.dart';
import 'daily_face_verification_screen.dart';
import '../widgets/artisan_keyword_uplift_widget.dart';

class WorkerProfileDetailScreen extends StatefulWidget {
  const WorkerProfileDetailScreen({
    super.key,
    required this.user,
    required this.worker,
    required this.onSignOut,
    this.profileHubKey,
    this.profileKycKey,
  });

  final AppUser user;
  final Worker worker;
  final VoidCallback onSignOut;
  final GlobalKey? profileHubKey;
  final GlobalKey? profileKycKey;

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
                'profile_photo_updated'.tr(),
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
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      }
      widget.onSignOut();
    }
  }

  void _handleDeleteAccount() async {
    final confirmed = await showDeleteAccountConfirmationSheet(context);
    if (confirmed == true) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFE11D48)),
          ),
        );
      }

      try {
        final authService = AuthService();
        await authService.deleteAccount(uid: widget.worker.id);
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (mounted) {
          Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'dpdp_account_deleted'.tr(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F0B24),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('error_during_erasure_arg'.tr(args: [e.toString()])),
              backgroundColor: const Color(0xFFE11D48),
            ),
          );
        }
      }
    }
  }

  void _showReferPeerDialog() {
    HapticFeedback.lightImpact();
    showPeerReferralNetworkSheet(context, worker: widget.worker);
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

        return Scaffold(
          backgroundColor: KX.canvas,
          appBar: AppBar(
            backgroundColor: KX.canvas,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF0EDE6)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: KX.textPrimary),
              ),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
            centerTitle: true,
            title: Text(
              'profile'.trSafe("Profile"),
              style: WorkGoFonts.heading(
                color: KX.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF0EDE6)),
                  ),
                  child: const Icon(Icons.settings_outlined, size: 18, color: KX.textPrimary),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => WorkerProfileSetupScreen(
                      worker: worker,
                      onProfileUpdated: () => setState(() {}),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Artisan Profile Card (Avatar, Name, Subtitle, Actions)
                  _buildArtisanHero(name, worker, isOnline),
                  const SizedBox(height: 18),

                  // 3 Metric Bento Chips (Mint Green, Sky Blue, Pastel Amber)
                  _buildMetricStatsRow(worker),
                  const SizedBox(height: 18),

                  // AI Match Strength & Equipment Specializations Card (Exclusive to Profile when match score >= 85%)
                  if (ArtisanKeywordUpliftWidget.calculateMatchStrength(worker) >= 0.85) ...[
                    _buildAiMatchStrengthProfileCard(worker),
                    const SizedBox(height: 18),
                  ],

                  // Menu Matrix List Cards
                  _buildMenuMatrix(worker),
                  const SizedBox(height: 24),

                  // Titan Dispatch Bar
                  _buildTitanControlCard(worker),
                  const SizedBox(height: 24),

                  // Secure Sign Out CTA
                  OutlinedButton.icon(
                    onPressed: _handleSignOut,
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFF43F5E), size: 18),
                    label: Text(
                      "sign_out".trSafe("Sign Out"),
                      style: WorkGoFonts.heading(
                        color: const Color(0xFFF43F5E),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      side: const BorderSide(color: Color(0xFFFECDD3), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: const Color(0xFFFFF1F2),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Delete Account Action
                  TextButton.icon(
                    onPressed: _handleDeleteAccount,
                    icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFF9CA3AF), size: 16),
                    label: Text(
                      'dpdp_delete_account'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
    return StreamBuilder<AppUser?>(
      stream: _authService.streamAppUser(widget.user.uid),
      initialData: widget.user,
      builder: (context, snap) {
        final liveUser = snap.data ?? widget.user;
        final avatar = liveUser.avatarBase64;
        final baseStation = worker.baseAddress?.formattedAddress ??
            worker.baseArea ??
            (worker.preferredAreas.isNotEmpty ? worker.preferredAreas.first : 'base_station_unset'.tr());

        return Column(
          children: [
            // Center Avatar
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E0D8), width: 2),
                  ),
                  child: WorkGoAvatar(
                    avatarBase64: avatar,
                    name: name,
                    radius: 46,
                    onEditTap: _handleAvatarUpload,
                  ),
                ),
                GestureDetector(
                  onTap: _handleAvatarUpload,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF141416),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Name
            Text(
              name,
              style: WorkGoFonts.display(
                color: KX.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // Location
            Text(
              baseStation,
              style: WorkGoFonts.body(
                color: KX.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Contact Mobile Phone Row
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => WorkerProfileSetupScreen(
                    worker: worker,
                    onProfileUpdated: () => setState(() {}),
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.phone_android_rounded,
                      size: 13,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        (worker.phoneForCalling?.isNotEmpty == true)
                            ? worker.phoneForCalling!
                            : (widget.user.phoneNumber?.isNotEmpty == true
                                ? widget.user.phoneNumber!
                                : 'add_phone_number'.tr()),
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.edit_outlined,
                      size: 12,
                      color: Color(0xFFB45309),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2 Circular Action Buttons (Edit Profile & Share Referral)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCircularAction(
                  icon: Icons.edit_rounded,
                  label: 'btn_edit'.tr(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => WorkerProfileSetupScreen(
                        worker: worker,
                        onProfileUpdated: () => setState(() {}),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                _buildCircularAction(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'btn_refer'.tr(),
                  onTap: _showReferPeerDialog,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCircularAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: KX.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: WorkGoFonts.heading(
                color: KX.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricStatsRow(Worker worker) {
    return StreamBuilder<List<Booking>>(
      stream: _bookingService.streamWorkerActiveJobs(worker.id),
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? [];
        final completedJobs = jobs.where((b) => b.status == BookingStatus.completed).toList();
        final totalJobsCount = completedJobs.isNotEmpty ? completedJobs.length : worker.homesServiced;
        final expYears = worker.experienceYears > 0 ? "${worker.experienceYears} Yrs" : 'badge_new'.tr();
        final ratingVal = worker.avgRating > 0 ? "${worker.avgRating.toStringAsFixed(1)} ★" : "5.0 ★";

        return Row(
          children: [
            // Mint Green Card (Experience)
            Expanded(
              child: _buildBentoStatCard(
                title: 'experience_label'.tr(),
                value: expYears,
                bgColor: const Color(0xFFD1FAE5),
                textColor: const Color(0xFF065F46),
              ),
            ),
            const SizedBox(width: 8),

            // Sky Blue Card (Jobs Done)
            Expanded(
              child: _buildBentoStatCard(
                title: 'jobs_done_label'.tr(),
                value: "$totalJobsCount ${'done_label'.tr()}",
                bgColor: const Color(0xFFD6EBFF),
                textColor: const Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(width: 8),

            // Pastel Amber Card (Rating)
            Expanded(
              child: _buildBentoStatCard(
                title: 'coop_rating_label'.tr(),
                value: ratingVal,
                bgColor: const Color(0xFFFFDE9C),
                textColor: const Color(0xFF92400E),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBentoStatCard({
    required String title,
    required String value,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAiMatchStrengthProfileCard(Worker worker) {
    final matchScore = ArtisanKeywordUpliftWidget.calculateMatchStrength(worker);
    final matchPercent = (matchScore * 100).round();
    final tags = worker.equipmentTags;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A10B981),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFD1FAE5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Color(0xFF065F46),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'ai_match_strength'.tr(),
                            style: WorkGoFonts.heading(
                              color: KX.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'percent_elite_arg'.tr(args: [matchPercent.toString()]),
                            style: const TextStyle(
                              color: Color(0xFF065F46),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'priority_symptom_triage'.tr(),
                      style: WorkGoFonts.body(
                        color: KX.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => ArtisanKeywordUpliftWidget.showOffcanvas(
                  context: context,
                  worker: worker,
                  onKeywordsUpdated: () => setState(() {}),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 13, color: KX.gold),
                      const SizedBox(width: 4),
                      Text(
                        'btn_manage'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...tags.take(3).map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          tag,
                          style: WorkGoFonts.body(
                            color: KX.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (tags.length > 3)
                  GestureDetector(
                    onTap: () => ArtisanKeywordUpliftWidget.showOffcanvas(
                      context: context,
                      worker: worker,
                      onKeywordsUpdated: () => setState(() {}),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Text(
                        'plus_more_count'.tr(args: ['${tags.length - 3}']),
                        style: WorkGoFonts.body(
                          color: const Color(0xFF7E22CE),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _buildMenuMatrix(Worker worker) {
    final area = worker.preferredAreas.isNotEmpty ? worker.preferredAreas.first : (worker.baseArea ?? "Erode Central");
    final skillsStr = worker.skills.isNotEmpty ? worker.skills.take(2).map((s) => s.toLocalizedTrade()).join(', ') : 'general_trades'.trSafe("General Trades");
    final isKycApproved = worker.verificationStatus == VerificationStatus.approved;
    final matchScore = ArtisanKeywordUpliftWidget.calculateMatchStrength(worker);
    final matchPercent = (matchScore * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.location_on_rounded,
            title: 'operating_base_station'.tr(),
            subtitle: "$area · ${'active_range_km'.tr(args: [worker.serviceRadiusKm.toInt().toString()])}",
            onTap: () => showAddressManagementSheet(
              context,
              userId: worker.id,
              userRole: "worker",
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EDE6), indent: 56),
          _buildMenuItem(
            icon: Icons.construction_rounded,
            title: 'trade_skills_rates'.tr(),
            subtitle: "$skillsStr · ₹${worker.baseRate.toInt()} ${'base_fare'.trSafe('Base')}",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => WorkerProfileSetupScreen(
                  worker: worker,
                  onProfileUpdated: () => setState(() {}),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EDE6), indent: 56),
          _buildMenuItem(
            icon: Icons.psychology_rounded,
            title: 'equipment_specializations'.tr(),
            subtitle: matchPercent >= 85
                ? 'equipment_strength_elite'.tr(args: ['$matchPercent'])
                : 'equipment_strength_add'.tr(args: ['$matchPercent']),
            badgeColor: matchPercent >= 85 ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
            badgeTextColor: matchPercent >= 85 ? const Color(0xFF065F46) : const Color(0xFF92400E),
            badgeText: matchPercent >= 85 ? "$matchPercent% ELITE" : "$matchPercent%",
            onTap: () => ArtisanKeywordUpliftWidget.showOffcanvas(
              context: context,
              worker: worker,
              onKeywordsUpdated: () => setState(() {}),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EDE6), indent: 56),
          _buildMenuItem(
            icon: Icons.verified_user_rounded,
            title: 'ekyc_certification'.tr(),
            subtitle: isKycApproved ? 'coop_verified'.tr() : 'verification_pending'.tr(),
            badgeColor: isKycApproved ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
            badgeTextColor: isKycApproved ? const Color(0xFF065F46) : const Color(0xFF92400E),
            badgeText: isKycApproved ? 'verified_caps'.tr() : 'pending_caps'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => DocumentUploadScreen(
                  workerId: worker.id,
                  initialVerificationStatus: worker.verificationStatus,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EDE6), indent: 56),
          _buildMenuItem(
            icon: Icons.health_and_safety_rounded,
            title: 'welfare_shield_title'.tr(),
            subtitle: worker.insuranceStatus ? 'pmsby_pmjjby_active'.tr() : 'coop_welfare_cover'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => WorkerWelfareScreen(worker: worker)),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EDE6), indent: 56),
          _buildMenuItem(
            icon: Icons.groups_rounded,
            title: 'peer_referral_network'.tr(),
            subtitle: 'referral_bonus_subtitle'.tr(args: ['${worker.referralCount}']),
            onTap: _showReferPeerDialog,
          ),
          const Divider(height: 1, color: Color(0xFFF0EDE6), indent: 56),
          _buildMenuItem(
            icon: Icons.explore_rounded,
            title: 'app_tour_title'.tr(),
            subtitle: 'app_tour_subtitle'.tr(),
            onTap: () {
              HapticFeedback.lightImpact();
              KaryaHomeScreen.launchLiveSpotlightTour(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
    Color? badgeTextColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF141416), size: 18),
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
                          title,
                          style: WorkGoFonts.heading(
                            color: KX.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor ?? const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeTextColor ?? const Color(0xFF065F46),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: WorkGoFonts.body(
                      color: KX.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF9CA3AF), size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTitanControlCard(Worker worker) {
    final isCheckedIn = worker.isTitan;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCheckedIn ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCheckedIn ? 'titan_dispatch_active'.tr() : 'titan_standby'.tr(),
                        style: WorkGoFonts.heading(
                          color: KX.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isCheckedIn ? 'receiving_broadcasts'.tr() : 'offline_tap_live'.tr(),
                        style: WorkGoFonts.body(
                          color: KX.textSecondary,
                          fontSize: 11,
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
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => _toggleTitanCheckIn(worker),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCheckedIn ? const Color(0xFFF43F5E) : const Color(0xFF141416),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              isCheckedIn ? 'btn_check_out'.tr() : 'btn_go_live'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTitanCheckIn(Worker worker) async {
    final isCurrentlyCheckedIn = worker.isTitan;

    if (!isCurrentlyCheckedIn) {
      if (worker.verificationStatus != VerificationStatus.approved) {
        HapticFeedback.heavyImpact();
        _showVerificationRequiredModal(context, worker);
        return;
      }

      // 1. Native Biometric Fingerprint/Face ID verification prompt
      final authenticated = await BiometricService().authenticate(
        reason: 'biometric_reason'.tr(),
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('biometric_cancelled'.tr())),
                ],
              ),
              backgroundColor: const Color(0xFFE11D48),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
        return;
      }

      // 2. Mandatory Daily 3D Face Verification against registered KYC selfie
      if (mounted) {
        final faceVerified = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => DailyFaceVerificationScreen(worker: worker),
          ),
        );

        if (faceVerified != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.face_retouching_off_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('face_verification_cancelled'.tr())),
                  ],
                ),
                backgroundColor: const Color(0xFFE11D48),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            );
          }
          return;
        }
      }
    }

    if (isCurrentlyCheckedIn) {
      if (!mounted) return;
      final confirmedCheckOut = await showCheckOutMotivationSheet(
        context,
        worker: worker,
      );

      if (confirmedCheckOut != true) {
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

  void _showVerificationRequiredModal(BuildContext context, Worker worker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFF0EDE6), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 28,
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
                    color: const Color(0xFFE5E0D8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFB800), width: 1.5),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Color(0xFFB45309), size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'identity_verification_required'.tr(),
                textAlign: TextAlign.center,
                style: WorkGoFonts.display(
                  color: KX.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ekyc_modal_desc'.tr(),
                textAlign: TextAlign.center,
                style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (c) => DocumentUploadScreen(workerId: worker.id),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: const Color(0xFF1E1035),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('complete_verification_now'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('ill_do_it_later'.tr(), style: const TextStyle(color: Color(0xFF9CA3AF))),
              ),
            ],
          ),
        );
      },
    );
  }
}

