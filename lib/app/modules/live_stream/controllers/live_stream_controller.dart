// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:super_up/app/core/services/story_status_service.dart';

// Conditional import for Agora
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:v_chat_message_page/src/agora/web_js_bridge_stub.dart'
    if (dart.library.html) 'package:v_chat_message_page/src/agora/web_js_bridge_web.dart';

import '../models/live_stream_model.dart';
import '../models/live_stream_participant_model.dart' as participant_model;
import '../models/stream_filter_model.dart';
import '../services/live_stream_api_service.dart';
import 'watch_live_controller.dart';
import 'stream_filter_controller.dart';
import 'dart:developer';

class LiveStreamController extends ChangeNotifier {
  final LiveStreamApiService _apiService = GetIt.I.get<LiveStreamApiService>();

  RtcEngine? agoraEngine;
  LiveStreamModel? currentStream;
  bool isStreamer = false;
  String? _viewerToken; // used on web for shadow subscribe
  bool _webPluginAvailable = true; // if Iris/plugin fails on web, fall back to JS-only
  bool _inChannel = false; // track if engine already joined a channel to avoid -17

  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<String> loadingStatus = ValueNotifier('Connecting...');
  final ValueNotifier<bool> isMuted = ValueNotifier(false);
  final ValueNotifier<bool> isCameraOn = ValueNotifier(true);
  final ValueNotifier<bool> isSpeakerOn = ValueNotifier(false);
  // True for host and co-hosts (broadcasters). View updates listen to this.
  final ValueNotifier<bool> isBroadcaster = ValueNotifier(false);
  final ValueNotifier<List<int>> remoteUsers = ValueNotifier([]);
  final ValueNotifier<int> viewerCount = ValueNotifier(0);
  final ValueNotifier<bool> streamEnded = ValueNotifier(false);
  final ValueNotifier<int> likesCount = ValueNotifier(0);
  final ValueNotifier<bool> isLiked = ValueNotifier(false);
  final ValueNotifier<bool> isRecording = ValueNotifier(false);
  final ValueNotifier<String> recordingDuration = ValueNotifier('00:00');

  StreamSubscription? _socketSubscription;
  Timer? _viewerCountTimer;
  Timer? _qualityUpgradeTimer;
  Timer? _recordingTimer;
  bool _isDisposed = false;
  DateTime? _recordingStartTime;

  /// Getter to check if controller is disposed
  bool get isDisposed => _isDisposed;

  // Filter controller
  final StreamFilterController _filterController = StreamFilterController();

  // Callback for when stream ends (for participants)
  VoidCallback? onStreamEndedCallback;
  Function(String?, bool)? onStreamEndedWithReasonCallback;

  // Getters
  StreamFilterController get filterController => _filterController;

  /// Check if required permissions are already granted
  Future<bool> arePermissionsGranted({required bool isStreamer}) async {
    if (isStreamer) {
      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;
      return cameraStatus == PermissionStatus.granted &&
          microphoneStatus == PermissionStatus.granted;
    } else {
      // Viewers don't strictly need microphone permission
      return true;
    }
  }

