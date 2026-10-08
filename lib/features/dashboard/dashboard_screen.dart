
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../desk/close_day_screen.dart';
import '../desk/day_pass_sheet.dart';
import '../shop/shop_screen.dart';
import '../training/pt_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/pin_pad.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../device/device_service.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../admission/admission_screen.dart';
import '../device/device_screen.dart';
import '../enquiries/enquiries_screen.dart';
import '../enquiries/enquiry_sheet.dart';
import '../members/member_profile_screen.dart';
import '../money/expenses_screen.dart';
import '../money/payment_sheet.dart';
import '../more/classes_screen.dart';
import '../reports/revenue_screen.dart';
import '../shell/app_shell.dart';
import '../shell/shell_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _scroll = ScrollController();
  final _barShown = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _barShown.value = _scroll.offset > 120);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _barShown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final wide = MediaQuery.sizeOf(context).width >= AppShell.wideBreakpoint;

    final left = <Widget>[
      if (!gym.hasMembers) const _WelcomeCard() else const _TodayHero(),
      const SizedBox(height: 14),
      const _KpiGrid(),
      if (gym.hasMembers) const ScrollReveal(child: _ReminderCta()),
      if (gym.hasMembers) ...[
        const SectionHeader('Rush hours today'),
        const ScrollReveal(child: _RushHours()),
      ],
      const SectionHeader('Quick actions'),
      const ScrollReveal(child: _QuickActions()),
    ];
    final right = <Widget>[
      if (gym.hasMembers) ...[
        if (!wide) const SectionHeader('Income') else const SizedBox(height: 0),
        const ScrollReveal(child: _IncomeCard()),
      ],
      const SectionHeader("Today's classes"),
      const ScrollReveal(child: _TodayClasses()),
      if (gym.hasMembers) ...[
        const SectionHeader('Live at the desk'),
        const ScrollReveal(child: _ActivityFeed()),
      ],
    ];

    if (wide) {
      return ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        children: [
          const _Header(showBrand: false),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
              const SizedBox(width: 22),
              Expanded(flex: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
            ],
          ),
        ],
      );
    }
    return Stack(
      children: [
        ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 130),
          children: [
            const _Header(showBrand: true),
            const SizedBox(height: 18),
            ...left,
            ...right,
          ],
        ),
        // A compact bar fades in once the big header has scrolled away.
        ValueListenableBuilder<bool>(
          valueListenable: _barShown,
          builder: (context, shown, _) => AnimatedSlide(
            offset: shown ? Offset.zero : const Offset(0, -1.2),
            duration: Motion.medium,
            curve: Motion.settle,
            child: AnimatedOpacity(opacity: shown ? 1 : 0, duration: Motion.fast, child: const _CompactBar()),
          ),
        ),
      ],
    );
  }
}

class _CompactBar extends StatelessWidget {
  const _CompactBar();

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: const BoxDecoration(color: AppColors.background, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        const BrandLogo(height: 26),
        const SizedBox(width: 10),
        Text('${formatWeekday(gym.now)} ${gym.now.day}', style: AppText.headline.copyWith(fontSize: 16)),
        const Spacer(),
        Text('${gym.checkInsToday.length} in today', style: AppText.small),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  final bool showBrand;

  const _Header({required this.showBrand});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final hour = gym.now.hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showBrand) Expanded(child: Align(alignment: Alignment.centerLeft, child: BrandHeader(branch: gym.settings.branchName))) else const Spacer(),
            if (gym.settings.demoData) const Tooltip(message: 'Fictional members. Messages and calls are switched off.', child: StatusPill('Demo data', color: AppColors.warning)),
            if (gym.settings.hasPin)
              IconButton(
                tooltip: gym.ownerUnlocked ? 'Lock owner areas' : 'Unlock owner areas',
                onPressed: () => gym.ownerUnlocked ? gym.lock() : ensureOwner(context),
                icon: Icon(gym.ownerUnlocked ? AppIcons.lockOpen : AppIcons.lock, color: AppColors.textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Text('$greeting, ${gym.settings.ownerName}', style: AppText.bodyMuted),
        const SizedBox(height: 2),
        Text('${formatWeekday(gym.now)} ${gym.now.day} ${formatMonthYear(gym.now).split(' ').first}', style: AppText.display),
        const SizedBox(height: 10),
        const _DoorStatus(),
      ],
    );
  }
}

