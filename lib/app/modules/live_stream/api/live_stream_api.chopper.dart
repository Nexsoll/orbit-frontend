// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'live_stream_api.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$LiveStreamApi extends LiveStreamApi {
  _$LiveStreamApi([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = LiveStreamApi;

  @override
  Future<Response<dynamic>> createLiveStream(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('live-stream/');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> startLiveStream(String streamId) {
    final Uri $url = Uri.parse('live-stream/${streamId}/start');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> endLiveStream(String streamId) {
    final Uri $url = Uri.parse('live-stream/${streamId}/end');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> joinLiveStream(String streamId) {
    final Uri $url = Uri.parse('live-stream/${streamId}/join');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> leaveLiveStream(String streamId) {
    final Uri $url = Uri.parse('live-stream/${streamId}/leave');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> sendMessage(
    String streamId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('live-stream/${streamId}/message');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateStreamFilter(
    String streamId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('live-stream/${streamId}/filter');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getLiveStreams(Map<String, dynamic> queries) {
    final Uri $url = Uri.parse('live-stream/');
    final Map<String, dynamic> $params = queries;
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getStreamById(String streamId) {
    final Uri $url = Uri.parse('live-stream/${streamId}');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getStreamMessages(
    String streamId,
    int page,
    int limit,
  ) {
    final Uri $url = Uri.parse('live-stream/${streamId}/messages');
    final Map<String, dynamic> $params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getStreamParticipants(String streamId) {
    final Uri $url = Uri.parse('live-stream/${streamId}/participants');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateLiveStream(
    String streamId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('live-stream/${streamId}');
    final $body = body;
    final Request $request = Request(
      'PUT',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> deleteLiveStream(String streamId) {
    final Uri $url = Uri.parse('live-stream/${streamId}');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> pinMessage(
    String streamId,
    String messageId,
  ) {
    final Uri $url =
        Uri.parse('live-stream/${streamId}/message/${messageId}/pin');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> unpinMessage(
    String streamId,
    String messageId,
  ) {
    final Uri $url =
        Uri.parse('live-stream/${streamId}/message/${messageId}/pin');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getPinnedMessage(String streamId) {
    final Uri $url = Uri.parse('live-stream/${streamId}/pinned-message');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> removeParticipant(
    String streamId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('live-stream/${streamId}/remove-participant');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> banParticipant(
    String streamId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('live-stream/${streamId}/ban-participant');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> likeStream(String streamId) {
    final Uri $url = Uri.parse('live-stream/${streamId}/like');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getStreamLikes(String streamId) {
    final Uri $url = Uri.parse('live-stream/${streamId}/likes');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> requestJoinStream(
    String streamId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('live-stream/${streamId}/request-join');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> respondToJoinRequest(
    String requestId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('live-stream/join-request/${requestId}/respond');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getJoinRequests(String streamId) {
    final Uri $url = Uri.parse('live-stream/${streamId}/join-requests');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> inviteUserToStream(
    String streamId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('live-stream/${streamId}/invite');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> respondToInvite(
    String requestId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('live-stream/invite/${requestId}/respond');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> startRecording(String streamId) {
    final Uri $url = Uri.parse('live-stream/${streamId}/start-recording');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> stopRecording(
    String streamId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('live-stream/${streamId}/stop-recording');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getRecordings(Map<String, dynamic> queries) {
    final Uri $url = Uri.parse('live-stream/recordings');
    final Map<String, dynamic> $params = queries;
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getRecordingById(String recordingId) {
    final Uri $url = Uri.parse('live-stream/recordings/${recordingId}');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> likeRecording(String recordingId) {
    final Uri $url = Uri.parse('live-stream/recordings/${recordingId}/like');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> deleteRecording(String recordingId) {
    final Uri $url = Uri.parse('live-stream/recordings/${recordingId}');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> incrementRecordingViews(String recordingId) {
    final Uri $url = Uri.parse('live-stream/recordings/${recordingId}/view');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateRecordingPrivacy(
    String recordingId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('live-stream/recordings/${recordingId}/privacy');
    final $body = body;
    final Request $request = Request(
      'PUT',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateRecordingPrice(
    String recordingId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('live-stream/recordings/${recordingId}/price');
    final $body = body;
    final Request $request = Request(
      'PUT',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getRecordingAccess(String recordingId) {
    final Uri $url = Uri.parse('live-stream/recordings/${recordingId}/access');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> initiateRecordingPurchase(
    String recordingId,
    Map<String, dynamic> body,
  ) {
    final Uri $url =
        Uri.parse('live-stream/recordings/${recordingId}/purchase');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getRecordingPlayback(String recordingId) {
    final Uri $url =
        Uri.parse('live-stream/recordings/${recordingId}/playback');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getLiveCategories() {
    final Uri $url = Uri.parse('live-stream/categories');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
