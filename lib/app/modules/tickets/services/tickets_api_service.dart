import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:super_up/app/core/api_service/exceptions.dart';

class TicketsApiService {
  final http.Client _client;
  final Uri _base;

  TicketsApiService._(this._client, this._base);

  static TicketsApiService init() {
    return TicketsApiService._(http.Client(), Uri.parse(SConstants.sApiBaseUrl.toString()));
  }

  Map<String, String> _headers() {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    return {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      'accept': 'application/json',
    };
  }

  Future<List<Map<String, dynamic>>> listTickets({
    String? q,
    String? category,
    bool showAll = false,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = _base.replace(
      path: _joinPath(_base.path, 'tickets'),
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (showAll) 'showAll': 'true',
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

  Future<List<Map<String, dynamic>>> myTickets() async {
    final uri = _base.replace(path: _joinPath(_base.path, 'tickets/mine'));
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  Future<Map<String, dynamic>> getTicket(String id) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'tickets/$id'));
    final res = await _client.get(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> createTicket({
    required String name,
    required int priceKes,
    required String expiryDate,
    required int quantity,
    String? category,
    VPlatformFile? image,
  }) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'tickets'));

    // If there's an image, use multipart upload
    if (image != null) {
      final req = http.MultipartRequest('POST', uri);
      final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
      if (token != null && token.isNotEmpty) {
        req.headers['authorization'] = 'Bearer $token';
      }
      req.headers['accept'] = 'application/json';

      req.fields['name'] = name;
      req.fields['priceKes'] = priceKes.toString();
      req.fields['expiryDate'] = expiryDate;
      req.fields['quantity'] = quantity.toString();
      if (category != null && category.isNotEmpty) {
        req.fields['category'] = category;
      }

      final mf = await VPlatforms.getMultipartFile(source: image);
      req.files.add(mf);

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      _throwIfBad(res);
      final body = jsonDecode(res.body);
      return Map<String, dynamic>.from(body['data'] ?? {});
    }

    // No image - use regular JSON POST
    final res = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'priceKes': priceKes,
        'expiryDate': expiryDate,
        'quantity': quantity,
        if (category != null && category.isNotEmpty) 'category': category,
      }),
    );
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> buyTicket(String id) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'tickets/$id/buy'));
    final res = await _client.post(uri, headers: _headers());
    _throwIfBad(res);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<bool> deleteTicket(String id) async {
    final uri = _base.replace(path: _joinPath(_base.path, 'tickets/$id'));
    final res = await _client.delete(uri, headers: _headers());
    _throwIfBad(res);
    return true;
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
