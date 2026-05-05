// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:super_up_core/super_up_core.dart';
import 'loyalty_points_api.dart';
import '../interceptors.dart';

class LoyaltyPointsApiService {
  static LoyaltyPointsApi? _loyaltyPointsApi;

  LoyaltyPointsApiService._();

  Future<int> getUserLoyaltyPoints() async {
    final res = await _loyaltyPointsApi!.getUserLoyaltyPoints();
    throwIfNotSuccess(res);
    final data = extractDataFromResponse(res);
    return data['loyaltyPoints'] ?? 0;
  }

  static LoyaltyPointsApiService init({
    Uri? baseUrl,
    String? accessToken,
  }) {
    _loyaltyPointsApi ??= LoyaltyPointsApi.create(
      accessToken: accessToken,
      baseUrl: baseUrl ?? SConstants.sApiBaseUrl,
    );
    return LoyaltyPointsApiService._();
  }
}
