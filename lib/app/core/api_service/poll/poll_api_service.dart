import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';

class PollApiService {
  PollApiService._();
  static final PollApiService I = PollApiService._();

  Uri _uriVote(String roomId, String messageId) => Uri.parse(
      "${SConstants.sApiBaseUrl}/channel/$roomId/message/$messageId/poll/vote");
  Uri _uriResults(String roomId, String messageId) => Uri.parse(
      "${SConstants.sApiBaseUrl}/channel/$roomId/message/$messageId/poll/results");

  Future<void> vote({
    required String roomId,
    required String messageId,
    required String optionId,
  }) async {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (token == null || token.isEmpty) {
      throw Exception('No auth token');
    }
    final res = await http
        .post(_uriVote(roomId, messageId),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
              'Accept-Language': 'en',
            },
            body: jsonEncode({
              'optionIds': [optionId],
            }))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Vote failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<Map<String, dynamic>> results({
    required String roomId,
    required String messageId,
  }) async {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (token == null || token.isEmpty) {
      throw Exception('No auth token');
    }
    final res = await http
        .get(_uriResults(roomId, messageId), headers: {
      'authorization': 'Bearer $token',
      'Accept-Language': 'en',
    }).timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Fetch results failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    // backend wraps with {data: ...}
    return (data is Map && data['data'] is Map)
        ? (data['data'] as Map<String, dynamic>)
        : (data as Map<String, dynamic>);
  }
}