/// The Face ID door's state as a plate ring and a line of text; tap to open the device screen.
class _DoorStatus extends StatelessWidget {
  const _DoorStatus();

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final device = context.watch<DeviceService>();
    final ok = device.configured && device.error == null;
    final color = !device.configured ? AppColors.muted : (ok ? AppColors.success : AppColors.warning);
    final text = !device.configured ? 'Face ID door not connected' : (device.error != null ? 'Face ID door unreachable' : 'Face ID door ${syncAgo(gym.settings.lastDeviceSync, gym.now).toLowerCase()}');
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () async {
        if (await ensureOwner(context) && context.mounted) openPage(context, const DeviceScreen());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          PlateRing(color: color, size: 11),
          const SizedBox(width: 8),
          Text(text, style: AppText.small),
          if (device.busy) ...[const SizedBox(width: 8), const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.4))],
        ]),
      ),
    );
  }
}

/// Today's door entries by the hour against a usual day like today.
class _RushHours extends StatelessWidget {
  const _RushHours();

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final today = gym.hourlyToday();
    final usual = gym.usualHourly();
    var peak = 0;
    for (var i = 1; i < usual.length; i++) {
      if (usual[i] > usual[peak]) peak = i;
    }
    final peakHour = heatmapFirstHour + peak;
    final upcoming = peakHour > gym.now.hour;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                upcoming ? 'Usual rush at ${minutesLabel(peakHour * 60).replaceAll(':00', '')} · get the desk ready' : 'Busiest hour today was ${minutesLabel(peakHour * 60).replaceAll(':00', '')}',
                style: AppText.title.copyWith(fontSize: 15),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 14, children: [
            _Legend(color: AppColors.primaryBright, label: 'Today'),
            _Legend(color: AppColors.seriesCompare, label: 'Usual ${formatWeekday(gym.now)}', dashed: true),
          ]),
          const SizedBox(height: 10),
          RushHoursChart(today: today, usual: usual, firstHour: heatmapFirstHour, nowHour: gym.now.hour + gym.now.minute / 60),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _Legend({required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        dashed
            ? Row(children: [for (var i = 0; i < 3; i++) Container(width: 4, height: 2, margin: const EdgeInsets.only(right: 2), color: color)])
            : Container(width: 14, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: AppText.small.copyWith(fontSize: 11.5)),
      ]);
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    return AppCard(
      gradient: AppColors.redGradient,
      glow: true,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome to\nyour gym desk', style: AppText.display.copyWith(fontSize: 30, color: Colors.white)),
          const SizedBox(height: 10),
          const Text(
            'Register your first member to start tracking memberships, payments and attendance. Or load sample data to see the app in action.',
            style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, color: Colors.white70, height: 1.4, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDeep),
                  onPressed: () => openPage(context, const AdmissionScreen()),
                  child: const FittedBox(child: Text('New admission')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.transparent, side: const BorderSide(color: Colors.white54), minimumSize: const Size(0, 54)),
                  onPressed: gym.loadDemoData,
                  child: const Text('Load demo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () async {
                if (await ensureOwner(context) && context.mounted) openPage(context, const DeviceScreen());
              },
              icon: const Icon(AppIcons.faceId),
              label: const Text('Connect the Face ID door'),
            ),
          ),
        ],
      ),
    ).entrance(context, index: 1);
  }
}

