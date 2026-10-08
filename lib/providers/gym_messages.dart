import '../core/utils/format.dart';
import '../models/models.dart';
import 'gym_provider.dart';

/// One person to message: who, why, and the ready-to-send WhatsApp text.
class ReminderTarget {
  final ReminderKind kind;
  final String id; // member id, or enquiry id for follow-ups
  final String name;
  final String phone;
  final String detail; // short reason shown in the list, e.g. "Ends in 3 days"
  final String message;
  final bool sentRecently;
  final Member? member;

  const ReminderTarget({
    required this.kind,
    required this.id,
    required this.name,
    required this.phone,
    required this.detail,
    required this.message,
    required this.sentRecently,
    this.member,
  });
}

/// Reminder lists, message text, receipts and exports.
extension GymMessages on GymProvider {
  static const _winBackDays = 30; // expired longer than this counts as gone, not "just expired"

  /// The ready-to-send list for one kind of reminder. People messaged within the kind's cooldown
  /// are left out unless [includeSent] is true (they are then marked as sent).
  List<ReminderTarget> reminderQueue(ReminderKind kind, {bool includeSent = false}) {
    final targets = <ReminderTarget>[];

    void addMember(Member m, String detail) {
      final sent = remindedRecently(m.id, kind);
      if (sent && !includeSent) return;
      targets.add(ReminderTarget(kind: kind, id: m.id, name: m.name, phone: m.phone, detail: detail, message: messageFor(kind, m), sentRecently: sent, member: m));
    }

    switch (kind) {
      case ReminderKind.expiring:
        for (final m in expiringSoon) {
          final left = daysLeft(m);
          addMember(m, left == 0 ? 'Ends today' : 'Ends in $left day${left == 1 ? '' : 's'}');
        }
      case ReminderKind.expired:
        final list = members.where((m) => statusOf(m) == MemberStatus.expired && daysLeft(m) >= -_winBackDays).toList()..sort((a, b) => b.endDate.compareTo(a.endDate));
        for (final m in list) {
          final ago = -daysLeft(m);
          addMember(m, 'Expired ${ago == 1 ? 'yesterday' : '$ago days ago'}');
        }
      case ReminderKind.due:
        for (final m in membersWithDue) {
          addMember(m, '${formatMoney(m.balanceDue)} due');
        }
      case ReminderKind.birthday:
        for (final m in birthdaysToday) {
          final age = m.dateOfBirth == null ? null : today.year - m.dateOfBirth!.year;
          addMember(m, age == null ? 'Birthday today' : 'Turns $age today');
        }
      case ReminderKind.inactive:
        for (final m in inactiveMembers) {
          final last = lastVisit(m.id);
          addMember(m, last == null ? 'No visits yet' : 'Last visit ${today.difference(dateOnly(last)).inDays} days ago');
        }
      case ReminderKind.followUp:
        for (final e in followUpsDue) {
          final sent = remindedRecently(e.id, kind);
          if (sent && !includeSent) continue;
          final overdue = today.difference(dateOnly(e.nextFollowUp!)).inDays;
          targets.add(ReminderTarget(
            kind: kind,
            id: e.id,
            name: e.name,
            phone: e.phone,
            detail: overdue == 0 ? 'Follow up today' : 'Overdue by $overdue day${overdue == 1 ? '' : 's'}',
            message: enquiryMessage(e),
            sentRecently: sent,
          ));
        }
      case ReminderKind.welcome:
        break; // sent right after an admission, never queued
      case ReminderKind.progress:
        for (final m in progressReportMembers()) {
          final sent = remindedRecently(m.id, kind);
          if (sent && !includeSent) continue;
          final r = progressReport(m.id);
          targets.add(ReminderTarget(kind: kind, id: m.id, name: m.name, phone: m.phone, detail: '${r.visits} workouts in ${formatShortMonth(r.month)}', message: progressText(r), sentRecently: sent, member: m));
        }
    }
    return targets;
  }

  /// Kinds shown on the Reminders tab, in priority order.
  static const queueKinds = [ReminderKind.expiring, ReminderKind.due, ReminderKind.expired, ReminderKind.inactive, ReminderKind.birthday, ReminderKind.followUp];

  int get pendingReminderCount => queueKinds.fold(0, (s, k) => s + reminderQueue(k).length);

