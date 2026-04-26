import 'package:flutter_test/flutter_test.dart';
import 'package:onyu/domain/saju_profile.dart';

void main() {
  group('SajuProfile.fromJson', () {
    test('parses Edge Function response shape', () {
      final json = {
        'id': '2965f9c8-2908-42da-9ba2-6b9901d7e5ac',
        'user_id': '37a3e8c0-0a41-42d7-917b-bb089b56b872',
        'birth_date': '1990-05-15',
        'birth_time': '14:30:00',
        'birth_calendar': 'solar',
        'birth_is_leap_month': false,
        'birth_location': '서울',
        'pillars': {
          'year': '庚午',
          'month': '辛巳',
          'day': '庚辰',
          'hour': '癸未',
          'lunar': {'lunarYear': 1990, 'lunarMonth': 4, 'lunarDay': 21},
        },
        'created_at': '2026-04-26T11:47:12.211673+00:00',
      };

      final profile = SajuProfile.fromJson(json);

      expect(profile.id, '2965f9c8-2908-42da-9ba2-6b9901d7e5ac');
      expect(profile.birthDate, DateTime(1990, 5, 15));
      expect(profile.birthTime, '14:30:00');
      expect(profile.birthCalendar, SajuCalendar.solar);
      expect(profile.birthIsLeapMonth, false);
      expect(profile.yearPillar, '庚午');
      expect(profile.monthPillar, '辛巳');
      expect(profile.dayPillar, '庚辰');
      expect(profile.hourPillar, '癸未');
    });

    test('handles unknown birth_time (null)', () {
      final json = {
        'id': 'x',
        'user_id': 'y',
        'birth_date': '1990-01-01',
        'birth_time': null,
        'birth_calendar': 'lunar',
        'birth_is_leap_month': true,
        'birth_location': null,
        'pillars': {'year': '庚午'},
        'created_at': '2026-04-26T00:00:00Z',
      };
      final profile = SajuProfile.fromJson(json);
      expect(profile.birthTime, isNull);
      expect(profile.birthCalendar, SajuCalendar.lunar);
      expect(profile.birthIsLeapMonth, true);
      expect(profile.hourPillar, isNull);
    });
  });
}
