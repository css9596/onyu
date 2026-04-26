import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/account_repository.dart';
import '../data/auth_repository.dart';
import '../data/chat_repository.dart';
import '../data/saju_repository.dart';
import '../data/subscriptions_repository.dart';
import '../data/supabase.dart';
import '../data/usage_repository.dart';
import '../domain/saju_profile.dart';
import '../domain/usage_info.dart';

final supabaseClientProvider = Provider<SupabaseClient>((_) => supabase);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final sajuRepositoryProvider = Provider<SajuRepository>((ref) {
  return SajuRepository(ref.watch(supabaseClientProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  return UsageRepository(ref.watch(supabaseClientProvider));
});

final subscriptionsRepositoryProvider = Provider<SubscriptionsRepository>((ref) {
  return SubscriptionsRepository(ref.watch(supabaseClientProvider));
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(supabaseClientProvider));
});

/// Today's usage + tier for the signed-in user. Re-fetched on auth changes
/// or when callers `ref.invalidate(usageInfoProvider)` (e.g. after send).
final usageInfoProvider = FutureProvider<UsageInfo?>((ref) async {
  final session = ref.watch(authStateProvider).whenOrNull(data: (s) => s);
  if (session == null) return null;
  return ref.watch(usageRepositoryProvider).fetchToday();
});

/// Emits the current Session whenever auth state changes (sign in/out, refresh).
final authStateProvider = StreamProvider<Session?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges().map((event) => event.session);
});

/// Loads the user's saju_profile, or null if not yet onboarded. Recomputes
/// whenever auth state changes.
final sajuProfileProvider = FutureProvider<SajuProfile?>((ref) async {
  final session = ref.watch(authStateProvider).value;
  if (session == null) return null;
  final repo = ref.watch(sajuRepositoryProvider);
  return repo.fetchOwn();
});
