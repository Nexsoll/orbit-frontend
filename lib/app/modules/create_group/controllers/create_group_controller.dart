// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

class CreateGroupController extends ValueNotifier implements SBaseController {
  final List<SBaseUser> users;
  final Function(VRoom) onDone;
  final txtController = TextEditingController();
  final focusNode = FocusNode();
  VChatLoadingState loadingState = VChatLoadingState.ideal;

  CreateGroupController(this.users, this.onDone) : super(null);

  VPlatformFile? image;
  bool isCreating = false;

  Future<void> createGroup(BuildContext context) async {
    final title = txtController.text;
    if (title.isEmpty) {
      VAppAlert.showErrorSnackBar(
          message: S.of(context).titleIsRequired, context: context);
      return;
    }
    await vSafeApiCall<VRoom>(
      onLoading: () async {
        isCreating = true;
        notifyListeners();
      },
      onError: (exception, trace) {
        isCreating = false;
        notifyListeners();
        VAppAlert.showErrorSnackBar(
          message: exception,
          context: context,
        );
      },
      request: () async {
        final room = await VChatController.I.roomApi.createGroup(
          dto: CreateGroupDto(
            peerIds: users.map((e) => e.id).toList(),
            title: title,
            platformImage: image,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        return room;
      },
      onSuccess: (response) {
        isCreating = false;
        notifyListeners();
        onDone(response);
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }

  @override
  void onClose() {
    txtController.dispose();
    focusNode.dispose();
  }

  bool get isEmpty => txtController.value.text.isEmpty;

  @override
  void onInit() {
    focusNode.requestFocus();
    txtController.addListener(() {
      notifyListeners();
    });
  }
}
