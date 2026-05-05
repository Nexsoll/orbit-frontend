// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

class CreateBroadcastController extends ValueNotifier
    implements SBaseController {
  final List<SBaseUser> users;
  final txtController = TextEditingController();

  bool isCreating = false;
  final Function(VRoom) onDone;

  CreateBroadcastController(this.users, this.onDone) : super(null);

  bool get isTextEmpty => txtController.value.text.isEmpty;
  final focusNode = FocusNode();
  VPlatformFile? image;

  Future<void> createBroadcast(BuildContext context) async {
    final title = txtController.text;
    if (title.isEmpty) {
      VAppAlert.showErrorSnackBar(
        message: S.of(context).titleIsRequired,
        context: context,
      );
      return;
    }
    await vSafeApiCall(
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
        final room =
            await VChatController.I.nativeApi.remote.room.createBroadcast(
          CreateBroadcastDto(
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

  @override
  void onInit() {
    txtController.addListener(() {
      notifyListeners();
    });
    focusNode.requestFocus();
  }
}
