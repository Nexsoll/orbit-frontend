// Emergency Contacts API Service (mobile app)
// Provides endpoints to manage user emergency contacts

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/api_service/exceptions.dart';

class EmergencyContactsApiService {
  static Map<String, String> _headers() {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // GET /profile/emergency-contacts
  static Future<List<Map<String, dynamic>>> getMyContacts() async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/profile/emergency-contacts',
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(exception: (err['data'] ?? err['message'] ?? 'Failed to load contacts').toString());
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Failed with status ${res.statusCode}');
      }
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final list = decoded['data'] as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  // POST /profile/emergency-contacts
  static Future<Map<String, dynamic>> addContact({
    required String name,
    required String phone,
    String? relation,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/profile/emergency-contacts',
    );
    final body = {
      'name': name,
      'phone': phone,
      if (relation != null && relation.isNotEmpty) 'relation': relation,
    };
    final res = await http.post(uri, headers: _headers(), body: jsonEncode(body));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(exception: (err['data'] ?? err['message'] ?? 'Failed to add contact').toString());
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Failed with status ${res.statusCode}');
      }
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>;
  }

  // DELETE /profile/emergency-contacts/:id
  static Future<bool> deleteContact(String id) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/profile/emergency-contacts/$id',
    );
    final res = await http.delete(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(exception: (err['data'] ?? err['message'] ?? 'Failed to delete contact').toString());
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Failed with status ${res.statusCode}');
      }
    }
    return true;
  }
}
