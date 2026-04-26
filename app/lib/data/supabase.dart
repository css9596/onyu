import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';

Future<void> initSupabase() async {
  if (!Env.isConfigured) {
    throw StateError(
      'SUPABASE_ANON_KEY is empty. Pass --dart-define=SUPABASE_ANON_KEY=<key>',
    );
  }
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  debugPrint('[supabase] connected to ${Env.supabaseUrl}');
}

SupabaseClient get supabase => Supabase.instance.client;
