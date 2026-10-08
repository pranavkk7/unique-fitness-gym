import 'package:flutter/material.dart';

import 'json.dart';

enum PayMethod {
  cash('Cash', Icons.payments_rounded),
  upi('UPI', Icons.qr_code_2_rounded),
  card('Card', Icons.credit_card_rounded),
  bank('Bank transfer', Icons.account_balance_rounded);

  const PayMethod(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum PaymentKind {
  membership('Membership'),
  admission('Admission fee'),
  personalTraining('Personal training'),
  dayPass('Day pass'),
  product('Shop sale'),
  other('Other');

  const PaymentKind(this.label);
  final String label;
}

class Payment {
  final String id;
  final String receiptNo;
  final String memberId;
  final double amount;
  final DateTime date;
  final PayMethod method;
  final PaymentKind kind;
  final String note;

  /// Name of a payer who is not a member (day pass, walk-in shop sale). Empty for members.
  final String payerName;

  const Payment({
    required this.id,
    required this.receiptNo,
    required this.memberId,
    required this.amount,
    required this.date,
    required this.method,
    this.kind = PaymentKind.membership,
    this.note = '',
    this.payerName = '',
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: str(j['id']),
        receiptNo: str(j['receiptNo']),
        memberId: str(j['memberId']),
        amount: doubleOr(j['amount']),
        date: dateOr(j['date'], DateTime(2000)),
        method: enumByName(PayMethod.values, j['method'], PayMethod.cash),
        kind: enumByName(PaymentKind.values, j['kind'], PaymentKind.membership),
        note: str(j['note']),
        payerName: str(j['payerName']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'receiptNo': receiptNo,
        'memberId': memberId,
        'amount': amount,
        'date': date.toIso8601String(),
        'method': method.name,
        'kind': kind.name,
        'note': note,
        'payerName': payerName,
      };
}

enum ExpenseCategory {
  rent('Rent', Icons.home_work_rounded, Color(0xFF8B5CF6)),
  salary('Salaries', Icons.badge_rounded, Color(0xFF3B82F6)),
  electricity('Electricity & water', Icons.bolt_rounded, Color(0xFFFFB020)),
  equipment('Equipment', Icons.fitness_center_rounded, Color(0xFFE11D2A)),
  maintenance('Maintenance', Icons.build_rounded, Color(0xFFFF6B1A)),
  marketing('Marketing', Icons.campaign_rounded, Color(0xFFFF4DA6)),
  supplies('Supplies & cleaning', Icons.cleaning_services_rounded, Color(0xFF2FD07F)),
  other('Other', Icons.more_horiz_rounded, Color(0xFF9A9AA3));

  const ExpenseCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class Expense {
  final String id;
  final ExpenseCategory category;
  final double amount;
  final DateTime date;
  final PayMethod method;
  final String note;

  const Expense({required this.id, required this.category, required this.amount, required this.date, this.method = PayMethod.cash, this.note = ''});

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: str(j['id']),
        category: enumByName(ExpenseCategory.values, j['category'], ExpenseCategory.other),
        amount: doubleOr(j['amount']),
        date: dateOr(j['date'], DateTime(2000)),
        method: enumByName(PayMethod.values, j['method'], PayMethod.cash),
        note: str(j['note']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'amount': amount,
        'date': date.toIso8601String(),
        'method': method.name,
        'note': note,
      };
}
