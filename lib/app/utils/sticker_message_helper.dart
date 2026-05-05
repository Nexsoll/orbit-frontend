import 'package:v_chat_input_ui/v_chat_input_ui.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

/// Helper class for sending sticker messages
class StickerMessageHelper {
  /// Send a sticker message to a room
  static Future<void> sendStickerMessage({
    required String roomId,
    required VSticker sticker,
    required String stickerPackId,
  }) async {
    final stickerData = {
      'type': 'sticker',
      'stickerId': sticker.id,
      'stickerPackId': stickerPackId,
      'assetPath': sticker.assetPath,
      'name': sticker.name,
      'emoji': sticker.emoji,
      'tags': sticker.tags,
    };

    // Create and send the custom message
    final customMessage = VCustomMessage.buildMessage(
      roomId: roomId,
      data: VCustomMsgData(data: stickerData),
      content: "sticker",
    );

    // Insert locally and queue for upload
    await VChatController.I.nativeApi.local.message
        .insertMessage(customMessage);
    VMessageUploaderQueue.instance.addToQueue(
      await MessageFactory.createUploadMessage(customMessage),
    );
  }

  /// Check if a custom message is a sticker message
  static bool isStickerMessage(Map<String, dynamic> data) {
    return data['type'] == 'sticker';
  }

  /// Extract sticker data from a custom message
  static VStickerMessageData? extractStickerData(Map<String, dynamic> data) {
    if (!isStickerMessage(data)) return null;

    try {
      return VStickerMessageData(
        stickerId: data['stickerId'] as String,
        stickerPackId: data['stickerPackId'] as String,
        assetPath: data['assetPath'] as String,
        name: data['name'] as String,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get a preview text for sticker messages in chat lists
  static String getStickerPreviewText(Map<String, dynamic> data) {
    final stickerId = data['stickerId'] as String?;
    if (stickerId?.startsWith('giphy_') == true) {
      return '🎭 GIPHY Sticker';
    }
    return 'sticker';
  }
}
