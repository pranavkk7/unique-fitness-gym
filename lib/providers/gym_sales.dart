part of 'gym_provider.dart';

/// Revenue beyond memberships: referrals, offer codes, day passes and trials, personal training and the shop.
extension GymSales on GymProvider {
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
}
