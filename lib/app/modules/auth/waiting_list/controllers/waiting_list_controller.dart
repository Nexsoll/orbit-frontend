// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/api_service.dart';
import 'package:super_up/app/modules/home/mobile/calls_tab/controllers/calls_tab_controller.dart';
import 'package:super_up/app/modules/home/mobile/rooms_tab/controllers/rooms_tab_controller.dart';
import 'package:super_up/app/modules/home/mobile/story_tab/controllers/story_tab_controller.dart';
import 'package:super_up/app/modules/home/mobile/users_tab/controllers/users_tab_controller.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import '../../../home/home_controller/views/home_view.dart';
import '../../../splash/views/splash_view.dart';
import '../states/waiting_list_state.dart';

class WaitingListController extends SLoadingController<WaitingListState?> {
  final txtController = TextEditingController();

  WaitingListController() : super(SLoadingState(null));
  final _profileApi = GetIt.I.get<ProfileApiService>();

  @override
  void onClose() {
    txtController.dispose();
  }

  @override
  void onInit() {}

  Future<void> refreshProfile(BuildContext context) async {
    await vSafeApiCall<SMyProfile>(
      onError: (exception, trace) {
        VAppAlert.showErrorSnackBar(
          message: exception.toString(),
          context: context,
        );
      },
      request: () async {
        return _profileApi.getMyProfile();
      },
      onSuccess: (SMyProfile response) async {
        if (response.registerStatus == RegisterStatus.accepted) {
          VAppAlert.showSuccessSnackBar(
            message: S.of(context).congregationsYourAccountHasBeenAccepted,
            context: context,
          );
          await VAppPref.setMap(SStorageKeys.myProfile.name, response.toMap());
          await Future.delayed(const Duration(seconds: 2));
          context.toPage(
            const HomeView(),
            removeAll: true,
            withAnimation: true,
          );
        } else {
          VAppAlert.showSuccessSnackBar(
            message: S.of(context).yourAccountIsUnderReview,
            context: context,
          );
        }
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }

  void logout(BuildContext context) {
    vSafeApiCall(
      onLoading: () {
        VAppAlert.showLoading(context: context);
      },
      request: () async {
        await VChatController.I.profileApi.logout();
        final current = MultiAccountManager.instance.currentAccount;
        if (current != null) {
          await MultiAccountManager.instance.removeAccount(current.accountId);
        } else {
          AppAuth.setProfileNull();
          await VAppPref.clearAuthKeys();
        }
      },
      onSuccess: (response) {
        // Clean up GetIt controllers before navigation
        _cleanupGetItControllers();

        VChatController.I.navigatorKey.currentContext!.toPage(
          const SplashView(),
          withAnimation: false,
          removeAll: true,
        );
        AppAuth.setProfileNull();
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
