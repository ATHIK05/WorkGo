import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';
import '../customer_theme.dart';
import '../services/voice_recognition_service.dart';
import 'live_booking_tracker_screen.dart';
import 'rapido_live_broadcast_screen.dart';

/// Symptom-First AI Triage and Specialist Recommendation Sheet.
/// Solves cross-disciplinary booking ambiguity (e.g. water motor electrical vs plumbing).
class SymptomTriageSheet extends StatefulWidget {
  final String customerId;
  final String? initialQuery;
  final DiagnosticResult? initialDiagnosis;
  final double? customerLat;
  final double? customerLng;
  final String? customerAddress;
  final bool autoStartVoice;

  const SymptomTriageSheet({
    super.key,
    required this.customerId,
    this.initialQuery,
    this.initialDiagnosis,
    this.customerLat,
    this.customerLng,
    this.customerAddress,
    this.autoStartVoice = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String customerId,
    String? initialQuery,
    DiagnosticResult? initialDiagnosis,
    double? customerLat,
    double? customerLng,
    String? customerAddress,
    bool autoStartVoice = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SymptomTriageSheet(
        customerId: customerId,
        initialQuery: initialQuery,
        initialDiagnosis: initialDiagnosis,
        customerLat: customerLat,
        customerLng: customerLng,
        customerAddress: customerAddress,
        autoStartVoice: autoStartVoice,
      ),
    );
  }

  @override
  State<SymptomTriageSheet> createState() => _SymptomTriageSheetState();
}

