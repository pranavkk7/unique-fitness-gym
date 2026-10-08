import 'package:flutter_test/flutter_test.dart';
import 'package:unique_fitness_gym/data/gym_store.dart';
import 'package:unique_fitness_gym/models/models.dart';
import 'package:unique_fitness_gym/providers/gym_provider.dart';

// Business rules for the front-desk extras, revenue and engagement features.

final _now = DateTime(2026, 10, 15, 10, 30);

Future<GymProvider> _provider({GymStore? store, DateTime Function()? clock}) async {
  final p = GymProvider(store: store ?? MemoryGymStore(), clock: clock ?? () => _now);
  await p.init();
  return p;
}

Future<Member> _add(GymProvider p, {String name = 'Member', String? referredById, String? offerId, double? paid}) async =>
    (await p.admit(name: name, phone: '9876543210', gender: Gender.male, planId: 'silver-1m', amountPaid: paid ?? 1500, referredById: referredById, offerId: offerId)).member;

void main() {
  group('referrals and offers', () {
    test('the referrer gets bonus days added to their membership', () async {
      final p = await _provider();
      final a = await _add(p, name: 'Referrer');
      final b = await _add(p, name: 'Friend', referredById: a.id);
      expect(p.memberById(a.id)!.endDate, a.endDate.add(Duration(days: p.settings.referralRewardDays)));
      expect(p.memberById(b.id)!.referredById, a.id);
      expect(p.referralsBy(a.id).map((m) => m.name), ['Friend']);
    });

    test('offer codes check dates and limits, and count each use', () async {
      final p = await _provider();
      await p.saveOffer(Offer(id: 'o1', code: 'ONAM10', value: 10, validUntil: DateTime(2026, 10, 31), maxUses: 1));
      await p.saveOffer(Offer(id: 'o2', code: 'OLD', value: 10, validUntil: DateTime(2026, 9, 30)));
      await p.saveOffer(const Offer(id: 'o3', code: 'FLAT500', percent: false, value: 500));

      expect(p.checkOffer('onam10 ', 1500).discount, 150); // case and spaces do not matter
      expect(p.checkOffer('FLAT500', 300).discount, 300); // never more than the price
      expect(p.checkOffer('OLD', 1500).error, contains('ended'));
      expect(p.checkOffer('NOPE', 1500).error, isNotNull);
      expect(p.checkOffer('', 1500).error, isNull);

      await _add(p, offerId: 'o1', paid: 1350);
      expect(p.offers.firstWhere((o) => o.id == 'o1').used, 1);
      expect(p.checkOffer('ONAM10', 1500).error, contains('used up'));
      expect(() => p.saveOffer(const Offer(id: 'o4', code: 'FLAT500', value: 5)), throwsArgumentError);
    });
  });

  group('day passes and trials', () {
    test('a day pass is a payment by a non-member plus a lead to follow up', () async {
      final p = await _provider();
      final pay = await p.sellDayPass(name: 'Visitor', phone: '9000000000', amount: 150);
      expect(pay.memberId, isEmpty);
      expect(pay.kind, PaymentKind.dayPass);
      expect(p.payerOf(pay), 'Visitor');
      expect(p.receiptText(pay.receiptNo), contains('Name: Visitor'));
      final lead = p.enquiries.single;
      expect(lead.status, EnquiryStatus.trial);
      expect(lead.nextFollowUp, DateTime(2026, 10, 16));
      expect(p.recentActivity().any((a) => a.title == 'Visitor' && a.memberId == null), isTrue);
    });

    test('a free trial is followed up when it ends', () async {
      final p = await _provider();
      final e = await p.startTrial(name: 'Trial Person', phone: '9000000001');
      expect(e.nextFollowUp, DateTime(2026, 10, 15 + p.settings.trialDays));
      expect(p.payments, isEmpty);
    });
  });

  group('personal training', () {
    test('sessions are counted, expire, and earn the trainer commission', () async {
      final p = await _provider();
      final m = await _add(p);
      await p.saveTrainer(p.trainers.first.copyWith(commissionPct: 40));
      final t = p.trainers.first;
      final (pkg, pay) = await p.sellPtPackage(m.id, trainerId: t.id, sessions: 2, price: 1000, amountPaid: 1000);
      expect(pay!.kind, PaymentKind.personalTraining);
      expect(p.memberById(m.id)!.balanceDue, 0);

      expect(await p.usePtSession(pkg.id), isTrue);
      expect(await p.usePtSession(pkg.id), isTrue);
      expect(await p.usePtSession(pkg.id), isFalse); // none left
      expect(p.trainerEarnings(t.id, _now), 400); // 2 × ₹500 × 40%
      await p.undoPtSession(pkg.id);
      expect(p.activePtPackage(m.id)!.left, 1);
    });

    test('an unpaid package adds to the balance due', () async {
      final p = await _provider();
      final m = await _add(p);
      await p.sellPtPackage(m.id, trainerId: p.trainers.first.id, sessions: 8, price: 4000, amountPaid: 1000);
      expect(p.memberById(m.id)!.balanceDue, 3000);
    });
  });

  group('shop', () {
    test('a sale takes stock, records a payment, and refuses to oversell', () async {
      final p = await _provider();
      await p.saveProduct(const Product(id: 'water', name: 'Water', price: 20, stock: 3, lowStockAt: 1));
      final sale = await p.sell({'water': 2}, buyerName: 'Walk-in');
      expect(sale.total, 40);
      expect(p.productById('water')!.stock, 1);
      expect(p.lowStock.map((x) => x.id), ['water']);
      final pay = p.paymentsOnReceipt(sale.receiptNo).single;
      expect(pay.kind, PaymentKind.product);
      expect(pay.payerName, 'Walk-in');
      expect(() => p.sell({'water': 5}), throwsStateError);
      expect(p.productById('water')!.stock, 1); // unchanged after the refused sale
    });

    test('restocking with a cost also books the expense', () async {
      final p = await _provider();
      await p.saveProduct(const Product(id: 'bar', name: 'Bar', price: 90));
      await p.restock('bar', 10, unitCost: 60);
      expect(p.productById('bar')!.stock, 10);
      expect(p.expenses.single.amount, 600);
    });
  });

  group('class batches', () {
    test('members join until the batch is full', () async {
      final p = await _provider();
      final c = p.classes.first;
      await p.saveClass(c.copyWith(capacity: 1));
      final a = await _add(p, name: 'A');
      final b = await _add(p, name: 'B');
      expect(await p.enrollInClass(c.id, a.id), isTrue);
      expect(await p.enrollInClass(c.id, b.id), isFalse);
      expect(p.classesOf(a.id).single.id, c.id);
      await p.removeFromClass(c.id, a.id);
      expect(await p.enrollInClass(c.id, b.id), isTrue);
    });
  });

  group('closing the day', () {
    test('expected cash is cash in minus cash spent, and closing again replaces the count', () async {
      final p = await _provider();
      await _add(p, paid: 1500); // cash
      await p.addExpense(category: ExpenseCategory.supplies, amount: 200);
      final s = p.daySummary();
      expect(s.cash, 1500);
      expect(s.cashOut, 200);
      expect(s.admissions, 1);

      final first = await p.closeDay(counted: 1200);
      expect(first.difference, -100);
      final again = await p.closeDay(counted: 1300);
      expect(again.difference, 0);
      expect(p.dayCloses.length, 1);
    });
  });

  group('plans and feedback', () {
    test('plans are assigned per kind and cleared when deleted', () async {
      final p = await _provider();
      expect(p.trainingPlans, isNotEmpty); // starter templates
      final m = await _add(p);
      final workout = p.trainingPlans.firstWhere((x) => x.kind == TrainingPlanKind.workout);
      final diet = p.trainingPlans.firstWhere((x) => x.kind == TrainingPlanKind.diet);
      await p.assignTrainingPlan(m.id, TrainingPlanKind.workout, workout.id);
      await p.assignTrainingPlan(m.id, TrainingPlanKind.diet, diet.id);
      expect(p.memberById(m.id)!.workoutPlanId, workout.id);
      await p.deleteTrainingPlan(workout.id);
      expect(p.memberById(m.id)!.workoutPlanId, isNull);
      expect(p.memberById(m.id)!.dietPlanId, diet.id);
    });

    test('low ratings need action until resolved; the average covers recent feedback', () async {
      final p = await _provider();
      final bad = await p.addFeedback(name: 'A', rating: 2, category: FeedbackCategory.timing);
      await p.addFeedback(name: 'B', rating: 5);
      expect(bad.needsAction, isTrue);
      expect(p.averageRating(), 3.5);
      await p.resolveFeedback(bad.id, response: 'Added a second batch');
      expect(p.feedback.firstWhere((f) => f.id == bad.id).needsAction, isFalse);
      expect(() => p.addFeedback(name: 'C', rating: 6), throwsArgumentError);
    });
  });

  group('reports and notifications', () {
    test('a progress report counts visits, streaks and weight change for the month', () async {
      var now = DateTime(2026, 10, 1, 7);
      final p = await _provider(clock: () => now);
      final m = await _add(p);
      await p.addMeasurement(m.id, weightKg: 80);
      for (final day in [1, 2, 3, 6, 8]) {
        now = DateTime(2026, 10, day, 7);
        await p.checkIn(m.id);
      }
      await p.addMeasurement(m.id, weightKg: 78.5);
      now = DateTime(2026, 10, 15, 10);
      final r = p.progressReport(m.id, DateTime(2026, 10));
      expect(r.visits, 5);
      expect(r.bestStreak, 3);
      expect(r.weeklyVisits.take(2), [4, 1]);
      expect(r.weightChange, closeTo(-1.5, 0.001));
      final text = p.progressText(r);
      expect(text, contains('Workouts: 5'));
      expect(text, contains('-1.5 kg'));
      expect(p.reminderQueue(ReminderKind.progress).map((t) => t.id), [m.id]);
      await p.logReminder(ReminderKind.progress, m.id);
      expect(p.reminderQueue(ReminderKind.progress), isEmpty);
    });

    test('the morning summary lists what needs doing, or nothing on a quiet day', () async {
      final p = await _provider();
      expect(p.morningDigest(DateTime(2026, 10, 16)), isNull);
      await _add(p, paid: 1000); // ₹500 due
      final digest = p.morningDigest(DateTime(2026, 10, 16))!;
      expect(digest.body, contains('1 with dues'));
      expect(p.morningDigest(DateTime(2026, 11, 13))!.body, contains('1 plan ending soon'));
    });
  });

  test('demo data fills every new feature and survives a restart', () async {
    final store = MemoryGymStore();
    final p = await _provider(store: store);
    await p.loadDemoData();
    expect(p.products, isNotEmpty);
    expect(p.lowStock, isNotEmpty);
    expect(p.sales, isNotEmpty);
    expect(p.ptPackages, isNotEmpty);
    expect(p.offers, isNotEmpty);
    expect(p.dayCloses, isNotEmpty);
    expect(p.feedback.where((f) => f.needsAction), isNotEmpty);
    expect(p.classes.every((c) => c.memberIds.length <= c.capacity), isTrue);
    expect(p.members.where((m) => m.referredById != null), isNotEmpty);
    expect(p.payments.where((x) => x.kind == PaymentKind.dayPass).every((x) => x.payerName.isNotEmpty), isTrue);
    expect(p.trainerEarnings('t-floor', _now), greaterThan(0));

    final again = await _provider(store: store);
    expect(again.sales.length, p.sales.length);
    expect(again.trainingPlans.length, p.trainingPlans.length);
  });
}
