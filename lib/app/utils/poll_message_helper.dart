import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class PollMessageHelper {
  static Map<String, dynamic> buildPollData({
    required String question,
    required List<String> options,
    bool allowMulti = false,
  }) {
    final opts = <Map<String, dynamic>>[];
    for (var i = 0; i < options.length; i++) {
      final id = 'opt_${DateTime.now().microsecondsSinceEpoch}_$i';
      opts.add({'id': id, 'text': options[i]});
    }
    return {
      'type': 'poll',
      'question': question,
      'allowMulti': allowMulti,
      'options': opts,
      'votes': <String, List<String>>{},
    };
  }

  static Future<void> sendPoll({
    required String roomId,
    required String question,
    required List<String> options,
    bool allowMulti = false,
  }) async {
    final data = buildPollData(
      question: question,
      options: options,
      allowMulti: allowMulti,
    );

    final msg = VCustomMessage.buildMessage(
      roomId: roomId,
      data: VCustomMsgData(data: data),
      content: question,
    );

    print('[PollMessageHelper] === START sendPoll ===');
    print('[PollMessageHelper] Room: $roomId');
    print('[PollMessageHelper] localId: ${msg.localId}');
    print('[PollMessageHelper] id: ${msg.id}');

    await VChatController.I.nativeApi.local.message.insertMessage(msg);
    print('[PollMessageHelper] Local insert complete');
    
    final uploadMsg = await MessageFactory.createUploadMessage(msg);
    print('[PollMessageHelper] Upload model ready - calling addToQueue');
    
    await VMessageUploaderQueue.instance.addToQueue(uploadMsg);
    print('[PollMessageHelper] === END sendPoll ===');
  }
}