/// The red hero card: who is in today, today's collection and the last two weeks of visits.
/// The door log: today's check-in count, and one tick for every entry across the gym's hours. The
/// ticks draw in left to right when the screen opens, the app's one orchestrated moment.
class _TodayHero extends StatelessWidget {
  const _TodayHero();

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final entries = [for (final c in gym.checkInsToday) c.time.hour + c.time.minute / 60];
    final recent = gym.recentlyIn();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      onTap: () => context.read<ShellController>().goTo(ShellTabs.checkIn),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('In today', style: AppText.label),
                    const SizedBox(height: 4),
                    CountUp(value: gym.checkInsToday.length, duration: const Duration(milliseconds: 900), style: AppText.stat.copyWith(fontSize: 52, letterSpacing: -2)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Collected', style: AppText.label),
                  const SizedBox(height: 4),
                  LockedValue(
                    locked: !gym.ownerUnlocked,
                    style: AppText.stat.copyWith(fontSize: 22),
                    child: Text(formatMoney(gym.incomeToday), style: AppText.stat.copyWith(fontSize: 22)),
                  ),
                  const SizedBox(height: 6),
                  Text(recent == 0 ? 'Quiet right now' : '$recent in the last 90 min', style: AppText.small),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          DoorLog(entries: entries, firstHour: heatmapFirstHour, lastHour: 23, nowHour: gym.now.hour + gym.now.minute / 60),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid();

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final shell = context.read<ShellController>();
    final tiles = [
      StatTile(
        icon: AppIcons.groups,
        color: AppColors.success,
        label: 'Active members',
        caption: '+${gym.newThisMonth} joined this month',
        value: CountUp(value: gym.activeCount),
        chart: Sparkline(values: gym.runningTrend(), color: AppColors.success, height: 30),
        onTap: () => shell.openMembers(const MemberFilter(status: MemberStatus.active)),
      ),
      StatTile(
        icon: AppIcons.hourglassLow,
        color: AppColors.warning,
        label: 'Expiring soon',
        caption: 'Within ${gym.settings.expiryAlertDays} days',
        value: CountUp(value: gym.expiringSoon.length),
        chart: MiniColumns(values: gym.endingPerDay(), color: AppColors.warning),
        onTap: () => shell.openReminders(ReminderKind.expiring),
      ),
      StatTile(
        icon: AppIcons.wallet,
        color: AppColors.ember,
        label: 'Pending dues',
        caption: '${gym.membersWithDue.length} members',
        value: CountUp(value: gym.totalDue, format: formatMoneyCompact),
        onTap: () => shell.openMembers(const MemberFilter(onlyDue: true)),
      ),
      StatTile(
        icon: AppIcons.support,
        color: AppColors.categorical[3],
        label: 'Follow-ups today',
        caption: '${gym.enquiriesWith(openOnly: true).length} open enquiries',
        value: CountUp(value: gym.followUpsDue.length),
        onTap: () => openPage(context, const EnquiriesScreen()),
      ),
    ];
    return LayoutBuilder(builder: (context, box) {
      // Four across on a tablet, two on a phone; tiles stay about 160 px tall either way.
      final columns = box.maxWidth > 600 ? 4 : 2;
      final width = (box.maxWidth - 12 * (columns - 1)) / columns;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: width / 118,
        children: [for (var i = 0; i < tiles.length; i++) tiles[i].entrance(context, index: i + 2)],
      );
    });
  }
}

