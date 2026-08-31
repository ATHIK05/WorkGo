import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Service for picking profile images, converting them to Base64 strings,
/// and updating user avatars in Firestore.
class ImageUploadService {
  ImageUploadService._();
  static final ImageUploadService instance = ImageUploadService._();

  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Pick an image from camera or gallery and convert it to a Base64 string.
  Future<String?> pickImageAndConvertToBase64({
    ImageSource source = ImageSource.gallery,
    double maxWidth = 512,
    double maxHeight = 512,
    int imageQuality = 70,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (file == null) return null;

      final Uint8List bytes = await file.readAsBytes();
      final String base64String = base64Encode(bytes);
      return base64String;
    } catch (e) {
      debugPrint("Error picking/encoding image: $e");
      return null;
    }
  }

  /// Update user avatar Base64 in Firestore `users/{uid}`.
  Future<void> updateUserAvatar(String uid, String base64Image) async {
    await _db.collection("users").doc(uid).set({
      "avatarBase64": base64Image,
      "photoUrl": base64Image,
    }, SetOptions(merge: true));
  }

  /// Opens a modern Obsidian bottom sheet to select Camera or Gallery,
  /// converts to Base64, and updates the user profile directly.
  Future<String?> showAvatarPickerBottomSheet(
    BuildContext context, {
    required String uid,
  }) async {
    HapticFeedback.mediumImpact();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF130E2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              "Update Profile Picture",
              style: WorkGoFonts.display(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Select a photo to represent your profile on WorkGo",
              style: WorkGoFonts.body(
                color: WorkGoColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPickerOption(
                    ctx,
                    title: "Camera",
                    icon: Icons.camera_alt_rounded,
                    gradient: WorkGoColors.electricVioletGradient,
                    onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPickerOption(
                    ctx,
                    title: "Gallery",
                    icon: Icons.photo_library_rounded,
                    gradient: WorkGoColors.solarGoldGradient,
                    isGold: true,
                    onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;

    final base64String = await pickImageAndConvertToBase64(source: source);
    if (base64String != null && base64String.isNotEmpty) {
      await updateUserAvatar(uid, base64String);
      return base64String;
    }
    return null;
  }

  Widget _buildPickerOption(
    BuildContext ctx, {
    required String title,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
    bool isGold = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E153D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: (isGold ? WorkGoColors.accent : WorkGoColors.primaryLight)
                .withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gradient,
                boxShadow: [
                  BoxShadow(
                    color: (isGold ? WorkGoColors.accent : WorkGoColors.primary)
                        .withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isGold ? const Color(0xFF1E1035) : Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: WorkGoFonts.heading(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
