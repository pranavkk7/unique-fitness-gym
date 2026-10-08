import '../core/utils/format.dart';
import '../models/models.dart';
import 'gym_provider.dart';

/// Money in and out, and the people side of one calendar month.
class MonthStats {
  final DateTime month;
  final double income;
  final double expenses;
  final int admissions;
  final int renewals;

  const MonthStats({required this.month, required this.income, required this.expenses, required this.admissions, required this.renewals});

  double get profit => income - expenses;
}

enum ActivityKind { checkIn, payment, admission, enquiry }

/// One line of the "what just happened" feed on the dashboard.
class ActivityItem {
  final ActivityKind kind;
  final DateTime time;
  final String title;
  final String subtitle;
  final String? memberId;
  final double? amount;

  const ActivityItem({required this.kind, required this.time, required this.title, required this.subtitle, this.memberId, this.amount});
}

/// First hour shown on the busy-hours heatmap, and how many hours it covers (5 AM to 10 PM).
const heatmapFirstHour = 5;
const heatmapHours = 18;

/// Revenue, attendance and retention numbers for the reports and the dashboard.
extension GymAnalytics on GymProvider {
  DateTime get thisMonth => DateTime(today.year, today.month);

  DateTime monthsAgo(int n) => DateTime(today.year, today.month - n);

  double incomeIn(DateTime month) => payments.where((p) => sameMonth(p.date, month)).fold(0.0, (s, p) => s + p.amount);

  double expensesIn(DateTime month) => expenses.where((e) => sameMonth(e.date, month)).fold(0.0, (s, e) => s + e.amount);

  double get incomeToday => payments.where((p) => sameDay(p.date, today)).fold(0.0, (s, p) => s + p.amount);

  double get incomeThisMonth => incomeIn(thisMonth);

  MonthStats statsFor(DateTime month) {
    final subs = subscriptions.where((s) => sameMonth(s.createdAt, month));
    return MonthStats(
      month: DateTime(month.year, month.month),
      income: incomeIn(month),
      expenses: expensesIn(month),
      admissions: subs.where((s) => s.kind == SubscriptionKind.admission).length,
      renewals: subs.where((s) => s.kind == SubscriptionKind.renewal).length,
    );
  }

  /// The last [count] months, oldest first, ending with the current month.
  List<MonthStats> monthlyStats([int count = 12]) => [for (var i = count - 1; i >= 0; i--) statsFor(monthsAgo(i))];

  /// Change from [previous] to [current] as a fraction (0.12 = +12%), or null when there is nothing to compare with.
  static double? change(double current, double previous) => previous <= 0 ? null : (current - previous) / previous;

  /// This month's income so far against the same days of last month, so a half-finished month is
  /// compared fairly instead of against a whole one.
  double? get incomeChangeToDate {
    final lastMonth = monthsAgo(1);
    final lastMonthDays = DateTime(lastMonth.year, lastMonth.month + 1, 0).day;
    final cutoff = DateTime(lastMonth.year, lastMonth.month, today.day > lastMonthDays ? lastMonthDays : today.day, 23, 59, 59);
    final lastToDate = payments.where((p) => sameMonth(p.date, lastMonth) && !p.date.isAfter(cutoff)).fold(0.0, (s, p) => s + p.amount);
    return change(incomeThisMonth, lastToDate);
  }

  /// Month-end income if the rest of the month goes like the days so far.
  double get projectedIncome {
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    return incomeThisMonth / today.day * daysInMonth;
  }

  /// Share of the monthly target already collected (0 when no target is set).
  double get targetProgress => settings.monthlyTarget <= 0 ? 0 : incomeThisMonth / settings.monthlyTarget;

  /// Each of the last 12 months against the same month one year earlier.
  List<(DateTime month, double current, double lastYear)> yearOverYear() => [
        for (var i = 11; i >= 0; i--) (monthsAgo(i), incomeIn(monthsAgo(i)), incomeIn(monthsAgo(i + 12))),
      ];

  Map<PayMethod, double> incomeByMethod(DateTime month) {
    final result = {for (final m in PayMethod.values) m: 0.0};
    for (final p in payments.where((p) => sameMonth(p.date, month))) {
      result[p.method] = result[p.method]! + p.amount;
    }
    return result;
  }

