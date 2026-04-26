import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/saju_profile.dart';

class SajuComputationException implements Exception {
  SajuComputationException(this.code);
  final String code;
  @override
  String toString() => 'SajuComputationException($code)';
}

class SajuRepository {
  SajuRepository(this._client);
  final SupabaseClient _client;

  Future<SajuProfile> compute({
    required DateTime birthDate,
    String? birthTime,
    SajuCalendar calendar = SajuCalendar.solar,
    bool isLeapMonth = false,
    String? location,
    double? longitudeDeg,
  }) async {
    final body = <String, dynamic>{
      'birth_date': _formatDate(birthDate),
      'birth_calendar': calendar.name,
      'birth_is_leap_month': isLeapMonth,
      'birth_time': ?birthTime,
      'birth_location': ?location,
      'longitude_deg': ?longitudeDeg,
    };

    final response = await _client.functions.invoke('compute-saju', body: body);
    final payload = response.data;
    if (payload is! Map) {
      throw SajuComputationException('invalid_response_shape');
    }
    if (payload['error'] != null) {
      throw SajuComputationException(payload['error'].toString());
    }
    final data = payload['data'];
    if (data is! Map) {
      throw SajuComputationException('missing_data');
    }
    return SajuProfile.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SajuProfile?> fetchOwn() async {
    final row = await _client.from('saju_profiles').select().maybeSingle();
    if (row == null) return null;
    return SajuProfile.fromJson(Map<String, dynamic>.from(row));
  }

  String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
