import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/sign_in_screen.dart';
import '../features/auth/sign_up_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/chat/conversations_list_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/subscription/premium_screen.dart';
import 'providers.dart';

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(SupabaseClient client) {
    _sub = client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final notifier = _AuthRefreshNotifier(client);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = client.auth.currentSession;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/sign-in' || loc == '/sign-up';
      final isOnboarding = loc == '/onboarding';

      if (session == null) {
        return isAuthRoute ? null : '/sign-in';
      }

      // Signed in. Check onboarding completion (cached AsyncValue).
      // While loading we leave them where they are to avoid flicker;
      // once resolved, the listener-driven refresh will redirect.
      final sajuAsync = ref.read(sajuProfileProvider);
      if (sajuAsync.isLoading) return null;
      final hasProfile = sajuAsync.whenOrNull(data: (p) => p) != null;

      if (!hasProfile) {
        return isOnboarding ? null : '/onboarding';
      }
      if (isAuthRoute || isOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/chat',
        builder: (_, state) =>
            ChatScreen(conversationId: state.uri.queryParameters['id']),
      ),
      GoRoute(path: '/conversations', builder: (_, _) => const ConversationsListScreen()),
      GoRoute(path: '/premium', builder: (_, _) => const PremiumScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
});
