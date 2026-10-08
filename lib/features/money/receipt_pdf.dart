import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/brand.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';

/// Builds the receipt as an A5 PDF: gym logo and details, member, each line paid, total, and the
/// membership dates. Pure function of the data, so it can be tested without a device.
Future<Uint8List> buildReceiptPdf(GymProvider gym, String receiptNo, {AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  final lines = gym.paymentsOnReceipt(receiptNo);
  if (lines.isEmpty) throw ArgumentError('No payments on receipt $receiptNo');
  final member = gym.memberById(lines.first.memberId);
  final s = gym.settings;
  final total = lines.fold(0.0, (sum, p) => sum + p.amount);

  final regular = pw.Font.ttf(await assets.load('assets/fonts/Barlow-Regular.ttf'));
  final bold = pw.Font.ttf(await assets.load('assets/fonts/Barlow-Bold.ttf'));
  final heavy = pw.Font.ttf(await assets.load('assets/fonts/BarlowCondensed-BlackItalic.ttf'));
  final symbols = pw.Font.ttf(await assets.load('assets/fonts/UfgSymbols-Bold.ttf'));
  final logo = pw.MemoryImage((await assets.load(BrandLogo.originalAsset)).buffer.asUint8List());

  const red = PdfColor.fromInt(0xFFD9141C);
  const grey = PdfColor.fromInt(0xFF666670);
  pw.TextStyle t(double size, {pw.Font? font, PdfColor color = PdfColors.black}) => pw.TextStyle(font: font ?? regular, fontSize: size, color: color, fontFallback: [symbols]);

  pw.Widget row(String label, String value, {bool strong = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(label, style: t(strong ? 12 : 10.5, font: strong ? bold : regular, color: strong ? PdfColors.black : grey))),
          pw.Text(value, style: t(strong ? 14 : 10.5, font: bold)),
        ]),
      );

  final doc = pw.Document(title: 'Receipt $receiptNo', author: s.gymName);
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.all(28),
    build: (context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(logo, width: 78),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(s.gymName.toUpperCase(), style: t(20, font: heavy)),
                pw.Text('${s.branchName} branch', style: t(10, font: bold, color: red)),
                if (s.address.isNotEmpty) pw.Text(s.address, style: t(9, color: grey)),
                if (s.tagline.isNotEmpty) pw.Text(s.tagline, style: t(9, color: grey)),
                if (s.phone.isNotEmpty) pw.Text('Phone ${[s.phone, s.altPhone].where((p) => p.isNotEmpty).join(' / ')}', style: t(9, color: grey)),
              ]),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(height: 3, color: red),
        pw.SizedBox(height: 14),
        pw.Row(children: [
          pw.Expanded(child: pw.Text('PAYMENT RECEIPT', style: t(15, font: heavy))),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(receiptNo, style: t(11, font: bold)),
            pw.Text('${formatDate(lines.first.date)}, ${formatTime(lines.first.date)}', style: t(9, color: grey)),
          ]),
        ]),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFF4F4F6), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('RECEIVED FROM', style: t(8, font: bold, color: grey)),
                pw.Text(gym.payerOf(lines.first), style: t(12, font: bold)),
                if (member != null) pw.Text('${memberCode(member.number)} · ${member.phone}', style: t(9, color: grey)),
              ]),
            ),
            if (member != null && lines.any((p) => p.kind == PaymentKind.membership || p.kind == PaymentKind.admission))
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('VALID TILL', style: t(8, font: bold, color: grey)),
                pw.Text(formatDate(member.endDate), style: t(12, font: bold)),
                pw.Text(gym.planById(member.planId)?.name ?? '', style: t(9, color: grey)),
              ]),
          ]),
        ),
        pw.SizedBox(height: 12),
        for (final p in lines) row(p.note.isEmpty ? p.kind.label : p.note, formatMoney(p.amount)),
        pw.Divider(color: PdfColors.grey400),
        row('Total paid (${lines.first.method.label})', formatMoney(total), strong: true),
        if (member != null && member.balanceDue > 0) row('Balance due', formatMoney(member.balanceDue)),
        pw.Spacer(),
        pw.Center(child: pw.Text('Thank you for training with us!', style: t(11, font: bold, color: red))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('This is a computer-generated receipt.', style: t(8, color: grey))),
      ],
    ),
  ));
  return doc.save();
}

/// Opens the share sheet with the PDF receipt (WhatsApp, email, print).
Future<void> shareReceiptPdf(BuildContext context, String receiptNo) async {
  final gym = context.read<GymProvider>();
  try {
    final bytes = await buildReceiptPdf(gym, receiptNo);
    await Printing.sharePdf(bytes: bytes, filename: 'UFG-$receiptNo.pdf', subject: '${gym.settings.gymName} receipt $receiptNo');
  } catch (_) {
    if (context.mounted) showMessage(context, 'Could not create the PDF on this device.');
  }
}
