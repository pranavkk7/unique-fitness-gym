import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/utils/photo.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/member_widgets.dart';
import '../../core/widgets/pin_pad.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../device/face_id_sheet.dart';
import '../engagement/feedback_screen.dart';
import '../engagement/member_pdfs.dart';
import '../engagement/training_plans_screen.dart';
import '../more/class_roster_screen.dart';
import '../shop/shop_screen.dart';
import '../training/pt_screen.dart';
import '../money/payment_sheet.dart';
import 'freeze_sheet.dart';
import 'measurement_sheet.dart';
import 'plan_picker.dart';
import 'member_edit_screen.dart';
import 'renew_sheet.dart';

class MemberProfileScreen extends StatelessWidget {
  final String memberId;

  const MemberProfileScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final m = gym.memberById(memberId);
    if (m == null) {
      return const SubPage(title: 'Member', child: EmptyState(icon: Icons.person_off_rounded, title: 'Member not found', subtitle: 'They may have been deleted.'));
    }
    return SubPage(
      title: m.firstName,
      subtitle: memberCode(m.number),
      actions: [
        IconButton(tooltip: 'Edit details', icon: const Icon(Icons.edit_rounded), onPressed: () => openPage(context, MemberEditScreen(memberId: m.id))),
        _MoreMenu(member: m),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          _Header(member: m),
          const SizedBox(height: 18),
          _ContactActions(member: m).entrance(context, index: 1),
          const SizedBox(height: 14),
          _MembershipCard(member: m).entrance(context, index: 2),
          if (m.balanceDue > 0) ...[const SizedBox(height: 12), _DueBanner(member: m).entrance(context, index: 3)],
          const SectionHeader('Attendance'),
          _Attendance(member: m).entrance(context, index: 3),
          SectionHeader('Body progress', actionLabel: 'Add check', onAction: () => showMeasurementSheet(context, m)),
          _Progress(member: m).entrance(context, index: 4),
          PtProfileSection(member: m),
          TrainingPlansSection(member: m),
          _Community(member: m),
          const SectionHeader('Details'),
          _Details(member: m).entrance(context, index: 5),
          const SectionHeader('Membership history'),
          _History(member: m),
          const SectionHeader('Payments'),
          _Payments(member: m),
        ],
      ),
    );
  }
}

/// Class batches and referrals: who brought them in, and who they brought.
class _Community extends StatelessWidget {
  final Member member;

  const _Community({required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final classes = gym.classesOf(member.id);
    final referrer = gym.memberById(member.referredById);
    final referrals = gym.referralsBy(member.id);
    if (classes.isEmpty && referrer == null && referrals.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Classes & referrals'),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (final c in classes)
            ListTile(
              onTap: () => openPage(context, ClassRosterScreen(classId: c.id)),
              leading: IconBadge(c.type.icon, color: c.type.color, size: 38),
              title: Text(c.title),
              subtitle: Text('${minutesLabel(c.startMinutes)} · ${c.memberIds.length}/${c.capacity} in the batch'),
            ),
          if (referrer != null)
            ListTile(
              onTap: () => openPage(context, MemberProfileScreen(memberId: referrer.id)),
              leading: IconBadge(Icons.call_received_rounded, color: AppColors.categorical[2], size: 38),
              title: Text('Referred by ${referrer.name}'),
              subtitle: Text(memberCode(referrer.number)),
            ),
          if (referrals.isNotEmpty)
            ListTile(
              leading: IconBadge(Icons.card_giftcard_rounded, color: AppColors.categorical[2], size: 38),
              title: Text('Brought ${referrals.length} ${referrals.length == 1 ? 'friend' : 'friends'}'),
              subtitle: Text(referrals.map((r) => r.firstName).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: gym.settings.referralRewardDays > 0 ? Text('+${referrals.length * gym.settings.referralRewardDays}d', style: AppText.number.copyWith(color: AppColors.success)) : null,
            ),
        ]),
      ),
    ]);
  }
}

class _MoreMenu extends StatelessWidget {
  final Member member;

