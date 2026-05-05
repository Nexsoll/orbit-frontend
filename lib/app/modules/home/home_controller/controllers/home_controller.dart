// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';
import 'package:v_chat_receive_share/v_chat_receive_share.dart';
// import 'package:v_chat_receive_share/v_chat_receive_share.dart';

// import 'package:v_chat_receive_share/v_chat_receive_share.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../../../core/api_service/profile/profile_api_service.dart';
import '../../../../core/controllers/version_checker_controller.dart';
import '../../mobile/calls_tab/controllers/calls_tab_controller.dart';
import '../../mobile/rooms_tab/controllers/rooms_tab_controller.dart';
import '../../mobile/story_tab/controllers/story_tab_controller.dart';
import '../../mobile/users_tab/controllers/users_tab_controller.dart';
import '../../../live_stream/controllers/go_live_controller.dart';
import '../../../live_stream/controllers/watch_live_controller.dart';
import '../../../live_stream/controllers/live_stream_controller.dart';
import '../../../live_stream/controllers/live_stream_chat_controller.dart';

class HomeController extends SLoadingController<int> {
  int totalChatUnRead = 0;
  int totalMarketplaceUnRead = 0;
  int totalGroupsChannelsUnRead = 0;
  final versionCheckerController = GetIt.I.get<VersionCheckerController>();
  int get tabIndex => data;
  final ProfileApiService profileApiService;
  final BuildContext context;
  IconData fabIcon = Icons.message;

  HomeController(this.profileApiService, this.context)
      : super(SLoadingState(0));

  StreamSubscription<VRoomEvents>? _roomStream;
  StreamSubscription<VMessageEvents>? _messageStream;

