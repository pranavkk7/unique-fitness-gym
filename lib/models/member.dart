import 'json.dart';
import 'lead.dart';

enum Gender {
  male('Male'),
  female('Female'),
  other('Other');

  const Gender(this.label);
  final String label;
}

enum MemberStatus { active, expiringSoon, expired, frozen }

/// A pause in a membership (travel, illness). The end date moves out by the frozen days.
class Freeze {
  final DateTime start;
  final int days;
  final String reason;

  const Freeze({required this.start, required this.days, this.reason = ''});

  /// First day the membership runs again.
  DateTime get end => DateTime(start.year, start.month, start.day + days);

  bool covers(DateTime day) => !day.isBefore(start) && day.isBefore(end);

  factory Freeze.fromJson(Map<String, dynamic> j) =>
      Freeze(start: dateOr(j['start'], DateTime(2000)), days: intOr(j['days']), reason: str(j['reason']));

  Map<String, dynamic> toJson() => {'start': isoDate(start), 'days': days, 'reason': reason};
}

class Member {
  final String id;
  final int number; // shown as UFG-0001
  final String name;
  final String phone;
  final Gender gender;
  final DateTime? dateOfBirth;
  final String email;
  final String address;
  final String branchId;
  final String planId;
  final String? trainerId;
  final DateTime joinDate;
  final DateTime startDate;
  final DateTime endDate;
  final String goal;
  final double? heightCm;
  final double? weightKg;
  final String medicalNotes;
  final String emergencyName;
  final String emergencyPhone;
  final LeadSource source;
  final String notes;
  final double balanceDue;
  final bool hasPhoto;
  final List<Freeze> freezes;

  /// The member's ID on the Face ID terminal ("236"), once linked or registered from the app.
  final String? deviceUserId;

  /// True once their face is enrolled on the terminal.
  final bool faceEnrolled;

  /// The member who brought them in, for referral rewards.
  final String? referredById;

  /// Workout and diet plans their trainer assigned.
  final String? workoutPlanId;
  final String? dietPlanId;

