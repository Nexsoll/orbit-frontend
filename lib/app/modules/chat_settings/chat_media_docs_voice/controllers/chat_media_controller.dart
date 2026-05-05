// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../../../core/app_config/app_config_controller.dart';

class ChatMediaState {
  final List<VBaseMessage> media;
  final List<VBaseMessage> files;
  final List<VBaseMessage> links;

  ChatMediaState({
    this.media = const <VBaseMessage>[],
    this.files = const <VBaseMessage>[],
    this.links = const <VBaseMessage>[],
  });
}

class ChatMediaController extends SLoadingController<ChatMediaState> {
  final String roomId;

  ChatMediaController(this.roomId) : super(SLoadingState(ChatMediaState()));

  final appConfigController = GetIt.I.get<VAppConfigController>();

  @override
  void onInit() {
    getData();
    AdsBannerWidget.loadAd(
      VPlatforms.isAndroid
          ? SConstants.androidInterstitialId
          : SConstants.iosInterstitialId,
      enableAds: VAppConfigController.appConfig.enableAds,
    );
  }

  @override
  void onClose() {}

  void getData() {
    vSafeApiCall<ChatMediaState>(
      onLoading: () {
        setStateLoading();
      },
      request: () async {
        // Use local database instead of remote API to get ALL items (not limited to 30)
        final media =
            await VChatController.I.nativeApi.local.message.getRoomMessages(
          roomId: roomId,
          filter: VRoomMessagesDto(filter: VMessagesFilter.media, limit: 10000),
        );
        final files =
            await VChatController.I.nativeApi.local.message.getRoomMessages(
          roomId: roomId,
          filter: VRoomMessagesDto(filter: VMessagesFilter.file, limit: 10000),
        );
        final links =
            await VChatController.I.nativeApi.local.message.getRoomMessages(
          roomId: roomId,
          filter: VRoomMessagesDto(filter: VMessagesFilter.links, limit: 10000),
        );
        return ChatMediaState(
          media: media,
          files: files,
          links: links,
        );
      },
      onSuccess: (response) {
        value.data = response;
        setStateSuccess();
      },
      onError: (exception, trace) {
        setStateError();
      },
    );
  }
}
