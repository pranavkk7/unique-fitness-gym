import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:unique_fitness_gym/core/utils/format.dart';
import 'package:unique_fitness_gym/data/gym_store.dart';
import 'package:unique_fitness_gym/data/hive_gym_store.dart';
import 'package:unique_fitness_gym/data/seed_data.dart';
import 'package:unique_fitness_gym/models/models.dart';
import 'package:unique_fitness_gym/providers/gym_provider.dart';

final _now = DateTime(2026, 10, 15, 18, 0);

void main() {
  group('demo data', () {
    late GymProvider p;

    setUp(() async {
      p = GymProvider(store: MemoryGymStore(), clock: () => _now);
      await p.init();
      await p.loadDemoData();
    });

    test('is consistent: nothing is paid, joined or checked in after now', () {
      for (final m in p.members) {
        expect(m.joinDate.isAfter(_now), isFalse, reason: m.name);
        expect(m.endDate.isAfter(m.startDate), isTrue, reason: m.name);
      }
      for (final pay in p.payments) {
        expect(pay.date.isAfter(_now), isFalse, reason: pay.receiptNo);
      }
      for (final c in p.checkIns) {
        expect(c.time.isAfter(_now), isFalse);
      }
      expect(p.payments.map((x) => x.id).toSet().length, p.payments.length);
    });

    test('shows every status and fills every reminder list', () {
      expect(p.members.map(p.statusOf).toSet(), containsAll(MemberStatus.values));
      for (final kind in GymMessages.queueKinds) {
        expect(p.reminderQueue(kind), isNotEmpty, reason: kind.label);
      }
      expect(p.birthdaysToday.length, greaterThanOrEqualTo(2)); // two are set on purpose; a random one can match too
    });

    test('has two years of income and expenses for the comparison charts', () {
      final yoy = p.yearOverYear();
      expect(yoy.where((m) => m.$2 > 0).length, 12);
      expect(yoy.where((m) => m.$3 > 0).length, greaterThanOrEqualTo(10));
      expect(p.monthlyStats(12).every((s) => s.expenses > 0), isTrue);
      expect(p.incomeThisMonth, greaterThan(0));
      expect(p.activeCount, inInclusiveRange(40, 140));
    });

    test('is the same every time for the same clock', () async {
      final again = GymProvider(store: MemoryGymStore(), clock: () => _now);
      await again.init();
      await again.loadDemoData();
      expect(again.members.length, p.members.length);
      expect(again.incomeThisMonth, p.incomeThisMonth);
      expect(again.members.last.name, p.members.last.name);
    });

    test('counters continue after the demo data', () async {
      final r = await p.admit(name: 'New', phone: '9876543210', gender: Gender.male, planId: 'silver-1m', amountPaid: 1500);
      expect(r.member.number, p.members.length);
      expect(memberCode(r.member.number), isNot('UFG-0001'));
    });
  });

  group('Hive store', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ufg_hive_');
      Hive.init(dir.path);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('first launch returns null, then data and photos round-trip', () async {
      final store = HiveGymStore();
      expect(await store.load(), isNull);

      final data = demoData(now: _now);
      await store.replaceAll(data, photos: {'m-1': Uint8List.fromList([1, 2, 3])});
      final m = data.members.first;
      await store.put(Collections.members, m.id, m.copyWith(name: 'Renamed').toJson());
      await store.delete(Collections.enquiries, data.enquiries.first.id);

      final loaded = (await store.load())!;
      expect(loaded.members.length, data.members.length);
      expect(loaded.members.firstWhere((x) => x.id == m.id).name, 'Renamed');
      expect(loaded.enquiries.length, data.enquiries.length - 1);
      expect(loaded.payments.length, data.payments.length);
      expect(loaded.nextMemberNumber, data.nextMemberNumber);
      expect(await store.loadPhoto('m-1'), [1, 2, 3]);
      expect((await store.allPhotos()).keys, ['m-1']);
    });

    test('a damaged record is skipped instead of stopping the app', () async {
      final store = HiveGymStore();
      await store.replaceAll(baseSetup());
      await Hive.box<String>('ufg_members').put('bad', '{not json');
      final loaded = (await store.load())!;
      expect(loaded.members, isEmpty);
      expect(loaded.plans, isNotEmpty);
    });
  });
}
