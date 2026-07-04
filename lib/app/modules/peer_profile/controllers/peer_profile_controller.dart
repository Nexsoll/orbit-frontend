// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/core/api_service/api_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import '../../../core/widgets/custom_image_cropper.dart';

import '../../../core/app_config/app_config_controller.dart';
import '../../report/views/report_page.dart';
import '../mobile/sheet_for_create_group_from_profile.dart';
import '../states/peer_profile_state.dart';

class PeerProfileController extends SLoadingController<PeerProfileModel?> {
  final String peerId;
  final _profileApiService = GetIt.I<ProfileApiService>();

  PeerProfileController(this.peerId) : super(SLoadingState(null));

  @override
  void onClose() {}

  @override
  void onInit() {
    getProfileData();
    AdsBannerWidget.loadAd(
      VPlatforms.isAndroid
          ? SConstants.androidInterstitialId
          : SConstants.iosInterstitialId,
      enableAds: VAppConfigController.appConfig.enableAds,
    );
  }

  void toggleFollow(BuildContext context) {
    final current = value.data;
    if (current == null) return;

    vSafeApiCall(
      onLoading: () {
        isFollowLoading = true;
        notifyListeners();
      },
      request: () async {
        if (current.isFollowing) {
          await _profileApiService.unfollowUser(peerId);
        } else {
          await _profileApiService.followUser(peerId);
        }
      },
      onSuccess: (response) {
        isFollowLoading = false;

        final wasFollowing = current.isFollowing;
        final updatedFollowersCount = wasFollowing
            ? (current.followersCount - 1).clamp(0, 1 << 31)
            : current.followersCount + 1;
        final isFollowingNow = !wasFollowing;
        final followsOrPublic =
            current.userPrivacy.publicSearch || isFollowingNow;

        value.data = current.copyWith(
          isFollowing: isFollowingNow,
          canViewFollowers:
              followsOrPublic && !current.userPrivacy.hideFollowers,
          canViewFollowing:
              followsOrPublic && !current.userPrivacy.hideFollowing,
          canViewGallery: followsOrPublic,
          followersCount: updatedFollowersCount,
        );
        notifyListeners();
      },
      onError: (exception, trace) {
        isFollowLoading = false;
        notifyListeners();
        VAppAlert.showErrorSnackBar(
          context: context,
          message: exception.toString(),
        );
      },
    );
  }

  void getProfileData() async {
    await vSafeApiCall<PeerProfileModel>(
      onLoading: () {
        setStateLoading();
      },
      request: () async {
        return _profileApiService.peerProfile(peerId);
      },
      onSuccess: (response) async {
        print('PeerProfile API Response: ${response.toString()}');
        print('Mutual Groups Count: ${response.mutualGroups.length}');
        for (var group in response.mutualGroups) {
          print('Group: ${group.title} (${group.id})');
        }
        value.data = response;
        setStateSuccess();
      },
      onError: (exception, trace) {
        setStateError();
      },
    );
  }

  void openFullImage(BuildContext context) {
    context.toPage(
      VImageViewer(
        showDownload: false,
        platformFileSource:
            VPlatformFile.fromUrl(networkUrl: data!.searchUser.baseUser.userImage),
        downloadingLabel: S.of(context).downloading,
        successfullyDownloadedInLabel: S.of(context).successfullyDownloadedIn,
      ),
    );
  }

  bool isOpeningChat = false;
  bool isBlockingChat = false;
  bool isFollowLoading = false;

  bool get isLoading => isOpeningChat || isBlockingChat;

  void openChatWith(BuildContext context) async {
    vSafeApiCall(
      onLoading: () {
        isOpeningChat = true;
        notifyListeners();
      },
      request: () async {
        await VChatController.I.roomApi.openChatWith(
          peerId: peerId,
        );
      },
      onSuccess: (response) {
        isOpeningChat = false;
        notifyListeners();
      },
      onError: (exception, trace) {
        isOpeningChat = false;
        notifyListeners();
      },
    );
  }

