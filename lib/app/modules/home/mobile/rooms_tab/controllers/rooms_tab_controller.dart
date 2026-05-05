// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_platform/v_platform.dart';
import 'package:super_up/app/core/widgets/custom_image_cropper.dart';
import 'package:v_chat_media_editor/v_chat_media_editor.dart';
import 'package:v_chat_media_editor/src/core/v_media_file_utils.dart' as editor_utils;

import 'package:v_chat_room_page/v_chat_room_page.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import '../../../../chats_search/views/chats_search_view.dart';
import '../../../../create_broadcast/mobile/sheet_for_create_broadcast.dart';
import '../../../../create_group/mobile/sheet_for_create_group.dart';
import '../../../../loyalty_points/views/loyalty_points_view.dart';
import '../../../../../core/services/ai_message_handler.dart';
import '../../../../../core/utils/permission_manager.dart';
import '../../../../start_new_chat/views/start_new_chat_view.dart';

class RoomsTabController extends ValueNotifier implements SBaseController {
  final vRoomController = VRoomController();

  RoomsTabController() : super(null);

  @override
  void onClose() {
    vRoomController.dispose();
  }

  @override
  void onInit() {}

  void createNewGroup(BuildContext context) async {
    final groupRoom = await showCupertinoModalBottomSheet(
      expand: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const SheetForCreateGroup(),
    ) as VRoom?;
    if (groupRoom == null) {
      return;
    }
    VChatController.I.vNavigator.messageNavigator
        .toMessagePage(context, groupRoom);
  }

  void createNewBroadcast(BuildContext context) async {
    final broadcastRoom = await showCupertinoModalBottomSheet(
      expand: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const SheetForCreateBroadcast(),
    );
    if (broadcastRoom == null) {
      return;
    }
    VChatController.I.vNavigator.messageNavigator
        .toMessagePage(context, broadcastRoom);
  }

  // New: Create Channel flow (moved from Stories tab)
  void createNewChannel(BuildContext context) {
    final titleController = TextEditingController();
    VPlatformFile? image;

    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return CupertinoAlertDialog(
            title: Text(S.of(context).createChannelTitle),
            content: Column(
              children: [
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: titleController,
                  placeholder: S.of(context).channelName,
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  onPressed: () async {
                    final picked = await AppImageCropper.pickAndCrop(context);
                    if (picked != null) {
                      image = picked;
                      setState(() {});
                    }
                  },
                  child: Text(image == null
                      ? S.of(context).pickImageOptional
                      : S.of(context).changeImage),
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(S.of(context).cancel),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  final name = titleController.text.trim();
                  if (name.isEmpty) {
                    VAppAlert.showErrorSnackBar(
                        message: S.of(context).titleIsRequired, context: context);
                    return;
                  }
                  try {
                    // 1) Create an empty group with me only
                    final room = await VChatController.I.roomApi.createGroup(
                      dto: CreateGroupDto(
                        peerIds: const [],
                        title: name,
                        platformImage: image,
                        extraData: const {'isChannel': true},
                      ),
                    );
                    // 2) Ensure channel flag persists
                    await VChatController.I.roomApi.updateGroupExtraData(
                      roomId: room.id,
                      data: {'isChannel': true},
                    );
                    // 3) Insert locally for instant appearance
                    await VChatController.I.nativeApi.local.room.safeInsertRoom(room);
                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                      // 4) Open channel
                      VChatController.I.vNavigator.messageNavigator
                          .toMessagePage(context, room);
                    }
                  } catch (e) {
                    VAppAlert.showErrorSnackBar(
                        message: e.toString(), context: context);
                  }
                },
                child: Text(S.of(context).create),
              ),
            ],
          );
        });
      },
    );
  }

  void onSearchClicked(BuildContext context) {
    context.toPage(const ChatsSearchView());
  }

  void onCameraPress(BuildContext context) async {
    if (!VPlatforms.isMobile) {
      return;
    }

    // Check camera permission
    final isCameraAllowed = await PermissionManager.isCameraAllowed();
    if (!isCameraAllowed) {
      final granted = await PermissionManager.askForCamera();
      if (!granted) return;
    }

    // Open camera directly - supports both photo and video
    final fileSource = await VAppPick.pickFromWeAssetCamera(
      context: context,
      videoSeconds: 60,
    );
    if (fileSource == null) return;

    final isVideo = fileSource.isContentVideo;

    final roomsIds = await VChatController.I.vNavigator.roomNavigator
        .toForwardPage(context, null);
    if (roomsIds == null) return;

    for (final roomId in roomsIds) {
      if (isVideo) {
        // Handle video message
        final durationMs = await editor_utils.VMediaFileUtils.getVideoDurationMill(fileSource);
        final message = VVideoMessage.buildMessage(
          roomId: roomId,
          data: VMessageVideoData(
            fileSource: fileSource,
            duration: durationMs ?? 0,
          ),
        );
        await VChatController.I.nativeApi.local.message.insertMessage(message);
        try {
          VMessageUploaderQueue.instance.addToQueue(
            await MessageFactory.createUploadMessage(message),
          );
        } catch (err) {
          if (kDebugMode) {
            print(err);
          }
        }
      } else {
        // Handle image message
        final data = await VFileUtils.getImageInfo(
          fileSource: fileSource,
        );
        final message = VImageMessage.buildMessage(
          roomId: roomId,
          data: VMessageImageData(
            fileSource: fileSource,
            height: data.image.height,
            width: data.image.width,
            blurHash: await VMediaFileUtils.getBlurHash(fileSource),
          ),
        );
        await VChatController.I.nativeApi.local.message.insertMessage(message);
        try {
          VMessageUploaderQueue.instance.addToQueue(
            await MessageFactory.createUploadMessage(message),
          );
        } catch (err) {
          if (kDebugMode) {
            print(err);
          }
        }
      }
    }
  }

  void onTrophyPress(BuildContext context) {
    context.toPage(const LoyaltyPointsView());
  }

  void onAiAssistantPress(BuildContext context) async {
    // Clear all previous AI Assistant messages first
    await AiMessageHandler().clearAllMessages();

    // Create AI Assistant room
    final aiRoom = VRoom(
      id: "ai_assistant_room",
      title: "Orbit AI",
      enTitle: "Orbit AI",
      roomType: VRoomType.s, // Single room type
      thumbImage: "assets/ai-logo.png", // AI logo asset path
      transTo: null,
      isArchived: false,
      unReadCount: 0,
      isOneSeen: false,
      lastMessage: VEmptyMessage(),
      createdAt: DateTime.now(),
      isMuted: false,
      peerId: "ai_assistant_peer", // Unique peer ID for AI
      nickName: null,
    );

    // Insert the room locally first to ensure it exists
    await VChatController.I.nativeApi.local.room.safeInsertRoom(aiRoom);

    // Navigate to regular message page
    VChatController.I.vNavigator.messageNavigator
        .toMessagePage(context, aiRoom);

    // Send welcome message after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      AiMessageHandler().sendWelcomeMessage();
    });
  }

  void onNewChatPress(BuildContext context) {
    context.toPage(const StartNewChatView());
  }
}
