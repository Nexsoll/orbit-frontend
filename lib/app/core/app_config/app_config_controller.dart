// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:super_up/app/core/api_service/api_service.dart';
import 'package:super_up_core/super_up_core.dart';

class VAppConfigController {
  final ProfileApiService _profileApiService;

  VAppConfigController(this._profileApiService);

  Future<void> refreshAppConfig() async {
    await vSafeApiCall<AppConfigModel>(
      request: () async {
        return _profileApiService.appConfig();
      },
      onSuccess: (response) async {
        await VAppPref.setMap(
          SStorageKeys.appConfigModelData.name,
          response.toMap(),
        );
      },
      onError: (exception, trace) {
        if (kDebugMode) {
          print(exception);
          print(trace);
        }
      },
    );
  }

  static AppConfigModel get appConfig {
    final cachedConfig = VAppPref.getMap(SStorageKeys.appConfigModelData.name);
    try {
      if (cachedConfig != null) {
        return AppConfigModel.fromMap(cachedConfig);
      }
    } catch (err) {
      if (kDebugMode) {
        print(err);
      }
    }
    return AppConfigModel.init();
  }
}
