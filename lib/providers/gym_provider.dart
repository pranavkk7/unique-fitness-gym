import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/format.dart';
import '../data/gym_store.dart';
import '../data/seed_data.dart';
import '../models/models.dart';

export 'gym_analytics.dart';
export 'gym_messages.dart';
export 'gym_reports.dart';

part 'gym_desk.dart';
part 'gym_memberships.dart';
part 'gym_records.dart';
part 'gym_sales.dart';
part 'gym_setup.dart';

enum CheckInOutcome { recorded, duplicateToday, blockedExpired, blockedFrozen }

/// What an admission created: the member, and the payments taken at the desk (one receipt).
class AdmissionResult {
  final Member member;
  final List<Payment> payments;

  const AdmissionResult(this.member, this.payments);

  String? get receiptNo => payments.isEmpty ? null : payments.first.receiptNo;
}

/// All gym data and business rules. This file holds the state, loading and saving, member status,
/// check-ins and the Face ID door; the rest is split by area into part files, each an extension
/// with access to the same private state:
///
/// * `gym_memberships.dart`: admissions, renewals, freezes, payments
/// * `gym_sales.dart`: offers, referrals, day passes, personal training, the shop
/// * `gym_desk.dart`: class batches, closing the day, workout and diet plans, feedback
/// * `gym_records.dart`: photos, body checks, enquiries, expenses, reminder logs
/// * `gym_setup.dart`: plans, trainers, classes, settings, owner PIN, backup
///
/// Screens read state from here with Provider and call its methods to change it. Each change writes
/// only the records it touched. The clock is injectable so every date rule can be tested.
class GymProvider extends ChangeNotifier {
  final GymStore _store;
  final DateTime Function() _clock;

