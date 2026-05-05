// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/modules/home/mobile/calls_tab/views/calls_tab_view.dart';
import 'package:super_up/app/modules/home/mobile/rooms_tab/views/rooms_tab_view.dart';
import 'package:super_up/app/modules/home/mobile/communities_tab/views/communities_tab_view.dart';
import 'package:super_up/app/modules/home/mobile/users_tab/views/users_tab_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import '../../../../core/api_service/profile/profile_api_service.dart';
import '../../../social/views/social_splash_view.dart';
import '../../home_wide_modules/home/view/home_wide_view.dart';
import '../../mobile/settings_tab/views/settings_tab_view.dart';
import '../../mobile/story_tab/views/story_tab_view.dart';
import '../controllers/home_controller.dart';
import '../widgets/chat_un_read_counter.dart';
import '../../mobile/story_tab/controllers/story_tab_controller.dart';
import '../../mobile/rooms_tab/controllers/rooms_tab_controller.dart';
import '../../mobile/rooms_tab/views/groups_channels_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  late final HomeController controller;
  final sizer = GetIt.I.get<AppSizeHelper>();

  @override
  void initState() {
    super.initState();
    controller = HomeController(
      GetIt.I.get<ProfileApiService>(),
      context,
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
    if (sizer.isWide(context)) {
      return const HomeWideView();
    }
    return ValueListenableBuilder<SLoadingState<int>>(
      valueListenable: controller,
      builder: (_, value, __) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final tabBgColor = isDark ? Colors.black : const Color(0xFFc9cfc8);
        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.2);

        return CupertinoPageScaffold(
          backgroundColor: tabBgColor,
          child: Stack(
            children: [
              // Tab content
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 50), // Space for bottom nav
                child: IndexedStack(
                  index: value.data,
                  children: const [
                    RoomsTabView(), // 0
                    StoryTabView(), // 1
                    CallsTabView(), // 2
                    UsersTabView(), // 3
                    CommunitiesTabView(), // 4
                    SettingsTabView(), // 5 (not in bottom bar)
                  ],
                ),
              ),
              // Bottom navigation bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: tabBgColor,
                    border: Border(
                      top: BorderSide(
                        color: borderColor,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 50,
                      child: Row(
                        children: [
                          _buildTabItem(
                            context: context,
                            index: 0,
                            currentIndex: value.data,
                            icon: ValueListenableBuilder<SLoadingState<int>>(
                              valueListenable: controller,
                              builder: (context, value, child) {
                                return Stack(
                                  children: [
                                    const Icon(CupertinoIcons.chat_bubble_2),
                                    PositionedDirectional(
                                      end: 0,
                                      child: ChatUnReadWidget(
                                        unReadCount: controller.totalChatUnRead,
                                        width: 15,
                                        height: 15,
                                      ),
                                    )
                                  ],
                                );
                              },
                            ),
                            label: S.of(context).chats,
                            onTap: () {
                              blinkUnreadRoomsStream.add(true);
                              controller.value.data = 0;
                              controller.update();
                            },
                          ),
                          _buildTabItem(
                            context: context,
                            index: 1,
                            currentIndex: value.data,
                            icon: const Icon(CupertinoIcons.play_circle),
                            label: S.of(context).stories,
                            onTap: () async {
                              controller.value.data = 1;
                              controller.update();
                              try {
                                if (!GetIt.I
                                    .isRegistered<StoryTabController>()) {
                                  GetIt.I.registerLazySingleton<
                                          StoryTabController>(
                                      () => StoryTabController());
                                  GetIt.I.get<StoryTabController>().onInit();
                                }
                                final storyCtrl =
                                    GetIt.I.get<StoryTabController>();
                                await storyCtrl.getMyStoryFromApi();
                                await storyCtrl.getStoriesFromApi();
                                storyCtrl.update();
                              } catch (_) {}
                            },
                          ),
                          _buildTabItem(
                            context: context,
                            index: 11,
                            currentIndex: value.data,
                            icon: const Icon(CupertinoIcons.globe),
                            label: 'Social',
                            onTap: () {
                              context.toPage(const SocialSplashView());
                            },
                          ),
                          _buildTabItem(
                            context: context,
                            index: 2,
                            currentIndex: value.data,
                            icon: const Icon(CupertinoIcons.phone),
                            label: S.of(context).phone,
                            onTap: () {
                              controller.value.data = 2;
                              controller.update();
                            },
                          ),
                          _buildTabItem(
                            context: context,
                            index: 3,
                            currentIndex: value.data,
                            icon: const Icon(CupertinoIcons.person_2),
                            label: S.of(context).users,
                            onTap: () {
                              controller.value.data = 3;
                              controller.update();
                            },
                          ),
                          _buildTabItem(
                            context: context,
                            index:
                                10, // Use a non-conflicting index for push-only tab
                            currentIndex: value.data,
                            icon: Stack(
                              children: [
                                const Icon(
                                    CupertinoIcons.person_2_square_stack),
                                PositionedDirectional(
                                  end: -2,
                                  top: -2,
                                  child: ChatUnReadWidget(
                                    unReadCount:
                                        controller.totalGroupsChannelsUnRead,
                                    width: 15,
                                    height: 15,
                                  ),
                                ),
                              ],
                            ),
                            label: 'Groups',
                            onTap: () {
                              final roomsCtrl =
                                  GetIt.I.get<RoomsTabController>();
                              final config = VAppConfigController.appConfig;
                              context.toPage(
                                GroupsChannelsView(
                                  onCreateNewGroup: config.allowCreateGroup
                                      ? () => roomsCtrl.createNewGroup(context)
                                      : null,
                                  onCreateNewChannel: config
                                          .allowCreateBroadcast
                                      ? () =>
                                          roomsCtrl.createNewChannel(context)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required int index,
    required int currentIndex,
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isSelected = index == currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabItemColor = isDark ? Colors.white : Colors.black;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(
                  color: isSelected ? const Color(0xFFB48648) : tabItemColor,
                  size: 24,
                ),
                child: icon,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? const Color(0xFFB48648) : tabItemColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
