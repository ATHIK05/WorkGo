
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../localization/trade_localization.dart';
import '../models/booking.dart';
import '../models/payment_provider_model.dart';
import 'indic_pdf_shaper.dart';
import 'payment_service.dart';

/// Generates and exports a professional WorkGo tax invoice PDF entirely
/// on-device (RAM only) — matching the WorkGo corporate brand template.
///
/// Call [InvoiceService.exportInvoicePdf] from any screen after payment.
class InvoiceService {
  InvoiceService._();

  // ── Brand colours (matching WorkGo brand template) ────────────────────────
  static const _yellow = PdfColor.fromInt(0xFFF59E0B);
  static const _darkBg = PdfColor.fromInt(0xFF1C1B2E);
  static const _textPrimary = PdfColor.fromInt(0xFF141416);
  static const _textSecondary = PdfColor.fromInt(0xFF6B7280);
  static const _divider = PdfColor.fromInt(0xFFE5E0D8);
  static const _white = PdfColors.white;
  static const _green = PdfColor.fromInt(0xFF059669);

  /// Public entry point — call this from the UI layer.
  /// Always fetches fresh dynamic config from PaymentService so admin changes
  /// are instantly reflected.
  static Future<void> exportInvoicePdf({
    required Booking booking,
    required String workerName,
    required String paymentMethod,
    PaymentGatewayConfig? config,
    String? customerNameOverride,
    String? customerPhoneOverride,
    String? customerEmailOverride,
    required BuildContext context,
  }) async {
    final locale = context.locale.languageCode; // 'en', 'hi', 'ta'

    // Fetch fresh config from switchboard service (falls back to passed config or defaults)
    PaymentGatewayConfig activeConfig = config ?? PaymentGatewayConfig.defaults();
    try {
      activeConfig = await PaymentService.instance.getGatewayConfig();
    } catch (_) {
      activeConfig = config ?? PaymentGatewayConfig.defaults();
    }

    // ── 1. Load fonts ──────────────────────────────────────────────────────
    final regularFont = await _loadFont(locale);
    final boldFont = await _loadFont(locale);

    // ── 2. Load genuine WorkGo logo ────────────────────────────────────────
    final logoBytes =
        await rootBundle.load('packages/workgo_core/assets/images/workgo_logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // ── 3. Compute amounts dynamically ─────────────────────────────────────
    final platformFeePercent = activeConfig.platformFeePercent;
    final welfareFundPercent = activeConfig.welfareFundPercent;
    final gstPercent = activeConfig.gstPercent;

    final baseAmount = booking.amount > 0 ? booking.amount : 450.0;
    final emergencyFee = booking.isEmergency ? 150.0 : 0.0;
    final diagnosticCredit =
        (booking.isDiagnosticVisit && booking.isFeeCredited)
            ? booking.diagnosticFee
            : 0.0;
    final subtotal = baseAmount + emergencyFee - diagnosticCredit;

    final platformFee = platformFeePercent > 0
        ? baseAmount * (platformFeePercent / 100.0)
        : 0.0;
    final gstAmount = (gstPercent != null && gstPercent > 0)
        ? subtotal * (gstPercent / 100.0)
        : 0.0;
    final total = subtotal + platformFee + gstAmount;
    final welfareContribution = total * (welfareFundPercent / 100.0);

    // ── 4. Invoice meta & dynamic customer resolution ─────────────────────
    final txnId =
        (booking.invoiceId != null && booking.invoiceId!.isNotEmpty)
            ? booking.invoiceId!
            : 'TXN-${booking.id.toUpperCase().replaceAll('-', '').padRight(12, '0').substring(0, 12)}';
    final safeId = booking.id.length >= 8
        ? booking.id.substring(0, 8).toUpperCase()
        : booking.id.toUpperCase();
    final dateStr = DateFormat('dd / MM / yyyy')
        .format(booking.completedAt ?? DateTime.now());

    // Resolve customer details with full multi-layer fallback
    String resolvedCustomerName = (customerNameOverride ?? booking.customerName ?? '').trim();
    String resolvedCustomerPhone = (customerPhoneOverride ?? booking.customerPhone ?? '').trim();
    String resolvedCustomerEmail = (customerEmailOverride ?? booking.customerEmail ?? '').trim();
    String resolvedCustomerAddress = (booking.customerAddressText ?? '').trim();

    try {
      // 1. Check currently authenticated Firebase User
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        if (resolvedCustomerName.isEmpty &&
            currentUser.displayName != null &&
            currentUser.displayName!.trim().isNotEmpty) {
          resolvedCustomerName = currentUser.displayName!.trim();
        }
        if (resolvedCustomerPhone.isEmpty &&
            currentUser.phoneNumber != null &&
            currentUser.phoneNumber!.trim().isNotEmpty) {
          resolvedCustomerPhone = currentUser.phoneNumber!.trim();
        }
        if (resolvedCustomerEmail.isEmpty &&
            currentUser.email != null &&
            currentUser.email!.trim().isNotEmpty) {
          resolvedCustomerEmail = currentUser.email!.trim();
        }
      }

      // 2. Query Firestore 'users' collection using booking.customerId
      final targetUid = booking.customerId.isNotEmpty
          ? booking.customerId
          : (currentUser?.uid ?? '');

      if (targetUid.isNotEmpty &&
          (resolvedCustomerName.isEmpty ||
           resolvedCustomerPhone.isEmpty ||
           resolvedCustomerEmail.isEmpty ||
           resolvedCustomerAddress.isEmpty)) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .get();

        if (userDoc.exists) {
          final ud = userDoc.data() ?? {};
          if (resolvedCustomerName.isEmpty) {
            resolvedCustomerName = (ud['displayName'] ??
                    ud['name'] ??
                    ud['fullName'] ??
                    ud['customerName'] ??
                    '')
                .toString()
                .trim();
          }
          if (resolvedCustomerPhone.isEmpty) {
            resolvedCustomerPhone = (ud['phoneNumber'] ??
                    ud['phone'] ??
                    ud['mobile'] ??
                    ud['contactPhone'] ??
                    '')
                .toString()
                .trim();
          }
          if (resolvedCustomerEmail.isEmpty) {
            resolvedCustomerEmail =
                (ud['email'] ?? ud['mail'] ?? ud['userEmail'] ?? '')
                    .toString()
                    .trim();
          }
          if (resolvedCustomerAddress.isEmpty) {
            resolvedCustomerAddress =
                (ud['currentAddress'] ?? ud['address'] ?? '')
                    .toString()
                    .trim();
          }
        }
      }

      // 3. Fallback: Query 'customers' collection
      if (targetUid.isNotEmpty &&
          (resolvedCustomerName.isEmpty ||
           resolvedCustomerPhone.isEmpty ||
           resolvedCustomerEmail.isEmpty)) {
        final custDoc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(targetUid)
            .get();
        if (custDoc.exists) {
          final cd = custDoc.data() ?? {};
          if (resolvedCustomerName.isEmpty) {
            resolvedCustomerName = (cd['displayName'] ??
                    cd['name'] ??
                    cd['fullName'] ??
                    cd['customerName'] ??
                    '')
                .toString()
                .trim();
          }
          if (resolvedCustomerPhone.isEmpty) {
            resolvedCustomerPhone = (cd['phoneNumber'] ??
                    cd['phone'] ??
                    cd['mobile'] ??
                    cd['contactPhone'] ??
                    '')
                .toString()
                .trim();
          }
          if (resolvedCustomerEmail.isEmpty) {
            resolvedCustomerEmail =
                (cd['email'] ?? cd['mail'] ?? cd['userEmail'] ?? '')
                    .toString()
                    .trim();
          }
        }
      }

      // 4. Silently backfill booking document in Firestore
      if (booking.id.isNotEmpty) {
        final updates = <String, dynamic>{};
        if (resolvedCustomerName.isNotEmpty && (booking.customerName == null || booking.customerName!.isEmpty)) {
          updates['customerName'] = resolvedCustomerName;
        }
        if (resolvedCustomerPhone.isNotEmpty && (booking.customerPhone == null || booking.customerPhone!.isEmpty)) {
          updates['customerPhone'] = resolvedCustomerPhone;
        }
        if (resolvedCustomerEmail.isNotEmpty && (booking.customerEmail == null || booking.customerEmail!.isEmpty)) {
          updates['customerEmail'] = resolvedCustomerEmail;
        }
        if (updates.isNotEmpty) {
          FirebaseFirestore.instance.collection('bookings').doc(booking.id).update(updates).catchError((_) {});
        }
      }
    } catch (_) {}

