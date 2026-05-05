// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import '../config/in_app_purchase_config.dart';

class InAppPurchaseService {
  static final InAppPurchaseService _instance =
      InAppPurchaseService._internal();
  factory InAppPurchaseService() => _instance;
  InAppPurchaseService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Product IDs for your subscription plans
  static String get bronzePlanId => InAppPurchaseConfig.bronzePlanMonthly;
  static String get silverPlanId => InAppPurchaseConfig.silverPlanMonthly;
  static String get goldPlanId => InAppPurchaseConfig.goldPlanMonthly;

  static List<String> get _productIds => InAppPurchaseConfig.allProductIds;

  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  String? _queryProductError;

  // Getters
  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  String? get queryProductError => _queryProductError;

  // Callbacks
  Function(PurchaseDetails)? onPurchaseSuccess;
  Function(PurchaseDetails)? onPurchaseError;
  Function(PurchaseDetails)? onPurchaseCanceled;
  Function(PurchaseDetails)? onPurchasePending;

  Future<void> initialize() async {
    if (kDebugMode) {
      print('Initializing In-App Purchase Service...');
    }

    // Check if in-app purchase is available
    _isAvailable = await _inAppPurchase.isAvailable();

    if (!_isAvailable) {
      if (kDebugMode) {
        print('In-app purchase not available');
      }
      return;
    }

    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase
              .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(ExamplePaymentQueueDelegate());
    }

    // Listen to purchase updates
    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        if (kDebugMode) {
          print('Purchase stream error: $error');
        }
      },
    );

    // Load products
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (kDebugMode) {
      print('Loading products...');
    }

    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(_productIds.toSet());

    if (response.notFoundIDs.isNotEmpty) {
      if (kDebugMode) {
        print('Products not found: ${response.notFoundIDs}');
      }
    }

    if (response.error != null) {
      _queryProductError = response.error!.message;
      if (kDebugMode) {
        print('Error loading products: ${response.error!.message}');
      }
      return;
    }

    _products = response.productDetails;
    if (kDebugMode) {
      print('Loaded ${_products.length} products');
      for (final product in _products) {
        print('Product: ${product.id} - ${product.title} - ${product.price}');
      }
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (kDebugMode) {
        print(
            'Purchase update: ${purchaseDetails.status} for ${purchaseDetails.productID}');
      }

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
          onPurchasePending?.call(purchaseDetails);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _purchasePending = false;
          _handleSuccessfulPurchase(purchaseDetails);
          break;
        case PurchaseStatus.error:
          _purchasePending = false;
          _handlePurchaseError(purchaseDetails);
          break;
        case PurchaseStatus.canceled:
          _purchasePending = false;
          onPurchaseCanceled?.call(purchaseDetails);
          break;
      }

      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    if (kDebugMode) {
      print('Purchase successful: ${purchaseDetails.productID}');
    }

    // Here you would typically verify the purchase with your backend
    // and update the user's subscription status
    onPurchaseSuccess?.call(purchaseDetails);
  }

  void _handlePurchaseError(PurchaseDetails purchaseDetails) {
    if (kDebugMode) {
      print('Purchase error: ${purchaseDetails.error?.message}');
    }
    onPurchaseError?.call(purchaseDetails);
  }

  Future<bool> buyProduct(ProductDetails productDetails) async {
    if (!_isAvailable) {
      if (kDebugMode) {
        print('In-app purchase not available');
      }
      return false;
    }

    if (_purchasePending) {
      if (kDebugMode) {
        print('Purchase already pending');
      }
      return false;
    }

    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);

    try {
      final bool success =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      if (kDebugMode) {
        print('Purchase initiated: $success');
      }
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('Error initiating purchase: $e');
      }
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      if (kDebugMode) {
        print('In-app purchase not available');
      }
      return;
    }

    try {
      await _inAppPurchase.restorePurchases();
      if (kDebugMode) {
        print('Restore purchases initiated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error restoring purchases: $e');
      }
    }
  }

  ProductDetails? getProductById(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}

// iOS Payment Queue Delegate
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
