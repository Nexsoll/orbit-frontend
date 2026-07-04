// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/modules/home/mobile/settings_tab/widgets/settings_list_item_tile.dart';
import 'package:super_up/app/modules/peer_profile/views/widgets/peer_profile_chat_row.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_platform/v_platform.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import '../controllers/peer_profile_controller.dart';
import 'follow_users_page.dart';
import 'user_music_gallery_view.dart';

class PeerProfileView extends StatefulWidget {
  final String peerId;

  const PeerProfileView({
    super.key,
    required this.peerId,
  });

  @override
  State<PeerProfileView> createState() => _PeerProfileViewState();
}

class _PeerProfileViewState extends State<PeerProfileView> {
  late final PeerProfileController controller;

  @override
  void initState() {
    super.initState();
    controller = PeerProfileController(widget.peerId);
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
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

  void _openFollowList({required bool isFollowersTab}) {
    final profile = controller.data;
    if (profile == null) return;

    final hiddenByPrivacy = isFollowersTab
        ? profile.userPrivacy.hideFollowers
        : profile.userPrivacy.hideFollowing;
    final canView = isFollowersTab
        ? profile.canViewFollowers
        : profile.canViewFollowing;
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
        userId: profile.searchUser.baseUser.id,
        isFollowersTab: isFollowersTab,
      ),
    );
  }

  void _openGallery() {
    final profile = controller.data;
    if (profile == null) return;

    if (!profile.canViewGallery) {
      _showPrivacyMessage('Follow first to view gallery.');
      return;
    }

    context.toPage(
      UserMusicGalleryView(
        userId: profile.searchUser.baseUser.id,
        userName: profile.searchUser.baseUser.fullName,
        userImage: profile.searchUser.baseUser.userImage,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        middle: Text(S.of(context).contactInfo),
      ),
      child: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, child) {
            return VAsyncWidgetsBuilder(
              loadingState: controller.loadingState,
              successWidget: () {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 40,
                        ),
                        GestureDetector(
                          onTap: () => controller.openFullImage(context),
                          child: VCircleAvatar(
                            vFileSource: VPlatformFile.fromUrl(
                              networkUrl: controller
                                  .data!.searchUser.baseUser.userImage,
                            ),
                            radius: 90,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        SUserNameWithBadge(
                          fullName: controller.data!.searchUser.baseUser.fullName,
                          isVerified: controller.data!.searchUser.hasBadge,
                          textStyle: context.cupertinoTextTheme.navLargeTitleTextStyle,
                          badgeSize: 20.0,
                        ),
                        if ((controller.data!.searchUser.profession ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              controller.data!.searchUser.profession!.trim(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: CupertinoColors.systemGrey.resolveFrom(context),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        const SizedBox(
                          height: 5,
                        ),
                        if (controller.data!.searchUser.phoneNumber != null &&
                            controller.data!.searchUser.phoneNumber!.isNotEmpty)
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  final number =
                                      controller.data!.searchUser.phoneNumber!;
                                  if (VPlatforms.isMobile) {
                                    VStringUtils.lunchLink("tel:$number");
                                  }
                                },
                                child: Text(
                                  controller.data!.searchUser.phoneNumber!,
                                  style: TextStyle(
                                    color: CupertinoColors.label.resolveFrom(context),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                            ],
                          ),
                        Text(
                          controller.data!.searchUser.bio ??
                              "${S.of(context).hiIamUse} ${SConstants.appName}",
                          maxLines: 3,
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _openFollowList(isFollowersTab: true),
                              child: Text(
                                '${controller.data!.followersCount} ${S.of(context).followersLabel}',
                                style: const TextStyle(
                                  color: CupertinoColors.systemGrey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _openFollowList(isFollowersTab: false),
                              child: Text(
                                '${controller.data!.followingCount} following',
                                style: const TextStyle(
                                  color: CupertinoColors.systemGrey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            onPressed: value.data!.getIsThereBan || controller.isFollowLoading
                                ? null
                                : () => controller.toggleFollow(context),
                            child: controller.isFollowLoading
                                ? const CupertinoActivityIndicator(
                                    color: CupertinoColors.white,
                                  )
                                : Text(
                                    controller.data!.isFollowing ? 'Unfollow' : S.of(context).follow,
                                  ),
                          ),
                        ),
                        const SizedBox(
                          height: 15,
                        ),
                        PeerProfileChatRow(
                          isLoading: controller.isLoading,
                          createGroupWith: () =>
                              controller.createGroupWith(context),
                          openChatWith: () => controller.openChatWith(context),
                          isMeBanner: controller.data!.isMeBanner,
                          isThereBan: value.data!.getIsThereBan,
                          updateBlock: () => controller.updateBlock(context),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        CupertinoListSection.insetGrouped(
                          hasLeading: false,
                          dividerMargin: 0,
                          topMargin: 0,
                          margin: const EdgeInsets.all(10),
                          children: [
                            CupertinoListTile.notched(
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: value.data!.isOnline
                                        ? Colors.green
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  Text(
                                    value.data!.isOnline
                                        ? S.of(context).online
                                        : S.of(context).offline,
                                    style: TextStyle(
                                        color: value.data!.isOnline
                                            ? Colors.green
                                            : Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                        CupertinoListSection.insetGrouped(
                          hasLeading: false,
                          margin: const EdgeInsets.all(10),
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
                              onTap: _openGallery,
                            ),
                          ],
                        ),
                        // Groups in common section (always visible) - custom styled to match scaffold background
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
                              if (controller.data!.mutualGroups.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    'No groups in common',
                                    style: TextStyle(color: CupertinoColors.systemGrey),
                                  ),
                                )
                              else
                                ...controller.data!.mutualGroups.map((group) {
                                  return Column(
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () async {
                                          try {
                                            final vRoom = await VChatController.I
                                                .nativeApi.remote.room
                                                .getRoomById(group.id);
                                            // ignore: use_build_context_synchronously
                                            VChatController.I.vNavigator.messageNavigator
                                                .toMessagePage(context, vRoom);
                                          } catch (e) {
                                            // ignore: use_build_context_synchronously
                                            VAppAlert.showErrorSnackBar(
                                              context: context,
                                              message: 'Failed to open group',
                                            );
                                          }
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
                                      // Divider
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
                          hasLeading: false,
                          margin: const EdgeInsets.all(10),
                          dividerMargin: 0,
                          topMargin: 0,
                          children: [
                            SettingsListItemTile(
                              color: Colors.red,
                              icon: CupertinoIcons.ant_circle_fill,
                              onTap: () {
                                controller.reportToAdmin(context);
                              },
                              title: S.of(context).reportUser,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              onRefresh: controller.getProfileData,
            );
          },
        ),
      ),
    );
  }
}
