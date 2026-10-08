import 'dart:math';

import '../core/utils/format.dart';
import '../models/models.dart';

const pinarayi = Branch(id: 'b-pinarayi', name: 'Pinarayi', area: 'Aiswarya Shopping Mall, Pinarayi');

/// The gym's two membership tiers from its price list (October 2026): six durations each.
const _silver = [(1, 1500), (2, 2500), (3, 3500), (4, 4500), (6, 6500), (12, 10000)];
const _platinum = [(1, 1800), (2, 3000), (3, 4000), (4, 5000), (6, 7000), (12, 12000)];

String _planName(String tier, int months) => '$tier ${months == 12 ? '1 Year' : (months == 1 ? '1 Month' : '$months Months')}';

/// The coaches on the gym's posters. Phone numbers and salaries are left for the owner to add.
const deekshith = Trainer(id: 't-deekshith', name: 'Deekshith Praveen', speciality: 'Kick boxing coach · International silver medallist', phone: '');
const greeta = Trainer(id: 't-greeta', name: 'Greeta', speciality: 'Boxing & self-defence coach · National medallist', phone: '');

/// Starting setup for a brand-new install: the Pinarayi branch, the gym's real plans, coaches and
/// class timetable, taken from its posters. Only the monthly target is a sample.
GymData baseSetup() {
  return GymData(
    settings: const GymSettings(
      gymName: 'Unique Fitness Gym',
      tagline: 'Premium Luxury Fitness Centre',
      branchName: 'Pinarayi',
      address: 'Aiswarya Shopping Mall, Pinarayi',
      phone: '9562277010',
      altPhone: '8921096344',
      ownerName: 'Owner',
      // The gym's UPI ID is not kept in the public repo: it is passed at build time
      // (--dart-define-from-file=private/gym.json). Without it, the owner adds it in Settings.
      upiId: String.fromEnvironment('GYM_UPI_ID'),
      // No joining fee: the price list is the full fee.
      admissionFee: 0,
      monthlyTarget: 150000,
    ),
    branches: const [pinarayi],
    plans: [
      for (final (months, price) in _silver)
        Plan(id: 'silver-${months}m', name: _planName('Silver', months), months: months, price: price.toDouble(), tier: PlanTier.silver, perks: PlanTier.silver.perks.join(' · ')),
      for (final (months, price) in _platinum)
        Plan(
          id: 'platinum-${months}m',
          name: _planName('Platinum', months),
          months: months,
          price: price.toDouble(),
          tier: PlanTier.platinum,
          perks: PlanTier.platinum.perks.join(' · '),
        ),
    ],
    trainers: const [deekshith, greeta],
    classes: const [
      GymClass(id: 'c-boxing', title: 'Boxing & Self-Defence', type: ClassType.boxing, trainerId: 't-greeta', weekdays: [2, 4, 6], startMinutes: 17 * 60, durationMin: 120, capacity: 20, notes: 'With coach Greeta'),
      GymClass(id: 'c-zumba', title: 'Zumba Dance Fitness', type: ClassType.zumba, weekdays: [1, 3, 5], startMinutes: 18 * 60, durationMin: 60, capacity: 30, notes: 'Second batch open. Dance, sweat, be happy'),
      GymClass(id: 'c-kickboxing', title: 'Kick Boxing', type: ClassType.kickBoxing, trainerId: 't-deekshith', weekdays: [1, 3, 5], startMinutes: 19 * 60 + 30, durationMin: 60, capacity: 20, notes: 'With coach Deekshith Praveen'),
    ],
    trainingPlans: trainingPlanTemplates,
  );
}

