import 'package:flutter/services.dart';

class NativeNotificationChannel {
  static const MethodChannel _channel = MethodChannel('com.orbit.ke/notifications');

  // Pick a system notification sound (Android only). Returns {uri, title} or null.
  static Future<Map<String, String>?> pickNotificationSound() async {
    try {
      final res = await _channel.invokeMethod('pickNotificationSound');
      if (res is Map) {
        return res.cast<String, String>();
      }
      return null;
    } catch (e) {
      print('❌ pickNotificationSound error: $e');
      return null;
    }
  }

  // Create or update a notification channel with a custom sound (Android O+)
  static Future<bool> createOrUpdateChannel({
    required String channelId,
    required String name,
    required String description,
    required String soundUri,
  }) async {
    try {
      final ok = await _channel.invokeMethod('createOrUpdateChannel', {
        'channelId': channelId,
        'name': name,
        'description': description,
        'soundUri': soundUri,
      });
      return ok == true;
    } catch (e) {
      print('❌ createOrUpdateChannel error: $e');
      return false;
    }
  }

  static Future<bool> showNotificationWithReply({
    required int id,
    required String title,
    required String body,
    required String payload,
    String? channelId,
  }) async {
    try {
      print('🔔 Calling native notification method');
      final result = await _channel.invokeMethod('showNotificationWithReply', {
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
        if (channelId != null) 'channelId': channelId,
      });
      print('✅ Native notification method called successfully');
      return result == true;
    } catch (e) {
      print('❌ Error calling native notification: $e');
      return false;
    }
  }
}
