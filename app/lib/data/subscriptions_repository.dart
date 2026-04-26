import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kPremiumProductId = 'onyu_premium_monthly';

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
  /// `store`: 'appstore' | 'playstore' | 'mock' (mock is for local testing).
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

  /// Returns true when the platform store advertises the premium product
  /// (i.e. it's been registered + activated in the developer console). When
  /// false, callers should fall back to [purchaseMock] for dev / staging.
  Future<bool> isRealIapAvailable() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final iap = InAppPurchase.instance;
    if (!await iap.isAvailable()) return false;
    final response = await iap.queryProductDetails({kPremiumProductId});
    return response.productDetails.isNotEmpty;
  }

  /// Run the real IAP flow: query product, launch the platform purchase UI,
  /// wait for completion, then submit the receipt to verify-purchase.
  ///
  /// Throws [PurchaseException] with codes 'product_not_found',
  /// 'cancelled', 'iap_error', or whatever the server returned.
  Future<void> purchaseReal() async {
    final iap = InAppPurchase.instance;
    final response = await iap.queryProductDetails({kPremiumProductId});
    if (response.productDetails.isEmpty) {
      throw PurchaseException('product_not_found');
    }
    final product = response.productDetails.first;

    final completer = Completer<PurchaseDetails>();
    late final StreamSubscription<List<PurchaseDetails>> sub;
    sub = iap.purchaseStream.listen((purchases) {
      for (final p in purchases) {
        if (p.productID != kPremiumProductId) continue;
        switch (p.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            if (!completer.isCompleted) completer.complete(p);
            break;
          case PurchaseStatus.canceled:
            if (!completer.isCompleted) {
              completer.completeError(PurchaseException('cancelled'));
            }
            break;
          case PurchaseStatus.error:
            if (!completer.isCompleted) {
              completer.completeError(
                PurchaseException('iap_error: ${p.error?.message ?? 'unknown'}'),
              );
            }
            break;
          case PurchaseStatus.pending:
            break;
        }
      }
    });

    try {
      await iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      final purchase = await completer.future;
      await verifyReceipt(
        store: Platform.isIOS ? 'appstore' : 'playstore',
        productId: purchase.productID,
        receipt: purchase.verificationData.serverVerificationData,
      );
      if (purchase.pendingCompletePurchase) {
        await iap.completePurchase(purchase);
      }
    } finally {
      await sub.cancel();
    }
  }

  /// Dev-only path used when the real product is not yet registered or
  /// when running on a non-mobile platform.
  Future<void> purchaseMock() {
    return verifyReceipt(
      store: 'mock',
      productId: kPremiumProductId,
      receipt: 'mock-receipt-${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
