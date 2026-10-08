import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/member_widgets.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../reminders/reminder_runner.dart';
import 'member_pdfs.dart';

/// Monthly progress reports: workouts, streak and weight for each active member, sent on WhatsApp
/// one after another or shared as a PDF.
class ProgressReportsScreen extends StatelessWidget {
  const ProgressReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final month = gym.reportMonth;
    final members = gym.progressReportMembers();
    final reports = [for (final m in members) gym.progressReport(m.id)]..sort((a, b) => b.visits.compareTo(a.visits));
    final pending = gym.reminderQueue(ReminderKind.progress).length;
    final avg = reports.isEmpty ? 0.0 : reports.fold(0, (s, r) => s + r.visits) / reports.length;

    return SubPage(
      title: 'Progress reports',
      subtitle: '${formatMonthYear(month)}${sameMonth(month, gym.today) ? ' so far' : ''} · ${members.length} active members',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          AppCard(
            gradient: AppColors.redGradient,
            glow: true,
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ready to send', style: AppText.label.copyWith(color: Colors.white70)),
              CountUp(value: pending.toDouble(), style: AppText.stat.copyWith(color: Colors.white, fontSize: 46)),
              Text('${(members.length - pending).clamp(0, members.length)} already sent · ${avg.toStringAsFixed(1)} workouts per member on average', style: AppText.small.copyWith(color: Colors.white)),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                onPressed: pending == 0 ? null : () => runReminderQueue(context, ReminderKind.progress),
                icon: const Icon(AppIcons.send),
                label: Text(pending == 0 ? 'All sent' : 'Send all on WhatsApp'),
              ),
            ]),
          ).entrance(context),
          if (reports.isNotEmpty) ...[
            const SectionHeader('Most consistent'),
            AppCard(child: RankedBars(items: [for (final r in reports.take(5)) (r.member.name, r.visits.toDouble(), '${r.visits} visits')], color: AppColors.categorical[2])),
          ],
          const SectionHeader('Members'),
          if (reports.isEmpty) const EmptyState(icon: AppIcons.insights, title: 'No visits yet', subtitle: 'Reports appear once members check in this month.'),
          for (var i = 0; i < reports.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReportTile(report: reports[i], sent: gym.remindedRecently(reports[i].member.id, ReminderKind.progress)),
            ).entrance(context, index: i < 12 ? i + 1 : 12),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final ProgressReport report;
  final bool sent;

  const _ReportTile({required this.report, required this.sent});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final r = report;
    final change = r.weightChange;
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(children: [
        MemberAvatar(member: r.member, size: 42, hero: false),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.member.name, style: AppText.body.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            SizedBox(height: 18, child: MiniColumns(values: [for (final v in r.weeklyVisits) v.toDouble()], color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(
              [
                '${r.visits} workouts',
                if (r.bestStreak > 1) '${r.bestStreak}-day streak',
                if (change != null) '${change <= 0 ? '' : '+'}${change.toStringAsFixed(1)} kg',
              ].join(' · '),
              style: AppText.small.copyWith(color: AppColors.muted),
            ),
          ]),
        ),
        AnimatedSwitcher(
          duration: Motion.fast,
          child: sent ? const Padding(padding: EdgeInsets.only(right: 4), child: Icon(AppIcons.doneAll, color: AppColors.success, size: 20)) : const SizedBox.shrink(),
        ),
        IconButton(tooltip: 'Share PDF', icon: const Icon(AppIcons.pdf, color: AppColors.muted), onPressed: () => shareProgressPdf(context, r.member)),
        IconButton(
          tooltip: 'Send on WhatsApp',
          icon: const Icon(AppIcons.chat, color: AppColors.whatsapp),
          onPressed: () async {
            final ok = await openWhatsApp(context, r.member.phone, gym.progressText(r));
            if (ok) await gym.logReminder(ReminderKind.progress, r.member.id);
          },
        ),
      ]),
    );
  }
}
