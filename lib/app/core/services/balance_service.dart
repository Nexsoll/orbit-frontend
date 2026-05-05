// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:super_up_core/super_up_core.dart';
import '../api_service/profile/profile_api_service.dart';

class BalanceService extends ChangeNotifier {
  static final BalanceService _instance = BalanceService._internal();
  factory BalanceService() => _instance;
  BalanceService._internal();

  static BalanceService get instance => _instance;

  double _balance = 0.0;
  late ProfileApiService _profileApiService;

  double get balance => _balance;

  /// Initialize balance from backend
  Future<void> init() async {
    try {
      print('BalanceService: Initializing...');
      _profileApiService = ProfileApiService.init();
      print('BalanceService: ProfileApiService initialized');
      await _fetchBalanceFromBackend();
    } catch (e) {
      // If initialization fails, start with 0 balance
      print('BalanceService: Initialization failed: $e');
      _balance = 0.0;
      notifyListeners();
    }
  }

  /// Fetch balance from backend
  Future<void> _fetchBalanceFromBackend() async {
    try {
      print('BalanceService: Fetching balance from backend...');
      final response = await _profileApiService.getBalance();
      print('BalanceService: Backend response: $response');
      _balance = (response['balance'] as num?)?.toDouble() ?? 0.0;
      print('BalanceService: Updated balance to: $_balance');
      notifyListeners();
    } catch (e) {
      // If API fails, try to get balance from local storage or keep current balance
      print('BalanceService: Failed to fetch balance: $e');
      // Don't reset to 0, keep current balance
      notifyListeners();
    }
  }

  /// Add amount to balance (when claiming gifts) - NOT USED, use claimGift instead
  Future<void> addToBalance(double amount) async {
    try {
      await _profileApiService.addToBalance(amount);
      // Always fetch fresh balance from backend
      await _fetchBalanceFromBackend();
    } catch (e) {
      rethrow;
    }
  }

  /// Subtract amount from balance (when spending)
  Future<void> subtractFromBalance(double amount) async {
    try {
      await _profileApiService.subtractFromBalance(amount);
      // Always fetch fresh balance from backend
      await _fetchBalanceFromBackend();
    } catch (e) {
      rethrow;
    }
  }

  /// Update balance directly (from claim response)
  void updateBalanceFromResponse(double newBalance) {
    print('BalanceService: Updating balance from response: $newBalance');
    _balance = newBalance;
    notifyListeners();
  }

  /// Clear balance (on logout)
  Future<void> clearBalance() async {
    _balance = 0.0;
    notifyListeners();
  }

  /// Format balance for display
  String get formattedBalance => 'KSh ${_balance.toStringAsFixed(2)}';
}
