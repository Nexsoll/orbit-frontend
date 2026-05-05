// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import '../states/privacy_policy_state.dart';

class PrivacyPolicyController extends SLoadingController<PrivacyPolicyState?> {
  final txtController = TextEditingController();

  PrivacyPolicyController() : super(SLoadingState(null));

  @override
  void onClose() {
    txtController.dispose();
  }

  @override
  void onInit() {
    getData();
  }

  Future<void> getData() async {
    await vSafeApiCall<PrivacyPolicyState?>(
      onLoading: () async {
        setStateLoading();
        update();
      },
      onError: (exception, trace) {
        setStateError();
        update();
      },
      request: () async {
        return null;
      },
      onSuccess: (response) {
        value.data = response;
        update();
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }
}
