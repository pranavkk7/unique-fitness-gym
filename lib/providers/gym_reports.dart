import 'dart:math';

import '../core/utils/format.dart';
import '../models/models.dart';
import 'gym_provider.dart';

/// One member's month: visits, body change, personal training and what is assigned to them.
class ProgressReport {
  final Member member;
  final DateTime month;
  final int visits;
  final int previousVisits;
  final int bestStreak; // most days in a row with a visit
  final List<int> weeklyVisits; // visits in each week of the month, for the PDF chart
  final Measurement? firstWeight; // earliest of the last three months
  final Measurement? lastWeight;
  final int ptSessions;
  final List<GymClass> classes;
  final TrainingPlan? workoutPlan;
  final TrainingPlan? dietPlan;
  final int daysLeft;

  const ProgressReport({
    required this.member,
    required this.month,
    required this.visits,
    required this.previousVisits,
    required this.bestStreak,
    required this.weeklyVisits,
    required this.firstWeight,
    required this.lastWeight,
    required this.ptSessions,
    required this.classes,
    required this.workoutPlan,
    required this.dietPlan,
    required this.daysLeft,
  });

  double? get weightChange => firstWeight == null || lastWeight == null || firstWeight!.id == lastWeight!.id ? null : lastWeight!.weightKg - firstWeight!.weightKg;
}

extension GymReports on GymProvider {
  /// Reports go out for last month during the first week, and for the running month after that.
  DateTime get reportMonth => today.day <= 7 ? DateTime(today.year, today.month - 1) : DateTime(today.year, today.month);

  /// Running members who came in at least once in [month]: the people a report is worth sending to.
  List<Member> progressReportMembers([DateTime? month]) {
    final m = month ?? reportMonth;
    final visited = checkIns.where((c) => sameMonth(c.time, m)).map((c) => c.memberId).toSet();
    return members.where((x) => visited.contains(x.id) && isRunning(x)).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  ProgressReport progressReport(String memberId, [DateTime? month]) {
    final m = month ?? reportMonth;
    final member = memberById(memberId)!;
    final prev = DateTime(m.year, m.month - 1);
    final mine = checkInsFor(memberId);
    final days = mine.where((c) => sameMonth(c.time, m)).map((c) => dateOnly(c.time)).toSet().toList()..sort();
    var best = 0, run = 0;
    for (var i = 0; i < days.length; i++) {
      run = i > 0 && days[i].difference(days[i - 1]).inDays == 1 ? run + 1 : 1;
      best = max(best, run);
    }
    final weeks = List.filled(((DateTime(m.year, m.month + 1, 0).day - 1) ~/ 7) + 1, 0);
    for (final d in days) {
      weeks[(d.day - 1) ~/ 7]++;
    }
    final since = DateTime(m.year, m.month - 2, 1);
    final monthEnd = DateTime(m.year, m.month + 1, 1);
    final weights = measurementsFor(memberId).where((w) => !w.date.isBefore(since) && w.date.isBefore(monthEnd)).toList();
    return ProgressReport(
      member: member,
      month: m,
      visits: days.length,
      previousVisits: mine.where((c) => sameMonth(c.time, prev)).map((c) => dateOnly(c.time)).toSet().length,
      bestStreak: best,
      weeklyVisits: weeks,
      firstWeight: weights.firstOrNull,
      lastWeight: weights.lastOrNull,
      ptSessions: ptPackagesFor(memberId).expand((p) => p.sessions).where((s) => sameMonth(s, m)).length,
      classes: classesOf(memberId),
      workoutPlan: trainingPlanById(member.workoutPlanId),
      dietPlan: trainingPlanById(member.dietPlanId),
      daysLeft: daysLeft(member),
    );
  }

  /// The morning summary for [day]: plans ending within three days, dues, birthdays and
  /// follow-ups. Null when there is nothing to do, so no notification is sent.
  ({String title, String body})? morningDigest(DateTime day) {
    final d = dateOnly(day);
    final ending = members.where((m) {
      final left = dateOnly(m.endDate).difference(d).inDays;
      return left >= 0 && left <= 3 && m.freezeOn(d) == null;
    }).length;
    final dues = members.where((m) => m.balanceDue > 0 && isRunning(m)).length;
    final birthdays = members.where((m) => m.dateOfBirth != null && m.dateOfBirth!.month == d.month && m.dateOfBirth!.day == d.day && isRunning(m)).length;
    final followUps = enquiries.where((e) => e.nextFollowUp != null && !dateOnly(e.nextFollowUp!).isAfter(d) && e.status != EnquiryStatus.converted && e.status != EnquiryStatus.lost).length;
    final parts = [
      if (ending > 0) '$ending plan${ending == 1 ? '' : 's'} ending soon',
      if (dues > 0) '$dues with dues',
      if (birthdays > 0) '$birthdays birthday${birthdays == 1 ? '' : 's'}',
      if (followUps > 0) '$followUps follow-up${followUps == 1 ? '' : 's'}',
    ];
    if (parts.isEmpty) return null;
    return (title: 'Good morning, ${settings.branchName}', body: '${parts.join(' · ')}. Open the app to send the reminders.');
  }

  /// The WhatsApp version: the editable intro from the templates, then the numbers.
  String progressText(ProgressReport r) {
    final intro = fillTemplate(settings.templates.of(ReminderKind.progress), {
      '{name}': r.member.firstName,
      '{gym}': settings.gymName,
      '{plan}': planById(r.member.planId)?.name ?? 'membership',
      '{date}': formatDate(r.member.endDate),
      '{code}': memberCode(r.member.number),
      '{phone}': settings.phone,
    });
    final diff = r.visits - r.previousVisits;
    final change = r.weightChange;
    return [
      intro,
      '',
      '*${formatMonthYear(r.month)} · ${memberCode(r.member.number)}*',
      '🏋️ Workouts: ${r.visits}${r.previousVisits > 0 ? ' (${diff >= 0 ? '+' : ''}$diff vs last month)' : ''}',
      if (r.bestStreak > 1) '🔥 Best streak: ${r.bestStreak} days in a row',
      if (r.lastWeight != null) '⚖️ Weight: ${r.lastWeight!.weightKg.toStringAsFixed(1)} kg${change == null ? '' : ' (${change <= 0 ? '' : '+'}${change.toStringAsFixed(1)} kg)'}',
      if (r.ptSessions > 0) '🥊 PT sessions: ${r.ptSessions}',
      if (r.classes.isNotEmpty) '📅 Classes: ${r.classes.map((c) => c.title).join(', ')}',
      if (r.workoutPlan != null) '📋 Workout plan: ${r.workoutPlan!.name}',
      if (r.dietPlan != null) '🥗 Diet plan: ${r.dietPlan!.name}',
      r.daysLeft >= 0 ? '✅ Membership valid till ${formatDate(r.member.endDate)}' : '⚠️ Membership ended on ${formatDate(r.member.endDate)}',
      '',
      _motivation(r),
    ].join('\n');
  }

  String _motivation(ProgressReport r) {
    if (r.visits >= 20) return 'Outstanding consistency. You are in the top group this month! 🏆';
    if (r.visits > r.previousVisits) return 'More workouts than last month. Keep the momentum going! 💪';
    if (r.visits >= 12) return 'Solid month. Aim for one extra session a week next month.';
    return 'Every visit counts. Let us see you a little more often next month! 🙌';
  }
}
