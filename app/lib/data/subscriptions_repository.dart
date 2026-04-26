import 'package:supabase_flutter/supabase_flutter.dart';

class PurchaseException implements Exception {
  PurchaseException(this.code);
  final String code;
  @override
  String toString() => 'PurchaseException($code)';
}

class SubscriptionsRepository {
  SubscriptionsRepository(this._client);
  final SupabaseClient _client;

  /// Submit a receipt to the verify-purchase Edge Function.
  /// On success the server marks the user as premium.
  ///
  /// `store`: 'appstore' | 'playstore' | 'mock' (only mock works locally
  ///   without external store credentials).
  Future<void> verifyReceipt({
    required String store,
    required String productId,
    required String receipt,
  }) async {
    final response = await _client.functions.invoke('verify-purchase', body: {
      'store': store,
      'product_id': productId,
      'receipt': receipt,
    });
    final body = response.data;
    if (body is! Map) throw PurchaseException('invalid_response_shape');
    if (body['error'] != null) {
      throw PurchaseException(body['error'].toString());
    }
  }

  /// Convenience for the dev-only mock upgrade button (real IAP plugin
  /// integration is wired in a separate step once store IDs are configured).
  Future<void> purchaseMock() {
    return verifyReceipt(
      store: 'mock',
      productId: 'onyu_premium_monthly',
      receipt: 'mock-receipt-${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
