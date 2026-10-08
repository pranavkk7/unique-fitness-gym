import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/pin_pad.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';

/// The owner's money and growth report. Touch or drag across the bars to pick a month; every
/// card below follows the chosen month.
class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  int _selected = 11;
  bool _compare = false;

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    if (!gym.ownerUnlocked) {
      return SubPage(
        title: 'Revenue',
        child: EmptyState(icon: AppIcons.lock, title: 'Owner only', subtitle: 'Income and expenses need the owner PIN.', actionLabel: 'Unlock', onAction: () => ensureOwner(context)),
      );
    }
    final months = gym.monthlyStats(12);
    final yoy = gym.yearOverYear();
    final sel = months[_selected];
    final prev = _selected > 0 ? months[_selected - 1] : gym.statsFor(gym.monthsAgo(12));
    final isCurrent = _selected == months.length - 1;

    return SubPage(
      title: 'Revenue',
      subtitle: '${gym.settings.gymName} · ${gym.settings.branchName}',
      maxWidth: 900,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
        children: [
          _MonthHero(stats: sel, previous: prev, isCurrent: isCurrent).entrance(context),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 16, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text('Monthly income', style: AppText.label.copyWith(color: AppColors.text))),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: const [ButtonSegment(value: false, label: Text('12 months')), ButtonSegment(value: true, label: Text('vs last year'))],
                    selected: {_compare},
                    onSelectionChanged: (s) => setState(() => _compare = s.first),
                  ),
                ]),
                AnimatedSize(
                  duration: Motion.medium,
                  child: _compare
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(spacing: 16, children: [
                            _Legend(color: AppColors.seriesPrimary, label: 'This year'),
                            _Legend(color: AppColors.seriesCompare, label: 'Same month last year'),
                          ]),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 14),
                RevenueBars(
                  data: [
                    for (var i = 0; i < months.length; i++) BarDatum(formatShortMonth(months[i].month), formatMonthYear(months[i].month), months[i].income, compare: yoy[i].$3),
                  ],
                  selected: _selected,
                  onSelect: (i) => setState(() => _selected = i),
                  showCompare: _compare,
                  target: gym.settings.monthlyTarget > 0 ? gym.settings.monthlyTarget : null,
                  height: 250,
                  semanticLabel: 'Monthly income for the last 12 months. Selected ${formatMonthYear(sel.month)}: ${formatMoney(sel.income)}.',
                ),
                if (_compare) ...[
                  const SizedBox(height: 10),
                  _YearSummary(rows: yoy),
                ],
              ],
            ),
          ).entrance(context, index: 1),
          const SectionHeader('How members paid'),
          _MethodSplit(month: sel.month).entrance(context, index: 2),
          const SectionHeader('Income and expenses'),
          _IncomeVsExpenses(months: months).entrance(context, index: 3),
          const SectionHeader('Spending'),
          _Spending(month: sel.month),
          const SectionHeader('Members'),
          _Retention(months: months, selected: _selected),
          const SectionHeader('Busy hours (last 4 weeks)'),
          AppCard(padding: const EdgeInsets.all(16), child: BusyHeatmap(grid: gym.busyHours(), firstHour: heatmapFirstHour)),
          const SectionHeader('Running members by plan'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: RankedBars(items: [for (final (plan, n) in gym.planMix) (plan.name, n.toDouble(), '$n')]),
          ),
          const SectionHeader('Where new members came from'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: RankedBars(color: AppColors.seriesCompare, items: [for (final (s, n) in gym.sourceMix) (s.label, n.toDouble(), '$n')]),
          ),
        ],
      ),
    );
  }
}

class _MonthHero extends StatelessWidget {
  final MonthStats stats;
  final MonthStats previous;
  final bool isCurrent;

  const _MonthHero({required this.stats, required this.previous, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final change = isCurrent ? gym.incomeChangeToDate : GymAnalytics.change(stats.income, previous.income);
    final profitUp = stats.profit >= 0;
    // Four figures in a two-by-two grid, so long amounts never run into each other on a phone.
    Widget mini(String label, Widget value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppText.small.copyWith(color: Colors.white70)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
          ]),
        );
    final small = AppText.headline.copyWith(fontSize: 19, color: Colors.white);
    return AppCard(
      gradient: AppColors.redGradient,
      glow: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.fast,
                child: Text('${formatMonthYear(stats.month)}${isCurrent ? ' so far' : ''}', key: ValueKey(stats.month), style: AppText.body.copyWith(color: Colors.white70)),
              ),
            ),
            ChangeChip(change, onRed: true, suffix: isCurrent ? 'vs same days' : 'vs month before'),
          ]),
          const SizedBox(height: 6),
          CountUp(value: stats.income, format: formatMoney, duration: Motion.slow, style: AppText.display.copyWith(fontSize: 46, color: Colors.white)),
          const SizedBox(height: 16),
          Row(children: [
            mini('Expenses', CountUp(value: stats.expenses, format: formatMoneyCompact, style: small)),
            mini(profitUp ? 'Profit' : 'Loss', CountUp(value: stats.profit.abs(), format: formatMoneyCompact, style: small)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            mini('Admissions', CountUp(value: stats.admissions, style: small)),
            mini('Renewals', CountUp(value: stats.renewals, style: small)),
          ]),
          if (isCurrent && gym.settings.monthlyTarget > 0) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: gym.targetProgress.clamp(0, 1)),
                    duration: Motion.chart,
                    curve: Motion.settle,
                    builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: Colors.white, backgroundColor: Colors.black.withValues(alpha: 0.25)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${(gym.targetProgress * 100).round()}% of ${formatMoneyCompact(gym.settings.monthlyTarget)} target', style: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: AppText.small),
      ]);
}