  Future<void> initializeStream({
    required LiveStreamModel stream,
    required bool isStreamer,
  }) async {
    // Reset disposal flag when starting a new stream
    _isDisposed = false;

    currentStream = stream;
    this.isStreamer = isStreamer;
    // Initialize broadcaster state (host = broadcaster, viewer = not)
    if (!_isDisposed) {
      isBroadcaster.value = isStreamer;
    }

    // Web is supported: we will use plugin for audio and JS shadow client for video.

    if (!_isDisposed) {
      if (kDebugMode) {
        print(
            'INIT: Setting loading to true at start. Current: ${isLoading.value}');
      }
      isLoading.value = true;

      // Check if permissions are already granted
      final permissionsGranted =
          await arePermissionsGranted(isStreamer: isStreamer);
      if (permissionsGranted && isStreamer) {
        loadingStatus.value = 'Preparing camera...';
      } else {
        loadingStatus.value = 'Requesting permissions...';
      }

      if (kDebugMode) {
        print('INIT: Loading set to true. New value: ${isLoading.value}');
        print('INIT: Permissions already granted: $permissionsGranted');
      }
    }

    try {
      // Request permissions (mobile only). On web, camera permission will be requested by the Web view when needed.
      if (!VPlatforms.isWeb) {
        await _requestPermissions();
      }

      // Pre-warm camera for streamers to reduce loading time
      if (isStreamer) {
        if (!_isDisposed) {
          loadingStatus.value = 'Preparing camera...';
        }
        await _preWarmCamera();
      }

      // Initialize Agora engine (also on web for audio track handling)
      if (!_isDisposed) {
        loadingStatus.value = 'Initializing video engine...';
      }
      await _initializeAgoraEngine().then((val) {
        log('=================================            ${agoraEngine}');
        log('=================================            Agero  is now initailize               ');
      });

    

      // Ensure engine is initialized before proceeding (skip throw on web fallback)
      if (agoraEngine == null) {
        if (VPlatforms.isWeb) {
          if (kDebugMode) {
            print('Proceeding with JS-only fallback (no plugin engine)');
          }
        } else {
          throw Exception('Failed to initialize Agora engine');
        }
      }

      // Join the stream (web: publish video via JS, audio via plugin)
      if (!_isDisposed) {
        loadingStatus.value = 'Joining stream...';
      }
      if (isStreamer) {
        await _joinAsStreamer();
        if (VPlatforms.isWeb && currentStream != null) {
          // Publish local camera via Web SDK; keep audio via plugin
          await shadowJoinPublish(
            SConstants.agoraAppId,
            currentStream!.channelName,
            currentStream!.agoraToken,
            null,
            true,
          );
          // Ensure plugin does NOT publish camera on web to avoid double video
          try {
            await agoraEngine!.updateChannelMediaOptions(
              const ChannelMediaOptions(
                clientRoleType: ClientRoleType.clientRoleBroadcaster,
                channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
                publishCameraTrack: false,
                publishMicrophoneTrack: true,
              ),
            );
          } catch (_) {}
          // Web fallback: mark loading finished after JS join completes
          if (!_isDisposed) {
            isLoading.value = false;
            loadingStatus.value = 'Connected!';
          }
        }
      } else {
        await _joinAsViewer();
        if (VPlatforms.isWeb && currentStream != null) {
          // Join shadow client to ensure remote playback overlays
          await shadowJoin(
            SConstants.agoraAppId,
            currentStream!.channelName,
            _viewerToken, // use viewer token if channel requires authentication
            null,
          );
          // Web fallback: mark loading finished after JS join completes
          if (!_isDisposed) {
            isLoading.value = false;
            loadingStatus.value = 'Connected!';
          }
        }
      }

      // Fallback: if we're the streamer and have stream info, immediately broadcast live
      if (isStreamer && currentStream != null) {
        try {
          final storyStatus = GetIt.I.get<StoryStatusService>();
          storyStatus.setUserLiveNow(
            userId: currentStream!.streamerId,
            streamId: currentStream!.id,
          );
        } catch (_) {}
      }

      // Listen to socket events
      _listenToSocketEvents();

      // Set up filter broadcasting for hosts
      if (isStreamer) {
        _setupFilterBroadcasting();
      }

      // Load join requests for streamers
      if (isStreamer) {
        await loadJoinRequests();
      }

      // Final status update
      if (!_isDisposed) {
        loadingStatus.value = 'Connected!';
        // Ensure the UI loading overlay is hidden in all paths (including web fallback)
        isLoading.value = false;
      }

      // Auto-enable camera for streamers when permissions are granted (mobile). On web, JS handles camera.
      if (isStreamer && agoraEngine != null && !_isDisposed && !VPlatforms.isWeb) {
        try {
          // Ensure camera is automatically turned on for live streaming
          await agoraEngine!.muteLocalVideoStream(false);
          isCameraOn.value = true;
          if (kDebugMode) {
            print('Camera auto-enabled for live streaming - ready to go live!');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error auto-enabling camera: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing stream: $e');
      }
      // Ensure loading is set to false even on error
      if (!_isDisposed) {
        isLoading.value = false;
      }
      rethrow;
    }
  }

  Future<void> _requestPermissions() async {
    if (isStreamer) {
      // Check if permissions are already granted to avoid showing dialog multiple times
      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;

      if (kDebugMode) {
        print('Current camera permission status: $cameraStatus');
        print('Current microphone permission status: $microphoneStatus');
      }

      // Only request permissions if not already granted
      Map<Permission, PermissionStatus> permissions = {};

      if (cameraStatus != PermissionStatus.granted) {
        if (kDebugMode) {
          print('Requesting camera permission...');
        }
        final cameraResult = await Permission.camera.request();
        permissions[Permission.camera] = cameraResult;
      } else {
        permissions[Permission.camera] = cameraStatus;
      }

      if (microphoneStatus != PermissionStatus.granted) {
        if (kDebugMode) {
          print('Requesting microphone permission...');
        }
        final micResult = await Permission.microphone.request();
        permissions[Permission.microphone] = micResult;
      } else {
        permissions[Permission.microphone] = microphoneStatus;
      }

      // Check if camera permission was granted
      if (permissions[Permission.camera] != PermissionStatus.granted) {
        throw Exception('Camera permission is required for live streaming');
      }

      if (kDebugMode) {
        print('Final camera permission: ${permissions[Permission.camera]}');
        print(
            'Final microphone permission: ${permissions[Permission.microphone]}');
      }
    } else {
      // Viewer only needs microphone permission for potential interaction
      final micStatus = await Permission.microphone.status;
      if (micStatus != PermissionStatus.granted) {
        await Permission.microphone.request();
      }
    }
  }

  Future<void> _initializeAgoraEngine() async {
    try {
      // Create Agora engine
      agoraEngine = createAgoraRtcEngine();

      await agoraEngine!.initialize(RtcEngineContext(
        appId: SConstants.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
    } catch (e) {
      // On web, if Iris is missing, allow JS shadow client to handle streaming
      if (VPlatforms.isWeb) {
        if (kDebugMode) {
          print('Agora engine initialize failed on web, falling back to JS: $e');
        }
        _webPluginAvailable = false;
        return; // continue without throwing
      }
      rethrow;
    }

    // Set event handlers
    agoraEngine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        if (kDebugMode) {
          print('✅ Successfully joined channel: ${connection.channelId} as ${isStreamer ? "BROADCASTER" : "AUDIENCE"}');
        }
        _inChannel = true;

        if (isStreamer && !_isDisposed && !VPlatforms.isWeb) {
          // For streamers, ensure camera is enabled after joining
          agoraEngine?.muteLocalVideoStream(false).then((_) {
            if (!_isDisposed) {
              isCameraOn.value = true;
            }
            if (kDebugMode) {
              print('Camera enabled in onJoinChannelSuccess for streamer');
            }
            // Start local preview to ensure host sees own feed immediately
            Future.microtask(() async {
              try { await agoraEngine?.enableVideo(); } catch (_) {}
              try { await agoraEngine?.startPreview(); } catch (_) {}
            });
          }).catchError((e) {
            if (kDebugMode) {
              print('Error enabling camera in onJoinChannelSuccess: $e');
            }
          });
        } else if (!isStreamer && !_isDisposed) {
          // For viewers, set loading to false when successfully joined
          isLoading.value = false;
        }
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        if (kDebugMode) {
          print('✅ Remote user joined: uid=$remoteUid, channel=${connection.channelId}');
        }
        if (!_isDisposed) {
          if (remoteUid == 0) {
            if (kDebugMode) print('⚠️ Ignoring invalid uid=0');
            return;
          }
          final users = List<int>.from(remoteUsers.value);
          if (!users.contains(remoteUid)) {
            users.add(remoteUid);
            remoteUsers.value = users;
            if (kDebugMode) {
              print('✅ Added remote uid=$remoteUid to remoteUsers. Total: ${users.length}');
            }
          }
        }

        // If we are the host/co-host, reinforce publish and local preview so our own tile stays visible
        if (!_isDisposed && isStreamer) {
          Future.microtask(() async {
            try {
              await agoraEngine?.updateChannelMediaOptions(const ChannelMediaOptions(
                clientRoleType: ClientRoleType.clientRoleBroadcaster,
                channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
                publishCameraTrack: true,
                publishMicrophoneTrack: true,
                autoSubscribeVideo: true,
                autoSubscribeAudio: true,
              ));
            } catch (_) {}
            try { await agoraEngine?.enableVideo(); } catch (_) {}
            try { await agoraEngine?.muteLocalVideoStream(false); } catch (_) {}
            if (!VPlatforms.isWeb) {
              try { await agoraEngine?.startPreview(); } catch (_) {}
            }
            if (!_isDisposed) {
              isCameraOn.value = true;
              isBroadcaster.value = true;
            }
          });
        }
      },
      onFirstRemoteVideoFrame: (
        RtcConnection connection,
        int remoteUid,
        int width,
        int height,
        int elapsed,
      ) {
        if (kDebugMode) {
          print('📹 First remote video frame: uid=$remoteUid ${width}x$height');
        }
        // Already added in onUserJoined; this is just for logging
      },
      onRemoteVideoStateChanged: (
        RtcConnection connection,
        int remoteUid,
        RemoteVideoState state,
        RemoteVideoStateReason reason,
        int elapsed,
      ) {
        if (kDebugMode) {
          print('📹 Remote video state changed: uid=$remoteUid, state=$state, reason=$reason');
        }
        // Ensure user is in list when video starts
        if (state == RemoteVideoState.remoteVideoStateStarting ||
            state == RemoteVideoState.remoteVideoStateDecoding) {
          if (!_isDisposed && remoteUid != 0) {
            final users = List<int>.from(remoteUsers.value);
            if (!users.contains(remoteUid)) {
              users.add(remoteUid);
              remoteUsers.value = users;
              if (kDebugMode) {
                print('✅ Added remote uid=$remoteUid via video state change');
              }
            }
          }
        }
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        if (kDebugMode) {
          print('❌ Remote user left: uid=$remoteUid, reason=$reason');
        }
        if (!_isDisposed) {
          final users = List<int>.from(remoteUsers.value);
          users.remove(remoteUid);
          remoteUsers.value = users;
        }
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        if (kDebugMode) {
          print('⬅️ Left channel: ${connection.channelId}');
        }
        if (!_isDisposed) {
          remoteUsers.value = [];
        }
        _inChannel = false;
      },
      onFirstLocalVideoFrame: (
        VideoSourceType source,
        int width,
        int height,
        int elapsed,
      ) {
        if (kDebugMode) {
          print('First local video frame rendered: ${width}x$height');
        }
        // Note: Loading is now set to false immediately after startPreview()
        // This event is kept for debugging purposes
      },
      onError: (ErrorCodeType err, String msg) {
        if (kDebugMode) {
          print('Agora error: $err - $msg');
        }
        // Hide loading on critical errors
        if (!_isDisposed) {
          isLoading.value = false;
        }
      },
    ));

    // Configure video settings for optimal performance
    await _configureVideoSettings();

    // Enable video
    await agoraEngine!.enableVideo();

    if (isStreamer) {
      // Set client role as broadcaster
      await agoraEngine!
          .setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // Configure camera settings for better performance
      await _configureCameraSettings();

      // Enable local video preview with error handling (skip on web; JS will handle camera)
      if (!VPlatforms.isWeb) {
        try {
          await agoraEngine!.startPreview();
          if (kDebugMode) {
            print('Camera preview started successfully');
          }

          // Ensure camera is on by default for streamers
          await agoraEngine!.muteLocalVideoStream(false);
          if (!_isDisposed) {
            isCameraOn.value = true;
          }
          if (kDebugMode) {
            print('Camera enabled by default for streaming');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error starting camera preview: $e');
          }
        }
      }
    } else {
      // Set client role as audience
      await agoraEngine!.setClientRole(role: ClientRoleType.clientRoleAudience);
    }

    // Set loading to false for both streamers and viewers after engine setup
    if (!_isDisposed) {
      if (kDebugMode) {
        print('Setting loading to false after Agora engine setup completed');
      }
      isLoading.value = false;
    }
  }

  Future<void> _joinAsStreamer() async {
    if (currentStream == null) return;

    // Web fallback: skip plugin join if Iris is not available
    if (VPlatforms.isWeb && !_webPluginAvailable) {
      if (kDebugMode) {
        print('⚠️ Web plugin not available - camera will not publish to remote viewers');
      }
      // Camera state reflects our WebCameraView local preview only
      if (!_isDisposed) {
        isCameraOn.value = true;
      }
      return;
    }

    if (kDebugMode) {
      print('📡 Joining channel as BROADCASTER: ${currentStream!.channelName}');
    }

    // Join channel with streamer token
    await agoraEngine!.joinChannel(
      token: currentStream!.agoraToken,
      channelId: currentStream!.channelName,
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

    // Ensure camera is enabled after joining channel
    try {
      await agoraEngine!.muteLocalVideoStream(false);
      if (!_isDisposed) {
        isCameraOn.value = true;
      }
      if (kDebugMode) {
        print('Camera enabled after joining channel as streamer');
      }
      if (!_isDisposed) {
        isBroadcaster.value = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling camera after joining channel: $e');
      }
    }
  }

  Future<void> _joinAsViewer() async {
    if (currentStream == null) return;

    try {
      // Get viewer token from API
      final result = await _apiService.joinLiveStream(currentStream!.id);
      final viewerToken = result['agoraToken'] as String;
      _viewerToken = viewerToken;

      // Web fallback: if plugin not available, skip plugin join and rely on JS client
      if (VPlatforms.isWeb && !_webPluginAvailable) {
        // Update stream info and UI counters
        currentStream = result['stream'] as LiveStreamModel;
        if (!_isDisposed) {
          viewerCount.value = currentStream!.viewerCount;
          // Initialize likes data
          updateLikesFromStream();
        }
        return;
      }

      // If already joined, leave first to avoid AgoraRtcException(-17)
      if (_inChannel) {
        await _leaveChannel();
        await Future.delayed(const Duration(milliseconds: 150));
      }

      // Join channel with viewer token
      try {
        await agoraEngine!.joinChannel(
          token: viewerToken,
          channelId: currentStream!.channelName,
          uid: 0,
          options: const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleAudience,
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          ),
        );
      } catch (e) {
        // Retry once on ERR_REFUSED (-17)
        final es = e.toString();
        if (es.contains('(-17')) {
          await _leaveChannel();
          await Future.delayed(const Duration(milliseconds: 200));
          await agoraEngine!.joinChannel(
            token: viewerToken,
            channelId: currentStream!.channelName,
            uid: 0,
            options: const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleAudience,
              channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
            ),
          );
        } else {
          rethrow;
        }
      }

      // Update stream info
      currentStream = result['stream'] as LiveStreamModel;
      if (!_isDisposed) {
        viewerCount.value = currentStream!.viewerCount;
        // Initialize likes data
        updateLikesFromStream();
        // Ensure viewer role
        isBroadcaster.value = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error joining as viewer: $e');
      }
      rethrow;
    }
  }

