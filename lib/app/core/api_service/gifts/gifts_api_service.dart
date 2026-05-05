// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:super_up_core/super_up_core.dart';
import '../interceptors.dart';
import 'gifts_api.dart';

class GiftsApiService {
  static GiftsApi? _giftsApi;

  GiftsApiService._();

  Future<List<Gift>> getGifts() async {
    final res = await _giftsApi!.getGifts();
    throwIfNotSuccess(res);
    final data = extractDataFromResponse(res) as List;
    return data.map((e) => Gift.fromMap(e)).toList();
  }

  static GiftsApiService init({
    Uri? baseUrl,
    String? accessToken,
    Map<String, String>? headers,
  }) {
    _giftsApi ??= GiftsApi.create(
      accessToken: accessToken,
      baseUrl: baseUrl ?? SConstants.sApiBaseUrl,
    );
    return GiftsApiService._();
  }
}
