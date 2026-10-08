import 'package:flutter/material.dart';

import 'json.dart';

/// The app runs one branch today (Pinarayi). Records still carry a branch id so more branches can
/// be added later without migrating saved data.
class Branch {
  final String id;
  final String name;
  final String area;

  const Branch({required this.id, required this.name, required this.area});

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(id: str(j['id']), name: str(j['name']), area: str(j['area']));

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'area': area};
}

class Trainer {
  final String id;
  final String name;
  final String speciality;
  final String phone;
  final double monthlySalary;

  /// Share of personal-training income the trainer earns, in percent.
  final double commissionPct;

  const Trainer({required this.id, required this.name, required this.speciality, required this.phone, this.monthlySalary = 0, this.commissionPct = 0});

  Trainer copyWith({String? name, String? speciality, String? phone, double? monthlySalary, double? commissionPct}) => Trainer(
        id: id,
        name: name ?? this.name,
        speciality: speciality ?? this.speciality,
        phone: phone ?? this.phone,
        monthlySalary: monthlySalary ?? this.monthlySalary,
        commissionPct: commissionPct ?? this.commissionPct,
      );

  factory Trainer.fromJson(Map<String, dynamic> j) => Trainer(
        id: str(j['id']),
        name: str(j['name'], 'Trainer'),
        speciality: str(j['speciality']),
        phone: str(j['phone']),
        monthlySalary: doubleOr(j['monthlySalary']),
        commissionPct: doubleOr(j['commissionPct']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'speciality': speciality, 'phone': phone, 'monthlySalary': monthlySalary, 'commissionPct': commissionPct};
}

/// Membership tier from the gym's price list. Each tier has its own perks and a metallic look.
enum PlanTier {
  silver('Silver', ['Strength training', 'Fingerprint access']),
  platinum('Platinum', ['Strength training', 'Face ID biometric', 'Cardio access', 'Doctor consultation']),
  other('Other', []);

  const PlanTier(this.label, this.perks);
  final String label;
  final List<String> perks;
}

class Plan {
  final String id;
  final String name;
  final int months;
  final double price;
  final String perks;
  final bool popular;
  final bool active; // retired plans stay for history but are not offered at the desk
  final PlanTier tier;

  const Plan({
    required this.id,
    required this.name,
    required this.months,
    required this.price,
    this.perks = '',
    this.popular = false,
    this.active = true,
    this.tier = PlanTier.other,
  });

  Plan copyWith({String? name, int? months, double? price, String? perks, bool? popular, bool? active, PlanTier? tier}) => Plan(
        id: id,
        name: name ?? this.name,
        months: months ?? this.months,
        price: price ?? this.price,
        perks: perks ?? this.perks,
        popular: popular ?? this.popular,
        active: active ?? this.active,
        tier: tier ?? this.tier,
      );

  String get durationLabel => months == 12 ? '1 year' : (months == 1 ? '1 month' : '$months months');

  double get perMonth => months <= 0 ? price : price / months;

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: str(j['id']),
        name: str(j['name'], 'Plan'),
        months: intOr(j['months'], 1),
        price: doubleOr(j['price']),
        perks: str(j['perks']),
        popular: j['popular'] == true,
        active: j['active'] != false,
        tier: enumByName(PlanTier.values, j['tier'], PlanTier.other),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'months': months, 'price': price, 'perks': perks, 'popular': popular, 'active': active, 'tier': tier.name};
}

enum ClassType {
  boxing('Boxing & Self-Defence', Icons.sports_mma_rounded, Color(0xFFE11D2A)),
  kickBoxing('Kick Boxing', Icons.sports_kabaddi_rounded, Color(0xFFFF6B1A)),
  zumba('Zumba', Icons.music_note_rounded, Color(0xFFFF4DA6)),
  kidsBoxing('Kids Boxing', Icons.child_care_rounded, Color(0xFFFFB020)),
  strength('Strength', Icons.fitness_center_rounded, Color(0xFF3B82F6)),
  cardio('Cardio & HIIT', Icons.local_fire_department_rounded, Color(0xFFFFB020)),
  yoga('Yoga & Mobility', Icons.self_improvement_rounded, Color(0xFF2FD07F));