  /// Running members (not frozen) who have not come in for [GymSettings.inactiveAfterDays] days.
  List<Member> get inactiveMembers {
    final limit = settings.inactiveAfterDays;
    final list = members.where((m) {
      final s = statusOf(m);
      if (s == MemberStatus.expired || s == MemberStatus.frozen) return false;
      final last = lastVisit(m.id);
      final since = last == null ? dateOnly(m.startDate) : dateOnly(last);
      return today.difference(since).inDays >= limit;
    }).toList();
    list.sort((a, b) => (lastVisit(a.id) ?? a.startDate).compareTo(lastVisit(b.id) ?? b.startDate));
    return list;
  }

  Map<String, String> _values(Member m) {
    final left = daysLeft(m);
    return {
      '{name}': m.firstName,
      '{gym}': settings.gymName,
      '{plan}': planById(m.planId)?.name ?? 'membership',
      '{date}': formatDate(m.endDate),
      '{days}': left < 0 ? 'already ended' : (left == 0 ? 'that is today' : '$left day${left == 1 ? '' : 's'} left'),
      '{amount}': formatMoney(m.balanceDue),
      '{code}': memberCode(m.number),
      '{phone}': settings.phone,
    };
  }

  String messageFor(ReminderKind kind, Member m) => kind == ReminderKind.progress ? progressText(progressReport(m.id)) : fillTemplate(settings.templates.of(kind), _values(m));

  String enquiryMessage(Enquiry e) => fillTemplate(settings.templates.of(ReminderKind.followUp), {
        '{name}': e.name.trim().split(RegExp(r'\s+')).first,
        '{gym}': settings.gymName,
        '{plan}': planById(e.planId)?.name ?? 'membership',
        '{phone}': settings.phone,
      });

  /// Plain-text receipt for WhatsApp, covering every line paid on the receipt.
  String receiptText(String receiptNo) {
    final lines = paymentsOnReceipt(receiptNo);
    if (lines.isEmpty) return '';
    final m = memberById(lines.first.memberId);
    final total = lines.fold(0.0, (s, p) => s + p.amount);
    final b = StringBuffer()
      ..writeln('*${settings.gymName}* · ${settings.branchName}')
      ..writeln('Receipt $receiptNo')
      ..writeln('Date: ${formatDate(lines.first.date)}')
      ..writeln('${m == null ? 'Name' : 'Member'}: ${payerOf(lines.first)}${m == null ? '' : ' (${memberCode(m.number)})'}');
    for (final p in lines) {
      b.writeln('• ${p.note.isEmpty ? p.kind.label : p.note}: ${formatMoney(p.amount)}');
    }
    b
      ..writeln('*Total paid: ${formatMoney(total)}* (${lines.first.method.label})')
      ..writeln(m == null || !lines.any((p) => p.kind == PaymentKind.membership || p.kind == PaymentKind.admission) ? '' : 'Valid till: ${formatDate(m.endDate)}${m.balanceDue > 0 ? ' · Balance due: ${formatMoney(m.balanceDue)}' : ''}')
      ..write('Thank you! ${settings.phone}');
    return b.toString();
  }

  /// Payee on the sample QR shown until the gym's real UPI ID is added. "example" is not a bank
  /// handle, so any UPI app refuses to pay it: the sample can be shown without risk.
  static const demoUpiId = 'unique.fitness@example';

  /// The sample QR is shown while demo data is loaded (nobody should pay for a fictional member)
  /// and whenever no UPI ID is set.
  bool get upiIsDemo => settings.demoData || settings.upiId.trim().isEmpty;

  /// UPI payment link (opens GPay, PhonePe or Paytm) for the amount. Uses [demoUpiId] when
  /// [upiIsDemo].
  String upiLink(double amount, {String note = ''}) {
    return Uri(scheme: 'upi', host: 'pay', queryParameters: {
      'pa': upiIsDemo ? demoUpiId : settings.upiId.trim(),
      'pn': settings.gymName,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      if (note.isNotEmpty) 'tn': note,
    }).toString();
  }

  String exportMembersCsv() {
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('code,name,phone,gender,plan,joined,start,end,status,balance_due,trainer\n');
    final sorted = [...members]..sort((a, b) => a.number.compareTo(b.number));
    for (final m in sorted) {
      b.writeln([
        memberCode(m.number),
        esc(m.name),
        esc(m.phone),
        m.gender.label,
        esc(planById(m.planId)?.name ?? ''),
        isoDay(m.joinDate),
        isoDay(m.startDate),
        isoDay(m.endDate),
        statusOf(m).name,
        m.balanceDue.toStringAsFixed(0),
        esc(trainerById(m.trainerId)?.name ?? ''),
      ].join(','));
    }
    return b.toString();
  }
}