/// Starter workout and diet templates the trainers can assign and edit. General guidance only;
/// the diets use everyday Kerala food.
const trainingPlanTemplates = [
  TrainingPlan(
    id: 'tp-beginner',
    kind: TrainingPlanKind.workout,
    name: 'Beginner full body',
    goal: 'General fitness · first 8 weeks',
    sections: [
      PlanSection('Mon · Wed · Fri', 'Treadmill warm-up 10 min\nLeg press 3 × 12\nLat pulldown 3 × 12\nDumbbell chest press 3 × 12\nSeated row 3 × 12\nPlank 3 × 30 s'),
      PlanSection('Tue · Thu', 'Brisk walk or cycle 25 min\nStretching 10 min'),
      PlanSection('Progress', 'Add a little weight when all sets feel easy. Rest 60 to 90 s between sets.'),
    ],
    notes: 'Learn the form first. Ask a trainer before going heavy.',
  ),
  TrainingPlan(
    id: 'tp-fatloss',
    kind: TrainingPlanKind.workout,
    name: 'Fat loss circuit',
    goal: 'Weight loss · 5 days a week',
    sections: [
      PlanSection('Mon · Thu', 'Circuit × 4 rounds: goblet squat 15, push-ups 12, kettlebell swing 15, mountain climbers 30 s\nIncline walk 20 min'),
      PlanSection('Tue · Fri', 'Circuit × 4 rounds: lunges 12 each, seated row 15, shoulder press 12, burpees 10\nCycle 20 min'),
      PlanSection('Wed', 'Zumba or kick boxing class'),
      PlanSection('Weekend', 'Walk 8,000+ steps. One full rest day.'),
    ],
  ),
  TrainingPlan(
    id: 'tp-muscle',
    kind: TrainingPlanKind.workout,
    name: 'Muscle gain split',
    goal: 'Muscle gain · push, pull, legs',
    sections: [
      PlanSection('Push (Mon, Thu)', 'Bench press 4 × 8\nIncline dumbbell press 3 × 10\nShoulder press 3 × 10\nLateral raise 3 × 15\nTriceps pushdown 3 × 12'),
      PlanSection('Pull (Tue, Fri)', 'Deadlift 4 × 6\nPull-ups or lat pulldown 4 × 8\nBarbell row 3 × 10\nFace pull 3 × 15\nBiceps curl 3 × 12'),
      PlanSection('Legs (Wed, Sat)', 'Squat 4 × 8\nRomanian deadlift 3 × 10\nLeg press 3 × 12\nLeg curl 3 × 12\nCalf raise 4 × 15'),
    ],
    notes: 'Log your weights. Sleep 7 to 8 hours.',
  ),
  TrainingPlan(
    id: 'tp-diet-loss',
    kind: TrainingPlanKind.diet,
    name: 'Kerala fat loss diet',
    goal: 'Weight loss · about 1,600 kcal',
    sections: [
      PlanSection('Early morning', 'Warm water, 5 soaked almonds'),
      PlanSection('Breakfast', '2 idli or 1 small puttu with kadala curry, black coffee or tea without sugar'),
      PlanSection('Lunch', 'Half plate vegetables (thoran, avial), 1 cup rice, fish curry or dal, buttermilk'),
      PlanSection('Evening', 'Fruit or boiled chana, green tea'),
      PlanSection('Dinner', '2 chapati or oats with egg whites or grilled chicken, salad'),
      PlanSection('Rules', 'No fried snacks or sweets on weekdays. 3 litres of water.'),
    ],
  ),
  TrainingPlan(
    id: 'tp-diet-gain',
    kind: TrainingPlanKind.diet,
    name: 'High protein muscle gain',
    goal: 'Muscle gain · about 2,600 kcal',
    sections: [
      PlanSection('Breakfast', '4 eggs (2 whole), puttu or appam, banana, milk'),
      PlanSection('Mid-morning', 'Peanut butter sandwich or a whey shake'),
      PlanSection('Lunch', 'Rice, chicken or fish curry, thoran, curd'),
      PlanSection('After workout', 'Whey shake or 200 g paneer, a banana'),
      PlanSection('Dinner', 'Chapati or rice, chicken, egg or soya chunks, vegetables'),
      PlanSection('Rules', 'About 1.6 g of protein per kg body weight. Eat every 3 to 4 hours.'),
    ],
  ),
];

const _firstMale = [
  'Aarav', 'Vishnu', 'Nikhil', 'Gokul', 'Adithya', 'Sreejith', 'Midhun', 'Akhil', 'Jishnu', 'Basil', 'Sarath', 'Rohit', 'Ashwin',
  'Farhan', 'Kevin', 'Arjun', 'Abhinav', 'Anandu', 'Rahul', 'Shibin', 'Nidhin', 'Vyshakh', 'Amal', 'Sanju', 'Jithin', 'Fahad',
  'Ajmal', 'Rinshad', 'Hrithik', 'Athul', 'Sreerag', 'Muhammed', 'Nandu', 'Vivek', 'Ebin', 'Sooraj',
];
const _firstFemale = [
  'Sneha', 'Anjali', 'Divya', 'Fathima', 'Neha', 'Lakshmi', 'Amrutha', 'Hiba', 'Remya', 'Keerthana', 'Aswathy', 'Nandana',
  'Anagha', 'Gopika', 'Athira', 'Sana', 'Devika', 'Nimisha', 'Shilpa', 'Aparna', 'Riya', 'Meenakshi',
];
const _surnames = [
  'Krishnan', 'Pillai', 'Prasad', 'Raj', 'Varma', 'Suresh', 'Mohan', 'Babu', 'Joseph', 'Kumar', 'Anand', 'Das', 'Nair', 'Thomas',
  'Shahid', 'Raman', 'Gopal', 'Mathew', 'Chandran', 'Menon', 'Pai', 'Sunil', 'Rao', 'George', 'Rizwan', 'Balan', 'Vinod', 'Kurup',
];
const _goals = ['Weight loss', 'Muscle gain', 'General fitness', 'Boxing', 'Stamina', 'Strength', 'Flexibility'];