  const ClassType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class GymClass {
  final String id;
  final String title;
  final ClassType type;
  final String? trainerId;
  final List<int> weekdays; // DateTime.monday (1) to DateTime.sunday (7)
  final int startMinutes; // minutes after midnight, e.g. 17:30 = 1050
  final int durationMin;
  final int capacity;
  final String notes;

  /// Members enrolled in this batch.
  final List<String> memberIds;

  const GymClass({
    required this.id,
    required this.title,
    required this.type,
    this.trainerId,
    required this.weekdays,
    required this.startMinutes,
    this.durationMin = 60,
    this.capacity = 20,
    this.notes = '',
    this.memberIds = const [],
  });

  int get endMinutes => startMinutes + durationMin;
  int get spotsLeft => (capacity - memberIds.length).clamp(0, capacity);

  GymClass copyWith({
    String? title,
    ClassType? type,
    String? trainerId,
    bool clearTrainer = false,
    List<int>? weekdays,
    int? startMinutes,
    int? durationMin,
    int? capacity,
    String? notes,
    List<String>? memberIds,
  }) =>
      GymClass(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        trainerId: clearTrainer ? null : (trainerId ?? this.trainerId),
        weekdays: weekdays ?? this.weekdays,
        startMinutes: startMinutes ?? this.startMinutes,
        durationMin: durationMin ?? this.durationMin,
        capacity: capacity ?? this.capacity,
        notes: notes ?? this.notes,
        memberIds: memberIds ?? this.memberIds,
      );

  factory GymClass.fromJson(Map<String, dynamic> j) => GymClass(
        id: str(j['id']),
        title: str(j['title'], 'Class'),
        type: enumByName(ClassType.values, j['type'], ClassType.strength),
        trainerId: strOrNull(j['trainerId']),
        weekdays: j['weekdays'] is List ? [for (final e in j['weekdays'] as List) if (e is num) e.toInt()] : const [],
        startMinutes: intOr(j['startMinutes'], 18 * 60),
        durationMin: intOr(j['durationMin'], 60),
        capacity: intOr(j['capacity'], 20),
        notes: str(j['notes']),
        memberIds: j['memberIds'] is List ? [for (final e in j['memberIds'] as List) if (e is String) e] : const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'trainerId': trainerId,
        'weekdays': weekdays,
        'startMinutes': startMinutes,
        'durationMin': durationMin,
        'capacity': capacity,
        'notes': notes,
        'memberIds': memberIds,
      };
}

enum CheckInSource {
  desk('Front desk'),
  faceId('Face ID');

  const CheckInSource(this.label);
  final String label;
}

class CheckIn {
  final String id;
  final String memberId;
  final DateTime time;
  final CheckInSource source;

  const CheckIn({required this.id, required this.memberId, required this.time, this.source = CheckInSource.desk});

  factory CheckIn.fromJson(Map<String, dynamic> j) => CheckIn(
        id: str(j['id']),
        memberId: str(j['memberId']),
        time: dateOr(j['time'], DateTime(2000)),
        source: enumByName(CheckInSource.values, j['source'], CheckInSource.desk),
      );

  Map<String, dynamic> toJson() => {'id': id, 'memberId': memberId, 'time': time.toIso8601String(), 'source': source.name};
}

/// The kinds of WhatsApp message the front desk sends. Each has its own template and its own
/// "don't send again for N days" window so nobody gets spammed.
enum ReminderKind {
  expiring('Expiring soon', Icons.hourglass_bottom_rounded, Color(0xFFFFB020), 3),
  expired('Expired', Icons.history_rounded, Color(0xFFFF4D4F), 7),
  due('Pending dues', Icons.account_balance_wallet_rounded, Color(0xFFFF6B1A), 3),
  birthday('Birthdays', Icons.cake_rounded, Color(0xFFFF4DA6), 1),
  inactive('Missing workouts', Icons.directions_run_rounded, Color(0xFF3B82F6), 7),
  followUp('Enquiry follow-ups', Icons.support_agent_rounded, Color(0xFFB57BFF), 1),
  welcome('Welcome', Icons.celebration_rounded, Color(0xFF2FD07F), 36500),
  progress('Progress reports', Icons.insights_rounded, Color(0xFF199E70), 25);

