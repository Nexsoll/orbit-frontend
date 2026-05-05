// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:s_translation/generated/l10n.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class CallsTabController extends SLoadingController<List<VCallHistory>> {
  CallsTabController() : super(SLoadingState(<VCallHistory>[]));

  @override
  void onInit() {
    getCalls();
  }

  Future getCallsFromApi() async {
    await vSafeApiCall<List<VCallHistory>>(
      request: () async {
        return VChatController.I.roomApi.getCallHistory();
      },
      onSuccess: (response) async {
        data.clear();
        data.addAll(response);
        unawaited(VAppPref.setMap("api/calls", {
          "data": response.map((e) => e.toMap()).toList(),
        }));
        setStateSuccess();
        update();
      },
      // onError: (exception, trace) {
      //   setStateError(exception);
      // },
    );
  }

  @override
  void onClose() {}

  void getCalls() async {
    try {
      final oldCalls = VAppPref.getMap("api/calls");
      if (oldCalls != null) {
        final list = oldCalls['data'] as List;
        value.data = list.map((e) => VCallHistory.fromJson(e)).toList();
        setStateSuccess();
      }
    } catch (err) {
      if (kDebugMode) {
        print(err);
      }
    }
    await getCallsFromApi();
  }

  Future onLongPress(BuildContext context, VCallHistory item) async {
    final res = await VAppAlert.showModalSheetWithActions(
      content: [
        ModelSheetItem(
          title: S.of(context).delete,
          id: "1",
        )
      ],
      context: context,
    );
    if (res == null) return;
    if (res.id == "1") {
      vSafeApiCall(
        request: () async {
          VChatController.I.nativeApi.remote.calls.deleteOneHistory(item.id);
        },
        onSuccess: (response) {
          getCalls();
        },
      );
    }
  }

  void clearCalls(BuildContext context) async {
    ///ask the user
    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: S.of(context).clear,
      content: S.of(context).clearCallsConfirm,
    );
    if (res != 1) return;
    await vSafeApiCall(
      request: () async {
        VChatController.I.nativeApi.remote.calls.clearHistory();
      },
      onSuccess: (response) {
        getCalls();
      },
    );
  }
}
