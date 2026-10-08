import 'extras.dart';
import 'finance.dart';
import 'gym.dart';
import 'json.dart';
import 'lead.dart';
import 'member.dart';

/// Names of the stored collections. Each record is saved on its own under its id, so recording a
/// check-in writes one small record instead of rewriting the whole data set.
class Collections {
  Collections._();

  static const branches = 'branches';
  static const plans = 'plans';
  static const trainers = 'trainers';
  static const members = 'members';
  static const subscriptions = 'subscriptions';
  static const payments = 'payments';
  static const expenses = 'expenses';
  static const checkIns = 'checkIns';
  static const classes = 'classes';
  static const enquiries = 'enquiries';
  static const measurements = 'measurements';
  static const reminders = 'reminders';
  static const ptPackages = 'ptPackages';
  static const products = 'products';
  static const sales = 'sales';
  static const offers = 'offers';
  static const dayCloses = 'dayCloses';
  static const trainingPlans = 'trainingPlans';
  static const feedback = 'feedback';

  static const all = [
    branches, plans, trainers, members, subscriptions, payments, expenses, checkIns, classes, enquiries, measurements, reminders,
    ptPackages, products, sales, offers, dayCloses, trainingPlans, feedback,
  ];
}

/// Everything the app stores. Used for loading, demo data, reset, and backup files.
class GymData {
  static const schemaVersion = 2;

  final List<Branch> branches;
  final List<Plan> plans;
  final List<Trainer> trainers;
  final List<Member> members;
  final List<Subscription> subscriptions;
  final List<Payment> payments;
  final List<Expense> expenses;
  final List<CheckIn> checkIns;
  final List<GymClass> classes;
  final List<Enquiry> enquiries;
  final List<Measurement> measurements;
  final List<ReminderLog> reminders;
  final List<PtPackage> ptPackages;
  final List<Product> products;
  final List<Sale> sales;
  final List<Offer> offers;
  final List<DayClose> dayCloses;
  final List<TrainingPlan> trainingPlans;
  final List<FeedbackEntry> feedback;
  final GymSettings settings;
  final int nextMemberNumber;
  final int nextReceiptNumber;

  const GymData({
    this.branches = const [],
    this.plans = const [],
    this.trainers = const [],
    this.members = const [],
    this.subscriptions = const [],
    this.payments = const [],
    this.expenses = const [],
    this.checkIns = const [],
    this.classes = const [],
    this.enquiries = const [],
    this.measurements = const [],
    this.reminders = const [],
    this.ptPackages = const [],
    this.products = const [],
    this.sales = const [],
    this.offers = const [],
    this.dayCloses = const [],
    this.trainingPlans = const [],
    this.feedback = const [],
    this.settings = const GymSettings(),
    this.nextMemberNumber = 1,
    this.nextReceiptNumber = 1,
  });

  GymData copyWith({GymSettings? settings}) => GymData(
        branches: branches,
        plans: plans,
        trainers: trainers,
        members: members,
        subscriptions: subscriptions,
        payments: payments,
        expenses: expenses,
        checkIns: checkIns,
        classes: classes,
        enquiries: enquiries,
        measurements: measurements,
        reminders: reminders,
        ptPackages: ptPackages,
        products: products,
        sales: sales,
        offers: offers,
        dayCloses: dayCloses,
        trainingPlans: trainingPlans,
        feedback: feedback,
        settings: settings ?? this.settings,
        nextMemberNumber: nextMemberNumber,
        nextReceiptNumber: nextReceiptNumber,
      );

