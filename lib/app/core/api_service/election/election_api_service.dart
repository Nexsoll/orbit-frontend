import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';

class ElectionApiService {
  ElectionApiService._();
  static final ElectionApiService I = ElectionApiService._();

  Uri _uriActive() => Uri.parse("${SConstants.sApiBaseUrl}/elections/active");
  Uri _uriVote(String electionId) => Uri.parse("${SConstants.sApiBaseUrl}/elections/$electionId/vote");

  Future<List<Map<String, dynamic>>> getActiveElections() async {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (token == null || token.isEmpty) {
      throw Exception('No auth token');
    }
    final res = await http.get(_uriActive(), headers: {
      'authorization': 'Bearer $token',
      'Accept-Language': 'en',
    }).timeout(const Duration(seconds: 10));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Fetch active elections failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    final list = (data is Map && data['data'] is List)
        ? (data['data'] as List)
        : (data as List);
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> vote({
    required String electionId,
    required String optionId,
  }) async {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (token == null || token.isEmpty) {
      throw Exception('No auth token');
    }
    final res = await http
        .post(_uriVote(electionId),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
              'Accept-Language': 'en',
            },
            body: jsonEncode({
              'optionId': optionId,
            }))
        .timeout(const Duration(seconds: 10));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Vote failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    return (data is Map && data['data'] is Map)
        ? (data['data'] as Map<String, dynamic>)
        : (data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> removeVote({
    required String electionId,
  }) async {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (token == null || token.isEmpty) {
      throw Exception('No auth token');
    }
    final res = await http
        .delete(_uriVote(electionId), headers: {
          'authorization': 'Bearer $token',
          'Accept-Language': 'en',
        })
        .timeout(const Duration(seconds: 10));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Remove vote failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    return (data is Map && data['data'] is Map)
        ? (data['data'] as Map<String, dynamic>)
        : (data as Map<String, dynamic>);
  }
}
