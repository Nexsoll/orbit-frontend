# In-App Purchase Implementation Guide

## Overview
This document outlines the in-app purchase implementation for the Super Up app, enabling users to upgrade their storage plans through subscription purchases.

## Features Implemented

### 1. Subscription Plans
- **Free Plan**: 1GB storage (default)
- **Bronze Plan**: 5GB storage - Monthly subscription
- **Silver Plan**: 50GB storage - Monthly subscription  
- **Gold Plan**: 100GB storage - Monthly subscription

### 2. Core Services

#### InAppPurchaseService (`lib/app/core/services/in_app_purchase_service.dart`)
- Handles all in-app purchase operations
- Manages purchase flow and callbacks
- Supports both Android (Google Play) and iOS (App Store)
- Automatic purchase verification and completion

#### SubscriptionManager (`lib/app/core/services/subscription_manager.dart`)
- Manages user subscription state
- Handles plan activation/deactivation
- Persists subscription data locally
- Provides subscription status and features

#### StorageWarningService (Updated)
- Now uses dynamic storage limits based on subscription
- Shows warnings at 70% capacity
- Integrates with subscription manager for plan-specific limits

### 3. User Interface

#### PremiumUpgradePage (`lib/app/modules/storage/views/premium_upgrade_page.dart`)
- Displays available subscription plans
- Shows real-time pricing from app stores
- Handles purchase initiation
- Includes restore purchases functionality
- Loading states and error handling

#### Storage Management Integration
- Updated storage warnings to show current plan limits
- Direct navigation to upgrade page when storage is full
- Plan-specific storage capacity display

## Setup Instructions

### Prerequisites
1. Flutter app with `in_app_purchase` plugin added
2. Google Play Console account (Android)
3. Apple Developer account (iOS)

### Android Setup (Google Play Console)

1. **Create Subscription Products**:
   - Go to Play Console > Your App > Monetize > Products > Subscriptions
   - Create products with these exact IDs:
     - `bronze_plan_monthly`
     - `silver_plan_monthly`
     - `gold_plan_monthly`

2. **Configure Products**:
   - Set appropriate prices (e.g., $4.99, $24.99, $64.99)
   - Set billing period to 1 month
   - Add product descriptions
   - Activate products

3. **Testing**:
   - Add test accounts in Play Console
   - Test purchases in internal testing track

### iOS Setup (App Store Connect)

1. **Create Subscription Products**:
   - Go to App Store Connect > Your App > Features > In-App Purchases
   - Create Auto-Renewable Subscriptions with these IDs:
     - `bronze_plan_monthly`
     - `silver_plan_monthly`
     - `gold_plan_monthly`

2. **Configure Products**:
   - Set prices in all required territories
   - Set subscription duration to 1 month
   - Add localized descriptions
   - Submit for review

3. **Testing**:
   - Create sandbox test accounts
   - Test in iOS Simulator or device with test account

### Configuration

#### Product IDs
Update product IDs in `lib/app/core/config/in_app_purchase_config.dart` if needed:

```dart
class InAppPurchaseConfig {
  static const String bronzePlanMonthly = 'your_bronze_plan_id';
  static const String silverPlanMonthly = 'your_silver_plan_id';
  static const String goldPlanMonthly = 'your_gold_plan_id';
}
```

## Usage Flow

1. **User sees storage warning** → Clicks "Upgrade Plan"
2. **Premium upgrade page loads** → Shows available plans with real pricing
3. **User selects plan** → Initiates purchase through app store
4. **Purchase completes** → Subscription activated automatically
5. **Storage limits updated** → User can now use increased storage

## Key Files Modified/Created

### New Files
- `lib/app/core/services/in_app_purchase_service.dart`
- `lib/app/core/services/subscription_manager.dart`
- `lib/app/core/config/in_app_purchase_config.dart`
- `lib/app/modules/storage/views/premium_upgrade_page.dart`

### Modified Files
- `lib/main.dart` - Added service initialization
- `lib/app/core/services/storage_warning_service.dart` - Dynamic storage limits
- `lib/app/core/widgets/storage_warning_banner.dart` - Navigation to upgrade page
- `lib/app/modules/storage/views/manage_storage_page.dart` - Upgrade integration
- `pubspec.yaml` - Added in_app_purchase dependency

## Testing Checklist

### Before Production
- [ ] Test purchases in sandbox/test environments
- [ ] Verify subscription activation works
- [ ] Test storage limit increases after purchase
- [ ] Test restore purchases functionality
- [ ] Verify error handling for failed purchases
- [ ] Test subscription expiry handling
- [ ] Verify pricing displays correctly from stores

### Production Deployment
- [ ] Products created and approved in both stores
- [ ] Test accounts removed from production builds
- [ ] Purchase verification implemented (if using backend)
- [ ] Analytics tracking for purchase events
- [ ] Customer support process for purchase issues

## Security Considerations

1. **Purchase Verification**: Consider implementing server-side purchase verification for additional security
2. **Subscription Status**: Regularly verify subscription status with app stores
3. **Local Storage**: Subscription data is stored locally - consider syncing with backend
4. **Error Handling**: Comprehensive error handling for network issues and store problems

## Support and Troubleshooting

### Common Issues
1. **Products not loading**: Check product IDs match store configuration
2. **Purchases failing**: Verify test accounts and sandbox setup
3. **Subscription not activating**: Check purchase callback implementation
4. **Restore not working**: Ensure restore purchases is properly implemented

### Debug Information
- Enable debug logging in `InAppPurchaseService`
- Check device logs for purchase-related errors
- Verify network connectivity for store communication

## Next Steps

1. **Backend Integration**: Implement server-side purchase verification
2. **Analytics**: Add purchase tracking and conversion metrics
3. **A/B Testing**: Test different pricing strategies
4. **Additional Plans**: Consider yearly subscriptions or family plans
5. **Promotional Offers**: Implement introductory pricing or free trials
