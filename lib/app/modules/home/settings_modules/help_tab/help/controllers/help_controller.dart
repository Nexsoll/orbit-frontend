// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import '../states/help_state.dart';
import '../../privacy_policy/privacy_policy_page.dart';

class HelpController extends SLoadingController<HelpState> {
  HelpController() : super(SLoadingState(HelpState()));
  bool isOpeningChat = false;
  final appConfig = VAppConfigController.appConfig;

  @override
  void onClose() {}

  @override
  void onInit() {
    getAppVersion();
  }

  void openChatWith(BuildContext context) async {
    vSafeApiCall(
      onLoading: () {
        isOpeningChat = true;
        notifyListeners();
      },
      request: () async {
        await VChatController.I.roomApi.openChatWith(
          peerId: "peerId",
        );
      },
      onSuccess: (response) {
        isOpeningChat = false;
        notifyListeners();
      },
      onError: (exception, trace) {
        isOpeningChat = false;
        notifyListeners();
      },
    );
  }

  Future<void> getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      value.data.version = "$version+$buildNumber";
      update();
    } catch (err) {
      log(err.toString());
    }
  }

  Future<void> onEmailContact(BuildContext context) async {
    if (!await launchUrl(Uri.parse(
      "mailto:info@orbit.ke?subject=${SConstants.appName}&body= ",
    ))) {
      throw Exception('Could not launch  ');
    }
  }

  Future<void> onPrivacy(BuildContext context) async {
    context.toPage(const PrivacyPolicyPage());
  }
}
