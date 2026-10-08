import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unique_fitness_gym/core/utils/format.dart';
import 'package:unique_fitness_gym/data/gym_store.dart';
import 'package:unique_fitness_gym/models/models.dart';
import 'package:unique_fitness_gym/providers/gym_provider.dart';

final _clockTime = DateTime(2026, 10, 15, 10, 30); // a Thursday

Future<GymProvider> _provider({DateTime Function()? clock, GymStore? store, double admissionFee = 500}) async {
  final p = GymProvider(store: store ?? MemoryGymStore(), clock: clock ?? () => _clockTime);
  await p.init();
  // The gym charges no joining fee, but the app supports one, so the billing rules are tested with it.
  if (p.settings.admissionFee != admissionFee) await p.updateSettings(p.settings.copyWith(admissionFee: admissionFee));
  return p;
}

Future<Member> _add(GymProvider p, {String name = 'Test Member', String planId = 'silver-1m', double? paid, DateTime? start, double discount = 0, bool fee = false, DateTime? dob}) async =>
    (await p.admit(
      name: name,
      phone: '9876543210',
      gender: Gender.male,
      planId: planId,
      amountPaid: paid ?? p.planById(planId)!.price - discount + (fee ? p.settings.admissionFee : 0),
      startDate: start,
      discount: discount,
      chargeAdmissionFee: fee,
      dateOfBirth: dob,
    ))
        .member;

