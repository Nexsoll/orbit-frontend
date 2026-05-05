import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/api_service/exceptions.dart';

class JobsApiService {
  final http.Client _client;
  final Uri _base;

  JobsApiService._(this._client, this._base);

  static JobsApiService init() {
    return JobsApiService._(http.Client(), Uri.parse(SConstants.sApiBaseUrl.toString()));
  }

  Map<String, String> _headers() {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    return {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      'accept': 'application/json',
    };
  }

  Future<List<Map<String, dynamic>>> listJobs({
    String? q,
    String? category,
    String? location,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'jobs'),
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (location != null && location.isNotEmpty) 'location': location,
        'page': '$page',
        'limit': '$limit',
      },
    );
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map && data['docs'] is List) {
      return List<Map<String, dynamic>>.from(data['docs']);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  Future<Map<String, dynamic>> getJob(String id) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'jobs/$id'));
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> updateJob({
    required String id,
    String? title,
    String? description,
    String? qualifications,
    String? category,
    String? location,
    int? salaryMin,
    int? salaryMax,
    bool includeSalaryMin = false,
    bool includeSalaryMax = false,
  }) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'jobs/$id'));
    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (qualifications != null) 'qualifications': qualifications,
      if (category != null) 'category': category,
      if (location != null) 'location': location,
      if (includeSalaryMin) 'salaryMin': salaryMin,
      if (includeSalaryMax) 'salaryMax': salaryMax,
    };
    final res = await _client.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<bool> deleteJob(String id) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'jobs/$id'));
    final res = await _client.delete(uri, headers: _headers());
    _throwIfBad(res);
    return true;
  }

  Future<Map<String, dynamic>> createJob({
    required String title,
    required String description,
    required String qualifications,
    required String category,
    required String location,
    int? salaryMin,
    int? salaryMax,
  }) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'jobs'));
    final res = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'title': title,
        'description': description,
        'qualifications': qualifications,
        'category': category,
        'location': location,
        if (salaryMin != null) 'salaryMin': salaryMin,
        if (salaryMax != null) 'salaryMax': salaryMax,
      }),
    );
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<List<String>> getCategories() async {
    final uri = _base.replace(path: _joinPath(_base.path, 'jobs/categories'));
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is List) {
      return List<String>.from(data.map((e) => e.toString()));
    }
    return const [];
  }

  Future<Map<String, dynamic>?> getMySeekerProfile() async {
    final uri = _base.replace(path: _joinPath(_base.path, 'job-seekers/me'));
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    return body['data'] == null ? null : Map<String, dynamic>.from(body['data']);
  }

  Future<Map<String, dynamic>> updateMySeekerProfile({
    String? skills,
    int? yearsExperience,
    String? cvUrl,
  }) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'job-seekers/me'));
    final res = await _client.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({
        if (skills != null) 'skills': skills,
        if (yearsExperience != null) 'yearsExperience': yearsExperience,
        if (cvUrl != null) 'cvUrl': cvUrl,
      }),
    );
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  String _joinPath(String base, String extra) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final e = extra.startsWith('/') ? extra.substring(1) : extra;
    return '$b/$e';
  }

  void _throwIfBad(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    try {
      final body = jsonDecode(res.body);
      final msg = body['data']?.toString() ?? body['message']?.toString() ?? 'Request failed (${res.statusCode})';
      throw SuperHttpBadRequest(exception: msg);
    } catch (_) {
      throw SuperHttpBadRequest(exception: 'Request failed (${res.statusCode})');
    }
  }
}