  const ReminderKind(this.label, this.icon, this.color, this.cooldownDays);
  final String label;
  final IconData icon;
  final Color color;

  /// After a message is sent, the person drops off this list for this many days.
  final int cooldownDays;
}

class ReminderLog {
  final String id;
  final String targetId; // member id, or enquiry id for follow-ups
  final ReminderKind kind;
  final DateTime sentAt;

  const ReminderLog({required this.id, required this.targetId, required this.kind, required this.sentAt});

  factory ReminderLog.fromJson(Map<String, dynamic> j) => ReminderLog(
        id: str(j['id']),
        targetId: str(j['targetId']),
        kind: enumByName(ReminderKind.values, j['kind'], ReminderKind.expiring),
        sentAt: dateOr(j['sentAt'], DateTime(2000)),
      );

  Map<String, dynamic> toJson() => {'id': id, 'targetId': targetId, 'kind': kind.name, 'sentAt': sentAt.toIso8601String()};
}

/// WhatsApp message templates. Placeholders in braces are filled in per member, see [placeholders].
class MessageTemplates {
  final Map<ReminderKind, String> texts;

  const MessageTemplates([this.texts = const {}]);

  static const placeholders = {
    '{name}': 'First name',
    '{gym}': 'Gym name',
    '{plan}': 'Plan name',
    '{date}': 'End date',
    '{days}': 'Days left',
    '{amount}': 'Balance due',
    '{code}': 'Member code',
    '{phone}': 'Gym phone',
  };

  static const defaults = {
    ReminderKind.expiring: 'Hi {name}, your {gym} membership ({plan}) ends on {date}, {days}. '
        'Renew now to keep your progress going! Reply here or call {phone}. 💪',
    ReminderKind.expired: 'Hi {name}, we miss you at {gym}! Your {plan} membership ended on {date}. '
        'Come back this week and pick up where you left off. Call {phone} to renew. 🔥',
    ReminderKind.due: 'Hi {name}, a gentle reminder from {gym}: your pending balance is {amount}. '
        'You can pay at the front desk or by UPI. Thank you! 🙏',
    ReminderKind.birthday: 'Happy birthday {name}! 🎉 Wishing you a strong and healthy year ahead from all of us at {gym}. 🎂',
    ReminderKind.inactive: "Hi {name}, we haven't seen you at {gym} for a while. Your membership is still running till {date}. "
        "Let's get back on track, see you today? 💪",
    ReminderKind.followUp: 'Hi {name}, thanks for visiting {gym}! Ready to start your fitness journey? '
        'Join this week and we will help you set up a plan. Call {phone} for details.',
    ReminderKind.welcome: 'Welcome to {gym}, {name}! 🎉 Your member ID is {code}. Your {plan} membership is active till {date}. '
        "Let's get strong together! 💪",
    ReminderKind.progress: 'Hi {name}, here is your monthly progress report from {gym}. Thank you for training with us!',
  };

  String of(ReminderKind kind) {
    final custom = texts[kind];
    return custom == null || custom.trim().isEmpty ? defaults[kind]! : custom;
  }

  MessageTemplates withText(ReminderKind kind, String? text) {
    final next = Map<ReminderKind, String>.from(texts);
    if (text == null || text.trim().isEmpty || text == defaults[kind]) {
      next.remove(kind);
    } else {
      next[kind] = text;
    }
    return MessageTemplates(next);
  }

  factory MessageTemplates.fromJson(Object? j) {
    if (j is! Map) return const MessageTemplates();
    final texts = <ReminderKind, String>{};
    j.forEach((key, value) {
      final kind = ReminderKind.values.where((k) => k.name == key).firstOrNull;
      if (kind != null && value is String) texts[kind] = value;
    });
    return MessageTemplates(texts);
  }

