import 'package:flutter/material.dart';

import 'json.dart';
import 'member.dart';

/// How a person heard about the gym. Kept on enquiries and members for the "where do members come
/// from" report.
enum LeadSource {
  walkIn('Walk-in', Icons.directions_walk),
  phone('Phone call', Icons.call),
  whatsapp('WhatsApp', Icons.chat),
  instagram('Instagram', Icons.camera_alt),
  referral('Friend referral', Icons.people),
  google('Google', Icons.search),
  other('Other', Icons.more_horiz);

  const LeadSource(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum EnquiryStatus {
  open('New', Color(0xFF3B82F6)),
  followUp('Follow-up', Color(0xFFFFB020)),
  trial('On trial', Color(0xFFB57BFF)),
  converted('Joined', Color(0xFF2FD07F)),
  lost('Not interested', Color(0xFF6B6B73));

  const EnquiryStatus(this.label, this.color);
  final String label;
  final Color color;

  bool get isOpen => this == open || this == followUp || this == trial;
}

/// A walk-in or phone enquiry from someone who has not joined yet.
class Enquiry {
  final String id;
  final String name;
  final String phone;
  final Gender gender;
  final String? planId; // the plan they asked about
  final LeadSource source;
  final EnquiryStatus status;
  final DateTime createdAt;
  final DateTime? nextFollowUp;
  final DateTime? lastContacted;
  final String notes;
  final String? memberId; // set when they join

  const Enquiry({
    required this.id,
    required this.name,
    required this.phone,
    this.gender = Gender.male,
    this.planId,
    this.source = LeadSource.walkIn,
    this.status = EnquiryStatus.open,
    required this.createdAt,
    this.nextFollowUp,
    this.lastContacted,
    this.notes = '',
    this.memberId,
  });

  Enquiry copyWith({
    String? name,
    String? phone,
    Gender? gender,
    String? planId,
    bool clearPlan = false,
    LeadSource? source,
    EnquiryStatus? status,
    DateTime? nextFollowUp,
    bool clearFollowUp = false,
    DateTime? lastContacted,
    String? notes,
    String? memberId,
  }) =>
      Enquiry(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        gender: gender ?? this.gender,
        planId: clearPlan ? null : (planId ?? this.planId),
        source: source ?? this.source,
        status: status ?? this.status,
        createdAt: createdAt,
        nextFollowUp: clearFollowUp ? null : (nextFollowUp ?? this.nextFollowUp),
        lastContacted: lastContacted ?? this.lastContacted,
        notes: notes ?? this.notes,
        memberId: memberId ?? this.memberId,
      );

  factory Enquiry.fromJson(Map<String, dynamic> j) => Enquiry(
        id: str(j['id']),
        name: str(j['name'], 'Enquiry'),
        phone: str(j['phone']),
        gender: enumByName(Gender.values, j['gender'], Gender.male),
        planId: strOrNull(j['planId']),
        source: enumByName(LeadSource.values, j['source'], LeadSource.walkIn),
        status: enumByName(EnquiryStatus.values, j['status'], EnquiryStatus.open),
        createdAt: dateOr(j['createdAt'], DateTime(2000)),
        nextFollowUp: dateOrNull(j['nextFollowUp']),
        lastContacted: dateOrNull(j['lastContacted']),
        notes: str(j['notes']),
        memberId: strOrNull(j['memberId']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'gender': gender.name,
        'planId': planId,
        'source': source.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'nextFollowUp': isoDate(nextFollowUp),
        'lastContacted': lastContacted?.toIso8601String(),
        'notes': notes,
        'memberId': memberId,
      };
}