  GymProvider({required this._store, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  List<Branch> _branches = [];
  List<Plan> _plans = [];
  List<Trainer> _trainers = [];
  List<Member> _members = [];
  List<Subscription> _subscriptions = [];
  List<Payment> _payments = [];
  List<Expense> _expenses = [];
  List<CheckIn> _checkIns = [];
  List<GymClass> _classes = [];
  List<Enquiry> _enquiries = [];
  List<Measurement> _measurements = [];
  List<ReminderLog> _reminders = [];
  List<PtPackage> _ptPackages = [];
  List<Product> _products = [];
  List<Sale> _sales = [];
  List<Offer> _offers = [];
  List<DayClose> _dayCloses = [];
  List<TrainingPlan> _trainingPlans = [];
  List<FeedbackEntry> _feedback = [];
  GymSettings _settings = const GymSettings();
  int _nextMemberNumber = 1;
  int _nextReceiptNumber = 1;
  int _idCounter = 0;
  bool _loaded = false;
  bool _unlocked = false;

  /// The method used for the last payment, pre-selected for the next one (most desks use one most of the day).
  PayMethod lastPayMethod = PayMethod.cash;

  final _pending = <Future<void> Function()>[];
  bool _metaDirty = false;
  final Map<String, Uint8List?> _photoCache = {};

  // Derived values (last visits, today's check-ins) are cached until the data or the day changes,
  // so long lists stay fast however many years of check-ins build up.
  int _version = 0;
  int _memoVersion = -1;
  DateTime? _memoDay;
  final Map<String, Object> _memo = {};

  T _cached<T extends Object>(String key, T Function() build) {
    final day = today;
    if (_memoVersion != _version || _memoDay != day) {
      _memo.clear();
      _memoVersion = _version;
      _memoDay = day;
    }
    return _memo.putIfAbsent(key, build) as T;
  }
  final Map<String, Future<Uint8List?>> _photoLoads = {};

  // ---- basic getters -----------------------------------------------------------------

  bool get loaded => _loaded;
  DateTime get now => _clock();
  DateTime get today => dateOnly(_clock());
  GymSettings get settings => _settings;
  Branch get branch => _branches.firstOrNull ?? pinarayi;
  List<Plan> get plans => List.unmodifiable(_plans);
  List<Plan> get activePlans => _plans.where((p) => p.active).toList();
  List<Trainer> get trainers => List.unmodifiable(_trainers);
  List<GymClass> get classes => List.unmodifiable(_classes);
  List<Member> get members => List.unmodifiable(_members);
  List<Subscription> get subscriptions => List.unmodifiable(_subscriptions);
  List<Payment> get payments => List.unmodifiable(_payments);
  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<CheckIn> get checkIns => List.unmodifiable(_checkIns);
  List<Enquiry> get enquiries => List.unmodifiable(_enquiries);
  List<Measurement> get measurements => List.unmodifiable(_measurements);
  List<ReminderLog> get reminderLogs => List.unmodifiable(_reminders);
  List<PtPackage> get ptPackages => List.unmodifiable(_ptPackages);
  List<Product> get products => List.unmodifiable(_products);
  List<Sale> get sales => List.unmodifiable(_sales);
  List<Offer> get offers => List.unmodifiable(_offers);
  List<DayClose> get dayCloses => List.unmodifiable(_dayCloses);
  List<TrainingPlan> get trainingPlans => List.unmodifiable(_trainingPlans);
  List<FeedbackEntry> get feedback => List.unmodifiable(_feedback);
  /// Who paid: the member's name, or the walk-in name saved on the payment.
  String payerOf(Payment p) => p.payerName.isNotEmpty ? p.payerName : memberById(p.memberId)?.name ?? 'Former member';
  Product? productById(String? id) => _products.where((p) => p.id == id).firstOrNull;
  TrainingPlan? trainingPlanById(String? id) => _trainingPlans.where((p) => p.id == id).firstOrNull;
  bool get hasMembers => _members.isNotEmpty;

  Plan? planById(String? id) => _plans.where((p) => p.id == id).firstOrNull;
  Trainer? trainerById(String? id) => _trainers.where((t) => t.id == id).firstOrNull;
  Member? memberById(String? id) => _members.where((m) => m.id == id).firstOrNull;
  Enquiry? enquiryById(String? id) => _enquiries.where((e) => e.id == id).firstOrNull;

  // ---- loading and saving --------------------------------------------------------------

  Future<void> init() async {
    final saved = await _store.load();
    _apply(saved ?? baseSetup());
    _loaded = true;
    notifyListeners();
    if (saved == null) await _store.replaceAll(baseSetup());
  }

  void _apply(GymData d) {
    _branches = [...d.branches];
    _plans = [...d.plans];
    _trainers = [...d.trainers];
    _members = [...d.members];
    _subscriptions = [...d.subscriptions];
    _payments = [...d.payments];
    _expenses = [...d.expenses];
    _checkIns = [...d.checkIns];
    _classes = [...d.classes];
    _enquiries = [...d.enquiries];
    _measurements = [...d.measurements];
    _reminders = [...d.reminders];
    _ptPackages = [...d.ptPackages];
    _products = [...d.products];
    _sales = [...d.sales];
    _offers = [...d.offers];
    _dayCloses = [...d.dayCloses];
    _trainingPlans = [...d.trainingPlans];
    _feedback = [...d.feedback];
    _settings = d.settings;
    _nextMemberNumber = d.nextMemberNumber;
    _nextReceiptNumber = d.nextReceiptNumber;
    _photoCache.clear();
    _photoLoads.clear();
    _version++;
  }

  GymData get snapshot => GymData(
        branches: _branches,
        plans: _plans,
        trainers: _trainers,
        members: _members,
        subscriptions: _subscriptions,
        payments: _payments,
        expenses: _expenses,
        checkIns: _checkIns,
        classes: _classes,
        enquiries: _enquiries,
        measurements: _measurements,
        reminders: _reminders,
        ptPackages: _ptPackages,
        products: _products,
        sales: _sales,
        offers: _offers,
        dayCloses: _dayCloses,
        trainingPlans: _trainingPlans,
        feedback: _feedback,
        settings: _settings,
        nextMemberNumber: _nextMemberNumber,
        nextReceiptNumber: _nextReceiptNumber,
      );

  void _put(String collection, String id, Map<String, dynamic> json) => _pending.add(() => _store.put(collection, id, json));

  void _delete(String collection, String id) => _pending.add(() => _store.delete(collection, id));

  /// Refreshes the screens for a change that has nothing to save (the owner PIN lock). The part
  /// files are extensions, which may not call [notifyListeners] directly.
  void _notify() => notifyListeners();

  /// Updates the screens first, then writes the queued records.
  Future<void> _commit() async {
    _version++;
    notifyListeners();
    final ops = [..._pending];
    _pending.clear();
    for (final op in ops) {
      await op();
    }
    if (_metaDirty) {
      _metaDirty = false;
      await _store.putMeta(settings: _settings, nextMemberNumber: _nextMemberNumber, nextReceiptNumber: _nextReceiptNumber);
    }
  }

  String _newId(String prefix) => '$prefix-${_clock().microsecondsSinceEpoch}-${_idCounter++}';

  /// Fills the app with fictional members and history. The gym's own settings are kept.
  Future<void> loadDemoData() => _replaceAll(demoData(now: _clock()).copyWith(settings: _settings.copyWith(demoData: true)));

  /// Removes members, payments, check-ins and everything else, then restores the default plans and
  /// timetable. The gym's settings (name, phone, PIN, templates) are kept.
  Future<void> resetAll() => _replaceAll(baseSetup().copyWith(settings: _settings.copyWith(demoData: false)));

  Future<void> _replaceAll(GymData data, {Map<String, Uint8List> photos = const {}}) async {
    _pending.clear();
    _apply(data);
    notifyListeners();
    await _store.replaceAll(data, photos: photos);
  }

  // ---- member status -----------------------------------------------------------------

  /// Days until the membership ends. Zero means it ends today; negative means it has expired.
  int daysLeft(Member m) => dateOnly(m.endDate).difference(today).inDays;

  MemberStatus statusOf(Member m) {
    if (m.freezeOn(today) != null) return MemberStatus.frozen;
    final left = daysLeft(m);
    if (left < 0) return MemberStatus.expired;
    if (left <= _settings.expiryAlertDays) return MemberStatus.expiringSoon;
    return MemberStatus.active;
  }

  /// A membership still running (active, expiring soon or frozen).
  bool isRunning(Member m) => statusOf(m) != MemberStatus.expired;

  /// Fraction of the membership period already used, 0 to 1. Drives the progress ring.
  double progressOf(Member m) {
    final total = dateOnly(m.endDate).difference(dateOnly(m.startDate)).inDays;
    if (total <= 0) return 1;
    final used = today.difference(dateOnly(m.startDate)).inDays;
    return (used / total).clamp(0.0, 1.0);
  }

  // ---- member lists ------------------------------------------------------------------

  List<Member> searchMembers({String query = '', MemberStatus? status, bool onlyDue = false}) {
    final q = query.trim().toLowerCase();
    final digits = digitsOnly(query);
    final result = _members.where((m) {
      if (status != null && statusOf(m) != status) return false;
      if (onlyDue && m.balanceDue <= 0) return false;
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) ||
          memberCode(m.number).toLowerCase().contains(q) ||
          (digits.length >= 3 && digitsOnly(m.phone).contains(digits));
    }).toList();
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  int get activeCount => _members.where(isRunning).length;

  int countWithStatus(MemberStatus s) => _members.where((m) => statusOf(m) == s).length;

  List<Member> get expiringSoon => _members.where((m) => statusOf(m) == MemberStatus.expiringSoon).toList()..sort((a, b) => a.endDate.compareTo(b.endDate));

  List<Member> get membersWithDue => _members.where((m) => m.balanceDue > 0).toList()..sort((a, b) => b.balanceDue.compareTo(a.balanceDue));

  double get totalDue => _members.fold(0.0, (s, m) => s + m.balanceDue);

  int get newThisMonth => _members.where((m) => sameMonth(m.joinDate, today)).length;

  List<Member> get birthdaysToday =>
      _members.where((m) => m.dateOfBirth != null && m.dateOfBirth!.month == today.month && m.dateOfBirth!.day == today.day && daysLeft(m) > -90).toList();

  // ---- check-ins ---------------------------------------------------------------------

  List<CheckIn> get checkInsToday =>
      _cached('today', () => List<CheckIn>.unmodifiable(_checkIns.where((c) => sameDay(c.time, today)).toList()..sort((a, b) => b.time.compareTo(a.time))));

  List<CheckIn> checkInsFor(String memberId) => _checkIns.where((c) => c.memberId == memberId).toList()..sort((a, b) => b.time.compareTo(a.time));

  bool checkedInToday(String memberId) => _cached('todayIds', () => {for (final c in checkInsToday) c.memberId}).contains(memberId);

  DateTime? lastVisit(String memberId) => _cached('lastVisits', () {
        final last = <String, DateTime>{};
        for (final c in _checkIns) {
          final seen = last[c.memberId];
          if (seen == null || c.time.isAfter(seen)) last[c.memberId] = c.time;
        }
        return last;
      })[memberId];

  Future<CheckInOutcome> checkIn(String memberId, {bool allowExpired = false, CheckInSource source = CheckInSource.desk}) async {
    final member = memberById(memberId);
    if (member == null) throw ArgumentError('Unknown member $memberId');
    if (checkedInToday(memberId)) return CheckInOutcome.duplicateToday;
    final status = statusOf(member);
    if (status == MemberStatus.frozen && !allowExpired) return CheckInOutcome.blockedFrozen;
    if (status == MemberStatus.expired && !allowExpired) return CheckInOutcome.blockedExpired;
    final c = CheckIn(id: _newId('ci'), memberId: memberId, time: _clock(), source: source);
    _checkIns.add(c);
    _put(Collections.checkIns, c.id, c.toJson());
    await _commit();
    return CheckInOutcome.recorded;
  }

  Future<void> undoCheckIn(String checkInId) async {
    _checkIns.removeWhere((c) => c.id == checkInId);
    _delete(Collections.checkIns, checkInId);
    await _commit();
  }

  // ---- Face ID terminal ---------------------------------------------------------------

  /// Whether the terminal should let this member in: a running, unfrozen plan, and no unpaid
  /// balance when the gym blocks dues at the door.
  bool doorAccessAllowed(Member m) {
    final s = statusOf(m);
    if (s == MemberStatus.expired || s == MemberStatus.frozen) return !_settings.blockExpiredAtDoor;
    if (_settings.blockDuesAtDoor && m.balanceDue > 0) return false;
    return true;
  }

  Member? memberByDeviceId(String userId) => _members.where((m) => m.deviceUserId == userId).firstOrNull;

  /// Links a member to their ID on the terminal (or unlinks with null).
  Future<void> linkDevice(String memberId, String? deviceUserId, {bool? faceEnrolled}) async {
    final i = _members.indexWhere((m) => m.id == memberId);
    if (i == -1) return;
    // One device ID belongs to one member.
    if (deviceUserId != null) {
      for (var j = 0; j < _members.length; j++) {
        if (j != i && _members[j].deviceUserId == deviceUserId) {
          _members[j] = _members[j].copyWith(clearDevice: true);
          _put(Collections.members, _members[j].id, _members[j].toJson());
        }
      }
    }
    _members[i] = deviceUserId == null ? _members[i].copyWith(clearDevice: true) : _members[i].copyWith(deviceUserId: deviceUserId, faceEnrolled: faceEnrolled);
    _put(Collections.members, memberId, _members[i].toJson());
    await _commit();
  }

  /// Turns door entries from the terminal into check-ins: the first entry of each member each day
  /// counts, entries already recorded are skipped, and IDs not linked to a member are counted.
  Future<({int imported, int unknown})> importDeviceEntries(List<({String userId, DateTime time})> entries) async {
    var imported = 0;
    final unknown = <String>{};
    final sorted = [...entries]..sort((a, b) => a.time.compareTo(b.time));
    for (final e in sorted) {
      final m = memberByDeviceId(e.userId);
      if (m == null) {
        unknown.add(e.userId);
        continue;
      }
      if (e.time.isAfter(_clock())) continue;
      if (_checkIns.any((c) => c.memberId == m.id && sameDay(c.time, e.time))) continue;
      final c = CheckIn(id: 'face-${e.userId}-${e.time.millisecondsSinceEpoch ~/ 1000}', memberId: m.id, time: e.time, source: CheckInSource.faceId);
      _checkIns.add(c);
      _put(Collections.checkIns, c.id, c.toJson());
      imported++;
    }
    if (imported > 0) await _commit();
    return (imported: imported, unknown: unknown.length);
  }

}