  Map<String, dynamic> toJson() => {for (final e in texts.entries) e.key.name: e.value};
}

/// Fills `{name}`-style placeholders. Unknown placeholders are left as they are.
String fillTemplate(String template, Map<String, String> values) =>
    template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => values['{${m[1]}}'] ?? m[0]!);

class GymSettings {
  final String gymName;
  final String tagline;
  final String branchName;
  final String address;
  final String phone;
  final String altPhone;
  final String ownerName;
  final String upiId;
  final int expiryAlertDays;
  final int inactiveAfterDays;
  final double admissionFee;
  final double monthlyTarget;
  final String? pinHash; // owner PIN, salted SHA-256; null means no PIN
  final String? pinSalt;
  final MessageTemplates templates;

  /// Face ID terminal on the gym network (eSSL/ZKTeco, port 4370). Empty host means not set up.
  final String deviceHost;
  final int devicePort;
  final int deviceCommKey;

  /// Door rules the app enforces on the terminal.
  final bool blockExpiredAtDoor;
  final bool blockDuesAtDoor;
  final bool syncDeviceClock;
  final DateTime? lastDeviceSync;

  /// The owner's WhatsApp number for the end-of-day report.
  final String ownerPhone;

  /// Front desk extras.
  final double dayPassPrice;
  final int trialDays;
  final int referralRewardDays;
  final bool dailyNotification;
  final int notifyHour;

  /// True while the fictional demo data is loaded: WhatsApp and calls then show a preview instead
  /// of contacting anyone, because demo phone numbers could belong to real people.
  final bool demoData;

  const GymSettings({
    this.gymName = 'Unique Fitness Gym',
    this.tagline = '',
    this.branchName = 'Pinarayi',
    this.address = '',
    this.phone = '',
    this.altPhone = '',
    this.ownerName = 'Owner',
    this.upiId = '',
    this.expiryAlertDays = 7,
    this.inactiveAfterDays = 10,
    this.admissionFee = 0,
    this.monthlyTarget = 0,
    this.pinHash,
    this.pinSalt,
    this.templates = const MessageTemplates(),
    this.deviceHost = '',
    this.devicePort = 4370,
    this.deviceCommKey = 0,
    this.blockExpiredAtDoor = true,
    this.blockDuesAtDoor = false,
    this.syncDeviceClock = true,
    this.lastDeviceSync,
    this.ownerPhone = '',
    this.dayPassPrice = 0,
    this.trialDays = 3,
    this.referralRewardDays = 15,
    this.dailyNotification = true,
    this.notifyHour = 9,
    this.demoData = false,
  });

  bool get hasPin => pinHash != null && pinSalt != null;

  GymSettings copyWith({
    String? gymName,
    String? tagline,
    String? branchName,
    String? address,
    String? phone,
    String? altPhone,
    String? ownerName,
    String? upiId,
    int? expiryAlertDays,
    int? inactiveAfterDays,
    double? admissionFee,
    double? monthlyTarget,
    String? pinHash,
    String? pinSalt,
    bool clearPin = false,
    MessageTemplates? templates,
    String? deviceHost,
    int? devicePort,
    int? deviceCommKey,
    bool? blockExpiredAtDoor,
    bool? blockDuesAtDoor,
    bool? syncDeviceClock,
    DateTime? lastDeviceSync,
    String? ownerPhone,
    double? dayPassPrice,
    int? trialDays,
    int? referralRewardDays,
    bool? dailyNotification,
    int? notifyHour,
    bool? demoData,
  }) =>
      GymSettings(
        gymName: gymName ?? this.gymName,
        tagline: tagline ?? this.tagline,
        branchName: branchName ?? this.branchName,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        altPhone: altPhone ?? this.altPhone,
        ownerName: ownerName ?? this.ownerName,
        upiId: upiId ?? this.upiId,
        expiryAlertDays: expiryAlertDays ?? this.expiryAlertDays,
        inactiveAfterDays: inactiveAfterDays ?? this.inactiveAfterDays,
        admissionFee: admissionFee ?? this.admissionFee,
        monthlyTarget: monthlyTarget ?? this.monthlyTarget,
        pinHash: clearPin ? null : (pinHash ?? this.pinHash),
        pinSalt: clearPin ? null : (pinSalt ?? this.pinSalt),
        templates: templates ?? this.templates,
        deviceHost: deviceHost ?? this.deviceHost,
        devicePort: devicePort ?? this.devicePort,
        deviceCommKey: deviceCommKey ?? this.deviceCommKey,
        blockExpiredAtDoor: blockExpiredAtDoor ?? this.blockExpiredAtDoor,
        blockDuesAtDoor: blockDuesAtDoor ?? this.blockDuesAtDoor,
        syncDeviceClock: syncDeviceClock ?? this.syncDeviceClock,
        lastDeviceSync: lastDeviceSync ?? this.lastDeviceSync,
        ownerPhone: ownerPhone ?? this.ownerPhone,
        dayPassPrice: dayPassPrice ?? this.dayPassPrice,
        trialDays: trialDays ?? this.trialDays,
        referralRewardDays: referralRewardDays ?? this.referralRewardDays,
        dailyNotification: dailyNotification ?? this.dailyNotification,
        notifyHour: notifyHour ?? this.notifyHour,
        demoData: demoData ?? this.demoData,
      );

