import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';
import 'dart:convert';

// GLOBAL PLUGIN INSTANCE - CRITICAL FOR BACKGROUND HANDLING
final FlutterLocalNotificationsPlugin notificationPlugin =
    FlutterLocalNotificationsPlugin();

// GLOBAL HANDLER - MUST BE TOP-LEVEL FOR BACKGROUND ISOLATE
@pragma('vm:entry-point')
Future<void> handleNotificationReply(NotificationResponse details) async {
  print('\n🚨🚨🚨 NOTIFICATION REPLY HANDLER TRIGGERED! 🚨🚨🚨');
  print('ActionId: ${details.actionId}');
  print('Input: ${details.input}');
  print('Payload: ${details.payload}');

  try {
    if (details.actionId == "2") {
      final text = (details.input ?? "").trim();
      if (text.isEmpty) {
        print('Empty text, skipping');
        return;
      }

      print('📝 Reply text: "$text"');

      Map<String, dynamic> payloadData;
      try {
        payloadData = jsonDecode(details.payload ?? '{}');
      } catch (e) {
        print('Failed to parse payload: $e');
        return;
      }

      final roomId = payloadData['roomId'] ?? '';
      final token = payloadData['token'] ?? '';
      final baseUrl =
          payloadData['baseUrl'] ?? SConstants.sApiBaseUrl.toString();

      if (roomId.isEmpty || token.isEmpty) {
        print('Missing roomId or token');
        return;
      }

      print('📤 Sending reply to room: $roomId');

      final uri =
          Uri.parse("$baseUrl/channel/$roomId/message/notification-reply");
      final response = await http
          .post(
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
          )
          .timeout(Duration(seconds: 10));

      print('Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅✅✅ REPLY SENT SUCCESSFULLY! ✅✅✅');
      } else {
        print('❌ Failed: ${response.statusCode}');
      }
    } else if (details.actionId == "1") {
      print('Mark as read action');
    }
  } catch (e, stack) {
    print('❌ Error in handler: $e');
    print('Stack: $stack');
  }
}

Future<void> initializeNotificationPlugin() async {
  print('🔧 Initializing global notification plugin...');

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
    iOS: null,
  );

  await notificationPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {
      print('Foreground response');
    },
    onDidReceiveBackgroundNotificationResponse: handleNotificationReply,
  );

  print('✅ Global notification plugin initialized');
}
