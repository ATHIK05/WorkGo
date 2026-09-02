import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Premium WorkGo Avatar widget supporting Base64 images with memory cache,
/// glowing solar rings, and interactive camera upload badges.
class WorkGoAvatar extends StatelessWidget {
  const WorkGoAvatar({
    super.key,
    this.avatarBase64,
    this.name = "",
    this.radius = 30,
    this.gradient,
    this.border,
    this.glowColor,
    this.onEditTap,
    this.isLoading = false,
  });

  final String? avatarBase64;
  final String name;
  final double radius;
  final Gradient? gradient;
  final BoxBorder? border;
  final Color? glowColor;
  final VoidCallback? onEditTap;
  final bool isLoading;

  Uint8List? _decodeBase64(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      String clean = raw.trim();
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeBase64(avatarBase64);
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "W";
    final size = radius * 2;

    Widget avatarContent;
    if (isLoading) {
      avatarContent = const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(WorkGoColors.accent),
          ),
        ),
      );
    } else if (bytes != null && bytes.isNotEmpty) {
      avatarContent = ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(initial),
        ),
      );
    } else {
      avatarContent = _buildFallback(initial);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient ?? WorkGoColors.solarGoldGradient, // amber ring
            border: border ?? Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: (glowColor ?? WorkGoColors.primary).withValues(alpha: 0.25),
                blurRadius: 14,
                spreadRadius: -2,
              ),
            ],
          ),
          child: avatarContent,
        ),
        if (onEditTap != null)
          Positioned(
            bottom: -2,
            right: -2,
            child: GestureDetector(
              onTap: onEditTap,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: WorkGoColors.solarGoldGradient,
                  border: Border.all(color: Colors.white, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: WorkGoColors.accent.withValues(alpha: 0.30),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFF1A1A1A), // dark icon on yellow
                  size: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallback(String initial) {
    return Center(
      child: name.isNotEmpty
          ? Text(
              initial,
              style: WorkGoFonts.display(
                color: Colors.white,
                fontSize: radius * 0.75,
                fontWeight: FontWeight.w900,
              ),
            )
          : Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: radius * 0.9,
            ),
    );
  }
}
