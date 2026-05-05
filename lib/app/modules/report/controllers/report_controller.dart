// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/api_service.dart';
import 'package:super_up/app/core/dto/create_report_dto.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import '../states/report_state.dart';

class ReportController extends SLoadingController<ReportState> {
  final txtController = TextEditingController();
  final _profileApi = GetIt.I.get<ProfileApiService>();
  final String userId;

  ReportController(this.userId) : super(SLoadingState(ReportState()));

  @override
  void onClose() {
    txtController.dispose();
  }

  bool get isSendReady {
    return data.currentType != null && txtController.text.isNotEmpty;
  }

  @override
  void onInit() {
    txtController.addListener(() {
      update();
    });
  }

  void onBlockPress(bool x) {
    value.data.blockThisUser = x;
    update();
  }

  void onTypePress(int x) {
    if (x == 0) {
      value.data.currentType = null;
    } else {
      value.data.currentType = x;
    }
    update();
  }

  Future<void> onReport(BuildContext context) async {
    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: S.of(context).areYouSure,
      content: S.of(context).areYouSureToReportUserToAdmin,
    );
    if (res != 1) return;
    await vSafeApiCall<ReportState?>(
      onLoading: () async {
        setStateLoading();
        update();
      },
      onError: (exception, trace) {
        setStateError();
        update();
      },
      request: () async {
        await _profileApi.createReport(
          CreateReportDto(
            content: txtController.text,
            type: "${value.data.currentType}",
            targetId: userId,
          ),
        );
        if (value.data.blockThisUser) {
          await VChatController.I.blockApi.blockUser(peerId: userId);
        }
        return null;
      },
      onSuccess: (response) {
        VAppAlert.showSuccessSnackBar(
          message: S.of(context).reportHasBeenSubmitted,
          context: context,
        );
        context.pop();
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }
}
