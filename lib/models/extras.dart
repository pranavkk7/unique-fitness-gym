import 'package:flutter/material.dart';

import 'finance.dart';
import 'json.dart';

// ---------------------------------------------------------------------------------------------
// Personal training
// ---------------------------------------------------------------------------------------------

/// A block of personal-training sessions sold to a member with one trainer.
class PtPackage {
  final String id;
  final String memberId;
  final String trainerId;
  final int sessionsTotal;
  final double price;
  final DateTime soldAt;
  final DateTime expiresAt;
  final List<DateTime> sessions; // when each session was used

  const PtPackage({
    required this.id,
    required this.memberId,
    required this.trainerId,
    required this.sessionsTotal,
    required this.price,
    required this.soldAt,
    required this.expiresAt,
    this.sessions = const [],
  });

  int get used => sessions.length;
  int get left => (sessionsTotal - used).clamp(0, sessionsTotal);
  double get pricePerSession => sessionsTotal == 0 ? 0 : price / sessionsTotal;
  bool isActive(DateTime today) => left > 0 && !today.isAfter(expiresAt);

  PtPackage copyWith({List<DateTime>? sessions}) =>
      PtPackage(id: id, memberId: memberId, trainerId: trainerId, sessionsTotal: sessionsTotal, price: price, soldAt: soldAt, expiresAt: expiresAt, sessions: sessions ?? this.sessions);

  factory PtPackage.fromJson(Map<String, dynamic> j) {
    final sold = dateOr(j['soldAt'], DateTime(2000));
    return PtPackage(
      id: str(j['id']),
      memberId: str(j['memberId']),
      trainerId: str(j['trainerId']),
      sessionsTotal: intOr(j['sessionsTotal'], 1),
      price: doubleOr(j['price']),
      soldAt: sold,
      expiresAt: dateOr(j['expiresAt'], sold),
      sessions: [for (final s in (j['sessions'] is List ? j['sessions'] as List : const [])) ?dateOrNull(s)],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'trainerId': trainerId,
        'sessionsTotal': sessionsTotal,
        'price': price,
        'soldAt': soldAt.toIso8601String(),
        'expiresAt': isoDate(expiresAt),
        'sessions': [for (final s in sessions) s.toIso8601String()],
      };
}

// ---------------------------------------------------------------------------------------------
// Shop: products, stock and sales
// ---------------------------------------------------------------------------------------------

enum ProductCategory {
  supplement('Supplements', Icons.science_rounded),
  drink('Drinks', Icons.local_drink_rounded),
  merch('Merchandise', Icons.checkroom_rounded),
  gear('Gear', Icons.sports_mma_rounded),
  other('Other', Icons.category_rounded);

  const ProductCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

class Product {
  final String id;
  final String name;
  final ProductCategory category;
  final double price;
  final double cost;
  final int stock;
  final int lowStockAt;
  final bool active;

  const Product({required this.id, required this.name, this.category = ProductCategory.other, required this.price, this.cost = 0, this.stock = 0, this.lowStockAt = 3, this.active = true});

  bool get lowStock => stock <= lowStockAt;

  Product copyWith({String? name, ProductCategory? category, double? price, double? cost, int? stock, int? lowStockAt, bool? active}) => Product(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        price: price ?? this.price,
        cost: cost ?? this.cost,
        stock: stock ?? this.stock,
        lowStockAt: lowStockAt ?? this.lowStockAt,
        active: active ?? this.active,
      );

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: str(j['id']),
        name: str(j['name'], 'Product'),
        category: enumByName(ProductCategory.values, j['category'], ProductCategory.other),
        price: doubleOr(j['price']),
        cost: doubleOr(j['cost']),
        stock: intOr(j['stock']),
        lowStockAt: intOr(j['lowStockAt'], 3),
        active: j['active'] != false,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'category': category.name, 'price': price, 'cost': cost, 'stock': stock, 'lowStockAt': lowStockAt, 'active': active};
}

class SaleLine {
  final String productId;
  final String name;
  final int qty;
  final double price;

  const SaleLine({required this.productId, required this.name, required this.qty, required this.price});

  double get total => qty * price;

  factory SaleLine.fromJson(Map<String, dynamic> j) => SaleLine(productId: str(j['productId']), name: str(j['name']), qty: intOr(j['qty'], 1), price: doubleOr(j['price']));

