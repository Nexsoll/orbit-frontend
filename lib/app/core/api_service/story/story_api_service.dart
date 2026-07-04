// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:super_up/app/core/api_service/story/story_api.dart';
import 'package:super_up/app/core/models/story/create_story_dto.dart';
import 'package:super_up/app/core/models/story/story_model.dart';
import 'package:super_up/app/core/models/story/story_reaction_model.dart';
import 'package:super_up/app/core/models/story/story_reply_model.dart';
import 'package:super_up/app/core/models/story/story_view_count_model.dart';
import 'package:super_up/app/core/models/story/story_viewer_model.dart';
import 'package:super_up/app/core/services/story_media_cache_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:chopper/chopper.dart';
import 'package:http/http.dart' show MultipartFile;

import '../interceptors.dart';

class StoryApiService {
  static StoryApi? _storyApi;

  StoryApiService._();

  Future<void> createStory(CreateStoryDto dto) async {
    final body = dto.toListOfPartValue();
    debugPrint('createStory - storySource: ${dto.storySource}');
    debugPrint('createStory - body: $body');
    // If a second image (video thumbnail) exists, append it as another 'file' part
    if (dto.secondImage != null) {
      final second =
          await VPlatforms.getMultipartFile(source: dto.secondImage!);
      body.add(PartValueFile<MultipartFile?>(
        'file',
        second,
      ));
    }
    final res = await _storyApi!.createStory(
      body,
      dto.image == null
          ? null
          : await VPlatforms.getMultipartFile(
              source: dto.image!,
            ),
    );
    throwIfNotSuccess(res);
  }

  Future<void> deleteStory(String id) async {
    final res = await _storyApi!.deleteStory(id);
    throwIfNotSuccess(res);
  }

  Future<void> setSeen(String id) async {
    final res = await _storyApi!.setSeen(id);
    throwIfNotSuccess(res);
  }

  Future<List<UserStoryModel>> getUsersStories({
    int page = 1,
    int limit = 30,
    String storySource = 'main',
  }) async {
    final queryParams = {
      "page": page,
      "limit": limit,
      "storySource": storySource,
    };
    debugPrint('getUsersStories queryParams: $queryParams');
    final res = await _storyApi!.getUsersStories(queryParams);
    throwIfNotSuccess(res);
    final stories = (extractDataFromResponse(res)['docs'] as List)
        .map((e) => UserStoryModel.fromMap(e))
        .toList();
    unawaited(StoryMediaCacheService.I.prefetchStoryMedia(stories));
    return stories;
  }

  Future<UserStoryModel?> getMyStories({String storySource = 'main'}) async {
    final queryParams = {"storySource": storySource};
    debugPrint('getMyStories queryParams: $queryParams');
    final res = await _storyApi!.getMyStories(queryParams);
    throwIfNotSuccess(res);
    final l = extractDataFromResponse(res)['docs'] as List;
    if (l.isEmpty) return null;
    final mine = UserStoryModel.fromMap(l.first);
    unawaited(StoryMediaCacheService.I.prefetchStoryMedia([mine]));
    return mine;
  }

  Future<StoryReactionModel> reactToStory(String storyId,
      {String? emoji}) async {
    final body = emoji != null ? {"emoji": emoji} : <String, dynamic>{};
    final res = await _storyApi!.reactToStory(storyId, body);
    throwIfNotSuccess(res);
    return StoryReactionModel.fromMap(extractDataFromResponse(res));
  }

  Future<StoryReplyResponse> replyToStory(String storyId, String text) async {
    final res = await _storyApi!.replyToStory(storyId, {"text": text});
    throwIfNotSuccess(res);
    return StoryReplyResponse.fromMap(extractDataFromResponse(res));
  }

  Future<StoryViewCountModel> getStoryViewsCount(String storyId) async {
    final res = await _storyApi!.getStoryViewsCount(storyId);
    throwIfNotSuccess(res);
    return StoryViewCountModel.fromMap(extractDataFromResponse(res));
  }

  Future<StoryViewersResponse> getStoryViewers(
    String storyId, {
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _storyApi!.getStoryViews(storyId, {
      "page": page,
      "limit": limit,
    });
    throwIfNotSuccess(res);

    // Handle the response directly since it returns a List in data field
    final responseBody = res.body as Map<String, dynamic>;
    return StoryViewersResponse.fromMap(responseBody);
  }

  static StoryApiService init({
    Uri? baseUrl,
    String? accessToken,
  }) {
    _storyApi = StoryApi.create(
      accessToken: accessToken,
      baseUrl: baseUrl ?? StoryApi.storyReelsServiceBaseUrl,
    );
    return StoryApiService._();
  }
}
