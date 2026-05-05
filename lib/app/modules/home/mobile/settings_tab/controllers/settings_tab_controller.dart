// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:super_up/app/modules/home/mobile/calls_tab/controllers/calls_tab_controller.dart';
import 'package:super_up/app/modules/home/mobile/rooms_tab/controllers/rooms_tab_controller.dart';
import 'package:super_up/app/modules/home/mobile/story_tab/controllers/story_tab_controller.dart';
import 'package:super_up/app/modules/home/mobile/users_tab/controllers/users_tab_controller.dart';
import 'package:super_up/app/modules/splash/views/splash_view.dart';

import 'package:super_up/main.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:v_platform/v_platform.dart';
import '../../../../../core/services/app_lock_service.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';

import '../../../../../core/controllers/version_checker_controller.dart';
import '../states/setting_state.dart';
import '../views/media_storage_settings.dart';
import '../views/sheet_for_choose_language.dart';
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';

class SettingsTabController extends SLoadingController<SettingState> {
  SettingsTabController()
      : super(
          SLoadingState(
            SettingState(
                isDarkMode: VAppPref.getStringOrNullKey(
                      SStorageKeys.appTheme.name,
                    ) ==
                    ThemeMode.dark.name,
                language: VAppPref.getStringOrNullKey(
                      SStorageKeys.appLanguageTitle.name,
                    ) ??
                    "English",
                inAppAlerts: VAppPref.getBoolOrNull(
                      SStorageKeys.inAppAlerts.name,
                    ) ??
                    true,
                appLockEnabled: VAppPref.getBool(
                  SStorageKeys.appLockEnabled.name,
                ),
                twoFactorEnabled: false,
            ),
          ),
        );
  final versionCheckerController = GetIt.I.get<VersionCheckerController>();
  final appConfig = VAppConfigController.appConfig;

  @override
  void onClose() {}

  @override
  void onInit() {
    _loadTwoFactorStatus();
  }