  Map<ExpenseCategory, double> expensesByCategory(DateTime month) {
    final result = <ExpenseCategory, double>{};
    for (final e in expenses.where((e) => sameMonth(e.date, month))) {
      result[e.category] = (result[e.category] ?? 0) + e.amount;
    }
    return Map.fromEntries(result.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  /// Running members per plan, biggest first.
  List<(Plan plan, int count)> get planMix {
    final counts = <String, int>{};
    for (final m in members.where(isRunning)) {
      counts[m.planId] = (counts[m.planId] ?? 0) + 1;
    }
    final list = [
      for (final e in counts.entries)
        if (planById(e.key) != null) (planById(e.key)!, e.value),
    ];
    list.sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  /// Where the members who joined in the last 12 months heard about the gym.
  List<(LeadSource source, int count)> get sourceMix {
    final since = monthsAgo(11);
    final counts = <LeadSource, int>{};
    for (final m in members.where((m) => !m.joinDate.isBefore(since))) {
      counts[m.source] = (counts[m.source] ?? 0) + 1;
    }
    return [for (final e in counts.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
  }

  /// Of the memberships that ended in [month], the share renewed within 15 days of ending.
  /// Null when none ended that month.
  double? renewalRate(DateTime month) {
    final ended = subscriptions.where((s) => sameMonth(s.end, month) && !s.end.isAfter(today)).toList();
    if (ended.isEmpty) return null;
    var renewed = 0;
    for (final s in ended) {
      final next = subscriptions.any((n) => n.memberId == s.memberId && n.kind == SubscriptionKind.renewal && !n.start.isBefore(s.end.subtract(const Duration(days: 1))) && n.start.difference(s.end).inDays <= 15);
      if (next) renewed++;
    }
    return renewed / ended.length;
  }

  /// Check-ins per day for the last [days] days, oldest first.
  List<(DateTime day, int count)> checkInsPerDay([int days = 7]) => [
        for (var i = days - 1; i >= 0; i--) (today.subtract(Duration(days: i)), checkIns.where((c) => sameDay(c.time, today.subtract(Duration(days: i)))).length),
      ];

  /// Average check-ins per weekday and hour over the last [days] days: rows Monday..Sunday,
  /// columns [heatmapFirstHour] onwards. Used for the busy-hours heatmap.
  List<List<double>> busyHours({int days = 28}) {
    final grid = List.generate(7, (_) => List.filled(heatmapHours, 0.0));
    final since = today.subtract(Duration(days: days - 1));
    for (final c in checkIns) {
      if (c.time.isBefore(since)) continue;
      final col = c.time.hour - heatmapFirstHour;
      if (col < 0 || col >= heatmapHours) continue;
      grid[c.time.weekday - 1][col] += 1;
    }
    final weeks = days / 7;
    return [for (final row in grid) [for (final v in row) v / weeks]];
  }

  /// Check-ins today per hour from [heatmapFirstHour].
  List<double> hourlyToday() {
    final out = List<double>.filled(heatmapHours, 0);
    for (final c in checkInsToday) {
      final i = c.time.hour - heatmapFirstHour;
      if (i >= 0 && i < heatmapHours) out[i]++;
    }
    return out;
  }

  /// A usual day like today: average check-ins per hour on this weekday over the last 4 weeks.
  List<double> usualHourly() => busyHours()[today.weekday - 1];

  /// Members with a running plan at the end of each of the last [weeks] weeks, oldest first.
  List<double> runningTrend([int weeks = 8]) {
    double runningOn(DateTime day) => subscriptions.where((s) => !s.start.isAfter(day) && s.end.isAfter(day)).map((s) => s.memberId).toSet().length.toDouble();
    return [for (var i = weeks - 1; i >= 0; i--) runningOn(today.subtract(Duration(days: 7 * i)))];
  }

  /// Memberships ending on each of the next [days] days (today first).
  List<double> endingPerDay([int days = 7]) => [
        for (var i = 0; i < days; i++) members.where((m) => sameDay(m.endDate, today.add(Duration(days: i)))).length.toDouble(),
      ];

  /// Members who checked in during the last [window], a fair stand-in for "in the gym now".
  int recentlyIn([Duration window = const Duration(minutes: 90)]) {
    final since = now.subtract(window);
    return checkIns.where((c) => c.time.isAfter(since) && !c.time.isAfter(now)).length;
  }

  int visitsInLast(String memberId, int days) {
    final since = today.subtract(Duration(days: days - 1));
    return checkIns.where((c) => c.memberId == memberId && !c.time.isBefore(since)).length;
  }

  /// Visits for each of the last [weeks] weeks (oldest first), for the attendance strip on a profile.
  List<int> weeklyVisits(String memberId, [int weeks = 12]) {
    final result = List.filled(weeks, 0);
    final start = today.subtract(Duration(days: weeks * 7 - 1));
    for (final c in checkIns) {
      if (c.memberId != memberId || c.time.isBefore(start)) continue;
      final i = dateOnly(c.time).difference(start).inDays ~/ 7;
      if (i >= 0 && i < weeks) result[i]++;
    }
    return result;
  }

  /// The latest admissions, payments, check-ins and enquiries, newest first.
  List<ActivityItem> recentActivity([int limit = 8]) {
    String who(String id) => memberById(id)?.name ?? 'Former member';
    final items = <ActivityItem>[
      for (final c in checkIns.where((c) => !c.time.isAfter(now)).toList()..sort((a, b) => b.time.compareTo(a.time)))
        ActivityItem(kind: ActivityKind.checkIn, time: c.time, title: who(c.memberId), subtitle: 'Checked in · ${c.source.label}', memberId: c.memberId),
    ].take(limit).toList();
    final paid = payments.toList()..sort((a, b) => b.date.compareTo(a.date));
    final seenReceipts = <String>{};
    for (final p in paid) {
      if (items.length > limit * 2) break;
      if (!seenReceipts.add(p.receiptNo)) continue;
      final total = paymentsOnReceipt(p.receiptNo).fold(0.0, (s, x) => s + x.amount);
      items.add(ActivityItem(kind: ActivityKind.payment, time: p.date, title: payerOf(p), subtitle: '${p.kind == PaymentKind.membership || p.kind == PaymentKind.admission ? p.method.label : p.kind.label} · ${p.receiptNo}', memberId: p.memberId.isEmpty ? null : p.memberId, amount: total));
    }
    for (final m in members.where((m) => today.difference(m.joinDate).inDays < 30)) {
      final sub = subscriptions.where((s) => s.memberId == m.id && s.kind == SubscriptionKind.admission).firstOrNull;
      items.add(ActivityItem(kind: ActivityKind.admission, time: sub?.createdAt ?? m.joinDate, title: m.name, subtitle: 'New admission · ${planById(m.planId)?.name ?? ''}', memberId: m.id));
    }
    for (final e in enquiries.where((e) => today.difference(dateOnly(e.createdAt)).inDays < 30)) {
      items.add(ActivityItem(kind: ActivityKind.enquiry, time: e.createdAt, title: e.name, subtitle: 'Enquiry · ${e.source.label}'));
    }
    items.sort((a, b) => b.time.compareTo(a.time));
    return items.take(limit).toList();
  }
}