class _SymptomTriageSheetState extends State<SymptomTriageSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _observationsCtrl = TextEditingController();
  final BookingService _bookingService = BookingService();
  final AiDiagnosticService _aiService = AiDiagnosticService.instance;
  final VoiceRecognitionService _voiceService = VoiceRecognitionService.instance;

  DiagnosticResult? _diagnosis;
  bool _isAnalyzing = false;
  Timer? _debounceTimer;
  String? _selectedOptionLabel;
  bool _isDispatching = false;

  bool _isListeningVoice = false;
  double _voiceSoundLevel = 0.0;
  String _voiceStatusMsg = '';
  bool _isListeningObservations = false;

  final List<String> _quickSymptoms = const [
    'Water motor humming no water',
    'AC fan running but not cooling',
    'Inverter beeping continuously',
    'Geyser shock or lukewarm water',
    'Concealed pipe leak & wall dampness',
    'Main MCB tripping repeatedly',
    'RO purifier waste water overflow',
    'Washing machine not spinning',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDiagnosis != null) {
      _searchCtrl.text = widget.initialQuery?.trim() ?? widget.initialDiagnosis!.symptomQuery;
      _diagnosis = widget.initialDiagnosis;
      _isAnalyzing = false;
    } else if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchCtrl.text = widget.initialQuery!.trim();
      _triggerDiagnosis(_searchCtrl.text);
    } else if (widget.autoStartVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startVoiceListening();
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _observationsCtrl.dispose();
    _voiceService.cancelListening();
    super.dispose();
  }

  Future<void> _startObservationsVoiceListening() async {
    HapticFeedback.mediumImpact();
    setState(() => _isListeningObservations = true);

    final available = await _voiceService.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _observationsCtrl.text = words;
          _observationsCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: words.length),
          );
        });
        if (isFinal) {
          _stopObservationsVoiceListening();
        }
      },
      onSoundLevel: (_) {},
    );

    if (!available && mounted) {
      setState(() => _isListeningObservations = false);
    }
  }

  Future<void> _stopObservationsVoiceListening() async {
    await _voiceService.stopListening();
    if (mounted) {
      setState(() => _isListeningObservations = false);
    }
  }

  Future<void> _startVoiceListening() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isListeningVoice = true;
      _voiceStatusMsg = 'Listening... Speak your household problem clearly';
      _voiceSoundLevel = 0.0;
    });

    final available = await _voiceService.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _searchCtrl.text = words;
          _searchCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: words.length),
          );
        });

        if (isFinal && words.trim().isNotEmpty) {
          _stopVoiceListening();
          _triggerDiagnosis(words.trim());
        }
      },
      onSoundLevel: (level) {
        if (!mounted) return;
        setState(() {
          _voiceSoundLevel = level;
        });
      },
    );

    if (!available && mounted) {
      setState(() {
        _isListeningVoice = false;
        _voiceStatusMsg = 'Microphone speech recognition unavailable on this device';
      });
    }
  }

  Future<void> _stopVoiceListening() async {
    await _voiceService.stopListening();
    if (mounted) {
      setState(() {
        _isListeningVoice = false;
        _voiceSoundLevel = 0.0;
      });
    }
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _selectedOptionLabel = null;
    if (query.trim().isEmpty) {
      setState(() {
        _diagnosis = null;
        _isAnalyzing = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _triggerDiagnosis(query);
    });
  }

  Future<void> _triggerDiagnosis(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isAnalyzing = true);

    try {
      final result = await _aiService.diagnoseSymptom(query);
      if (mounted) {
        setState(() {
          _diagnosis = result;
          _isAnalyzing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _diagnosis = SymptomCatalog.matchSymptom(query);
          _isAnalyzing = false;
        });
      }
    }
  }

  void _selectTriageOption(TriageOption option) {
    if (_diagnosis == null) return;
    HapticFeedback.lightImpact();

    setState(() {
      _selectedOptionLabel = option.label;
      _diagnosis = _aiService.refineDiagnosis(
        baseResult: _diagnosis!,
        selectedProbableCategory: option.probableCategory,
        selectedOptionLabel: option.label,
        likelyCause: option.likelyCause,
      );
    });
  }

  Future<void> _bookDiagnosticVisit({Worker? preferredWorker}) async {
    if (_diagnosis == null || _isDispatching) return;
    HapticFeedback.mediumImpact();
    setState(() => _isDispatching = true);

    final buffer = StringBuffer();
    final customNotes = _observationsCtrl.text.trim();
    if (customNotes.isNotEmpty) {
      buffer.writeln(customNotes);
    }
    if (_selectedOptionLabel != null && _selectedOptionLabel!.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('Clarification: $_selectedOptionLabel');
    }
    final fullDetails = buffer.toString().trim();

    try {
      final bookingId = await _bookingService.createDiagnosticBooking(
        customerId: widget.customerId,
        primaryCategory: _diagnosis!.primaryCategory,
        symptomDescription: _diagnosis!.symptomQuery.isNotEmpty
            ? _diagnosis!.symptomQuery
            : _diagnosis!.summary,
        customerIssueDetails: fullDetails.isNotEmpty ? fullDetails : null,
        equipmentTag: _diagnosis!.equipmentTag,
        suggestedToolsNeeded: _diagnosis!.suggestedToolsNeeded,
        workerId: preferredWorker?.id,
        acceptedWorkerName: preferredWorker?.name,
        workerLatitude: preferredWorker?.latitude,
        workerLongitude: preferredWorker?.longitude,
        customerAddressText: widget.customerAddress ?? 'Registered Home Address',
        customerLatitude: widget.customerLat,
        customerLongitude: widget.customerLng,
        diagnosticFee: _diagnosis!.diagnosticFee,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close triage sheet

      if (preferredWorker != null) {
        // Direct assigned booking -> Live Booking Tracker
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LiveBookingTrackerScreen(
              bookingId: bookingId,
            ),
          ),
        );
      } else {
        // Diagnostic broadcast -> Rapido Live Broadcast Radar
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RapidoLiveBroadcastScreen(
              bookingId: bookingId,
              serviceCategory: _diagnosis!.primaryCategory,
              initialAmount: _diagnosis!.diagnosticFee,
              pickupAddress: widget.customerAddress ?? 'Home Location',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDispatching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not initialize dispatch: $e'),
            backgroundColor: CX.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: CX.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6D1C7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CX.violet.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.troubleshoot_rounded,
                    color: CX.amberDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Symptom Triage',
                        style: WorkGoFonts.heading(
                          color: CX.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Describe the problem · We diagnose the right craft trade',
                        style: WorkGoFonts.body(
                          color: CX.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: CX.textSecondary),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: CX.dividerLight),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Input
                  _buildSearchInput(),
                  const SizedBox(height: 14),

                  // Quick symptom chips when empty or analyzing
                  if (_diagnosis == null && !_isAnalyzing) ...[
                    Text(
                      'Common Household Problems',
                      style: WorkGoFonts.heading(
                        color: CX.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickSymptoms.map((symptom) {
                        return ActionChip(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: CX.dividerLight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          label: Text(
                            symptom,
                            style: WorkGoFonts.body(
                              color: CX.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onPressed: () {
                            _searchCtrl.text = symptom;
                            _triggerDiagnosis(symptom);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Analyzing State Indicator
                  if (_isAnalyzing) _buildAnalyzingShimmer(),

                  // Diagnostic Result View
                  if (_diagnosis != null && !_isAnalyzing) ...[
                    _buildDiagnosticReportCard(_diagnosis!),
                    const SizedBox(height: 16),

                    // Micro-Triage Clarifying Questions (if present)
                    if (_diagnosis!.clarifyingQuestions.isNotEmpty) ...[
                      _buildClarifyingQuestionsSection(_diagnosis!),
                      const SizedBox(height: 16),
                    ],

                    // Detailed Observations & Problem Notes
                    _buildDetailedObservationsInput(),
                    const SizedBox(height: 16),

                    // ₹99 Smart Diagnostic Guarantee Card
                    _buildDiagnosticGuaranteeCard(_diagnosis!),
                    const SizedBox(height: 20),

                    // Curated Top Recommended Specialists Carousel
                    _buildRecommendedSpecialistsSection(_diagnosis!),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          if (_diagnosis != null)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: CX.dividerLight)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                '₹99',
                                style: WorkGoFonts.heading(
                                  color: CX.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: CX.emerald.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '100% Credited',
                                  style: WorkGoFonts.body(
                                    color: CX.emerald,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Smart Diagnostic Inspection',
                            style: WorkGoFonts.body(
                              color: CX.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton.icon(
                      onPressed: _isDispatching ? null : () => _bookDiagnosticVisit(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CX.violet,
                        foregroundColor: const Color(0xFF141416),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isDispatching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF141416),
                              ),
                            )
                          : const Icon(Icons.flash_on_rounded, size: 18),
                      label: Text(
                        _isDispatching ? 'Dispatching...' : 'Book Diagnostic',
                        style: WorkGoFonts.body(
                          color: const Color(0xFF141416),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isListeningVoice ? CX.amberDark : CX.dividerLight,
              width: _isListeningVoice ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isListeningVoice
                    ? CX.amberDark.withValues(alpha: 0.15)
                    : const Color(0x0A000000),
                blurRadius: _isListeningVoice ? 14 : 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onQueryChanged,
            style: WorkGoFonts.body(
              color: CX.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Water motor humming sound or AC blowing room air...',
              hintStyle: WorkGoFonts.body(
                color: CX.textMuted,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: CX.amberDark,
                size: 22,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, color: CX.textSecondary, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onQueryChanged('');
                      },
                    ),
                  // Mic Trigger Button
                  GestureDetector(
                    onTap: () {
                      if (_isListeningVoice) {
                        _stopVoiceListening();
                        if (_searchCtrl.text.trim().isNotEmpty) {
                          _triggerDiagnosis(_searchCtrl.text.trim());
                        }
                      } else {
                        _startVoiceListening();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _isListeningVoice
                            ? CX.amberDark
                            : CX.violet.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isListeningVoice ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _isListeningVoice ? Colors.white : CX.amberDark,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        // Live Voice Listening HUD
        if (_isListeningVoice) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CX.amberDark.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: CX.amberDark,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _voiceStatusMsg,
                    style: WorkGoFonts.body(
                      color: const Color(0xFF92400E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildVoiceSoundBars(),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _stopVoiceListening,
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: CX.amberDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVoiceSoundBars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final height = 6.0 + (_voiceSoundLevel * (12.0 + (index * 2.5)));
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 3,
          height: height.clamp(4.0, 18.0),
          decoration: BoxDecoration(
            color: CX.amberDark,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildAnalyzingShimmer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CX.dividerLight),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: CX.amberDark,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Cross-Trade Diagnosis Running...',
                  style: WorkGoFonts.heading(
                    color: CX.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Evaluating electrical, plumbing, and mechanical fault trees',
                  style: WorkGoFonts.body(
                    color: CX.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticReportCard(DiagnosticResult diag) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CX.dividerLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trade matching badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: CX.violet.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CX.amberDark.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.handyman_rounded, color: CX.amberDark, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      'Primary: ${diag.primaryCategory}',
                      style: WorkGoFonts.body(
                        color: CX.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (diag.secondaryCategory != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz_rounded, color: CX.textSecondary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Relay: ${diag.secondaryCategory}',
                        style: WorkGoFonts.body(
                          color: CX.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CX.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(diag.confidence * 100).round()}% Confidence',
                  style: WorkGoFonts.body(
                    color: CX.emerald,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Diagnostic Summary
          Text(
            diag.equipmentTag,
            style: WorkGoFonts.heading(
              color: CX.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            diag.summary,
            style: WorkGoFonts.body(
              color: CX.textSecondary,
              fontSize: 13,
            ),
          ),

          if (diag.likelyCauses.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: CX.dividerLight),
            const SizedBox(height: 10),
            Text(
              'Suspected Root Causes:',
              style: WorkGoFonts.heading(
                color: CX.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...diag.likelyCauses.take(3).map(
                  (cause) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4, right: 8),
                          child: Icon(Icons.circle, size: 6, color: CX.amberDark),
                        ),
                        Expanded(
                          child: Text(
                            cause,
                            style: WorkGoFonts.body(
                              color: CX.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildClarifyingQuestionsSection(DiagnosticResult diag) {
    final question = diag.clarifyingQuestions.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CX.violet.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: CX.amberDark, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.questionText,
                  style: WorkGoFonts.heading(
                    color: CX.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...question.options.map((opt) {
            final isSelected = _selectedOptionLabel == opt.label;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => _selectTriageOption(opt),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? CX.amberDark : CX.dividerLight,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: isSelected ? CX.amberDark : CX.textMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          opt.label,
                          style: WorkGoFonts.body(
                            color: isSelected ? CX.textPrimary : CX.textSecondary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailedObservationsInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isListeningObservations ? CX.amberDark : CX.dividerLight,
          width: _isListeningObservations ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _isListeningObservations
                ? CX.amberDark.withValues(alpha: 0.12)
                : const Color(0x06000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_rounded, color: CX.amberDark, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Specific Signs or Observations',
                  style: WorkGoFonts.heading(
                    color: CX.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Optional',
                style: WorkGoFonts.body(
                  color: CX.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _observationsCtrl,
            maxLines: 2,
            style: WorkGoFonts.body(
              color: CX.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Water dripping from bottom right corner, unusual humming, or trips breaker...',
              hintStyle: WorkGoFonts.body(
                color: CX.textMuted,
                fontSize: 12,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CX.amberDark, width: 1.2),
              ),
              suffixIcon: GestureDetector(
                onTap: () {
                  if (_isListeningObservations) {
                    _stopObservationsVoiceListening();
                  } else {
                    _startObservationsVoiceListening();
                  }
                },
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isListeningObservations ? CX.amberDark : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListeningObservations ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: 18,
                    color: _isListeningObservations ? Colors.white : CX.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticGuaranteeCard(DiagnosticResult diag) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CX.amberDark.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: CX.amberDark,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Diagnostic Visit (₹${diag.diagnosticFee.round()})',
                  style: WorkGoFonts.heading(
                    color: const Color(0xFF78350F),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '100% credited against your final repair bill. Our certified artisan tests line voltage, pipe pressures, and windings on-site.',
                  style: WorkGoFonts.body(
                    color: const Color(0xFF92400E),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedSpecialistsSection(DiagnosticResult diag) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Specialists Ready to Inspect',
                style: WorkGoFonts.heading(
                  color: CX.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Co-op Certified',
              style: WorkGoFonts.body(
                color: CX.emerald,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Real Specialist Worker Stream
        StreamBuilder<List<Worker>>(
          stream: _bookingService.streamSpecializedWorkers(
            primaryCategory: diag.primaryCategory,
            secondaryCategory: diag.secondaryCategory,
            equipmentTag: diag.equipmentTag,
            keywords: diag.suggestedKeywords,
          ),
          builder: (context, snap) {
            final workers = snap.data ?? [];

            if (snap.connectionState == ConnectionState.waiting && workers.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2, color: CX.amberDark),
                ),
              );
            }

            if (workers.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CX.dividerLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: CX.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Dispatch will broadcast to nearest available verified artisans in your sector.',
                        style: WorkGoFonts.body(color: CX.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: workers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  final distanceLabel = worker.formattedDistanceString(
                    widget.customerLat,
                    widget.customerLng,
                  );

                  return Container(
                    width: 220,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: CX.dividerLight),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar + Status + Rating
                        Row(
                          children: [
                            WorkGoAvatar(
                              avatarBase64: worker.avatarBase64,
                              name: worker.name,
                              radius: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    worker.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: WorkGoFonts.heading(
                                      color: CX.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    distanceLabel,
                                    style: WorkGoFonts.body(
                                      color: CX.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Accuracy & Rating Pill
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: CX.amberDark),
                            const SizedBox(width: 3),
                            Text(
                              worker.avgRating.toStringAsFixed(1),
                              style: WorkGoFonts.body(
                                color: CX.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: CX.emerald.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${(worker.diagnosticAccuracyScore * 100).round()}% Accuracy',
                                style: WorkGoFonts.body(
                                  color: CX.emerald,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),

                        // 1-Tap Direct Specialist Booking Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isDispatching ? null : () => _bookDiagnosticVisit(preferredWorker: worker),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: CX.violet),
                              foregroundColor: const Color(0xFF141416),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Book Specialist',
                              style: WorkGoFonts.body(
                                color: const Color(0xFF141416),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
