import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:super_up/app/core/api_service/exceptions.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

class MarketplaceApiService {
  final http.Client _client;
  final Uri _base;

  MarketplaceApiService._(this._client, this._base);

  static MarketplaceApiService init() {
    return MarketplaceApiService._(
      http.Client(),
      Uri.parse(SConstants.sApiBaseUrl.toString()),
    );
  }

  Map<String, String> _headers({
    bool withJson = true,
    bool requireAuth = false,
  }) {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);

    if (requireAuth && (token == null || token.isEmpty)) {
      throw SuperHttpBadRequest(exception: 'Please login again');
    }
    return {
      if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
      if (withJson) 'content-type': 'application/json',
      'accept': 'application/json',
    };
  }

  String _joinPath(String base, String extra) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final e = extra.startsWith('/') ? extra.substring(1) : extra;
    return '$b/$e';
  }

  void _throwIfBad(http.Response res, Uri uri) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    try {
      final body = jsonDecode(res.body);
      String msg;
      final data = (body is Map) ? body['data'] : null;
      final message = (body is Map) ? body['message'] : null;
      if (data is List) {
        msg = data.map((e) => e.toString()).join('\n');
      } else if (message is List) {
        msg = message.map((e) => e.toString()).join('\n');
      } else {
        msg = data?.toString() ?? message?.toString() ?? 'Request failed';
      }

      throw SuperHttpBadRequest(
        exception: '$msg (HTTP ${res.statusCode})\n$uri',
      );
    } catch (_) {
      final raw = res.body.trim();
      final snippet = raw.isEmpty
          ? ''
          : (raw.length > 400 ? raw.substring(0, 400) : raw);
      final suffix = snippet.isEmpty ? '' : '\n$snippet';
      throw SuperHttpBadRequest(
        exception: 'Request failed (HTTP ${res.statusCode})\n$uri$suffix',
      );
    }
  }

  Future<List<String>> getCategories() async {
    final uri = _base.replace(path: _joinPath(_base.path, 'marketplace/categories'));
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is List) {
      return List<String>.from(data.map((e) => e.toString()));
    }
    return const [];
  }

  Future<Map<String, dynamic>> myAnalytics() async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/my/analytics'),
    );
    final res = await _client.get(uri, headers: _headers(requireAuth: true));
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> incrementListingViewPublic(String id) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/public/$id/view'),
    );
    final res = await _client.patch(uri, headers: _headers());
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> getListingLikeState(String id) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/$id/like'),
    );
    final res = await _client.get(uri, headers: _headers(requireAuth: true));
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> toggleListingLike(String id) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/$id/like'),
    );
    final res = await _client.post(uri, headers: _headers(requireAuth: true));
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<List<Map<String, dynamic>>> feed({
    String? category,
    String? q,
    int limit = 30,
    double? lat,
    double? lng,
    double? radiusKm,
    int? minPrice,
    int? maxPrice,
    String? condition,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/feed'),
      queryParameters: {
        if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (lat != null) 'lat': lat.toString(),
        if (lng != null) 'lng': lng.toString(),
        if (radiusKm != null) 'radiusKm': radiusKm.toString(),
        if (minPrice != null) 'minPrice': minPrice.toString(),
        if (maxPrice != null) 'maxPrice': maxPrice.toString(),
        if (condition != null && condition.trim().isNotEmpty) 'condition': condition.trim(),
        'limit': '$limit',
      },
    );
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is List) {
      return List<Map<String, dynamic>>.from(
        data.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    return const [];
  }

  Future<Map<String, dynamic>> saveDraft(Map<String, dynamic> payload) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'marketplace/listings/drafts'));
    final res = await _client.post(
      uri,
      headers: _headers(requireAuth: true),
      body: jsonEncode(payload),
    );
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> preview(Map<String, dynamic> payload) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'marketplace/listings/preview'));
    final res = await _client.post(
      uri,
      headers: _headers(requireAuth: true),
      body: jsonEncode(payload),
    );
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> savePreview(Map<String, dynamic> payload) async {
    final uri =
        _base.replace(path: _joinPath(_base.path, 'marketplace/listings/preview/save'));
    final res = await _client.post(
      uri,
      headers: _headers(requireAuth: true),
      body: jsonEncode(payload),
    );
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> publish(Map<String, dynamic> payload) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'marketplace/listings/publish'));
    final res = await _client.post(
      uri,
      headers: _headers(requireAuth: true),
      body: jsonEncode(payload),
    );
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> hideListing(String id) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/$id/hide'),
    );
    final res = await _client.patch(
      uri,
      headers: _headers(requireAuth: true),
    );
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> unhideListing(String id) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/$id/unhide'),
    );
    final res = await _client.patch(
      uri,
      headers: _headers(requireAuth: true),
    );
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> markListingSold(
    String id, {
    num? soldPrice,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/$id/sold'),
    );
    final res = await _client.patch(
      uri,
      headers: _headers(requireAuth: true),
      body: jsonEncode({
        if (soldPrice != null) 'soldPrice': soldPrice,
      }),
    );
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<List<Map<String, dynamic>>> myListings({String? status}) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/my'),
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
    final res = await _client.get(uri, headers: _headers(requireAuth: true));
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is List) {
      return List<Map<String, dynamic>>.from(
        data.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    return const [];
  }

  Future<Map<String, dynamic>> getListing(String id) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'marketplace/listings/$id'));
    final res = await _client.get(uri, headers: _headers(requireAuth: true));
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> getListingPublic(String id) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/public/$id'),
    );
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<bool> deleteListing(String id) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'marketplace/listings/$id'));
    final res = await _client.delete(uri, headers: _headers(requireAuth: true));
    _throwIfBad(res, uri);
    return true;
  }

  Future<bool> reportListing({
    required String id,
    required String content,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/$id/report'),
    );
    final res = await _client.post(
      uri,
      headers: _headers(requireAuth: true),
      body: jsonEncode({
        'content': content,
      }),
    );
    _throwIfBad(res, uri);
    return true;
  }

  Future<Map<String, dynamic>> uploadMedia(VPlatformFile file) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/media/upload'),
    );

    final req = http.MultipartRequest('POST', uri);
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (token != null && token.isNotEmpty) {
      req.headers['authorization'] = 'Bearer $token';
    }
    req.headers['accept'] = 'application/json';

    final mf = await _toMultipartFile(file);
    req.files.add(mf);

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<http.MultipartFile> _toMultipartFile(VPlatformFile file) async {
    if (file.bytes != null) {
      final fn = file.name;
      final mime = (file.getMimeType?.trim().isNotEmpty ?? false)
          ? file.getMimeType!.trim()
          : (lookupMimeType(fn, headerBytes: file.bytes) ?? _fallbackMimeFromName(fn));
      final ct = _tryParseMediaType(mime);
      return http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: fn,
        contentType: ct,
      );
    }
    if (file.fileLocalPath != null) {
      final p = file.fileLocalPath!;
      final fn = file.name.isNotEmpty
          ? file.name
          : p.split(RegExp(r'[\\/]+')).last;
      final mime = (file.getMimeType?.trim().isNotEmpty ?? false)
          ? file.getMimeType!.trim()
          : (lookupMimeType(p) ?? _fallbackMimeFromName(fn));
      final ct = _tryParseMediaType(mime);
      return http.MultipartFile.fromPath(
        'file',
        p,
        filename: fn,
        contentType: ct,
      );
    }
    throw SuperHttpBadRequest(exception: 'Invalid file: no path or bytes');
  }

  MediaType? _tryParseMediaType(String? mime) {
    final m = (mime ?? '').trim();
    if (m.isEmpty) return null;
    final parts = m.split('/');
    if (parts.length != 2) return null;
    final type = parts[0].trim();
    final subType = parts[1].trim();
    if (type.isEmpty || subType.isEmpty) return null;
    return MediaType(type, subType);
  }

  String? _fallbackMimeFromName(String name) {
    final n = name.trim().toLowerCase();
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic') || n.endsWith('.heif')) return 'image/heic';
    if (n.endsWith('.mp4') || n.endsWith('.m4v')) return 'video/mp4';
    if (n.endsWith('.mov')) return 'video/quicktime';
    if (n.endsWith('.avi')) return 'video/x-msvideo';
    if (n.endsWith('.mkv')) return 'video/x-matroska';
    return null;
  }

  // =================== Reviews ===================

  Future<Map<String, dynamic>> getListingReviews(String listingId) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/$listingId/reviews'),
    );
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> submitReview({
    required String listingId,
    required int rating,
    String? text,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/$listingId/review'),
    );
    final res = await _client.post(
      uri,
      headers: _headers(requireAuth: true),
      body: jsonEncode({
        'rating': rating,
        if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      }),
    );
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> deleteReview(String listingId) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/$listingId/review'),
    );
    final res = await _client.delete(uri, headers: _headers(requireAuth: true));
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  // =================== Promotions ===================

  Future<Map<String, dynamic>> promoteListing({
    required String listingId,
    required String plan,
    required double paidAmount,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/$listingId/promote'),
    );
    final res = await _client.post(
      uri,
      headers: _headers(requireAuth: true),
      body: jsonEncode({
        'plan': plan,
        'paidAmount': paidAmount,
      }),
    );
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<List<Map<String, dynamic>>> getFeaturedListings({int limit = 20}) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/featured'),
      queryParameters: {'limit': limit.toString()},
    );
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMyPromotedListings() async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/my/promoted'),
    );
    final res = await _client.get(uri, headers: _headers(requireAuth: true));
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getPublishedListingsForPromotion() async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'marketplace/listings/my'),
      queryParameters: {'status': 'published'},
    );
    final res = await _client.get(uri, headers: _headers(requireAuth: true));
    _throwIfBad(res, uri);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }
}
