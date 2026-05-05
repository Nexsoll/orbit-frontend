import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:super_up/app/core/api_service/post/post_api.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../exceptions.dart';
import '../interceptors.dart';

class PostApiService {
  static PostApi? _postApi;
  static final ValueNotifier<int> socialFeedRefreshToken = ValueNotifier<int>(0);
  final PostApi? _postApiInstance;

  PostApiService._(this._postApiInstance);

  static void notifySocialFeedRefresh() {
    socialFeedRefreshToken.value = socialFeedRefreshToken.value + 1;
  }

  static PostApiService init({
    Uri? baseUrl,
    String? accessToken,
  }) {
    _postApi ??= PostApi.create(
      baseUrl: baseUrl,
      accessToken: accessToken,
    );
    return PostApiService._(_postApi);
  }

  static Map<String, String> _authHeaders() {
    final token =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<PostModel>> getPosts({
    int page = 1,
    int limit = 20,
    PostType? postType,
    String? hashtag,
  }) async {
    final res = await _postApiInstance!.getPosts(
      page: page,
      limit: limit,
      postType: postType?.name,
      hashtag: hashtag,
    );
    throwIfNotSuccess(res);
    final data = extractDataFromResponse(res);
    final docs = data['docs'] as List;
    return docs.map((e) => PostModel.fromMap(e)).toList();
  }

  Future<List<PostModel>> getReels({int page = 1, int limit = 20}) async {
    final res = await _postApiInstance!.getReels(page: page, limit: limit);
    throwIfNotSuccess(res);
    final data = extractDataFromResponse(res);
    final docs = data['docs'] as List;
    return docs.map((e) => PostModel.fromMap(e)).toList();
  }

  Future<List<PostModel>> getMyPosts({int page = 1, int limit = 20}) async {
    final res = await _postApiInstance!.getMyPosts(page: page, limit: limit);
    throwIfNotSuccess(res);
    final data = extractDataFromResponse(res);
    final docs = data['docs'] as List;
    return docs.map((e) => PostModel.fromMap(e)).toList();
  }

  Future<void> createTextPost({required String caption}) async {
    final body = {
      "postType": "text",
      "caption": caption,
    };
    debugPrint('createTextPost: $body');
    final res = await _postApiInstance!.createPost(body);
    throwIfNotSuccess(res);
  }

  /// Upload 1-10 photos for an image post via raw multipart HTTP.
  Future<void> createMultiPhotoPost({
    required List<VPlatformFile> files,
    String? caption,
  }) async {
    debugPrint('createMultiPhotoPost: ${files.length} files');
    await _multipartUpload(
      postType: 'image',
      caption: caption,
      files: files,
    );
  }

  /// Upload a single video post.
  Future<void> createVideoPost({
    required VPlatformFile file,
    String? caption,
  }) async {
    debugPrint('createVideoPost');
    await _multipartUpload(
      postType: 'video',
      caption: caption,
      files: [file],
    );
  }

  /// Upload a single reel video post.
  Future<void> createReelPost({
    required VPlatformFile file,
    String? caption,
  }) async {
    debugPrint('createReelPost');
    await _multipartUpload(
      postType: 'reel',
      caption: caption,
      files: [file],
      isReel: true,
    );
  }

  /// Create a check-in / location post (no media upload needed).
  Future<void> createLocationPost({
    required String caption,
    required Map<String, dynamic> location,
  }) async {
    final body = {
      "postType": "location",
      "caption": caption,
      "location": location,
    };
    debugPrint('createLocationPost: $body');
    final res = await _postApiInstance!.createPost(body);
    throwIfNotSuccess(res);
  }

  Future<PostModel> getPostById(String postId) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: '${SConstants.sApiBaseUrl.path}/posts/$postId',
    );
    final res = await http.get(uri, headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SuperHttpBadRequest(exception: 'Post not found');
    }
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map) return PostModel.fromMap(Map<String, dynamic>.from(data));
    throw SuperHttpBadRequest(exception: 'Invalid post response');
  }

  Future<void> likePost(String postId) async {
    final res = await _postApiInstance!.likePost(postId);
    throwIfNotSuccess(res);
  }

  Future<Map<String, dynamic>> sharePost(String postId) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: '${SConstants.sApiBaseUrl.path}/posts/$postId/share',
    );
    final res = await http.post(uri, headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SuperHttpBadRequest(exception: 'Failed to share post');
    }
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<List<Map<String, dynamic>>> listComments(
    String postId, {
    int page = 1,
    int limit = 50,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: '${SConstants.sApiBaseUrl.path}/posts/$postId/comments',
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final res = await http.get(uri, headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SuperHttpBadRequest(exception: 'Failed to load comments');
    }
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map && data['docs'] is List) {
      return List<Map<String, dynamic>>.from(data['docs']);
    }
    return [];
  }

  Future<Map<String, dynamic>> addComment(
    String postId,
    String text, {
    String? parentCommentId,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: '${SConstants.sApiBaseUrl.path}/posts/$postId/comments',
    );
    final res = await http.post(
      uri,
      headers: {..._authHeaders(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        if (parentCommentId != null && parentCommentId.isNotEmpty)
          'parentCommentId': parentCommentId,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SuperHttpBadRequest(exception: 'Failed to add comment');
    }
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> deleteComment(
    String postId,
    String commentId,
  ) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: '${SConstants.sApiBaseUrl.path}/posts/$postId/comments/$commentId',
    );
    final res = await http.delete(uri, headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SuperHttpBadRequest(exception: 'Failed to delete comment');
    }
    final body = jsonDecode(res.body);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<void> deletePost(String postId) async {
    final res = await _postApiInstance!.deletePost(postId);
    throwIfNotSuccess(res);
  }

  Future<void> updatePost(String postId, Map<String, dynamic> body) async {
    final res = await _postApiInstance!.updatePost(postId, body);
    throwIfNotSuccess(res);
  }

  // ─── legacy compat (single file) ────────────────────────────────────────────
  Future<void> createMediaPost({
    required PostType postType,
    required VPlatformFile file,
    String? caption,
    VPlatformFile? thumbnail,
    Map<String, dynamic>? location,
    bool isReel = false,
  }) async {
    await _multipartUpload(
      postType: postType.name,
      caption: caption,
      files: [file],
      isReel: isReel,
      locationJson: location != null ? jsonEncode(location) : null,
    );
  }

  // ─── raw multipart upload ────────────────────────────────────────────────────
  Future<void> _multipartUpload({
    required String postType,
    String? caption,
    List<VPlatformFile> files = const [],
    bool isReel = false,
    String? locationJson,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/posts/upload',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authHeaders());

    request.fields['postType'] = postType;
    if (caption != null && caption.isNotEmpty) request.fields['caption'] = caption;
    if (isReel) request.fields['isReel'] = 'true';
    if (locationJson != null) request.fields['location'] = locationJson;

    for (final f in files) {
      final path = f.fileLocalPath;
      if (path == null) continue;
      final ioFile = File(path);
      final stream = http.ByteStream(ioFile.openRead());
      final length = await ioFile.length();
      final mf = http.MultipartFile(
        'files',
        stream,
        length,
        filename: ioFile.path.split('/').last,
      );
      request.files.add(mf);
    }

    final streamed = await request.send();
    final body = await http.Response.fromStream(streamed);

    debugPrint('_multipartUpload status: ${body.statusCode}');

    if (body.statusCode < 200 || body.statusCode >= 300) {
      Map<String, dynamic>? err;
      try {
        err = jsonDecode(body.body) as Map<String, dynamic>;
      } catch (_) {}
      final msg = (err?['data'] ?? err?['message'] ?? 'Upload failed').toString();
      if (body.statusCode == 401) {
        unAuthStream450Error.add(true);
      }
      throw SuperHttpBadRequest(exception: msg);
    }
  }
}
