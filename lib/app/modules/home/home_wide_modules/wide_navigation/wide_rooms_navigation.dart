// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_room_page/v_chat_room_page.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../../../../v_chat_v2/translations.dart';
import '../../../../core/app_config/app_config_controller.dart';
import '../../../../core/api_service/drivers/drivers_api_service.dart';
import '../../home_controller/widgets/chat_un_read_counter.dart';
import 'no_animation_page_route.dart';
import '../../../live_stream/views/live_stream_options_view.dart';
import '../../../ride/views/orbit_ride_view.dart';
import '../../../driver/views/driver_dashboard_view.dart';
import '../../../music/views/music_home_view.dart';
import '../../../../core/services/ride_mode_service.dart';

class WideRoomsNavigation extends StatelessWidget {
  final VoidCallback onShowSettings;
  final VoidCallback onNewChat;
  final VoidCallback onOpenStory;
  final VoidCallback onCreateNewBroadcast;
  final VoidCallback onCreateNewGroup;
  final VoidCallback onSearchClicked;
  final VRoomController vRoomController;

  final Function(VRoom room)? onRoomItemPress;

  WideRoomsNavigation({
    super.key,
    required this.onShowSettings,
    required this.onNewChat,
    required this.onCreateNewBroadcast,
    required this.onCreateNewGroup,
    required this.onOpenStory,
    required this.onSearchClicked,
    required this.vRoomController,
    this.onRoomItemPress,
  });

  static final navKey = GlobalKey<NavigatorState>();
  final sizer = GetIt.I.get<AppSizeHelper>();
  final config = VAppConfigController.appConfig;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      initialRoute: 'chats',
      onGenerateRoute: (settings) {
        return NoAnimationPageRoute(
          builder: (context) {
            return Builder(
              builder: (context) {
                final isSmall = sizer.isSmall(context);
                return VChatPage(
                  appBar: CupertinoListTile(
                    padding: const EdgeInsets.all(0),
                    title: Row(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: onShowSettings,
                              child: VCircleAvatar(
                                vFileSource: VPlatformFile.fromUrl(
                                  networkUrl:
                                      AppAuth.myProfile.baseUser.userImage,
                                ),
                                radius: 21,
                              ),
                            ),
                            PositionedDirectional(
                              end: 0,
                              child: StreamBuilder<VRoomEvents>(
                                stream: VChatController.I.nativeApi.streams.roomStream.where(
                                      (event) =>
                                          event is VUpdateRoomUnReadCountByOneEvent ||
                                          event is VUpdateRoomUnReadCountToZeroEvent ||
                                          event is VInsertRoomEvent ||
                                          event is VDeleteRoomEvent,
                                    ),
                                builder: (context, _) {
                                  return FutureBuilder<List<VRoom>>(
                                    future: VChatController.I.nativeApi.local.room.getRooms(
                                      limit: 200,
                                    ),
                                    builder: (context, snapshot) {
                                      var totalChatUnRead = 0;
                                      final rooms = snapshot.data;
                                      if (rooms != null) {
                                        totalChatUnRead = rooms
                                            .where(
                                              (r) =>
                                                  r.roomType != VRoomType.o &&
                                                  !r.isArchived &&
                                                  r.unReadCount > 0,
                                            )
                                            .length;
                                      }
                                      return ChatUnReadWidget(
                                        unReadCount: totalChatUnRead,
                                      );
                                    },
                                  );
                                },
                              ),
                            )
                          ],
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minSize: 32,
                          onPressed: () async {
                            try {
                              final status = await DriversApiService.myRideBanStatus();
                              final isBanned = status['isBanned'] == true;
                              final reason = (status['reason'] ?? '').toString().trim();
                              if (isBanned) {
                                await showCupertinoDialog(
                                  context: context,
                                  builder: (_) => CupertinoAlertDialog(
                                    title: const Text('Ride access restricted'),
                                    content: Text(
                                      reason.isEmpty ? 'You are banned from using Ride.' : reason,
                                    ),
                                    actions: [
                                      CupertinoDialogAction(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }
                            } catch (_) {}

                            final isDriver = RideModeService.instance.isDriverMode;
                            if (isDriver) {
                              context.toPage(const DriverDashboardView());
                            } else {
                              context.toPage(const OrbitRideView());
                            }
                          },
                          child: const Icon(CupertinoIcons.car_detailed),
                        ),
                        if (!isSmall) ...[
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minSize: 32,
                            onPressed: () {
                              // Open Live Stream options (Go Live / Watch Live)
                              context.toPage(const LiveStreamOptionsView());
                            },
                            child: const Icon(CupertinoIcons.play_rectangle),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minSize: 32,
                            onPressed: () {
                              // Open Music page (same as mobile Rooms tab)
                              context.toPage(const MusicHomeView());
                            },
                            child: const Icon(CupertinoIcons.music_note_2),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minSize: 32,
                            onPressed: onShowSettings,
                            child: const Icon(CupertinoIcons.settings),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minSize: 32,
                            onPressed: onNewChat,
                            child: const Icon(CupertinoIcons.chat_bubble_text),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minSize: 32,
                            onPressed: onOpenStory,
                            child: const Icon(Icons.history_toggle_off_rounded),
                          ),
                        ] else ...[
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minSize: 32,
                            onPressed: onShowSettings,
                            child: const Icon(CupertinoIcons.settings),
                          ),
                        ]
                      ],
                    ),
                  ),
                  onSearchClicked: onSearchClicked,
                  language: vRoomLanguageModel(context),
                  onCreateNewBroadcast:
                      config.allowCreateBroadcast ? onCreateNewBroadcast : null,
                  onCreateNewGroup:
                      config.allowCreateGroup ? onCreateNewGroup : null,
                  controller: vRoomController,
                  useIconForRoomItem: isSmall,
                  onRoomItemPress: onRoomItemPress,
                );
              },
            );
          },
        );
      },
    );
  }
}