  // ===== Two-Factor (Email) =====
  Future<void> onToggleTwoFactor(BuildContext context, bool enable) async {
    if (enable) {
      try {
        VAppAlert.showLoading(context: context);
        await ProfileApiService.init().requestTwoFactor();
        Navigator.of(context).pop();
        final inputs = await showTextInputDialog(
          context: context,
          title: 'Enable Email 2FA',
          message:
              'A 6-digit verification code has been sent to your email. Enter it to enable Two-Factor Authentication.',
          textFields: const [
            DialogTextField(
              hintText: '6-digit code',
              keyboardType: TextInputType.number,
            ),
          ],
        );
        if (inputs == null || inputs.isEmpty || inputs.first.trim().isEmpty) {
          VAppAlert.showErrorSnackBar(
            context: context,
            message: 'Two-factor code is required to enable',
          );
          return;
        }
        VAppAlert.showLoading(context: context);
        await ProfileApiService.init().enableTwoFactor(inputs.first.trim());
        Navigator.of(context).pop();
        value.data = value.data.copyWith(twoFactorEnabled: true);
        notifyListeners();
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Email 2FA enabled',
        );
      } catch (e) {
        Navigator.of(context).maybePop();
        VAppAlert.showErrorSnackBar(
          context: context,
          message: e.toString(),
        );
      }
    } else {
      try {
        VAppAlert.showLoading(context: context);
        await ProfileApiService.init().requestTwoFactor();
        Navigator.of(context).pop();
        final inputs = await showTextInputDialog(
          context: context,
          title: 'Disable Email 2FA',
          message:
              'Enter the 6-digit verification code sent to your email to disable Two-Factor Authentication.',
          textFields: const [
            DialogTextField(
              hintText: '6-digit code',
              keyboardType: TextInputType.number,
            ),
          ],
        );
        if (inputs == null || inputs.isEmpty || inputs.first.trim().isEmpty) {
          VAppAlert.showErrorSnackBar(
            context: context,
            message: 'Two-factor code is required to disable',
          );
          return;
        }
        VAppAlert.showLoading(context: context);
        await ProfileApiService.init().disableTwoFactor(inputs.first.trim());
        Navigator.of(context).pop();
        value.data = value.data.copyWith(twoFactorEnabled: false);
        notifyListeners();
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Email 2FA disabled',
        );
      } catch (e) {
        Navigator.of(context).maybePop();
        VAppAlert.showErrorSnackBar(
          context: context,
          message: e.toString(),
        );
      }
    }
  }

  Future<void> _loadTwoFactorStatus() async {
    try {
      final enabled = await ProfileApiService.init().getTwoFactorStatusEnabled();
      value.data = value.data.copyWith(twoFactorEnabled: enabled);
      notifyListeners();
    } catch (e) {
      // ignore
    }
  }

  Future<void> logout(BuildContext context) async {
    final currentAccount = MultiAccountManager.instance.currentAccount;
    if (currentAccount == null) return;

    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: S.of(context).areYouSure,
      content:
          "${S.of(context).yourAreAboutToLogoutFromThisAccount} ${currentAccount.profile.baseUser.fullName}",
    );
    if (res == 1) {
      vSafeApiCall(
        onLoading: () {
          VAppAlert.showLoading(context: context);
        },
        request: () async {
          await VChatController.I.profileApi.logout();

          // Remove current account from multi-account manager
          await MultiAccountManager.instance
              .removeAccount(currentAccount.accountId);

          // Clear balance when logging out
          await BalanceService.instance.clearBalance();
        },
        onSuccess: (response) async {
          // Clean up GetIt controllers before navigation
          _cleanupGetItControllers();

          // Check if there are other accounts
          if (MultiAccountManager.instance.accounts.isNotEmpty) {
            // Switch to another account
            context.toPage(
              const SplashView(),
              withAnimation: false,
              removeAll: true,
            );
          } else {
            // No other accounts, go to login
            AppAuth.setProfileNull();
            await VAppPref.clearAuthKeys();
            context.toPage(
              const SplashView(),
              withAnimation: false,
              removeAll: true,
            );
          }
        },
        onError: (exception, trace) {
          context.pop();
          VAppAlert.showOkAlertDialog(
            context: context,
            title: S.of(context).error,
            content: exception,
          );
        },
      );
    }
  }

  // ===== App Lock =====
  Future<void> onToggleAppLock(BuildContext context, bool enable) async {
    if (enable) {
      final ok = await AppLockService.instance.enableWithPrompt(context);
      value.data = value.data.copyWith(appLockEnabled: ok);
      notifyListeners();
      if (!ok) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Authentication required to enable App Lock',
        );
      }
    } else {
      await AppLockService.instance.disable();
      value.data = value.data.copyWith(appLockEnabled: false);
      notifyListeners();
    }
  }

  Future<void> openAdminPanel(BuildContext context) async {
    await VStringUtils.lunchLink("https://admin.orbit.ke");
  }

  Future<void> onThemeChange(BuildContext context) async {
    final newTheme = !value.data.isDarkMode;
    value.data = value.data.copyWith(isDarkMode: newTheme);
    //update the flutter cupertino theme
    CupertinoTheme.of(navigatorKey.currentState!.context)
        .copyWith(brightness: newTheme ? Brightness.dark : Brightness.light);
    VThemeListener.I
        .setTheme(newTheme == false ? ThemeMode.light : ThemeMode.dark);
    notifyListeners();
  }

  FutureOr<void> onLanguageChange(BuildContext context) async {
    final res = await showCupertinoModalBottomSheet(
      expand: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const SheetForChooseLanguage(),
    ) as ModelSheetItem?;
    if (res == null) {
      return;
    }
    value.data = value.data.copyWith(language: res.title);
    await VLanguageListener.I.setLocal(Locale(res.id.toString()));
    await VAppPref.setStringKey(
      SStorageKeys.appLanguageTitle.name,
      res.title,
    );
    notifyListeners();
  }

  FutureOr<void> checkForUpdates(BuildContext context) async {
    final url = VPlatforms.isIOS
        ? 'https://apps.apple.com/us/app/orbit-chats/id6749538035'
        : 'https://play.google.com/store/apps/details?id=com.orbit.ke';
    await VStringUtils.lunchLink(url);
  }

  FutureOr<void> onChangeAppNotifications(BuildContext context) async {
    final options = <ModelSheetItem>[
      ModelSheetItem<bool>(
        title: S.of(context).on,
        id: true,
      ),
      ModelSheetItem<bool>(
        title: S.of(context).off,
        id: false,
      ),
    ];
    final res = await VAppAlert.showModalSheetWithActions(
      content: options,
      context: navigatorKey.currentState!.context,
    ) as ModelSheetItem<bool>?;
    if (res == null) return;
    value.data = value.data.copyWith(inAppAlerts: res.id);
    notifyListeners();
    await VAppPref.setBool(
      SStorageKeys.inAppAlerts.name,
      res.id,
    );
    final pushService =
        await VChatController.I.vChatConfig.currentPushProviderService;
    if (pushService == null) return null;

    if (res.id) {
      ///enable
      // Request permissions first on iOS when enabling notifications
      if (VPlatforms.isIOS) {
        await pushService.askForPermissions();
      }

      final token = await pushService.getToken(
        VPlatforms.isWeb ? SConstants.webVapidKey : null,
      );
      if (token == null) return;
      await VChatController.I.nativeApi.remote.profile
          .addPushKey(fcm: token, voipKey: null);
    } else {
      await pushService.deleteToken();
      await VChatController.I.nativeApi.remote.profile.deleteFcm();
    }
  }

  FutureOr<void> onStorageClick(BuildContext context) async {
    if (VPlatforms.isMobile) {
      context.toPage(const MediaStorageSettings());
      return;
    }
    VAppAlert.showOkAlertDialog(
      context: context,
      title: S.of(context).dataPrivacy,
      content: S
          .of(context)
          .allDataHasBeenBackupYouDontNeedToManageSaveTheDataByYourself,
    );
  }

  FutureOr<void> tellAFriend(BuildContext context) async {
    await Share.share('''Try ${SConstants.appName} — social media chat system

ANDROID
https://play.google.com/store/apps/details?id=com.orbit.ke

IOS
https://apps.apple.com/us/app/orbit-chats/id6749538035''');
  }

  FutureOr<void> shareMyProfile(BuildContext context) async {
    final myProfile = AppAuth.myProfile;
    final profileUrl = 'https://api.orbit.ke/profile/${myProfile.baseUser.id}';

    await Share.share(
        '''Check out ${myProfile.baseUser.fullName}'s profile on ${SConstants.appName}!

$profileUrl

Download ${SConstants.appName}:

ANDROID
https://play.google.com/store/apps/details?id=com.orbit.ke

IOS
https://apps.apple.com/us/app/orbit-chats/id6749538035''');
  }

  void _cleanupGetItControllers() {
    // Safely close and unregister controllers to prevent disposed controller errors
    if (GetIt.I.isRegistered<RoomsTabController>()) {
      try {
        GetIt.I.get<RoomsTabController>().onClose();
        GetIt.I.unregister<RoomsTabController>();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }

    if (GetIt.I.isRegistered<CallsTabController>()) {
      try {
        GetIt.I.get<CallsTabController>().onClose();
        GetIt.I.unregister<CallsTabController>();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }

    if (GetIt.I.isRegistered<UsersTabController>()) {
      try {
        GetIt.I.get<UsersTabController>().onClose();
        GetIt.I.unregister<UsersTabController>();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }

    if (GetIt.I.isRegistered<StoryTabController>()) {
      try {
        GetIt.I.unregister<StoryTabController>();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
  }
}
