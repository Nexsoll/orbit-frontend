// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:http/io_client.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:http/http.dart' show MultipartFile;

import '../interceptors.dart';

part 'user_files_api.chopper.dart';

@ChopperApi(baseUrl: 'user/files')
abstract class UserFilesApi extends ChopperService {
  @GET()
  Future<Response> getUserFiles({
    @Query('page') int? page,
    @Query('limit') int? limit,
    @Query('fileType') String? fileType,
  });

  @GET(path: '/private-media')
  Future<Response> getPrivateMedia({
    @Query('page') int? page,
    @Query('limit') int? limit,
    @Query('fileType') String? fileType,
  });

  @DELETE(path: '/{fileId}')
  Future<Response> deleteFile(@Path('fileId') String fileId);

  @DELETE(path: '/private-media/{fileId}')
  Future<Response> deletePrivateMedia(@Path('fileId') String fileId);

  @DELETE()
  Future<Response> deleteMultipleFiles(@Body() Map<String, dynamic> body);

  @DELETE(path: '/private-media')
  Future<Response> deleteMultiplePrivateMedia(
    @Body() Map<String, dynamic> body,
  );

  @POST(path: '/cleanup')
  Future<Response> cleanupOrphanedFiles();

  @POST(path: '/upload')
  @multipart
  Future<Response> uploadFiles(@PartFile("file") MultipartFile file);

  @POST(path: '/private-media/upload')
  @multipart
  Future<Response> uploadPrivateMedia(@PartFile("file") MultipartFile file);

  @POST(path: '/test')
  Future<Response> testEndpoint(@Body() Map<String, dynamic> body);

  @POST(path: '/upload-simple')
  Future<Response> uploadSimple(@Body() Map<String, dynamic> body);

  @POST(path: '/upload-any')
  @multipart
  Future<Response> uploadAny(@PartFile("file") MultipartFile file);

  static UserFilesApi create({
    Uri? baseUrl,
    String? accessToken,
  }) {
    final client = ChopperClient(
      baseUrl: SConstants.sApiBaseUrl,
      services: [_$UserFilesApi()],
      converter: const JsonConverter(),
      interceptors: [AuthInterceptor()],
      errorConverter: ErrorInterceptor(),
      client: VPlatforms.isWeb
          ? null
          : IOClient(
              HttpClient()..connectionTimeout = const Duration(seconds: 10),
            ),
    );
    return _$UserFilesApi(client);
  }
}
