// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

// Stub implementations for Agora types when running on web

class RtcEngine {
  // Stub implementation
  Future<void> initialize(RtcEngineContext context) async {}
  Future<void> registerEventHandler(RtcEngineEventHandler handler) async {}
  Future<void> setClientRole({required ClientRoleType role}) async {}
  Future<void> joinChannel({
    required String token,
    required String channelId,
    required int uid,
    required ChannelMediaOptions options,
  }) async {}
  Future<void> leaveChannel() async {}
  Future<void> release() async {}
  Future<void> enableVideo() async {}
  Future<void> startPreview() async {}
  Future<void> stopPreview() async {}
  Future<void> setEnableSpeakerphone(bool enabled) async {}
  Future<void> muteLocalVideoStream(bool muted) async {}
  Future<void> muteLocalAudioStream(bool muted) async {}
  Future<void> switchCamera() async {}
  Future<void> setVideoEncoderConfiguration(
      VideoEncoderConfiguration config) async {}
  Future<void> enableLocalVideo(bool enabled) async {}
  Future<void> setCameraAutoFocusFaceModeEnabled(bool enabled) async {}
  Future<void> setCameraExposurePosition({
    required double positionXinView,
    required double positionYinView,
  }) async {}
  Future<void> setCameraZoomFactor(double factor) async {}
}

class RtcEngineContext {
  final String appId;
  final ChannelProfileType channelProfile;

  const RtcEngineContext({
    required this.appId,
    required this.channelProfile,
  });
}

class RtcEngineEventHandler {
  final Function(RtcConnection, int)? onJoinChannelSuccess;
  final Function(RtcConnection, int, int)? onUserJoined;
  final Function(RtcConnection, int, UserOfflineReasonType)? onUserOffline;
  final Function(RtcConnection, RtcStats)? onLeaveChannel;
  final Function(ErrorCodeType, String)? onError;
  final Function(VideoSourceType, int, int, int)? onFirstLocalVideoFrame;

  const RtcEngineEventHandler({
    this.onJoinChannelSuccess,
    this.onUserJoined,
    this.onUserOffline,
    this.onLeaveChannel,
    this.onError,
    this.onFirstLocalVideoFrame,
  });
}

class RtcConnection {
  final String channelId;

  const RtcConnection({
    required this.channelId,
  });
}

class RtcStats {
  // Stub implementation
}

class ChannelMediaOptions {
  final ClientRoleType clientRoleType;
  final ChannelProfileType channelProfile;

  const ChannelMediaOptions({
    required this.clientRoleType,
    required this.channelProfile,
  });
}

class VideoCanvas {
  final int uid;

  const VideoCanvas({
    required this.uid,
  });
}

class VideoViewController {
  final RtcEngine rtcEngine;
  final VideoCanvas canvas;
  final RtcConnection? connection;

  const VideoViewController({
    required this.rtcEngine,
    required this.canvas,
    this.connection,
  });

  const VideoViewController.remote({
    required this.rtcEngine,
    required this.canvas,
    this.connection,
  });
}

enum ClientRoleType {
  clientRoleBroadcaster,
  clientRoleAudience,
}

enum ChannelProfileType {
  channelProfileLiveBroadcasting,
}

enum UserOfflineReasonType {
  userOfflineQuit,
  userOfflineDropped,
  userOfflineBecomeAudience,
}

enum ErrorCodeType {
  errOk,
  errFailed,
}

enum VideoSourceType {
  videoSourceCamera,
  videoSourceScreen,
}

class VideoEncoderConfiguration {
  const VideoEncoderConfiguration({
    this.dimensions,
    this.frameRate,
    this.bitrate,
    this.orientationMode,
    this.degradationPreference,
    this.mirrorMode,
  });

  final VideoDimensions? dimensions;
  final int? frameRate;
  final int? bitrate;
  final int? orientationMode;
  final int? degradationPreference;
  final int? mirrorMode;
}

class VideoDimensions {
  const VideoDimensions({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
}

// Stub functions
RtcEngine createAgoraRtcEngine() {
  return RtcEngine();
}