  Future<void> _refreshUnreadCounts() async {
    try {
      final rooms = await VChatController.I.nativeApi.local.room.getRooms(
        limit: 200,
      );
      final marketCount = rooms
          .where(
            (r) =>
                r.roomType == VRoomType.o &&
                !r.isArchived &&
                (r.unReadCount) > 0,
          )
          .length;
      final groupsChannelsCount = rooms
          .where(
            (r) =>
                (r.roomType.isGroup || r.roomType.isBroadcast) &&
                !r.isArchived &&
                (r.unReadCount) > 0,
          )
          .length;
      final chatCount = rooms
          .where(
            (r) =>
                r.roomType != VRoomType.o &&
                !r.roomType.isGroup &&
                !r.roomType.isBroadcast &&
                !r.isArchived &&
                (r.unReadCount) > 0,
          )
          .length;
      var changed = false;
      if (totalMarketplaceUnRead != marketCount) {
        totalMarketplaceUnRead = marketCount;
        changed = true;
      }
      if (totalGroupsChannelsUnRead != groupsChannelsCount) {
        totalGroupsChannelsUnRead = groupsChannelsCount;
        changed = true;
      }
      if (totalChatUnRead != chatCount) {
        totalChatUnRead = chatCount;
        changed = true;
      }
      if (changed) {
        notifyListeners();
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void onInit() {
    _registerLazySingletons();
    // Connect to VChat SDK and eagerly sync rooms as soon as socket is ready
    _connectToVChatSdk();
    // Run non-critical init tasks in parallel (don't block room loading)
    unawaited(Future.wait([
      Future(() => _checkVersion()),
      Future(() => _updateProfile()),
      _refreshUnreadCounts(),
    ]));
    try {
      _roomStream = VChatController.I.nativeApi.streams.roomStream
          .where(
        (event) =>
            event is VUpdateRoomUnReadCountByOneEvent ||
            event is VUpdateRoomUnReadCountToZeroEvent ||
            event is VInsertRoomEvent ||
            event is VDeleteRoomEvent,
      )
          .listen((_) {
        unawaited(_refreshUnreadCounts());
      });
      _messageStream = VChatController.I.nativeApi.streams.messageStream
          .where((event) => event is VInsertMessageEvent)
          .listen((_) {
        unawaited(_refreshUnreadCounts());
      });
    } catch (e) {
      if (kDebugMode) {
        print(
            '[HomeController] VChat not ready (unread stream): ${e.toString()}');
      }
    }
  }

  @override
  void onClose() {
    _unregister();
    _roomStream?.cancel();
    _messageStream?.cancel();
  }

  Future<void> _connectToVChatSdk() async {
    final sw = Stopwatch()..start();
    await _ensureChatDbIsForActiveAccount();
    print('[PERF] _ensureChatDbIsForActiveAccount took ${sw.elapsedMilliseconds}ms');
    try {
      await VChatController.I.profileApi.connect();
      print('[PERF] profileApi.connect() took ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      if (kDebugMode) {
        print('[HomeController] VChat not ready (connect): ${e.toString()}');
      }
      return;
    }

    // Best-effort push token sync — fire-and-forget, do NOT block room loading
    unawaited(() async {
      try {
        final pushService =
            await VChatController.I.vChatConfig.currentPushProviderService;
        if (pushService != null) {
          final token = await pushService.getToken(
            VPlatforms.isWeb ? SConstants.webVapidKey : null,
          );
          if (token != null && token.isNotEmpty) {
            await VChatController.I.nativeApi.remote.profile.addPushKey(
              fcm: token,
              voipKey: null,
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('[HomeController] Push token sync skipped: ${e.toString()}');
        }
      }
    }());

    vInitReceiveShareHandler();
    _setVisit();
    // Initialize call listener on both mobile and web so incoming call events are handled
    vInitCallListener(context);
    if (VPlatforms.isMobile) {
      CallKeepHandler.I.checkLastCall();
      _setVoipKey();
    }
  }

  Future<void> _ensureChatDbIsForActiveAccount() async {
    try {
      final currentAccountId =
          VAppPref.getStringOrNullKey(SStorageKeys.currentActiveAccountId.name);
      if (currentAccountId == null || currentAccountId.trim().isEmpty) {
        return;
      }

      final lastDbAccountId =
          VAppPref.getStringOrNullKey(SStorageKeys.lastChatDbAccountId.name);
      if (lastDbAccountId == currentAccountId) {
        return;
      }

      if (kDebugMode) {
        print(
            '[HomeController] Active account changed. Clearing local chat DB. last=$lastDbAccountId current=$currentAccountId');
      }

      await VChatController.I.nativeApi.local.reCreate();
      await VAppPref.setStringKey(
        SStorageKeys.lastChatDbAccountId.name,
        currentAccountId,
      );
    } catch (e) {
      if (kDebugMode) {
        print(
            '[HomeController] Failed to ensure chat DB account: ${e.toString()}');
      }
    }
  }

  void _setVisit() async {
    vSafeApiCall(
      request: () async {
        return profileApiService.setVisit();
      },
      onSuccess: (response) {},
      ignoreTimeoutAndNoInternet: true,
    );
  }

  void _checkVersion() async {
    await versionCheckerController.checkForUpdates(context, false);
  }

  void _registerLazySingletons() {
    // Check if controllers are already registered to avoid conflicts
    if (!GetIt.I.isRegistered<CallsTabController>()) {
      GetIt.I.registerLazySingleton<CallsTabController>(
        () => CallsTabController(),
      );
    }

    if (!GetIt.I.isRegistered<UsersTabController>()) {
      GetIt.I.registerLazySingleton<UsersTabController>(
        () => UsersTabController(GetIt.I.get<ProfileApiService>()),
      );
    }

    if (!GetIt.I.isRegistered<StoryTabController>()) {
      GetIt.I.registerLazySingleton<StoryTabController>(
        () => StoryTabController(),
      );
    }

    if (!GetIt.I.isRegistered<RoomsTabController>()) {
      GetIt.I.registerLazySingleton<RoomsTabController>(
        () => RoomsTabController(),
      );
    }

    // Live Stream Controllers - only register on mobile platforms
    if (!VPlatforms.isWeb) {
      if (!GetIt.I.isRegistered<GoLiveController>()) {
        GetIt.I.registerLazySingleton<GoLiveController>(
          () => GoLiveController(),
        );
      }

      if (!GetIt.I.isRegistered<WatchLiveController>()) {
        GetIt.I.registerLazySingleton<WatchLiveController>(
          () => WatchLiveController(),
        );
      }

      if (!GetIt.I.isRegistered<LiveStreamController>()) {
        GetIt.I.registerLazySingleton<LiveStreamController>(
          () => LiveStreamController(),
        );
      }

      if (!GetIt.I.isRegistered<LiveStreamChatController>()) {
        GetIt.I.registerLazySingleton<LiveStreamChatController>(
          () => LiveStreamChatController(),
        );
      }
    }
  }

  void _unregister() {
    // Safely close and unregister controllers
    if (GetIt.I.isRegistered<RoomsTabController>()) {
      GetIt.I.get<RoomsTabController>().onClose();
      GetIt.I.unregister<RoomsTabController>();
    }

    if (GetIt.I.isRegistered<CallsTabController>()) {
      GetIt.I.get<CallsTabController>().onClose();
      GetIt.I.unregister<CallsTabController>();
    }

    if (GetIt.I.isRegistered<UsersTabController>()) {
      GetIt.I.get<UsersTabController>().onClose();
      GetIt.I.unregister<UsersTabController>();
    }

    if (GetIt.I.isRegistered<StoryTabController>()) {
      GetIt.I.unregister<StoryTabController>();
    }
  }

  void _updateProfile() async {
    final newProfile = await profileApiService.getMyProfile();
    await VAppPref.setMap(SStorageKeys.myProfile.name, newProfile.toMap());
    AppAuth.setProfileNull();
  }

  void _setVoipKey() async {
    if (VPlatforms.isIOS) {
      final token = await CallKeepHandler.I.getVoipIos();
      print("----------------------------------------------------------");
      print(token);
      print("----------------------------------------------------------");
      if (token == null || token.isEmpty) {
        return;
      }
      try {
        await VChatController.I.nativeApi.remote.profile
            .addPushKey(fcm: null, voipKey: token);
      } catch (e) {
        print(e);
      }
    }
  }
}
