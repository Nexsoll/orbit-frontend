// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:super_up_core/super_up_core.dart';

class AccountSwitcherController
    extends SLoadingController<List<AccountSession>> {
  AccountSwitcherController() : super(SLoadingState([]));

  @override
  void onInit() {
    loadAccounts();
  }

  @override
  void onClose() {}

  /// Load all accounts
  Future<void> loadAccounts() async {
    try {
      setStateLoading();
      await MultiAccountManager.instance.initialize();
      final accounts =
          MultiAccountManager.instance.getAccountsSortedByLastActive();
      value.data = accounts;
      setStateSuccess();
    } catch (e) {
      setStateError('Failed to load accounts: ${e.toString()}');
    }
  }

  /// Switch to a specific account
  Future<void> switchToAccount(String accountId) async {
    try {
      await MultiAccountManager.instance.switchToAccount(accountId);
      await loadAccounts(); // Refresh the list
    } catch (e) {
      rethrow;
    }
  }

  /// Remove an account
  Future<void> removeAccount(String accountId) async {
    try {
      await MultiAccountManager.instance.removeAccount(accountId);
      await loadAccounts(); // Refresh the list
    } catch (e) {
      rethrow;
    }
  }

  /// Get current active account
  AccountSession? get currentAccount =>
      MultiAccountManager.instance.currentAccount;

  /// Check if has multiple accounts
  bool get hasMultipleAccounts =>
      MultiAccountManager.instance.hasMultipleAccounts;
}
