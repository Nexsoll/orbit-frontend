// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:super_up/app/modules/home/mobile/calls_tab/controllers/calls_tab_controller.dart';
import 'package:super_up/app/modules/home/mobile/rooms_tab/controllers/rooms_tab_controller.dart';
import 'package:super_up/app/modules/home/mobile/story_tab/controllers/story_tab_controller.dart';
import 'package:super_up/app/modules/home/mobile/users_tab/controllers/users_tab_controller.dart';
import 'package:super_up/app/modules/home/settings_modules/my_account/views/sheet_for_update_password.dart';
import 'package:super_up/app/modules/home/settings_modules/my_account/views/sheet_for_select_profession.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import '../../../../../core/api_service/profile/profile_api_service.dart';
import '../../../../splash/views/splash_view.dart';
import '../states/my_account_state.dart';
import '../../../../../core/widgets/custom_image_cropper.dart';

class MyAccountController extends SLoadingController<MyAccountState?> {
  final ProfileApiService profileApiService;

  MyAccountController(this.profileApiService) : super(SLoadingState(null));

  @override
  void onClose() {}

  @override
  void onInit() {}

  void updateUserImage(BuildContext context) async {
    final image = await AppImageCropper.pickAndCrop(context);
    if (image == null) return;
    vSafeApiCall<String>(
      onLoading: () {
        // VAppAlert.showLoading(context: context);
      },
      request: () async {
        return await profileApiService.updateImage(image);
      },
      onSuccess: (response) async {
        // final file = VPlatformFile.fromUrl(networkUrl: response);
        final newProfile = AppAuth.myProfile.copyWith(
          baseUser: AppAuth.myProfile.baseUser.copyWith(userImage: response),
        );
        await VAppPref.setMap(SStorageKeys.myProfile.name, newProfile.toMap());
        AppAuth.setProfileNull();
        update();
        // context.pop();
      },
    );
  }

  void updateUserProfession(BuildContext context) async {
    final selected = await showCupertinoModalBottomSheet<String>(
      expand: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const SheetForSelectProfession(),
    );
    if (selected == null || selected.isEmpty) return;
    vSafeApiCall<String>(
      onLoading: () {},
      request: () async {
        await profileApiService.updateUserProfession(selected);
        return selected;
      },
      onSuccess: (response) async {
        final newProfile = AppAuth.myProfile.copyWith(profession: response);
        await VAppPref.setMap(SStorageKeys.myProfile.name, newProfile.toMap());
        AppAuth.setProfileNull();
        update();
      },
    );
  }

  /// UI-only: restore edit icon behavior for Email. Currently backend does not
  /// support changing email, so we show the input then inform user.
  void updateUserEmail(BuildContext context) async {
    final attempted = await context.toPage(
      VSingleRename(
        appbarTitle: S.of(context).updateYourName, // reuse generic title UI
        subTitle: AppAuth.myProfile.email,
        oldValue: AppAuth.myProfile.email,
      ),
      withAnimation: false,
    );
    if (attempted == null) return;
    await VAppAlert.showOkAlertDialog(
      context: context,
      title: 'Update Email',
      content: 'Changing email is not supported in this version.',
    );
  }

  void updateUserName(BuildContext context) async {
    final newName = await context.toPage(
      VSingleRename(
        appbarTitle: S.of(context).updateYourName,
        subTitle: AppAuth.myProfile.baseUser.fullName,
      ),
      withAnimation: false,
    );
    if (newName == null || newName.toString().isEmpty) return;
    vSafeApiCall<String>(
      onLoading: () {
        //VAppAlert.showLoading(context: context);
      },
      request: () async {
        await profileApiService.updateUserName(newName);
        return newName;
      },
      onSuccess: (response) async {
        final newProfile = AppAuth.myProfile.copyWith(
          baseUser: AppAuth.myProfile.baseUser.copyWith(fullName: response),
        );
        await VAppPref.setMap(SStorageKeys.myProfile.name, newProfile.toMap());
        AppAuth.setProfileNull();
        update();
        //  context.pop();
      },
    );
  }

