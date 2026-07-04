import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';
import 'dart:convert';

// CRITICAL: Top-level function with pragma for background isolate
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print('🚨🚨🚨 BACKGROUND HANDLER INVOKED! 🚨🚨🚨');
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    print(
        'notification action tapped with input: ${notificationResponse.input}');

    // Send the reply
    _sendReply(notificationResponse);
  }
}

void _sendReply(NotificationResponse response) async {
  try {
    final text = response.input?.trim() ?? '';
    if (text.isEmpty) return;

    print('📤 Sending reply: "$text"');

    final payloadData = jsonDecode(response.payload ?? '{}');
    final roomId = payloadData['roomId'] ?? '';
    final token = payloadData['token'] ?? '';
    final baseUrl = payloadData['baseUrl'] ?? SConstants.sApiBaseUrl.toString();

    if (roomId.isEmpty || token.isEmpty) {
      print('Missing roomId or token');
      return;
    }

    final uri =
        Uri.parse("$baseUrl/channel/$roomId/message/notification-reply");

    final res = await http.post(
      uri,
      headers: {
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
        'clint-version': '2.0.0',
        'Accept-Language': 'en',
      },
      body: jsonEncode({
        'content': text,
        'roomId': roomId,
        'localId': 'notif_${DateTime.now().millisecondsSinceEpoch}',
        'platform': 'notification',
      }),
    );

    print('✅ Response: ${res.statusCode} - ${res.body}');
  } catch (e) {
    print('❌ Error sending reply: $e');
  }
}
