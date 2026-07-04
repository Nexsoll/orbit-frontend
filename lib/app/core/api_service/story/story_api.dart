// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:http/http.dart' hide Response, Request;
import 'package:http/io_client.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../interceptors.dart';
import '../safe_json_converter.dart';

part 'story_api.chopper.dart';

@ChopperApi(baseUrl: 'user-story')
abstract class StoryApi extends ChopperService {
  static Uri get storyReelsServiceBaseUrl {
    return SConstants.storyReelsApiBaseUrl;
  }

  @Post(path: "/")
  @multipart
  Future<Response> createStory(
    @PartMap() List<PartValue> body,
    @PartFile("file") MultipartFile? file,
  );

  @Delete(path: "/{id}", optionalBody: true)
  Future<Response> deleteStory(@Path("id") String id);

  @Get(path: "/")
  Future<Response> getUsersStories(@QueryMap() Map<String, dynamic> query);

  @Post(path: "/views/{id}")
  Future<Response> setSeen(@Path("id") String id);

  @Get(path: "/me")
  Future<Response> getMyStories(@QueryMap() Map<String, dynamic> query);

  @Post(path: "/views/{id}", optionalBody: true)
  Future<Response> addViewToStory();

  @Get(path: "/views/{id}")
  Future<Response> getStoryViews(
      @Path("id") String id, @QueryMap() Map<String, dynamic> query);

  @POST(path: "{storyId}/react")
  Future<Response> reactToStory(
    @Path("storyId") String storyId,
    @Body() Map<String, dynamic> body,
  );

  @POST(path: "{storyId}/reply")
  Future<Response> replyToStory(
    @Path("storyId") String storyId,
    @Body() Map<String, dynamic> body,
  );

  @GET(path: "{storyId}/views-count")
  Future<Response> getStoryViewsCount(@Path("storyId") String storyId);

  static StoryApi create({
    Uri? baseUrl,
    String? accessToken,
  }) {
    final client = ChopperClient(
      baseUrl: baseUrl ?? storyReelsServiceBaseUrl,
      services: [
        _$StoryApi(),
      ],
      converter: const SafeJsonConverter(),
      //, HttpLoggingInterceptor()
      interceptors: [AuthInterceptor()],
      errorConverter: ErrorInterceptor(),
      client: VPlatforms.isWeb
          ? null
          : IOClient(
              HttpClient()
                ..connectionTimeout = const Duration(seconds: 30)
                ..connectionTimeout = const Duration(minutes: 10),
            ),
    );
    return _$StoryApi(client);
  }
}
