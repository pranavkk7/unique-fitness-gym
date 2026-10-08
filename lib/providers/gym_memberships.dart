part of 'gym_provider.dart';

/// Admissions, renewals, freezes and payments: the money and dates behind every membership.
extension GymMemberships on GymProvider {
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
}
