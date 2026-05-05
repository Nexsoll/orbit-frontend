// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class ChatsSearchController extends SLoadingController<List<VRoom>> {
  ChatsSearchController() : super(SLoadingState([]));
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();

  @override
  void onInit() {
    searchFocusNode.requestFocus();
  }

  @override
  void onClose() {
    searchController.dispose();
    searchFocusNode.dispose();
  }

  void onSearch(String query) async {
    if (query.isEmpty) {
      value.data = [];
      return;
    }
    vSafeApiCall<List<VRoom>>(
      onLoading: () {
        setStateLoading();
      },
      request: () async {
        return VChatController.I.nativeApi.local.room.searchRoom(text: query);
      },
      onSuccess: (response) {
        value.data = response;
        setStateSuccess();
      },
      onError: (_, __) {
        setStateError();
      },
      ignoreTimeoutAndNoInternet: true,
    );
  }

  void onRoomItemPress(VRoom vRoom, BuildContext context) {
    VChatController.I.vNavigator.messageNavigator.toMessagePage(
      context,
      vRoom,
    );
  }
}
