class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => supabaseAnonKey.isNotEmpty;

  /// Sentry DSN — when empty, crash reporting is skipped. Set via
  /// --dart-define=SENTRY_DSN=... to enable.
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static bool get isSentryEnabled => sentryDsn.isNotEmpty;
}