    // Fallback if name is still 'Customer' or empty
    if (resolvedCustomerName.isEmpty || resolvedCustomerName.toLowerCase() == 'customer') {
      if (resolvedCustomerEmail.isNotEmpty) {
        final prefix = resolvedCustomerEmail.split('@').first;
        resolvedCustomerName = prefix
            .split(RegExp(r'[._-]'))
            .where((s) => s.isNotEmpty)
            .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
            .join(' ');
      }
    }
    if (resolvedCustomerName.isEmpty) {
      resolvedCustomerName = 'Valued Customer';
    }

    // ── 5. Dynamic artisan resolution with multi-layer fallback ────────────
    String resolvedWorkerName = (booking.genuineArtisanName ??
        (!Booking.isGenericArtisanName(workerName) ? workerName : '')).trim();

    if (Booking.isGenericArtisanName(resolvedWorkerName) &&
        booking.workerId != null &&
        booking.workerId!.isNotEmpty) {
      try {
        // 1. Query Firestore 'workers' collection
        final workerDoc = await FirebaseFirestore.instance
            .collection('workers')
            .doc(booking.workerId!)
            .get();
        if (workerDoc.exists) {
          final wd = workerDoc.data() ?? {};
          final name = (wd['name'] ?? wd['displayName'] ?? wd['artisanName'] ?? '').toString().trim();
          if (name.isNotEmpty && !Booking.isGenericArtisanName(name)) {
            resolvedWorkerName = name;
          }
        }

        // 2. Query Firestore 'users' collection if still generic
        if (Booking.isGenericArtisanName(resolvedWorkerName)) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(booking.workerId!)
              .get();
          if (userDoc.exists) {
            final ud = userDoc.data() ?? {};
            final name = (ud['displayName'] ?? ud['name'] ?? ud['fullName'] ?? '').toString().trim();
            if (name.isNotEmpty && !Booking.isGenericArtisanName(name)) {
              resolvedWorkerName = name;
            }
          }
        }
      } catch (_) {}
    }

    // Silently backfill booking document if artisan name was resolved
    if (resolvedWorkerName.isNotEmpty &&
        !Booking.isGenericArtisanName(resolvedWorkerName) &&
        booking.id.isNotEmpty &&
        booking.acceptedWorkerName != resolvedWorkerName) {
      FirebaseFirestore.instance
          .collection('bookings')
          .doc(booking.id)
          .update({'acceptedWorkerName': resolvedWorkerName})
          .catchError((_) {});
    }

    if (Booking.isGenericArtisanName(resolvedWorkerName)) {
      resolvedWorkerName = booking.serviceType.isNotEmpty
          ? "${booking.serviceType.substring(0, 1).toUpperCase()}${booking.serviceType.substring(1)} Artisan"
          : "Cooperative Artisan";
    }

    // ── 6. Build PDF matching the corporate template ───────────────────────
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

    // Pre-shape and localize all widgets before adding page
    final headerWidget = await _buildHeader(logoImage, regularFont, boldFont, locale);
    final bannerWidget = await _buildInvoiceBanner(boldFont, locale);
    final billToWidget = await _buildBillToRow(
      customerName: resolvedCustomerName,
      customerPhone: resolvedCustomerPhone,
      customerEmail: resolvedCustomerEmail,
      customerAddress: resolvedCustomerAddress,
      workerName: resolvedWorkerName,
      safeId: safeId,
      txnId: txnId,
      dateStr: dateStr,
      regularFont: regularFont,
      boldFont: boldFont,
      locale: locale,
    );
    final itemTableWidget = await _buildItemTable(
      booking: booking,
      baseAmount: baseAmount,
      emergencyFee: emergencyFee,
      diagnosticCredit: diagnosticCredit,
      regularFont: regularFont,
      boldFont: boldFont,
      locale: locale,
    );
    final summaryWidget = await _buildSummaryAndTerms(
      subtotal: subtotal,
      platformFee: platformFee,
      platformFeePercent: platformFeePercent,
      gstAmount: gstAmount,
      gstPercent: gstPercent,
      total: total,
      welfareContribution: welfareContribution,
      workerName: resolvedWorkerName,
      config: activeConfig,
      regularFont: regularFont,
      boldFont: boldFont,
      locale: locale,
    );
    final footerWidget = await _buildBottomFooter(
      config: activeConfig,
      regularFont: regularFont,
      boldFont: boldFont,
      locale: locale,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── 1. Header: Real WorkGo Logo + Brand Name ───────────────────
            headerWidget,
            pw.SizedBox(height: 14),

            // ── 2. Signature Yellow Band with INVOICE cutout ───────────────
            bannerWidget,
            pw.SizedBox(height: 18),

            // ── 3. Invoice To & Metadata Row ───────────────────────────────
            billToWidget,
            pw.SizedBox(height: 20),

            // ── 4. Items Table (NO QUANTITY COLUMN) ────────────────────────
            itemTableWidget,
            pw.SizedBox(height: 16),

            // ── 5. Lower Section: Terms on left, Breakdown & Total on right
            summaryWidget,

            pw.Spacer(),

            // ── 6. Bottom Footer: Contact on left, Signature on right ────────
            footerWidget,
          ],
        ),
      ),
    );

    // ── 7. Share via native OS share sheet ────────────────────────────────
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'WorkGo_Invoice_$safeId.pdf',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private builders matching the template layout with HarfBuzz text shaping
  // ──────────────────────────────────────────────────────────────────────────

  static Future<pw.Widget> _buildHeader(
    pw.MemoryImage logoImage,
    pw.Font regularFont,
    pw.Font boldFont,
    String locale,
  ) async {
    final taglineWidget = await IndicPdfShaper.render(
      text: 'invoice_coop_tagline'.tr(),
      fontSize: 8.5,
      color: _textSecondary,
      fallbackFont: regularFont,
      locale: locale,
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.ClipRRect(
          horizontalRadius: 10,
          verticalRadius: 10,
          child: pw.Image(logoImage, width: 48, height: 48, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(width: 12),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'WorkGo',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 20,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            pw.SizedBox(height: 2),
            taglineWidget,
          ],
        ),
      ],
    );
  }

  static Future<pw.Widget> _buildInvoiceBanner(pw.Font boldFont, String locale) async {
    final titleWidget = await IndicPdfShaper.render(
      text: 'invoice_title'.tr(),
      fontSize: 22,
      isBold: true,
      color: _textPrimary,
      maxWidth: 320,
      fallbackFont: boldFont,
      locale: locale,
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          flex: 62,
          child: pw.Container(height: 24, color: _yellow),
        ),
        pw.SizedBox(width: 14),
        titleWidget,
        pw.SizedBox(width: 14),
        pw.Expanded(
          flex: 14,
          child: pw.Container(height: 24, color: _yellow),
        ),
      ],
    );
  }

  static Future<pw.Widget> _buildBillToRow({
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String customerAddress,
    required String workerName,
    required String safeId,
    required String txnId,
    required String dateStr,
    required pw.Font regularFont,
    required pw.Font boldFont,
    required String locale,
  }) async {
    final invoiceToClean = 'invoice_to'.tr().replaceAll(RegExp(r':+$'), '').trim();
    final invoiceToLabel = await IndicPdfShaper.render(
      text: '$invoiceToClean:',
      fontSize: 11,
      isBold: true,
      color: _textPrimary,
      maxWidth: 260,
      fallbackFont: boldFont,
      locale: locale,
    );

    final customerNameWidget = await IndicPdfShaper.render(
      text: customerName,
      fontSize: 12,
      isBold: true,
      color: _textPrimary,
      maxWidth: 260,
      fallbackFont: boldFont,
      locale: locale,
    );

    pw.Widget? addressWidget;
    if (customerAddress.isNotEmpty) {
      addressWidget = await IndicPdfShaper.render(
        text: customerAddress,
        fontSize: 8.5,
        color: _textSecondary,
        maxWidth: 260,
        maxLines: 2,
        fallbackFont: regularFont,
        locale: locale,
      );
    }

    pw.Widget? phoneWidget;
    if (customerPhone.isNotEmpty) {
      final phoneLabel = 'invoice_phone'.tr().replaceAll(RegExp(r':+$'), '').trim();
      phoneWidget = await IndicPdfShaper.render(
        text: '$phoneLabel: $customerPhone',
        fontSize: 8.5,
        color: _textSecondary,
        maxWidth: 260,
        fallbackFont: regularFont,
        locale: locale,
      );
    }

    pw.Widget? emailWidget;
    if (customerEmail.isNotEmpty) {
      final emailLabel = 'invoice_email'.tr().replaceAll(RegExp(r':+$'), '').trim();
      emailWidget = await IndicPdfShaper.render(
        text: '$emailLabel: $customerEmail',
        fontSize: 8.5,
        color: _textSecondary,
        maxWidth: 260,
        fallbackFont: regularFont,
        locale: locale,
      );
    }

    final metaRows = await Future.wait([
      _metaRow('invoice_num'.tr(), txnId, regularFont, boldFont, locale),
      _metaRow('invoice_date'.tr(), dateStr, regularFont, boldFont, locale),
      _metaRow('invoice_booking'.tr(), '#$safeId', regularFont, boldFont, locale),
      _metaRow('invoice_artisan'.tr(), workerName, regularFont, boldFont, locale),
    ]);

    final paidLabelWidget = await IndicPdfShaper.render(
      text: 'invoice_paid'.tr(),
      fontSize: 9,
      isBold: true,
      color: _white,
      maxWidth: 120,
      fallbackFont: boldFont,
      locale: locale,
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Invoice To
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              invoiceToLabel,
              pw.SizedBox(height: 5),
              customerNameWidget,
              if (addressWidget != null) ...[
                pw.SizedBox(height: 3),
                addressWidget,
              ],
              if (phoneWidget != null) ...[
                pw.SizedBox(height: 2),
                phoneWidget,
              ],
              if (emailWidget != null) ...[
                pw.SizedBox(height: 2),
                emailWidget,
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        // Right: Metadata
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              metaRows[0],
              pw.SizedBox(height: 6),
              metaRows[1],
              pw.SizedBox(height: 6),
              metaRows[2],
              pw.SizedBox(height: 6),
              metaRows[3],
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: pw.BoxDecoration(
                    color: _green,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: paidLabelWidget,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Future<pw.Widget> _metaRow(
    String label,
    String value,
    pw.Font regularFont,
    pw.Font boldFont,
    String locale,
  ) async {
    final cleanLabel = label.replaceAll(RegExp(r':+$'), '').trim();
    final labelWidget = await IndicPdfShaper.render(
      text: cleanLabel,
      fontSize: 8.5,
      color: _textSecondary,
      maxWidth: 100,
      fallbackFont: regularFont,
      locale: locale,
    );
    final valueWidget = await IndicPdfShaper.render(
      text: value,
      fontSize: 8.5,
      isBold: true,
      color: _textPrimary,
      align: pw.TextAlign.right,
      maxWidth: 110,
      fallbackFont: boldFont,
      locale: locale,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        labelWidget,
        valueWidget,
      ],
    );
  }

  /// Item table without any Quantity column — suitable for service invoices.
  static Future<pw.Widget> _buildItemTable({
    required Booking booking,
    required double baseAmount,
    required double emergencyFee,
    required double diagnosticCredit,
    required pw.Font regularFont,
    required pw.Font boldFont,
    required String locale,
  }) async {
    int sl = 0;
    final rowFutures = <Future<List<pw.Widget>>>[];

    sl++;
    final tradeName = booking.serviceType.isNotEmpty
        ? booking.serviceType.toLocalizedTrade()
        : 'cat_cleaning'.tr();
    rowFutures.add(_createTableRow(
      sl: '$sl',
      desc: tradeName,
      price: '₹${baseAmount.toStringAsFixed(0)}',
      total: '₹${baseAmount.toStringAsFixed(0)}',
      isBold: false,
      regularFont: regularFont,
      boldFont: boldFont,
      locale: locale,
    ));

    if (emergencyFee > 0) {
      sl++;
      rowFutures.add(_createTableRow(
        sl: '$sl',
        desc: 'invoice_emergency_fee'.tr(),
        price: '₹${emergencyFee.toStringAsFixed(0)}',
        total: '₹${emergencyFee.toStringAsFixed(0)}',
        isBold: false,
        regularFont: regularFont,
        boldFont: boldFont,
        locale: locale,
      ));
    }

    if (diagnosticCredit > 0) {
      sl++;
      rowFutures.add(_createTableRow(
        sl: '$sl',
        desc: 'invoice_diagnostic_credit'.tr(),
        price: '-₹${diagnosticCredit.toStringAsFixed(0)}',
        total: '-₹${diagnosticCredit.toStringAsFixed(0)}',
        isBold: false,
        isNegative: true,
        regularFont: regularFont,
        boldFont: boldFont,
        locale: locale,
      ));
    }

    final headers = await Future.wait([
      IndicPdfShaper.render(text: 'invoice_sl'.tr(), fontSize: 9, isBold: true, color: _white, maxWidth: 36, fallbackFont: boldFont, locale: locale),
      IndicPdfShaper.render(text: 'invoice_item_desc'.tr(), fontSize: 9, isBold: true, color: _white, maxWidth: 290, fallbackFont: boldFont, locale: locale),
      IndicPdfShaper.render(text: 'invoice_price'.tr(), fontSize: 9, isBold: true, color: _white, align: pw.TextAlign.right, maxWidth: 68, fallbackFont: boldFont, locale: locale),
      IndicPdfShaper.render(text: 'invoice_total'.tr(), fontSize: 9, isBold: true, color: _white, align: pw.TextAlign.right, maxWidth: 68, fallbackFont: boldFont, locale: locale),
    ]);

    final rows = await Future.wait(rowFutures);

    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(46),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(80),
        3: const pw.FixedColumnWidth(80),
      },
      border: pw.TableBorder.all(color: _divider, width: 0.5),
      children: [
        // Header (dark bar)
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _darkBg),
          children: headers
              .asMap()
              .entries
              .map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: e.value,
                  ))
              .toList(),
        ),
        // Item rows
        ...rows.asMap().entries.map((entry) {
          final isEven = entry.key % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? _white : const PdfColor.fromInt(0xFFFAFAFA),
            ),
            children: entry.value
                .map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: cell,
                    ))
                .toList(),
          );
        }),
        // Empty footer row matching template box layout
        pw.TableRow(
          children: List.generate(
            4,
            (_) => pw.Container(height: 48),
          ),
        ),
      ],
    );
  }

  static Future<List<pw.Widget>> _createTableRow({
    required String sl,
    required String desc,
    required String price,
    required String total,
    required bool isBold,
    bool isNegative = false,
    required pw.Font regularFont,
    required pw.Font boldFont,
    required String locale,
  }) async {
    final effectiveColor = isNegative ? _green : _textPrimary;
    final wSl = await IndicPdfShaper.render(
      text: sl,
      fontSize: 9,
      isBold: isBold,
      color: effectiveColor,
      maxWidth: 34,
      fallbackFont: isBold ? boldFont : regularFont,
      locale: locale,
    );
    final wDesc = await IndicPdfShaper.render(
      text: desc,
      fontSize: 9,
      isBold: isBold,
      color: effectiveColor,
      maxWidth: 290,
      fallbackFont: isBold ? boldFont : regularFont,
      locale: locale,
    );
    final wPrice = await IndicPdfShaper.render(
      text: price,
      fontSize: 9,
      isBold: isBold,
      color: effectiveColor,
      align: pw.TextAlign.right,
      maxWidth: 68,
      fallbackFont: isBold ? boldFont : regularFont,
      locale: locale,
    );
    final wTotal = await IndicPdfShaper.render(
      text: total,
      fontSize: 9,
      isBold: isBold,
      color: effectiveColor,
      align: pw.TextAlign.right,
      maxWidth: 68,
      fallbackFont: isBold ? boldFont : regularFont,
      locale: locale,
    );
    return [wSl, wDesc, wPrice, wTotal];
  }

  /// Lower section: Terms on left, Breakdown and solid Yellow Total on right.
  static Future<pw.Widget> _buildSummaryAndTerms({
    required double subtotal,
    required double platformFee,
    required double platformFeePercent,
    required double gstAmount,
    required double? gstPercent,
    required double total,
    required double welfareContribution,
    required String workerName,
    required PaymentGatewayConfig config,
    required pw.Font regularFont,
    required pw.Font boldFont,
    required String locale,
  }) async {
    const double leftColWidth = 250.0;

    final thankYouWidget = await IndicPdfShaper.render(
      text: 'thank_you_business'.tr(),
      fontSize: 9.0,
      isBold: true,
      color: _textPrimary,
      maxWidth: leftColWidth,
      fallbackFont: boldFont,
      locale: locale,
    );

    final welfareFormatted = (locale == 'ta' || locale == 'hi')
        ? 'invoice_welfare_contribution'.tr(args: [
            workerName,
            '₹${welfareContribution.toStringAsFixed(1)}',
          ])
        : 'invoice_welfare_contribution'.tr(args: [
            '₹${welfareContribution.toStringAsFixed(1)}',
            workerName,
          ]);

    final welfareWidget = await IndicPdfShaper.render(
      text: welfareFormatted,
      fontSize: 8,
      color: const PdfColor.fromInt(0xFF047857),
      maxWidth: leftColWidth,
      fallbackFont: regularFont,
      locale: locale,
    );

    final termsHeadingWidget = await IndicPdfShaper.render(
      text: 'invoice_terms_heading'.tr(),
      fontSize: 9,
      isBold: true,
      color: _textPrimary,
      maxWidth: leftColWidth,
      fallbackFont: boldFont,
      locale: locale,
    );

    final termsText = _hasValue(config.invoiceTerms) ? config.invoiceTerms! : 'invoice_terms'.tr();
    final termsBodyWidget = await IndicPdfShaper.render(
      text: termsText,
      fontSize: 8,
      color: _textSecondary,
      maxWidth: leftColWidth,
      fallbackFont: regularFont,
      locale: locale,
    );

    final subTotalRow = await _summaryRow(
      'invoice_subtotal'.tr(),
      '₹${subtotal.toStringAsFixed(2)}',
      regularFont,
      boldFont,
      locale,
    );

    pw.Widget? platformFeeRow;
    if (platformFee > 0) {
      final pStr = platformFeePercent.toStringAsFixed(platformFeePercent == platformFeePercent.roundToDouble() ? 0 : 1);
      platformFeeRow = await _summaryRow(
        '${'invoice_platform_fee'.tr()} ($pStr%)',
        '₹${platformFee.toStringAsFixed(2)}',
        regularFont,
        regularFont,
        locale,
      );
    }

    pw.Widget? gstRow;
    if (gstPercent != null && gstPercent > 0 && gstAmount > 0) {
      final gStr = gstPercent.toStringAsFixed(gstPercent == gstPercent.roundToDouble() ? 0 : 1);
      gstRow = await _summaryRow(
        '${'invoice_gst'.tr()} ($gStr%)',
        '₹${gstAmount.toStringAsFixed(2)}',
        regularFont,
        regularFont,
        locale,
      );
    }

    final totalLabelText = 'invoice_total_amount'.tr().replaceAll(RegExp(r':+$'), '').trim();
    final totalLabelWidget = await IndicPdfShaper.render(
      text: '$totalLabelText:',
      fontSize: 11,
      isBold: true,
      color: _textPrimary,
      maxWidth: 115,
      fallbackFont: boldFont,
      locale: locale,
    );
    final totalValWidget = await IndicPdfShaper.render(
      text: '₹${total.toStringAsFixed(2)}',
      fontSize: 12,
      isBold: true,
      color: _textPrimary,
      align: pw.TextAlign.right,
      maxWidth: 85,
      fallbackFont: boldFont,
      locale: locale,
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left Column: Thank you note + Terms & Conditions
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              thankYouWidget,
              pw.SizedBox(height: 4),
              welfareWidget,
              pw.SizedBox(height: 14),
              termsHeadingWidget,
              pw.SizedBox(height: 4),
              termsBodyWidget,
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        // Right Column: Subtotal, Platform Fee, GST, and Solid Yellow Total Box
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            children: [
              subTotalRow,
              if (platformFeeRow != null) ...[
                pw.SizedBox(height: 5),
                platformFeeRow,
              ],
              if (gstRow != null) ...[
                pw.SizedBox(height: 5),
                gstRow,
              ],
              pw.SizedBox(height: 8),
              // Solid Yellow Total Box matching template
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: _yellow,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    totalLabelWidget,
                    totalValWidget,
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Future<pw.Widget> _summaryRow(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valFont,
    String locale,
  ) async {
    final cleanLabel = label.replaceAll(RegExp(r':+$'), '').trim();
    final labelWidget = await IndicPdfShaper.render(
      text: '$cleanLabel:',
      fontSize: 8.5,
      color: _textSecondary,
      maxWidth: 130,
      fallbackFont: labelFont,
      locale: locale,
    );
    final valWidget = await IndicPdfShaper.render(
      text: value,
      fontSize: 8.5,
      color: _textPrimary,
      align: pw.TextAlign.right,
      maxWidth: 75,
      fallbackFont: valFont,
      locale: locale,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        labelWidget,
        valWidget,
      ],
    );
  }

  /// Bottom footer: Left has yellow bar with contact info, Right has signature line matching template.
  static Future<pw.Widget> _buildBottomFooter({
    required PaymentGatewayConfig config,
    required pw.Font regularFont,
    required pw.Font boldFont,
    required String locale,
  }) async {
    final hasContact = _hasValue(config.invoicePhone) ||
        _hasValue(config.invoiceEmail) ||
        _hasValue(config.invoiceWebsite);
    final hasSignatory = _hasValue(config.invoiceAuthorisedSignatory);

    pw.Widget? contactWidget;
    if (hasContact) {
      final parts = <String>[];
      final phoneLabel = 'invoice_phone'.tr().replaceAll(RegExp(r':+$'), '').trim();
      final emailLabel = 'invoice_email'.tr().replaceAll(RegExp(r':+$'), '').trim();
      final webLabel = 'invoice_website'.tr().replaceAll(RegExp(r':+$'), '').trim();
      if (_hasValue(config.invoicePhone)) parts.add('$phoneLabel: ${config.invoicePhone!}');
      if (_hasValue(config.invoiceEmail)) parts.add('$emailLabel: ${config.invoiceEmail!}');
      if (_hasValue(config.invoiceWebsite)) parts.add('$webLabel: ${config.invoiceWebsite!}');

      contactWidget = await IndicPdfShaper.render(
        text: parts.join('   |   '),
        fontSize: 8,
        color: _textSecondary,
        maxWidth: 320,
        fallbackFont: regularFont,
        locale: locale,
      );
    }

    final signLabelWidget = await IndicPdfShaper.render(
      text: 'authorised_sign'.tr(),
      fontSize: 8.5,
      color: _textSecondary,
      maxWidth: 160,
      align: pw.TextAlign.center,
      fallbackFont: regularFont,
      locale: locale,
    );

    pw.Widget? signatoryNameWidget;
    if (hasSignatory) {
      signatoryNameWidget = await IndicPdfShaper.render(
        text: config.invoiceAuthorisedSignatory!,
        fontSize: 9,
        isBold: true,
        color: _textPrimary,
        maxWidth: 160,
        align: pw.TextAlign.center,
        fallbackFont: boldFont,
        locale: locale,
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Yellow horizontal bar + Contact details
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(height: 2.5, color: _yellow),
              if (contactWidget != null) ...[
                pw.SizedBox(height: 8),
                contactWidget,
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 32),
        // Right: Signature line + Authorised Sign
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(height: 0.8, color: _textPrimary),
              pw.SizedBox(height: 5),
              signLabelWidget,
              if (signatoryNameWidget != null) ...[
                pw.SizedBox(height: 2),
                signatoryNameWidget,
              ],
            ],
          ),
        ),
      ],
    );
  }

  static bool _hasValue(String? v) => v != null && v.trim().isNotEmpty;

  // ── Font Loader ─────────────────────────────────────────────────────────

  static Future<pw.Font> _loadFont(String locale) async {
    final String path;
    switch (locale) {
      case 'hi':
        path =
            'packages/workgo_core/assets/fonts/NotoSansDevanagari-Regular.ttf';
        break;
      case 'ta':
        path = 'packages/workgo_core/assets/fonts/NotoSansTamil-Regular.ttf';
        break;
      default:
        path = 'packages/workgo_core/assets/fonts/NotoSans-Regular.ttf';
    }
    final data = await rootBundle.load(path);
    return pw.Font.ttf(data);
  }
}

