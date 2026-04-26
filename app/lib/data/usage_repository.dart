import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/usage_info.dart';

class UsageRepository {
  UsageRepository(this._client);
  final SupabaseClient _client;

  Future<UsageInfo> fetchToday() async {
    final profile = await _client
        .from('profiles')
        .select('subscription_tier, daily_message_limit')
        .single();

    final usage = await _client
        .from('daily_usage_view')
        .select('user_message_count')
        .eq('usage_date', _seoulToday())
        .maybeSingle();

    final tierStr = profile['subscription_tier'] as String;
    final tier = SubscriptionTier.values.byName(tierStr);

    DateTime? expiresAt;
    if (tier == SubscriptionTier.premium) {
      final sub = await _client
          .from('subscriptions')
          .select('expires_at')
          .eq('status', 'active')
          .order('expires_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (sub != null) {
        expiresAt = DateTime.parse(sub['expires_at'] as String);
      }
    }

    return UsageInfo(
      tier: tier,
      dailyLimit: profile['daily_message_limit'] as int,
      usedToday: (usage?['user_message_count'] as int?) ?? 0,
      premiumExpiresAt: expiresAt,
    );
  }

  /// Asia/Seoul (UTC+9, no DST) date in YYYY-MM-DD.
  String _seoulToday() {
    final seoul = DateTime.now().toUtc().add(const Duration(hours: 9));
    final m = seoul.month.toString().padLeft(2, '0');
    final d = seoul.day.toString().padLeft(2, '0');
    return '${seoul.year}-$m-$d';
  }
}