/// Two years of fictional history for the Pinarayi branch: admissions, renewals and lapses, part
/// payments, about two months of check-ins, expenses, enquiries and body checks. Every name and
/// number is invented. The result depends only on [now], so tests and screenshots are repeatable.
GymData demoData({required DateTime now}) {
  final base = baseSetup();
  final today = dateOnly(now);
  final rng = Random(7);
  final plans = {for (final p in base.plans) p.id: p};

  // A sample floor trainer for the demo's personal training, so no real coach's pay is invented.
  const floorTrainer = Trainer(id: 't-floor', name: 'Floor Trainer', speciality: 'Sample trainer · personal training', phone: '', commissionPct: 40);
  final trainers = [...base.trainers, floorTrainer];

  final members = <Member>[];
  final subscriptions = <Subscription>[];
  final payments = <Payment>[];
  final dedication = <String, double>{}; // how often each member turns up
  var receipt = 1;
  var subId = 1;

  var payId = 1;
  // One desk visit is one receipt: an admission fee and the plan share the receipt number and method.
  Payment pay(String memberId, double amount, DateTime date, PaymentKind kind, String note, String receiptNo, PayMethod method) => Payment(
        id: 'pay-${payId++}',
        receiptNo: receiptNo,
        memberId: memberId,
        amount: amount,
        date: date,
        method: method,
        kind: kind,
        note: note,
      );

  final firstDay = DateTime(today.year, today.month - 23, 1);
  var number = 1;
  for (var month = 0; month < 24; month++) {
    final monthStart = DateTime(firstDay.year, firstDay.month + month, 1);
    // A growing gym, with the usual January and monsoon-end bumps.
    final seasonal = monthStart.month == 1 ? 4 : (monthStart.month == 9 ? 2 : 0);
    final joins = 4 + (month * 0.4).round() + seasonal + rng.nextInt(3);
    for (var j = 0; j < joins; j++) {
      final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
      final join = DateTime(monthStart.year, monthStart.month, 1 + rng.nextInt(daysInMonth));
      if (join.isAfter(today)) continue;

      final female = rng.nextDouble() < 0.38;
      final first = female ? _firstFemale[rng.nextInt(_firstFemale.length)] : _firstMale[rng.nextInt(_firstMale.length)];
      final name = '$first ${_surnames[rng.nextInt(_surnames.length)]}';
      final roll = rng.nextDouble();
      // Most people take a short Silver plan; about a third choose Platinum.
      final tier = rng.nextDouble() < 0.34 ? 'platinum' : 'silver';
      final months = roll < 0.36 ? 1 : roll < 0.48 ? 2 : roll < 0.72 ? 3 : roll < 0.80 ? 4 : roll < 0.92 ? 6 : 12;
      var plan = plans['$tier-${months}m']!;
      final id = 'm-$number';

      // Walk the membership forward: renew most of the time, sometimes lapse for good.
      var start = join;
      var end = addMonths(start, plan.months);
      var due = 0.0;
      var isFirst = true;
      while (true) {
        final discount = isFirst && rng.nextDouble() < 0.2 ? 500.0 : 0.0;
        subscriptions.add(Subscription(
          id: 's-${subId++}',
          memberId: id,
          planId: plan.id,
          planName: plan.name,
          kind: isFirst ? SubscriptionKind.admission : SubscriptionKind.renewal,
          start: start,
          end: end,
          price: plan.price,
          discount: discount,
          createdAt: start.isAfter(now) ? now : start,
        ));
        var paidAt = start.add(Duration(hours: 9 + rng.nextInt(11), minutes: rng.nextInt(60)));
        if (paidAt.isAfter(now)) paidAt = now.subtract(Duration(minutes: 5 + rng.nextInt(60)));
        final receiptNo = 'RCPT-${(receipt++).toString().padLeft(5, '0')}';
        final method = [PayMethod.upi, PayMethod.upi, PayMethod.cash, PayMethod.cash, PayMethod.card, PayMethod.bank][rng.nextInt(6)];
        if (isFirst && base.settings.admissionFee > 0) {
          payments.add(pay(id, base.settings.admissionFee, paidAt, PaymentKind.admission, 'Admission fee', receiptNo, method));
        }
        final price = plan.price - discount;
        // About one in eight pays part now; only the latest period's balance is still open.
        final partial = rng.nextDouble() < 0.12;
        final paid = partial ? (price / 2 / 100).round() * 100.0 : price;
        payments.add(pay(id, paid, paidAt, PaymentKind.membership, '${plan.name} plan${isFirst ? '' : ' (renewal)'}', receiptNo, method));
        due = price - paid;
        isFirst = false;

        if (!end.isBefore(today)) break; // still running
        if (rng.nextDouble() > 0.72) break; // lapsed
        final gap = rng.nextDouble() < 0.7 ? 0 : 1 + rng.nextInt(6);
        final next = end.add(Duration(days: gap));
        if (next.isAfter(today)) break;
        start = next;
        if (rng.nextDouble() < 0.15) plan = plans['platinum-3m']!; // some move up to Platinum
        end = addMonths(start, plan.months);
      }

      final dob = DateTime(today.year - 18 - rng.nextInt(24), 1 + rng.nextInt(12), 1 + rng.nextInt(28));
      final height = female ? 150 + rng.nextInt(22) : 162 + rng.nextInt(24);
      members.add(Member(
        id: id,
        number: number,
        name: name,
        phone: '9${(400000000 + number * 7919 % 599999999).toString().padLeft(9, '0')}',
        gender: female ? Gender.female : Gender.male,
        dateOfBirth: dob,
        branchId: pinarayi.id,
        planId: plan.id,
        trainerId: rng.nextDouble() < 0.25 ? trainers[rng.nextInt(trainers.length)].id : null,
        joinDate: join,
        startDate: start,
        endDate: end,
        goal: _goals[rng.nextInt(_goals.length)],
        heightCm: height.toDouble(),
        weightKg: (female ? 50 : 62) + rng.nextInt(30).toDouble(),
        emergencyName: 'Family',
        emergencyPhone: '94000${(10000 + number).toString()}',
        source: LeadSource.values[rng.nextInt(LeadSource.values.length - 1)],
        balanceDue: due,
        // Most members are already enrolled on the Face ID terminal; a few recent joiners are not yet.
        deviceUserId: today.difference(join).inDays > 6 || number % 3 != 0 ? '$number' : null,
        faceEnrolled: today.difference(join).inDays > 6 || number % 3 != 0,
      ));
      dedication[id] = 0.3 + rng.nextDouble() * 0.55;
      number++;
    }
  }

  // Make the "today" lists lively: two birthdays today, and memberships ending this week.
  for (final i in [3, 11]) {
    if (i < members.length) {
      final m = members[members.length - 1 - i];
      members[members.length - 1 - i] = m.copyWith(dateOfBirth: DateTime(today.year - 27 + i, today.month, today.day));
    }
  }
  // One member is frozen (travelling), with the end date pushed out.
  final running = [for (var i = 0; i < members.length; i++) if (!members[i].endDate.isBefore(today)) i];
  if (running.length > 5) {
    final i = running[running.length ~/ 2];
    final m = members[i];
    members[i] = m.copyWith(
      endDate: m.endDate.add(const Duration(days: 14)),
      freezes: [Freeze(start: today.subtract(const Duration(days: 4)), days: 14, reason: 'Travelling')],
    );
  }

  // A few members clear their dues at the desk today, so today's collection is not empty.
  var settled = 0;
  for (var i = members.length - 1; i >= 0 && settled < 3; i--) {
    final m = members[i];
    if (m.balanceDue <= 0 || m.endDate.isBefore(today)) continue;
    final at = now.subtract(Duration(minutes: 20 + settled * 70));
    if (!sameDay(at, now)) break;
    payments.add(pay(m.id, m.balanceDue, at, PaymentKind.membership, 'Balance payment', 'RCPT-${(receipt++).toString().padLeft(5, '0')}', PayMethod.upi));
    members[i] = m.copyWith(balanceDue: 0);
    settled++;
  }

  // About two months of check-ins for members whose plan covered that day.
  final checkIns = <CheckIn>[];
  const hours = [5, 6, 6, 7, 7, 8, 9, 11, 16, 17, 17, 18, 18, 18, 19, 19, 20, 21];
  for (var d = 59; d >= 0; d--) {
    final day = today.subtract(Duration(days: d));
    final sunday = day.weekday == DateTime.sunday;
    for (final m in members) {
      if (day.isBefore(dateOnly(m.startDate)) || day.isAfter(dateOnly(m.endDate))) continue;
      if (m.freezeOn(day) != null) continue;
      // A few members drift away in the last two weeks, so the "missing workouts" list is real.
      final drifting = m.number % 9 == 0 && d < 14;
      final chance = dedication[m.id]! * (sunday ? 0.3 : 1) * (drifting ? 0 : 1);
      if (rng.nextDouble() >= chance) continue;
      final time = DateTime(day.year, day.month, day.day, hours[rng.nextInt(hours.length)], rng.nextInt(60));
      if (time.isAfter(now)) continue;
      checkIns.add(CheckIn(
        id: 'ci-${checkIns.length + 1}',
        memberId: m.id,
        time: time,
        // Entries come from the Face ID door; the desk checks in the odd member the device missed.
        source: m.deviceUserId != null && rng.nextDouble() < 0.92 ? CheckInSource.faceId : CheckInSource.desk,
      ));
    }
  }

  // Running costs for each month.
  final expenses = <Expense>[];
  for (var month = 0; month < 24; month++) {
    final m = DateTime(firstDay.year, firstDay.month + month, 1);
    void add(ExpenseCategory c, double amount, int day, String note) {
      final date = DateTime(m.year, m.month, day, 11);
      if (!date.isAfter(now)) {
        expenses.add(Expense(id: 'e-${expenses.length + 1}', category: c, amount: amount, date: date, note: note, method: c == ExpenseCategory.salary ? PayMethod.bank : PayMethod.upi));
      }
    }

    add(ExpenseCategory.rent, 18000, 5, 'Hall rent');
    // Fictional staff cost as one line, so no real person's pay is invented.
    add(ExpenseCategory.salary, 38000, 1, 'Staff salaries, ${formatMonthYear(DateTime(m.year, m.month - 1))}');
    add(ExpenseCategory.electricity, 6000 + rng.nextInt(4000).toDouble(), 12, 'KSEB bill');
    if (rng.nextDouble() < 0.5) add(ExpenseCategory.supplies, 800 + rng.nextInt(1500).toDouble(), 18, 'Cleaning supplies');
    if (rng.nextDouble() < 0.25) add(ExpenseCategory.maintenance, 1500 + rng.nextInt(4000).toDouble(), 21, 'Treadmill service');
    if (month % 7 == 3) add(ExpenseCategory.equipment, 18000 + rng.nextInt(20000).toDouble(), 15, 'New dumbbell set');
    if (month % 5 == 1) add(ExpenseCategory.marketing, 3000, 9, 'Instagram ads');
  }

  // Enquiries: some waiting for a call back today.
  const leadNames = ['Shyam Prakash', 'Ameena Basheer', 'Joel Varghese', 'Ritika Sharma', 'Haris Kader', 'Anu Mohan', 'Deepak Nambiar', 'Safna Riyas', 'Tony Jacob', 'Varsha Manoj'];
  final enquiries = <Enquiry>[
    for (var i = 0; i < leadNames.length; i++)
      Enquiry(
        id: 'q-${i + 1}',
        name: leadNames[i],
        phone: '98470${(11000 + i * 371).toString()}',
        gender: i.isEven ? Gender.male : Gender.female,
        planId: ['silver-1m', 'platinum-3m', 'silver-6m', null][i % 4],
        source: LeadSource.values[i % (LeadSource.values.length - 1)],
        status: [EnquiryStatus.open, EnquiryStatus.followUp, EnquiryStatus.trial, EnquiryStatus.followUp, EnquiryStatus.open, EnquiryStatus.converted, EnquiryStatus.lost, EnquiryStatus.followUp, EnquiryStatus.open, EnquiryStatus.trial][i],
        createdAt: now.subtract(Duration(days: i * 3 + 1, hours: i)),
        nextFollowUp: i % 3 == 2 ? today.add(const Duration(days: 2)) : (i == 6 || i == 5 ? null : today.subtract(Duration(days: i % 2))),
        notes: ['Asked about evening batch', 'Wants personal training', 'Free 3-day trial started', 'Comparing with other gyms', 'Interested in Zumba', 'Joined', 'Too far from home', 'Will join after exams', 'Came with a friend', 'Trial ends Friday'][i],
      ),
  ];

  // Monthly body checks for members on a trainer's programme.
  final measurements = <Measurement>[];
  for (final m in members.where((m) => m.trainerId != null && m.weightKg != null && !m.endDate.isBefore(today)).take(25)) {
    final losing = m.goal == 'Weight loss';
    var weight = m.weightKg! + (losing ? 6 : -3);
    for (var k = 5; k >= 0; k--) {
      final date = DateTime(today.year, today.month - k, 3);
      if (date.isBefore(m.joinDate) || date.isAfter(today)) continue;
      measurements.add(Measurement(id: 'w-${measurements.length + 1}', memberId: m.id, date: date, weightKg: double.parse(weight.toStringAsFixed(1)), waistCm: 70 + weight * 0.25));
      weight += losing ? -(0.6 + rng.nextDouble()) : (0.3 + rng.nextDouble() * 0.6);
    }
  }

  final extras = _demoExtras(now: now, rng: rng, members: members, payments: payments, expenses: expenses, checkIns: checkIns, pay: pay, nextReceipt: () => 'RCPT-${(receipt++).toString().padLeft(5, '0')}');

  return GymData(
    branches: base.branches,
    plans: base.plans,
    classes: extras.classes,
    trainers: trainers,
    members: members,
    subscriptions: subscriptions,
    payments: payments,
    expenses: expenses,
    checkIns: checkIns,
    enquiries: enquiries,
    measurements: measurements,
    trainingPlans: base.trainingPlans,
    ptPackages: extras.ptPackages,
    products: extras.products,
    sales: extras.sales,
    offers: extras.offers,
    dayCloses: extras.dayCloses,
    feedback: extras.feedback,
    settings: base.settings,
    nextMemberNumber: number,
    nextReceiptNumber: receipt,
  );
}

