// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import '../states/link_by_qr_code_state.dart';

class LinkByQrCodeController extends SLoadingController<LinkByQrCodeState?> {
  final txtController = TextEditingController();

  LinkByQrCodeController() : super(SLoadingState(null));

  @override
  void onClose() {
    txtController.dispose();
  }

  @override
  void onInit() {
    getData();
  }

  Future<void> getData() async {
    await vSafeApiCall<LinkByQrCodeState?>(
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