  void updateUserBio(BuildContext context) async {
    final newBio = await context.toPage(
      VSingleRename(
        appbarTitle: S.of(context).updateYourBio,
        subTitle: AppAuth.myProfile.userBio,
      ),
      withAnimation: false,
    );
    if (newBio == null || newBio.toString().isEmpty) return;
    vSafeApiCall<String>(
      onLoading: () {
        //  VAppAlert.showLoading(context: context);
      },
      request: () async {
        await profileApiService.updateUserBio(newBio);
        return newBio;
      },
      onSuccess: (response) async {
        final newProfile = AppAuth.myProfile.copyWith(bio: response);
        await VAppPref.setMap(SStorageKeys.myProfile.name, newProfile.toMap());
        AppAuth.setProfileNull();
        update();
        //context.pop();
      },
    );
  }

  void updateUserPhoneNumber(BuildContext context) async {
    final newPhoneNumber = await context.toPage(
      VSingleRename(
        appbarTitle: "Update Your Phone Number",
        subTitle: AppAuth.myProfile.phoneNumber ?? "",
      ),
      withAnimation: false,
    );
    if (newPhoneNumber == null || newPhoneNumber.toString().isEmpty) return;
    vSafeApiCall<String>(
      onLoading: () {
        //  VAppAlert.showLoading(context: context);
      },
      request: () async {
        await profileApiService.updateUserPhoneNumber(newPhoneNumber);
        return newPhoneNumber;
      },
      onSuccess: (response) async {
        final newProfile = AppAuth.myProfile.copyWith(phoneNumber: response);
        await VAppPref.setMap(SStorageKeys.myProfile.name, newProfile.toMap());
        AppAuth.setProfileNull();
        update();
        //context.pop();
      },
    );
  }

  void updateUserGender(BuildContext context) async {
    final selectedGender = await showModalActionSheet<String>(
      context: context,
      title: 'Select Gender',
      actions: [
        SheetAction(
          key: 'male',
          label: 'Male',
        ),
        SheetAction(
          key: 'female',
          label: 'Female',
        ),
        SheetAction(
          key: 'other',
          label: 'Other',
        ),
      ],
    );
    
    if (selectedGender == null) return;
    
    vSafeApiCall<String>(
      onLoading: () {
        //  VAppAlert.showLoading(context: context);
      },
      request: () async {
        await profileApiService.updateUserGender(selectedGender);
        return selectedGender;
      },
      onSuccess: (response) async {
        final newProfile = AppAuth.myProfile.copyWith(gender: response);
        await VAppPref.setMap(SStorageKeys.myProfile.name, newProfile.toMap());
        AppAuth.setProfileNull();
        update();
      },
    );
  }

  void updateUserPassword(BuildContext context) async {
    await showCupertinoModalBottomSheet(
      expand: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const SheetForUpdatePassword(),
    );
  }

  Future<void> deleteMyAccount(BuildContext context) async {
    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: S.of(context).areYouSure,
      content: S
          .of(context)
          .youAreAboutToDeleteYourAccountYourAccountWillNotAppearAgainInUsersList,
    );
    if (res == 1) {
      final passwordRes = await VAppAlert.showTextInputDialog(
        context: context,
        textFields: [
          DialogTextField(hintText: S.of(context).password, obscureText: true),
        ],
      );
      if (passwordRes == null) return;

      vSafeApiCall<void>(
        onLoading: () {
          VAppAlert.showLoading(context: context);
        },
        request: () async {
          await VChatController.I.profileApi.logout();
          await profileApiService.deleteMyAccount(passwordRes.first);
          final current = MultiAccountManager.instance.currentAccount;
          if (current != null) {
            await MultiAccountManager.instance.removeAccount(current.accountId);
          } else {
            AppAuth.setProfileNull();
            await VAppPref.clearAuthKeys();
          }
        },
        onSuccess: (response) async {
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
          if (exception == "invalidLoginData") {
            VAppAlert.showErrorSnackBar(
                message: S.of(context).invalidLoginData, context: context);
          } else {
            VAppAlert.showErrorSnackBar(message: exception, context: context);
          }
        },
      );
    }
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
