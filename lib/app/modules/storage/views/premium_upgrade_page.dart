// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../core/services/in_app_purchase_service.dart';
import '../../../core/services/subscription_manager.dart';

class PremiumUpgradePage extends StatefulWidget {
  const PremiumUpgradePage({super.key});

  @override
  State<PremiumUpgradePage> createState() => _PremiumUpgradePageState();
}

class _PremiumUpgradePageState extends State<PremiumUpgradePage> {
  final InAppPurchaseService _purchaseService = InAppPurchaseService();
  final SubscriptionManager _subscriptionManager = SubscriptionManager();
  bool _isLoading = true;
  String? _errorMessage;

  final List<PlanModel> plans = [
    PlanModel(
      name: 'Bronze Plan',
      storage: '5 GB',
      price: '\$5',
      period: 'USD',
      color: const Color(0xFFCD7F32), // Bronze color
      features: [
        'Basic file storage and sharing',
        'Ideal for casual users or light file backup',
      ],
      isPopular: false,
    ),
    PlanModel(
      name: 'Silver Plan',
      storage: '50 GB',
      price: '\$25',
      period: 'USD',
      color: const Color(0xFFC0C0C0), // Silver color
      features: [
        'Ample space for documents, media, and backups',
        'Priority upload/download speed',
      ],
      isPopular: true,
    ),
    PlanModel(
      name: 'Gold Plan',
      storage: '100 GB',
      price: '\$65',
      period: 'USD',
      color: const Color(0xFFE6B800), // Lighter, less vibrant gold color
      features: [
        'Maximum storage capacity',
        'Premium support',
        'File versioning and recovery options',
      ],
      isPopular: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _purchaseService.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      await _subscriptionManager.initialize();
      await _purchaseService.initialize();

      // Set up purchase callbacks
      _purchaseService.onPurchaseSuccess = _onPurchaseSuccess;
      _purchaseService.onPurchaseError = _onPurchaseError;
      _purchaseService.onPurchaseCanceled = _onPurchaseCanceled;
      _purchaseService.onPurchasePending = _onPurchasePending;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize purchase service: $e';
      });
    }
  }

  void _onPurchaseSuccess(PurchaseDetails purchaseDetails) {
    final plan = _subscriptionManager
        .getSubscriptionPlanFromProductId(purchaseDetails.productID);
    _subscriptionManager.activateSubscription(plan);

    _showSuccessDialog(plan);
  }

  void _onPurchaseError(PurchaseDetails purchaseDetails) {
    _showErrorDialog(
        'Purchase failed: ${purchaseDetails.error?.message ?? 'Unknown error'}');
  }

  void _onPurchaseCanceled(PurchaseDetails purchaseDetails) {
    _showInfoDialog('Purchase was canceled');
  }

  void _onPurchasePending(PurchaseDetails purchaseDetails) {
    _showInfoDialog('Purchase is pending...');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Upgrade Plan'),
          )
        ],
        body: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : _errorMessage != null
                  ? _buildErrorView()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          // Plans section
                          _buildPlansSection(),
                          const SizedBox(height: 16),
                          // Restore purchases button
                          _buildRestoreButton(),
                          const SizedBox(height: 16),
                          // Terms text
                          _buildTermsText(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildPlansSection() {
    return Column(
      children: plans.asMap().entries.map((entry) {
        final index = entry.key;
        final plan = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildPlanCard(plan, index),
        );
      }).toList(),
    );
  }

  Widget _buildPlanCard(PlanModel plan, int index) {
    // Get actual product details from the store
    String productId;
    switch (plan.name) {
      case 'Bronze Plan':
        productId = InAppPurchaseService.bronzePlanId;
        break;
      case 'Silver Plan':
        productId = InAppPurchaseService.silverPlanId;
        break;
      case 'Gold Plan':
        productId = InAppPurchaseService.goldPlanId;
        break;
      default:
        productId = '';
    }

    final productDetails = _purchaseService.getProductById(productId);
    final actualPrice = productDetails?.price ?? plan.price;
    final actualCurrency = productDetails?.currencyCode ?? 'USD';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: CupertinoColors.systemGrey4,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: plan.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getPlanIcon(index),
                  color: plan.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: plan.color,
                          ),
                        ),
                        if (plan.isPopular) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'POPULAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Storage: Up to ${plan.storage}',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    actualPrice,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: plan.color,
                    ),
                  ),
                  Text(
                    actualCurrency,
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...plan.features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: plan.color,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          // Subscribe button for this plan
          SizedBox(
            width: double.infinity,
            height: 48,
            child: CupertinoButton(
              color: plan.color,
              borderRadius: BorderRadius.circular(12),
              onPressed: () {
                _handleSubscription(plan);
              },
              child: Text(
                'Subscribe to ${plan.name} - $actualPrice',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPlanIcon(int index) {
    switch (index) {
      case 0:
        return CupertinoIcons.cube_box; // Bronze
      case 1:
        return CupertinoIcons.star_circle; // Silver
      case 2:
        return CupertinoIcons.star_fill; // Gold
      default:
        return CupertinoIcons.cube_box;
    }
  }

  Widget _buildTermsText() {
    return Text(
      'Payment integration coming soon!\nTerms and conditions apply.',
      style: TextStyle(
        fontSize: 12,
        color: CupertinoColors.systemGrey,
      ),
      textAlign: TextAlign.center,
    );
  }

  Future<void> _handleSubscription(PlanModel plan) async {
    if (!_purchaseService.isAvailable) {
      _showErrorDialog('In-app purchases are not available on this device');
      return;
    }

    // Get the product ID based on the plan
    String productId;
    switch (plan.name) {
      case 'Bronze Plan':
        productId = InAppPurchaseService.bronzePlanId;
        break;
      case 'Silver Plan':
        productId = InAppPurchaseService.silverPlanId;
        break;
      case 'Gold Plan':
        productId = InAppPurchaseService.goldPlanId;
        break;
      default:
        _showErrorDialog('Invalid plan selected');
        return;
    }

    // Find the product details
    final productDetails = _purchaseService.getProductById(productId);
    if (productDetails == null) {
      _showErrorDialog('Product not found. Please try again later.');
      return;
    }

    // Initiate purchase
    final success = await _purchaseService.buyProduct(productDetails);
    if (!success) {
      _showErrorDialog('Failed to initiate purchase');
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 64,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializeServices();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        color: CupertinoColors.systemGrey,
        onPressed: () async {
          await _purchaseService.restorePurchases();
        },
        child: const Text(
          'Restore Purchases',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _showSuccessDialog(SubscriptionPlan plan) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Purchase Successful!'),
        content: Text(
          'You have successfully subscribed to ${_subscriptionManager.planName}. Enjoy your premium features!',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Info'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class PlanModel {
  final String name;
  final String storage;
  final String price;
  final String period;
  final Color color;
  final List<String> features;
  final bool isPopular;

  PlanModel({
    required this.name,
    required this.storage,
    required this.price,
    required this.period,
    required this.color,
    required this.features,
    required this.isPopular,
  });
}
