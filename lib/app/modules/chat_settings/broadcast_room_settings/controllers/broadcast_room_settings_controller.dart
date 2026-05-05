// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:super_up/app/modules/broadcast_members/views/broadcast_members_view.dart';
import 'package:super_up/app/modules/chat_settings/broadcast_room_settings/mobile/sheet_for_add_members_to_broadcast.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../../../core/app_config/app_config_controller.dart';
import '../../../../core/widgets/custom_image_cropper.dart';

class BroadcastRoomSettingsController
    extends SLoadingController<VMyBroadcastInfo> {
  final txtController = TextEditingController();

  VToChatSettingsModel settingsModel;
  late VMyBroadcastInfo info;

  BroadcastRoomSettingsController(
    this.settingsModel,
  ) : super(SLoadingState(VMyBroadcastInfo.empty()));

  @override
  void onInit() {
    getData();
    AdsBannerWidget.loadAd(
      VPlatforms.isAndroid
          ? SConstants.androidInterstitialId
          : SConstants.iosInterstitialId,
      enableAds: VAppConfigController.appConfig.enableAds,
    );
  }

  String get roomId => settingsModel.roomId;

  void onChangeImage(BuildContext context) async {
    final image = await AppImageCropper.pickAndCrop(context);
    if (image != null) {
      vSafeApiCall<String>(
        onLoading: () {
          VAppAlert.showLoading(context: context);
        },
        request: () async {
          return VChatController.I.roomApi.updateBroadcastImage(
            roomId: roomId,
            file: image,
          );
        },
        onSuccess: (response) {
          settingsModel = settingsModel.copyWith(image: response);
          Navigator.of(context).pop();
          update();
        },
      );
    }
  }

  Future<void> getData() async {
    await vSafeApiCall<VMyBroadcastInfo>(
      onLoading: () async {
        setStateLoading();
      },
      onError: (exception, trace) {
        setStateError(exception);
      },
      request: () async {
        return VChatController.I.roomApi.getBroadcastMyInfo(roomId: roomId);
      },
      onSuccess: (response) {
        info = response;
        setStateSuccess();
        update();
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }

  @override
  void onClose() {
    txtController.dispose();
  }

  void onUpdateTitle(BuildContext context) async {
    final newTitle = await context.toPage(VSingleRename(
      appbarTitle: S.of(context).updateBroadcastTitle,
      oldValue: settingsModel.title,
      subTitle: '',
    ));
    if (newTitle == null) return;
    if (newTitle != settingsModel.title) {
      await vSafeApiCall<String>(
        onLoading: () {
          // VAppAlert.showLoading(context: context);
        },
        request: () async {
          await VChatController.I.nativeApi.local.room.updateRoomName(
              VUpdateRoomNameEvent(roomId: roomId, name: newTitle));
          await VChatController.I.roomApi
              .updateBroadcastTitle(roomId: roomId, title: newTitle);
          return newTitle;
        },
        onSuccess: (response) {
          settingsModel = settingsModel.copyWith(
            title: response,
          );
          update();
        },
      );
      // Navigator.of(context).pop();
    }
  }

  void onGoShowMembers(BuildContext context) {
    context.toPage(BroadcastMembersView(
      roomId: roomId,
      settingsModel: settingsModel,
    ));
  }

  void addParticipantsToBroadcast(BuildContext context) async {
    final users = await showCupertinoModalBottomSheet(
      expand: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SheetForAddMembersToBroadcast(
        broadcastId: roomId,
      ),
    ) as List<SBaseUser>?;
    // final users = await context.toPage(
    //   const ChooseMembersView(),
    // ) as List<SBaseUser>?;
    if (users != null) {
      _addBroadcastMembers(context, users.map((e) => e.id.toString()).toList());
      VAppAlert.showSuccessSnackBar(
          message: S.of(context).success, context: context);
      getData();
    }
  }

  void _addBroadcastMembers(BuildContext context, List<String> list) async {
    await vSafeApiCall<void>(
      onLoading: () {
        VAppAlert.showLoading(
          context: context,
          isDismissible: true,
        );
      },
      request: () async {
        await VChatController.I.roomApi
            .addParticipantsToBroadcast(roomId, list);
      },
      onSuccess: (response) {
        VAppAlert.showSuccessSnackBar(
            context: context, message: S.of(context).usersAddedSuccessfully);
      },
    );
    Navigator.of(context).pop();
  }

  openFullImage(BuildContext context) {}
}
