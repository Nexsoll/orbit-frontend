import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';

import '../exceptions.dart';

class SellerApiService {
  static Map<String, String> _headers() {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // POST /sellers/applications
  static Future<Map<String, dynamic>> createApplication({
    required String idImageUrl,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/sellers/applications',
    );

    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'idImageUrl': idImageUrl,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(
          exception: (err['data'] ?? err['message'] ?? 'Submit failed').toString(),
        );
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Submit failed with status ${res.statusCode}');
      }
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>;
  }

  // GET /sellers/applications/my-latest
  static Future<Map<String, dynamic>?> myLatest() async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/sellers/applications/my-latest',
    );

    final res = await http.get(uri, headers: _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(
          exception: (err['data'] ?? err['message'] ?? 'Failed').toString(),
        );
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Failed with status ${res.statusCode}');
      }
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>?;
  }
}
