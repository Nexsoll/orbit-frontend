// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/modules/home/mobile/settings_tab/widgets/settings_list_item_tile.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import 'package:v_platform/v_platform.dart';

import '../../../../core/app_config/app_config_controller.dart';
import '../../widgets/chat_settings_navigation_bar.dart';
import '../controllers/group_room_settings_controller.dart';
import '../states/group_room_setting_state.dart';

class GroupRoomSettingsView extends StatefulWidget {
  final VToChatSettingsModel settingsModel;

  const GroupRoomSettingsView({super.key, required this.settingsModel});

  @override
  State<GroupRoomSettingsView> createState() => _GroupRoomSettingsViewState();
}

class _GroupRoomSettingsViewState extends State<GroupRoomSettingsView> {
  late final GroupRoomSettingsController controller;

  @override
  void initState() {
    super.initState();
    controller = GroupRoomSettingsController(widget.settingsModel);
    controller.onInit();
    AdsBannerWidget.loadAd(
      VPlatforms.isAndroid
          ? SConstants.androidInterstitialId
          : SConstants.iosInterstitialId,
      enableAds: VAppConfigController.appConfig.enableAds,
    );
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: ChatSettingsNavigationBar(
        middle: S.of(context).groupInfo,
        previousPageTitle: S.of(context).back,
        middleWidget:
            ValueListenableBuilder<SLoadingState<GroupRoomSettingState>>(
          valueListenable: controller,
          builder: (context, value, child) {
            final isChannel = controller.groupInfo?.groupSettings?.extraData !=
                    null &&
                (controller.groupInfo!.groupSettings!.extraData!['isChannel'] ==
                    true);
            return Text(isChannel
                ? 'Channel info'
                : S.of(context).groupInfo);
          },
        ),
      ),
      child: SafeArea(
        child: ValueListenableBuilder<SLoadingState<GroupRoomSettingState>>(
          valueListenable: controller,
          builder: (context, value, child) => SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(
                  height: 40,
                ),
                GestureDetector(
                  onTap: () => controller.openFullImage(context),
                  child: ValueListenableBuilder<
                      SLoadingState<GroupRoomSettingState>>(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      if (value.loadingState != VChatLoadingState.success) {
                        return VCircleAvatar(
                          vFileSource: VPlatformFile.fromUrl(
                            networkUrl: controller.settingsModel.image,
                          ),
                          radius: 90,
                        );
                      }
                      if (controller.groupInfo!.isMeOut) {
                        return VCircleAvatar(
                          vFileSource: VPlatformFile.fromUrl(
                            networkUrl: controller.settingsModel.image,
                          ),
                          radius: 90,
                        );
                      }
                      return Stack(
                        children: [
                          VCircleAvatar(
                            vFileSource: VPlatformFile.fromUrl(
                              networkUrl: controller.settingsModel.image,
                            ),
                            radius: 90,
                          ),
                          if (controller.canEditGroupInfo)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => controller.openEditImage(context),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: context.isDark
                                        ? Colors.brown
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.camera,
                                    color: Colors.green,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    if (value.loadingState != VChatLoadingState.success) {
                      return Text(
                        controller.settingsModel.room.title,
                        style:
                            context.cupertinoTextTheme.navLargeTitleTextStyle,
                      );
                    }
                    if (controller.groupInfo!.isMeOut) {
                      return Text(
                        controller.settingsModel.room.title,
                        style:
                            context.cupertinoTextTheme.navLargeTitleTextStyle,
                      );
                    }
                    final canEdit = controller.canEditGroupInfo;
                    final title = Text(
                      controller.settingsModel.room.title,
                      style: context.cupertinoTextTheme.navLargeTitleTextStyle,
                    );
                    if (!canEdit) return title;
                    return GestureDetector(
                      onTap: () => controller.openEditTitle(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          title,
                          const SizedBox(
                            width: 5,
                          ),
                          const Icon(
                            Icons.edit,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(
                  height: 15,
                ),
                ValueListenableBuilder<SLoadingState<GroupRoomSettingState>>(
                  valueListenable: controller,
                  builder: (_, value, __) {
                    return VAsyncWidgetsBuilder(
                      loadingState: value.loadingState,
                      onRefresh: controller.getData,
                      successWidget: () {
                        final isMeAdminOrSuper = controller.isMeAdminOrSuper;
                        final isChannel = (value.data.groupInfo?.groupSettings?.extraData != null &&
                            value.data.groupInfo!.groupSettings!.extraData!['isChannel'] == true);
                        if (value.data.groupInfo!.isMeOut) {
                          return ChatSettingsTileInfo(
                            title: Text(
                              S.of(context).youNotParticipantInThisGroup,
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: controller.canEditGroupInfo
                                    ? () => controller
                                        .onChangeGroupDescriptionClicked(
                                            context)
                                    : null,
                                behavior: HitTestBehavior.opaque,
                                child: _getGroupBio(
                                  context,
                                  controller.getGroupDesc,
                                  (controller.groupInfo?.groupSettings?.extraData !=
                                              null &&
                                          controller
                                                  .groupInfo!
                                                  .groupSettings!
                                                  .extraData!['isChannel'] ==
                                              true)
                                      ? true
                                      : false,
                                  controller.canEditGroupInfo,
                                ),
                              ),
                              CupertinoListSection.insetGrouped(
                                hasLeading: false,
                                margin: const EdgeInsets.all(10),
                                dividerMargin: 0,
                                topMargin: 0,
                                children: [
                                  SettingsListItemTile(
                                    color: Colors.lightGreen,
                                    icon: CupertinoIcons.search,
                                    title: S.of(context).search,
                                    onTap: () {
                                      controller.openSearch(context);
                                    },
                                  ),
                                  // Share group/channel link (all members)
                                  SettingsListItemTile(
                                    color: Colors.teal,
                                    icon: CupertinoIcons.link,
                                    title: isChannel ? 'Share channel link' : 'Share invite link',
                                    onTap: () => controller.shareInviteLink(context),
                                  ),
                                  SettingsListItemTile(
                                    color: Colors.cyan,
                                    icon: CupertinoIcons.person_2,
                                    title: S.of(context).members,
                                    onTap: () {
                                      controller.onGoShowMembers(context);
                                    },
                                    additionalInfo: Text(controller
                                        .groupInfo!.membersCount
                                        .toString()),
                                  ),
                                  SettingsListItemTile(
                                    color: Colors.green,
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
                                  if (isMeAdminOrSuper && !isChannel)
                                    SettingsListItemTile(
                                      color: Colors.indigo,
                                      icon: CupertinoIcons.checkmark_seal,
                                      title: 'Who can send messages',
                                      additionalInfo: Builder(
                                        builder: (_) {
                                          final extra = controller.groupInfo?.groupSettings?.extraData;
                                          final adminsOnly = extra != null && extra['sendPolicy'] == 'admins';
                                          return Text(adminsOnly ? 'Only admins' : 'Everyone');
                                        },
                                      ),
                                      onTap: () {
                                        showCupertinoModalPopup(
                                          context: context,
                                          builder: (_) => CupertinoActionSheet(
                                            title: const Text('Who can send messages'),
                                            actions: [
                                              CupertinoActionSheetAction(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  controller.updateSendPolicyAdminsOnly(context, false);
                                                },
                                                child: const Text('Everyone'),
                                              ),
                                              CupertinoActionSheetAction(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  controller.updateSendPolicyAdminsOnly(context, true);
                                                },
                                                child: const Text('Only admins'),
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
                                  if (isMeAdminOrSuper && !isChannel)
                                    SettingsListItemTile(
                                      color: Colors.green,
                                      onTap: () {
                                        controller
                                            .addParticipantsToGroup(context);
                                      },
                                      icon: CupertinoIcons.add,
                                      title: S.of(context).addMembers,
                                    ),
                                  if (isMeAdminOrSuper)
                                    SettingsListItemTile(
                                      color: Colors.redAccent,
                                      icon: CupertinoIcons.refresh,
                                      title: 'Reset invite link',
                                      onTap: () => controller.resetInviteLink(context),
                                    ),
                                  if (isMeAdminOrSuper)
                                    SettingsListItemTile(
                                      color: Colors.purple,
                                      icon: CupertinoIcons.person_3,
                                      title: 'Add to Community',
                                      onTap: () => controller.onAddToCommunity(context),
                                    ),
                                ],
                              ),
                              CupertinoListSection.insetGrouped(
                                hasLeading: false,
                                margin: const EdgeInsets.all(10),
                                dividerMargin: 0,
                                topMargin: 0,
                                children: [
                                  SettingsListItemTile(
                                    color: Colors.blue,
                                    icon: CupertinoIcons.photo,
                                    onTap: () {
                                      controller.openChatMedia(context);
                                    },
                                    title: S.of(context).mediaLinksAndDocs,
                                  ),
                                  SettingsListItemTile(
                                    color: Colors.amber,
                                    icon: CupertinoIcons.star_fill,
                                    title: S.of(context).starredMessage,
                                    onTap: () {
                                      controller.openStarredMessages(context);
                                    },
                                  ),
                                  SettingsListItemTile(
                                    color: Colors.deepOrangeAccent,
                                    icon: CupertinoIcons.person,
                                    title: S.of(context).nickname,
                                    onTap: () {
                                      controller.toUpdateNickName(context);
                                    },
                                    additionalInfo: value.data.settingsModel
                                                .room.nickName ==
                                            null
                                        ? Text(S.of(context).none)
                                        : Text(
                                            value.data.settingsModel.room
                                                .nickName!,
                                          ),
                                  ),
                                  SettingsListItemTile(
                                    color: Colors.deepOrangeAccent,
                                    icon: value.data.isLocked ? CupertinoIcons.lock_open : CupertinoIcons.lock,
                                    title: value.data.isLocked ? 'Unlock chat' : 'Lock chat',
                                    isLoading: value.data.isUpdatingLock,
                                    onTap: () {
                                      controller.toggleChatLock(context);
                                    },
                                  ),
                                ],
                              ),
                              CupertinoListSection.insetGrouped(
                                hasLeading: false,
                                margin: const EdgeInsets.all(10),
                                dividerMargin: 0,
                                topMargin: 0,
                                children: [
                                  SettingsListItemTile(
                                    color: Colors.green,
                                    isLoading: value.data.isUpdatingMute,
                                    icon: CupertinoIcons.speaker_2,
                                    title: S.of(context).mute,
                                    onTap: () {
                                      controller.updateMute(context);
                                    },
                                    additionalInfo:
                                        value.data.settingsModel.room.isMuted
                                            ? Text(S.of(context).yes)
                                            : Text(S.of(context).no),
                                  ),
                                  SettingsListItemTile(
                                    color: Colors.green,
                                    isLoading: value.data.isUpdatingCustomSound,
                                    icon: CupertinoIcons.bell_solid,
                                    title: 'Notification sound',
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
                                    color: Colors.red,
                                    isLoading: value.data.isUpdatingExitGroup,
                                    textColor: Colors.red,
                                    onTap: () => controller.leaveGroup(context),
                                    title: ((controller.groupInfo?.groupSettings?.extraData != null &&
                                            controller.groupInfo!.groupSettings!.extraData!['isChannel'] == true)
                                        ? 'Exit Channel'
                                        : S.of(context).exitGroup),
                                    icon: CupertinoIcons.ant_circle,
                                  ),
                                  if (controller.isMeCreator)
                                    SettingsListItemTile(
                                      color: Colors.red,
                                      isLoading:
                                          value.data.isUpdatingDeleteGroup,
                                      textColor: Colors.red,
                                      onTap: () =>
                                          controller.deleteGroup(context),
                                      title: ((controller.groupInfo?.groupSettings?.extraData != null &&
                                              controller.groupInfo!.groupSettings!.extraData!['isChannel'] == true)
                                          ? 'Delete Channel'
                                          : 'Delete Group'),
                                      icon: CupertinoIcons.delete,
                                    ),
                                  // SettingsListItemTile(
                                  //   color: Colors.red,
                                  //   textColor: Colors.red,
                                  //   onTap: () => controller.reportGroup(context),
                                  //   title: "Report Group",
                                  //   icon: PhosphorIcons.bug,
                                  // ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getGroupBio(
    BuildContext context,
    String? desc, [
    bool isChannel = false,
    bool canEdit = true,
  ]) {
    if (desc == null) {
      return ChatSettingsTileInfo(
        title: Text(
          isChannel
              ? 'Click to add channel description'
              : S.of(context).clickToAddGroupDescription,
          style: TextStyle(
            color: canEdit ? CupertinoColors.systemBlue : CupertinoColors.secondaryLabel,
          ),
        ),
      );
    }
    return ChatSettingsTileInfo(
      title: Text(desc),
    );
  }
}
