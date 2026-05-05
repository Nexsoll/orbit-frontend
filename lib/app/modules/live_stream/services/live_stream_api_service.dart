// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:chopper/chopper.dart';

import '../../../core/api_service/interceptors.dart';
import '../api/live_stream_api.dart';
import '../models/live_stream_model.dart';
import '../models/live_stream_recording_model.dart';
import '../models/live_category_model.dart';

class LiveStreamApiService {
  static LiveStreamApi? _liveStreamApi;

  LiveStreamApiService._();

  static LiveStreamApiService init() {
    _liveStreamApi = GetIt.I.get<LiveStreamApi>();
    return LiveStreamApiService._();
  }

  // ===== Support Donation (Viewer -> Host via M-Pesa STK) =====
  Future<Map<String, dynamic>> initiateSupportDonation({
    required String streamId,
    required double amount,
    required String phone,
  }) async {
    final client = _liveStreamApi!.client;
    final req = Request(
      'POST',
      Uri.parse('live-stream/$streamId/support'),
      client.baseUrl,
      body: {
        'amount': amount,
        'phone': phone,
      },
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  // ===== Wallet-based Support (Viewer -> Host, deduct from wallet) =====
  Future<Map<String, dynamic>> support({
    required String streamId,
    required num amount,
  }) async {
    final client = _liveStreamApi!.client;
    final req = Request(
      'POST',
      Uri.parse('live-stream/$streamId/support-wallet'),
      client.baseUrl,
      body: {
        'amount': amount,
      },
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  // ===== Gift Purchase (Viewer buys a gift via M-Pesa STK) =====
  Future<Map<String, dynamic>> initiateGiftPurchase({
    required String streamId,
    required String giftId,
    required String phone,
  }) async {
    final client = _liveStreamApi!.client;
    final req = Request(
      'POST',
      Uri.parse('live-stream/$streamId/gift/$giftId/purchase'),
      client.baseUrl,
      body: {
        'phone': phone,
      },
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> getGiftPurchaseStatus({
    required String streamId,
    required String giftId,
  }) async {
    final client = _liveStreamApi!.client;
    final req = Request(
      'GET',
      Uri.parse('live-stream/$streamId/gift/$giftId/purchase/status'),
      client.baseUrl,
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> getSupportDonationStatus({
    required String streamId,
    required String donationId,
  }) async {
    final client = _liveStreamApi!.client;
    final req = Request(
      'GET',
      Uri.parse('live-stream/$streamId/support/$donationId/status'),
      client.baseUrl,
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<LiveStreamModel> createLiveStream({
    required String title,
    String? description,
    bool? isPrivate,
    bool? requiresApproval,
    double? joinPrice,
    List<String>? allowedViewers,
    List<String>? tags,
    String? thumbnailUrl,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      if (description != null) 'description': description,
      if (isPrivate != null) 'isPrivate': isPrivate,
      if (requiresApproval != null) 'requiresApproval': requiresApproval,
      if (joinPrice != null) 'joinPrice': joinPrice,
      if (allowedViewers != null) 'allowedViewers': allowedViewers,
      if (tags != null) 'tags': tags,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    };

    final res = await _liveStreamApi!.createLiveStream(body);
    throwIfNotSuccess(res);

    final data = extractDataFromResponse(res);
    return LiveStreamModel.fromMap(data);
  }

  Future<LiveStreamModel> startLiveStream(String streamId) async {
    final res = await _liveStreamApi!.startLiveStream(streamId);
    throwIfNotSuccess(res);

    final data = extractDataFromResponse(res);
    return LiveStreamModel.fromMap(data);
  }

  Future<LiveStreamModel> endLiveStream(String streamId) async {
    final res = await _liveStreamApi!.endLiveStream(streamId);
    throwIfNotSuccess(res);

    final data = extractDataFromResponse(res);
    return LiveStreamModel.fromMap(data);
  }

  Future<Map<String, dynamic>> joinLiveStream(String streamId) async {
    final res = await _liveStreamApi!.joinLiveStream(streamId);
    throwIfNotSuccess(res);

    final data = extractDataFromResponse(res);
    return {
      'stream': LiveStreamModel.fromMap(data['stream']),
      'agoraToken': data['agoraToken'],
    };
  }

  Future<void> leaveLiveStream(String streamId) async {
    final res = await _liveStreamApi!.leaveLiveStream(streamId);
    throwIfNotSuccess(res);
  }

  Future<LiveStreamMessageModel> sendMessage({
    required String streamId,
    required String message,
    String? messageType,
    Map<String, dynamic>? giftData,
  }) async {
    // Check if API is initialized
    if (_liveStreamApi == null) {
      throw Exception('LiveStreamApi is not initialized');
    }

    // Validate streamId
    if (streamId.isEmpty) {
      throw Exception('StreamId cannot be empty');
    }

    // Validate message
    if (message.trim().isEmpty) {
      throw Exception('Message cannot be empty');
    }

    final body = <String, dynamic>{
      'message': message.trim(),
      if (messageType != null) 'messageType': messageType,
      if (giftData != null) 'giftData': giftData,
    };

    final res = await _liveStreamApi!.sendMessage(streamId, body);
    throwIfNotSuccess(res);

    final data = extractDataFromResponse(res);
    return LiveStreamMessageModel.fromMap(data);
  }

  Future<Map<String, dynamic>> updateStreamFilter(
    String streamId,
    String filterType,
    String faceFilterType,
    double intensity,
    bool isEnabled,
  ) async {
    final body = <String, dynamic>{
      'filterType': filterType,
      'faceFilterType': faceFilterType,
      'intensity': intensity,
      'isEnabled': isEnabled,
    };

    final res = await _liveStreamApi!.updateStreamFilter(streamId, body);
    throwIfNotSuccess(res);

    return extractDataFromResponse(res);
  }

  Future<List<LiveStreamModel>> getLiveStreams({
    String? search,
    List<String>? tags,
    String? status,
    String? sortBy,
    String? sortOrder,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null) 'search': search,
      if (tags != null) 'tags': tags,
      if (status != null) 'status': status,
      if (sortBy != null) 'sortBy': sortBy,
      if (sortOrder != null) 'sortOrder': sortOrder,
    };

    final res = await _liveStreamApi!.getLiveStreams(queryParams);
    throwIfNotSuccess(res);

    final data = extractDataFromResponse(res);
    final streams = data['streams'] as List;
    return streams.map((stream) => LiveStreamModel.fromMap(stream)).toList();
  }

  Future<LiveStreamModel> getStreamById(String streamId) async {
    final res = await _liveStreamApi!.getStreamById(streamId);
    throwIfNotSuccess(res);

    final data = extractDataFromResponse(res);
    return LiveStreamModel.fromMap(data);
  }

  Future<List<LiveStreamMessageModel>> getStreamMessages({
    required String streamId,
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _liveStreamApi!.getStreamMessages(streamId, page, limit);
    throwIfNotSuccess(res);

    // Handle the response - it could be a direct list or wrapped in data
    final responseBody = res.body as Map<String, dynamic>;
    final List<dynamic> messages;

    if (responseBody.containsKey('data')) {
      final data = responseBody['data'];
      if (data is List) {
        messages = data;
      } else if (data is Map<String, dynamic> && data.containsKey('messages')) {
        messages = data['messages'] as List;
      } else {
        messages = [];
      }
    } else {
      messages = [];
    }

    return messages
        .map((message) =>
            LiveStreamMessageModel.fromMap(message as Map<String, dynamic>))
        .toList();
  }

  Future<List<LiveStreamParticipantModel>> getStreamParticipants(
      String streamId) async {
    final res = await _liveStreamApi!.getStreamParticipants(streamId);
    throwIfNotSuccess(res);

    // Handle the response - it could be a direct list or wrapped in data
    final responseBody = res.body as Map<String, dynamic>;
    final List<dynamic> participants;

    if (responseBody.containsKey('data')) {
      final data = responseBody['data'];
      if (data is List) {
        participants = data;
      } else if (data is Map<String, dynamic> &&
          data.containsKey('participants')) {
        participants = data['participants'] as List;
      } else {
        participants = [];
      }
    } else {
      participants = [];
    }

    return participants
        .map((participant) => LiveStreamParticipantModel.fromMap(
            participant as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateLiveStream({
    required String streamId,
    String? title,
    String? description,
    bool? isPrivate,
    List<String>? allowedViewers,
    List<String>? tags,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (isPrivate != null) 'isPrivate': isPrivate,
      if (allowedViewers != null) 'allowedViewers': allowedViewers,
      if (tags != null) 'tags': tags,
    };

    final res = await _liveStreamApi!.updateLiveStream(streamId, body);
    throwIfNotSuccess(res);
  }

  Future<void> deleteLiveStream(String streamId) async {
    final res = await _liveStreamApi!.deleteLiveStream(streamId);
    throwIfNotSuccess(res);
  }

  Future<LiveStreamMessageModel> pinMessage({
    required String streamId,
    required String messageId,
  }) async {
    final res = await _liveStreamApi!.pinMessage(streamId, messageId);
    throwIfNotSuccess(res);

    final data = extractDataFromResponse(res);
    return LiveStreamMessageModel.fromMap(data);
  }

  Future<void> unpinMessage({
    required String streamId,
    required String messageId,
  }) async {
    final res = await _liveStreamApi!.unpinMessage(streamId, messageId);
    throwIfNotSuccess(res);
  }

  Future<LiveStreamMessageModel?> getPinnedMessage(String streamId) async {
    final res = await _liveStreamApi!.getPinnedMessage(streamId);
    throwIfNotSuccess(res);

    try {
      final data = extractDataFromResponse(res);
      return LiveStreamMessageModel.fromMap(data);
    } catch (e) {
      // If no pinned message exists, return null
      return null;
    }
  }

  Future<Map<String, dynamic>> removeParticipant({
    required String streamId,
    required String participantId,
    String? reason,
  }) async {
    final body = <String, dynamic>{
      'participantId': participantId,
      if (reason != null) 'reason': reason,
    };

    final res = await _liveStreamApi!.removeParticipant(streamId, body);
    throwIfNotSuccess(res);

    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> banParticipant({
    required String streamId,
    required String participantId,
    String? reason,
    String? duration,
  }) async {
    final body = <String, dynamic>{
      'participantId': participantId,
      if (reason != null) 'reason': reason,
      if (duration != null) 'duration': duration,
    };

    final res = await _liveStreamApi!.banParticipant(streamId, body);
    throwIfNotSuccess(res);

    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> likeStream(String streamId) async {
    final res = await _liveStreamApi!.likeStream(streamId);
    throwIfNotSuccess(res);

    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> getStreamLikes(String streamId) async {
    final res = await _liveStreamApi!.getStreamLikes(streamId);
    throwIfNotSuccess(res);

    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> requestJoinStream(
    String streamId, {
    String? requestType,
    int? age,
    double? amountPaid,
  }) async {
    final body = <String, dynamic>{
      if (requestType != null) 'requestType': requestType,
      if (age != null) 'age': age,
      if (amountPaid != null) 'amountPaid': amountPaid,
    };
    final res = await _liveStreamApi!.requestJoinStream(streamId, body);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> respondToJoinRequest(
      String requestId, String action) async {
    final body = {'action': action};
    final res = await _liveStreamApi!.respondToJoinRequest(requestId, body);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> inviteUserToStream({
    required String streamId,
    required String userId,
    String? requestType,
  }) async {
    final body = <String, dynamic>{
      'userId': userId,
      if (requestType != null) 'requestType': requestType,
    };
    final res = await _liveStreamApi!.inviteUserToStream(streamId, body);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> respondToInvite({
    required String requestId,
    required String action, // 'accept' | 'reject'
  }) async {
    final body = <String, dynamic>{'action': action};
    final res = await _liveStreamApi!.respondToInvite(requestId, body);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<List<Map<String, dynamic>>> getJoinRequests(String streamId) async {
    try {
      final res = await _liveStreamApi!.getJoinRequests(streamId);
      throwIfNotSuccess(res);

      // Handle the response directly without using extractDataFromResponse
      final responseBody = res.body as Map<String, dynamic>;
      final data = responseBody['data'];

      if (kDebugMode) {
        print("Raw join requests data: $data");
        print("Data type: ${data.runtimeType}");
      }

      // Handle different response structures
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data.containsKey('requests')) {
        list = data['requests'] as List<dynamic>;
      } else if (data is Map && data.containsKey('data')) {
        list = data['data'] as List<dynamic>;
      } else {
        if (kDebugMode) {
          print("Unexpected data structure: $data");
        }
        return [];
      }

      return list
          .map<Map<String, dynamic>>((e) {
            try {
              if (e is Map<String, dynamic>) {
                if (kDebugMode) {
                  print("Join request item: $e");
                }
                return e;
              } else if (e is Map) {
                final converted = Map<String, dynamic>.from(e);
                if (kDebugMode) {
                  print("Converted join request item: $converted");
                }
                return converted;
              } else {
                if (kDebugMode) {
                  print("Non-map element in list: $e (${e.runtimeType})");
                }
                // If it's not a Map, skip this item
                return <String, dynamic>{};
              }
            } catch (castError) {
              if (kDebugMode) {
                print("Error casting element: $e, error: $castError");
              }
              // Skip invalid items
              return <String, dynamic>{};
            }
          })
          .where((item) => item.isNotEmpty)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print("Error in getJoinRequests: $e");
      }
      return [];
    }
  }

  // Recording Methods
  Future<Map<String, dynamic>> startRecording({
    required String streamId,
    String? quality,
  }) async {
    final res = await _liveStreamApi!.startRecording(streamId);
    throwIfNotSuccess(res);

    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> stopRecording({
    required String streamId,
    required String recordingUrl,
    int? duration,
    int? fileSize,
    String? thumbnailUrl,
  }) async {
    final body = <String, dynamic>{
      'recordingUrl': recordingUrl,
      if (duration != null) 'duration': duration,
      if (fileSize != null) 'fileSize': fileSize,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    };

    final res = await _liveStreamApi!.stopRecording(streamId, body);
    throwIfNotSuccess(res);

    return extractDataFromResponse(res);
  }

  Future<List<LiveStreamRecordingModel>> getRecordings({
    String? search,
    List<String>? tags,
    String? streamerId,
    String? status,
    String? sortBy,
    String? sortOrder,
    int page = 1,
    int limit = 20,
    String? scope, // 'all' to fetch publicly accessible recordings across users
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null) 'search': search,
      if (tags != null) 'tags': tags,
      if (streamerId != null) 'streamerId': streamerId,
      if (status != null) 'status': status,
      if (sortBy != null) 'sortBy': sortBy,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (scope != null) 'scope': scope,
    };

    final res = await _liveStreamApi!.getRecordings(queryParams);
    throwIfNotSuccess(res);

    final data = extractDataFromResponse(res);
    final recordings = data['recordings'] as List;
    return recordings.map((recording) => LiveStreamRecordingModel.fromMap(recording)).toList();
  }

  Future<LiveStreamRecordingModel> getRecordingById(String recordingId) async {
    final res = await _liveStreamApi!.getRecordingById(recordingId);
    throwIfNotSuccess(res);

    final data = extractDataFromResponse(res);
    return LiveStreamRecordingModel.fromMap(data);
  }

  // ===== Paid recordings =====
  Future<Map<String, dynamic>> getRecordingAccess(String recordingId) async {
    final res = await _liveStreamApi!.getRecordingAccess(recordingId);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> initiateRecordingPurchase({
    required String recordingId,
    required String phone,
  }) async {
    final body = <String, dynamic>{'phone': phone};
    final res = await _liveStreamApi!.initiateRecordingPurchase(recordingId, body);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<String> getRecordingPlaybackUrl(String recordingId) async {
    final res = await _liveStreamApi!.getRecordingPlayback(recordingId);
    throwIfNotSuccess(res);
    final data = extractDataFromResponse(res);
    return (data['url'] as String?) ?? '';
  }

  Future<LiveStreamRecordingModel> updateRecordingPrice({
    required String recordingId,
    double? price,
  }) async {
    final body = <String, dynamic>{
      // Send null or numeric. Treat <=0 as free
      'price': price,
    };
    final res = await _liveStreamApi!.updateRecordingPrice(recordingId, body);
    throwIfNotSuccess(res);
    final data = extractDataFromResponse(res);
    return LiveStreamRecordingModel.fromMap(data);
  }

  Future<Map<String, dynamic>> likeRecording(String recordingId) async {
    final res = await _liveStreamApi!.likeRecording(recordingId);
    throwIfNotSuccess(res);

    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> deleteRecording(String recordingId) async {
    final res = await _liveStreamApi!.deleteRecording(recordingId);
    throwIfNotSuccess(res);

    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> incrementRecordingViews(String recordingId) async {
    final res = await _liveStreamApi!.incrementRecordingViews(recordingId);
    throwIfNotSuccess(res);

    return extractDataFromResponse(res);
  }

  Future<LiveStreamRecordingModel> updateRecordingPrivacy({
    required String recordingId,
    required bool isPrivate,
    List<String>? allowedViewers,
  }) async {
    final body = <String, dynamic>{
      'isPrivate': isPrivate,
      if (allowedViewers != null) 'allowedViewers': allowedViewers,
    };
    final res = await _liveStreamApi!.updateRecordingPrivacy(recordingId, body);
    throwIfNotSuccess(res);
    final data = extractDataFromResponse(res);
    return LiveStreamRecordingModel.fromMap(data);
  }

  // Live Categories Methods
  Future<List<LiveCategoryModel>> getLiveCategories() async {
    try {
      final res = await _liveStreamApi!.getLiveCategories();
      throwIfNotSuccess(res);

      // Categories endpoint returns a list in data
      final responseBody = res.body as Map<String, dynamic>;
      final list = (responseBody['data'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => LiveCategoryModel.fromMap(e))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching live categories: $e');
      }
      return [];
    }
  }
}
