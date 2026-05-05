// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:v_platform/v_platform.dart';

import '../models/live_stream_model.dart';
import '../services/live_stream_api_service.dart';
import 'live_stream_controller.dart';

class WatchLiveController extends SLoadingController<List<LiveStreamModel>> {
  final LiveStreamApiService _apiService = GetIt.I.get<LiveStreamApiService>();

  Timer? _refreshTimer;
  StreamSubscription? _socketSubscription;
  Map<String, dynamic>? _pendingApproval;
  Map<String, dynamic>? _pendingInvite;

  WatchLiveController() : super(SLoadingState([]));

  // Getter for pending approval data
  Map<String, dynamic>? get pendingApproval => _pendingApproval;
  Map<String, dynamic>? get pendingInvite => _pendingInvite;

  // Clear pending approval
  void clearPendingApproval() {
    _pendingApproval = null;
    notifyListeners();
  }

  void clearPendingInvite() {
    _pendingInvite = null;
    notifyListeners();
  }

  // Join approved stream
  LiveStreamModel? getStreamById(String streamId) {
    try {
      return data.firstWhere(
        (s) => s.id == streamId,
        orElse: () => throw Exception('Stream not found'),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Stream not found: $streamId');
      }
      return null;
    }
  }

  @override
  void onInit() {
    getLiveStreams();
    _startAutoRefresh();
    _listenToSocketEvents();
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    _socketSubscription?.cancel();
  }

