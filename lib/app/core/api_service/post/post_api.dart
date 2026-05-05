import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:http/http.dart' hide Response, Request;
import 'package:http/io_client.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../interceptors.dart';
import '../safe_json_converter.dart';

part 'post_api.chopper.dart';

@ChopperApi(baseUrl: '/posts')
abstract class PostApi extends ChopperService {
  static PostApi create({
    Uri? baseUrl,
    String? accessToken,
  }) {
    final client = ChopperClient(
      baseUrl: baseUrl ?? SConstants.sApiBaseUrl,
      services: [
        _$PostApi(),
      ],
      converter: const SafeJsonConverter(),
      interceptors: [AuthInterceptor(access: accessToken)],
      errorConverter: ErrorInterceptor(),
      client: VPlatforms.isWeb
          ? null
          : IOClient(
              HttpClient()
                ..connectionTimeout = const Duration(seconds: 30),
            ),
    );

    return _$PostApi(client);
  }

  @Get(path: '/')
  Future<Response> getPosts({
    @Query('page') int page = 1,
    @Query('limit') int limit = 20,
    @Query('postType') String? postType,
    @Query('hashtag') String? hashtag,
  });

  @Get(path: '/reels')
  Future<Response> getReels({
    @Query('page') int page = 1,
    @Query('limit') int limit = 20,
  });

  @Get(path: '/my')
  Future<Response> getMyPosts({
    @Query('page') int page = 1,
    @Query('limit') int limit = 20,
  });

  @Get(path: '/{id}')
  Future<Response> getPost(@Path('id') String id);

  @Post(path: '/')
  Future<Response> createPost(@Body() Map<String, dynamic> body);

  @Multipart()
  @Post(path: '/upload')
  Future<Response> createPostWithMedia(
    @Part('postType') String postType,
    @Part('caption') String? caption,
    @Part('location') String? location,
    @Part('isReel') bool? isReel,
    @PartFile('files') MultipartFile? file,
  );

  @Put(path: '/{id}')
  Future<Response> updatePost(
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  @Delete(path: '/{id}')
  Future<Response> deletePost(@Path('id') String id);

  @Post(path: '/{id}/like')
  Future<Response> likePost(@Path('id') String id);
}