/// The one-button reminder entry point: how many people need a message today.
class _ReminderCta extends StatelessWidget {
  const _ReminderCta();

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final count = gym.pendingReminderCount;
    final kinds = [for (final k in GymMessages.queueKinds) (k, gym.reminderQueue(k).length)].where((e) => e.$2 > 0).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: AppCard(
        onTap: () => context.read<ShellController>().openReminders(),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(AppIcons.send, color: count > 0 ? AppColors.text : AppColors.muted, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(count == 0 ? 'All caught up' : '$count reminders ready to send', style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    count == 0 ? 'Nobody needs a message right now.' : kinds.take(3).map((e) => '${e.$2} ${e.$1.label.toLowerCase()}').join(' · '),
                    style: AppText.small.copyWith(color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(AppIcons.chevronRight, color: AppColors.muted),
          ],
        ),
      ).entrance(context, index: 6),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final shell = context.read<ShellController>();
    final actions = [
      (AppIcons.personAdd, 'New\nadmission', AppColors.primary, () => openPage(context, const AdmissionScreen())),
      (AppIcons.checkIn, 'Check-in', AppColors.categorical[0], () => shell.goTo(ShellTabs.checkIn)),
      (AppIcons.rupee, 'Collect\npayment', AppColors.success, () => showCollectPayment(context)),
      (AppIcons.ticketOutline, 'Day pass\n& trial', AppColors.categorical[1], () => showDayPassSheet(context)),
      (AppIcons.bag, 'Shop\nsale', AppColors.ember, () => showSellSheet(context)),
      (AppIcons.trainer, 'PT\nsession', AppColors.categorical[0], () => openPage(context, const PtScreen())),
      (AppIcons.contact, 'New\nenquiry', AppColors.categorical[3], () => showEnquirySheet(context)),
      (AppIcons.receipt, 'Add\nexpense', AppColors.ember, () async {
        if (await ensureOwner(context) && context.mounted) showExpenseSheet(context);
      }),
      (AppIcons.closeDay, 'Close\nthe day', AppColors.whatsapp, () => openPage(context, const CloseDayScreen())),
    ];
    return LayoutBuilder(builder: (context, box) {
      final perRow = box.maxWidth > 720 ? 9 : 3;
      final w = (box.maxWidth - 10 * (perRow - 1)) / perRow;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < actions.length; i++)
            SizedBox(
              width: w,
              child: AppCard(
                onTap: actions[i].$4,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                radius: 20,
                child: Column(
                  children: [
                    IconBadge(actions[i].$1, color: actions[i].$3, size: 44, radius: 14),
                    const SizedBox(height: 10),
                    // Scales down instead of breaking a word when nine tiles share a tablet row.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(actions[i].$2, textAlign: TextAlign.center, style: AppText.small.copyWith(color: AppColors.text, fontWeight: FontWeight.w700, height: 1.15)),
                    ),
                  ],
                ),
              ).entrance(context, index: i + 7),
            ),
        ],
      );
    });
  }
}

/// This month's income against the target and the last six months, behind the owner PIN.
class _IncomeCard extends StatefulWidget {
  const _IncomeCard();

  @override
  State<_IncomeCard> createState() => _IncomeCardState();
}

class _IncomeCardState extends State<_IncomeCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final months = gym.monthlyStats(6);
    final selected = _selected ?? months.length - 1;
    final locked = !gym.ownerUnlocked;
    final target = gym.settings.monthlyTarget;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${formatMonthYear(gym.today)} so far', style: AppText.label),
                  const SizedBox(height: 6),
                  CountUp(value: gym.incomeThisMonth, format: formatMoney, style: AppText.display.copyWith(fontSize: 40)),
                  const SizedBox(height: 8),
                  ChangeChip(gym.incomeChangeToDate, suffix: 'vs last month'),
                  const SizedBox(height: 8),
                  Text('On track for ${formatMoneyCompact(gym.projectedIncome)} by month end', style: AppText.small.copyWith(color: AppColors.muted)),
                ],
              ),
            ),
            if (target > 0)
              ProgressRing(
                value: gym.targetProgress,
                size: 96,
                stroke: 9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(gym.targetProgress * 100).round()}%', style: AppText.headline.copyWith(fontSize: 22)),
                    Text('Of target', style: AppText.label.copyWith(fontSize: 8.5)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        RevenueBars(
          data: [for (final m in months) BarDatum(formatShortMonth(m.month), formatMonthYear(m.month), m.income)],
          selected: selected,
          onSelect: (i) => setState(() => _selected = i),
          target: target > 0 ? target : null,
          height: 200,
          semanticLabel: 'Income for the last 6 months. ${[for (final m in months) '${formatShortMonth(m.month)} ${formatMoney(m.income)}'].join(', ')}',
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: Motion.medium,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a), child: c)),
          child: _MonthDetail(key: ValueKey(selected), stats: months[selected], previous: selected > 0 ? months[selected - 1] : null),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => openPage(context, const RevenueScreen()), child: const Text('Full report')),
        ),
      ],
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 8),
      child: AnimatedSwitcher(
        duration: Motion.medium,
        child: locked
            ? SizedBox(
                key: const ValueKey('locked'),
                height: 150,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(AppIcons.lock, color: AppColors.muted, size: 30),
                    const SizedBox(height: 8),
                    const Text('Income is visible to the owner only', style: AppText.bodyMuted),
                    TextButton(onPressed: () => ensureOwner(context), child: const Text('Unlock with PIN')),
                  ],
                ),
              )
            : KeyedSubtree(key: const ValueKey('open'), child: content),
      ),
    ).entrance(context, index: 3);
  }
}

