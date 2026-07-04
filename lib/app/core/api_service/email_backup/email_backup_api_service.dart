import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';

/// Lightweight service that talks to the backend email-backup API.
///
/// Endpoints (all under /api/v1/email-backup):
///   GET  /settings         → get current backup settings
///   POST /settings/update  → create / update backup settings
///   POST /run              → trigger a manual backup now
///   GET  /history?limit=N  → list recent backup history
class EmailBackupApiService {
  EmailBackupApiService._();

  static final EmailBackupApiService _instance = EmailBackupApiService._();
  factory EmailBackupApiService() => _instance;

  // ── helpers ────────────────────────────────────────────────────────────

  Map<String, String> get _headers {
    final token =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${SConstants.sApiBaseUrl}/email-backup$path')
          .replace(queryParameters: query);

  String _extractMessage(String body) {
    try {
      final parsed = json.decode(body) as Map<String, dynamic>;
      return (parsed['data'] ?? parsed['message'] ?? 'Request failed')
          .toString();
    } catch (_) {
      return 'Request failed';
    }
  }

  void _throwIfFailed(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception(_extractMessage(res.body));
  }

  // ── public API ─────────────────────────────────────────────────────────

  /// Fetch the user's current email‑backup settings (may return null).
  Future<Map<String, dynamic>?> getSettings() async {
    final res = await http
        .get(_uri('/settings'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    _throwIfFailed(res);
    final body = json.decode(res.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>?;
  }

  /// Create or update backup settings.
  Future<Map<String, dynamic>> updateSettings({
    required String primaryEmail,
    String? secondaryEmail,
    required String frequency,
    required bool includeAttachments,
    required bool encrypted,
    String? encryptionSecret,
    required int sizeLimitMb,
    required List<String> categories,
  }) async {
    final payload = <String, dynamic>{
      'primaryEmail': primaryEmail,
      'frequency': frequency,
      'includeAttachments': includeAttachments,
      'encrypted': encrypted,
      'sizeLimitMb': sizeLimitMb,
      'categories': categories,
    };
    if (secondaryEmail != null && secondaryEmail.isNotEmpty) {
      payload['secondaryEmail'] = secondaryEmail;
    }
    if (encrypted && encryptionSecret != null && encryptionSecret.isNotEmpty) {
      payload['encryptionSecret'] = encryptionSecret;
    }

    final res = await http
        .post(
          _uri('/settings/update'),
          headers: _headers,
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 15));
    _throwIfFailed(res);
    final body = json.decode(res.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  /// Manually trigger a backup right now.
  Future<Map<String, dynamic>> runBackupNow() async {
    final res = await http
        .post(_uri('/run'), headers: _headers)
        .timeout(const Duration(seconds: 60));
    _throwIfFailed(res);
    final body = json.decode(res.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  /// Fetch recent backup history.
  Future<List<Map<String, dynamic>>> getHistory({int limit = 20}) async {
    final res = await http
        .get(_uri('/history', {'limit': limit.toString()}), headers: _headers)
        .timeout(const Duration(seconds: 15));
    _throwIfFailed(res);
    final body = json.decode(res.body) as Map<String, dynamic>;
    final list = body['data'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }
}
