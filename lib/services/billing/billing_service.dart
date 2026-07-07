import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BillingService {
  BillingService._();

  static final BillingService instance = BillingService._();

  static const String proProductId = 'pro_unlock';
  static const String _proUnlockedKey = 'pro_unlocked';

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  ProductDetails? proProduct;
  bool isAvailable = false;
  bool isPro = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    isPro = prefs.getBool(_proUnlockedKey) ?? false;

    isAvailable = await _iap.isAvailable();

    if (!isAvailable) return;

    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchases,
      onDone: () {
        _purchaseSubscription?.cancel();
      },
      onError: (error) {
        // We will improve this later.
      },
    );

    await loadProducts();
  }

  Future<void> loadProducts() async {
    final response = await _iap.queryProductDetails({proProductId});

    if (response.productDetails.isNotEmpty) {
      proProduct = response.productDetails.first;
    }
  }

  Future<void> buyPro() async {
    final product = proProduct;
    if (product == null) return;

    final purchaseParam = PurchaseParam(productDetails: product);

    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    if (!Platform.isAndroid) return;
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchases(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.productID != proProductId) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _unlockPro();
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _unlockPro() async {
    isPro = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proUnlockedKey, true);
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
  }
}