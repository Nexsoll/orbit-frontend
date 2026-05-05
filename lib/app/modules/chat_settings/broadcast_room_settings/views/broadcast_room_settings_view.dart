// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import 'package:v_platform/v_platform.dart';

import '../../../home/mobile/settings_tab/widgets/settings_list_item_tile.dart';
import '../../widgets/chat_settings_navigation_bar.dart';
import '../controllers/broadcast_room_settings_controller.dart';

class BroadcastRoomSettingsView extends StatefulWidget {
  final VToChatSettingsModel settingsModel;

  const BroadcastRoomSettingsView({super.key, required this.settingsModel});

  @override
  State<BroadcastRoomSettingsView> createState() =>
      _BroadcastRoomSettingsViewState();
}

class _BroadcastRoomSettingsViewState extends State<BroadcastRoomSettingsView> {
  late final BroadcastRoomSettingsController controller;

  @override
  void initState() {
    super.initState();
    controller = BroadcastRoomSettingsController(widget.settingsModel);
    controller.onInit();
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
        middle: S.of(context).broadcastInfo,
        previousPageTitle: S.of(context).back,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(
                height: 40,
              ),
              GestureDetector(
                onTap: () => controller.openFullImage(context),
                child: ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return VCircleAvatar(
                      vFileSource: VPlatformFile.fromUrl(
                        networkUrl: controller.settingsModel.image,
                      ),
                      radius: 90,
                    );
                  },
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, child) => Text(
                  controller.settingsModel.title,
                  style: context.cupertinoTextTheme.navLargeTitleTextStyle,
                ),
              ),
              const SizedBox(
                height: 15,
              ),
              ValueListenableBuilder<SLoadingState<VMyBroadcastInfo>>(
                valueListenable: controller,
                builder: (_, value, __) {
                  return VAsyncWidgetsBuilder(
                    loadingState: value.loadingState,
                    onRefresh: controller.getData,
                    successWidget: () {
                      return Column(
                        children: [
                          CupertinoListSection.insetGrouped(
                            hasLeading: false,
                            margin: const EdgeInsets.all(10),
                            dividerMargin: 0,
                            topMargin: 0,
                            children: [
                              SettingsListItemTile(
                                color: Colors.amber,
                                icon: Icons.edit,
                                title: S.of(context).updateTitle,
                                onTap: () {
                                  controller.onUpdateTitle(context);
                                },
                                additionalInfo:
                                    Text(controller.settingsModel.title),
                              ),
                              SettingsListItemTile(
                                color: Colors.cyan,
                                icon: CupertinoIcons.person_2,
                                title: S.of(context).members,
                                onTap: () {
                                  controller.onGoShowMembers(context);
                                },
                                additionalInfo:
                                    Text(controller.info.totalUsers.toString()),
                              ),
                              SettingsListItemTile(
                                color: Colors.green,
                                onTap: () {
                                  controller
                                      .addParticipantsToBroadcast(context);
                                },
                                icon: CupertinoIcons.add,
                                title: S.of(context).addMembers,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
