import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';

/// CRITICAL: This MUST be a top-level function in the main app
/// for background isolate to access it properly
@pragma('vm:entry-point')
Future<void> notificationReplyHandler(NotificationResponse event) async {
  print(
      '🔔 DEBUG: Notification handler triggered - ActionId: ${event.actionId}');

  try {
    if (event.actionId == "2") {
      // Reply action
      final text = (event.input ?? "").trim();
      print('📝 DEBUG: Reply text: "$text"');

      if (text.isEmpty) {
        print('⚠️ DEBUG: Empty reply text, skipping');
        return;
      }

      // Parse the JSON payload
      Map<String, dynamic> payloadData;
      try {
        payloadData = jsonDecode(event.payload ?? '{}');
        print('📦 DEBUG: Payload parsed successfully');
      } catch (e) {
        print('❌ DEBUG: Failed to parse payload: $e');
        return;
      }

      final roomId = payloadData['roomId'] ?? '';
      final token = payloadData['token'] ?? '';
      final baseUrl =
          payloadData['baseUrl'] ?? SConstants.sApiBaseUrl.toString();

      print('🔑 DEBUG: RoomId: $roomId');
      print(
          '🔑 DEBUG: Token: ${token.isNotEmpty ? "present (${token.substring(0, 20)}...)" : "missing"}');
      print('🔑 DEBUG: BaseUrl: $baseUrl');

      if (roomId.isEmpty || token.isEmpty) {
        print('❌ DEBUG: Missing roomId or token');
        return;
      }

      final localId = 'notif_reply_${DateTime.now().millisecondsSinceEpoch}';
      final uri =
          Uri.parse("$baseUrl/channel/$roomId/message/notification-reply");

      print('🚀 DEBUG: Sending POST request to: ${uri.toString()}');

      final requestBody = {
        'content': text,
        'roomId': roomId,
        'localId': localId,
        'platform': 'notification',
      };

      print('📤 DEBUG: Request body: ${jsonEncode(requestBody)}');

      try {
        final res = await http
            .post(
          uri,
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
            'clint-version': '2.0.0',
            'Accept-Language': 'en',
          },
          body: jsonEncode(requestBody),
        )
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⏱️ DEBUG: Request timed out after 10 seconds');
            throw 'Request timed out';
          },
        );

        print('📥 DEBUG: Response received - Status: ${res.statusCode}');
        print('📥 DEBUG: Response body: ${res.body}');

        if (res.statusCode >= 200 && res.statusCode < 300) {
          print('✅ SUCCESS: Reply sent successfully!');
        } else {
          print('❌ FAILED: Status ${res.statusCode} - ${res.body}');
        }
      } catch (e) {
        print('❌ ERROR: Request failed - $e');
      }
    } else if (event.actionId == "1") {
      // Mark as read action
      print('👁️ DEBUG: Mark as read action triggered');

      Map<String, dynamic> payloadData;
      try {
        payloadData = jsonDecode(event.payload ?? '{}');
      } catch (e) {
        print('❌ DEBUG: Failed to parse payload for mark read: $e');
        return;
      }

      final roomId = payloadData['roomId'] ?? '';
      final token = payloadData['token'] ?? '';
      final baseUrl =
          payloadData['baseUrl'] ?? SConstants.sApiBaseUrl.toString();

      if (roomId.isNotEmpty && token.isNotEmpty) {
        try {
          final res = await http.patch(
            Uri.parse("$baseUrl/channel/$roomId/deliver"),
            headers: {
              'authorization': 'Bearer $token',
              'clint-version': '2.0.0',
              'Accept-Language': 'en',
            },
          );

          if (res.statusCode == 200) {
            print('✅ Marked as read successfully');
          } else {
            print('❌ Mark read failed - Status: ${res.statusCode}');
          }
        } catch (e) {
          print('❌ Mark read error: $e');
        }
      }
    } else {
      print('❓ DEBUG: Unknown action ID: ${event.actionId}');
    }
  } catch (e, stack) {
    print('💥 CRITICAL ERROR in notification handler: $e');
    print('Stack trace: $stack');
  }
}
