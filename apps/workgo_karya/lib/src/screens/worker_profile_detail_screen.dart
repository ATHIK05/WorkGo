import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Account and all biometric/KYC records permanently erased under DPDP Act 2023.",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
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
              content: Text("Error during erasure: $e"),
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

  void _showEditNameDialog(BuildContext context, Worker worker, String currentName) {
    final effectiveCurrent = (currentName.isNotEmpty &&
            currentName != "Artisan Partner" &&
            currentName != "Co-op Artisan")
        ? currentName
        : "";
    final controller = TextEditingController(text: effectiveCurrent);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              decoration: const BoxDecoration(
                color: KX.canvasCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: KX.gold.withAlpha(35),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.badge_outlined, color: Color(0xFFB45309), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Edit Display Name",
                                style: WorkGoFonts.heading(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: KX.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Visible to customers on quotes and dispatch cards",
                                style: WorkGoFonts.body(
                                  fontSize: 11.5,
                                  color: KX.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 40,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: KX.textPrimary,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return "Please enter your name";
                        }
                        if (val.trim().length < 2) {
                          return "Name must be at least 2 characters";
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        labelStyle: const TextStyle(color: KX.textSecondary, fontSize: 13),
                        hintText: "e.g. Ramesh Kumar",
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                        counterText: "",
                        filled: true,
                        fillColor: const Color(0xFFF9F6EE),
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF9CA3AF)),
                        suffixIcon: controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF9CA3AF)),
                                onPressed: () {
                                  controller.clear();
                                  setSheetState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: KX.gold, width: 2),
                        ),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving ? null : () => Navigator.of(sheetContext).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              "Cancel",
                              style: WorkGoFonts.heading(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: KX.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    setSheetState(() => isSaving = true);
                                    final newName = controller.text.trim();
                                    await _updateUserName(sheetContext, worker, newName);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: KaryaColors.brandYellow,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : Text(
                                    "Save Name",
                                    style: WorkGoFonts.heading(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                          ),
                        ),
                      ],
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

  Future<void> _updateUserName(BuildContext sheetContext, Worker worker, String newName) async {
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        await authUser.updateDisplayName(newName);
      }

      await FirebaseFirestore.instance.collection('users').doc(worker.userId).set({
        'displayName': newName,
        'name': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('workers').doc(worker.id).set({
        'name': newName,
        'displayName': newName,
        'artisanName': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Display name updated successfully!",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
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
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(
            content: Text("Failed to update name: $e"),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Worker?>(
      stream: _workerService.streamWorker(widget.worker.id),
      initialData: widget.worker,
      builder: (context, snapshot) {
        final worker = snapshot.data ?? widget.worker;
        final isOnline = worker.availabilityStatus == AvailabilityStatus.online;
        final name = (worker.name.isNotEmpty &&
                worker.name != "Co-op Artisan" &&
                worker.name != "Artisan Partner")
            ? worker.name
            : (widget.user.displayName.isNotEmpty
                ? widget.user.displayName
                : "Artisan Partner");

        return Scaffold(
          backgroundColor: KX.canvas,
          appBar: AppBar(
            backgroundColor: KX.canvas,
            elevation: 0,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Text(
              "Profile",
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

                  // Account Security & Trust Hub (Google, Phone OTP, Backup Password)
                  ProfileTrustHubCard(
                    user: widget.user,
                    role: "worker",
                  ),
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
                    label: const Text(
                      "Delete Account & Wipe Data (DPDP Act)",
                      style: TextStyle(
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

  int _calculateTrustScore(AppUser user) {
    int count = 0;
    final currentUser = FirebaseAuth.instance.currentUser;
    final hasPassword = (currentUser?.providerData.any((p) => p.providerId == "password") ?? false) || user.hasBackupPassword;
    final hasGoogle = currentUser?.providerData.any((p) => p.providerId == "google.com") ?? false;
    final hasPhone = (currentUser?.providerData.any((p) => p.providerId == "phone") ?? false) ||
        (currentUser?.phoneNumber != null && currentUser!.phoneNumber!.trim().isNotEmpty) ||
        user.isPhoneVerified;

    if (hasPassword) count++;
    if (hasGoogle) count++;
    if (hasPhone) count++;
    if (count == 0 && ((currentUser?.email?.isNotEmpty ?? false) || user.email.isNotEmpty)) return 15;
    return ((count / 3.0) * 100).round();
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
            (worker.preferredAreas.isNotEmpty ? worker.preferredAreas.first : "Base Station Unset");

        return Column(
          children: [
            // Center Avatar with Tinder-style verification progress ring
            ProfileAvatarTrustRing(
              score: _calculateTrustScore(liveUser),
              avatarRadius: 46,
              ringGap: 4.5,
              strokeWidth: 3.5,
              onTap: () => showProfileTrustHubSheet(
                context,
                user: liveUser,
                role: "worker",
                onUpdated: () => setState(() {}),
              ),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  WorkGoAvatar(
                    avatarBase64: avatar,
                    name: name,
                    radius: 46,
                    onEditTap: _handleAvatarUpload,
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
            ),
            const SizedBox(height: 14),

            // Name with Edit Option
            InkWell(
              onTap: () => _showEditNameDialog(context, worker, name),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: WorkGoFonts.display(
                          color: KX.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
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
                  label: "Edit",
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
                  label: "Refer",
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
        final expYears = worker.experienceYears > 0 ? "${worker.experienceYears} Yrs" : "New";
        final ratingVal = worker.avgRating > 0 ? "${worker.avgRating.toStringAsFixed(1)} ★" : "5.0 ★";

        return Row(
          children: [
            // Mint Green Card (Experience)
            Expanded(
              child: _buildBentoStatCard(
                title: "Experience",
                value: expYears,
                bgColor: const Color(0xFFD1FAE5),
                textColor: const Color(0xFF065F46),
              ),
            ),
            const SizedBox(width: 8),

            // Sky Blue Card (Jobs Done)
            Expanded(
              child: _buildBentoStatCard(
                title: "Jobs Done",
                value: "$totalJobsCount Done",
                bgColor: const Color(0xFFD6EBFF),
                textColor: const Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(width: 8),

            // Pastel Amber Card (Rating)
            Expanded(
              child: _buildBentoStatCard(
                title: "Co-op Rating",
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
                            "AI Match Strength",
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
                            "$matchPercent% ELITE",
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
                      "Priority Symptom Triage Active",
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
                    children: const [
                      Icon(Icons.tune_rounded, size: 13, color: KX.gold),
                      SizedBox(width: 4),
                      Text(
                        "Manage",
                        style: TextStyle(
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
                        "+${tags.length - 3} more",
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
    final skillsStr = worker.skills.isNotEmpty ? worker.skills.take(2).join(', ') : "General Trades";
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
            title: "Operating Base Station",
            subtitle: "$area · ${worker.serviceRadiusKm.toInt()} km Radius",
            onTap: () => showAddressManagementSheet(
              context,
              userId: worker.id,
              userRole: "worker",
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EDE6), indent: 56),
          _buildMenuItem(
            icon: Icons.construction_rounded,
            title: "Trade Skills & Rates",
            subtitle: "$skillsStr · ₹${worker.baseRate.toInt()} Base",
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
            title: "Equipment & Specializations",
            subtitle: matchPercent >= 85
                ? "$matchPercent% Strength · Priority Triage Active"
                : "$matchPercent% Strength · Add equipment to reach 85%+",
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
            title: "eKYC & Certification",
            subtitle: isKycApproved
                ? "Co-op Verified"
                : (worker.trustScore > 0
                    ? "Trust Score: ${worker.trustScore}/5 Signals"
                    : "Verification Pending"),
            badgeColor: isKycApproved ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
            badgeTextColor: isKycApproved ? const Color(0xFF065F46) : const Color(0xFF92400E),
            badgeText: isKycApproved
                ? "VERIFIED"
                : (worker.trustScore > 0 ? "${worker.trustScore}/5" : "PENDING"),
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
            title: "₹2 Lakh Welfare Shield",
            subtitle: worker.insuranceStatus ? "PMSBY / PMJJBY Active" : "Co-op Welfare Cover",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => WorkerWelfareScreen(worker: worker)),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EDE6), indent: 56),
          _buildMenuItem(
            icon: Icons.groups_rounded,
            title: "Peer Referral Network",
            subtitle: "2% Bonus · ${worker.referralCount} Referred",
            onTap: _showReferPeerDialog,
          ),
          const Divider(height: 1, color: Color(0xFFF0EDE6), indent: 56),
          _buildMenuItem(
            icon: Icons.explore_rounded,
            title: "Interactive App Tour",
            subtitle: "Explore features & operational tools",
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
                      Text(
                        title,
                        style: WorkGoFonts.heading(
                          color: KX.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCheckedIn ? "Titan Dispatch Active" : "Titan Standby",
                    style: WorkGoFonts.heading(
                      color: KX.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    isCheckedIn ? "Receiving live broadcasts" : "Offline · Tap to go live",
                    style: WorkGoFonts.body(
                      color: KX.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
              isCheckedIn ? "Check Out" : "Go Live",
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
        reason: "Scan fingerprint or face to verify identity before checking in.",
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text("Biometric verification cancelled. Check-in aborted.")),
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
                content: const Row(
                  children: [
                    Icon(Icons.face_retouching_off_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(child: Text("3D Face verification cancelled or failed. Check-in aborted.")),
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
                "Identity Verification Required",
                textAlign: TextAlign.center,
                style: WorkGoFonts.display(
                  color: KX.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "To guarantee transparent wage payouts and cooperative trust, complete your eKYC before going live on customer radar.",
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Complete Verification Now", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("I'll do it later", style: TextStyle(color: Color(0xFF9CA3AF))),
              ),
            ],
          ),
        );
      },
    );
  }
}