  Future<void> _configureVideoSettings() async {
    if (agoraEngine == null) return;

    try {
      // Start with lower quality for faster initialization
      await agoraEngine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(
              width: 480, height: 640), // 480p portrait for faster start
          frameRate: 24, // Lower FPS for faster initialization
          bitrate: 800, // Lower bitrate for faster connection
        ),
      );

      // Enable hardware acceleration for better performance
      await agoraEngine!.enableLocalVideo(true);

      // Schedule quality upgrade after connection is stable
      if (isStreamer) {
        _scheduleQualityUpgrade();
      }

      if (kDebugMode) {
        print('Video settings configured successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error configuring video settings: $e');
      }
    }
  }

  void _scheduleQualityUpgrade() {
    // Cancel any existing quality upgrade timer
    _qualityUpgradeTimer?.cancel();

    // Upgrade to higher quality after 3 seconds of stable connection
    _qualityUpgradeTimer = Timer(const Duration(seconds: 3), () async {
      if (agoraEngine != null && !_isDisposed) {
        try {
          await agoraEngine!.setVideoEncoderConfiguration(
            const VideoEncoderConfiguration(
              dimensions:
                  VideoDimensions(width: 720, height: 1280), // Upgrade to 720p
              frameRate: 30, // Upgrade to 30 FPS
              bitrate: 1500, // Upgrade bitrate
            ),
          );
          if (kDebugMode) {
            print('Video quality upgraded to 720p');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error upgrading video quality: $e');
          }
        }
      }
    });
  }

  Future<void> _configureCameraSettings() async {
    if (agoraEngine == null) return;

    try {
      // Enable camera auto-focus for better video quality
      await agoraEngine!.setCameraAutoFocusFaceModeEnabled(true);

      // Enable camera exposure position with correct parameter names
      await agoraEngine!.setCameraExposurePosition(
        positionXinView: 0.5,
        positionYinView: 0.5,
      );

      // Set camera zoom ratio to default
      await agoraEngine!.setCameraZoomFactor(1.0);

      if (kDebugMode) {
        print('Camera settings configured successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error configuring camera settings: $e');
      }
    }
  }

  Future<void> _preWarmCamera() async {
    try {
      // Pre-initialize camera to reduce loading time
      // This helps warm up the camera hardware before Agora initialization
      if (kDebugMode) {
        print('Pre-warming camera for faster initialization');
      }

      // Small delay to allow camera hardware to initialize
      await Future.delayed(const Duration(milliseconds: 100));

      if (kDebugMode) {
        print('Camera pre-warming completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error pre-warming camera: $e');
      }
    }
  }

  void _listenToSocketEvents() {
    // Listen for socket connection status
    _socketSubscription =
        VChatController.I.nativeStreams.socketStatusStream.listen((event) {
      if (event.isConnected) {
        // Socket reconnected, refresh viewer count
        if (currentStream != null && !_isDisposed) {
          _updateViewerCount();
        }
      }
    });

    // Listen for live stream specific events
    final socket = VChatController.I.nativeApi.remote.socketIo.socket;

    // Join the stream room to receive stream-specific events
    if (currentStream != null) {
      socket.emit('join_stream_room', {'streamId': currentStream!.id});
    }

    // Listen for stream ended event
    socket.on('live_stream_ended', (data) {
      if (_isDisposed) return;

      final streamId = data['streamId'] as String?;
      if (streamId == currentStream?.id) {
        if (kDebugMode) {
          print('Stream ended: $streamId');
        }

        // Mark stream as ended
        if (!_isDisposed) {
          streamEnded.value = true;
        }

        // Notify the view that stream ended
        onStreamEndedCallback?.call();
      }
    });

    // Listen for viewer count updates
    socket.on('stream_viewer_count_updated', (data) {
      if (_isDisposed) return;

      final streamId = data['streamId'] as String?;
      final newCount = data['viewerCount'] as int?;

      if (streamId == currentStream?.id && newCount != null && !_isDisposed) {
        viewerCount.value = newCount;
      }
    });

    // Listen for join request events (for streamers)
    socket.on('join_request_received', (data) {
      if (_isDisposed || !isStreamer) return;

      final streamId = data['streamId'] as String?;
      if (kDebugMode) {
        print('📨 join_request_received: streamId=$streamId, currentStream=${currentStream?.id}');
      }
      if (streamId == currentStream?.id) {
        if (kDebugMode) {
          print('✅ Reloading join requests for this stream');
        }
        // Reload join requests to get the latest list
        loadJoinRequests();
      }
    });

    // Room-wide approval notification (e.g., when a viewer is approved)
    socket.on('join_request_approved', (data) {
      if (_isDisposed) return;

      final streamId = data['streamId'] as String?;
      if (streamId == currentStream?.id) {
        if (kDebugMode) {
          print('join_request_approved received for this stream');
        }
        _updateViewerCount();
      }
    });

    // Listen for host-initiated invite responses from invitees (for streamers)
    socket.on('join_invite_response', (data) {
      if (_isDisposed || !isStreamer) return;

      final streamId = data['streamId'] as String?;
      final action = data['action'] as String?; // 'accept' | 'reject'
      if (streamId == currentStream?.id) {
        if (kDebugMode) {
          print('Invite response received: action=$action for stream $streamId');
        }
        // Refresh join requests list; if accepted, participant list/viewer count
        loadJoinRequests();
        _updateViewerCount();
      }
    });

    // Listen for participant removal events
    socket.on('participant_removed', (data) {
      if (_isDisposed) return;

      final streamId = data['streamId'] as String?;
      final removedUserId = data['userId'] as String?;
      final reason = data['reason'] as String?;

      if (streamId == currentStream?.id && removedUserId == currentUserId) {
        if (kDebugMode) {
          print('You have been removed from the stream. Reason: $reason');
        }

        // Force leave the stream
        _handleForcedRemoval(reason);
      }
    });

    // Listen for participant ban events
    socket.on('participant_banned', (data) {
      if (_isDisposed) return;

      final streamId = data['streamId'] as String?;
      final bannedUserId = data['userId'] as String?;
      final reason = data['reason'] as String?;

      if (streamId == currentStream?.id && bannedUserId == currentUserId) {
        if (kDebugMode) {
          print('You have been banned from the stream. Reason: $reason');
        }

        // Force leave the stream
        _handleForcedRemoval(reason, isBanned: true);
      }
    });

    // Listen for direct removal events (sent specifically to the user)
    socket.on('removed_from_stream', (data) {
      if (_isDisposed) return;

      final streamId = data['streamId'] as String?;
      final reason = data['reason'] as String?;

      if (streamId == currentStream?.id) {
        if (kDebugMode) {
          print('Direct removal notification: $reason');
        }

        // Force leave the stream
        _handleForcedRemoval(reason);
      }
    });

    // Listen for direct ban events (sent specifically to the user)
    socket.on('banned_from_stream', (data) {
      if (_isDisposed) return;

      final streamId = data['streamId'] as String?;
      final reason = data['reason'] as String?;

      if (streamId == currentStream?.id) {
        if (kDebugMode) {
          print('Direct ban notification: $reason');
        }

        // Force leave the stream
        _handleForcedRemoval(reason, isBanned: true);
      }
    });

    // Listen for stream like events
    socket.on('stream_liked', (data) {
      if (_isDisposed) return;

      final streamId = data['streamId'] as String?;
      final newLikesCount = data['likesCount'] as int?;

      if (streamId == currentStream?.id &&
          newLikesCount != null &&
          !_isDisposed) {
        likesCount.value = newLikesCount;
      }
    });

    // Listen for stream unlike events
    socket.on('stream_unliked', (data) {
      if (_isDisposed) return;

      final streamId = data['streamId'] as String?;
      final newLikesCount = data['likesCount'] as int?;

      if (streamId == currentStream?.id &&
          newLikesCount != null &&
          !_isDisposed) {
        likesCount.value = newLikesCount;
      }
    });

    // Listen for filter updates from host (for participants)
    socket.on('stream_filter_updated', (data) {
      if (_isDisposed) return;

      final streamId = data['streamId'] as String?;
      final filterData = data['filterData'] as Map<String, dynamic>?;

      if (streamId == currentStream?.id && filterData != null && !isStreamer) {
        try {
          // Parse filter data and update participant's filter controller
          final filterType = FilterType.values.firstWhere(
            (e) => e.name == filterData['filterType'],
            orElse: () => FilterType.none,
          );
          final faceFilterType = FaceFilterType.values.firstWhere(
            (e) => e.name == filterData['faceFilterType'],
            orElse: () => FaceFilterType.none,
          );
          final intensity =
              (filterData['intensity'] as num?)?.toDouble() ?? 1.0;
          final isEnabled = filterData['isEnabled'] as bool? ?? false;

          final updatedFilter = StreamFilterModel(
            filterType: filterType,
            faceFilterType: faceFilterType,
            intensity: intensity,
            isEnabled: isEnabled,
          );

          // Update filter controller for participants
          _filterController.updateFilterFromHost(updatedFilter);

          if (kDebugMode) {
            print(
                'Received filter update from host: ${filterType.name}, ${faceFilterType.name}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error processing filter update: $e');
          }
        }
      }
    });

    // Start periodic viewer count updates as fallback
    _viewerCountTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (currentStream != null && !streamEnded.value) {
        _updateViewerCount();
      }
    });
  }

  void _setupFilterBroadcasting() {
    // Set up callback for filter changes to broadcast to participants
    _filterController.setOnFilterChangedCallback((filter) async {
      if (currentStream == null || _isDisposed) return;

      try {
        // Send filter update to backend which will broadcast to participants
        await _apiService.updateStreamFilter(
          currentStream!.id,
          filter.filterType.name,
          filter.faceFilterType.name,
          filter.intensity,
          filter.isEnabled,
        );

        if (kDebugMode) {
          print(
              'Broadcasted filter change: ${filter.filterType.name}, ${filter.faceFilterType.name}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error broadcasting filter change: $e');
        }
      }
    });
  }

  Future<void> _updateViewerCount() async {
    if (_isDisposed) return;

    try {
      final updatedStream = await _apiService.getStreamById(currentStream!.id);
      if (!_isDisposed) {
        viewerCount.value = updatedStream.viewerCount;
        currentStream = updatedStream;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating viewer count: $e');
      }
    }
  }

  Future<void> toggleMute() async {
    if (agoraEngine == null || _isDisposed) return;

    final newMutedState = !isMuted.value;
    await agoraEngine!.muteLocalAudioStream(newMutedState);
    if (!_isDisposed) {
      isMuted.value = newMutedState;
    }
  }

  Future<void> toggleCamera() async {
    if (agoraEngine == null || !isStreamer || _isDisposed) return;

    final newCameraState = !isCameraOn.value;
    await agoraEngine!.muteLocalVideoStream(!newCameraState);
    if (!_isDisposed) {
      isCameraOn.value = newCameraState;
    }
  }

  Future<void> switchCamera() async {
    if (agoraEngine == null || !isStreamer) return;

    await agoraEngine!.switchCamera();
  }

  Future<void> toggleSpeaker() async {
    if (agoraEngine == null || _isDisposed) return;

    final newSpeakerState = !isSpeakerOn.value;
    await agoraEngine!.setEnableSpeakerphone(newSpeakerState);
    if (!_isDisposed) {
      isSpeakerOn.value = newSpeakerState;
    }
  }

  Future<void> endStream() async {
    if (currentStream == null) return;

    try {
      if (isStreamer) {
        // End the stream on the server
        await _apiService.endLiveStream(currentStream!.id);

        if (kDebugMode) {
          print('Stream ended successfully: ${currentStream!.id}');
        }

        // Immediately broadcast ended to remove red ring for everyone locally
        try {
          final storyStatus = GetIt.I.get<StoryStatusService>();
          storyStatus.setUserLiveEnded(userId: currentStream!.streamerId);
        } catch (_) {}

        // Refresh the watch streams list to remove this ended stream
        _refreshWatchStreams();
      } else {
        // Leave the stream as viewer
        await _apiService.leaveLiveStream(currentStream!.id);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error ending stream: $e');
      }
    }

    // Leave Agora channel
    await _leaveChannel();
  }

  void _refreshWatchStreams() {
    try {
      // Get the WatchLiveController and refresh the streams immediately
      final watchController = GetIt.I.get<WatchLiveController>();

      // Refresh immediately
      watchController.refreshStreams();

      // Also refresh after a short delay to ensure backend has updated
      Future.delayed(const Duration(seconds: 2), () {
        watchController.refreshStreams();
      });

      if (kDebugMode) {
        print('Triggered immediate refresh of watch streams list');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing watch streams: $e');
      }
    }
  }

  Future<void> _leaveChannel() async {
    if (agoraEngine == null) return;

    try {
      await agoraEngine!.leaveChannel();
    } catch (_) {}
    // Prevent duplicate-join races; mark as not in channel immediately
    _inChannel = false;
    if (isStreamer) {
      try { await agoraEngine!.stopPreview(); } catch (_) {}
    }
    if (VPlatforms.isWeb) {
      // Ensure we disconnect the shadow JS client
      try { await shadowLeave(); } catch (_) {}
    }
  }

  void resetController() {
    // Reset state without disposing ValueNotifiers
    if (!_isDisposed) {
      // Clear callbacks first
      onStreamEndedCallback = null;
      onStreamEndedWithReasonCallback = null;

      _socketSubscription?.cancel();
      _viewerCountTimer?.cancel();
      _leaveSocketRoom();
      _leaveChannel();
      agoraEngine?.release();

      // Reset values to defaults
      isLoading.value = false;
      isMuted.value = false;
      isCameraOn.value = true;
      isSpeakerOn.value = false;
      remoteUsers.value = [];
      viewerCount.value = 0;
      streamEnded.value = false;
      likesCount.value = 0;
      isLiked.value = false;
      isRecording.value = false;
      recordingDuration.value = '00:00';
      isBroadcaster.value = false;

      // Reset other properties
      agoraEngine = null;
      currentStream = null;
      isStreamer = false;
    }
  }

  void _leaveSocketRoom() {
    if (currentStream != null) {
      try {
        final socket = VChatController.I.nativeApi.remote.socketIo.socket;
        socket.emit('leave_stream_room', {'streamId': currentStream!.id});
      } catch (e) {
        if (kDebugMode) {
          print('Error leaving socket room: $e');
        }
      }
    }
  }

  void _handleForcedRemoval(String? reason, {bool isBanned = false}) {
    if (_isDisposed) return;

    // Leave the Agora channel immediately
    _leaveChannel();

    // Leave the socket room
    _leaveSocketRoom();

    // Mark stream as ended for this user
    if (!_isDisposed) {
      streamEnded.value = true;
    }

    // Use a delayed callback to ensure UI operations happen after current frame
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isDisposed) return;

      // Notify the UI with removal information
      if (onStreamEndedWithReasonCallback != null) {
        onStreamEndedWithReasonCallback!(reason, isBanned);
      } else {
        // Fallback to the regular callback
        onStreamEndedCallback?.call();
      }
    });

    if (kDebugMode) {
      final action = isBanned ? 'banned from' : 'removed from';
      print('User was $action stream. Reason: $reason');
    }
  }

  // Participant Management Methods
  Future<List<participant_model.LiveStreamParticipantModel>> getParticipants(
      String streamId) async {
    try {
      final participants = await _apiService.getStreamParticipants(streamId);
      return participants
          .map((p) =>
              participant_model.LiveStreamParticipantModel.fromMap(p.toMap()))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting participants: $e');
      }
      throw Exception('Failed to get participants: $e');
    }
  }

  Future<void> removeParticipant({
    required String streamId,
    required String participantId,
    String? reason,
  }) async {
    try {
      await _apiService.removeParticipant(
        streamId: streamId,
        participantId: participantId,
        reason: reason,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error removing participant: $e');
      }
      throw Exception('Failed to remove participant: $e');
    }
  }

  Future<void> banParticipant({
    required String streamId,
    required String participantId,
    String? reason,
    String? duration,
  }) async {
    try {
      await _apiService.banParticipant(
        streamId: streamId,
        participantId: participantId,
        reason: reason,
        duration: duration,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error banning participant: $e');
      }
      throw Exception('Failed to ban participant: $e');
    }
  }

  Future<void> likeStream() async {
    print(
        'likeStream called - currentStream: ${currentStream?.id}, disposed: $_isDisposed'); // Debug
    if (currentStream == null || _isDisposed) {
      print('Returning early - currentStream is null or disposed'); // Debug
      return;
    }

    try {
      print(
          'Calling API service likeStream for stream: ${currentStream!.id}'); // Debug
      final result = await _apiService.likeStream(currentStream!.id);
      print('API response: $result'); // Debug

      if (!_isDisposed) {
        final newLikesCount = result['likesCount'] ?? 0;
        final newIsLiked = result['isLiked'] ?? false;
        print(
            'Updating UI - likesCount: $newLikesCount, isLiked: $newIsLiked'); // Debug

        likesCount.value = newLikesCount;
        isLiked.value = newIsLiked;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error liking stream: $e');
      }
      rethrow;
    }
  }

  Future<void> updateLikesFromStream() async {
    if (currentStream == null || _isDisposed) return;

    if (!_isDisposed) {
      likesCount.value = currentStream!.likesCount;
      isLiked.value = currentStream!.likedBy.contains(currentUserId);
    }
  }

  // Get current user ID for UI logic
  String get currentUserId {
    return AppAuth.myId;
  }

  // Join request functionality
  List<Map<String, dynamic>> _joinRequests = [];
  List<Map<String, dynamic>> get joinRequests => _joinRequests;

  Future<void> requestJoinStream({String requestType = 'viewer'}) async {
    if (currentStream == null) return;

    try {
      if (kDebugMode) {
        print('📤 Sending join request: streamId=${currentStream!.id}, requestType=$requestType');
      }
      await _apiService.requestJoinStream(currentStream!.id, requestType: requestType);
      if (kDebugMode) {
        print('✅ Join request sent successfully');
      }
      // success handled by UI layer if needed
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending join request: $e');
      }
      // Error will be handled in the UI
      rethrow;
    }
  }

  Future<void> loadJoinRequests() async {
    if (currentStream == null || !isStreamer) {
      if (kDebugMode) {
        print(
            "Not loading join requests - currentStream: $currentStream, isStreamer: $isStreamer");
      }
      return;
    }

    try {
      if (kDebugMode) {
        print("Loading join requests for stream: ${currentStream!.id}");
      }
      _joinRequests = await _apiService.getJoinRequests(currentStream!.id);
      if (kDebugMode) {
        print("Loaded ${_joinRequests.length} join requests: $_joinRequests");
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Failed to load join requests: $e");
      }
    }
  }

  Future<void> respondToJoinRequest(String requestId, bool approve) async {
    try {
      final action = approve ? 'approve' : 'reject';
      await _apiService.respondToJoinRequest(requestId, action);

      // Remove the request from the list
      _joinRequests.removeWhere((request) =>
          request['id'] == requestId || request['_id'] == requestId);
      notifyListeners();

      if (kDebugMode) {
        print("Join request ${approve ? 'approved' : 'rejected'}: $requestId");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Failed to respond to join request: $e");
      }
      rethrow;
    }
  }

  // Recording Methods
  Future<void> startRecording({String? quality}) async {
    if (currentStream == null || !isStreamer || _isDisposed) return;
    
    if (isRecording.value) {
      throw Exception('Recording is already in progress');
    }

    try {
      final result = await _apiService.startRecording(
        streamId: currentStream!.id,
        quality: quality ?? '720p',
      );
      
      if (result['success'] == true) {
        isRecording.value = true;
        _recordingStartTime = DateTime.now();
        _startRecordingTimer();
        
        if (kDebugMode) {
          print('Recording started successfully');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error starting recording: $e');
      }
      rethrow;
    }
  }

  Future<void> stopRecording() async {
    if (currentStream == null || !isStreamer || _isDisposed) return;
    if (!isRecording.value) throw Exception('No recording in progress');

    try {
      final duration = _recordingStartTime != null 
          ? DateTime.now().difference(_recordingStartTime!).inSeconds 
          : 0;

      // Generate unique recording URL for this stream session
      // In production, this would be the actual path where Agora Cloud Recording saves the file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final recordingUrl = '/recordings/stream_${currentStream!.id}_${timestamp}.mp4';

      await _apiService.stopRecording(
        streamId: currentStream!.id,
        recordingUrl: recordingUrl,
        duration: duration,
      );

      isRecording.value = false;
      _stopRecordingTimer();
      _recordingStartTime = null;
      
      if (kDebugMode) {
        print('Recording saved successfully! Duration: ${_formatDuration(duration)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping recording: $e');
      }
      rethrow;
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !isRecording.value || _recordingStartTime == null) {
        timer.cancel();
        return;
      }
      
      final duration = DateTime.now().difference(_recordingStartTime!);
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      recordingDuration.value = '$minutes:$seconds';
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    recordingDuration.value = '00:00';
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Clear callbacks first to prevent any further UI updates
    onStreamEndedCallback = null;
    onStreamEndedWithReasonCallback = null;

    _socketSubscription?.cancel();
    _viewerCountTimer?.cancel();
    _qualityUpgradeTimer?.cancel();
    _leaveSocketRoom();
    _leaveChannel();
    agoraEngine?.release();

    isLoading.dispose();
    loadingStatus.dispose();
    isMuted.dispose();
    isCameraOn.dispose();
    isSpeakerOn.dispose();
    remoteUsers.dispose();
    viewerCount.dispose();
    streamEnded.dispose();
    likesCount.dispose();
    isLiked.dispose();
    isRecording.dispose();
    recordingDuration.dispose();
    isBroadcaster.dispose();
    _recordingTimer?.cancel();

    // Dispose filter controller
    _filterController.dispose();

    super.dispose();
  }
}
