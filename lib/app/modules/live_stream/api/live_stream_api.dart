// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:http/io_client.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../../core/api_service/interceptors.dart';

part 'live_stream_api.chopper.dart';

@ChopperApi(baseUrl: 'live-stream')
abstract class LiveStreamApi extends ChopperService {
  @Post(path: "/")
  Future<Response> createLiveStream(@Body() Map<String, dynamic> body);

  @Post(path: "/{id}/start", optionalBody: true)
  Future<Response> startLiveStream(@Path("id") String streamId);

  @Post(path: "/{id}/end", optionalBody: true)
  Future<Response> endLiveStream(@Path("id") String streamId);

  @Post(path: "/{id}/join", optionalBody: true)
  Future<Response> joinLiveStream(@Path("id") String streamId);

  @Post(path: "/{id}/leave", optionalBody: true)
  Future<Response> leaveLiveStream(@Path("id") String streamId);

  @Post(path: "/{id}/message")
  Future<Response> sendMessage(
    @Path("id") String streamId,
    @Body() Map<String, dynamic> body,
  );

  @Post(path: "/{id}/filter")
  Future<Response> updateStreamFilter(
    @Path("id") String streamId,
    @Body() Map<String, dynamic> body,
  );

  @Get(path: "/")
  Future<Response> getLiveStreams(@QueryMap() Map<String, dynamic> queries);

  @Get(path: "/{id}")
  Future<Response> getStreamById(@Path("id") String streamId);

  @Get(path: "/{id}/messages")
  Future<Response> getStreamMessages(
    @Path("id") String streamId,
    @Query("page") int page,
    @Query("limit") int limit,
  );

  @Get(path: "/{id}/participants")
  Future<Response> getStreamParticipants(@Path("id") String streamId);

  @Put(path: "/{id}")
  Future<Response> updateLiveStream(
    @Path("id") String streamId,
    @Body() Map<String, dynamic> body,
  );

  @Delete(path: "/{id}")
  Future<Response> deleteLiveStream(@Path("id") String streamId);

  @POST(path: "/{streamId}/message/{messageId}/pin", optionalBody: true)
  Future<Response> pinMessage(
    @Path("streamId") String streamId,
    @Path("messageId") String messageId,
  );

  @DELETE(path: "/{streamId}/message/{messageId}/pin")
  Future<Response> unpinMessage(
    @Path("streamId") String streamId,
    @Path("messageId") String messageId,
  );

  @GET(path: "/{id}/pinned-message")
  Future<Response> getPinnedMessage(@Path("id") String streamId);

  @POST(path: "/{id}/remove-participant")
  Future<Response> removeParticipant(
    @Path("id") String streamId,
    @Body() Map<String, dynamic> body,
  );

  @POST(path: "/{id}/ban-participant")
  Future<Response> banParticipant(
    @Path("id") String streamId,
    @Body() Map<String, dynamic> body,
  );

  @POST(path: "/{id}/like", optionalBody: true)
  Future<Response> likeStream(@Path("id") String streamId);

  @GET(path: "/{id}/likes")
  Future<Response> getStreamLikes(@Path("id") String streamId);

  @POST(path: "/{id}/request-join", optionalBody: true)
  Future<Response> requestJoinStream(
    @Path("id") String streamId,
    @Body() Map<String, dynamic> body,
  );

  @POST(path: "/join-request/{requestId}/respond")
  Future<Response> respondToJoinRequest(
    @Path("requestId") String requestId,
    @Body() Map<String, dynamic> body,
  );

  @GET(path: "/{id}/join-requests")
  Future<Response> getJoinRequests(@Path("id") String streamId);

  // Host invite endpoints
  @POST(path: "/{id}/invite")
  Future<Response> inviteUserToStream(
    @Path("id") String streamId,
    @Body() Map<String, dynamic> body,
  );

  @POST(path: "/invite/{requestId}/respond")
  Future<Response> respondToInvite(
    @Path("requestId") String requestId,
    @Body() Map<String, dynamic> body,
  );

  // Recording endpoints
  @POST(path: "/{id}/start-recording", optionalBody: true)
  Future<Response> startRecording(@Path("id") String streamId);

  @POST(path: "/{id}/stop-recording")
  Future<Response> stopRecording(
    @Path("id") String streamId,
    @Body() Map<String, dynamic> body,
  );

  @GET(path: "/recordings")
  Future<Response> getRecordings(@QueryMap() Map<String, dynamic> queries);

  @GET(path: "/recordings/{id}")
  Future<Response> getRecordingById(@Path("id") String recordingId);

  @POST(path: "/recordings/{id}/like", optionalBody: true)
  Future<Response> likeRecording(@Path("id") String recordingId);

  @DELETE(path: "/recordings/{id}")
  Future<Response> deleteRecording(@Path("id") String recordingId);

  @POST(path: "/recordings/{id}/view", optionalBody: true)
  Future<Response> incrementRecordingViews(@Path("id") String recordingId);

  @Put(path: "/recordings/{id}/privacy")
  Future<Response> updateRecordingPrivacy(
    @Path("id") String recordingId,
    @Body() Map<String, dynamic> body,
  );

  // Update recording price (null or <=0 means free)
  @Put(path: "/recordings/{id}/price")
  Future<Response> updateRecordingPrice(
    @Path("id") String recordingId,
    @Body() Map<String, dynamic> body,
  );

  // Paid recordings
  @GET(path: "/recordings/{id}/access")
  Future<Response> getRecordingAccess(@Path("id") String recordingId);

  @POST(path: "/recordings/{id}/purchase")
  Future<Response> initiateRecordingPurchase(
    @Path("id") String recordingId,
    @Body() Map<String, dynamic> body,
  );

  @GET(path: "/recordings/{id}/playback")
  Future<Response> getRecordingPlayback(@Path("id") String recordingId);

  // Live Categories
  @GET(path: "/categories")
  Future<Response> getLiveCategories();

  static LiveStreamApi create() {
    final baseUrl = SConstants.sApiBaseUrl;

    // Ensure baseUrl is not null
    if (baseUrl.toString().isEmpty) {
      throw Exception('Base URL is empty or null');
    }

    final client = ChopperClient(
      baseUrl: baseUrl,
      services: [
        _$LiveStreamApi(),
      ],
      converter: const JsonConverter(),
      interceptors: [AuthInterceptor()],
      errorConverter: ErrorInterceptor(),
      client: VPlatforms.isWeb
          ? null
          : IOClient(
              HttpClient()..connectionTimeout = const Duration(seconds: 10),
            ),
    );

    return _$LiveStreamApi(client);
  }
}