  Map<String, dynamic> toJson() => {'productId': productId, 'name': name, 'qty': qty, 'price': price};
}

/// One shop sale (several items). The money is also recorded as a [Payment] so income totals include it.
class Sale {
  final String id;
  final String receiptNo;
  final String? memberId;
  final String buyerName;
  final List<SaleLine> lines;
  final PayMethod method;
  final DateTime date;

  const Sale({required this.id, required this.receiptNo, this.memberId, this.buyerName = '', required this.lines, required this.method, required this.date});

  double get total => lines.fold(0.0, (s, l) => s + l.total);

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
        id: str(j['id']),
        receiptNo: str(j['receiptNo']),
        memberId: strOrNull(j['memberId']),
        buyerName: str(j['buyerName']),
        lines: [for (final l in mapList(j['lines'])) SaleLine.fromJson(l)],
        method: enumByName(PayMethod.values, j['method'], PayMethod.cash),
        date: dateOr(j['date'], DateTime(2000)),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'receiptNo': receiptNo,
        'memberId': memberId,
        'buyerName': buyerName,
        'lines': [for (final l in lines) l.toJson()],
        'method': method.name,
        'date': date.toIso8601String(),
      };
}

// ---------------------------------------------------------------------------------------------
// Offers
// ---------------------------------------------------------------------------------------------

/// A discount code staff can apply at admission or renewal (e.g. ONAM20 for 20% off).
class Offer {
  final String id;
  final String code;
  final bool percent; // true: value is a percentage; false: rupees off
  final double value;
  final DateTime? validUntil;
  final int maxUses; // 0 means unlimited
  final int used;
  final bool active;

  const Offer({required this.id, required this.code, this.percent = true, required this.value, this.validUntil, this.maxUses = 0, this.used = 0, this.active = true});

  String get label => percent ? '${value.round()}% off' : '₹${value.round()} off';

  Offer copyWith({String? code, bool? percent, double? value, DateTime? validUntil, bool clearValidUntil = false, int? maxUses, int? used, bool? active}) => Offer(
        id: id,
        code: code ?? this.code,
        percent: percent ?? this.percent,
        value: value ?? this.value,
        validUntil: clearValidUntil ? null : (validUntil ?? this.validUntil),
        maxUses: maxUses ?? this.maxUses,
        used: used ?? this.used,
        active: active ?? this.active,
      );

  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        id: str(j['id']),
        code: str(j['code']).toUpperCase(),
        percent: j['percent'] != false,
        value: doubleOr(j['value']),
        validUntil: dateOrNull(j['validUntil']),
        maxUses: intOr(j['maxUses']),
        used: intOr(j['used']),
        active: j['active'] != false,
      );

  Map<String, dynamic> toJson() => {'id': id, 'code': code, 'percent': percent, 'value': value, 'validUntil': isoDate(validUntil), 'maxUses': maxUses, 'used': used, 'active': active};
}

// ---------------------------------------------------------------------------------------------
// End of day
// ---------------------------------------------------------------------------------------------

/// The front desk's end-of-day count: what the app expected in the cash drawer and what was counted.
class DayClose {
  final String id;
  final DateTime date;
  final double cashIn;
  final double cashOut;
  final double counted;
  final double upi;
  final double card;
  final double bank;
  final String note;
  final DateTime closedAt;

  const DayClose({
    required this.id,
    required this.date,
    required this.cashIn,
    required this.cashOut,
    required this.counted,
    this.upi = 0,
    this.card = 0,
    this.bank = 0,
    this.note = '',
    required this.closedAt,
  });

  double get expectedCash => cashIn - cashOut;
  double get difference => counted - expectedCash;
  double get total => cashIn + upi + card + bank;

