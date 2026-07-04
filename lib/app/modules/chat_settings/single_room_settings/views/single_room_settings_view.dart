// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/modules/chat_settings/single_room_settings/states/single_room_setting_state.dart';
import 'package:super_up/app/modules/home/mobile/settings_tab/widgets/settings_list_item_tile.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:super_up_core/super_up_core.dart' as core;

import '../../widgets/chat_settings_list_section.dart';
import '../../widgets/chat_settings_navigation_bar.dart';
import '../controllers/single_room_settings_controller.dart';
import '../../encryption_verification/views/encryption_verification_view.dart';
import '../../advanced_chat_privacy/views/advanced_chat_privacy_view.dart';
import '../../../peer_profile/states/peer_profile_state.dart';
import '../../../peer_profile/views/follow_users_page.dart';
import '../../../peer_profile/views/user_music_gallery_view.dart';

class SingleRoomSettingsView extends StatefulWidget {
  const SingleRoomSettingsView({
    super.key,
    required this.settingsModel,
  });
  final VToChatSettingsModel settingsModel;

  @override
  State<SingleRoomSettingsView> createState() => _SingleRoomSettingsViewState();
}

class _SingleRoomSettingsViewState extends State<SingleRoomSettingsView> {
  late final SingleRoomSettingsController controller;

