// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:http/io_client.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../interceptors.dart';

part 'memory_api.chopper.dart';

@ChopperApi(baseUrl: 'memories')
abstract class MemoryApi extends ChopperService {
  @POST(path: "/")
  @multipart
  Future<Response> createMemory(
    @PartMap() List<PartValue> body,
  );

  @GET(path: "/")
  Future<Response> getMemories(
    @Query("page") int page,
    @Query("limit") int limit,
  );

  @GET(path: "/{id}")
  Future<Response> getMemory(@Path("id") String id);

  @DELETE(path: "/{id}")
  Future<Response> deleteMemory(@Path("id") String id);

  @DELETE(path: "/story/{storyId}")
  Future<Response> deleteMemoryByStoryId(@Path("storyId") String storyId);

  @GET(path: "/reminders/today")
  Future<Response> getTodayReminders();

  static MemoryApi create({
    Uri? baseUrl,
    String? accessToken,
  }) {
    final client = ChopperClient(
      baseUrl: SConstants.sApiBaseUrl,
      services: [
        _$MemoryApi(),
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
    return _$MemoryApi(client);
  }
}