class _YearSummary extends StatelessWidget {
  final List<(DateTime, double, double)> rows;

  const _YearSummary({required this.rows});

  @override
  Widget build(BuildContext context) {
    final current = rows.fold(0.0, (s, r) => s + r.$2);
    final last = rows.fold(0.0, (s, r) => s + r.$3);
    return Row(children: [
      Expanded(child: Text('Last 12 months ${formatMoneyCompact(current)} against ${formatMoneyCompact(last)} the year before', style: AppText.small)),
      ChangeChip(GymAnalytics.change(current, last)),
    ]);
  }
}

class _MethodSplit extends StatelessWidget {
  final DateTime month;

  const _MethodSplit({required this.month});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final byMethod = gym.incomeByMethod(month);
    final total = byMethod.values.fold(0.0, (s, v) => s + v);
    final methods = PayMethod.values;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SplitBar(key: ValueKey(month), parts: [for (var i = 0; i < methods.length; i++) (byMethod[methods[i]]!, AppColors.payMethods[i])]),
          const SizedBox(height: 14),
          for (var i = 0; i < methods.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.payMethods[i], borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                Icon(methods[i].icon, size: 18, color: AppColors.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(methods[i].label, style: AppText.body)),
                Text(formatMoney(byMethod[methods[i]]!), style: AppText.number),
                SizedBox(width: 52, child: Text(total == 0 ? '' : '${(byMethod[methods[i]]! / total * 100).round()}%', textAlign: TextAlign.right, style: AppText.small.copyWith(color: AppColors.muted))),
              ]),
            ),
        ],
      ),
    );
  }
}

class _IncomeVsExpenses extends StatelessWidget {
  final List<MonthStats> months;

  const _IncomeVsExpenses({required this.months});

  @override
  Widget build(BuildContext context) {
    final peak = months.fold<double>(0, (m, s) => [m, s.income, s.expenses].reduce((a, b) => a > b ? a : b));
    final step = niceStep(peak, 4);
    final maxY = (peak / step).ceil() * step;
    LineChartBarData line(List<double> values, Color color, {bool fill = false}) => LineChartBarData(
          spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
          isCurved: true,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: fill, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)])),
        );
    final totalProfit = months.fold(0.0, (s, m) => s + m.profit);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Wrap(spacing: 16, runSpacing: 6, children: [
              const _Legend(color: AppColors.seriesPrimary, label: 'Income'),
              const _Legend(color: AppColors.seriesCompare, label: 'Expenses'),
              Text('12-month profit ${formatMoneyCompact(totalProfit)}', style: AppText.small.copyWith(color: totalProfit >= 0 ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: LineChart(
              duration: Motion.chart,
              curve: Motion.settle,
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(drawVerticalLine: false, horizontalInterval: step, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: step,
                      getTitlesWidget: (v, meta) => SideTitleWidget(meta: meta, child: Text(v == 0 ? '0' : formatMoneyCompact(v), style: AppText.small.copyWith(fontSize: 10.5, color: AppColors.muted))),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) => v.toInt() % 2 == 1 || v != v.roundToDouble()
                          ? const SizedBox.shrink()
                          : SideTitleWidget(meta: meta, child: Text(formatShortMonth(months[v.toInt()].month), style: AppText.label.copyWith(fontSize: 9))),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceHigher,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${s.barIndex == 0 ? 'Income' : 'Expenses'} ${formatMoney(s.y)}',
                          AppText.small.copyWith(color: AppColors.text, fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  line([for (final m in months) m.income], AppColors.seriesPrimary, fill: true),
                  line([for (final m in months) m.expenses], AppColors.seriesCompare),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spending extends StatelessWidget {
  final DateTime month;

  const _Spending({required this.month});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final byCategory = gym.expensesByCategory(month);
    if (byCategory.isEmpty) return AppCard(child: Text('No expenses recorded for ${formatMonthYear(month)}.', style: AppText.bodyMuted));
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: RankedBars(
        key: ValueKey(month),
        color: AppColors.seriesCompare,
        items: [for (final e in byCategory.entries) (e.key.label, e.value, formatMoney(e.value))],
      ),
    );
  }
}

class _Retention extends StatelessWidget {
  final List<MonthStats> months;
  final int selected;

  const _Retention({required this.months, required this.selected});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    // The current month is still running, so its renewal rate is not final; use the month before.
    final rateMonth = selected == months.length - 1 ? months[selected - 1].month : months[selected].month;
    final rate = gym.renewalRate(rateMonth);
    final joins = [for (final m in months) m.admissions.toDouble()];
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ProgressRing(
            value: rate ?? 0,
            size: 104,
            stroke: 10,
            color: AppColors.success,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(rate == null ? '-' : '${(rate * 100).round()}%', style: AppText.headline.copyWith(fontSize: 24)),
              Text('Renewed', style: AppText.label.copyWith(fontSize: 8.5)),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Renewal rate, ${formatMonthYear(rateMonth)}', style: AppText.title.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text('Members whose plan ended and who renewed within 15 days.', style: AppText.small.copyWith(color: AppColors.muted)),
                const SizedBox(height: 12),
                Text('New admissions, 12 months', style: AppText.label.copyWith(fontSize: 9.5)),
                const SizedBox(height: 4),
                Sparkline(values: joins, color: AppColors.primaryBright, height: 44),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
