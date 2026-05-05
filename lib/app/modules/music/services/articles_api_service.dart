import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/api_service/exceptions.dart';
import 'package:v_platform/v_platform.dart';

class ArticlesApiService {
  final http.Client _client;
  final Uri _base;

  ArticlesApiService._(this._client, this._base);

  static ArticlesApiService init() {
    return ArticlesApiService._(
      http.Client(),
      Uri.parse(SConstants.sApiBaseUrl.toString()),
    );
  }

  Map<String, String> _headers({bool isMultipart = false}) {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    final headers = <String, String>{
      'authorization': 'Bearer $token',
      'accept': 'application/json',
    };
    if (!isMultipart) {
      headers['content-type'] = 'application/json';
    }
    return headers;
  }

  String _joinPath(String base, String extra) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final e = extra.startsWith('/') ? extra.substring(1) : extra;
    return '$b/$e';
  }

  Future<Map<String, dynamic>> listArticles({
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'articles'),
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );

    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map) {
      return {
        'docs': data['docs'] is List ? List<Map<String, dynamic>>.from(data['docs']) : <Map<String, dynamic>>[],
        'total': data['total'] ?? 0,
        'page': data['page'] ?? page,
        'limit': data['limit'] ?? limit,
      };
    }
    if (data is List) {
      return {
        'docs': List<Map<String, dynamic>>.from(data),
        'total': data.length,
        'page': page,
        'limit': limit,
      };
    }
    return {
      'docs': <Map<String, dynamic>>[],
      'total': 0,
      'page': page,
      'limit': limit,
    };
  }

  Future<Map<String, dynamic>> uploadPdf({
    required VPlatformFile file,
    String? title,
    String? description,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'articles'),
    );

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers(isMultipart: true));

    final multipartFile = await VPlatforms.getMultipartFile(source: file);
    request.files.add(multipartFile);

    if (title != null && title.trim().isNotEmpty) {
      request.fields['title'] = title.trim();
    }
    if (description != null && description.trim().isNotEmpty) {
      request.fields['description'] = description.trim();
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> toggleLike(String id) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'articles/$id/like'),
    );
    final res = await _client.post(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> listComments(
    String articleId, {
    int page = 1,
    int limit = 50,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'articles/$articleId/comments'),
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
      },
    );
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map) {
      return {
        'docs': data['docs'] is List ? List<Map<String, dynamic>>.from(data['docs']) : <Map<String, dynamic>>[],
        'total': data['total'] ?? 0,
        'page': data['page'] ?? page,
        'limit': data['limit'] ?? limit,
      };
    }
    if (data is List) {
      return {
        'docs': List<Map<String, dynamic>>.from(data),
        'total': data.length,
        'page': page,
        'limit': limit,
      };
    }
    return {
      'docs': <Map<String, dynamic>>[],
      'total': 0,
      'page': page,
      'limit': limit,
    };
  }

  Future<Map<String, dynamic>> addComment({
    required String articleId,
    required String text,
    String? parentCommentId,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'articles/$articleId/comments'),
    );
    final res = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'text': text,
        if (parentCommentId != null && parentCommentId.isNotEmpty)
          'parentCommentId': parentCommentId,
      }),
    );
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> deleteComment({
    required String articleId,
    required String commentId,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'articles/$articleId/comments/$commentId'),
    );
    final res = await _client.delete(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> support({
    required String articleId,
    required num amount,
    required String phone,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'articles/$articleId/support'),
    );
    final res = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'amount': amount, 'phone': phone}),
    );
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> deleteArticle(String id) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'articles/$id'),
    );
    final res = await _client.delete(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<bool> reportArticle({
    required String id,
    required String content,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'articles/$id/report'),
    );
    final res = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'content': content,
      }),
    );
    _throwIfBad(res);
    return true;
  }

  void _throwIfBad(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    try {
      final body = jsonDecode(res.body);
      final msg = body['data']?.toString() ??
          body['message']?.toString() ??
          'Request failed (${res.statusCode})';
      throw SuperHttpBadRequest(exception: msg);
    } catch (_) {
      throw SuperHttpBadRequest(
        exception: 'Request failed (${res.statusCode})',
      );
    }
  }
}
