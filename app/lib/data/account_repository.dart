import 'package:supabase_flutter/supabase_flutter.dart';

class AccountException implements Exception {
  AccountException(this.code);
  final String code;
  @override
  String toString() => 'AccountException($code)';
}

class AccountRepository {
  AccountRepository(this._client);
  final SupabaseClient _client;

  /// Calls the delete-account Edge Function. On success the auth.users row
  /// is removed and CASCADEs through profiles and all dependent rows.
  /// The local session is signed out by the caller after this returns.
  Future<void> deleteAccount() async {
    final response = await _client.functions.invoke('delete-account');
    final body = response.data;
    if (body is! Map) throw AccountException('invalid_response_shape');
    if (body['error'] != null) throw AccountException(body['error'].toString());
  }
}
