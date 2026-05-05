// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/modules/chat_settings/chat_star_messages/views/chat_star_messages_page.dart';
import 'package:super_up/app/modules/chat_settings/group_room_settings/mobile/sheet_for_add_members_to_group.dart';
import 'package:super_up/app/modules/group_members/views/group_members_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:super_up/app/core/widgets/custom_image_cropper.dart';

import '../../chat_media_docs_voice/views/chat_media_view.dart';
import '../states/group_room_setting_state.dart';
import '../../../../core/services/custom_notification_sound_service.dart';
import '../../../../core/api_service/community/community_api_service.dart';
import '../../../../core/api_service/channel/group_invite_api_service.dart';
import '../../../../core/services/chat_lock_service.dart';

class GroupRoomSettingsController
    extends SLoadingController<GroupRoomSettingState> {
  final txtController = TextEditingController();
  final sizer = GetIt.I.get<AppSizeHelper>();
  final VToChatSettingsModel _settingsModel;

  GroupRoomSettingsController(this._settingsModel)
      : super(SLoadingState(GroupRoomSettingState(_settingsModel)));

  VToChatSettingsModel get settingsModel => value.data.settingsModel;

  VMyGroupInfo? get groupInfo => value.data.groupInfo;

  bool get isMeAdminOrSuper {
    if (value.data.groupInfo!.myRole == VGroupMemberRole.member) return false;
    return true;
  }

  bool get canEditGroupInfo => isMeCreator || isMeAdminOrSuper;

  // ================= Group Invite Link =================
  Future<void> shareInviteLink(BuildContext context) async {
    try {
      final info = await GroupInviteApiService.I.getInviteLink(roomId);
      final link = (info['link'] ?? info['url'] ?? '') as String;
      if (link.isEmpty) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Failed to get invite link');
        return;
      }
      // Share only the raw URL, nothing else
      await Share.share(link);
    } catch (e) {
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  Future<void> resetInviteLink(BuildContext context) async {
    if (!isMeAdminOrSuper) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Only admins can reset invite link');
      return;
    }
    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: 'Reset invite link?',
      content: 'Old link will stop working and a new one will be generated.',
    );
    if (res != 1) return;
    try {
      VAppAlert.showLoading(context: context);
      await GroupInviteApiService.I.regenerateInviteLink(roomId);
      Navigator.of(context).maybePop();
      VAppAlert.showSuccessSnackBar(context: context, message: 'Invite link reset');
    } catch (e) {
      Navigator.of(context).maybePop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  Future<void> updateSendPolicyAdminsOnly(BuildContext context, bool adminsOnly) async {
    if (!isMeAdminOrSuper) return;
    final currentExtra = Map<String, dynamic>.from(
      groupInfo?.groupSettings?.extraData ?? const <String, dynamic>{},
    );
    currentExtra['sendPolicy'] = adminsOnly ? 'admins' : 'all';
    await vSafeApiCall<void>(
      request: () async {
        await VChatController.I.roomApi.updateGroupExtraData(
          roomId: roomId,
          data: currentExtra,
        );
      },
      onSuccess: (_) async {
        // Update local state
        final gi = await VChatController.I.roomApi.getGroupVMyGroupInfo(roomId: roomId);
        value.data.groupInfo = gi;
        update();
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: S.of(context).success,
        );
      },
      onError: (e, s) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      },
    );
  }

  bool get isMeCreator {
    if (value.data.groupInfo?.groupSettings == null) return false;
    return value.data.groupInfo!.groupSettings!.isMeCreator;
  }

  String? get getGroupDesc {
    if (value.data.groupInfo!.groupSettings == null) return null;
    return value.data.groupInfo!.groupSettings!.desc;
  }

  String get roomId => value.data.settingsModel.roomId;

  @override
  void onInit() {
    getData();
    _loadLockStatus();
    _loadCustomNotificationSound();
  }

  Future<void> getData() async {
    await vSafeApiCall<VMyGroupInfo>(
      onLoading: () async {
        setStateLoading();
      },
      onError: (exception, trace) {
        setStateError(exception);
      },
      request: () async {
        return VChatController.I.roomApi.getGroupVMyGroupInfo(roomId: roomId);
      },
      onSuccess: (response) {
        value.data.groupInfo = response;
        setStateSuccess();
        notifyListeners();
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }

  @override
  void onClose() {
    txtController.dispose();
  }

  // ================= Custom Notification Sound =================
  Future<void> _loadCustomNotificationSound() async {
    try {
      final title = await CustomNotificationSoundService.getDisplayName(roomId);
      value.data.customSoundTitle = title;
      update();
    } catch (_) {}
  }

  Future<void> pickCustomNotificationSound(BuildContext context) async {
    try {
      value.data.isUpdatingCustomSound = true;
      update();
      await CustomNotificationSoundService.pickAndSetForRoom(
        context,
        roomId,
        channelName: settingsModel.room.realTitle,
      );
      await _loadCustomNotificationSound();
    } finally {
      value.data.isUpdatingCustomSound = false;
      update();
    }
  }

  Future<void> resetCustomNotificationSound(BuildContext context) async {
    try {
      value.data.isUpdatingCustomSound = true;
      update();
      await CustomNotificationSoundService.clearForRoom(roomId);
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Notification sound reset to default',
      );
      await _loadCustomNotificationSound();
    } finally {
      value.data.isUpdatingCustomSound = false;
      update();
    }
  }

  void addParticipantsToGroup(BuildContext context) async {
    final users = await showCupertinoModalBottomSheet(
      expand: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SheetForAddMembersToGroup(
        groupId: roomId,
      ),
    ) as List<SBaseUser>?;

    if (users != null) {
      await _addGroupMembers(context, users.map((e) => e.id).toList());
      await getData();
    }
  }

  void onChangeGroupDescriptionClicked(BuildContext context) async {
    if (!canEditGroupInfo) return;
    final newTitle = await context.toPage(VSingleRename(
      appbarTitle: S.of(context).updateGroupDescription,
      oldValue: groupInfo!.groupSettings!.desc,
      subTitle: S.of(context).updateGroupDescriptionWillUpdateAllGroupMembers,
    )) as String?;
    if (newTitle == null || newTitle.toString().isEmpty) return;
    if (newTitle != settingsModel.title) {
      await vSafeApiCall<String>(
        request: () async {
          await VChatController.I.roomApi
              .updateGroupDescription(roomId: roomId, description: newTitle);
          return newTitle;
        },
        onSuccess: (response) {
          value.data.groupInfo = groupInfo!.copyWith(
            groupSettings: groupInfo!.groupSettings!.copyWith(desc: newTitle),
          );
          update();
        },
      );
    }
  }

  void toUpdateNickName(BuildContext context) async {
    final hasNickname = value.data.settingsModel.room.nickName != null &&
        value.data.settingsModel.room.nickName!.isNotEmpty;

    if (hasNickname) {
      final action = await showCupertinoModalPopup<String>(
        context: context,
        builder: (BuildContext ctx) => CupertinoActionSheet(
          title: Text(S.of(context).updateNickname),
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              child: Text(S.of(context).updateNickname),
              onPressed: () {
                Navigator.pop(ctx, 'edit');
              },
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: const Text('Reset to Default'),
              onPressed: () {
                Navigator.pop(ctx, 'reset');
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text(S.of(context).cancel),
            onPressed: () {
              Navigator.pop(ctx);
            },
          ),
        ),
      );

      if (action == null) return;

      if (action == 'reset') {
        await VChatController.I.nativeApi.remote.room
            .updateRoomNickName(roomId, "");
        await VChatController.I.nativeApi.local.room.updateNickName(
          VUpdateLocalRoomNickNameEvent(
            name: null,
            roomId: roomId,
          ),
        );
        value.data.settingsModel.room.nickName = null;
        update();
        return;
      }
    }

    final text = await context.toPage(VSingleRename(
      appbarTitle: S.of(context).updateNickname,
      oldValue: value.data.settingsModel.room.nickName ?? "",
      subTitle: "",
    )) as String?;

    if (text != null && text.isNotEmpty) {
      await VChatController.I.nativeApi.remote.room
          .updateRoomNickName(roomId, text);
      await VChatController.I.nativeApi.local.room.updateNickName(
        VUpdateLocalRoomNickNameEvent(
          name: text,
          roomId: roomId,
        ),
      );
      value.data.settingsModel.room.nickName = text;
      update();
    }
  }

  void updateMute(BuildContext context) {
    if (value.data.settingsModel.room.isMuted) {
      unMuteRoomNotification();
    } else {
      muteRoomNotification();
    }
  }

  void muteRoomNotification() async {
    await vSafeApiCall<void>(
      onLoading: () {
        value.data.isUpdatingMute = true;
        update();
      },
      request: () async {
        await VChatController.I.nativeApi.remote.room.muteRoomNotification(
          roomId: roomId,
        );
        await VChatController.I.nativeApi.local.room.updateRoomIsMuted(
          VUpdateRoomMuteEvent(
            roomId: roomId,
            isMuted: true,
          ),
        );
      },
      onSuccess: (response) {
        value.data.settingsModel.room.isMuted = true;
        update();
      },
    );
    value.data.isUpdatingMute = false;
    update();
  }

  void unMuteRoomNotification() async {
    await vSafeApiCall<void>(
      onLoading: () {
        value.data.isUpdatingMute = true;
        update();
      },
      request: () async {
        await VChatController.I.nativeApi.remote.room.unMuteRoomNotification(
          roomId: roomId,
        );
        await VChatController.I.nativeApi.local.room.updateRoomIsMuted(
          VUpdateRoomMuteEvent(
            roomId: roomId,
            isMuted: false,
          ),
        );
      },
      onSuccess: (response) {
        value.data.settingsModel.room.isMuted = false;
        update();
      },
    );
    value.data.isUpdatingMute = false;
    update();
  }

  void onGoShowMembers(BuildContext context) {
    context.toPage(GroupMembersView(
      roomId: roomId,
      myGroupInfo: groupInfo!,
      settingsModel: settingsModel,
    ));
  }

  Future _addGroupMembers(BuildContext context, List<String> list) async {
    await vSafeApiCall<void>(
      // onLoading: () {
      //   VAppAlert.showLoading(context: context, isDismissible: true);
      // },
      request: () async {
        await VChatController.I.roomApi.addParticipantsToGroup(roomId, list);
      },
      onSuccess: (response) {
        //Navigator.of(context).pop();
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: S.of(context).usersAddedSuccessfully,
        );
      },
      onError: (exception, trace) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: exception.toString(),
        );
      },
    );
  }

  void openFullImage(BuildContext context) {
    context.toPage(
      VImageViewer(
        showDownload: false,
        platformFileSource: VPlatformFile.fromUrl(
          networkUrl: settingsModel.image,
        ),
        downloadingLabel: S.of(context).downloading,
        successfullyDownloadedInLabel: S.of(context).successfullyDownloadedIn,
      ),
    );
  }

  void openStarredMessages(BuildContext context) {
    context.toPage(ChatStarMessagesPage(roomId: roomId));
  }

  void openChatMedia(BuildContext context) {
    context.toPage(ChatMediaView(roomId: roomId));
  }

  void openSearch(BuildContext context) {
    if (!sizer.isWide(context)) {
      context.pop("search");
    } else {
      chatInfoSearchStream.sink.add(true);
    }
  }

  Future<void> onAddToCommunity(BuildContext context) async {
    if (!isMeAdminOrSuper) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Admin permission required',
      );
      return;
    }
    final api = GetIt.I.get<CommunityApiService>();
    try {
      final list = await api.myCommunities();
      final comms = list
          .where((e) => e is Map)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (comms.isEmpty) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'You do not have any communities yet',
        );
        return;
      }

      final selected = await showCupertinoModalPopup<String>(
        context: context,
        builder: (_) => CupertinoActionSheet(
          title: const Text('Add to Community'),
          message: const Text('Choose a community'),
          actions: [
            for (final c in comms.take(20))
              CupertinoActionSheetAction(
                onPressed: () => Navigator.of(context).pop(c['_id'].toString()),
                child: Text(c['name']?.toString() ?? 'Unnamed'),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.of(context).cancel),
          ),
        ),
      );
      if (selected == null) return;

      await vSafeApiCall<String>(
        request: () async {
          return await api.attachExisting(selected, roomId);
        },
        onSuccess: (_) async {
          VAppAlert.showSuccessSnackBar(
            context: context,
            message: 'Added to community',
          );
          await getData();
        },
        onError: (e, s) {
          VAppAlert.showErrorSnackBar(context: context, message: e.toString());
        },
      );
    } catch (e) {
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  Future openEditTitle(BuildContext context) async {
    if (!canEditGroupInfo) return;
    final newTitle = await context.toPage(VSingleRename(
      appbarTitle: S.of(context).updateGroupTitle,
      oldValue: settingsModel.title,
      subTitle: '',
    )) as String?;
    if (newTitle == null || newTitle.toString().isEmpty) return;
    if (newTitle != settingsModel.title) {
      await vSafeApiCall<String>(
        request: () async {
          await VChatController.I.nativeApi.local.room.updateRoomName(
              VUpdateRoomNameEvent(roomId: roomId, name: newTitle));
          await VChatController.I.roomApi
              .updateGroupTitle(roomId: roomId, title: newTitle);
          return newTitle;
        },
        onSuccess: (response) {
          value.data.settingsModel.title = response;
          update();
          VAppAlert.showSuccessSnackBar(
              message: S.of(context).success, context: context);
        },
      );
    }
  }

  Future openEditImage(BuildContext context) async {
    if (!canEditGroupInfo) return;
    final image = await AppImageCropper.pickAndCrop(context);
    if (image == null) return;
    await vSafeApiCall<String>(
      request: () async {
        final url = await VChatController.I.roomApi.updateGroupImage(
          roomId: roomId,
          file: image,
        );
        await VChatController.I.nativeApi.local.room
            .updateRoomImage(VUpdateRoomImageEvent(roomId: roomId, image: url));
        return url;
      },
      onSuccess: (response) {
        value.data.settingsModel.image = response;

        VAppAlert.showSuccessSnackBar(
            message: S.of(context).success, context: context);
        update();
      },
      onError: (exception, trace) {
        VAppAlert.showErrorSnackBar(
            message: S.of(context).error, context: context);
      },
    );
  }

  Future<void> leaveGroup(BuildContext context) async {
    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: S.of(context).areYouSureToLeaveThisGroupThisActionCantUndo,
      content: S.of(context).leaveGroupAndDeleteYourMessageCopy,
    );
    if (res != 1) return;
    await vSafeApiCall(
      onLoading: () {
        value.data.isUpdatingExitGroup = true;
        update();
      },
      request: () async {
        return await VChatController.I.nativeApi.remote.room.leaveGroup(roomId);
      },
      onSuccess: (response) async {
        context.pop();
        context.pop();
      },
    );

    value.data.isUpdatingExitGroup = false;
    update();
  }

  Future<void> deleteGroup(BuildContext context) async {
    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: "Are you sure you want to delete this group?",
      content:
          "This action will permanently delete the group for all members and cannot be undone.",
    );
    if (res != 1) return;
    await vSafeApiCall(
      onLoading: () {
        value.data.isUpdatingDeleteGroup = true;
        update();
      },
      request: () async {
        return await VChatController.I.roomApi.deleteGroup(roomId: roomId);
      },
      onSuccess: (response) async {
        context.pop();
        context.pop();
      },
      onError: (exception, trace) {
        VAppAlert.showErrorSnackBar(message: exception, context: context);
      },
    );

    value.data.isUpdatingDeleteGroup = false;
    update();
  }

  void updateOneTimeSeen(BuildContext context) {
    if (value.data.settingsModel.room.isOneSeen) {
      oneSeenOff();
    } else {
      oneSeenOne();
    }
  }

  void oneSeenOne() async {
    await vSafeApiCall<void>(
      onLoading: () {
        value.data.isUpdatingOneSeen = true;
        update();
      },
      request: () async {
        await VChatController.I.nativeApi.remote.room.oneSeenOn(
          roomId: roomId,
        );
        await VChatController.I.nativeApi.local.room.updateRoomOneSeen(
          VUpdateRoomOneSeenEvent(
            roomId: roomId,
            isEnable: true,
          ),
        );
      },
      onSuccess: (response) {
        value.data.settingsModel.room.isOneSeen = true;
        update();
      },
    );
    value.data.isUpdatingOneSeen = false;
    update();
  }

  void oneSeenOff() async {
    await vSafeApiCall<void>(
      onLoading: () {
        value.data.isUpdatingOneSeen = true;
        update();
      },
      request: () async {
        await VChatController.I.nativeApi.remote.room.oneSeenOff(
          roomId: roomId,
        );
        await VChatController.I.nativeApi.local.room.updateRoomOneSeen(
          VUpdateRoomOneSeenEvent(
            roomId: roomId,
            isEnable: false,
          ),
        );
      },
      onSuccess: (response) {
        value.data.settingsModel.room.isOneSeen = false;
        update();
      },
    );
    value.data.isUpdatingOneSeen = false;
    update();
  }

  // ================= Chat Lock Methods =================
  void _loadLockStatus() {
    value.data.isLocked = ChatLockService.instance.isRoomLocked(roomId);
    update();
  }

  bool get isPasswordSet => ChatLockService.instance.isPasswordSet;

  Future<void> toggleChatLock(BuildContext context) async {
    if (value.data.isLocked) {
      await _unlockChat(context);
    } else {
      await _lockChat(context);
    }
  }

  Future<void> _lockChat(BuildContext context) async {
    // If no password is set, prompt to create one first
    if (!isPasswordSet) {
      final created = await _showSetPasswordDialog(context);
      if (created != true) return;
    }

    value.data.isUpdatingLock = true;
    update();

    await ChatLockService.instance.lockRoom(roomId);
    value.data.isLocked = true;
    value.data.isUpdatingLock = false;
    update();

    if (context.mounted) {
      VAppAlert.showSuccessSnackBar(context: context, message: 'Chat locked');
    }
  }

  Future<void> _unlockChat(BuildContext context) async {
    // Prompt for password verification
    final verified = await _showVerifyPasswordDialog(context);
    if (verified != true) return;

    value.data.isUpdatingLock = true;
    update();

    await ChatLockService.instance.unlockRoom(roomId);
    value.data.isLocked = false;
    value.data.isUpdatingLock = false;
    update();

    if (context.mounted) {
      VAppAlert.showSuccessSnackBar(context: context, message: 'Chat unlocked');
    }
  }

  Future<bool?> _showSetPasswordDialog(BuildContext context) async {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final res = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text('Set Chat Lock Password'),
          content: Column(
            children: [
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: newCtrl,
                placeholder: 'New password',
                obscureText: true,
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: confirmCtrl,
                placeholder: 'Confirm password',
                obscureText: true,
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                final p1 = newCtrl.text.trim();
                final p2 = confirmCtrl.text.trim();
                if (p1.length < 4) {
                  VAppAlert.showErrorSnackBar(
                    context: ctx,
                    message: 'Password must be at least 4 characters',
                  );
                  return;
                }
                if (p1 != p2) {
                  VAppAlert.showErrorSnackBar(
                    context: ctx,
                    message: 'Passwords do not match',
                  );
                  return;
                }
                await ChatLockService.instance.setPassword(p1);
                // ignore: use_build_context_synchronously
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    newCtrl.dispose();
    confirmCtrl.dispose();
    return res;
  }

  Future<bool?> _showVerifyPasswordDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final res = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text('Enter Chat Lock Password'),
          content: Column(
            children: [
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: ctrl,
                placeholder: 'Password',
                obscureText: true,
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                final ok = ChatLockService.instance.verifyPassword(ctrl.text.trim());
                if (!ok) {
                  VAppAlert.showErrorSnackBar(
                    context: ctx,
                    message: 'Incorrect password',
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Unlock'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return res;
  }
}