  factory DayClose.fromJson(Map<String, dynamic> j) {
    final date = dateOr(j['date'], DateTime(2000));
    return DayClose(
      id: str(j['id']),
      date: date,
      cashIn: doubleOr(j['cashIn']),
      cashOut: doubleOr(j['cashOut']),
      counted: doubleOr(j['counted']),
      upi: doubleOr(j['upi']),
      card: doubleOr(j['card']),
      bank: doubleOr(j['bank']),
      note: str(j['note']),
      closedAt: dateOr(j['closedAt'], date),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': isoDate(date),
        'cashIn': cashIn,
        'cashOut': cashOut,
        'counted': counted,
        'upi': upi,
        'card': card,
        'bank': bank,
        'note': note,
        'closedAt': closedAt.toIso8601String(),
      };
}

// ---------------------------------------------------------------------------------------------
// Workout and diet plans
// ---------------------------------------------------------------------------------------------

/// A titled block of text: one day of a workout plan, or one meal of a diet plan.
class PlanSection {
  final String title;
  final String body;

  const PlanSection(this.title, this.body);

  factory PlanSection.fromJson(Map<String, dynamic> j) => PlanSection(str(j['title']), str(j['body']));

  Map<String, dynamic> toJson() => {'title': title, 'body': body};
}

enum TrainingPlanKind {
  workout('Workout plan', Icons.fitness_center_rounded),
  diet('Diet plan', Icons.restaurant_rounded);

  const TrainingPlanKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// A workout or diet template that trainers assign to members and send as a PDF.
class TrainingPlan {
  final String id;
  final TrainingPlanKind kind;
  final String name;
  final String goal;
  final List<PlanSection> sections;
  final String notes;

  const TrainingPlan({required this.id, required this.kind, required this.name, this.goal = '', this.sections = const [], this.notes = ''});

  TrainingPlan copyWith({String? name, String? goal, List<PlanSection>? sections, String? notes}) =>
      TrainingPlan(id: id, kind: kind, name: name ?? this.name, goal: goal ?? this.goal, sections: sections ?? this.sections, notes: notes ?? this.notes);

  factory TrainingPlan.fromJson(Map<String, dynamic> j) => TrainingPlan(
        id: str(j['id']),
        kind: enumByName(TrainingPlanKind.values, j['kind'], TrainingPlanKind.workout),
        name: str(j['name'], 'Plan'),
        goal: str(j['goal']),
        sections: [for (final s in mapList(j['sections'])) PlanSection.fromJson(s)],
        notes: str(j['notes']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind.name, 'name': name, 'goal': goal, 'sections': [for (final s in sections) s.toJson()], 'notes': notes};
}

// ---------------------------------------------------------------------------------------------
// Feedback
// ---------------------------------------------------------------------------------------------

enum FeedbackCategory {
  equipment('Equipment', Icons.fitness_center_rounded),
  cleanliness('Cleanliness', Icons.cleaning_services_rounded),
  trainers('Trainers', Icons.sports_rounded),
  timing('Timing & crowd', Icons.schedule_rounded),
  facilities('Facilities', Icons.shower_rounded),
  other('Other', Icons.chat_bubble_rounded);

  const FeedbackCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

class FeedbackEntry {
  final String id;
  final String? memberId;
  final String name;
  final int rating; // 1 to 5
  final FeedbackCategory category;
  final String comment;
  final DateTime createdAt;
  final bool resolved;
  final String response;

  const FeedbackEntry({
    required this.id,
    this.memberId,
    required this.name,
    required this.rating,
    this.category = FeedbackCategory.other,
    this.comment = '',
    required this.createdAt,
    this.resolved = false,
    this.response = '',
  });

  /// Low ratings need a reply from the gym.
  bool get needsAction => !resolved && rating <= 3;

  FeedbackEntry copyWith({bool? resolved, String? response}) => FeedbackEntry(
        id: id,
        memberId: memberId,
        name: name,
        rating: rating,
        category: category,
        comment: comment,
        createdAt: createdAt,
        resolved: resolved ?? this.resolved,
        response: response ?? this.response,
      );

  factory FeedbackEntry.fromJson(Map<String, dynamic> j) => FeedbackEntry(
        id: str(j['id']),
        memberId: strOrNull(j['memberId']),
        name: str(j['name'], 'Member'),
        rating: intOr(j['rating'], 3).clamp(1, 5),
        category: enumByName(FeedbackCategory.values, j['category'], FeedbackCategory.other),
        comment: str(j['comment']),
        createdAt: dateOr(j['createdAt'], DateTime(2000)),
        resolved: j['resolved'] == true,
        response: str(j['response']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'name': name,
        'rating': rating,
        'category': category.name,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
        'resolved': resolved,
        'response': response,
      };
}
