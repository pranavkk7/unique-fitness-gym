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

enum CheckInOutcome { recorded, duplicateToday, blockedExpired, blockedFrozen }

/// What an admission created: the member, and the payments taken at the desk (one receipt).
class AdmissionResult {
  final Member member;
  final List<Payment> payments;

  const AdmissionResult(this.member, this.payments);

  String? get receiptNo => payments.isEmpty ? null : payments.first.receiptNo;
}

/// All gym data and business rules: admissions, renewals, freezes, payments, check-ins, enquiries,
/// expenses, reminders and the owner PIN.
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

  // ---- admissions, renewals, freezes, payments ----------------------------------------

  /// Registers a new member: saves their details and photo, starts the plan, and takes the first
  /// payment. The bill is the plan price minus [discount], plus the admission fee when charged.
  /// Whatever is not paid now becomes the member's balance due.
  Future<AdmissionResult> admit({
    required String name,
    required String phone,
    required Gender gender,
    required String planId,
    DateTime? dateOfBirth,
    String email = '',
    String address = '',
    String? trainerId,
    DateTime? startDate,
    String goal = '',
    double? heightCm,
    double? weightKg,
    String medicalNotes = '',
    String emergencyName = '',
    String emergencyPhone = '',
    LeadSource source = LeadSource.walkIn,
    String notes = '',
    double discount = 0,
    bool chargeAdmissionFee = true,
    double amountPaid = 0,
    PayMethod method = PayMethod.cash,
    Uint8List? photo,
    String? enquiryId,
    String? referredById,
    String? offerId,
  }) async {
    final plan = planById(planId);
    if (plan == null) throw ArgumentError('Unknown plan $planId');
    if (discount < 0 || discount > plan.price) throw ArgumentError('Discount must be between 0 and the plan price');
    if (amountPaid < 0) throw ArgumentError('Amount paid cannot be negative');

    final start = dateOnly(startDate ?? _clock());
    final fee = chargeAdmissionFee ? _settings.admissionFee : 0.0;
    final bill = plan.price - discount + fee;
    final member = Member(
      id: _newId('m'),
      number: _nextMemberNumber++,
      name: name.trim(),
      phone: phone.trim(),
      gender: gender,
      dateOfBirth: dateOfBirth,
      email: email.trim(),
      address: address.trim(),
      branchId: branch.id,
      planId: planId,
      trainerId: trainerId,
      joinDate: today,
      startDate: start,
      endDate: addMonths(start, plan.months),
      goal: goal.trim(),
      heightCm: heightCm,
      weightKg: weightKg,
      medicalNotes: medicalNotes.trim(),
      emergencyName: emergencyName.trim(),
      emergencyPhone: emergencyPhone.trim(),
      source: source,
      notes: notes.trim(),
      balanceDue: max(0, bill - amountPaid),
      hasPhoto: photo != null,
      referredById: referredById,
    );
    _metaDirty = true;
    _members.add(member);
    _put(Collections.members, member.id, member.toJson());
    _addSubscription(member.id, plan, SubscriptionKind.admission, start, member.endDate, discount);

    // One receipt for the desk visit: the admission fee is paid first, the rest goes to the plan.
    final payments = <Payment>[];
    if (amountPaid > 0) {
      final receipt = _nextReceipt();
      final towardsFee = min(amountPaid, fee);
      if (towardsFee > 0) payments.add(_addPayment(member.id, towardsFee, method, PaymentKind.admission, 'Admission fee', receipt));
      final towardsPlan = amountPaid - towardsFee;
      if (towardsPlan > 0) payments.add(_addPayment(member.id, towardsPlan, method, PaymentKind.membership, '${plan.name} plan', receipt));
    }
    if (photo != null) {
      _photoCache[member.id] = photo;
      _pending.add(() => _store.savePhoto(member.id, photo));
    }
    if (referredById != null) _rewardReferrer(referredById);
    if (offerId != null) _redeemOffer(offerId);
    if (enquiryId != null) {
      final i = _enquiries.indexWhere((e) => e.id == enquiryId);
      if (i != -1) {
        _enquiries[i] = _enquiries[i].copyWith(status: EnquiryStatus.converted, memberId: member.id, clearFollowUp: true);
        _put(Collections.enquiries, enquiryId, _enquiries[i].toJson());
      }
    }
    await _commit();
    return AdmissionResult(member, payments);
  }

  /// Extends a membership with a plan. A running membership continues from its end date; an expired
  /// one restarts today (or on [startDate]). Unpaid amounts are added to the balance due, and any
  /// extra paid reduces an older balance.
  Future<(Member, Payment?)> renew(String memberId, {required String planId, double discount = 0, double amountPaid = 0, PayMethod method = PayMethod.cash, DateTime? startDate, String? offerId}) async {
    final i = _members.indexWhere((m) => m.id == memberId);
    final plan = planById(planId);
    if (i == -1 || plan == null) throw ArgumentError('Unknown member or plan');
    if (discount < 0 || discount > plan.price) throw ArgumentError('Discount must be between 0 and the plan price');
    final m = _members[i];
    final stillRunning = daysLeft(m) >= 0;
    final start = startDate != null ? dateOnly(startDate) : (stillRunning ? dateOnly(m.endDate) : today);
    final end = addMonths(start, plan.months);
    final renewed = m.copyWith(planId: planId, startDate: start, endDate: end, balanceDue: max(0, m.balanceDue + plan.price - discount - amountPaid));
    _members[i] = renewed;
    _put(Collections.members, m.id, renewed.toJson());
    _addSubscription(m.id, plan, SubscriptionKind.renewal, start, end, discount);
    if (offerId != null) _redeemOffer(offerId);
    Payment? payment;
    if (amountPaid > 0) {
      payment = _addPayment(memberId, amountPaid, method, PaymentKind.membership, '${plan.name} plan (renewal)', _nextReceipt());
    }
    await _commit();
    return (renewed, payment);
  }

  /// Records a payment against a member and reduces their balance due.
  Future<Payment> recordPayment(String memberId, {required double amount, PayMethod method = PayMethod.cash, PaymentKind kind = PaymentKind.membership, String note = ''}) async {
    final i = _members.indexWhere((m) => m.id == memberId);
    if (i == -1) throw ArgumentError('Unknown member $memberId');
    if (amount <= 0) throw ArgumentError('Amount must be above zero');
    final m = _members[i];
    // Personal training and other sales are extra income; they do not settle the membership balance.
    if (kind == PaymentKind.membership || kind == PaymentKind.admission) {
      _members[i] = m.copyWith(balanceDue: max(0, m.balanceDue - amount));
      _put(Collections.members, m.id, _members[i].toJson());
    }
    final payment = _addPayment(memberId, amount, method, kind, note.isEmpty ? (kind == PaymentKind.membership ? 'Balance payment' : kind.label) : note, _nextReceipt());
    await _commit();
    return payment;
  }

  String _nextReceipt() {
    _metaDirty = true;
    return 'RCPT-${(_nextReceiptNumber++).toString().padLeft(5, '0')}';
  }

  Payment _addPayment(String memberId, double amount, PayMethod method, PaymentKind kind, String note, String receiptNo, {String payerName = ''}) {
    lastPayMethod = method;
    final payment = Payment(id: _newId('pay'), receiptNo: receiptNo, memberId: memberId, amount: amount, date: _clock(), method: method, kind: kind, note: note, payerName: payerName);
    _payments.add(payment);
    _put(Collections.payments, payment.id, payment.toJson());
    return payment;
  }

  void _addSubscription(String memberId, Plan plan, SubscriptionKind kind, DateTime start, DateTime end, double discount) {
    final s = Subscription(
      id: _newId('s'),
      memberId: memberId,
      planId: plan.id,
      planName: plan.name,
      kind: kind,
      start: start,
      end: end,
      price: plan.price,
      discount: discount,
      createdAt: _clock(),
    );
    _subscriptions.add(s);
    _put(Collections.subscriptions, s.id, s.toJson());
  }

  /// All payments made on one receipt (an admission can have an admission fee line and a plan line).
  List<Payment> paymentsOnReceipt(String receiptNo) => _payments.where((p) => p.receiptNo == receiptNo).toList();

  List<Payment> paymentsFor(String memberId) => _payments.where((p) => p.memberId == memberId).toList()..sort((a, b) => b.date.compareTo(a.date));

  List<Subscription> subscriptionsFor(String memberId) => _subscriptions.where((s) => s.memberId == memberId).toList()..sort((a, b) => b.start.compareTo(a.start));

  /// Pauses a running membership from today for [days]. The end date moves out by the same amount.
  Future<Member> freeze(String memberId, {required int days, String reason = ''}) async {
    final i = _members.indexWhere((m) => m.id == memberId);
    if (i == -1) throw ArgumentError('Unknown member $memberId');
    if (days < 1 || days > 90) throw ArgumentError('A freeze is 1 to 90 days');
    final m = _members[i];
    final status = statusOf(m);
    if (status == MemberStatus.expired) throw StateError('An expired membership cannot be frozen');
    if (status == MemberStatus.frozen) throw StateError('This membership is already frozen');
    final frozen = m.copyWith(
      endDate: m.endDate.add(Duration(days: days)),
      freezes: [...m.freezes, Freeze(start: today, days: days, reason: reason.trim())],
    );
    _members[i] = frozen;
    _put(Collections.members, m.id, frozen.toJson());
    await _commit();
    return frozen;
  }

  /// Ends the current freeze today. Days that were not used come off the end date again.
  Future<Member> unfreeze(String memberId) async {
    final i = _members.indexWhere((m) => m.id == memberId);
    if (i == -1) throw ArgumentError('Unknown member $memberId');
    final m = _members[i];
    final current = m.freezeOn(today);
    if (current == null) return m;
    final used = today.difference(current.start).inDays;
    final unused = current.days - used;
    final freezes = [
      for (final f in m.freezes)
        if (!identical(f, current)) f else if (used > 0) Freeze(start: f.start, days: used, reason: f.reason),
    ];
    final updated = m.copyWith(endDate: m.endDate.subtract(Duration(days: unused)), freezes: freezes);
    _members[i] = updated;
    _put(Collections.members, m.id, updated.toJson());
    await _commit();
    return updated;
  }

  Future<void> updateMember(Member updated) async {
    final i = _members.indexWhere((m) => m.id == updated.id);
    if (i == -1) return;
    _members[i] = updated;
    _put(Collections.members, updated.id, updated.toJson());
    await _commit();
  }

  /// Removes a member's personal data (details, photo, visits, body checks, reminder history).
  /// Payments and memberships sold stay in the books so past revenue does not change.
  Future<void> deleteMember(String memberId) async {
    _members.removeWhere((m) => m.id == memberId);
    _delete(Collections.members, memberId);
    for (final c in _checkIns.where((c) => c.memberId == memberId).toList()) {
      _delete(Collections.checkIns, c.id);
    }
    _checkIns.removeWhere((c) => c.memberId == memberId);
    for (final w in _measurements.where((w) => w.memberId == memberId).toList()) {
      _delete(Collections.measurements, w.id);
    }
    _measurements.removeWhere((w) => w.memberId == memberId);
    for (final r in _reminders.where((r) => r.targetId == memberId).toList()) {
      _delete(Collections.reminders, r.id);
    }
    _reminders.removeWhere((r) => r.targetId == memberId);
    _photoCache.remove(memberId);
    _photoLoads.remove(memberId);
    _pending.add(() => _store.savePhoto(memberId, null));
    await _commit();
  }

  // ---- referrals and offers -----------------------------------------------------------

  /// Bonus days for the member who brought someone in.
  void _rewardReferrer(String referrerId) {
    final days = _settings.referralRewardDays;
    final i = _members.indexWhere((m) => m.id == referrerId);
    if (i == -1 || days <= 0) return;
    final m = _members[i];
    _members[i] = m.copyWith(endDate: m.endDate.add(Duration(days: days)), notes: '${m.notes}${m.notes.isEmpty ? '' : '\n'}+$days days for a referral (${formatDayMonth(today)})');
    _put(Collections.members, referrerId, _members[i].toJson());
  }

  List<Member> referralsBy(String memberId) => _members.where((m) => m.referredById == memberId).toList();

  /// Checks an offer code against today's date and its use limit. Returns the offer and the
  /// discount for [price], or an error message.
  ({Offer? offer, double discount, String? error}) checkOffer(String code, double price) {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return (offer: null, discount: 0, error: null);
    final o = _offers.where((o) => o.code == c).firstOrNull;
    if (o == null || !o.active) return (offer: null, discount: 0, error: 'No such offer');
    if (o.validUntil != null && today.isAfter(dateOnly(o.validUntil!))) return (offer: null, discount: 0, error: 'This offer ended on ${formatDate(o.validUntil!)}');
    if (o.maxUses > 0 && o.used >= o.maxUses) return (offer: null, discount: 0, error: 'This offer has been used up');
    final discount = o.percent ? (price * o.value / 100).roundToDouble() : min(o.value, price);
    return (offer: o, discount: discount, error: null);
  }

  void _redeemOffer(String offerId) {
    final i = _offers.indexWhere((o) => o.id == offerId);
    if (i == -1) return;
    _offers[i] = _offers[i].copyWith(used: _offers[i].used + 1);
    _put(Collections.offers, offerId, _offers[i].toJson());
  }

  Future<void> saveOffer(Offer o) async {
    final i = _offers.indexWhere((x) => x.id == o.id);
    if (_offers.any((x) => x.code == o.code && x.id != o.id)) throw ArgumentError('Code ${o.code} already exists');
    i == -1 ? _offers.add(o) : _offers[i] = o;
    _put(Collections.offers, o.id, o.toJson());
    await _commit();
  }

  String newOfferId() => _newId('o');

  Future<void> deleteOffer(String id) async {
    _offers.removeWhere((o) => o.id == id);
    _delete(Collections.offers, id);
    await _commit();
  }

  // ---- day passes and trials ----------------------------------------------------------

  /// A paid single visit by someone who is not a member. Saved as an enquiry too, so the desk
  /// follows up tomorrow.
  Future<Payment> sellDayPass({required String name, required String phone, required double amount, PayMethod method = PayMethod.cash}) async {
    if (name.trim().isEmpty) throw ArgumentError('Enter a name');
    if (amount <= 0) throw ArgumentError('Enter the day pass price');
    final payment = _addPayment('', amount, method, PaymentKind.dayPass, 'Day pass', _nextReceipt(), payerName: name.trim());
    _addLead(name, phone, EnquiryStatus.trial, today.add(const Duration(days: 1)), 'Day pass on ${formatDate(today)}');
    await _commit();
    return payment;
  }

  /// A free trial: saved as an enquiry on trial, with a follow-up when the trial ends.
  Future<Enquiry> startTrial({required String name, required String phone, String? planId}) async {
    if (name.trim().isEmpty) throw ArgumentError('Enter a name');
    final e = _addLead(name, phone, EnquiryStatus.trial, today.add(Duration(days: _settings.trialDays)), '${_settings.trialDays}-day free trial from ${formatDate(today)}', planId: planId);
    await _commit();
    return e;
  }

  Enquiry _addLead(String name, String phone, EnquiryStatus status, DateTime followUp, String notes, {String? planId}) {
    final e = Enquiry(id: _newId('q'), name: name.trim(), phone: phone.trim(), createdAt: _clock(), status: status, nextFollowUp: followUp, notes: notes, planId: planId);
    _enquiries.add(e);
    _put(Collections.enquiries, e.id, e.toJson());
    return e;
  }

  // ---- personal training ---------------------------------------------------------------

  List<PtPackage> ptPackagesFor(String memberId) => _ptPackages.where((p) => p.memberId == memberId).toList()..sort((a, b) => b.soldAt.compareTo(a.soldAt));

  PtPackage? activePtPackage(String memberId) => ptPackagesFor(memberId).where((p) => p.isActive(today)).firstOrNull;

  Future<(PtPackage, Payment?)> sellPtPackage(String memberId, {required String trainerId, required int sessions, required double price, int validDays = 60, double amountPaid = 0, PayMethod method = PayMethod.cash}) async {
    if (memberById(memberId) == null || trainerById(trainerId) == null) throw ArgumentError('Unknown member or trainer');
    if (sessions < 1 || price < 0) throw ArgumentError('Check the sessions and price');
    final pkg = PtPackage(id: _newId('pt'), memberId: memberId, trainerId: trainerId, sessionsTotal: sessions, price: price, soldAt: _clock(), expiresAt: today.add(Duration(days: validDays)));
    _ptPackages.add(pkg);
    _put(Collections.ptPackages, pkg.id, pkg.toJson());
    Payment? payment;
    if (amountPaid > 0) payment = _addPayment(memberId, amountPaid, method, PaymentKind.personalTraining, 'PT: $sessions sessions with ${trainerById(trainerId)!.name}', _nextReceipt());
    if (amountPaid < price) {
      final i = _members.indexWhere((m) => m.id == memberId);
      _members[i] = _members[i].copyWith(balanceDue: _members[i].balanceDue + price - amountPaid);
      _put(Collections.members, memberId, _members[i].toJson());
    }
    await _commit();
    return (pkg, payment);
  }

  /// Marks one session as done. Returns false when none are left or the package has expired.
  Future<bool> usePtSession(String packageId) async {
    final i = _ptPackages.indexWhere((p) => p.id == packageId);
    if (i == -1 || !_ptPackages[i].isActive(today)) return false;
    _ptPackages[i] = _ptPackages[i].copyWith(sessions: [..._ptPackages[i].sessions, _clock()]);
    _put(Collections.ptPackages, packageId, _ptPackages[i].toJson());
    await _commit();
    return true;
  }

  Future<void> undoPtSession(String packageId) async {
    final i = _ptPackages.indexWhere((p) => p.id == packageId);
    if (i == -1 || _ptPackages[i].sessions.isEmpty) return;
    _ptPackages[i] = _ptPackages[i].copyWith(sessions: _ptPackages[i].sessions.sublist(0, _ptPackages[i].sessions.length - 1));
    _put(Collections.ptPackages, packageId, _ptPackages[i].toJson());
    await _commit();
  }

  /// What a trainer earned from personal training in [month]: their share of each session taken.
  double trainerEarnings(String trainerId, DateTime month) {
    final t = trainerById(trainerId);
    if (t == null || t.commissionPct <= 0) return 0;
    var total = 0.0;
    for (final p in _ptPackages.where((p) => p.trainerId == trainerId)) {
      total += p.sessions.where((s) => sameMonth(s, month)).length * p.pricePerSession * t.commissionPct / 100;
    }
    return total;
  }

  // ---- shop ------------------------------------------------------------------------------

  Future<void> saveProduct(Product p) async {
    final i = _products.indexWhere((x) => x.id == p.id);
    i == -1 ? _products.add(p) : _products[i] = p;
    _put(Collections.products, p.id, p.toJson());
    await _commit();
  }

  String newProductId() => _newId('pr');

  List<Product> get lowStock => _products.where((p) => p.active && p.lowStock).toList()..sort((a, b) => a.stock.compareTo(b.stock));

  /// Adds stock; with a [unitCost], the purchase is also saved as an expense.
  Future<void> restock(String productId, int qty, {double unitCost = 0}) async {
    final i = _products.indexWhere((p) => p.id == productId);
    if (i == -1 || qty <= 0) throw ArgumentError('Check the quantity');
    _products[i] = _products[i].copyWith(stock: _products[i].stock + qty, cost: unitCost > 0 ? unitCost : null);
    _put(Collections.products, productId, _products[i].toJson());
    if (unitCost > 0) {
      final e = Expense(id: _newId('e'), category: ExpenseCategory.supplies, amount: unitCost * qty, date: _clock(), note: 'Stock: $qty × ${_products[i].name}');
      _expenses.add(e);
      _put(Collections.expenses, e.id, e.toJson());
    }
    await _commit();
  }

  /// Sells items at the desk. Refuses a sale that would take stock below zero.
  Future<Sale> sell(Map<String, int> items, {String? memberId, String buyerName = '', PayMethod method = PayMethod.cash}) async {
    final lines = <SaleLine>[];
    for (final e in items.entries) {
      if (e.value <= 0) continue;
      final p = productById(e.key);
      if (p == null) throw ArgumentError('Unknown product');
      if (p.stock < e.value) throw StateError('Only ${p.stock} ${p.name} left');
      lines.add(SaleLine(productId: p.id, name: p.name, qty: e.value, price: p.price));
    }
    if (lines.isEmpty) throw ArgumentError('Add at least one item');
    for (final l in lines) {
      final i = _products.indexWhere((p) => p.id == l.productId);
      _products[i] = _products[i].copyWith(stock: _products[i].stock - l.qty);
      _put(Collections.products, l.productId, _products[i].toJson());
    }
    final member = memberById(memberId);
    final receipt = _nextReceipt();
    final sale = Sale(id: _newId('sale'), receiptNo: receipt, memberId: member?.id, buyerName: member?.name ?? buyerName.trim(), lines: lines, method: method, date: _clock());
    _sales.add(sale);
    _put(Collections.sales, sale.id, sale.toJson());
    _addPayment(member?.id ?? '', sale.total, method, PaymentKind.product, lines.map((l) => '${l.qty} × ${l.name}').join(', '), receipt,
        payerName: member == null ? (buyerName.trim().isEmpty ? 'Walk-in' : buyerName.trim()) : '');
    await _commit();
    return sale;
  }

  // ---- class batches ---------------------------------------------------------------------

  /// Adds a member to a class batch. Returns false when the batch is full.
  Future<bool> enrollInClass(String classId, String memberId) async {
    final i = _classes.indexWhere((c) => c.id == classId);
    if (i == -1) return false;
    final c = _classes[i];
    if (c.memberIds.contains(memberId)) return true;
    if (c.memberIds.length >= c.capacity) return false;
    _classes[i] = c.copyWith(memberIds: [...c.memberIds, memberId]);
    _put(Collections.classes, classId, _classes[i].toJson());
    await _commit();
    return true;
  }

  Future<void> removeFromClass(String classId, String memberId) async {
    final i = _classes.indexWhere((c) => c.id == classId);
    if (i == -1) return;
    _classes[i] = _classes[i].copyWith(memberIds: _classes[i].memberIds.where((id) => id != memberId).toList());
    _put(Collections.classes, classId, _classes[i].toJson());
    await _commit();
  }

  List<GymClass> classesOf(String memberId) => _classes.where((c) => c.memberIds.contains(memberId)).toList();

  // ---- end of day ------------------------------------------------------------------------

  /// Today's money by method, cash spent, and what should be in the drawer.
  ({double cash, double upi, double card, double bank, double cashOut, int receipts, int admissions, int renewals, int checkIns}) daySummary([DateTime? day]) {
    final d = dateOnly(day ?? _clock());
    final pay = _payments.where((p) => sameDay(p.date, d));
    double sum(PayMethod m) => pay.where((p) => p.method == m).fold(0.0, (s, p) => s + p.amount);
    final subs = _subscriptions.where((s) => sameDay(s.createdAt, d));
    return (
      cash: sum(PayMethod.cash),
      upi: sum(PayMethod.upi),
      card: sum(PayMethod.card),
      bank: sum(PayMethod.bank),
      cashOut: _expenses.where((e) => sameDay(e.date, d) && e.method == PayMethod.cash).fold(0.0, (s, e) => s + e.amount),
      receipts: pay.map((p) => p.receiptNo).toSet().length,
      admissions: subs.where((s) => s.kind == SubscriptionKind.admission).length,
      renewals: subs.where((s) => s.kind == SubscriptionKind.renewal).length,
      checkIns: _checkIns.where((c) => sameDay(c.time, d)).length,
    );
  }

  DayClose? closeFor(DateTime day) => _dayCloses.where((c) => sameDay(c.date, day)).firstOrNull;

  /// Saves today's count of the cash drawer. Closing again replaces the earlier count.
  Future<DayClose> closeDay({required double counted, String note = ''}) async {
    final s = daySummary();
    final existing = closeFor(today);
    final close = DayClose(id: existing?.id ?? _newId('dc'), date: today, cashIn: s.cash, cashOut: s.cashOut, counted: counted, upi: s.upi, card: s.card, bank: s.bank, note: note.trim(), closedAt: _clock());
    _dayCloses
      ..removeWhere((c) => c.id == close.id)
      ..add(close);
    _put(Collections.dayCloses, close.id, close.toJson());
    await _commit();
    return close;
  }

  // ---- workout and diet plans ----------------------------------------------------------------

  Future<void> saveTrainingPlan(TrainingPlan p) async {
    final i = _trainingPlans.indexWhere((x) => x.id == p.id);
    i == -1 ? _trainingPlans.add(p) : _trainingPlans[i] = p;
    _put(Collections.trainingPlans, p.id, p.toJson());
    await _commit();
  }

  String newTrainingPlanId() => _newId('tp');

  Future<void> deleteTrainingPlan(String id) async {
    _trainingPlans.removeWhere((p) => p.id == id);
    _delete(Collections.trainingPlans, id);
    for (var i = 0; i < _members.length; i++) {
      final m = _members[i];
      if (m.workoutPlanId == id || m.dietPlanId == id) {
        _members[i] = m.copyWith(clearWorkoutPlan: m.workoutPlanId == id, clearDietPlan: m.dietPlanId == id);
        _put(Collections.members, m.id, _members[i].toJson());
      }
    }
    await _commit();
  }

  /// Gives a member a plan (replacing the one of the same kind), or clears it with null.
  Future<void> assignTrainingPlan(String memberId, TrainingPlanKind kind, String? planId) async {
    final i = _members.indexWhere((m) => m.id == memberId);
    if (i == -1) return;
    final m = _members[i];
    _members[i] = kind == TrainingPlanKind.workout
        ? m.copyWith(workoutPlanId: planId, clearWorkoutPlan: planId == null)
        : m.copyWith(dietPlanId: planId, clearDietPlan: planId == null);
    _put(Collections.members, memberId, _members[i].toJson());
    await _commit();
  }

  // ---- feedback ----------------------------------------------------------------------------

  Future<FeedbackEntry> addFeedback({String? memberId, required String name, required int rating, FeedbackCategory category = FeedbackCategory.other, String comment = ''}) async {
    if (rating < 1 || rating > 5) throw ArgumentError('Rating is 1 to 5');
    final f = FeedbackEntry(id: _newId('fb'), memberId: memberId, name: name.trim().isEmpty ? 'Member' : name.trim(), rating: rating, category: category, comment: comment.trim(), createdAt: _clock());
    _feedback.add(f);
    _put(Collections.feedback, f.id, f.toJson());
    await _commit();
    return f;
  }

  Future<void> resolveFeedback(String id, {String response = ''}) async {
    final i = _feedback.indexWhere((f) => f.id == id);
    if (i == -1) return;
    _feedback[i] = _feedback[i].copyWith(resolved: true, response: response.trim());
    _put(Collections.feedback, id, _feedback[i].toJson());
    await _commit();
  }

  /// Average rating over the last [days] days, or null without feedback.
  double? averageRating([int days = 90]) {
    final since = today.subtract(Duration(days: days));
    final recent = _feedback.where((f) => f.createdAt.isAfter(since)).toList();
    if (recent.isEmpty) return null;
    return recent.fold(0, (s, f) => s + f.rating) / recent.length;
  }

  // ---- photos ------------------------------------------------------------------------

  /// The photo if it is already in memory. Use [loadPhoto] to fetch it.
  Uint8List? cachedPhoto(String memberId) => _photoCache[memberId];

  Future<Uint8List?> loadPhoto(String memberId) {
    if (_photoCache.containsKey(memberId)) return Future.value(_photoCache[memberId]);
    final member = memberById(memberId);
    if (member == null || !member.hasPhoto) return Future.value(null);
    return _photoLoads.putIfAbsent(memberId, () async {
      final bytes = await _store.loadPhoto(memberId);
      _photoCache[memberId] = bytes;
      return bytes;
    });
  }

  Future<void> setPhoto(String memberId, Uint8List? bytes) async {
    final i = _members.indexWhere((m) => m.id == memberId);
    if (i == -1) return;
    _members[i] = _members[i].copyWith(hasPhoto: bytes != null);
    _photoCache[memberId] = bytes;
    _photoLoads.remove(memberId);
    _put(Collections.members, memberId, _members[i].toJson());
    _pending.add(() => _store.savePhoto(memberId, bytes));
    await _commit();
  }

  // ---- body measurements ---------------------------------------------------------------

  List<Measurement> measurementsFor(String memberId) => _measurements.where((w) => w.memberId == memberId).toList()..sort((a, b) => a.date.compareTo(b.date));

  Future<Measurement> addMeasurement(String memberId, {required double weightKg, double? bodyFatPct, double? waistCm, double? chestCm, double? armCm, DateTime? date}) async {
    final i = _members.indexWhere((m) => m.id == memberId);
    if (i == -1) throw ArgumentError('Unknown member $memberId');
    if (weightKg <= 0 || weightKg > 400) throw ArgumentError('Enter a real weight');
    final w = Measurement(id: _newId('w'), memberId: memberId, date: dateOnly(date ?? _clock()), weightKg: weightKg, bodyFatPct: bodyFatPct, waistCm: waistCm, chestCm: chestCm, armCm: armCm);
    _measurements.add(w);
    _put(Collections.measurements, w.id, w.toJson());
    // The profile shows the latest weight.
    _members[i] = _members[i].copyWith(weightKg: weightKg);
    _put(Collections.members, memberId, _members[i].toJson());
    await _commit();
    return w;
  }

  Future<void> deleteMeasurement(String id) async {
    _measurements.removeWhere((w) => w.id == id);
    _delete(Collections.measurements, id);
    await _commit();
  }

  // ---- enquiries ---------------------------------------------------------------------

  List<Enquiry> enquiriesWith({EnquiryStatus? status, bool openOnly = false}) {
    final list = _enquiries.where((e) => (status == null || e.status == status) && (!openOnly || e.status.isOpen)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Open enquiries whose follow-up date is today or already past, oldest first.
  List<Enquiry> get followUpsDue {
    final list = _enquiries.where((e) => e.status.isOpen && e.nextFollowUp != null && !dateOnly(e.nextFollowUp!).isAfter(today)).toList();
    list.sort((a, b) => a.nextFollowUp!.compareTo(b.nextFollowUp!));
    return list;
  }

  Future<Enquiry> saveEnquiry(Enquiry e) async {
    final i = _enquiries.indexWhere((x) => x.id == e.id);
    i == -1 ? _enquiries.add(e) : _enquiries[i] = e;
    _put(Collections.enquiries, e.id, e.toJson());
    await _commit();
    return e;
  }

  String newEnquiryId() => _newId('q');

  Future<void> deleteEnquiry(String id) async {
    _enquiries.removeWhere((e) => e.id == id);
    _delete(Collections.enquiries, id);
    await _commit();
  }

  // ---- expenses ----------------------------------------------------------------------

  Future<Expense> addExpense({required ExpenseCategory category, required double amount, DateTime? date, PayMethod method = PayMethod.cash, String note = ''}) async {
    if (amount <= 0) throw ArgumentError('Amount must be above zero');
    final e = Expense(id: _newId('e'), category: category, amount: amount, date: date ?? _clock(), method: method, note: note.trim());
    _expenses.add(e);
    _put(Collections.expenses, e.id, e.toJson());
    await _commit();
    return e;
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    _delete(Collections.expenses, id);
    await _commit();
  }

  /// Records a trainer's monthly salary as an expense. Returns false if it was already paid for [month].
  Future<bool> paySalary(String trainerId, DateTime month) async {
    final t = trainerById(trainerId);
    if (t == null || t.monthlySalary <= 0) return false;
    final note = 'Salary: ${t.name}, ${formatMonthYear(month)}';
    if (_expenses.any((e) => e.category == ExpenseCategory.salary && e.note == note)) return false;
    await addExpense(category: ExpenseCategory.salary, amount: t.monthlySalary, method: PayMethod.bank, note: note);
    return true;
  }

  bool salaryPaid(String trainerId, DateTime month) {
    final t = trainerById(trainerId);
    return t != null && _expenses.any((e) => e.category == ExpenseCategory.salary && e.note == 'Salary: ${t.name}, ${formatMonthYear(month)}');
  }

  // ---- reminders ---------------------------------------------------------------------

  DateTime? lastReminder(String targetId, ReminderKind kind) {
    DateTime? last;
    for (final r in _reminders) {
      if (r.targetId == targetId && r.kind == kind && (last == null || r.sentAt.isAfter(last))) last = r.sentAt;
    }
    return last;
  }

  /// True while the person is inside the kind's cooldown after a message.
  bool remindedRecently(String targetId, ReminderKind kind) {
    final last = lastReminder(targetId, kind);
    return last != null && today.difference(dateOnly(last)).inDays < kind.cooldownDays;
  }

  Future<void> logReminder(ReminderKind kind, String targetId) async {
    final r = ReminderLog(id: _newId('r'), targetId: targetId, kind: kind, sentAt: _clock());
    _reminders.add(r);
    _put(Collections.reminders, r.id, r.toJson());
    if (kind == ReminderKind.followUp) {
      final i = _enquiries.indexWhere((e) => e.id == targetId);
      if (i != -1) {
        _enquiries[i] = _enquiries[i].copyWith(lastContacted: _clock(), status: _enquiries[i].status == EnquiryStatus.open ? EnquiryStatus.followUp : null);
        _put(Collections.enquiries, targetId, _enquiries[i].toJson());
      }
    }
    await _commit();
  }

  // ---- plans, trainers, classes, settings --------------------------------------------

  Future<void> savePlan(Plan plan) async {
    final i = _plans.indexWhere((p) => p.id == plan.id);
    i == -1 ? _plans.add(plan) : _plans[i] = plan;
    _put(Collections.plans, plan.id, plan.toJson());
    await _commit();
  }

  String newPlanId() => _newId('p');

  bool planInUse(String id) => _members.any((m) => m.planId == id);

  /// A plan members are on cannot be deleted (retire it instead). Returns false in that case.
  Future<bool> deletePlan(String id) async {
    if (planInUse(id)) return false;
    _plans.removeWhere((p) => p.id == id);
    _delete(Collections.plans, id);
    await _commit();
    return true;
  }

  Future<void> saveTrainer(Trainer t) async {
    final i = _trainers.indexWhere((x) => x.id == t.id);
    i == -1 ? _trainers.add(t) : _trainers[i] = t;
    _put(Collections.trainers, t.id, t.toJson());
    await _commit();
  }

  String newTrainerId() => _newId('t');

  Future<void> deleteTrainer(String id) async {
    _trainers.removeWhere((t) => t.id == id);
    _delete(Collections.trainers, id);
    // Members and classes keep working without a trainer.
    for (var i = 0; i < _members.length; i++) {
      if (_members[i].trainerId == id) {
        _members[i] = _members[i].copyWith(clearTrainer: true);
        _put(Collections.members, _members[i].id, _members[i].toJson());
      }
    }
    for (var i = 0; i < _classes.length; i++) {
      if (_classes[i].trainerId == id) {
        _classes[i] = _classes[i].copyWith(clearTrainer: true);
        _put(Collections.classes, _classes[i].id, _classes[i].toJson());
      }
    }
    await _commit();
  }

  List<Member> clientsOf(String trainerId) => _members.where((m) => m.trainerId == trainerId && isRunning(m)).toList();

  Future<void> saveClass(GymClass c) async {
    final i = _classes.indexWhere((x) => x.id == c.id);
    i == -1 ? _classes.add(c) : _classes[i] = c;
    _put(Collections.classes, c.id, c.toJson());
    await _commit();
  }

  String newClassId() => _newId('c');

  Future<void> deleteClass(String id) async {
    _classes.removeWhere((c) => c.id == id);
    _delete(Collections.classes, id);
    await _commit();
  }

  /// Classes on a weekday (DateTime.monday..sunday), earliest first.
  List<GymClass> classesOn(int weekday) => _classes.where((c) => c.weekdays.contains(weekday)).toList()..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  Future<void> updateSettings(GymSettings s) async {
    _settings = s;
    _metaDirty = true;
    await _commit();
  }

  // ---- owner PIN ---------------------------------------------------------------------

  /// Front-desk staff can use the app without the PIN; revenue, expenses, settings and deleting
  /// need the owner's PIN once one is set.
  bool get ownerUnlocked => !_settings.hasPin || _unlocked;

  static String _hash(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) throw ArgumentError('The PIN must be 4 digits');
    final rnd = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    _unlocked = true;
    await updateSettings(_settings.copyWith(pinHash: _hash(salt, pin), pinSalt: salt));
  }

  Future<void> clearPin() => updateSettings(_settings.copyWith(clearPin: true));

  bool unlock(String pin) {
    if (!_settings.hasPin) return true;
    final ok = _hash(_settings.pinSalt!, pin) == _settings.pinHash;
    if (ok && !_unlocked) {
      _unlocked = true;
      notifyListeners();
    }
    return ok;
  }

  void lock() {
    if (!_unlocked) return;
    _unlocked = false;
    notifyListeners();
  }

  // ---- backup ------------------------------------------------------------------------

  static const _backupApp = 'unique_fitness_gym';

  /// Everything, photos included, as one JSON document the owner can keep in Drive or WhatsApp.
  Future<String> exportBackup() async {
    final photos = await _store.allPhotos();
    return jsonEncode({
      'app': _backupApp,
      'exportedAt': _clock().toIso8601String(),
      'data': snapshot.toJson(),
      'photos': {for (final e in photos.entries) e.key: base64Encode(e.value)},
    });
  }

  /// Replaces all data with a backup. Throws [FormatException] if the file is not a backup from
  /// this app, and changes nothing in that case.
  Future<int> restoreBackup(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('This file is not a backup.');
    }
    if (decoded is! Map || decoded['app'] != _backupApp || decoded['data'] is! Map) {
      throw const FormatException('This file is not a Unique Fitness Gym backup.');
    }
    final data = GymData.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
    final photos = <String, Uint8List>{};
    if (decoded['photos'] is Map) {
      (decoded['photos'] as Map).forEach((key, value) {
        if (key is String && value is String) {
          try {
            photos[key] = base64Decode(value);
          } catch (_) {/* skip a damaged photo, keep the rest */}
        }
      });
    }
    await _replaceAll(data, photos: photos);
    return data.members.length;
  }
}
