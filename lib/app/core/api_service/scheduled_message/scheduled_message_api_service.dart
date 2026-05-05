import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';

class ScheduledMessageApiService {
  ScheduledMessageApiService._();
  static final ScheduledMessageApiService I = ScheduledMessageApiService._();

  Uri _base(String path) => Uri.parse("${SConstants.sApiBaseUrl}$path");

  Future<Map<String, dynamic>> schedule({
    required String roomId,
    required String content,
    required String localId,
    required DateTime scheduledAt,
    bool isEncrypted = false,
    bool isOneSeen = false,
    String? platform,
    Map<String, dynamic>? attachment,
    String? messageType, // defaults to Text on backend
  }) async {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (token == null || token.isEmpty) {
      throw Exception('No auth token');
    }
    final body = {
      'roomId': roomId,
      'content': content,
      'localId': localId,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      if (isEncrypted) 'isEncrypted': 'true',
      if (isOneSeen) 'isOneSeen': 'true',
      if (platform != null) 'platform': platform,
      if (attachment != null) 'attachment': attachment,
      if (messageType != null) 'messageType': messageType,
    };
    final res = await http
        .post(_base('/scheduled-message'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
              'Accept-Language': 'en',
            },
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Schedule failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    return (data is Map && data['data'] is Map)
        ? (data['data'] as Map<String, dynamic>)
        : (data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> listRoomPending(String roomId) async {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (token == null || token.isEmpty) {
      throw Exception('No auth token');
    }
    final res = await http.get(_base('/scheduled-message/room/$roomId'), headers: {
      'authorization': 'Bearer $token',
      'Accept-Language': 'en',
    }).timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    final payload = (data is Map && data['data'] is List)
        ? (data['data'] as List)
        : (data as List);
    return payload.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<bool> cancel(String id) async {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (token == null || token.isEmpty) {
      throw Exception('No auth token');
    }
    final res = await http
        .delete(_base('/scheduled-message/$id'), headers: {
      'authorization': 'Bearer $token',
      'Accept-Language': 'en',
    }).timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Cancel failed: ${res.statusCode} ${res.body}');
    }
    return true;
  }
}