void main() {
  group('first launch', () {
    test('starts with the Pinarayi branch, plans and timetable but no members', () async {
      final p = GymProvider(store: MemoryGymStore(), clock: () => _clockTime);
      await p.init();
      expect(p.loaded, isTrue);
      expect(p.branch.name, 'Pinarayi');
      expect(p.settings.branchName, 'Pinarayi');
      expect(p.plans, isNotEmpty);
      expect(p.classes, isNotEmpty);
      expect(p.hasMembers, isFalse);
      expect(p.settings.admissionFee, 0); // the price list is the full fee
      expect(p.settings.upiId, const String.fromEnvironment('GYM_UPI_ID')); // set at build time, empty in the public repo
      expect(p.settings.address, contains('Aiswarya'));
      expect(p.plans.length, 12); // Silver and Platinum, six durations each
      expect(p.planById('silver-12m')!.price, 10000);
      expect(p.planById('platinum-1m')!.price, 1800);
      expect(p.classes.map((c) => c.title), containsAll(['Zumba Dance Fitness', 'Kick Boxing', 'Boxing & Self-Defence']));
    });

    test('data survives a restart with the same store', () async {
      final store = MemoryGymStore();
      final p = await _provider(store: store);
      final m = await _add(p, name: 'Persisted');
      await p.checkIn(m.id);
      await p.updateSettings(p.settings.copyWith(ownerName: 'Boss'));

      final again = await _provider(store: store);
      expect(again.members.single.name, 'Persisted');
      expect(again.checkInsToday.length, 1);
      expect(again.settings.ownerName, 'Boss');
      expect(again.subscriptions.length, 1);
    });

    test('a check-in writes one record instead of rewriting everything', () async {
      final store = MemoryGymStore();
      final p = await _provider(store: store);
      final m = await _add(p);
      final before = store.writes;
      await p.checkIn(m.id);
      expect(store.writes - before, 1);
    });
  });

  group('admission', () {
    test('bill = plan - discount + admission fee, paid on one receipt with two lines', () async {
      final p = await _provider();
      final r = await p.admit(name: '  Ravi Kumar ', phone: '9876543210', gender: Gender.male, planId: 'platinum-3m', discount: 500, amountPaid: 4000);
      // 4000 - 500 + 500 fee = 4000, all paid.
      expect(r.member.name, 'Ravi Kumar');
      expect(r.member.balanceDue, 0);
      expect(r.member.endDate, DateTime(2027, 1, 15));
      expect(memberCode(r.member.number), 'UFG-0001');
      expect(r.payments.map((x) => (x.kind, x.amount)), [(PaymentKind.admission, 500.0), (PaymentKind.membership, 3500.0)]);
      expect(r.payments.map((x) => x.receiptNo).toSet(), {'RCPT-00001'});
      final sub = p.subscriptionsFor(r.member.id).single;
      expect(sub.kind, SubscriptionKind.admission);
      expect(sub.amount, 3500);
    });

    test('part payment covers the admission fee first and the rest becomes balance due', () async {
      final p = await _provider();
      final r = await p.admit(name: 'A', phone: '9876543210', gender: Gender.female, planId: 'silver-1m', amountPaid: 300);
      expect(r.payments.single.kind, PaymentKind.admission);
      expect(r.payments.single.amount, 300);
      expect(r.member.balanceDue, 1500 + 500 - 300);
      expect(p.totalDue, 1700);
    });

    test('member numbers and receipt numbers keep increasing', () async {
      final p = await _provider();
      await _add(p, name: 'First');
      final second = await _add(p, name: 'Second');
      expect(second.number, 2);
      final pay = await p.recordPayment(second.id, amount: 100, kind: PaymentKind.other);
      expect(pay.receiptNo, 'RCPT-00003');
    });

    test('month-end start dates do not overflow', () async {
      final p = await _provider();
      final m = await _add(p, start: DateTime(2026, 1, 31));
      expect(m.endDate, DateTime(2026, 2, 28));
    });

    test('invalid admissions are rejected', () async {
      final p = await _provider();
      expect(() => _add(p, planId: 'nope', paid: 0), throwsArgumentError);
      expect(() => _add(p, discount: 5000, paid: 0), throwsArgumentError);
      expect(() => _add(p, paid: -1), throwsArgumentError);
    });

    test('admitting from an enquiry marks it as joined', () async {
      final p = await _provider();
      final e = await p.saveEnquiry(Enquiry(id: p.newEnquiryId(), name: 'Lead', phone: '9123456780', createdAt: p.now, nextFollowUp: p.today));
      expect(p.followUpsDue, hasLength(1));
      final r = await p.admit(name: e.name, phone: e.phone, gender: Gender.male, planId: 'silver-1m', enquiryId: e.id);
      expect(p.enquiryById(e.id)!.status, EnquiryStatus.converted);
      expect(p.enquiryById(e.id)!.memberId, r.member.id);
      expect(p.followUpsDue, isEmpty);
    });

    test('photos are saved with the admission and can be removed', () async {
      final p = await _provider();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final r = await p.admit(name: 'Pic', phone: '9876543210', gender: Gender.male, planId: 'silver-1m', photo: bytes);
      expect(r.member.hasPhoto, isTrue);
      expect(await p.loadPhoto(r.member.id), bytes);
      await p.setPhoto(r.member.id, null);
      expect(p.memberById(r.member.id)!.hasPhoto, isFalse);
      expect(await p.loadPhoto(r.member.id), isNull);
    });
  });

  group('status, freeze and renewal', () {
    test('active, expiring soon, ends today and expired', () async {
      final p = await _provider();
      Future<Member> endingIn(int days) => _add(p, name: 'D$days', start: addMonths(DateTime(2026, 10, 15).add(Duration(days: days)), -1));
      final far = await endingIn(40);
      final soon = await endingIn(5);
      final today = await endingIn(0);
      final gone = await endingIn(-3);
      expect(p.statusOf(far), MemberStatus.active);
      expect(p.statusOf(soon), MemberStatus.expiringSoon);
      expect(p.statusOf(today), MemberStatus.expiringSoon);
      expect(p.daysLeft(today), 0);
      expect(p.statusOf(gone), MemberStatus.expired);
      expect(p.activeCount, 3);
      expect(p.expiringSoon.map((m) => m.name), ['D0', 'D5']);
    });

    test('freezing pauses the membership and moves the end date out', () async {
      final p = await _provider();
      final m = await _add(p); // ends 15 Nov
      final frozen = await p.freeze(m.id, days: 10, reason: 'Travel');
      expect(frozen.endDate, DateTime(2026, 11, 25));
      expect(p.statusOf(frozen), MemberStatus.frozen);
      expect(await p.checkIn(m.id), CheckInOutcome.blockedFrozen);
      expect(() => p.freeze(m.id, days: 5), throwsStateError);
    });

    test('ending a freeze early gives back the unused days', () async {
      var now = _clockTime;
      final p = await _provider(clock: () => now);
      final m = await _add(p);
      await p.freeze(m.id, days: 10);
      now = now.add(const Duration(days: 4));
      final back = await p.unfreeze(m.id);
      expect(back.endDate, DateTime(2026, 11, 19)); // 15 Nov + 4 used days
      expect(back.freezes.single.days, 4);
      expect(p.statusOf(back), MemberStatus.active);
    });

    test('an expired membership cannot be frozen', () async {
      final p = await _provider();
      final m = await _add(p, start: DateTime(2026, 7, 1));
      expect(() => p.freeze(m.id, days: 5), throwsStateError);
    });

    test('renewing a running membership continues from the old end date', () async {
      final p = await _provider();
      final m = await _add(p, start: DateTime(2026, 10, 1)); // ends 1 Nov
      final (renewed, payment) = await p.renew(m.id, planId: 'platinum-3m', amountPaid: 4000);
      expect(renewed.startDate, DateTime(2026, 11, 1));
      expect(renewed.endDate, DateTime(2027, 2, 1));
      expect(payment!.note, contains('renewal'));
      expect(p.subscriptionsFor(m.id).first.kind, SubscriptionKind.renewal);
    });

    test('renewing an expired membership restarts today and keeps old dues', () async {
      final p = await _provider();
      final m = await _add(p, start: DateTime(2026, 8, 1), paid: 1000); // expired 1 Sep, 500 due
      final (renewed, _) = await p.renew(m.id, planId: 'silver-1m', amountPaid: 1500);
      expect(renewed.startDate, DateTime(2026, 10, 15));
      expect(renewed.balanceDue, 500);
    });

    test('paying more than the renewal clears an older balance', () async {
      final p = await _provider();
      final m = await _add(p, paid: 1000); // 500 due
      final (renewed, _) = await p.renew(m.id, planId: 'silver-1m', discount: 200, amountPaid: 1800);
      expect(renewed.balanceDue, 0);
    });

    test('balance payments reduce dues; personal training does not', () async {
      final p = await _provider();
      final m = await _add(p, paid: 1000);
      await p.recordPayment(m.id, amount: 200);
      expect(p.memberById(m.id)!.balanceDue, 300);
      await p.recordPayment(m.id, amount: 2000, kind: PaymentKind.personalTraining);
      expect(p.memberById(m.id)!.balanceDue, 300);
      await p.recordPayment(m.id, amount: 900);
      expect(p.memberById(m.id)!.balanceDue, 0);
      expect(() => p.recordPayment(m.id, amount: 0), throwsArgumentError);
    });
  });

  group('check-ins', () {
    test('once per day, and expired members only with permission', () async {
      final p = await _provider();
      final active = await _add(p, name: 'Active');
      final expired = await _add(p, name: 'Expired', start: DateTime(2026, 7, 1));
      expect(await p.checkIn(active.id), CheckInOutcome.recorded);
      expect(await p.checkIn(active.id), CheckInOutcome.duplicateToday);
      expect(await p.checkIn(expired.id), CheckInOutcome.blockedExpired);
      expect(await p.checkIn(expired.id, allowExpired: true, source: CheckInSource.faceId), CheckInOutcome.recorded);
      expect(p.checkInsToday.length, 2);
      expect(p.checkInsFor(expired.id).single.source, CheckInSource.faceId);
    });

    test('undo removes the check-in so it can be done again', () async {
      final p = await _provider();
      final m = await _add(p);
      await p.checkIn(m.id);
      await p.undoCheckIn(p.checkInsToday.single.id);
      expect(p.checkInsToday, isEmpty);
      expect(await p.checkIn(m.id), CheckInOutcome.recorded);
    });

    test('search by name, member code and phone digits', () async {
      final p = await _provider();
      await _add(p, name: 'Sneha Pillai');
      await _add(p, name: 'Rahul Menon');
      expect(p.searchMembers(query: 'sneh').single.name, 'Sneha Pillai');
      expect(p.searchMembers(query: 'ufg-0002').single.name, 'Rahul Menon');
      expect(p.searchMembers(query: '98765').length, 2);
      expect(p.searchMembers(query: 'zzz'), isEmpty);
    });
  });

  group('reminders', () {
    test('queues list the right people with filled-in messages', () async {
      final p = await _provider();
      final ending = await _add(p, name: 'Sneha Pillai', start: DateTime(2026, 9, 18), paid: 1000); // ends 18 Oct, 500 due
      await _add(p, name: 'Lapsed', start: DateTime(2026, 8, 20)); // expired 20 Sep
      await _add(p, name: 'Long gone', start: DateTime(2026, 3, 1)); // expired in April: not a win-back
      await _add(p, name: 'Birthday', dob: DateTime(1998, 10, 15));

      final expiring = p.reminderQueue(ReminderKind.expiring);
      expect(expiring.single.name, 'Sneha Pillai');
      expect(expiring.single.detail, 'Ends in 3 days');
      expect(expiring.single.message, allOf(contains('Sneha'), contains('18 Oct 2026'), contains('3 days left'), contains('9562277010')));
      expect(p.reminderQueue(ReminderKind.due).single.message, contains('₹500'));
      expect(p.reminderQueue(ReminderKind.expired).map((t) => t.name), ['Lapsed']);
      expect(p.reminderQueue(ReminderKind.birthday).single.detail, 'Turns 28 today');
      expect(ending.balanceDue, 500);
    });

    test('a sent reminder drops off the queue until its cooldown ends', () async {
      var now = _clockTime;
      final p = await _provider(clock: () => now);
      final m = await _add(p, start: DateTime(2026, 9, 18));
      final before = p.pendingReminderCount;
      await p.logReminder(ReminderKind.expiring, m.id);
      expect(p.reminderQueue(ReminderKind.expiring), isEmpty);
      expect(p.reminderQueue(ReminderKind.expiring, includeSent: true).single.sentRecently, isTrue);
      expect(p.pendingReminderCount, before - 1);
      now = now.add(const Duration(days: 3)); // cooldown for expiring is 3 days
      expect(p.reminderQueue(ReminderKind.expiring).single.id, m.id);
    });

    test('members who stopped coming show up as missing workouts', () async {
      var now = _clockTime;
      final p = await _provider(clock: () => now);
      final regular = await _add(p, name: 'Regular', start: DateTime(2026, 10, 1));
      await _add(p, name: 'Missing', start: DateTime(2026, 10, 1));
      now = DateTime(2026, 10, 14, 9);
      await p.checkIn(regular.id);
      now = _clockTime;
      expect(p.inactiveMembers.map((m) => m.name), ['Missing']); // 14 days since start, never came
    });

    test('custom templates are used and following up moves an enquiry to follow-up', () async {
      final p = await _provider();
      await p.updateSettings(p.settings.copyWith(templates: p.settings.templates.withText(ReminderKind.due, 'Pay {amount}, {name}!')));
      final m = await _add(p, name: 'Anu Mohan', paid: 1200);
      expect(p.messageFor(ReminderKind.due, m), 'Pay ₹300, Anu!');
      final e = await p.saveEnquiry(Enquiry(id: p.newEnquiryId(), name: 'Joel V', phone: '9123456780', createdAt: p.now, nextFollowUp: p.today));
      expect(p.reminderQueue(ReminderKind.followUp).single.message, contains('Joel'));
      await p.logReminder(ReminderKind.followUp, e.id);
      expect(p.enquiryById(e.id)!.status, EnquiryStatus.followUp);
      expect(p.enquiryById(e.id)!.lastContacted, isNotNull);
    });

    test('templates fill known placeholders and leave unknown ones', () {
      expect(fillTemplate('Hi {name}, {unknown}', {'{name}': 'Asha'}), 'Hi Asha, {unknown}');
    });
  });

  group('money and reports', () {
    test('income, expenses and profit by month', () async {
      final p = await _provider();
      await _add(p, planId: 'platinum-3m', fee: true); // 4500 today
      await p.addExpense(category: ExpenseCategory.rent, amount: 25000);
      final stats = p.statsFor(p.thisMonth);
      expect(stats.income, 4500);
      expect(stats.expenses, 25000);
      expect(stats.profit, -20500);
      expect(stats.admissions, 1);
      expect(p.monthlyStats(6).length, 6);
      expect(p.monthlyStats(6).first.income, 0);
      expect(p.incomeByMethod(p.thisMonth)[PayMethod.cash], 4500);
      expect(p.incomeToday, 4500);
    });

    test('this month is compared with the same days of last month', () async {
      var now = DateTime(2026, 9, 10, 12);
      final p = await _provider(clock: () => now);
      final m = await _add(p, paid: 1000); // 10 Sep
      now = DateTime(2026, 9, 25, 12);
      await p.recordPayment(m.id, amount: 500); // after the cut-off day, must not count
      now = _clockTime; // 15 Oct
      await p.recordPayment(m.id, amount: 1, kind: PaymentKind.other);
      await _add(p, name: 'B', paid: 1500);
      expect(p.incomeChangeToDate, closeTo((1501 - 1000) / 1000, 0.0001));
    });

    test('year-over-year pairs each month with the same month last year', () async {
      final p = await _provider();
      final yoy = p.yearOverYear();
      expect(yoy.length, 12);
      expect(yoy.last.$1, DateTime(2026, 10));
    });

    test('renewal rate counts memberships renewed within 15 days of ending', () async {
      var now = DateTime(2026, 8, 1, 10);
      final p = await _provider(clock: () => now);
      final a = await _add(p, name: 'Renews'); // ends 1 Sep
      await _add(p, name: 'Leaves'); // ends 1 Sep
      now = DateTime(2026, 9, 5, 10);
      await p.renew(a.id, planId: 'silver-1m', amountPaid: 1500);
      now = _clockTime;
      expect(p.renewalRate(DateTime(2026, 9)), 0.5);
      expect(p.renewalRate(DateTime(2026, 5)), isNull);
    });

    test('salary is paid once per month and appears as an expense', () async {
      final p = await _provider();
      await p.saveTrainer(const Trainer(id: 't-x', name: 'Coach', speciality: 'Boxing', phone: '1', monthlySalary: 15000));
      expect(await p.paySalary('t-x', p.thisMonth), isTrue);
      expect(await p.paySalary('t-x', p.thisMonth), isFalse);
      expect(p.salaryPaid('t-x', p.thisMonth), isTrue);
      expect(p.expensesIn(p.thisMonth), 15000);
    });

    test('busy hours average check-ins per weekday and hour', () async {
      final p = await _provider();
      final m = await _add(p);
      await p.checkIn(m.id); // Thursday 10:30
      final grid = p.busyHours(days: 7);
      expect(grid[DateTime.thursday - 1][10 - heatmapFirstHour], 1);
    });

    test('receipt text lists each line and the total', () async {
      final p = await _provider();
      final r = await p.admit(name: 'Sneha Pillai', phone: '9876543210', gender: Gender.female, planId: 'silver-1m', amountPaid: 2000);
      final text = p.receiptText(r.receiptNo!);
      expect(text, allOf(contains('RCPT-00001'), contains('Admission fee: ₹500'), contains('Total paid: ₹2,000'), contains('UFG-0001')));
    });

    test('CSV export has a header and one row per member', () async {
      final p = await _provider();
      await _add(p, name: 'Sneha Pillai');
      final csv = p.exportMembersCsv();
      expect(csv, startsWith('code,name,phone'));
      expect(csv, contains('UFG-0001,"Sneha Pillai"'));
    });

    test('UPI link carries the payee and amount; demo data and a missing ID use the safe sample', () async {
      final p = await _provider();
      await p.updateSettings(p.settings.copyWith(upiId: 'gym@okaxis'));
      expect(p.upiIsDemo, isFalse);
      expect(p.upiLink(500), allOf(startsWith('upi://pay?'), contains('pa=gym%40okaxis'), contains('am=500.00'), contains('cu=INR')));
      await p.loadDemoData();
      expect(p.upiIsDemo, isTrue);
      expect(p.upiLink(500), contains('pa=unique.fitness%40example'));
      await p.resetAll();
      await p.updateSettings(p.settings.copyWith(upiId: ''));
      expect(p.upiIsDemo, isTrue);
    });

    test('the last payment method is offered first next time', () async {
      final p = await _provider();
      expect(p.lastPayMethod, PayMethod.cash);
      final m = await _add(p, paid: 1000);
      await p.recordPayment(m.id, amount: 500, method: PayMethod.upi);
      expect(p.lastPayMethod, PayMethod.upi);
    });
  });

  group('owner PIN', () {
    test('locks owner areas until the right PIN is entered', () async {
      final p = await _provider();
      expect(p.ownerUnlocked, isTrue);
      await p.setPin('2580');
      expect(p.settings.pinHash, isNot(contains('2580')));
      p.lock();
      expect(p.ownerUnlocked, isFalse);
      expect(p.unlock('1111'), isFalse);
      expect(p.unlock('2580'), isTrue);
      expect(p.ownerUnlocked, isTrue);
      await p.clearPin();
      p.lock();
      expect(p.ownerUnlocked, isTrue);
      expect(() => p.setPin('12ab'), throwsArgumentError);
    });
  });

  group('data safety', () {
    test('deleting a member removes personal data but keeps payments in the books', () async {
      final p = await _provider();
      final m = await _add(p);
      await p.checkIn(m.id);
      await p.addMeasurement(m.id, weightKg: 70);
      await p.deleteMember(m.id);
      expect(p.members, isEmpty);
      expect(p.checkInsToday, isEmpty);
      expect(p.measurements, isEmpty);
      expect(p.incomeThisMonth, 1500);
    });

    test('a plan in use cannot be deleted', () async {
      final p = await _provider();
      await _add(p, planId: 'silver-1m');
      expect(await p.deletePlan('silver-1m'), isFalse);
      expect(await p.deletePlan('platinum-12m'), isTrue);
    });

    test('deleting a trainer clears them from members and classes', () async {
      final p = await _provider();
      await p.saveTrainer(const Trainer(id: 't-x', name: 'Coach', speciality: 'Boxing', phone: '1'));
      final m = await _add(p);
      await p.updateMember(m.copyWith(trainerId: 't-x'));
      await p.saveClass(p.classes.first.copyWith(trainerId: 't-x'));
      await p.deleteTrainer('t-x');
      expect(p.memberById(m.id)!.trainerId, isNull);
      expect(p.classes.first.trainerId, isNull);
    });

    test('backup and restore bring everything back, photos included', () async {
      final p = await _provider();
      final r = await p.admit(name: 'Backed Up', phone: '9876543210', gender: Gender.male, planId: 'silver-1m', amountPaid: 1500, photo: Uint8List.fromList([9, 8, 7]));
      await p.addExpense(category: ExpenseCategory.rent, amount: 100);
      final backup = await p.exportBackup();

      final fresh = await _provider();
      expect(await fresh.restoreBackup(backup), 1);
      expect(fresh.members.single.name, 'Backed Up');
      expect(fresh.expenses.single.amount, 100);
      expect(await fresh.loadPhoto(r.member.id), [9, 8, 7]);
      final next = await _add(fresh, name: 'After restore');
      expect(next.number, 2); // counters restored too
    });

    test('an invalid backup is refused and nothing changes', () async {
      final p = await _provider();
      await _add(p);
      expect(() => p.restoreBackup('not json'), throwsFormatException);
      expect(() => p.restoreBackup('{"app":"other","data":{}}'), throwsFormatException);
      expect(p.members.length, 1);
    });

    test('demo data is flagged so nobody real gets messaged, and reset clears the flag', () async {
      final p = await _provider();
      expect(p.settings.demoData, isFalse);
      await p.loadDemoData();
      expect(p.settings.demoData, isTrue);
      await p.resetAll();
      expect(p.settings.demoData, isFalse);
    });

    test('resetAll clears members but keeps the gym settings', () async {
      final p = await _provider();
      await p.updateSettings(p.settings.copyWith(ownerName: 'Boss'));
      await _add(p);
      await p.resetAll();
      expect(p.hasMembers, isFalse);
      expect(p.settings.ownerName, 'Boss');
    });

    test('damaged JSON fields fall back instead of crashing', () {
      final m = Member.fromJson({'id': 'x', 'name': 'Odd', 'startDate': 'garbage', 'number': 'seven', 'freezes': 'nope'});
      expect(m.name, 'Odd');
      expect(m.number, 0);
      expect(m.freezes, isEmpty);
    });
  });
}
