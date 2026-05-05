// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_chat_sdk_core/src/utils/v_message_constants.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart' as adaptive_dialog;

class ChatStarMessagesController
    extends SLoadingController<List<VBaseMessage>> {
  final txtController = TextEditingController();
  final String? roomId;
  final scrollController = ScrollController();

  ChatStarMessagesController(
    this.roomId,
  ) : super(SLoadingState([]));
  late final VVoicePlayerController voiceControllers;

  @override
  void onClose() {
    super.dispose();
    txtController.dispose();
    voiceControllers.close();
  }

  @override
  void onInit() {
    getData();
    _setUpVoiceController();
  }

  void _setUpVoiceController() {
    voiceControllers = VVoicePlayerController(
      (localId) {
        final index = value.data.indexWhere((e) => e.localId == localId);
        if (index == -1 || index == 0) {
          return null;
        }
        if (!value.data[index - 1].messageType.isVoice) {
          return null;
        }
        return value.data[index - 1].localId;
      },
    );

    // Update the global controller with current callback when this controller is active
    VGlobalVoiceController().updatePlayNextCallback(
      (localId) {
        final index = value.data.indexWhere((e) => e.localId == localId);
        if (index == -1 || index == 0) {
          return null;
        }
        if (!value.data[index - 1].messageType.isVoice) {
          return null;
        }
        return value.data[index - 1].localId;
      },
    );
  }

  Future<void> getData() async {
    await vSafeApiCall<List<VBaseMessage>>(
      onLoading: () async {
        setStateLoading();
        update();
      },
      onError: (exception, trace) {
        setStateError();
        update();
      },
      request: () async {
        if (roomId == null) {
          return VChatController.I.nativeApi.remote.room.getAllStarMessages();
        }
        return VChatController.I.nativeApi.remote.message
            .getStarRoomMessages(roomId: roomId!);
      },
      onSuccess: (response) {
        value.data = response;
        if (value.data.isEmpty) {
          setStateEmpty();
        } else {
          setStateSuccess();
        }
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }

  Future onLongTab(BuildContext context, VBaseMessage message) async {
    final items = <ModelSheetItem<int>>[
      ModelSheetItem<int>(title: S.of(context).copy, id: 1),
      ModelSheetItem<int>(title: S.of(context).forward, id: 2),
      ModelSheetItem<int>(title: S.of(context).unStar, id: 3),
    ];
    
    final res = await VAppAlert.showModalSheetWithActions<int>(
      content: items,
      context: context,
    );
    if (res == null) return;
    
    switch (res.id) {
      case 1: // Copy
        await _handleCopy(message);
        break;
      case 2: // Forward
        await _handleForward(context, message);
        break;
      case 3: // Un star
        await _handleUnStar(message);
        break;
    }
  }

  Future<void> _handleCopy(VBaseMessage message) async {
    await Clipboard.setData(
      ClipboardData(
        text: message.realContentMentionParsedWithAt,
      ),
    );
  }

  Future<void> _handleForward(BuildContext context, VBaseMessage message) async {
    // Check if message can be forwarded
    if (!message.emitStatus.isServerConfirm || message.isAllDeleted) {
      VAppAlert.showErrorSnackBar(
        message: 'Message cannot be forwarded',
        context: context,
      );
      return;
    }

    String? customCaption;
    if (message is VImageMessage || message is VVideoMessage) {
      customCaption = await _showCaptionEditor(context, message);
      if (customCaption == null) return;
    }
    
    final ids = await VChatController.I.vNavigator.roomNavigator
        .toForwardPage(context, message.roomId);
    if (ids == null || ids.isEmpty) return;
    
    for (final roomId in ids) {
      await _forwardMessageToRoom(message, roomId, customCaption: customCaption);
    }
  }

  Future<String?> _showCaptionEditor(BuildContext context, VBaseMessage message) async {
    String currentCaption = message.realContent;
    if (currentCaption == VMessageConstants.thisContentIsImage ||
        currentCaption == VMessageConstants.thisContentIsVideo) {
      currentCaption = "";
    }

    final result = await VAppAlert.showTextInputDialog(
      context: context,
      title: "Edit Caption",
      textFields: [
        adaptive_dialog.DialogTextField(
          initialText: currentCaption,
          hintText: "Add a caption...",
        ),
      ],
    );

    if (result == null) return null;
    return result.first;
  }

  Future<void> _forwardMessageToRoom(
    VBaseMessage baseMessage,
    String targetRoomId, {
    String? customCaption,
  }) async {
    final localStorage = VChatController.I.nativeApi.local;
    
    VBaseMessage? message;
    switch (baseMessage.messageType) {
      case VMessageType.text:
        message = VTextMessage.buildMessage(
          content: customCaption ?? baseMessage.realContent,
          roomId: targetRoomId,
          forwardId: 'forwarded_${baseMessage.localId}',
          isEncrypted: false,
          linkAtt: null,
        );
        break;
      case VMessageType.image:
        message = VImageMessage.buildMessage(
          data: (baseMessage as VImageMessage).data,
          roomId: targetRoomId,
          forwardId: baseMessage.localId,
          content: customCaption ?? baseMessage.realContent,
        );
        break;
      case VMessageType.file:
        message = VFileMessage.buildMessage(
          data: (baseMessage as VFileMessage).data,
          roomId: targetRoomId,
          forwardId: 'forwarded_${baseMessage.localId}',
        );
        break;
      case VMessageType.video:
        message = VVideoMessage.buildMessage(
          data: (baseMessage as VVideoMessage).data,
          roomId: targetRoomId,
          forwardId: 'forwarded_${baseMessage.localId}',
          content: customCaption ?? baseMessage.realContent,
        );
        break;
      case VMessageType.voice:
        message = VVoiceMessage.buildMessage(
          data: (baseMessage as VVoiceMessage).data,
          roomId: targetRoomId,
          content: baseMessage.realContent,
          forwardId: 'forwarded_${baseMessage.localId}',
        );
        break;
      case VMessageType.location:
        message = VLocationMessage.buildMessage(
          data: (baseMessage as VLocationMessage).data,
          roomId: targetRoomId,
          forwardId: 'forwarded_${baseMessage.localId}',
        );
        break;
      case VMessageType.custom:
        message = VCustomMessage.buildMessage(
          data: (baseMessage as VCustomMessage).data,
          content: baseMessage.realContent,
          roomId: targetRoomId,
        );
        break;
      default:
        return;
    }
    
    if (message == null) return;
    message.emitStatus = VMessageEmitStatus.sending;
    
    // AI messages need sender reset
    if (message.senderId == "ai_assistant_peer") {
      message.senderId = VAppConstants.myProfile.id;
      message.senderName = VAppConstants.myProfile.fullName;
      message.senderImageThumb = VAppConstants.myProfile.userImage;
    }
    
    // Save to local storage
    await localStorage.message.updateFullMessage(message);
    
    // Emit insert event
    VEventBusSingleton.vEventBus.fire(VInsertMessageEvent(
      messageModel: message,
      roomId: message.roomId,
      localId: message.localId,
    ));
    
    // Update room list
    final existingRoom = await localStorage.room
        .getOneWithLastMessageByRoomId(targetRoomId);
    if (existingRoom != null) {
      final updatedRoom = existingRoom.copyWith(lastMessage: message);
      VEventBusSingleton.vEventBus.fire(VInsertRoomEvent(
        roomId: targetRoomId,
        room: updatedRoom,
      ));
    }
    
    // Add to upload queue
    try {
      VMessageUploaderQueue.instance.addToQueue(
        await MessageFactory.createForwardUploadMessage(message),
      );
    } catch (_) {}
  }

  Future<void> _handleUnStar(VBaseMessage message) async {
    await vSafeApiCall(
      request: () async {
        await VChatController.I.nativeApi.remote.message
            .unStarMessage(message.roomId, message.id);
      },
      onSuccess: (response) {
        getData();
      },
    );
  }
}