  const _MoreMenu({required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final frozen = gym.statusOf(member) == MemberStatus.frozen;
    return PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: (v) async {
        switch (v) {
          case 'freeze':
            showFreezeSheet(context, member);
          case 'unfreeze':
            await gym.unfreeze(member.id);
            if (context.mounted) showMessage(context, 'Membership running again. New end date ${formatDate(gym.memberById(member.id)!.endDate)}.');
          case 'measure':
            showMeasurementSheet(context, member);
          case 'face':
            showFaceIdSheet(context, member);
          case 'sale':
            showSellSheet(context, member: member);
          case 'pt':
            showSellPtSheet(context, member: member);
          case 'report':
            shareProgressPdf(context, member);
          case 'feedback':
            showFeedbackSheet(context, member: member);
          case 'delete':
            if (!await ensureOwner(context, reason: 'Deleting a member needs the owner PIN.') || !context.mounted) return;
            final ok = await confirmAction(context,
                title: 'Delete ${member.firstName}?',
                message: 'Their details, photo, visits and body checks are removed. Payments stay in the accounts so past income does not change.');
            if (ok && context.mounted) {
              Navigator.pop(context);
              await gym.deleteMember(member.id);
            }
        }
      },
      itemBuilder: (_) => [
        if (frozen)
          const PopupMenuItem(value: 'unfreeze', child: ListTile(leading: Icon(Icons.play_arrow_rounded), title: Text('End freeze'), contentPadding: EdgeInsets.zero))
        else if (gym.isRunning(member))
          const PopupMenuItem(value: 'freeze', child: ListTile(leading: Icon(Icons.ac_unit_rounded), title: Text('Freeze membership'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'measure', child: ListTile(leading: Icon(Icons.monitor_weight_rounded), title: Text('Add body check'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'face', child: ListTile(leading: Icon(Icons.face_retouching_natural_rounded), title: Text('Face ID'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'pt', child: ListTile(leading: Icon(Icons.sports_rounded), title: Text('Sell PT package'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'sale', child: ListTile(leading: Icon(Icons.shopping_bag_rounded), title: Text('Shop sale'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'report', child: ListTile(leading: Icon(Icons.insights_rounded), title: Text('Progress report PDF'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'feedback', child: ListTile(leading: Icon(Icons.rate_review_rounded), title: Text('Note feedback'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline_rounded, color: AppColors.danger), title: Text('Delete member'), contentPadding: EdgeInsets.zero)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Member member;

  const _Header({required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final style = StatusStyle.of(gym, member);
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: style.color.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: -6)]),
              child: MemberAvatar(member: member, size: 118),
            ),
            Positioned(
              right: -2,
              bottom: 2,
              child: Material(
                color: AppColors.primary,
                shape: const CircleBorder(side: BorderSide(color: AppColors.background, width: 3)),
                child: IconButton(
                  tooltip: member.hasPhoto ? 'Change photo' : 'Add photo',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.photo_camera_rounded, color: Colors.white),
                  onPressed: () async {
                    final bytes = await pickMemberPhoto(context, allowRemove: member.hasPhoto);
                    if (bytes == null) return;
                    await gym.setPhoto(member.id, bytes.isEmpty ? null : bytes);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(member.name.toUpperCase(), style: AppText.display.copyWith(fontSize: 30), textAlign: TextAlign.center).entrance(context),
        const SizedBox(height: 6),
        Text('${memberCode(member.number)}  ·  ${member.phone}', style: AppText.small.copyWith(color: AppColors.muted)),
        const SizedBox(height: 10),
        StatusPill(style.label, color: style.color, icon: style.icon),
      ],
    );
  }
}

class _ContactActions extends StatelessWidget {
  final Member member;

  const _ContactActions({required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    Widget action(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: AppCard(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(vertical: 13),
            radius: 18,
            child: Column(children: [Icon(icon, color: color), const SizedBox(height: 6), Text(label, style: AppText.small.copyWith(color: AppColors.text, fontWeight: FontWeight.w700))]),
          ),
        );
    return Row(
      children: [
        action(Icons.call_rounded, 'Call', AppColors.textSecondary, () => callNumber(context, member.phone)),
        const SizedBox(width: 10),
        action(Icons.chat_rounded, 'WhatsApp', AppColors.whatsapp, () => _pickMessage(context, gym)),
        const SizedBox(width: 10),
        action(
          Icons.face_retouching_natural_rounded,
          member.faceEnrolled ? 'Face ID' : 'Add Face ID',
          member.faceEnrolled ? (gym.doorAccessAllowed(member) ? AppColors.success : AppColors.danger) : AppColors.warning,
          () => showFaceIdSheet(context, member),
        ),
      ],
    );
  }

  /// Choose which message to send: the app picks sensible ones for this member's situation.
  Future<void> _pickMessage(BuildContext context, GymProvider gym) async {
    final status = gym.statusOf(member);
    final kinds = [
      if (status == MemberStatus.expiringSoon) ReminderKind.expiring,
      if (status == MemberStatus.expired) ReminderKind.expired,
      if (member.balanceDue > 0) ReminderKind.due,
      if (gym.birthdaysToday.contains(member)) ReminderKind.birthday,
      if (gym.inactiveMembers.contains(member)) ReminderKind.inactive,
      if (gym.progressReportMembers().contains(member)) ReminderKind.progress,
      ReminderKind.welcome,
    ];
    final kind = await showAppSheet<ReminderKind?>(
      context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader('Message ${member.firstName}', subtitle: 'Opens WhatsApp with the message ready. You press send.'),
              for (final k in kinds)
                ListTile(
                  leading: IconBadge(k.icon, color: k.color, size: 38),
                  title: Text(k.label),
                  subtitle: Text(gym.messageFor(k, member), maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(sheetContext, k),
                ),
              ListTile(
                leading: const IconBadge(Icons.edit_note_rounded, color: AppColors.textSecondary, size: 38),
                title: const Text('Blank message'),
                onTap: () => Navigator.pop(sheetContext, null),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    final opened = await openWhatsApp(context, member.phone, kind == null ? '' : gym.messageFor(kind, member));
    if (opened && kind != null && kind != ReminderKind.welcome) await gym.logReminder(kind, member.id);
  }
}

class _MembershipCard extends StatelessWidget {
  final Member member;

  const _MembershipCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final style = StatusStyle.of(gym, member);
    final left = gym.daysLeft(member);
    final plan = gym.planById(member.planId);
    final freeze = member.freezeOn(gym.today);
    return AppCard(
      padding: const EdgeInsets.all(18),
      borderColor: style.color.withValues(alpha: 0.3),
      child: Column(
        children: [
          Row(
            children: [
              ProgressRing(
                value: 1 - gym.progressOf(member),
                size: 108,
                stroke: 10,
                color: style.color,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${left.abs()}', style: AppText.display.copyWith(fontSize: 34)),
                    Text(left < 0 ? 'DAYS AGO' : (left == 1 ? 'DAY LEFT' : 'DAYS LEFT'), style: AppText.label.copyWith(fontSize: 9)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT PLAN', style: AppText.label.copyWith(fontSize: 10.5)),
                    const SizedBox(height: 4),
                    if (plan != null && plan.tier != PlanTier.other)
                      TierText(plan.name, tier: plan.tier, style: AppText.headline.copyWith(fontSize: 26))
                    else
                      Text(plan?.name ?? 'No plan', style: AppText.headline.copyWith(fontSize: 26)),
                    const SizedBox(height: 6),
                    Text('${formatDate(member.startDate)}  –  ${formatDate(member.endDate)}', style: AppText.small),
                    if (freeze != null) ...[
                      const SizedBox(height: 8),
                      StatusPill('Frozen till ${formatDayMonth(freeze.end)}', color: AppColors.frozen, icon: Icons.ac_unit_rounded),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showRenewSheet(context, member),
                  icon: const Icon(Icons.autorenew_rounded),
                  label: const Text('RENEW'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
                  onPressed: () => showCollectPayment(context, member: member),
                  icon: const Icon(Icons.currency_rupee_rounded),
                  label: const Text('PAYMENT'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DueBanner extends StatelessWidget {
  final Member member;

  const _DueBanner({required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    return AppCard(
      color: AppColors.danger.withValues(alpha: 0.1),
      borderColor: AppColors.danger.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(child: Text('${formatMoney(member.balanceDue)} balance due', style: AppText.title.copyWith(color: AppColors.danger, fontSize: 15.5))),
          TextButton(
            onPressed: () async {
              final ok = await openWhatsApp(context, member.phone, gym.messageFor(ReminderKind.due, member));
              if (ok) await gym.logReminder(ReminderKind.due, member.id);
            },
            child: const Text('Remind'),
          ),
          TextButton(onPressed: () => showCollectPayment(context, member: member, amount: member.balanceDue), child: const Text('Collect')),
        ],
      ),
    );
  }
}

class _Attendance extends StatelessWidget {
  final Member member;

  const _Attendance({required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final last = gym.lastVisit(member.id);
    final today = gym.checkedInToday(member.id);
    final weeks = gym.weeklyVisits(member.id);
    Widget stat(String value, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(value, style: AppText.headline.copyWith(fontSize: 22)), Text(label.toUpperCase(), style: AppText.label.copyWith(fontSize: 9.5))],
          ),
        );
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              stat('${gym.visitsInLast(member.id, 30)}', 'Visits, 30 days'),
              stat(last == null ? '-' : relativeDay(last, gym.today), 'Last visit'),
              stat('${(gym.today.difference(member.joinDate).inDays / 30).floor()} mo', 'Member for'),
            ],
          ),
          const SizedBox(height: 16),
          WeekColumns(counts: weeks),
          const SizedBox(height: 6),
          Row(children: [Text('12 WEEKS AGO', style: AppText.label.copyWith(fontSize: 9)), const Spacer(), Text('THIS WEEK', style: AppText.label.copyWith(fontSize: 9))]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: today
                ? const StatusPill('Checked in today', color: AppColors.success, icon: Icons.check_circle_rounded)
                : OutlinedButton.icon(
                    onPressed: () async {
                      final r = await gym.checkIn(member.id, allowExpired: true);
                      if (context.mounted) showMessage(context, r == CheckInOutcome.recorded ? '${member.firstName} checked in.' : 'Already checked in today.');
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('CHECK IN NOW'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final Member member;

  const _Progress({required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final list = gym.measurementsFor(member.id);
    if (list.length < 2) {
      return AppCard(
        onTap: () => showMeasurementSheet(context, member),
        child: Row(
          children: [
            IconBadge(Icons.monitor_weight_rounded, color: AppColors.categorical[2]),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                list.isEmpty ? 'No body checks yet. Add weight and measurements to track progress.' : 'One check so far (${list.first.weightKg} kg). Add another to see the trend.',
                style: AppText.bodyMuted,
              ),
            ),
            const Icon(Icons.add_rounded, color: AppColors.muted),
          ],
        ),
      );
    }
    final first = list.first.weightKg, last = list.last.weightKg;
    final diff = last - first;
    // Whole-number axis with clean steps, so labels never collide.
    final low = list.map((w) => w.weightKg).reduce((a, b) => a < b ? a : b);
    final high = list.map((w) => w.weightKg).reduce((a, b) => a > b ? a : b);
    final step = niceStep(high - low + 2, 3);
    final minY = ((low - 1) / step).floor() * step;
    final maxY = ((high + 1) / step).ceil() * step;
    final goodDirection = member.goal == 'Weight loss' ? diff <= 0 : diff >= 0;
    return AppCard(
      onTap: () => showMeasurementSheet(context, member),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${last.toStringAsFixed(1)} kg', style: AppText.headline.copyWith(fontSize: 26)),
              const SizedBox(width: 10),
              StatusPill('${diff >= 0 ? '+' : '−'}${diff.abs().toStringAsFixed(1)} kg since ${formatShortMonth(list.first.date)}',
                  color: goodDirection ? AppColors.success : AppColors.warning, icon: diff <= 0 ? Icons.south_east_rounded : Icons.north_east_rounded),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 140,
            child: LineChart(
              duration: Motion.chart,
              curve: Motion.settle,
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(drawVerticalLine: false, horizontalInterval: step, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: step, getTitlesWidget: (v, meta) => SideTitleWidget(meta: meta, child: Text(v.toStringAsFixed(0), style: AppText.small.copyWith(fontSize: 10.5, color: AppColors.muted))))),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) => v != v.roundToDouble() || v < 0 || v >= list.length
                          ? const SizedBox.shrink()
                          : SideTitleWidget(meta: meta, child: Text(formatShortMonth(list[v.toInt()].date).toUpperCase(), style: AppText.label.copyWith(fontSize: 9))),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceHigher,
                    getTooltipItems: (spots) => [for (final s in spots) LineTooltipItem('${s.y.toStringAsFixed(1)} kg\n', AppText.number, children: [TextSpan(text: formatDate(list[s.x.toInt()].date), style: AppText.small)])],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < list.length; i++) FlSpot(i.toDouble(), list[i].weightKg)],
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: AppColors.categorical[2],
                    barWidth: 2.5,
                    dotData: FlDotData(getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 4, color: AppColors.categorical[2], strokeWidth: 2, strokeColor: AppColors.surface)),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.categorical[2].withValues(alpha: 0.25), AppColors.categorical[2].withValues(alpha: 0)]),
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
}

class _Details extends StatelessWidget {
  final Member member;

  const _Details({required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final dob = member.dateOfBirth;
    final age = dob == null ? null : (gym.today.difference(dob).inDays / 365.25).floor();
    return DetailCard(children: [
      InfoRow(icon: Icons.call_rounded, label: 'Phone', value: member.phone),
      if (member.email.isNotEmpty) InfoRow(icon: Icons.mail_rounded, label: 'Email', value: member.email),
      InfoRow(icon: Icons.cake_rounded, label: 'Birthday', value: dob == null ? '' : '${formatDate(dob)} ($age)'),
      InfoRow(icon: Icons.wc_rounded, label: 'Gender', value: member.gender.label),
      InfoRow(icon: Icons.flag_rounded, label: 'Goal', value: member.goal),
      InfoRow(icon: Icons.sports_rounded, label: 'Trainer', value: gym.trainerById(member.trainerId)?.name ?? 'None'),
      InfoRow(
        icon: Icons.straighten_rounded,
        label: 'Body',
        value: [
          if (member.heightCm != null) '${member.heightCm!.round()} cm',
          if (member.weightKg != null) '${member.weightKg!.toStringAsFixed(1)} kg',
          if (member.bmi != null) 'BMI ${member.bmi!.toStringAsFixed(1)}',
        ].join(' · '),
      ),
      if (member.medicalNotes.isNotEmpty) InfoRow(icon: Icons.medical_information_rounded, label: 'Health notes', value: member.medicalNotes),
      InfoRow(icon: Icons.emergency_rounded, label: 'Emergency', value: [member.emergencyName, member.emergencyPhone].where((s) => s.isNotEmpty).join(' · ')),
      if (member.address.isNotEmpty) InfoRow(icon: Icons.home_rounded, label: 'Address', value: member.address),
      InfoRow(
        icon: Icons.face_retouching_natural_rounded,
        label: 'Face ID',
        value: member.deviceUserId == null
            ? 'Not registered'
            : '${member.faceEnrolled ? 'Registered' : 'On the device, face pending'} · ID ${member.deviceUserId}${gym.doorAccessAllowed(member) ? '' : ' · blocked at the door'}',
      ),
      InfoRow(icon: Icons.campaign_rounded, label: 'Heard via', value: member.source.label),
      InfoRow(icon: Icons.event_rounded, label: 'Joined', value: formatDate(member.joinDate)),
      if (member.notes.isNotEmpty) InfoRow(icon: Icons.notes_rounded, label: 'Notes', value: member.notes),
    ]);
  }
}

class _History extends StatelessWidget {
  final Member member;

  const _History({required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final subs = gym.subscriptionsFor(member.id);
    if (subs.isEmpty) return const AppCard(child: Text('No memberships recorded.', style: AppText.bodyMuted));
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        children: [
          for (var i = 0; i < subs.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timeline rail with a dot per membership.
                  SizedBox(
                    width: 22,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == 0 ? AppColors.primary : AppColors.surfaceHigher,
                            border: Border.all(color: i == 0 ? AppColors.primaryBright : AppColors.borderStrong, width: 2),
                          ),
                        ),
                        if (i < subs.length - 1) Expanded(child: Container(width: 2, color: AppColors.border)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('${subs[i].planName} · ${subs[i].kind.label}', style: AppText.body.copyWith(fontWeight: FontWeight.w700))),
                              Text(gym.ownerUnlocked ? formatMoney(subs[i].amount) : '₹ ••', style: AppText.number.copyWith(fontSize: 14)),
                            ],
                          ),
                          Text(
                            '${formatDate(subs[i].start)} – ${formatDate(subs[i].end)}${subs[i].discount > 0 ? '  ·  ${formatMoney(subs[i].discount)} off' : ''}',
                            style: AppText.small.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Payments extends StatelessWidget {
  final Member member;

  const _Payments({required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final payments = gym.paymentsFor(member.id);
    if (payments.isEmpty) return const AppCard(child: Text('No payments yet.', style: AppText.bodyMuted));
    // One row per receipt (an admission has a fee line and a plan line on one receipt).
    final receipts = <String, List<Payment>>{};
    for (final p in payments) {
      receipts.putIfAbsent(p.receiptNo, () => []).add(p);
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final e in receipts.entries)
            ListTile(
              leading: IconBadge(e.value.first.method.icon, color: AppColors.success, size: 38),
              title: Text(gym.ownerUnlocked || sameDay(e.value.first.date, gym.today) ? formatMoney(e.value.fold(0.0, (s, p) => s + p.amount)) : '₹ ••', style: AppText.number),
              subtitle: Text('${e.key} · ${formatDate(e.value.first.date)}\n${e.value.map((p) => p.note.isEmpty ? p.kind.label : p.note).join(' + ')}', style: AppText.small.copyWith(color: AppColors.muted)),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Share receipt',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () => showReceiptActions(context, e.key),
              ),
            ),
        ],
      ),
    );
  }
}
