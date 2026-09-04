import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
import '../services/ml_translation_service.dart';

class RatingReviewScreen extends StatefulWidget {
  const RatingReviewScreen({
    super.key,
    required this.booking,
    this.workerName = "Artisan",
  });

  final Booking booking;
  final String workerName;

  @override
  State<RatingReviewScreen> createState() => _RatingReviewScreenState();
}

class _RatingReviewScreenState extends State<RatingReviewScreen>
    with TickerProviderStateMixin {
  double _rating = 5.0;
  final Set<String> _selectedTags = {"tag_punctual", "tag_professional"};
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  final List<String> _tags = [
    "tag_punctual",
    "tag_professional",
    "tag_fair_price",
    "tag_great_work",
  ];

  late AnimationController _successCtrl;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (widget.booking.workerId == null) {
      setState(() => _isSubmitted = true);
      _successCtrl.forward();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final workerService = WorkerService();
      await workerService.submitReview(
        workerId: widget.booking.workerId!,
        customerId: widget.booking.customerId,
        bookingId: widget.booking.id,
        rating: _rating,
        tags: _selectedTags.toList(),
        comment: _commentController.text.trim(),
      );
      if (mounted) {
        setState(() => _isSubmitted = true);
        _successCtrl.forward();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('review_submit_error'.tr(args: [e.toString()])),
            backgroundColor: CX.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuroraScaffold(
      appBar: AuroraAppBar(title: 'rate_service'.tr()),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: CAnim.slow,
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim), child: child),
          ),
          child: _isSubmitted
              ? _SuccessView(key: const ValueKey('success'), onDone: () => Navigator.of(context).pop())
              : SingleChildScrollView(
                  key: const ValueKey('form'),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  child: _buildFeedbackForm(),
                ),
        ),
      ),
    );
  }

  Widget _buildFeedbackForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Artisan Avatar + Question
        SlideFadeIn(
          child: AuroraCard(
            glowColor: CX.amber,
            borderColor: CX.amber.withValues(alpha: 0.3),
            child: Column(
              children: [
                // Avatar orb
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: CX.auroraVioletAmber,
                    boxShadow: [
                      BoxShadow(
                        color: CX.violet.withValues(alpha: 0.45),
                        blurRadius: 24,
                        spreadRadius: -4,
                      ),
                    ],
                    border: Border.all(
                      color: CX.amber.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.person_rounded, size: 42, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'how_was_service'.tr(args: [
                    MlTranslationService.instance.translateSync(
                      widget.workerName,
                      context.locale.languageCode,
                    ),
                  ]),
                  style: const TextStyle(
                    color: CX.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Interactive star rating
                _InteractiveStarRating(
                  rating: _rating,
                  onChanged: (val) => setState(() => _rating = val),
                ),
                const SizedBox(height: 10),
                Text(
                  _ratingLabel(_rating),
                  style: const TextStyle(
                    color: CX.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Feedback Tags
        SlideFadeIn(
          delay: const Duration(milliseconds: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'what_liked_most'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CX.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tagKey) {
                  final isSelected = _selectedTags.contains(tagKey);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTags.remove(tagKey);
                        } else {
                          _selectedTags.add(tagKey);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: CAnim.normal,
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? CX.auroraVioletCyan : null,
                        color: isSelected ? null : CX.glassCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? CX.cyan.withValues(alpha: 0.6)
                              : CX.glassBorder,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: CX.violet.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            tagKey.tr(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : CX.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Comment Input
        SlideFadeIn(
          delay: const Duration(milliseconds: 100),
          child: _AuroraCommentField(controller: _commentController),
        ),
        const SizedBox(height: 24),

        // Submit Button
        SlideFadeIn(
          delay: const Duration(milliseconds: 140),
          child: GlowButton(
            label: 'submit_rating'.tr(),
            icon: Icons.star_rounded,
            isLoading: _isSubmitting,
            onPressed: _submitRating,
            gradient: CX.auroraVioletAmber,
            glowColor: CX.amber,
            height: 54,
          ),
        ),
      ],
    );
  }

  String _ratingLabel(double rating) {
    if (rating >= 5) return 'rating_exceptional'.tr();
    if (rating >= 4) return 'rating_very_good'.tr();
    if (rating >= 3) return 'rating_good'.tr();
    if (rating >= 2) return 'rating_fair'.tr();
    return 'rating_needs_improvement'.tr();
  }
}

// ──────────────────────────────────────────────────────
//  INTERACTIVE STAR RATING — bouncy animated stars
// ──────────────────────────────────────────────────────
class _InteractiveStarRating extends StatefulWidget {
  const _InteractiveStarRating({
    required this.rating,
    required this.onChanged,
  });
  final double rating;
  final ValueChanged<double> onChanged;

  @override
  State<_InteractiveStarRating> createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<_InteractiveStarRating>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _scales = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 5; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      _controllers.add(ctrl);
      _scales.add(Tween<double>(begin: 1.0, end: 1.35).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.elasticOut),
      ));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onStarTap(int starIndex) {
    widget.onChanged((starIndex + 1).toDouble());
    _controllers[starIndex].forward().then((_) {
      _controllers[starIndex].reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < widget.rating;
        return GestureDetector(
          onTap: () => _onStarTap(i),
          child: AnimatedBuilder(
            animation: _scales[i],
            builder: (_, __) => Transform.scale(
              scale: _scales[i].value,
              child: Container(
                padding: const EdgeInsets.all(6),
                child: AnimatedSwitcher(
                  duration: CAnim.fast,
                  child: ShaderMask(
                    key: ValueKey(filled),
                    shaderCallback: (bounds) => (filled
                            ? CX.auroraVioletAmber
                            : LinearGradient(
                                colors: [CX.textMuted, CX.textMuted],
                              ))
                        .createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ──────────────────────────────────────────────────────
//  COMMENT FIELD
// ──────────────────────────────────────────────────────
class _AuroraCommentField extends StatefulWidget {
  const _AuroraCommentField({required this.controller});
  final TextEditingController controller;

  @override
  State<_AuroraCommentField> createState() => _AuroraCommentFieldState();
}

class _AuroraCommentFieldState extends State<_AuroraCommentField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: CAnim.normal,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _focused
              ? CX.violetLight.withValues(alpha: 0.6)
              : CX.glassBorder,
          width: 1.3,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: CX.violet.withValues(alpha: 0.15),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        maxLines: 4,
        style: const TextStyle(color: CX.textPrimary, fontSize: 14, height: 1.5),
        onTap: () => setState(() => _focused = true),
        onTapOutside: (_) => setState(() => _focused = false),
        decoration: InputDecoration(
          hintText: 'write_review'.tr(),
          hintStyle: TextStyle(color: CX.textMuted.withValues(alpha: 0.8), fontSize: 13),
          filled: true,
          fillColor: CX.glassCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
//  SUCCESS VIEW — celebratory
// ──────────────────────────────────────────────────────
class _SuccessView extends StatefulWidget {
  const _SuccessView({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView>
    with TickerProviderStateMixin {
  late AnimationController _orbCtrl;
  late AnimationController _particleCtrl;
  late Animation<double> _orbScale;
  late Animation<double> _particleFade;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _orbScale = CurvedAnimation(parent: _orbCtrl, curve: Curves.elasticOut);

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _particleFade = CurvedAnimation(parent: _particleCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated success orb
            ScaleTransition(
              scale: _orbScale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: CX.auroraSuccess,
                      boxShadow: [
                        BoxShadow(
                          color: CX.emerald.withValues(alpha: 0.5),
                          blurRadius: 40,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 54,
                      ),
                    ),
                  ),

                  // Animated particle ring
                  AnimatedBuilder(
                    animation: _particleFade,
                    builder: (_, __) => Opacity(
                      opacity: (1.0 - _particleFade.value).clamp(0.0, 1.0),
                      child: Container(
                        width: 120 + 60 * _particleFade.value,
                        height: 120 + 60 * _particleFade.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CX.emerald.withValues(
                                alpha: (1.0 - _particleFade.value) * 0.8),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            SlideFadeIn(
              delay: const Duration(milliseconds: 300),
              child: Text(
                'thank_you_feedback'.tr(),
                style: const TextStyle(
                  color: CX.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),

            SlideFadeIn(
              delay: const Duration(milliseconds: 380),
              child: Text(
                'feedback_helps_coop'.tr(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: CX.textSecondary.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            SlideFadeIn(
              delay: const Duration(milliseconds: 460),
              child: GlowButton(
                label: 'done'.tr(),
                icon: Icons.check_rounded,
                onPressed: widget.onDone,
                gradient: CX.auroraSuccess,
                glowColor: CX.emerald,
                height: 52,
                isFullWidth: false,
                borderRadius: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
