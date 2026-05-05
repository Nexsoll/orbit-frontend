import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/api_service/exceptions.dart';
import 'package:v_platform/v_platform.dart';

class MusicApiService {
  final http.Client _client;
  final Uri _base;

  MusicApiService._(this._client, this._base);

  static MusicApiService init() {
    return MusicApiService._(
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

  Future<Map<String, dynamic>> listMusic({
    String? category,
    String? mediaType,
    String? query,
    String? uploaderId,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'music'),
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (category != null && category.isNotEmpty && category != 'all')
          'category': category,
        if (mediaType != null && mediaType.isNotEmpty && mediaType != 'all')
          'mediaType': mediaType,
        if (uploaderId != null && uploaderId.isNotEmpty) 'uploaderId': uploaderId,
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

  Future<Map<String, dynamic>> uploadMusic({
    required VPlatformFile file,
    String? title,
    String? description,
    String? genre,
    int? durationMs,
    String? category,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'music'),
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
    if (genre != null && genre.trim().isNotEmpty) {
      request.fields['genre'] = genre.trim();
    }
    if (durationMs != null) {
      request.fields['durationMs'] = durationMs.toString();
    }
    if (category != null && category.trim().isNotEmpty) {
      request.fields['category'] = category.trim();
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

  Future<bool> reportMusic({
    required String id,
    required String content,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'music/$id/report'),
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

  Future<Map<String, dynamic>> incrementPlay(String id) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'music/$id/play'),
    );
    final res = await _client.post(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> toggleLike(String id) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'music/$id/like'),
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
    String musicId, {
    int page = 1,
    int limit = 50,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'music/$musicId/comments'),
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
    required String musicId,
    required String text,
    String? parentCommentId,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'music/$musicId/comments'),
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
    required String musicId,
    required String commentId,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'music/$musicId/comments/$commentId'),
    );
    final res = await _client.delete(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> deleteMusic(String id) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'music/$id'),
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
    required String musicId,
    required num amount,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'music/$musicId/support'),
    );
    final res = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'amount': amount,
      }),
    );
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getArtists() async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'music/artists'),
    );
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return <Map<String, dynamic>>[];
  }

  void _throwIfBad(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    try {
      final body = jsonDecode(res.body);
      // Try multiple possible error message fields
      String? msg;
      if (body is Map) {
        msg = body['message']?.toString() ??
              body['data']?.toString() ??
              body['error']?.toString() ??
              body['msg']?.toString();
      }
      msg ??= 'Request failed (${res.statusCode})';
      throw SuperHttpBadRequest(exception: msg);
    } catch (e) {
      // If json parsing fails or it's already a SuperHttpBadRequest, rethrow
      if (e is SuperHttpBadRequest) rethrow;
      throw SuperHttpBadRequest(
        exception: 'Request failed (${res.statusCode})',
      );
    }
  }
}