  Future<int?> _showBlockDialog(BuildContext context) async {
    if (value.data!.isMeBanner) {
      return 1;
    }
    final res = await VAppAlert.showAskYesNoDialog(
      title: S.of(context).areYouSure,
      content: S.of(context).aboutToBlockUserWithConsequences,
      context: context,
    );
    return res;
  }

  void updateBlock(BuildContext context) async {
    final res = await _showBlockDialog(context);

    if (res != 1) return;
    vSafeApiCall(
      onLoading: () {
        isBlockingChat = true;
        notifyListeners();
      },
      request: () async {
        if (data!.isMeBanner) {
          await VChatController.I.blockApi.unBlockUser(peerId: peerId);
          value.data = value.data!.copyWith(isMeBanner: false);
          notifyListeners();
        } else {
          await VChatController.I.blockApi.blockUser(peerId: peerId);
          value.data = value.data!.copyWith(isMeBanner: true);
          notifyListeners();
        }
      },
      onSuccess: (response) {
        isBlockingChat = false;
        notifyListeners();
      },
      onError: (exception, trace) {
        isBlockingChat = false;
        notifyListeners();
      },
    );
  }

  void reportToAdmin(BuildContext context) async {
    context.toPage(ReportPage(userId: value.data!.searchUser.baseUser.id));
  }

  Future<void> shareProfileToChat(BuildContext context) async {
    final profile = value.data?.searchUser;
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

  // ================= Chat Wallpaper Management =================
  String get _peerKey => 'chat_wallpaper_b64_peer_${peerId}';

  Future<String?> _getRoomIdByPeer() async {
    try {
      final room = await VChatController.I.nativeApi.local.room.getRoomByPeerId(peerId);
      return room?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> onChangeChatWallpaper(BuildContext context) async {
    final prefs = VChatController.I.sharedPreferences;
    final hasCurrent = (prefs.getString(_peerKey) ?? '').isNotEmpty;

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
              if (hasCurrent)
                CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () async {
                    Navigator.pop(context);
                    await _removeWallpaper(context);
                  },
                  child: const Text('Remove wallpaper'),
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
    await prefs.setString(_peerKey, b64);
    final roomId = await _getRoomIdByPeer();
    if (roomId != null) {
      await prefs.setString('chat_wallpaper_b64_room_$roomId', b64);
      // Notify chat UI to refresh instantly if it's open behind
      VEventBusSingleton.vEventBus
          .fire(VUpdateRoomWallpaperEvent(roomId: roomId));
    }

    VAppAlert.showSuccessSnackBar(message: 'Wallpaper updated for this chat', context: context);
  }

  Future<void> _removeWallpaper(BuildContext context) async {
    final prefs = VChatController.I.sharedPreferences;
    await prefs.remove(_peerKey);
    final roomId = await _getRoomIdByPeer();
    if (roomId != null) {
      await prefs.remove('chat_wallpaper_b64_room_$roomId');
      // Notify chat UI to refresh instantly if it's open behind
      VEventBusSingleton.vEventBus
          .fire(VUpdateRoomWallpaperEvent(roomId: roomId));
    }
    VAppAlert.showSuccessSnackBar(message: 'Chat wallpaper removed', context: context);
  }

  Future<void> _viewCurrentWallpaper(BuildContext context) async {
    final prefs = VChatController.I.sharedPreferences;
    String? b64 = prefs.getString(_peerKey);
    final rid = await _getRoomIdByPeer();
    if (b64 == null || b64.isEmpty) {
      if (rid != null) {
        b64 = prefs.getString('chat_wallpaper_b64_room_$rid');
      }
    }
    if (b64 == null || b64.isEmpty) {
      VAppAlert.showErrorSnackBar(message: 'No wallpaper set', context: context);
      return;
    }
    try {
      final bytes = base64Decode(b64);
      // View via image viewer
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

  void createGroupWith(BuildContext context) async {
    final groupRoom = await showCupertinoModalBottomSheet(
      expand: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SheetForCreateGroupFromProfile(
        peer: data!.searchUser.baseUser,
      ),
    ) as VRoom?;
    if (groupRoom == null) {
      return;
    }
    VChatController.I.vNavigator.messageNavigator
        .toMessagePage(context, groupRoom);
  }

  final adUnitId = VPlatforms.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';
}
