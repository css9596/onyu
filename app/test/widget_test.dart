import 'package:flutter_test/flutter_test.dart';
import 'package:onyu/core/env.dart';

void main() {
  test('Env exposes Supabase URL with local default', () {
    expect(Env.supabaseUrl, isNotEmpty);
  });

  test('Env.isConfigured tracks whether anon key was provided', () {
    expect(Env.isConfigured, Env.supabaseAnonKey.isNotEmpty);
  });
}
