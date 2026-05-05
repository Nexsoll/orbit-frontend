import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';

class OfferApiService {
  OfferApiService._();
  static final OfferApiService I = OfferApiService._();

  Uri _uriRespond(String roomId, String messageId) => Uri.parse(
      "${SConstants.sApiBaseUrl}/channel/$roomId/message/$messageId/offer/respond");

  Future<void> respond({
    required String roomId,
    required String messageId,
    required String status,
  }) async {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (token == null || token.isEmpty) {
      throw Exception('No auth token');
    }
    final res = await http
        .post(
          _uriRespond(roomId, messageId),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
            'Accept-Language': 'en',
          },
          body: jsonEncode({
            'status': status,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Offer respond failed: ${res.statusCode} ${res.body}');
    }
  }
}
