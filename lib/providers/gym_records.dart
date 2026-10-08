part of 'gym_provider.dart';

/// Member records and day-to-day logs: photos, body checks, enquiries, expenses and reminders.
extension GymRecords on GymProvider {
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
}