typedef _Pay = Payment Function(String memberId, double amount, DateTime date, PaymentKind kind, String note, String receiptNo, PayMethod method);

/// Demo shop, offers, personal training, class batches, referrals, plans, feedback and closed
/// days. Adds the matching payments to [payments] and updates [members] in place.
({List<GymClass> classes, List<PtPackage> ptPackages, List<Product> products, List<Sale> sales, List<Offer> offers, List<DayClose> dayCloses, List<FeedbackEntry> feedback}) _demoExtras({
  required DateTime now,
  required Random rng,
  required List<Member> members,
  required List<Payment> payments,
  required List<Expense> expenses,
  required List<CheckIn> checkIns,
  required _Pay pay,
  required String Function() nextReceipt,
}) {
  final today = dateOnly(now);
  final running = [for (final m in members) if (!m.endDate.isBefore(today) && m.freezeOn(today) == null) m];
  int indexOf(String id) => members.indexWhere((m) => m.id == id);

  // Shop: prices are samples. Two items are low on stock.
  final products = <Product>[
    const Product(id: 'pr-whey', name: 'Whey protein 1 kg', category: ProductCategory.supplement, price: 2400, cost: 1900, stock: 6, lowStockAt: 3),
    const Product(id: 'pr-creatine', name: 'Creatine 250 g', category: ProductCategory.supplement, price: 1100, cost: 820, stock: 2, lowStockAt: 3),
    const Product(id: 'pr-bcaa', name: 'BCAA drink', category: ProductCategory.drink, price: 60, cost: 38, stock: 34, lowStockAt: 10),
    const Product(id: 'pr-water', name: 'Water bottle 1 L', category: ProductCategory.drink, price: 20, cost: 12, stock: 7, lowStockAt: 10),
    const Product(id: 'pr-bar', name: 'Protein bar', category: ProductCategory.supplement, price: 90, cost: 62, stock: 22, lowStockAt: 6),
    const Product(id: 'pr-tee', name: 'Unique Fitness T-shirt', category: ProductCategory.merch, price: 499, cost: 260, stock: 14, lowStockAt: 4),
    const Product(id: 'pr-shaker', name: 'Shaker bottle', category: ProductCategory.merch, price: 250, cost: 140, stock: 9, lowStockAt: 3),
    const Product(id: 'pr-gloves', name: 'Gym gloves', category: ProductCategory.gear, price: 650, cost: 400, stock: 5, lowStockAt: 2),
    const Product(id: 'pr-wraps', name: 'Boxing hand wraps', category: ProductCategory.gear, price: 350, cost: 190, stock: 8, lowStockAt: 3),
  ];
  // Drinks sell daily; the rest now and then.
  final weights = [3, 1, 14, 18, 8, 2, 2, 1, 2];
  final totalWeight = weights.fold(0, (a, b) => a + b);
  Product pick() {
    var r = rng.nextInt(totalWeight);
    for (var i = 0; i < products.length; i++) {
      if ((r -= weights[i]) < 0) return products[i];
    }
    return products.last;
  }

  final sales = <Sale>[];
  for (var d = 45; d >= 0; d--) {
    final day = today.subtract(Duration(days: d));
    final count = d == 0 ? 3 : rng.nextInt(4);
    for (var k = 0; k < count; k++) {
      final time = DateTime(day.year, day.month, day.day, [6, 7, 8, 17, 18, 19][rng.nextInt(6)], rng.nextInt(60));
      if (time.isAfter(now)) continue;
      final p = pick();
      final qty = p.category == ProductCategory.drink ? 1 + rng.nextInt(2) : 1;
      final member = running.isEmpty || rng.nextDouble() < 0.25 ? null : running[rng.nextInt(running.length)];
      final method = rng.nextDouble() < 0.55 ? PayMethod.cash : PayMethod.upi;
      final receipt = nextReceipt();
      final line = SaleLine(productId: p.id, name: p.name, qty: qty, price: p.price);
      sales.add(Sale(id: 'sale-${sales.length + 1}', receiptNo: receipt, memberId: member?.id, buyerName: member?.name ?? 'Walk-in', lines: [line], method: method, date: time));
      final payment = pay(member?.id ?? '', line.total, time, PaymentKind.product, '$qty × ${p.name}', receipt, method);
      payments.add(member == null ? Payment(id: payment.id, receiptNo: receipt, memberId: '', amount: payment.amount, date: time, method: method, kind: PaymentKind.product, note: payment.note, payerName: 'Walk-in') : payment);
    }
  }

  // Day passes: a few walk-ins each week.
  const visitors = ['Tourist from Kochi', 'Ajay (visiting)', 'Rinu S', 'Manu Thomas', 'Shafeeq', 'Visitor'];
  for (var d = 30; d >= 1; d -= 1 + rng.nextInt(4)) {
    final time = today.subtract(Duration(days: d)).add(Duration(hours: 7 + rng.nextInt(12)));
    final p = pay('', 150, time, PaymentKind.dayPass, 'Day pass', nextReceipt(), PayMethod.cash);
    payments.add(Payment(id: p.id, receiptNo: p.receiptNo, memberId: '', amount: 150, date: time, method: PayMethod.cash, kind: PaymentKind.dayPass, note: 'Day pass', payerName: visitors[rng.nextInt(visitors.length)]));
  }

  // Offer codes.
  final offers = [
    Offer(id: 'o-onam', code: 'ONAM10', value: 10, validUntil: today.add(const Duration(days: 20)), maxUses: 50, used: 12),
    const Offer(id: 'o-friend', code: 'FRIEND500', percent: false, value: 500, used: 7),
    Offer(id: 'o-newyear', code: 'NEWYEAR15', value: 15, validUntil: DateTime(today.year, 1, 31), maxUses: 40, used: 40),
  ];

  // Personal training with the sample floor trainer; a few packages nearly used up.
  final ptPackages = <PtPackage>[];
  final ptMembers = running.where((m) => m.number.isEven).take(7).toList();
  for (var i = 0; i < ptMembers.length; i++) {
    final m = ptMembers[i];
    final total = [12, 12, 24, 8][i % 4];
    final price = total * 500.0;
    final sold = today.subtract(Duration(days: 8 + i * 5));
    final used = <DateTime>[];
    for (var day = sold.add(const Duration(days: 1)); !day.isAfter(today) && used.length < total - (i < 2 ? 1 : 3); day = day.add(Duration(days: 1 + rng.nextInt(2)))) {
      final t = DateTime(day.year, day.month, day.day, 18, 30);
      if (!t.isAfter(now)) used.add(t);
    }
    ptPackages.add(PtPackage(id: 'pt-${i + 1}', memberId: m.id, trainerId: 't-floor', sessionsTotal: total, price: price, soldAt: sold.add(const Duration(hours: 19)), expiresAt: sold.add(const Duration(days: 60)), sessions: used));
    payments.add(pay(m.id, price, sold.add(const Duration(hours: 19)), PaymentKind.personalTraining, 'PT: $total sessions with Floor Trainer', nextReceipt(), PayMethod.upi));
  }

  // Referrals: newer members brought in by earlier ones.
  final byJoin = [...members]..sort((a, b) => a.joinDate.compareTo(b.joinDate));
  for (var k = byJoin.length - 1, made = 0; k > 20 && made < 12; k -= 3, made++) {
    final referrer = byJoin[rng.nextInt(k - 10)];
    final i = indexOf(byJoin[k].id);
    members[i] = members[i].copyWith(referredById: referrer.id);
  }

  // Workout and diet plans for members on a trainer's programme.
  for (var i = 0; i < members.length; i++) {
    final m = members[i];
    if (m.trainerId == null || m.endDate.isBefore(today)) continue;
    final losing = m.goal == 'Weight loss';
    final gaining = m.goal == 'Muscle gain' || m.goal == 'Strength';
    members[i] = m.copyWith(
      workoutPlanId: losing ? 'tp-fatloss' : gaining ? 'tp-muscle' : 'tp-beginner',
      dietPlanId: losing ? 'tp-diet-loss' : gaining ? 'tp-diet-gain' : null,
    );
  }

  // Class batches.
  final base = baseSetup().classes;
  final classes = [
    for (final c in base)
      c.copyWith(memberIds: [
        for (final m in running.where((m) => c.type == ClassType.zumba ? m.gender == Gender.female : m.number % 4 == (c.type == ClassType.boxing ? 1 : 2)).take(c.type == ClassType.zumba ? 24 : 14)) m.id,
      ]),
  ];

  // Feedback: mostly happy, two open complaints.
  const notes = [
    (5, FeedbackCategory.trainers, 'The coach explains every move. Loving the boxing batch.', true),
    (4, FeedbackCategory.equipment, 'Good machines. Please add one more squat rack.', true),
    (2, FeedbackCategory.timing, 'Too crowded at 6:30 pm, waiting for benches.', false),
    (5, FeedbackCategory.cleanliness, 'Very clean washrooms.', true),
    (3, FeedbackCategory.facilities, 'AC in the cardio area is weak in the afternoon.', false),
    (5, FeedbackCategory.other, 'Best gym in Pinarayi!', true),
    (4, FeedbackCategory.trainers, 'Zumba is so much fun.', true),
    (5, FeedbackCategory.equipment, 'New dumbbells are great.', true),
    (4, FeedbackCategory.timing, 'Happy with the 5 am opening.', true),
  ];
  final feedback = <FeedbackEntry>[
    for (var i = 0; i < notes.length && i < running.length; i++)
      FeedbackEntry(
        id: 'fb-${i + 1}',
        memberId: running[(i * 7) % running.length].id,
        name: running[(i * 7) % running.length].name,
        rating: notes[i].$1,
        category: notes[i].$2,
        comment: notes[i].$3,
        createdAt: now.subtract(Duration(days: i * 6 + 1, hours: i)),
        resolved: notes[i].$4,
        response: notes[i].$4 && notes[i].$1 <= 4 ? 'Thanks, noted.' : '',
      ),
  ];

  // The last two weeks were closed at the desk; one evening was ₹200 short.
  final dayCloses = <DayClose>[];
  for (var d = 14; d >= 1; d--) {
    final day = today.subtract(Duration(days: d));
    double sum(PayMethod m) => payments.where((p) => sameDay(p.date, day) && p.method == m).fold(0.0, (s, p) => s + p.amount);
    final cashOut = expenses.where((e) => sameDay(e.date, day) && e.method == PayMethod.cash).fold(0.0, (s, e) => s + e.amount);
    final expected = sum(PayMethod.cash) - cashOut;
    dayCloses.add(DayClose(
      id: 'dc-${dayCloses.length + 1}',
      date: day,
      cashIn: sum(PayMethod.cash),
      cashOut: cashOut,
      counted: d == 5 ? expected - 200 : expected,
      upi: sum(PayMethod.upi),
      card: sum(PayMethod.card),
      bank: sum(PayMethod.bank),
      note: d == 5 ? 'Change given twice by mistake' : '',
      closedAt: DateTime(day.year, day.month, day.day, 21, 40),
    ));
  }

  return (classes: classes, ptPackages: ptPackages, products: products, sales: sales, offers: offers, dayCloses: dayCloses, feedback: feedback);
}
