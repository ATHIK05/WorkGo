import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/ml_translation_service.dart';

/// A reactive widget that translates free-form text, Firebase data,
/// customer address locations, problem descriptions, and equipment names into the artisan's active locale.
///
/// Features:
///   - 0ms instant display via synchronous dictionary/cache (zero flicker/blank UI)
///   - Reacts automatically to language changes across app lifecycle
///   - Background ML Kit / Cloud fallback translation for deep phrases and long addresses
class TranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool isAddress;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.isAddress = false,
  });

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  late String _displayedText;
  String? _lastLocale;

  @override
  void initState() {
    super.initState();
    _displayedText = widget.text;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = context.locale.languageCode;
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _updateTranslation();
    }
  }

  @override
  void didUpdateWidget(TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.isAddress != widget.isAddress) {
      _updateTranslation();
    }
  }

  void _updateTranslation() {
    final locale = context.locale.languageCode;
    if (locale == 'en' || widget.text.trim().isEmpty) {
      _displayedText = widget.text;
      return;
    }

    // 1. Immediate synchronous resolution (Cache & Smart Dictionary)
    final syncVal = MlTranslationService.instance.translateSync(
      widget.text,
      locale,
      isAddress: widget.isAddress,
    );
    _displayedText = syncVal;

    // 2. Asynchronous deep translation (ML Kit on-device or Cloud fallback)
    MlTranslationService.instance
        .translate(
      widget.text,
      locale,
      isAddress: widget.isAddress,
    )
        .then((translated) {
      if (mounted && translated != _displayedText) {
        setState(() {
          _displayedText = translated;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
