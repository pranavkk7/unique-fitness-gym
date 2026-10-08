import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/utils/pdf_kit.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';

/// A workout or diet plan as an A4 PDF, optionally personalised with the member's name.
Future<Uint8List> buildPlanPdf(GymProvider gym, TrainingPlan plan, {Member? member, AssetBundle? bundle}) async {
  final k = await PdfKit.load(bundle);
  final trainer = gym.trainerById(member?.trainerId);
  final doc = pw.Document(title: plan.name, author: gym.settings.gymName);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    header: (_) => k.header(gym.settings, plan.name, subtitle: [plan.kind.label, if (plan.goal.isNotEmpty) plan.goal].join(' · ')),
    footer: (_) => k.footer('General guidance from ${gym.settings.gymName}. Check with a doctor before starting if you have a health condition.'),
    build: (_) => [
      if (member != null)
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          margin: const pw.EdgeInsets.only(bottom: 14),
          decoration: pw.BoxDecoration(color: PdfKit.panel, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text('Prepared for ${member.name} (${memberCode(member.number)})', style: k.t(11, font: k.bold))),
            pw.Text([if (trainer != null) 'Trainer: ${trainer.name}', formatDate(gym.today)].join(' · '), style: k.t(9, color: PdfKit.grey)),
          ]),
        ),
      for (final s in plan.sections)
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: PdfKit.red, width: 3))),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(s.title, style: k.t(11.5, font: k.bold, color: PdfKit.red)),
            pw.SizedBox(height: 4),
            for (final line in s.body.split('\n').where((l) => l.trim().isNotEmpty))
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('•  ', style: k.t(10.5, color: PdfKit.grey)),
                  pw.Expanded(child: pw.Text(line.trim(), style: k.t(10.5))),
                ]),
              ),
          ]),
        ),
      if (plan.notes.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text('Notes', style: k.t(10, font: k.bold, color: PdfKit.grey)),
        pw.Text(plan.notes, style: k.t(10.5)),
      ],
    ],
  ));
  return doc.save();
}

/// One member's monthly progress report as an A5 PDF with a weekly visits chart.
Future<Uint8List> buildProgressPdf(GymProvider gym, String memberId, {DateTime? month, AssetBundle? bundle}) async {
  final k = await PdfKit.load(bundle);
  final r = gym.progressReport(memberId, month);
  final m = r.member;
  final change = r.weightChange;
  final peak = r.weeklyVisits.fold(1, (a, b) => a > b ? a : b);

  pw.Widget tile(String label, String value, {String sub = ''}) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.all(3),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: PdfKit.panel, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label, style: k.t(7.5, font: k.bold, color: PdfKit.grey)),
            pw.Text(value, style: k.t(20, font: k.heavy)),
            if (sub.isNotEmpty) pw.Text(sub, style: k.t(8, color: PdfKit.grey)),
          ]),
        ),
      );

  final doc = pw.Document(title: 'Progress ${formatMonthYear(r.month)}', author: gym.settings.gymName);
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.all(26),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      k.header(gym.settings, 'Progress report', subtitle: '${m.name} · ${memberCode(m.number)} · ${formatMonthYear(r.month)}'),
      pw.Row(children: [
        tile('Workouts', '${r.visits}', sub: r.previousVisits > 0 ? '${r.visits - r.previousVisits >= 0 ? '+' : ''}${r.visits - r.previousVisits} vs last month' : ''),
        tile('Best streak', '${r.bestStreak}', sub: 'days in a row'),
        tile('Weight', r.lastWeight == null ? '—' : r.lastWeight!.weightKg.toStringAsFixed(1), sub: change == null ? 'kg' : 'kg · ${change <= 0 ? '' : '+'}${change.toStringAsFixed(1)}'),
      ]),
      pw.SizedBox(height: 12),
      pw.Text('Visits by week', style: k.t(8, font: k.bold, color: PdfKit.grey)),
      pw.SizedBox(height: 6),
      pw.SizedBox(
        height: 70,
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          for (var i = 0; i < r.weeklyVisits.length; i++)
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                  pw.Text('${r.weeklyVisits[i]}', style: k.t(8, font: k.bold)),
                  pw.Container(height: 48 * r.weeklyVisits[i] / peak + 2, color: PdfKit.red),
                  pw.Text('Wk ${i + 1}', style: k.t(7, color: PdfKit.grey)),
                ]),
              ),
            ),
        ]),
      ),
      pw.SizedBox(height: 12),
      for (final (label, value) in [
        if (r.ptSessions > 0) ('Personal training', '${r.ptSessions} sessions'),
        if (r.classes.isNotEmpty) ('Classes', r.classes.map((c) => c.title).join(', ')),
        if (r.workoutPlan != null) ('Workout plan', r.workoutPlan!.name),
        if (r.dietPlan != null) ('Diet plan', r.dietPlan!.name),
        ('Membership', r.daysLeft >= 0 ? 'Valid till ${formatDate(m.endDate)}' : 'Ended ${formatDate(m.endDate)}'),
      ])
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(children: [
            pw.SizedBox(width: 110, child: pw.Text(label, style: k.t(9.5, color: PdfKit.grey))),
            pw.Expanded(child: pw.Text(value, style: k.t(9.5, font: k.bold))),
          ]),
        ),
      pw.Spacer(),
      pw.Center(child: pw.Text('Keep showing up. See you at the gym!', style: k.t(11, font: k.bold, color: PdfKit.red))),
    ]),
  ));
  return doc.save();
}

Future<void> sharePlanPdf(BuildContext context, TrainingPlan plan, {Member? member}) async {
  final gym = context.read<GymProvider>();
  try {
    final bytes = await buildPlanPdf(gym, plan, member: member);
    final who = member == null ? '' : '-${member.firstName}';
    await Printing.sharePdf(bytes: bytes, filename: '${plan.name.replaceAll(' ', '-')}$who.pdf', subject: plan.name);
  } catch (_) {
    if (context.mounted) showMessage(context, 'Could not create the PDF on this device.');
  }
}

Future<void> shareProgressPdf(BuildContext context, Member member) async {
  final gym = context.read<GymProvider>();
  try {
    final bytes = await buildProgressPdf(gym, member.id);
    await Printing.sharePdf(bytes: bytes, filename: 'Progress-${member.firstName}-${formatShortMonth(gym.reportMonth)}.pdf', subject: 'Progress report');
  } catch (_) {
    if (context.mounted) showMessage(context, 'Could not create the PDF on this device.');
  }
}
