// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubscriptionPlan {
  free,
  bronze,
  silver,
  gold,
}

class SubscriptionManager {
  static final SubscriptionManager _instance = SubscriptionManager._internal();
  factory SubscriptionManager() => _instance;
  SubscriptionManager._internal();

  static const String _subscriptionPlanKey = 'subscription_plan';
  static const String _subscriptionExpiryKey = 'subscription_expiry';
  static const String _subscriptionActiveKey = 'subscription_active';

  SubscriptionPlan _currentPlan = SubscriptionPlan.free;
  DateTime? _expiryDate;
  bool _isActive = false;

  // Getters
  SubscriptionPlan get currentPlan => _currentPlan;
  DateTime? get expiryDate => _expiryDate;
  bool get isActive => _isActive;
  bool get isPremium => _currentPlan != SubscriptionPlan.free && _isActive;

  // Storage limits based on plan
  int get storageLimit {
    switch (_currentPlan) {
      case SubscriptionPlan.free:
        return 1; // 1 GB
      case SubscriptionPlan.bronze:
        return 5; // 5 GB
      case SubscriptionPlan.silver:
        return 50; // 50 GB
      case SubscriptionPlan.gold:
        return 100; // 100 GB
    }
  }

  String get planName {
    switch (_currentPlan) {
      case SubscriptionPlan.free:
        return 'Free Plan';
      case SubscriptionPlan.bronze:
        return 'Bronze Plan';
      case SubscriptionPlan.silver:
        return 'Silver Plan';
      case SubscriptionPlan.gold:
        return 'Gold Plan';
    }
  }

  List<String> get planFeatures {
    switch (_currentPlan) {
      case SubscriptionPlan.free:
        return [
          'Basic file storage and sharing',
          'Limited to ${storageLimit}GB storage',
        ];
      case SubscriptionPlan.bronze:
        return [
          'Basic file storage and sharing',
          'Up to ${storageLimit}GB storage',
          'Ideal for casual users or light file backup',
        ];
      case SubscriptionPlan.silver:
        return [
          'Ample space for documents, media, and backups',
          'Up to ${storageLimit}GB storage',
          'Priority upload/download speed',
        ];
      case SubscriptionPlan.gold:
        return [
          'Maximum storage capacity',
          'Up to ${storageLimit}GB storage',
          'Premium support',
          'File versioning and recovery options',
        ];
    }
  }

  Future<void> initialize() async {
    await _loadSubscriptionData();
    _checkSubscriptionExpiry();
  }

  Future<void> _loadSubscriptionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final planIndex = prefs.getInt(_subscriptionPlanKey) ?? 0;
      _currentPlan = SubscriptionPlan.values[planIndex];
      
      final expiryTimestamp = prefs.getInt(_subscriptionExpiryKey);
      if (expiryTimestamp != null) {
        _expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
      }
      
      _isActive = prefs.getBool(_subscriptionActiveKey) ?? false;
      
      if (kDebugMode) {
        print('Loaded subscription: $_currentPlan, Active: $_isActive, Expiry: $_expiryDate');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading subscription data: $e');
      }
    }
  }

  Future<void> _saveSubscriptionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setInt(_subscriptionPlanKey, _currentPlan.index);
      await prefs.setBool(_subscriptionActiveKey, _isActive);
      
      if (_expiryDate != null) {
        await prefs.setInt(_subscriptionExpiryKey, _expiryDate!.millisecondsSinceEpoch);
      } else {
        await prefs.remove(_subscriptionExpiryKey);
      }
      
      if (kDebugMode) {
        print('Saved subscription: $_currentPlan, Active: $_isActive, Expiry: $_expiryDate');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving subscription data: $e');
      }
    }
  }

  void _checkSubscriptionExpiry() {
    if (_expiryDate != null && DateTime.now().isAfter(_expiryDate!)) {
      if (kDebugMode) {
        print('Subscription expired, reverting to free plan');
      }
      _currentPlan = SubscriptionPlan.free;
      _isActive = false;
      _expiryDate = null;
      _saveSubscriptionData();
    }
  }

  Future<void> activateSubscription(SubscriptionPlan plan, {Duration? duration}) async {
    _currentPlan = plan;
    _isActive = true;
    
    // Set expiry date (default to 30 days for monthly subscription)
    final subscriptionDuration = duration ?? const Duration(days: 30);
    _expiryDate = DateTime.now().add(subscriptionDuration);
    
    await _saveSubscriptionData();
    
    if (kDebugMode) {
      print('Activated subscription: $plan until $_expiryDate');
    }
  }

  Future<void> deactivateSubscription() async {
    _currentPlan = SubscriptionPlan.free;
    _isActive = false;
    _expiryDate = null;
    
    await _saveSubscriptionData();
    
    if (kDebugMode) {
      print('Deactivated subscription');
    }
  }

  SubscriptionPlan getSubscriptionPlanFromProductId(String productId) {
    switch (productId) {
      case 'bronze_plan_monthly':
        return SubscriptionPlan.bronze;
      case 'silver_plan_monthly':
        return SubscriptionPlan.silver;
      case 'gold_plan_monthly':
        return SubscriptionPlan.gold;
      default:
        return SubscriptionPlan.free;
    }
  }

  String getProductIdFromPlan(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.bronze:
        return 'bronze_plan_monthly';
      case SubscriptionPlan.silver:
        return 'silver_plan_monthly';
      case SubscriptionPlan.gold:
        return 'gold_plan_monthly';
      case SubscriptionPlan.free:
        return '';
    }
  }

  bool hasFeature(String feature) {
    // Define premium features
    const premiumFeatures = [
      'priority_support',
      'file_versioning',
      'advanced_sharing',
      'unlimited_downloads',
    ];
    
    if (premiumFeatures.contains(feature)) {
      return isPremium;
    }
    
    return true; // Basic features are available to all users
  }

  int getDaysUntilExpiry() {
    if (_expiryDate == null) return 0;
    final difference = _expiryDate!.difference(DateTime.now());
    return difference.inDays;
  }

  bool isExpiringSoon({int days = 7}) {
    if (!_isActive || _expiryDate == null) return false;
    return getDaysUntilExpiry() <= days;
  }
}
