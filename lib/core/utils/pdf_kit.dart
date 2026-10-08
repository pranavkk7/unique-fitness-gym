import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/models.dart';
import '../widgets/brand.dart';

/// Fonts, logo and the branded header shared by the member-facing PDFs (plans and progress
/// reports). Loaded from the asset bundle, so it works the same in tests.
class PdfKit {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font heavy;
  final pw.Font symbols;
  final pw.MemoryImage logo;

  static const red = PdfColor.fromInt(0xFFD9141C);
  static const grey = PdfColor.fromInt(0xFF666670);
  static const panel = PdfColor.fromInt(0xFFF4F4F6);

  PdfKit._(this.regular, this.bold, this.heavy, this.symbols, this.logo);

  static Future<PdfKit> load([AssetBundle? bundle]) async {
    final a = bundle ?? rootBundle;
    Future<pw.Font> font(String name) async => pw.Font.ttf(await a.load('assets/fonts/$name.ttf'));
    return PdfKit._(
      await font('Barlow-Regular'),
      await font('Barlow-Bold'),
      await font('BarlowCondensed-BlackItalic'),
      await font('UfgSymbols-Bold'),
      pw.MemoryImage((await a.load(BrandLogo.originalAsset)).buffer.asUint8List()),
    );
  }

  pw.TextStyle t(double size, {pw.Font? font, PdfColor color = PdfColors.black}) => pw.TextStyle(font: font ?? regular, fontSize: size, color: color, fontFallback: [symbols]);

  /// Logo, gym name and branch, then a red rule and the document title.
  pw.Widget header(GymSettings s, String title, {String subtitle = ''}) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(children: [
            pw.Image(logo, width: 64),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(s.gymName.toUpperCase(), style: t(18, font: heavy)),
                pw.Text('${s.branchName} branch', style: t(9.5, font: bold, color: red)),
                if (s.phone.isNotEmpty) pw.Text('Phone ${[s.phone, s.altPhone].where((p) => p.isNotEmpty).join(' / ')}', style: t(8.5, color: grey)),
              ]),
            ),
          ]),
          pw.SizedBox(height: 12),
          pw.Container(height: 3, color: red),
          pw.SizedBox(height: 12),
          pw.Text(title.toUpperCase(), style: t(17, font: heavy)),
          if (subtitle.isNotEmpty) pw.Text(subtitle, style: t(10, color: grey)),
          pw.SizedBox(height: 12),
        ],
      );

  pw.Widget footer(String text) => pw.Center(child: pw.Text(text, style: t(8, color: grey)));
}