  /// Records of every collection as JSON maps, keyed by collection name.
  Map<String, List<Map<String, dynamic>>> get records => {
        Collections.branches: [for (final e in branches) e.toJson()],
        Collections.plans: [for (final e in plans) e.toJson()],
        Collections.trainers: [for (final e in trainers) e.toJson()],
        Collections.members: [for (final e in members) e.toJson()],
        Collections.subscriptions: [for (final e in subscriptions) e.toJson()],
        Collections.payments: [for (final e in payments) e.toJson()],
        Collections.expenses: [for (final e in expenses) e.toJson()],
        Collections.checkIns: [for (final e in checkIns) e.toJson()],
        Collections.classes: [for (final e in classes) e.toJson()],
        Collections.enquiries: [for (final e in enquiries) e.toJson()],
        Collections.measurements: [for (final e in measurements) e.toJson()],
        Collections.reminders: [for (final e in reminders) e.toJson()],
        Collections.ptPackages: [for (final e in ptPackages) e.toJson()],
        Collections.products: [for (final e in products) e.toJson()],
        Collections.sales: [for (final e in sales) e.toJson()],
        Collections.offers: [for (final e in offers) e.toJson()],
        Collections.dayCloses: [for (final e in dayCloses) e.toJson()],
        Collections.trainingPlans: [for (final e in trainingPlans) e.toJson()],
        Collections.feedback: [for (final e in feedback) e.toJson()],
      };

  /// Builds the data set from per-collection records plus the settings and counters.
  factory GymData.fromRecords(Map<String, List<Map<String, dynamic>>> r, {Map<String, dynamic>? settings, int nextMemberNumber = 1, int nextReceiptNumber = 1}) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) => [for (final j in r[key] ?? const <Map<String, dynamic>>[]) f(j)];
    final members = list(Collections.members, Member.fromJson);
    final payments = list(Collections.payments, Payment.fromJson);
    // Counters are recomputed as a safety net, so a damaged counter can never reuse a number.
    final maxMember = members.fold<int>(0, (m, e) => e.number > m ? e.number : m);
    final maxReceipt = payments.fold<int>(0, (m, e) {
      final n = int.tryParse(e.receiptNo.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return n > m ? n : m;
    });
    return GymData(
      branches: list(Collections.branches, Branch.fromJson),
      plans: list(Collections.plans, Plan.fromJson),
      trainers: list(Collections.trainers, Trainer.fromJson),
      members: members,
      subscriptions: list(Collections.subscriptions, Subscription.fromJson),
      payments: payments,
      expenses: list(Collections.expenses, Expense.fromJson),
      checkIns: list(Collections.checkIns, CheckIn.fromJson),
      classes: list(Collections.classes, GymClass.fromJson),
      enquiries: list(Collections.enquiries, Enquiry.fromJson),
      measurements: list(Collections.measurements, Measurement.fromJson),
      reminders: list(Collections.reminders, ReminderLog.fromJson),
      ptPackages: list(Collections.ptPackages, PtPackage.fromJson),
      products: list(Collections.products, Product.fromJson),
      sales: list(Collections.sales, Sale.fromJson),
      offers: list(Collections.offers, Offer.fromJson),
      dayCloses: list(Collections.dayCloses, DayClose.fromJson),
      trainingPlans: list(Collections.trainingPlans, TrainingPlan.fromJson),
      feedback: list(Collections.feedback, FeedbackEntry.fromJson),
      settings: settings == null ? const GymSettings() : GymSettings.fromJson(settings),
      nextMemberNumber: nextMemberNumber > maxMember ? nextMemberNumber : maxMember + 1,
      nextReceiptNumber: nextReceiptNumber > maxReceipt ? nextReceiptNumber : maxReceipt + 1,
    );
  }

  factory GymData.fromJson(Map<String, dynamic> j) => GymData.fromRecords(
        {for (final c in Collections.all) c: mapList(j[c])},
        settings: j['settings'] is Map ? Map<String, dynamic>.from(j['settings'] as Map) : null,
        nextMemberNumber: intOr(j['nextMemberNumber'], 1),
        nextReceiptNumber: intOr(j['nextReceiptNumber'], 1),
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        ...records,
        'settings': settings.toJson(),
        'nextMemberNumber': nextMemberNumber,
        'nextReceiptNumber': nextReceiptNumber,
      };
}
