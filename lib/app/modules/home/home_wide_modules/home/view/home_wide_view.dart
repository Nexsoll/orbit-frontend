// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/modules/home/mobile/story_tab/views/story_tab_view.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../../../../core/api_service/auth/auth_api_service.dart';
import '../../../../../core/api_service/profile/profile_api_service.dart';
import '../../../../../core/app_nav/app_navigation.dart';
import '../../wide_navigation/wide_chat_info_navigation.dart';
import '../../wide_navigation/wide_messages_navigation.dart';
import '../../wide_navigation/wide_rooms_navigation.dart';
import '../controller/home_wide_controller.dart';

class HomeWideView extends StatefulWidget {
  const HomeWideView({super.key});

  @override
  State<HomeWideView> createState() => _HomeWideViewState();
}

class _HomeWideViewState extends State<HomeWideView> {
  late final HomeWideController controller;
  final sizer = GetIt.I.get<AppSizeHelper>();

  @override
  void initState() {
    super.initState();
    controller = HomeWideController(
      GetIt.I.get<ProfileApiService>(),
      GetIt.I.get<AuthApiService>(),
    );
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
      child: SafeArea(
        child: Builder(
          builder: (context) {
            final isSmall = sizer.isSmall(context);
            if (isSmall == true) {
              AppNavigation.setWideMessagesInfoNotifier(false);
              AppNavigation.popKey(WideRoomsNavigation.navKey);
            }
            return Row(
              children: [
                SizedBox(
                  width: isSmall ? 90 : 360,
                  child: Padding(
                    padding:
                        isSmall ? EdgeInsets.zero : const EdgeInsets.all(8.0),
                    child: WideRoomsNavigation(
                      onSearchClicked: () {
                        controller.onSearchClicked(context);
                      },
                      onOpenStory: () {
                        context.toPage(const StoryTabView());
                      },
                      onCreateNewBroadcast: () {
                        controller.createNewChannel(
                            WideRoomsNavigation.navKey.currentState!.context);
                      },
                      onCreateNewGroup: () {
                        controller.createNewGroup(
                            WideRoomsNavigation.navKey.currentState!.context);
                      },
                      onNewChat: () {
                        controller.newChat(context);
                      },
                      onShowSettings: () {
                        controller.onShowSettings(context);
                      },
                      vRoomController: controller.vRoomController,
                      onRoomItemPress: (room) {
                        controller.onRoomItemPress(room, context);
                      },
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.isDark ? Colors.black12 : Colors.white,
                ),
                Expanded(child: WideMessagesNavigation()),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.isDark ? Colors.black12 : Colors.white,
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: AppNavigation.wideMessagesInfoNotifier,
                  builder: (context, value, child) {
                    if (value) {
                      return ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 360,
                          minWidth: 200,
                        ),
                        child: const WideMessageInfoNavigation(),
                      );
                    }
                    return const SizedBox();
                  },
                )
              ],
            );
          },
        ),
      ),
    );
  }
}