  factory GymSettings.fromJson(Map<String, dynamic> j) => GymSettings(
        gymName: str(j['gymName'], 'Unique Fitness Gym'),
        tagline: str(j['tagline']),
        branchName: str(j['branchName'], 'Pinarayi'),
        address: str(j['address']),
        phone: str(j['phone']),
        altPhone: str(j['altPhone']),
        ownerName: str(j['ownerName'], 'Owner'),
        upiId: str(j['upiId']),
        expiryAlertDays: intOr(j['expiryAlertDays'], 7),
        inactiveAfterDays: intOr(j['inactiveAfterDays'], 10),
        admissionFee: doubleOr(j['admissionFee']),
        monthlyTarget: doubleOr(j['monthlyTarget']),
        pinHash: strOrNull(j['pinHash']),
        pinSalt: strOrNull(j['pinSalt']),
        templates: MessageTemplates.fromJson(j['templates']),
        deviceHost: str(j['deviceHost']),
        devicePort: intOr(j['devicePort'], 4370),
        deviceCommKey: intOr(j['deviceCommKey']),
        blockExpiredAtDoor: j['blockExpiredAtDoor'] != false,
        blockDuesAtDoor: j['blockDuesAtDoor'] == true,
        syncDeviceClock: j['syncDeviceClock'] != false,
        lastDeviceSync: dateOrNull(j['lastDeviceSync']),
        ownerPhone: str(j['ownerPhone']),
        dayPassPrice: doubleOr(j['dayPassPrice']),
        trialDays: intOr(j['trialDays'], 3),
        referralRewardDays: intOr(j['referralRewardDays'], 15),
        dailyNotification: j['dailyNotification'] != false,
        notifyHour: intOr(j['notifyHour'], 9),
        demoData: j['demoData'] == true,
      );

  Map<String, dynamic> toJson() => {
        'gymName': gymName,
        'tagline': tagline,
        'branchName': branchName,
        'address': address,
        'phone': phone,
        'altPhone': altPhone,
        'ownerName': ownerName,
        'upiId': upiId,
        'expiryAlertDays': expiryAlertDays,
        'inactiveAfterDays': inactiveAfterDays,
        'admissionFee': admissionFee,
        'monthlyTarget': monthlyTarget,
        'pinHash': pinHash,
        'pinSalt': pinSalt,
        'templates': templates.toJson(),
        'deviceHost': deviceHost,
        'devicePort': devicePort,
        'deviceCommKey': deviceCommKey,
        'blockExpiredAtDoor': blockExpiredAtDoor,
        'blockDuesAtDoor': blockDuesAtDoor,
        'syncDeviceClock': syncDeviceClock,
        'lastDeviceSync': lastDeviceSync?.toIso8601String(),
        'ownerPhone': ownerPhone,
        'dayPassPrice': dayPassPrice,
        'trialDays': trialDays,
        'referralRewardDays': referralRewardDays,
        'dailyNotification': dailyNotification,
        'notifyHour': notifyHour,
        'demoData': demoData,
      };
}
