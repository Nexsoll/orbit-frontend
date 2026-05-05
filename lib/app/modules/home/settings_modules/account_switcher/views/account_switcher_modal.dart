// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:s_translation/generated/l10n.dart';
import '../controllers/account_switcher_controller.dart';
import '../widgets/account_list_item.dart';
import '../../../../auth/login/views/login_view.dart';
import '../../../../splash/views/splash_view.dart';

class AccountSwitcherModal extends StatefulWidget {
  const AccountSwitcherModal({super.key});

  @override
  State<AccountSwitcherModal> createState() => _AccountSwitcherModalState();
}

class _AccountSwitcherModalState extends State<AccountSwitcherModal> {
  late AccountSwitcherController controller;

  @override
  void initState() {
    super.initState();
    controller = AccountSwitcherController();
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheet(
      title: Text(
        S.of(context).switchAccount,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      message: Text(
        S.of(context).selectAccountToSwitchTo,
        style: const TextStyle(fontSize: 14),
      ),
      actions: [
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ValueListenableBuilder<SLoadingState<List<AccountSession>>>(
            valueListenable: controller,
            builder: (context, state, child) {
              if (state.loadingState == VChatLoadingState.loading) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }

              if (state.loadingState == VChatLoadingState.error) {
                return SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      S.of(context).errorLoadingAccounts,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              final accounts = state.data;
              if (accounts.isEmpty) {
                return SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(S.of(context).noAccountsFound),
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Account list
                  ...accounts.map((account) => AccountListItem(
                        account: account,
                        onTap: () => _switchToAccount(account),
                        onRemove: () => _removeAccount(account),
                      )),

                  // Add account button
                  CupertinoActionSheetAction(
                    onPressed: _addNewAccount,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.person_add_solid,
                          color: CupertinoColors.systemBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          S.of(context).addAccount,
                          style: const TextStyle(
                            color: CupertinoColors.systemBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(S.of(context).cancel),
      ),
    );
  }

  void _switchToAccount(AccountSession account) async {
    if (account.isActive) {
      Navigator.of(context).pop();
      return;
    }

    try {
      VAppAlert.showLoading(context: context);
      try {
        await VChatController.I.profileApi.logout();
      } catch (_) {}
      await controller.switchToAccount(account.accountId);
      Navigator.of(context).pop(); // Close loading
      Navigator.of(context).pop(); // Close modal

      // Show success message
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: S.of(context)
            .switchedToAccount(account.profile.baseUser.fullName),
      );

      // Refresh the app to reflect the new account
      _refreshApp();
    } catch (e) {
      Navigator.of(context).pop(); // Close loading
      VAppAlert.showErrorSnackBar(
        context: context,
        message: '${S.of(context).errorSwitchingAccount}: ${e.toString()}',
      );
    }
  }

  void _removeAccount(AccountSession account) async {
    final result = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: S.of(context).removeAccount,
      content: S.of(context).areYouSureRemoveAccount,
    );

    if (result == 1) {
      try {
        VAppAlert.showLoading(context: context);
        await controller.removeAccount(account.accountId);
        Navigator.of(context).pop(); // Close loading

        VAppAlert.showSuccessSnackBar(
          context: context,
          message: S.of(context).accountRemoved,
        );

        // If we removed the current account and there are no accounts left,
        // navigate to login
        if (MultiAccountManager.instance.accounts.isEmpty) {
          Navigator.of(context).pop(); // Close modal
          _navigateToLogin();
        }
      } catch (e) {
        Navigator.of(context).pop(); // Close loading
        VAppAlert.showErrorSnackBar(
          context: context,
          message: '${S.of(context).errorRemovingAccount}: ${e.toString()}',
        );
      }
    }
  }

  void _addNewAccount() {
    Navigator.of(context).pop(); // Close modal
    context.toPage(const LoginView(showBackButton: true));
  }

  void _refreshApp() {
    // Navigate to splash to reinitialize the app with new account
    context.toPage(
      const SplashView(),
      withAnimation: false,
      removeAll: true,
    );
  }

  void _navigateToLogin() {
    context.toPage(
      const LoginView(),
      withAnimation: true,
      removeAll: true,
    );
  }
}