/// One month under the income bars: income, change, admissions and renewals.
class _MonthDetail extends StatelessWidget {
  final MonthStats stats;
  final MonthStats? previous;

  const _MonthDetail({super.key, required this.stats, this.previous});

  @override
  Widget build(BuildContext context) {
    Widget cell(String value, String label) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: AppText.headline.copyWith(fontSize: 18)),
            Text(label, style: AppText.label.copyWith(fontSize: 9)),
          ]),
        );
    final change = previous == null ? null : GymAnalytics.change(stats.income, previous!.income);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        cell(formatShortMonth(stats.month), formatMonthYear(stats.month).split(' ').last),
        cell(formatMoneyCompact(stats.income), change == null ? 'Income' : 'Income ${formatChange(change)}'),
        cell('${stats.admissions}', 'Joined'),
        cell('${stats.renewals}', 'Renewed'),
      ]),
    );
  }
}

class _TodayClasses extends StatelessWidget {
  const _TodayClasses();

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final list = gym.classesOn(gym.now.weekday);
    final nowMin = gym.now.hour * 60 + gym.now.minute;
    if (list.isEmpty) {
      return const AppCard(child: Row(children: [Icon(AppIcons.eventBusy, color: AppColors.muted), SizedBox(width: 12), Expanded(child: Text('No classes today.', style: AppText.bodyMuted))]));
    }
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = list[i];
          final live = nowMin >= c.startMinutes && nowMin < c.endMinutes;
          final done = nowMin >= c.endMinutes;
          return SizedBox(
            width: 172,
            child: AppCard(
              onTap: () => openPage(context, const ClassesScreen()),
              borderColor: live ? AppColors.text : null,
              padding: const EdgeInsets.all(14),
              child: Opacity(
                opacity: done ? 0.5 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBadge(c.type.icon, color: c.type.color, size: 34, radius: 11),
                        const Spacer(),
                        if (live) const StatusPill('Live', color: AppColors.success) else if (done) const StatusPill('Done', color: AppColors.muted),
                      ],
                    ),
                    const Spacer(),
                    Text(minutesLabel(c.startMinutes), style: AppText.headline.copyWith(fontSize: 20)),
                    Text(c.title, style: AppText.small.copyWith(color: AppColors.text, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(gym.trainerById(c.trainerId)?.name ?? '${c.durationMin} min', style: AppText.small.copyWith(color: AppColors.muted, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ).entrance(context, index: i),
          );
        },
      ),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed();

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final items = gym.recentActivity(7);
    if (items.isEmpty) return const AppCard(child: Text('Nothing yet today.', style: AppText.bodyMuted));
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _ActivityRow(item: items[i], last: i == items.length - 1, locked: !gym.ownerUnlocked).entrance(context, index: i),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityItem item;
  final bool last;
  final bool locked;

  const _ActivityRow({required this.item, required this.last, required this.locked});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final (icon, color) = switch (item.kind) {
      ActivityKind.checkIn => (AppIcons.login, AppColors.categorical[0]),
      ActivityKind.payment => (AppIcons.rupee, AppColors.success),
      ActivityKind.admission => (AppIcons.personAdd, AppColors.primary),
      ActivityKind.enquiry => (AppIcons.contact, AppColors.categorical[3]),
    };
    final when = sameDay(item.time, gym.today) ? formatTime(item.time) : relativeDay(item.time, gym.today);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: item.memberId == null || gym.memberById(item.memberId) == null ? null : () => openPage(context, MemberProfileScreen(memberId: item.memberId!)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            IconBadge(icon, color: color, size: 36, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppText.body.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(item.subtitle, style: AppText.small.copyWith(color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.amount != null) Text(locked ? '₹ ••' : formatMoney(item.amount!), style: AppText.number.copyWith(color: AppColors.success)),
                Text(when, style: AppText.small.copyWith(color: AppColors.muted, fontSize: 11.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
