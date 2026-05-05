// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import '../views/account_switcher_modal.dart';
import '../../../../auth/login/views/login_view.dart';
import '../../../mobile/settings_tab/widgets/settings_list_item_tile.dart';

class AccountSwitcherButton extends StatefulWidget {
  const AccountSwitcherButton({super.key});

  @override
  State<AccountSwitcherButton> createState() => _AccountSwitcherButtonState();
}

class _AccountSwitcherButtonState extends State<AccountSwitcherButton> {
  bool hasMultipleAccounts = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkMultipleAccounts();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SettingsListItemTile(
        color: Colors.grey.shade800,
        title: S.of(context).addAccount,
        subtitle: S.of(context).addAnotherAccount.text,
        icon: CupertinoIcons.person_add_solid,
        onTap: () => _navigateToAddAccount(context),
      );
    }

    return SettingsListItemTile(
      color: Colors.grey.shade800,
      title: hasMultipleAccounts
          ? S.of(context).switchAccount
          : S.of(context).addAccount,
      subtitle: hasMultipleAccounts
          ? S.of(context).manageYourAccounts.text
          : S.of(context).addAnotherAccount.text,
      icon: hasMultipleAccounts
          ? CupertinoIcons.person_2_fill
          : CupertinoIcons.person_add_solid,
      onTap: () => _handleTap(context, hasMultipleAccounts),
    );
  }

  Future<void> _checkMultipleAccounts() async {
    try {
      await MultiAccountManager.instance.initialize();
      final hasMultiple = MultiAccountManager.instance.hasMultipleAccounts;
      print(
          'AccountSwitcherButton: _checkMultipleAccounts - hasMultiple: $hasMultiple');
      if (mounted) {
        setState(() {
          hasMultipleAccounts = hasMultiple;
          isLoading = false;
        });
      }
    } catch (e) {
      print('AccountSwitcherButton: Error checking accounts: $e');
      if (mounted) {
        setState(() {
          hasMultipleAccounts = false;
          isLoading = false;
        });
      }
    }
  }

  void _refreshAccountState() {
    print('AccountSwitcherButton: _refreshAccountState called');
    setState(() {
      isLoading = true;
    });
    _checkMultipleAccounts();
  }

  void _handleTap(BuildContext context, bool hasMultipleAccounts) {
    if (hasMultipleAccounts) {
      _showAccountSwitcher(context);
    } else {
      _navigateToAddAccount(context);
    }
  }

  void _showAccountSwitcher(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => const AccountSwitcherModal(),
    ).then((_) {
      // Refresh state when modal is closed
      _refreshAccountState();
    });
  }

  void _navigateToAddAccount(BuildContext context) async {
    await context.toPage(const LoginView(showBackButton: true));
    // Refresh state when returning from login
    _refreshAccountState();
  }
}
