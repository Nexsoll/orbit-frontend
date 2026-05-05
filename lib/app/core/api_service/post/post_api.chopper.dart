// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'post_api.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$PostApi extends PostApi {
  _$PostApi([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = PostApi;

  @override
  Future<Response<dynamic>> getPosts({
    int page = 1,
    int limit = 20,
    String? postType,
    String? hashtag,
  }) {
    final Uri $url = Uri.parse('/posts/');
    final Map<String, dynamic> $params = <String, dynamic>{
      'page': page,
      'limit': limit,
      'postType': postType,
      'hashtag': hashtag,
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
  Future<Response<dynamic>> getReels({
    int page = 1,
    int limit = 20,
  }) {
    final Uri $url = Uri.parse('/posts/reels');
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
  Future<Response<dynamic>> getMyPosts({
    int page = 1,
    int limit = 20,
  }) {
    final Uri $url = Uri.parse('/posts/my');
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
  Future<Response<dynamic>> getPost(String id) {
    final Uri $url = Uri.parse('/posts/${id}');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> createPost(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('/posts/');
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
  Future<Response<dynamic>> createPostWithMedia(
    String postType,
    String? caption,
    String? location,
    bool? isReel,
    MultipartFile? file,
  ) {
    final Uri $url = Uri.parse('/posts/upload');
    final List<PartValue> $parts = <PartValue>[
      PartValue<String>(
        'postType',
        postType,
      ),
      PartValue<String?>(
        'caption',
        caption,
      ),
      PartValue<String?>(
        'location',
        location,
      ),
      PartValue<bool?>(
        'isReel',
        isReel,
      ),
      PartValueFile<MultipartFile?>(
        'files',
        file,
      ),
    ];
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updatePost(
    String id,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/posts/${id}');
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
  Future<Response<dynamic>> deletePost(String id) {
    final Uri $url = Uri.parse('/posts/${id}');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> likePost(String id) {
    final Uri $url = Uri.parse('/posts/${id}/like');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
