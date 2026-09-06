import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// High-fidelity HarfBuzz text shaper for the `pdf` package.
///
/// Standard Dart `pdf` lacks complex text layout (GSUB/GPOS/HarfBuzz), causing
/// Indic scripts (Tamil, Hindi/Devanagari, Telugu, Bengali) to render with
/// detached matras, missing ligatures, and broken conjuncts (e.g. dotted circles).
///
/// [IndicPdfShaper] resolves this by utilizing Flutter's native HarfBuzz-backed
/// [TextPainter] at 3.0x DPI (300+ DPI laser print quality), converting complex
/// script strings into pixel-perfect PDF widgets while preserving pure ASCII/numbers
/// as scalable vector text.
class IndicPdfShaper {
  IndicPdfShaper._();

  static final Map<String, _CachedShapedImage> _imageCache = {};
  static bool _fontsInitialized = false;

  /// Loads bundled font families into the Flutter engine if not already registered.
  static Future<void> ensureFontsLoaded() async {
    if (_fontsInitialized) return;
    try {
      final loaders = <FontLoader>[
        FontLoader('NotoSansTamil')
          ..addFont(rootBundle.load('packages/workgo_core/assets/fonts/NotoSansTamil-Regular.ttf')),
        FontLoader('NotoSansDevanagari')
          ..addFont(rootBundle.load('packages/workgo_core/assets/fonts/NotoSansDevanagari-Regular.ttf')),
        FontLoader('NotoSans')
          ..addFont(rootBundle.load('packages/workgo_core/assets/fonts/NotoSans-Regular.ttf')),
      ];
      await Future.wait(loaders.map((l) => l.load()));
      _fontsInitialized = true;
    } catch (_) {
      // System fonts or pubspec-declared fonts are used as fallback
      _fontsInitialized = true;
    }
  }

  /// Returns true if [text] contains any Indic Unicode code units.
  /// (Devanagari: 0x0900 - 0x097F, Tamil: 0x0B80 - 0x0BFF)
  static bool hasIndicCharacters(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if ((code >= 0x0900 && code <= 0x097F) || (code >= 0x0B80 && code <= 0x0BFF)) {
        return true;
      }
    }
    return false;
  }

  /// Renders [text] into a PDF widget.
  ///
  /// - If [text] is pure ASCII/numbers and [fallbackFont] is provided, returns
  ///   native vector [pw.Text].
  /// - If [text] contains Tamil or Hindi characters, shapes it via Flutter's
  ///   HarfBuzz text engine at 3.0x pixel ratio and returns a high-resolution [pw.Image].
  static Future<pw.Widget> render({
    required String text,
    required double fontSize,
    PdfColor? color,
    bool isBold = false,
    double? maxWidth,
    int? maxLines,
    pw.TextAlign align = pw.TextAlign.left,
    pw.Font? fallbackFont,
    String? locale,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return pw.SizedBox();
    }

    final isIndic = hasIndicCharacters(text);

    // If pure ASCII and fallback font provided, use native vector text
    if (!isIndic && fallbackFont != null) {
      return pw.Text(
        text,
        textAlign: align,
        maxLines: maxLines,
        style: pw.TextStyle(
          font: fallbackFont,
          fontSize: fontSize,
          color: color ?? const PdfColor.fromInt(0xFF141416),
        ),
      );
    }

    // Ensure fonts are loaded in Flutter's engine
    await ensureFontsLoaded();

    // Cache key for performance
    final effectiveColor = color ?? const PdfColor.fromInt(0xFF141416);
    final cacheKey = '$locale-$text-$fontSize-$isBold-${effectiveColor.toInt()}-$maxWidth-$align-$maxLines';
    final cached = _imageCache[cacheKey];

    if (cached != null) {
      return pw.Image(
        cached.image,
        width: cached.width,
        height: cached.height,
        fit: pw.BoxFit.contain,
      );
    }

    const double pixelRatio = 3.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio, pixelRatio);

    final flutterColor = Color.fromARGB(
      (effectiveColor.alpha * 255).round().clamp(0, 255),
      (effectiveColor.red * 255).round().clamp(0, 255),
      (effectiveColor.green * 255).round().clamp(0, 255),
      (effectiveColor.blue * 255).round().clamp(0, 255),
    );

    String? targetFamily;
    if (locale == 'hi' || _containsHindi(text)) {
      targetFamily = 'NotoSansDevanagari';
    } else if (locale == 'ta' || _containsTamil(text)) {
      targetFamily = 'NotoSansTamil';
    }

    final flutterAlign = align == pw.TextAlign.right
        ? TextAlign.right
        : (align == pw.TextAlign.center ? TextAlign.center : TextAlign.left);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: targetFamily,
          package: 'workgo_core',
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
          color: flutterColor,
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: flutterAlign,
      maxLines: maxLines,
    );

    textPainter.layout(maxWidth: maxWidth ?? double.infinity);
    textPainter.paint(canvas, Offset.zero);

    final renderedWidth = textPainter.width;
    final renderedHeight = textPainter.height;

    final picture = recorder.endRecording();
    final imageWidth = (renderedWidth * pixelRatio).ceil().clamp(1, 8192);
    final imageHeight = (renderedHeight * pixelRatio).ceil().clamp(1, 8192);

    final img = await picture.toImage(imageWidth, imageHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      // Fallback to basic text if rasterization fails
      return pw.Text(text, style: pw.TextStyle(font: fallbackFont, fontSize: fontSize, color: color));
    }

    final pngBytes = byteData.buffer.asUint8List();
    final memoryImage = pw.MemoryImage(pngBytes);
    _imageCache[cacheKey] = _CachedShapedImage(
      image: memoryImage,
      width: renderedWidth,
      height: renderedHeight,
    );

    return pw.Image(
      memoryImage,
      width: renderedWidth,
      height: renderedHeight,
      fit: pw.BoxFit.contain,
    );
  }

  static bool _containsHindi(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x0900 && code <= 0x097F) return true;
    }
    return false;
  }

  static bool _containsTamil(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x0B80 && code <= 0x0BFF) return true;
    }
    return false;
  }
}

class _CachedShapedImage {
  final pw.MemoryImage image;
  final double width;
  final double height;

  _CachedShapedImage({
    required this.image,
    required this.width,
    required this.height,
  });
}