  void _startAutoRefresh() {
    // Refresh live streams every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (value.loadingState != VChatLoadingState.loading) {
        getLiveStreamsFromApi();
      }
    });
  }

  void _listenToSocketEvents() {
    // Listen for live stream events from socket
    _socketSubscription =
        VChatController.I.nativeStreams.socketStatusStream.listen((event) {
      if (event.isConnected) {
        // Socket connected, refresh streams
        getLiveStreamsFromApi();
      }
    });

    // Socket instance
    final socket = VChatController.I.nativeApi.remote.socketIo.socket;

    // Listen for join request responses (camelCase)
    socket.on('joinRequestResponse', (data) {
      if (data != null && data is Map<String, dynamic>) {
        final approved = data['approved'] as bool? ?? false;
        final streamId = data['streamId'] as String?;
        final message = data['message'] as String?;
        _pendingApproval = {
          'streamId': streamId,
          'message': message ?? (approved
              ? 'Your join request has been approved! 🎉'
              : 'Your join request was not approved.'),
          'approved': approved,
        };
        notifyListeners();
      }
    });

    // Listen for join request responses (snake_case)
    socket.on('join_request_response', (data) {
      try {
        if (data != null && data is Map<String, dynamic>) {
          final status = (data['status'] as String?) ?? '';
          final approved = status.toLowerCase() == 'approved';
          final streamId = data['streamId'] as String?;
          final message = data['message'] as String?;
          final requestType = data['requestType'] as String? ?? 'viewer';
          
          if (kDebugMode) {
            print('📨 join_request_response: approved=$approved, streamId=$streamId, requestType=$requestType');
          }
          
          // If it's a co-host request approval and user is already in this stream, treat it like an invite
          final liveCtrl = GetIt.I.get<LiveStreamController>();
          if (approved && requestType == 'cohost' && streamId != null && liveCtrl.currentStream?.id == streamId && liveCtrl.agoraEngine != null) {
            // User is already viewing this stream - upgrade them to co-host in place
            _handleCoHostEscalation(streamId);
            return;
          }
          
          // Otherwise, show the approval dialog (for viewers or when not already in stream)
          _pendingApproval = {
            'streamId': streamId,
            'message': message ?? (approved
                ? 'Your join request has been approved! 🎉'
                : 'Your join request was not approved.'),
            'approved': approved,
            'requestType': requestType,
          };
          notifyListeners();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error handling join_request_response: $e');
        }
      }
    });

    // Listen for host invites to join a stream (e.g., co-host)
    socket.on('join_invite_received', (data) {
      try {
        if (data != null && data is Map<String, dynamic>) {
          final requestId = data['requestId'] as String?;
          final streamId = data['streamId'] as String?;
          final message = data['message'] as String? ?? 'You are invited to join the live stream';
          final requestType = data['requestType'] as String? ?? 'cohost';

          if (requestId != null && streamId != null) {
            _pendingInvite = {
              'requestId': requestId,
              'streamId': streamId,
              'message': message,
              'requestType': requestType,
            };
            notifyListeners();
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error handling join_invite_received: $e');
        }
      }
    });

    // You can add more specific socket listeners here for:
    // - live_stream_started
    // - live_stream_ended
    // - user_joined_stream
    // - user_left_stream
  }

  Future<void> getLiveStreams() async {
    try {
      // Try to load cached data first
      final cachedData = VAppPref.getMap("api/live_streams");
      if (cachedData != null) {
        final list = cachedData['data'] as List;
        data.clear();
        data.addAll(list.map((e) => LiveStreamModel.fromMap(e)).toList());
        setStateSuccess();
        update();
      }
    } catch (err) {
      if (kDebugMode) {
        print('Error loading cached live streams: $err');
      }
    }

    await getLiveStreamsFromApi();
  }

  Future<void> getLiveStreamsFromApi() async {
    await vSafeApiCall<List<LiveStreamModel>>(
      request: () async {
        return await _apiService.getLiveStreams(
          status: 'live',
          page: 1,
          limit: 50,
        );
      },
      onSuccess: (response) {
        data.clear();
        data.addAll(response);

        // Cache the data
        unawaited(VAppPref.setMap("api/live_streams", {
          "data": response.map((e) => e.toMap()).toList(),
        }));

        setStateSuccess();
        update();
      },
      onError: (exception, trace) {
        if (kDebugMode) {
          print('Error fetching live streams: $exception');
        }
        setStateError();
        update();
      },
    );
  }

  Future<void> refreshStreams() async {
    // Clear cache to ensure fresh data
    await VAppPref.removeKey("api/live_streams");
    await getLiveStreamsFromApi();
  }

  void clearCache() {
    VAppPref.removeKey("api/live_streams");
  }

  Future<LiveStreamModel?> joinStream(String streamId) async {
    try {
      final result = await _apiService.joinLiveStream(streamId);
      return result['stream'] as LiveStreamModel?;
    } catch (e) {
      if (kDebugMode) {
        print('Error joining stream: $e');
      }
      // Re-throw the error so it can be handled by the UI
      rethrow;
    }
  }

  Future<void> _handleCoHostEscalation(String streamId) async {
    try {
      if (kDebugMode) {
        print('🔄 Co-host escalation via request approval: leaving channel to rejoin as broadcaster');
      }
      
      final liveCtrl = GetIt.I.get<LiveStreamController>();
      final channelName = liveCtrl.currentStream!.channelName;
      
      // Leave the channel first
      await liveCtrl.agoraEngine!.leaveChannel();
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (kDebugMode) {
        print('🔄 Fetching fresh token from backend...');
      }
      // Update backend role and fetch fresh token
      final joinRes = await _apiService.joinLiveStream(streamId);
      final freshToken = joinRes['agoraToken'] as String;
      
      if (kDebugMode) {
        print('🔄 Setting client role to BROADCASTER...');
      }
      // Rejoin as broadcaster
      await liveCtrl.agoraEngine!.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      );
      
      if (kDebugMode) {
        print('🔄 Rejoining channel as broadcaster with publish flags...');
      }
      await liveCtrl.agoraEngine!.joinChannel(
        token: freshToken,
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
        ),
      );
      
      // Enable video/audio
      try { await liveCtrl.agoraEngine!.enableVideo(); } catch (_) {}
      await liveCtrl.agoraEngine!.muteLocalVideoStream(false);
      await liveCtrl.agoraEngine!.muteLocalAudioStream(false);
      if (!VPlatforms.isWeb) {
        try { await liveCtrl.agoraEngine!.startPreview(); } catch (_) {}
      }
      
      liveCtrl.isCameraOn.value = true;
      liveCtrl.isMuted.value = false;
      liveCtrl.isBroadcaster.value = true;
      
      if (kDebugMode) {
        print('✅ Co-host status updated via request approval: isBroadcaster=true, isCameraOn=true');
      }
    } catch (err) {
      if (kDebugMode) {
        print('❌ Error during co-host escalation: $err');
      }
    }
  }

  void updateStreamViewerCount(String streamId, int newCount) {
    final streamIndex = data.indexWhere((stream) => stream.id == streamId);
    if (streamIndex != -1) {
      data[streamIndex] = data[streamIndex].copyWith(viewerCount: newCount);
      update();
    }
  }

  void removeEndedStream(String streamId) {
    data.removeWhere((stream) => stream.id == streamId);
    update();

    // Update cache
    unawaited(VAppPref.setMap("api/live_streams", {
      "data": data.map((e) => e.toMap()).toList(),
    }));
  }

  void addNewStream(LiveStreamModel stream) {
    // Add new stream to the beginning of the list
    data.insert(0, stream);
    update();

    // Update cache
    unawaited(VAppPref.setMap("api/live_streams", {
      "data": data.map((e) => e.toMap()).toList(),
    }));
  }
}