  @override
  void initState() {
    super.initState();
    controller = SingleRoomSettingsController(widget.settingsModel);
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  void _showEncryptionInfo(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text("End-to-End Encryption"),
          content: const Text(
            "Your chats and calls are secured with end-to-end encryption. Only you and the people you're chatting with can read or listen to them, and nobody else including Orbit Chat.",
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text("Verify Encryption"),
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToVerification(context);
              },
            ),
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToVerification(BuildContext context) {
    // Get current user ID from AppAuth and other user ID from room peerId
    final currentUserId = core.AppAuth.myProfile.baseUser.id;
    final otherUserId = widget.settingsModel.room.peerId!;
    final otherUserName = widget.settingsModel.room.title;
    
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => EncryptionVerificationView(
          currentUserId: currentUserId,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
        ),
      ),
    );
  }

  Future<void> _showPrivacyMessage(String message) {
    return showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Private'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openFollowList(PeerProfileModel user, {required bool isFollowersTab}) {
    final hiddenByPrivacy = isFollowersTab
        ? user.userPrivacy.hideFollowers
        : user.userPrivacy.hideFollowing;
    final canView = isFollowersTab
        ? user.canViewFollowers
        : user.canViewFollowing;
    final listName = isFollowersTab ? 'followers' : 'following';

    if (hiddenByPrivacy) {
      _showPrivacyMessage('This user has hidden their $listName list.');
      return;
    }

    if (!canView) {
      _showPrivacyMessage('Follow first to view $listName.');
      return;
    }

    context.toPage(
      FollowUsersPage(
        userId: user.searchUser.baseUser.id,
        isFollowersTab: isFollowersTab,
      ),
    );
  }

  void _openGallery(PeerProfileModel user) {
    if (!user.canViewGallery) {
      _showPrivacyMessage('Follow first to view gallery.');
      return;
    }

    context.toPage(
      UserMusicGalleryView(
        userId: user.searchUser.baseUser.id,
        userName: user.searchUser.baseUser.fullName,
        userImage: user.searchUser.baseUser.userImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: ChatSettingsNavigationBar(
        middle: S.of(context).contactInfo,
        previousPageTitle: S.of(context).back,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: ValueListenableBuilder<SLoadingState<SingleRoomSettingState>>(
            valueListenable: controller,
            builder: (context, value, child) {
              return Column(
                children: [
                  const SizedBox(
                    height: 40,
                  ),
                  GestureDetector(
                    onTap: () => controller.openFullImage(context),
                    child: VCircleAvatar(
                      vFileSource: VPlatformFile.fromUrl(
                        networkUrl: controller.data.settingsModel.image,
                      ),
                      radius: 90,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      final isVerified = value.data.user?.searchUser.hasBadge ?? false;
                      return SUserNameWithBadge(
                        fullName: value.data.settingsModel.room.realTitle,
                        isVerified: isVerified,
                        textStyle: context.cupertinoTextTheme.navLargeTitleTextStyle,
                        badgeSize: 20.0,
                      );
                    },
                  ),
                  // Display profession if available
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      final p = value.data.user?.searchUser.profession;
                      if (p != null && p.trim().isNotEmpty) {
                        return Column(
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              p.trim(),
                              style: context.cupertinoTextTheme.navTitleTextStyle.copyWith(
                                color: CupertinoColors.label.resolveFrom(context),
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  // Display phone number if available
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      if (value.data.user?.searchUser.phoneNumber != null &&
                          value.data.user!.searchUser.phoneNumber!.isNotEmpty) {
                        return Column(
                          children: [
                            const SizedBox(height: 5),
                            GestureDetector(
                              onTap: () {
                                final number =
                                    value.data.user!.searchUser.phoneNumber!;
                                if (VPlatforms.isMobile) {
                                  VStringUtils.lunchLink("tel:$number");
                                }
                              },
                              child: Text(
                                value.data.user!.searchUser.phoneNumber!,
                                style: TextStyle(
                                  color: CupertinoColors.label.resolveFrom(context),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      final user = value.data.user;
                      if (user == null) return const SizedBox.shrink();
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _openFollowList(
                                  user,
                                  isFollowersTab: true,
                                ),
                                child: Text(
                                  '${user.followersCount} ${S.of(context).followersLabel}',
                                  style: const TextStyle(
                                    color: CupertinoColors.systemGrey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _openFollowList(
                                  user,
                                  isFollowersTab: false,
                                ),
                                child: Text(
                                  '${user.followingCount} following',
                                  style: const TextStyle(
                                    color: CupertinoColors.systemGrey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              onPressed: user.getIsThereBan || value.data.isFollowLoading
                                  ? null
                                  : () => controller.toggleFollow(context),
                              child: value.data.isFollowLoading
                                  ? const CupertinoActivityIndicator(
                                      color: CupertinoColors.white,
                                    )
                                  : Text(
                                      user.isFollowing ? 'Unfollow' : S.of(context).follow,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          CupertinoListSection.insetGrouped(
                            backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                            hasLeading: false,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            dividerMargin: 0,
                            topMargin: 0,
                            children: [
                              CupertinoListTile.notched(
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0x1AB48648),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.music_note_2,
                                        color: Color(0xFFB48648),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Gallery',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 18,
                                      color: CupertinoColors.systemGrey3,
                                    ),
                                  ],
                                ),
                                onTap: () => _openGallery(user),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                        ],
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ChatSettingsListSection(
                        icon: CupertinoIcons.phone_fill,
                        title: S.of(context).audio,
                        iconSize: 24,
                        horizontalPadding: 14,
                        verticalPadding: 6,
                        titleFontSize: 13,
                        onPressed: !controller.isCallAllowed
                            ? null
                            : () {
                                controller.voiceCall(context);
                              },
                      ),
                      ChatSettingsListSection(
                        icon: CupertinoIcons.videocam_fill,
                        title: S.of(context).video,
                        iconSize: 24,
                        horizontalPadding: 14,
                        verticalPadding: 6,
                        titleFontSize: 13,
                        onPressed: !controller.isCallAllowed
                            ? null
                            : () {
                                controller.videoCall(context);
                              },
                      ),
                      ChatSettingsListSection(
                        icon: CupertinoIcons.search,
                        title: S.of(context).search,
                        iconSize: 24,
                        horizontalPadding: 14,
                        verticalPadding: 6,
                        titleFontSize: 13,
                        onPressed: () {
                          controller.openSearch(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        CupertinoListSection.insetGrouped(
                          backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                          hasLeading: false,
                          dividerMargin: 0,
                          topMargin: 0,
                          margin: const EdgeInsets.all(10),
                          children: [
                            ValueListenableBuilder(
                              valueListenable: controller,
                              builder: (context, value, child) {
                                if (value.data.user == null) {
                                  return const CupertinoListTile.notched(
                                    title: CupertinoActivityIndicator(),
                                  );
                                }
                                return CupertinoListTile.notched(
                                  title: Text(
                                    value.data.user!.searchUser.bio ??
                                        "${S.of(context).hiIamUse} ${SConstants.appName}",
                                  ),
                                );
                              },
                            )
                          ],
                        ),
                        CupertinoListSection.insetGrouped(
                          backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                          hasLeading: false,
                          margin: const EdgeInsets.all(10),
                          dividerMargin: 0,
                          topMargin: 0,
                          children: [
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              icon: CupertinoIcons.photo,
                              onTap: () {
                                controller.onShowMedia(context);
                              },
                              title: S.of(context).mediaLinksAndDocs,
                            ),
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              icon: CupertinoIcons.photo_on_rectangle,
                              onTap: () {
                                controller.onChangeChatWallpaper(context);
                              },
                              title: 'Change chat wallpaper',
                            ),
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              icon: CupertinoIcons.photo,
                              onTap: () {
                                controller.onChooseChatTheme(context);
                              },
                              title: 'Chat theme',
                            ),
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              icon: CupertinoIcons.paintbrush,
                              onTap: () {
                                controller.onChangeChatColor(context);
                              },
                              title: 'Change chat color',
                            ),
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              onTap: () {
                                controller.starMessage(context);
                              },
                              icon: CupertinoIcons.star_fill,
                              title: S.of(context).starredMessages,
                            ),
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              icon: CupertinoIcons.timer,
                              title: 'Disappearing messages',
                              isLoading: value.data.isUpdatingDisappearing,
                              onTap: () {
                                controller.openDisappearingPicker(context);
                              },
                              additionalInfo: Text(
                                (value.data.disappearingExpireSeconds == null ||
                                        (value.data.disappearingExpireSeconds ?? 0) <= 0)
                                    ? 'Off'
                                    : 'On',
                              ),
                            ),
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              icon: CupertinoIcons.lock_circle,
                              title: 'Advanced chat privacy',
                              onTap: () {
                                context.toPage(
                                  AdvancedChatPrivacyView(
                                    roomId: controller.roomId,
                                    initialEnabled: false,
                                  ),
                                );
                              },
                            ),
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              icon: CupertinoIcons.eye,
                              isLoading: value.data.isUpdatingOneSeen,
                              title: "One time seen",
                              onTap: () {
                                controller.updateOneTimeSeen(context);
                              },
                              additionalInfo:
                                  value.data.settingsModel.room.isOneSeen
                                      ? Text(S.of(context).yes)
                                      : Text(S.of(context).no),
                            ),
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              icon: CupertinoIcons.lock_shield,
                              title: "Encryption",
                              onTap: () {
                                _showEncryptionInfo(context);
                              },
                            ),
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              icon: value.data.isLocked ? CupertinoIcons.lock_open : CupertinoIcons.lock,
                              title: value.data.isLocked ? 'Unlock chat' : 'Lock chat',
                              isLoading: value.data.isUpdatingLock,
                              onTap: () {
                                controller.toggleChatLock(context);
                              },
                            ),
                          ],
                        ),
                        // Groups in common (above Block/Report) - custom painted to match scaffold background
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Groups in common',
                                style: TextStyle(
                                  color: CupertinoColors.systemGrey,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (!(value.data.user?.mutualGroups.isNotEmpty ?? false))
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    'No groups in common',
                                    style: TextStyle(color: CupertinoColors.systemGrey),
                                  ),
                                )
                              else
                                ...value.data.user!.mutualGroups.map((group) {
                                  return Column(
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () async {
                                          try {
                                            final vRoom = await VChatController.I
                                                .nativeApi.remote.room
                                                .getRoomById(group.id);
                                            // Close this page then open the selected group chat
                                            // ignore: use_build_context_synchronously
                                            Navigator.of(context).pop();
                                            await Future.delayed(const Duration(milliseconds: 10));
                                            // ignore: use_build_context_synchronously
                                            VChatController.I.vNavigator.messageNavigator
                                                .toMessagePage(context, vRoom);
                                          } catch (_) {}
                                        },
                                        child: Row(
                                          children: [
                                            (group.image != null && group.image!.isNotEmpty)
                                                ? VCircleAvatar(
                                                    vFileSource: VPlatformFile.fromUrl(
                                                      networkUrl: group.image!,
                                                    ),
                                                    radius: 20,
                                                  )
                                                : const CircleAvatar(
                                                    radius: 20,
                                                    backgroundColor: CupertinoColors.systemGrey5,
                                                    child: Icon(
                                                      CupertinoIcons.group,
                                                      size: 20,
                                                      color: CupertinoColors.systemGrey,
                                                    ),
                                                  ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                group.title,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              CupertinoIcons.chevron_right,
                                              size: 16,
                                              color: CupertinoColors.systemGrey3,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        height: 1,
                                        margin: const EdgeInsets.symmetric(vertical: 10),
                                        color: CupertinoColors.separator,
                                      ),
                                    ],
                                  );
                                }).toList(),
                            ],
                          ),
                        ),
                        CupertinoListSection.insetGrouped(
                          backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                          hasLeading: false,
                          margin: const EdgeInsets.all(10),
                          dividerMargin: 0,
                          topMargin: 0,
                          children: [
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              icon: CupertinoIcons.speaker_2,
                              title: S.of(context).mute,
                              isLoading: value.data.isUpdatingMute,
                              additionalInfo:
                                  value.data.settingsModel.room.isMuted
                                      ? Text(S.of(context).on)
                                      : Text(S.of(context).off),
                              onTap: () {
                                controller.updateMute(context);
                              },
                            ),
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              icon: CupertinoIcons.bell_solid,
                              title: 'Notification sound',
                              isLoading: value.data.isUpdatingCustomSound,
                              additionalInfo: Text(
                                (value.data.customSoundTitle == null || value.data.customSoundTitle!.isEmpty)
                                    ? 'Default'
                                    : value.data.customSoundTitle!,
                              ),
                              onTap: () async {
                                await showCupertinoModalPopup(
                                  context: context,
                                  builder: (_) => CupertinoActionSheet(
                                    title: const Text('Notification sound'),
                                    actions: [
                                      CupertinoActionSheetAction(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await controller.pickCustomNotificationSound(context);
                                        },
                                        child: const Text('Choose custom sound'),
                                      ),
                                      if ((value.data.customSoundTitle ?? '').isNotEmpty)
                                        CupertinoActionSheetAction(
                                          onPressed: () async {
                                            Navigator.of(context).pop();
                                            await controller.resetCustomNotificationSound(context);
                                          },
                                          isDestructiveAction: true,
                                          child: const Text('Reset to default'),
                                        ),
                                    ],
                                    cancelButton: CupertinoActionSheetAction(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: Text(S.of(context).cancel),
                                    ),
                                  ),
                                );
                              },
                            ),
                            SettingsListItemTile(
                              color: const Color(0xFFB48648),
                              icon: CupertinoIcons.person,
                              onTap: () {
                                controller.toUpdateNickName(context);
                              },
                              title: S.of(context).nickname,
                              additionalInfo:
                                  value.data.settingsModel.room.nickName == null
                                      ? Text(S.of(context).none)
                                      : Text(
                                          value.data.settingsModel.room
                                              .nickName!,
                                        ),
                            ),
                          ],
                        ),
                        CupertinoListSection.insetGrouped(
                          backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                          hasLeading: false,
                          margin: const EdgeInsets.all(10),
                          dividerMargin: 0,
                          topMargin: 0,
                          children: [
                            SettingsListItemTile(
                              color: Colors.red,
                              icon: CupertinoIcons.arrow_right_arrow_left,
                              isLoading: value.data.isUpdatingBlock,
                              onTap: () {
                                controller.onBlockUser(context);
                              },
                              textColor: Colors.red,
                              title: value.loadingState ==
                                      VChatLoadingState.success
                                  ? value.data.user!.isMeBanner
                                      ? S.of(context).unBlock
                                      : S.of(context).block
                                  : S.of(context).loading,
                            ),
                            SettingsListItemTile(
                              color: Colors.red,
                              icon: CupertinoIcons.ant_circle,
                              title: S.of(context).report,
                              textColor: Colors.red,
                              onTap: () {
                                controller.onReportUser(context);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
