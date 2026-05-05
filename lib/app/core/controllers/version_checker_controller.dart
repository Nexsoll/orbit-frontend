// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:universal_html/html.dart';
import 'package:v_platform/v_platform.dart';

import '../api_service/profile/profile_api_service.dart';

class VersionCheckerController extends ValueNotifier<SVersion> {
  final ProfileApiService profileApiService;

  VersionCheckerController(this.profileApiService) : super(SVersion.empty());

  Future<SVersion> _check() async {
    final res = await vSafeApiCall<SVersion>(
      request: () async {
        final packageInfo = await PackageInfo.fromPlatform();
        final version = packageInfo.version;
        return profileApiService.checkVersion(version);
      },
      onSuccess: (response) {
        return response;
      },
      onError: (exception, trace) {
        if (kDebugMode) {
          print(exception);
        }
      },
    );
    value = res ?? SVersion.empty();
    return value;
  }

  Future<void> lunchUpdate() async {
    if (VPlatforms.isAndroid) {
      await VStringUtils.lunchLink(VAppConfigController.appConfig.googlePayUrl);
    }
    if (VPlatforms.isIOS) {
      await VStringUtils.lunchLink(
          VAppConfigController.appConfig.appleStoreUrl);
    }
    if (VPlatforms.isWeb) {
      window.location.reload();
    }
    if (VPlatforms.isMacOs) {
      await VStringUtils.lunchLink(VAppConfigController.appConfig.macStoreUrl);
    }
    if (VPlatforms.isWindows) {
      await VStringUtils.lunchLink(
        VAppConfigController.appConfig.windowsStoreUrl,
      );
    }
  }

  FutureOr<void> checkForUpdates(
    BuildContext context,
    bool showAlert,
  ) async {
    final version = await _check();
    if (!version.isNeedUpdates) {
      if (showAlert) {
        VAppAlert.showSuccessSnackBar(
          message: S.of(context).noUpdatesAvailableNow,
          context: context,
        );
      }
      return;
    }
    if (version.isCritical) {
      await VAppAlert.showOkAlertDialog(
        context: context,
        title: S.of(context).newUpdateIsAvailable,
        content:
            "${S.of(context).weHighRecommendToDownloadThisUpdate} ${version.serverVersion}",
      );
      await lunchUpdate();
      return;
    }
    if (!showAlert) return;
    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: S.of(context).newUpdateIsAvailable,
      content: "${version.notes} ${version.serverVersion}",
    );
    if (res == 1) {
      await lunchUpdate();
    }
    return null;
  }
}
