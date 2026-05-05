// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

/// Configuration for in-app purchase product IDs
/// 
/// IMPORTANT: Before publishing to production, you need to:
/// 1. Create products in Google Play Console (Android)
/// 2. Create products in App Store Connect (iOS)
/// 3. Update these product IDs to match your actual product IDs
/// 4. Test purchases in sandbox/test environments
class InAppPurchaseConfig {
  // Product IDs for subscription plans
  // These should match the product IDs created in your app store accounts
  
  /// Bronze plan monthly subscription
  /// Default: 1-month subscription for Bronze plan (5GB storage)
  static const String bronzePlanMonthly = 'bronze_plan_monthly';
  
  /// Silver plan monthly subscription  
  /// Default: 1-month subscription for Silver plan (50GB storage)
  static const String silverPlanMonthly = 'silver_plan_monthly';
  
  /// Gold plan monthly subscription
  /// Default: 1-month subscription for Gold plan (100GB storage)
  static const String goldPlanMonthly = 'gold_plan_monthly';
  
  /// All available product IDs
  static const List<String> allProductIds = [
    bronzePlanMonthly,
    silverPlanMonthly,
    goldPlanMonthly,
  ];
  
  /// Get product ID for a specific plan name
  static String? getProductIdForPlan(String planName) {
    switch (planName.toLowerCase()) {
      case 'bronze plan':
      case 'bronze':
        return bronzePlanMonthly;
      case 'silver plan':
      case 'silver':
        return silverPlanMonthly;
      case 'gold plan':
      case 'gold':
        return goldPlanMonthly;
      default:
        return null;
    }
  }
  
  /// Get plan name from product ID
  static String? getPlanNameFromProductId(String productId) {
    switch (productId) {
      case bronzePlanMonthly:
        return 'Bronze Plan';
      case silverPlanMonthly:
        return 'Silver Plan';
      case goldPlanMonthly:
        return 'Gold Plan';
      default:
        return null;
    }
  }
}

/// Instructions for setting up in-app purchases:
/// 
/// ANDROID (Google Play Console):
/// 1. Go to Google Play Console > Your App > Monetize > Products > Subscriptions
/// 2. Create new subscription products with these IDs:
///    - bronze_plan_monthly
///    - silver_plan_monthly  
///    - gold_plan_monthly
/// 3. Set appropriate prices and billing periods
/// 4. Activate the products
/// 
/// iOS (App Store Connect):
/// 1. Go to App Store Connect > Your App > Features > In-App Purchases
/// 2. Create new Auto-Renewable Subscriptions with these IDs:
///    - bronze_plan_monthly
///    - silver_plan_monthly
///    - gold_plan_monthly
/// 3. Set appropriate prices and subscription duration
/// 4. Submit for review and get approved
/// 
/// TESTING:
/// - Use test accounts for both platforms
/// - Test in sandbox environments before production
/// - Verify purchase flows work correctly
/// - Test subscription renewals and cancellations
