import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// GLOBAL PLUGIN - MUST BE ACCESSIBLE FROM ANYWHERE
final FlutterLocalNotificationsPlugin globalNotificationPlugin = FlutterLocalNotificationsPlugin();

// TOP-LEVEL HANDLER - CRITICAL FOR BACKGROUND ISOLATE
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse details) {
  // IMPORTANT: Use synchronous code at the start
  print('\n🚨🚨🚨 NOTIFICATION TAP BACKGROUND CALLED! 🚨🚨🚨');
  print('ActionId: ${details.actionId}');
  print('Input: ${details.input}');
  
  // Handle the reply asynchronously
  _handleReply(details);
}

Future<void> _handleReply(NotificationResponse details) async {
  try {
    if (details.actionId == "2") {
      final text = (details.input ?? "").trim();
      if (text.isEmpty) return;
      
      print('📝 Sending reply: "$text"');
      
      final payloadData = jsonDecode(details.payload ?? '{}');
      final roomId = payloadData['roomId'] ?? '';
      final token = payloadData['token'] ?? '';
      final baseUrl = payloadData['baseUrl'] ?? 'https://api.orbit.ke/api/v1';
      
      if (roomId.isEmpty || token.isEmpty) return;
      
      final uri = Uri.parse("$baseUrl/channel/$roomId/message/notification-reply");
      
      final response = await http.post(
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
      
      print('✅ Response: ${response.statusCode}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ REPLY SENT!');
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> initGlobalNotifications() async {
  print('🔧 Initializing global notifications...');
  
  const AndroidInitializationSettings androidSettings = 
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: null,
  );
  
  await globalNotificationPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {
      print('Foreground tap');
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
  
  print('✅ Global notifications initialized');
}