  const Member({
    required this.id,
    required this.number,
    required this.name,
    required this.phone,
    required this.gender,
    this.dateOfBirth,
    this.email = '',
    this.address = '',
    required this.branchId,
    required this.planId,
    this.trainerId,
    required this.joinDate,
    required this.startDate,
    required this.endDate,
    this.goal = '',
    this.heightCm,
    this.weightKg,
    this.medicalNotes = '',
    this.emergencyName = '',
    this.emergencyPhone = '',
    this.source = LeadSource.walkIn,
    this.notes = '',
    this.balanceDue = 0,
    this.hasPhoto = false,
    this.freezes = const [],
    this.deviceUserId,
    this.faceEnrolled = false,
    this.referredById,
    this.workoutPlanId,
    this.dietPlanId,
  });

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  /// Body-mass index, or null when height or weight is missing.
  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm! <= 0) return null;
    final m = heightCm! / 100;
    return weightKg! / (m * m);
  }

  /// The freeze running on [day], if any.
  Freeze? freezeOn(DateTime day) {
    for (final f in freezes) {
      if (f.covers(day)) return f;
    }
    return null;
  }

  Member copyWith({
    String? name,
    String? phone,
    Gender? gender,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? email,
    String? address,
    String? planId,
    String? trainerId,
    bool clearTrainer = false,
    DateTime? startDate,
    DateTime? endDate,
    String? goal,
    double? heightCm,
    bool clearHeight = false,
    double? weightKg,
    bool clearWeight = false,
    String? medicalNotes,
    String? emergencyName,
    String? emergencyPhone,
    LeadSource? source,
    String? notes,
    double? balanceDue,
    bool? hasPhoto,
    List<Freeze>? freezes,
    String? deviceUserId,
    bool clearDevice = false,
    bool? faceEnrolled,
    String? workoutPlanId,
    bool clearWorkoutPlan = false,
    String? dietPlanId,
    bool clearDietPlan = false,
    String? referredById,
  }) =>
      Member(
        id: id,
        number: number,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        gender: gender ?? this.gender,
        dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
        email: email ?? this.email,
        address: address ?? this.address,
        branchId: branchId,
        planId: planId ?? this.planId,
        trainerId: clearTrainer ? null : (trainerId ?? this.trainerId),
        joinDate: joinDate,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        goal: goal ?? this.goal,
        heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
        weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
        medicalNotes: medicalNotes ?? this.medicalNotes,
        emergencyName: emergencyName ?? this.emergencyName,
        emergencyPhone: emergencyPhone ?? this.emergencyPhone,
        source: source ?? this.source,
        notes: notes ?? this.notes,
        balanceDue: balanceDue ?? this.balanceDue,
        hasPhoto: hasPhoto ?? this.hasPhoto,
        freezes: freezes ?? this.freezes,
        deviceUserId: clearDevice ? null : (deviceUserId ?? this.deviceUserId),
        faceEnrolled: clearDevice ? false : (faceEnrolled ?? this.faceEnrolled),
        referredById: referredById ?? this.referredById,
        workoutPlanId: clearWorkoutPlan ? null : (workoutPlanId ?? this.workoutPlanId),
        dietPlanId: clearDietPlan ? null : (dietPlanId ?? this.dietPlanId),
      );

  factory Member.fromJson(Map<String, dynamic> j) {
    final start = dateOr(j['startDate'], DateTime(2000));
    return Member(
      id: str(j['id']),
      number: intOr(j['number'], 0),
      name: str(j['name'], 'Member'),
      phone: str(j['phone']),
      gender: enumByName(Gender.values, j['gender'], Gender.male),
      dateOfBirth: dateOrNull(j['dateOfBirth']),
      email: str(j['email']),
      address: str(j['address']),
      branchId: str(j['branchId']),
      planId: str(j['planId']),
      trainerId: strOrNull(j['trainerId']),
      joinDate: dateOr(j['joinDate'], start),
      startDate: start,
      endDate: dateOr(j['endDate'], start),
      goal: str(j['goal']),
      heightCm: doubleOrNull(j['heightCm']),
      weightKg: doubleOrNull(j['weightKg']),
      medicalNotes: str(j['medicalNotes']),
      emergencyName: str(j['emergencyName']),
      emergencyPhone: str(j['emergencyPhone']),
      source: enumByName(LeadSource.values, j['source'], LeadSource.walkIn),
      notes: str(j['notes']),
      balanceDue: doubleOr(j['balanceDue']),
      hasPhoto: j['hasPhoto'] == true,
      freezes: [for (final f in mapList(j['freezes'])) Freeze.fromJson(f)],
      deviceUserId: strOrNull(j['deviceUserId']),
      faceEnrolled: j['faceEnrolled'] == true,
      referredById: strOrNull(j['referredById']),
      workoutPlanId: strOrNull(j['workoutPlanId']),
      dietPlanId: strOrNull(j['dietPlanId']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'name': name,
        'phone': phone,
        'gender': gender.name,
        'dateOfBirth': isoDate(dateOfBirth),
        'email': email,
        'address': address,
        'branchId': branchId,
        'planId': planId,
        'trainerId': trainerId,
        'joinDate': isoDate(joinDate),
        'startDate': isoDate(startDate),
        'endDate': isoDate(endDate),
        'goal': goal,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'medicalNotes': medicalNotes,
        'emergencyName': emergencyName,
        'emergencyPhone': emergencyPhone,
        'source': source.name,
        'notes': notes,
        'balanceDue': balanceDue,
        'hasPhoto': hasPhoto,
        'freezes': [for (final f in freezes) f.toJson()],
        'deviceUserId': deviceUserId,
        'faceEnrolled': faceEnrolled,
        'referredById': referredById,
        'workoutPlanId': workoutPlanId,
        'dietPlanId': dietPlanId,
      };
}

enum SubscriptionKind {
  admission('New admission'),
  renewal('Renewal');

  const SubscriptionKind(this.label);
  final String label;
}

/// One membership period that was sold: a new admission or a renewal. The member keeps only the
/// current period; this history drives the timeline on the profile and the renewal reports.
class Subscription {
  final String id;
  final String memberId;
  final String planId;
  final String planName; // kept so history still reads well if the plan is renamed or retired
  final SubscriptionKind kind;
  final DateTime start;
  final DateTime end;
  final double price;
  final double discount;
  final DateTime createdAt;

  const Subscription({
    required this.id,
    required this.memberId,
    required this.planId,
    required this.planName,
    required this.kind,
    required this.start,
    required this.end,
    required this.price,
    this.discount = 0,
    required this.createdAt,
  });

  double get amount => (price - discount).clamp(0, double.infinity).toDouble();

  factory Subscription.fromJson(Map<String, dynamic> j) {
    final start = dateOr(j['start'], DateTime(2000));
    return Subscription(
      id: str(j['id']),
      memberId: str(j['memberId']),
      planId: str(j['planId']),
      planName: str(j['planName'], 'Plan'),
      kind: enumByName(SubscriptionKind.values, j['kind'], SubscriptionKind.renewal),
      start: start,
      end: dateOr(j['end'], start),
      price: doubleOr(j['price']),
      discount: doubleOr(j['discount']),
      createdAt: dateOr(j['createdAt'], start),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'planId': planId,
        'planName': planName,
        'kind': kind.name,
        'start': isoDate(start),
        'end': isoDate(end),
        'price': price,
        'discount': discount,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// A body check: weight and optional measurements, for the progress chart on the profile.
class Measurement {
  final String id;
  final String memberId;
  final DateTime date;
  final double weightKg;
  final double? bodyFatPct;
  final double? waistCm;
  final double? chestCm;
  final double? armCm;

  const Measurement({
    required this.id,
    required this.memberId,
    required this.date,
    required this.weightKg,
    this.bodyFatPct,
    this.waistCm,
    this.chestCm,
    this.armCm,
  });

  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
        id: str(j['id']),
        memberId: str(j['memberId']),
        date: dateOr(j['date'], DateTime(2000)),
        weightKg: doubleOr(j['weightKg']),
        bodyFatPct: doubleOrNull(j['bodyFatPct']),
        waistCm: doubleOrNull(j['waistCm']),
        chestCm: doubleOrNull(j['chestCm']),
        armCm: doubleOrNull(j['armCm']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'date': isoDate(date),
        'weightKg': weightKg,
        'bodyFatPct': bodyFatPct,
        'waistCm': waistCm,
        'chestCm': chestCm,
        'armCm': armCm,
      };
}
