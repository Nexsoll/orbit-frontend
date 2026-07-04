// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:get_it/get_it.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/core/api_service/api_service.dart';
import 'package:super_up/app/modules/chat_settings/chat_star_messages/views/chat_star_messages_page.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import '../../../../core/widgets/custom_image_cropper.dart';
import '../../chat_color_picker/views/chat_color_picker_page.dart';

import '../../../../core/app_config/app_config_controller.dart';
import '../../../peer_profile/states/peer_profile_state.dart';
import '../../../report/views/report_page.dart';
import '../../chat_media_docs_voice/views/chat_media_view.dart';
import '../states/single_room_setting_state.dart';
import '../../../../core/services/custom_notification_sound_service.dart';
import '../../chat_theme_picker/views/chat_theme_picker_page.dart';
import '../../../../core/services/chat_lock_service.dart';

class SingleRoomSettingsController
    extends SLoadingController<SingleRoomSettingState> {
  final VToChatSettingsModel _settingsModel;
  final sizer = GetIt.I.get<AppSizeHelper>();

  SingleRoomSettingsController(this._settingsModel)
      : super(SLoadingState(SingleRoomSettingState(_settingsModel)));
  final _profileApiService = GetIt.I.get<ProfileApiService>();

  String get roomId => _settingsModel.roomId;

  bool get isCallAllowed => VAppConfigController.appConfig.allowCall;

  @override
  void onInit() {
    getData();
    _loadLockStatus();
    AdsBannerWidget.loadAd(
      VPlatforms.isAndroid
          ? SConstants.androidInterstitialId
          : SConstants.iosInterstitialId,
      enableAds: VAppConfigController.appConfig.enableAds,
    );
    // Ensure default wallpaper after removing the UI entry.
    _resetWallpaperToDefaultIfSet();
    _loadDisappearingTimer();
    _loadCustomNotificationSound();
  }

  Future<void> _setDefaultWallpaper(BuildContext context) async {
    final prefs = VChatController.I.sharedPreferences;
    await prefs.remove(_roomKey);
    await prefs.remove(_peerKey);
    // Inform chat UI
    VEventBusSingleton.vEventBus
        .fire(VUpdateRoomWallpaperEvent(roomId: roomId));
    VAppAlert.showSuccessSnackBar(
      message: 'Default wallpaper applied',
      context: context,
    );
    update();
  }

  Future<void> _resetWallpaperToDefaultIfSet() async {
    final prefs = VChatController.I.sharedPreferences;
    final hasRoom = (prefs.getString(_roomKey) ?? '').isNotEmpty;
    final hasPeer = (prefs.getString(_peerKey) ?? '').isNotEmpty;
    if (hasRoom || hasPeer) {
      await prefs.remove(_roomKey);
      await prefs.remove(_peerKey);
      VEventBusSingleton.vEventBus
          .fire(VUpdateRoomWallpaperEvent(roomId: roomId));
    }
  }

  // ================= Chat Wallpaper Management =================
  String get _roomKey => 'chat_wallpaper_b64_room_${roomId}';
  String get _peerKey => 'chat_wallpaper_b64_peer_${_settingsModel.room.peerId}';

  Future<void> onChangeChatWallpaper(BuildContext context) async {
    final prefs = VChatController.I.sharedPreferences;
    final hasCurrent = (prefs.getString(_roomKey) ?? prefs.getString(_peerKey) ?? '').isNotEmpty;

    await showCupertinoModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: CupertinoActionSheet(
            title: const Text('Chat wallpaper'),
            actions: [
              if (hasCurrent)
                CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _viewCurrentWallpaper(context);
                  },
                  child: const Text('View current wallpaper'),
                ),
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(context);
                  await _pickAndSetWallpaper(context);
                },
                child: Text(hasCurrent ? 'Replace wallpaper' : 'Choose wallpaper'),
              ),
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(context);
                  await _setDefaultWallpaper(context);
                },
                child: const Text('Use default wallpaper'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).cancel),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndSetWallpaper(BuildContext context) async {
    final picked = await AppImageCropper.pickAndCrop(context);
    if (picked == null) return;
    List<int>? bytes;
    if (picked.bytes != null) {
      bytes = picked.bytes!;
    } else if (picked.fileLocalPath != null) {
      bytes = await File(picked.fileLocalPath!).readAsBytes();
    }
    if (bytes == null) return;
    final b64 = base64Encode(bytes);

    final prefs = VChatController.I.sharedPreferences;
    await prefs.setString(_roomKey, b64);
    if (_settingsModel.room.peerId != null) {
      await prefs.setString(_peerKey, b64);
    }

    VAppAlert.showSuccessSnackBar(message: 'Wallpaper updated for this chat', context: context);
    // Notify chat UI to refresh instantly
    VEventBusSingleton.vEventBus
        .fire(VUpdateRoomWallpaperEvent(roomId: roomId));
    update();
  }


  Future<void> _viewCurrentWallpaper(BuildContext context) async {
    final prefs = VChatController.I.sharedPreferences;
    String? b64 = prefs.getString(_roomKey);
    b64 ??= prefs.getString(_peerKey);
    if (b64 == null || b64.isEmpty) {
      VAppAlert.showErrorSnackBar(message: 'No wallpaper set', context: context);
      return;
    }
    try {
      final bytes = base64Decode(b64);
      // ignore: use_build_context_synchronously
      context.toPage(
        VImageViewer(
          showDownload: false,
          platformFileSource: VPlatformFile.fromBytes(name: 'wallpaper.jpg', bytes: bytes),
          downloadingLabel: S.of(context).downloading,
          successfullyDownloadedInLabel: S.of(context).successfullyDownloadedIn,
        ),
      );
    } catch (e) {
      VAppAlert.showErrorSnackBar(message: 'Failed to open wallpaper', context: context);
    }
  }

  // ================= Chat Color Management =================
  Future<void> onChangeChatColor(BuildContext context) async {
    final currentColor = ChatColorService.I.getColorForRoom(
      roomId,
      _settingsModel.room.peerId,
    );

    await context.toPage(
      ChatColorPickerPage(
        roomId: roomId,
        peerId: _settingsModel.room.peerId,
        currentColor: currentColor,
      ),
    );
    update();
  }

  // ================= Chat Theme (Prebuilt wallpapers) =================
  Future<void> onChooseChatTheme(BuildContext context) async {
    await context.toPage(
      ChatThemePickerPage(
        roomId: roomId,
        peerId: _settingsModel.room.peerId,
      ),
    );
    // page will fire VUpdateRoomWallpaperEvent; still trigger UI refresh here
    update();
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

  Future<void> getData() async {
    await vSafeApiCall<PeerProfileModel>(
      request: () async {
        return _profileApiService.peerProfile(_settingsModel.room.peerId!);
      },
      onSuccess: (response) {
        value.data.user = response;
        setStateSuccess();
        notifyListeners();
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }

  void toggleFollow(BuildContext context) {
    final user = value.data.user;
    final peerId = _settingsModel.room.peerId;
    if (user == null || peerId == null) return;

    vSafeApiCall(
      onLoading: () {
        value.data.isFollowLoading = true;
        update();
      },
      request: () async {
        if (user.isFollowing) {
          await _profileApiService.unfollowUser(peerId);
        } else {
          await _profileApiService.followUser(peerId);
        }
      },
      onSuccess: (_) {
        value.data.isFollowLoading = false;

        final wasFollowing = user.isFollowing;
        final updatedFollowersCount = wasFollowing
            ? (user.followersCount - 1).clamp(0, 1 << 31)
            : user.followersCount + 1;
        final isFollowingNow = !wasFollowing;
        final followsOrPublic =
            user.userPrivacy.publicSearch || isFollowingNow;

        value.data.user = user.copyWith(
          isFollowing: isFollowingNow,
          canViewFollowers:
              followsOrPublic && !user.userPrivacy.hideFollowers,
          canViewFollowing:
              followsOrPublic && !user.userPrivacy.hideFollowing,
          canViewGallery: followsOrPublic,
          followersCount: updatedFollowersCount,
        );
        update();
      },
      onError: (exception, trace) {
        value.data.isFollowLoading = false;
        update();
        VAppAlert.showErrorSnackBar(
          context: context,
          message: exception.toString(),
        );
      },
    );
  }

  Future<void> _loadDisappearingTimer() async {
    try {
      final res = await VChatController.I.nativeApi.remote.room
          .getDisappearingTimer(roomId);
      final sec = res['expireSeconds'];
      value.data.disappearingExpireSeconds =
          sec == null ? null : (sec as num).toInt();
      update();
    } catch (_) {}
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
        channelName: value.data.settingsModel.room.realTitle,
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

  String _formatSeconds(int seconds) {
    if (seconds <= 0) return 'Off';
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (days > 0 && hours == 0 && mins == 0) return '$days day${days == 1 ? '' : 's'}';
    if (hours > 0 && days == 0 && mins == 0) return '$hours hour${hours == 1 ? '' : 's'}';
    if (mins > 0 && days == 0 && hours == 0) return '$mins min';
    final parts = <String>[];
    if (days > 0) parts.add('$days d');
    if (hours > 0) parts.add('$hours h');
    if (mins > 0) parts.add('$mins m');
    return parts.join(' ');
  }

  Future<void> setDisappearingSeconds(BuildContext context, int? seconds) async {
    await vSafeApiCall<void>(
      onLoading: () {
        value.data.isUpdatingDisappearing = true;
        update();
      },
      request: () async {
        await VChatController.I.nativeApi.remote.room
            .setDisappearingTimer(roomId: roomId, expireSeconds: seconds);
      },
      onSuccess: (_) {
        value.data.disappearingExpireSeconds = seconds;
        VAppAlert.showSuccessSnackBar(
          message: seconds == null || seconds <= 0
              ? 'Disappearing messages turned off'
              : 'Timer set to ${_formatSeconds(seconds)}',
          context: context,
        );
        update();
      },
    );
    value.data.isUpdatingDisappearing = false;
    update();
  }

  Future<void> openDisappearingPicker(BuildContext context) async {
    await showCupertinoModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: CupertinoActionSheet(
            title: const Text('Disappearing messages'),
            message: const Text('Make new messages disappear after a set time'),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  setDisappearingSeconds(context, null);
                },
                child: const Text('Off'),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  setDisappearingSeconds(context, 24 * 3600);
                },
                child: const Text('24 Hours'),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  setDisappearingSeconds(context, 7 * 24 * 3600);
                },
                child: const Text('7 Days'),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  setDisappearingSeconds(context, 90 * 24 * 3600);
                },
                child: const Text('90 Days'),
              ),
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(context);
                  final seconds = await _askCustomTimer(context);
                  if (seconds != null) {
                    await setDisappearingSeconds(context, seconds);
                  }
                },
                child: const Text('Custom...'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).cancel),
            ),
          ),
        );
      },
    );
  }

  Future<int?> _askCustomTimer(BuildContext context) async {
    final daysCtl = TextEditingController();
    final hoursCtl = TextEditingController();
    final minsCtl = TextEditingController();
    int? result;
    await showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Custom timer'),
        content: Column(
          children: [
            const SizedBox(height: 6),
            CupertinoTextField(
              controller: daysCtl,
              placeholder: 'Days',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 6),
            CupertinoTextField(
              controller: hoursCtl,
              placeholder: 'Hours',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 6),
            CupertinoTextField(
              controller: minsCtl,
              placeholder: 'Minutes',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).cancel),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final d = int.tryParse(daysCtl.text.trim()) ?? 0;
              final h = int.tryParse(hoursCtl.text.trim()) ?? 0;
              final m = int.tryParse(minsCtl.text.trim()) ?? 0;
              final seconds = (d.clamp(0, 100000) * 86400) +
                  (h.clamp(0, 100000) * 3600) +
                  (m.clamp(0, 100000) * 60);
              result = seconds > 0 ? seconds : null;
              Navigator.pop(context);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
    return result;
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

  @override
  void onClose() {}

  void openFullImage(BuildContext context) {
    context.toPage(VImageViewer(
      showDownload: false,
      platformFileSource:
          VPlatformFile.fromUrl(networkUrl: value.data.settingsModel.image),
      downloadingLabel: S.of(context).downloading,
      successfullyDownloadedInLabel: S.of(context).done,
    ));
  }

  void starMessage(BuildContext context) {
    context.toPage(ChatStarMessagesPage(roomId: roomId));
  }

  void onShowMedia(BuildContext context) {
    context.toPage(ChatMediaView(roomId: roomId));
  }

  Future<void> shareProfileToChat(BuildContext context) async {
    final profile = value.data.user?.searchUser;
    if (profile == null) return;

    try {
      final roomsIds = await VChatController.I.vNavigator.roomNavigator
          .toForwardPage(context, null);
      if (roomsIds == null || roomsIds.isEmpty) return;

      final baseUser = profile.baseUser;
      final payload = <String, dynamic>{
        'type': 'profile_share',
        'userId': baseUser.id,
        '_id': baseUser.id,
        'fullName': baseUser.fullName,
        'userImage': baseUser.userImage,
        'bio': profile.bio,
        'phoneNumber': profile.phoneNumber,
        'hasBadge': profile.hasBadge,
      };

      final previewText = 'Shared profile: ${baseUser.fullName}';

      VAppAlert.showLoading(context: context);
      try {
        for (final roomId in roomsIds) {
          final message = VCustomMessage.buildMessage(
            roomId: roomId,
            content: previewText,
            data: VCustomMsgData(data: payload),
          );
          await VChatController.I.nativeApi.local.message.insertMessage(message);
          try {
            VMessageUploaderQueue.instance.addToQueue(
              await MessageFactory.createUploadMessage(message),
            );
          } catch (_) {
            // message remains local only
          }
        }
        if (!context.mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Shared to chat',
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    } catch (e) {
      if (context.mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future onBlockUser(BuildContext context) async {
    if (value.data.user!.isMeBanner) {
      return await _onUnBlock(context);
    }
    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: S.of(context).blockUser,
      content:
          "${S.of(context).areYouSureToBlock} ${value.data.settingsModel.title}",
    );
    if (res == 1) {
      await vSafeApiCall(
        onLoading: () {
          value.data.isUpdatingBlock = true;
          update();
        },
        request: () async {
          await VChatController.I.blockApi.blockUser(
            peerId: _settingsModel.room.peerId!,
          );
        },
        onSuccess: (response) {
          getData();
        },
      );
      value.data.isUpdatingBlock = false;
      update();
    }
  }

  void onReportUser(BuildContext context) async {
    context.toPage(ReportPage(userId: _settingsModel.room.peerId!));
  }

  void openSearch(BuildContext context) {
    if (!sizer.isWide(context)) {
      context.pop("search");
    } else {
      chatInfoSearchStream.sink.add(false);
    }
  }

  void clearChat(BuildContext context) async {}

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

  void voiceCall(BuildContext context) async {
    await VChatController.I.vNavigator.callNavigator.toCall(
      context,
      VCallDto(
        isVideoEnable: false,
        isCaller: true,
        roomId: roomId,
        peerUser: SBaseUser(
            userImage: _settingsModel.room.thumbImage,
            fullName: _settingsModel.room.realTitle,
            id: _settingsModel.room.peerId!),
      ),
    );
  }

  void videoCall(BuildContext context) async {
    await VChatController.I.vNavigator.callNavigator.toCall(
      context,
      VCallDto(
        isVideoEnable: true,
        isCaller: true,
        roomId: roomId,
        peerUser: SBaseUser(
            userImage: _settingsModel.room.thumbImage,
            fullName: _settingsModel.room.realTitle,
            id: _settingsModel.room.peerId!),
      ),
    );
  }

  Future _onUnBlock(BuildContext context) async {
    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: S.of(context).unBlockUser,
      content:
          "${S.of(context).areYouSureToUnBlock} ${value.data.settingsModel.title}",
    );
    if (res == 1) {
      await vSafeApiCall(
        onLoading: () {
          value.data.isUpdatingBlock = true;
          update();
        },
        request: () async {
          await VChatController.I.blockApi.unBlockUser(
            peerId: _settingsModel.room.peerId!,
          );
        },
        onSuccess: (response) {
          getData();
        },
      );
      value.data.isUpdatingBlock = false;
      update();
    }
  }
}
