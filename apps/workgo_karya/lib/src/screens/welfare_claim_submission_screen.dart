import 'dart:convert';
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

/// Screen allowing artisans to submit a micro-insurance or emergency welfare claim (SIH 26089).
///
/// Features:
/// - Three encrypted document uploads: Doctor Certificate (Required, gate), Injury Photo (Optional),
///   Hospital/Ambulance Record (Optional).
/// - Optional booking link picker to corroborate job-linked incidents.
/// - Incident date selector & multi-line description field.
/// - Strict human-in-the-loop design: Never computes or surfaces internal confidence scores to the artisan.
class WelfareClaimSubmissionScreen extends StatefulWidget {
  const WelfareClaimSubmissionScreen({
    super.key,
    required this.worker,
  });

  final Worker worker;

  @override
  State<WelfareClaimSubmissionScreen> createState() => _WelfareClaimSubmissionScreenState();
}

class _WelfareClaimSubmissionScreenState extends State<WelfareClaimSubmissionScreen> {
  final WelfareService _welfareService = WelfareService();
  final BookingService _bookingService = BookingService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _descCtrl = TextEditingController();
  DateTime _incidentDate = DateTime.now();

  // Booking picker state
  List<Booking> _recentBookings = [];
  String? _selectedBookingId;
  bool _isLoadingBookings = true;

  // Document upload state
  // 1. Doctor Certificate (Required)
  String? _certDocId;
  String? _certFileName;
  String? _certFileSize;
  bool _isUploadingCert = false;

  // 2. Injury Photo (Optional)
  String? _photoDocId;
  String? _photoFileName;
  Uint8List? _photoPreviewBytes;
  bool _isUploadingPhoto = false;

  // 3. Hospital / Ambulance Record (Optional)
  String? _hospitalDocId;
  String? _hospitalFileName;
  String? _hospitalFileSize;
  bool _isUploadingHospital = false;

  // Submission & Validation state
  bool _isSubmitting = false;
  bool _isClaimSubmittedSuccessfully = false;
  String? _inlineErrorMessage;
  String? _submittedClaimId;

