part of 'gym_provider.dart';

/// Front-desk routines: class batches, closing the day, workout and diet plans, and feedback.
extension GymDesk on GymProvider {
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
}
