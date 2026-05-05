import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class TimeLockMessageHelper {
  static Map<String, dynamic> buildData({
    required String content,
    required DateTime unlockAt,
  }) {
    return {
      'type': 'time_lock',
      'content': content,
      'unlockAt': unlockAt.toUtc().toIso8601String(),
    };
  }

  static Future<void> sendTimeLocked({
    required String roomId,
    required String content,
    required DateTime unlockAt,
  }) async {
    final data = buildData(content: content, unlockAt: unlockAt);

    final msg = VCustomMessage.buildMessage(
      roomId: roomId,
      data: VCustomMsgData(data: data),
      content: content,
    );

    await VChatController.I.nativeApi.local.message.insertMessage(msg);
    VMessageUploaderQueue.instance
        .addToQueue(await MessageFactory.createUploadMessage(msg));
  }
}