  @override
  void initState() {
    super.initState();
    _loadRecentBookings();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecentBookings() async {
    try {
      final bookings = await _bookingService.getWorkerRecentBookings(widget.worker.id, limit: 15);
      if (mounted) {
        setState(() {
          _recentBookings = bookings;
          _isLoadingBookings = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingBookings = false);
      }
    }
  }

  // ── Document Pickers & Encrypted Uploads ─────────────────────────────────────

  Future<void> _pickDoctorCertificate() async {
    setState(() => _inlineErrorMessage = null);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        Uint8List? bytes = file.bytes;
        if (bytes == null && !kIsWeb && file.path != null) {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            bytes = await ioFile.readAsBytes();
          }
        }

        if (bytes == null || bytes.isEmpty) {
          _showError("Could not read file contents. Please choose another file.");
          return;
        }

        if (bytes.length > 1000 * 1024) {
          _showError("Certificate is larger than 1MB. Please compress or take a smaller photo.");
          return;
        }

        setState(() {
          _isUploadingCert = true;
          _certFileName = file.name;
          _certFileSize = "${(bytes!.length / 1024).toStringAsFixed(1)} KB";
        });

        HapticFeedback.lightImpact();
        final base64Data = base64Encode(bytes);

        final uploadRes = await _welfareService.uploadEncryptedDocument(
          workerId: widget.worker.id,
          docType: "welfareCertificate",
          base64Data: base64Data,
          fileName: file.name,
        );

        if (mounted) {
          setState(() {
            _certDocId = uploadRes["docId"]?.toString();
            _isUploadingCert = false;
          });
          HapticFeedback.mediumImpact();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingCert = false);
        _showError("Failed to upload doctor certificate: $e");
      }
    }
  }

  Future<void> _pickInjuryPhoto(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.length > 1000 * 1024) {
          _showError("Photo is too large. Please take a standard photo under 1MB.");
          return;
        }

        setState(() {
          _isUploadingPhoto = true;
          _photoFileName = file.name.isNotEmpty ? file.name : "injury_photo.jpg";
          _photoPreviewBytes = bytes;
        });

        HapticFeedback.lightImpact();
        final base64Data = base64Encode(bytes);

        final uploadRes = await _welfareService.uploadEncryptedDocument(
          workerId: widget.worker.id,
          docType: "welfareInjuryPhoto",
          base64Data: base64Data,
          fileName: _photoFileName,
        );

        if (mounted) {
          setState(() {
            _photoDocId = uploadRes["docId"]?.toString();
            _isUploadingPhoto = false;
          });
          HapticFeedback.mediumImpact();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        _showError("Failed to upload injury photo: $e");
      }
    }
  }

  Future<void> _pickHospitalRecord() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        Uint8List? bytes = file.bytes;
        if (bytes == null && !kIsWeb && file.path != null) {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            bytes = await ioFile.readAsBytes();
          }
        }

        if (bytes == null || bytes.isEmpty) {
          _showError("Could not read file data.");
          return;
        }

        setState(() {
          _isUploadingHospital = true;
          _hospitalFileName = file.name;
          _hospitalFileSize = "${(bytes!.length / 1024).toStringAsFixed(1)} KB";
        });

        HapticFeedback.lightImpact();
        final base64Data = base64Encode(bytes);

        final uploadRes = await _welfareService.uploadEncryptedDocument(
          workerId: widget.worker.id,
          docType: "welfareHospitalRecord",
          base64Data: base64Data,
          fileName: file.name,
        );

        if (mounted) {
          setState(() {
            _hospitalDocId = uploadRes["docId"]?.toString();
            _isUploadingHospital = false;
          });
          HapticFeedback.mediumImpact();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingHospital = false);
        _showError("Failed to upload hospital record: $e");
      }
    }
  }

  // ── Date Picker ─────────────────────────────────────────────────────────────

  Future<void> _selectIncidentDate() async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate,
      firstDate: firstDate,
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF141416),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF141416),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _incidentDate = picked);
    }
  }

  // ── Claim Submission ────────────────────────────────────────────────────────

  Future<void> _handleSubmitClaim() async {
    setState(() => _inlineErrorMessage = null);

    // Hard client-side gate before network request
    if (_certDocId == null || _certDocId!.isEmpty) {
      setState(() {
        _inlineErrorMessage =
            "welfare_doctor_cert_mandatory".trSafe("Doctor Certificate is mandatory. A claim cannot be submitted without an official medical certificate.");
      });
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final res = await _welfareService.submitClaim(
        workerId: widget.worker.id,
        doctorCertificateDocId: _certDocId!,
        bookingId: _selectedBookingId,
        injuryPhotoDocId: _photoDocId,
        hospitalRecordDocId: _hospitalDocId,
        incidentDate: _incidentDate,
        description: _descCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isClaimSubmittedSuccessfully = true;
          _submittedClaimId = res["claimId"]?.toString() ?? "WL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          final errStr = e.toString().toLowerCase();
          if (errStr.contains("doctorcertificatedocid") || errStr.contains("certificate")) {
            _inlineErrorMessage =
                "Doctor Certificate required: The backend verified that your certificate was missing or invalid. Please upload a genuine medical certificate.";
          } else {
            _inlineErrorMessage = "Unable to submit claim: $e";
          }
        });
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "welfare_file_claim_title".trSafe("File Welfare Claim"),
          style: WorkGoFonts.heading(
            color: KX.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _isClaimSubmittedSuccessfully
            ? _buildSuccessView()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header Banner
                    _buildHeaderBanner(),
                    const SizedBox(height: 16),

                    // ── Inline Error Message (e.g. 400 certificate gate)
                    if (_inlineErrorMessage != null) ...[
                      _buildInlineErrorBanner(_inlineErrorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // ── Section 1: Uploads (3 Only)
                    _buildUploadsSection(),
                    const SizedBox(height: 18),

                    // ── Section 2: Optional Booking Picker
                    _buildBookingPickerSection(),
                    const SizedBox(height: 18),

                    // ── Section 3: Incident Date & Description
                    _buildIncidentDetailsSection(),
                    const SizedBox(height: 24),

                    // ── Submit Button
                    _buildSubmitButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFFD97706), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cooperative Emergency Assistance",
                  style: WorkGoFonts.heading(
                    color: KX.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Claims are confidential and reviewed directly by the cooperative committee. Upload doctor confirmation to initiate claim review.",
                  style: WorkGoFonts.body(
                    color: KX.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF87171)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: WorkGoFonts.body(
                color: const Color(0xFF991B1B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3 Accessible Upload Cards ───────────────────────────────────────────────

  Widget _buildUploadsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Document Evidence (Max 3)",
              style: WorkGoFonts.heading(
                color: KX.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "AES-256 ENCRYPTED",
                style: TextStyle(
                  color: Color(0xFF6D28D9),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 1. Doctor Certificate (MANDATORY)
        _buildUploadCard(
          title: "Doctor's Certificate / Prescription",
          subtitle: "Official letterhead, diagnosis, or government hospital slip",
          isRequired: true,
          isUploaded: _certDocId != null,
          isUploading: _isUploadingCert,
          fileName: _certFileName,
          fileSize: _certFileSize,
          onTap: _pickDoctorCertificate,
          icon: Icons.medical_services_rounded,
        ),
        const SizedBox(height: 10),

        // 2. Injury Photo (OPTIONAL)
        _buildUploadCard(
          title: "Injury / Incident Photo",
          subtitle: "Clear photo of injury or damaged workplace gear",
          isRequired: false,
          isUploaded: _photoDocId != null,
          isUploading: _isUploadingPhoto,
          fileName: _photoFileName,
          previewBytes: _photoPreviewBytes,
          onTap: () => _showPhotoSourceSheet(),
          icon: Icons.camera_alt_rounded,
        ),
        const SizedBox(height: 10),

        // 3. Hospital Record (OPTIONAL)
        _buildUploadCard(
          title: "Hospital / Ambulance Receipt",
          subtitle: "Emergency admission slip, pharmacy bill, or transport bill",
          isRequired: false,
          isUploaded: _hospitalDocId != null,
          isUploading: _isUploadingHospital,
          fileName: _hospitalFileName,
          fileSize: _hospitalFileSize,
          onTap: _pickHospitalRecord,
          icon: Icons.local_hospital_rounded,
        ),
      ],
    );
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Add Injury Photo",
                  style: WorkGoFonts.heading(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF141416)),
                  title: const Text("Take Photo with Camera", style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickInjuryPhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF141416)),
                  title: const Text("Choose from Gallery", style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickInjuryPhoto(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required bool isRequired,
    required bool isUploaded,
    required bool isUploading,
    required VoidCallback onTap,
    required IconData icon,
    String? fileName,
    String? fileSize,
    Uint8List? previewBytes,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUploaded ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
          width: isUploaded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: isUploaded
                      ? const Color(0xFFD1FAE5)
                      : (isRequired ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isUploaded ? Icons.check_circle_rounded : icon,
                  color: isUploaded
                      ? const Color(0xFF047857)
                      : (isRequired ? const Color(0xFFD97706) : const Color(0xFF6B7280)),
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
                            title,
                            style: WorkGoFonts.heading(
                              color: KX.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isRequired ? const Color(0xFFFEE2E2) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isRequired ? "REQUIRED" : "OPTIONAL",
                            style: TextStyle(
                              color: isRequired ? const Color(0xFFB91C1C) : const Color(0xFF4B5563),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: WorkGoFonts.body(color: KX.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (previewBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(previewBytes, height: 90, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (fileName != null)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file_rounded, size: 14, color: Color(0xFF047857)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "$fileName ${fileSize != null ? '($fileSize)' : ''}",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF047857),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  "No file attached",
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                ),
              ElevatedButton.icon(
                onPressed: isUploading ? null : onTap,
                icon: isUploading
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(isUploaded ? Icons.refresh_rounded : Icons.upload_file_rounded, size: 14),
                label: Text(
                  isUploading ? "Encrypting…" : (isUploaded ? "Replace" : "Upload"),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUploaded ? const Color(0xFFF3F4F6) : const Color(0xFF141416),
                  foregroundColor: isUploaded ? const Color(0xFF141416) : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section 2: Optional Booking Picker ──────────────────────────────────────

  Widget _buildBookingPickerSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.work_history_rounded, color: Color(0xFF141416), size: 18),
              const SizedBox(width: 8),
              Text(
                "Link To WorkGo Booking (Optional)",
                style: WorkGoFonts.heading(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Linking an on-duty booking enables cooperative phone corroboration with the customer.",
            style: WorkGoFonts.body(fontSize: 11, color: KX.textSecondary),
          ),
          const SizedBox(height: 10),
          if (_isLoadingBookings)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            DropdownButtonFormField<String?>(
              initialValue: _selectedBookingId,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("No specific booking (Off-Duty / General)", style: TextStyle(fontSize: 12)),
                ),
                ..._recentBookings.map((b) {
                  return DropdownMenuItem<String?>(
                    value: b.id,
                    child: Text(
                      "#${b.id.substring(0, b.id.length > 8 ? 8 : b.id.length)} · ${b.serviceType} · ₹${b.amount.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() => _selectedBookingId = val);
              },
            ),
        ],
      ),
    );
  }

  // ── Section 3: Incident Details ─────────────────────────────────────────────

  Widget _buildIncidentDetailsSection() {
    final dateStr = "${_incidentDate.day.toString().padLeft(2, '0')}/${_incidentDate.month.toString().padLeft(2, '0')}/${_incidentDate.year}";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Incident Date",
                style: WorkGoFonts.heading(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              InkWell(
                onTap: _selectIncidentDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF141416)),
                      const SizedBox(width: 6),
                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Incident Description",
            style: WorkGoFonts.heading(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Briefly explain how the injury occurred and current treatment status…",
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _certDocId != null && !_isSubmitting;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: canSubmit ? _handleSubmitClaim : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF141416),
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    _certDocId == null ? "Upload Doctor Certificate to Submit" : "Submit Welfare Claim",
                    style: TextStyle(
                      color: canSubmit ? Colors.white : const Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Protected by WorkGo Cooperative Mutual Fund. No automated rejection.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  // ── Success State ───────────────────────────────────────────────────────────

  Widget _buildSuccessView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xFF047857), size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              "Claim Submitted!",
              style: WorkGoFonts.display(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: KX.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Claim Ref: ${_submittedClaimId ?? ''}",
              style: WorkGoFonts.numeric(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF047857),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                "Your welfare claim has been received by the cooperative governance committee. An administrator will review your medical certificates within 24 to 48 hours.\n\nYou can track the live review progress at any time from your Welfare & Insurance dashboard.",
                textAlign: TextAlign.center,
                style: WorkGoFonts.body(
                  fontSize: 12.5,
                  color: KX.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF141416),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  "Return to Welfare Dashboard",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
