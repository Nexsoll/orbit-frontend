import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../../native_notification_channel.dart';

class CustomNotificationSoundService {
  static const _storeKey = 'custom_notification_sounds_v1';

  // roomId -> { uri: String, title: String, channelId: String }
  static Future<Map<String, dynamic>> _getAll() async {
    await VAppPref.init();
    final map = VAppPref.getMap(_storeKey);
    return map ?? <String, dynamic>{};
  }

  static Future<void> _saveAll(Map<String, dynamic> data) async {
    await VAppPref.setMap(_storeKey, data);
  }

  static String _channelIdFor(String roomId) => 'orbit_room_sound_$roomId';

  static Future<Map<String, dynamic>?> getForRoom(String roomId) async {
    final all = await _getAll();
    final v = all[roomId];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static Future<String?> getDisplayName(String roomId) async {
    final v = await getForRoom(roomId);
    return v?['title'] as String?;
  }

  static Future<void> clearForRoom(String roomId) async {
    final all = await _getAll();
    if (all.containsKey(roomId)) {
      all.remove(roomId);
      await _saveAll(all);
    }
  }

  static Future<void> pickAndSetForRoom(BuildContext context, String roomId, {String? channelName}) async {
    if (!VPlatforms.isAndroid) {
      await VAppAlert.showOkAlertDialog(
        context: context,
        title: 'Not supported',
        content: 'Custom notification sounds are supported on Android only.',
      );
      return;
    }

    try {
      final res = await NativeNotificationChannel.pickNotificationSound();
      if (res == null) return;
      final uri = res['uri'];
      final title = res['title'] ?? 'Custom';
      if (uri == null || uri.isEmpty) return;

      final all = await _getAll();
      final channelId = _channelIdFor(roomId);
      all[roomId] = {
        'uri': uri,
        'title': title,
        'channelId': channelId,
      };
      await _saveAll(all);

      // Create or update the native channel immediately so it exists when notifications arrive
      await NativeNotificationChannel.createOrUpdateChannel(
        channelId: channelId,
        name: channelName ?? 'Chat with $roomId',
        description: 'Custom sound for this chat',
        soundUri: uri,
      );

      VAppAlert.showSuccessSnackBar(context: context, message: 'Custom sound set to "$title"');
    } catch (e) {
      if (kDebugMode) print('pickAndSetForRoom error: $e');
      VAppAlert.showErrorSnackBar(context: context, message: 'Failed to set custom sound');
    }
  }
}
