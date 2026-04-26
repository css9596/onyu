enum SajuCalendar { solar, lunar }

class SajuProfile {
  SajuProfile({
    required this.id,
    required this.userId,
    required this.birthDate,
    required this.birthTime,
    required this.birthCalendar,
    required this.birthIsLeapMonth,
    required this.birthLocation,
    required this.pillars,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final DateTime birthDate;
  final String? birthTime;
  final SajuCalendar birthCalendar;
  final bool birthIsLeapMonth;
  final String? birthLocation;
  final Map<String, dynamic> pillars;
  final DateTime createdAt;

  String? get yearPillar => pillars['year'] as String?;
  String? get monthPillar => pillars['month'] as String?;
  String? get dayPillar => pillars['day'] as String?;
  String? get hourPillar => pillars['hour'] as String?;

  factory SajuProfile.fromJson(Map<String, dynamic> json) {
    return SajuProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      birthDate: DateTime.parse(json['birth_date'] as String),
      birthTime: json['birth_time'] as String?,
      birthCalendar: SajuCalendar.values.byName(json['birth_calendar'] as String),
      birthIsLeapMonth: (json['birth_is_leap_month'] as bool?) ?? false,
      birthLocation: json['birth_location'] as String?,
      pillars: Map<String, dynamic>.from(json['pillars'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
