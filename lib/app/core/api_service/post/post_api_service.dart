import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:super_up/app/core/api_service/post/post_api.dart';
import 'package:super_up/app/core/api_service/story/story_api.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../services/social_feed_cache_service.dart';
import '../exceptions.dart';
import '../interceptors.dart';

class PostApiService {
  static PostApi? _postApi;
  static final ValueNotifier<int> socialFeedRefreshToken =
      ValueNotifier<int>(0);
  static final ValueNotifier<PostModel?> newlyPublishedPost =
      ValueNotifier<PostModel?>(null);
  final PostApi? _postApiInstance;

  PostApiService._(this._postApiInstance);

  static void notifySocialFeedRefresh() {
    socialFeedRefreshToken.value = socialFeedRefreshToken.value + 1;
  }

  static Future<void> invalidateSocialFeedCache(
      {bool includeReels = false}) async {
    await SocialFeedCacheService.instance.clearPosts();
    if (includeReels) {
      await SocialFeedCacheService.instance.clearReels();
    }
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
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
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
    String? search,
  }) async {
    final res = await _postApiInstance!.getPosts(
      page: page,
      limit: limit,
      postType: postType?.name,
      hashtag: hashtag,
      search: search,
    );
    throwIfNotSuccess(res);
    final data = extractDataFromResponse(res);
    final docs = data['docs'] as List;
    return docs.map((e) => PostModel.fromMap(e)).toList();
  }

  Future<List<PostModel>> getAllPosts({
    int pageSize = 100,
    PostType? postType,
    String? hashtag,
    String? search,
  }) async {
    final safePageSize = pageSize < 1 ? 100 : pageSize;
    final all = <PostModel>[];
    var page = 1;

    while (true) {
      final posts = await getPosts(
        page: page,
        limit: safePageSize,
        postType: postType,
        hashtag: hashtag,
        search: search,
      );
      all.addAll(posts);

      if (posts.length < safePageSize) break;
      page++;
    }

    return all;
  }

  Future<List<PostModel>> getReels({int page = 1, int limit = 20}) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 20 : (limit > 30 ? 30 : limit);
    final headers = _authHeaders();

    String? cursor;
    Map<String, dynamic> payload = const {'data': [], 'nextCursor': null};

    for (int i = 1; i <= safePage; i++) {
      final query = <String, dynamic>{
        'limit': safeLimit.toString(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      };
      final uri = StoryApi.storyReelsServiceBaseUrl.replace(
        path: '${StoryApi.storyReelsServiceBaseUrl.path}/reels/feed',
        queryParameters: query,
      );
      final res = await http.get(uri, headers: headers);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw SuperHttpBadRequest(exception: 'Failed to load reels feed');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      payload = body;

      if (i < safePage) {
        cursor = (body['nextCursor'] as String?)?.trim();
        if (cursor == null || cursor.isEmpty) break;
      }
    }

    final rawList =
        (payload['data'] is List) ? payload['data'] as List : const [];
    final docs = rawList.map((reel) {
      final m = (reel as Map<String, dynamic>);
      final uploader = (m['uploaderData'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      return <String, dynamic>{
        '_id': m['_id'] ?? '',
        'userId': {
          '_id': uploader['_id'] ?? m['uploaderId'] ?? '',
          'fullName': uploader['fullName'] ?? '',
          'userImage': uploader['userImage'] ?? '',
          'username': uploader['username'] ?? '',
          'isFollowing': uploader['isFollowing'] == true,
        },
        'postType': 'reel',
        'caption': m['caption'] ?? '',
        'mentionedUsers': const <String>[],
        'hashtags': (m['hashtags'] as List?) ?? const <dynamic>[],
        'media': {
          'url': m['mediaUrl'] ?? '',
          'thumbnail': m['coverUrl'] ?? '',
          'mimeType': 'video/mp4',
        },
        'mediaUrls': m['mediaUrl'] == null
            ? const <String>[]
            : <String>[m['mediaUrl'].toString()],
        'location': null,
        'likesCount': m['likesCount'] ?? 0,
        'viewsCount': m['viewsCount'] ?? 0,
        'commentsCount': m['commentsCount'] ?? 0,
        'sharesCount': m['sharesCount'] ?? 0,
        'likedBy': m['hasLiked'] == true ? <String>['me'] : const <String>[],
        'currentUserId': 'me',
        'isReel': true,
        'createdAt': m['createdAt'] ?? '',
      };
    }).toList();

    return docs.map((e) => PostModel.fromMap(e)).toList();
  }

  /// Returns cached posts instantly (if available), then fetches fresh data
  /// from the API and updates the cache silently.
  /// The [onFreshData] callback is called when fresh API data arrives.
  Future<List<PostModel>> getCachedPosts({
    int page = 1,
    int limit = 20,
    PostType? postType,
    String? hashtag,
    ValueChanged<List<PostModel>>? onFreshData,
  }) async {
    final cache = SocialFeedCacheService.instance;
    final cached = cache.getPosts();

    // If we have cached data, return it immediately
    if (cached.isNotEmpty) {
      // Kick off background refresh (don't await)
      _refreshPostsCache(
          page: page,
          limit: limit,
          postType: postType,
          hashtag: hashtag,
          onFreshData: onFreshData);
      return cached;
    }

    // No cache — fetch from API directly
    final fresh = await getPosts(
        page: page, limit: limit, postType: postType, hashtag: hashtag);
    await cache.savePosts(fresh);
    return fresh;
  }

  Future<void> _refreshPostsCache({
    int page = 1,
    int limit = 20,
    PostType? postType,
    String? hashtag,
    ValueChanged<List<PostModel>>? onFreshData,
  }) async {
    try {
      final fresh = await getPosts(
          page: page, limit: limit, postType: postType, hashtag: hashtag);
      await SocialFeedCacheService.instance.savePosts(fresh);
      onFreshData?.call(fresh);
    } catch (e) {
      debugPrint('Background posts refresh failed: $e');
    }
  }

  Future<List<PostModel>> getCachedAllPosts({
    int pageSize = 100,
    PostType? postType,
    String? hashtag,
    bool forceRefresh = false,
    ValueChanged<List<PostModel>>? onFreshData,
  }) async {
    final cache = SocialFeedCacheService.instance;
    final cached = cache.getPosts();

    if (!forceRefresh && cached.isNotEmpty) {
      _refreshAllPostsCache(
        pageSize: pageSize,
        postType: postType,
        hashtag: hashtag,
        onFreshData: onFreshData,
      );
      return cached;
    }

    final fresh = await getAllPosts(
      pageSize: pageSize,
      postType: postType,
      hashtag: hashtag,
    );
    await cache.savePosts(fresh);
    return fresh;
  }

  Future<void> _refreshAllPostsCache({
    int pageSize = 100,
    PostType? postType,
    String? hashtag,
    ValueChanged<List<PostModel>>? onFreshData,
  }) async {
    try {
      final fresh = await getAllPosts(
        pageSize: pageSize,
        postType: postType,
        hashtag: hashtag,
      );
      await SocialFeedCacheService.instance.savePosts(fresh);
      onFreshData?.call(fresh);
    } catch (e) {
      debugPrint('Background all posts refresh failed: $e');
    }
  }

  /// Returns cached reels instantly (if available), then fetches fresh data
  /// from the API and updates the cache silently.
  Future<List<PostModel>> getCachedReels({
    int page = 1,
    int limit = 20,
    ValueChanged<List<PostModel>>? onFreshData,
  }) async {
    final cache = SocialFeedCacheService.instance;
    final cached = cache.getReels();

    if (cached.isNotEmpty && page == 1) {
      // Kick off background refresh (don't await)
      _refreshReelsCache(page: page, limit: limit, onFreshData: onFreshData);
      return cached;
    }

    // No cache or paginating — fetch from API directly
    final fresh = await getReels(page: page, limit: limit);
    if (page == 1) {
      await cache.saveReels(fresh);
    }
    return fresh;
  }

  Future<void> _refreshReelsCache({
    int page = 1,
    int limit = 20,
    ValueChanged<List<PostModel>>? onFreshData,
  }) async {
    try {
      final fresh = await getReels(page: page, limit: limit);
      await SocialFeedCacheService.instance.saveReels(fresh);
      onFreshData?.call(fresh);
    } catch (e) {
      debugPrint('Background reels refresh failed: $e');
    }
  }

  Future<List<PostModel>> searchPosts({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    return getPosts(page: page, limit: limit, search: query);
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
    final post = await _postFromCreateResponse(extractDataFromResponse(res));
    await _postMutationSucceeded(createdPost: post);
  }

  /// Upload 1-10 photos for an image post via raw multipart HTTP.
  Future<void> createMultiPhotoPost({
    required List<VPlatformFile> files,
    String? caption,
  }) async {
    debugPrint('createMultiPhotoPost: ${files.length} files');
    final data = await _multipartUpload(
      postType: 'image',
      caption: caption,
      files: files,
    );
    final post = await _postFromCreateResponse(data);
    await _postMutationSucceeded(createdPost: post);
  }

  /// Upload a single video post.
  Future<void> createVideoPost({
    required VPlatformFile file,
    String? caption,
  }) async {
    debugPrint('createVideoPost');
    final data = await _multipartUpload(
      postType: 'video',
      caption: caption,
      files: [file],
    );
    final post = await _postFromCreateResponse(data);
    await _postMutationSucceeded(createdPost: post);
  }

  /// Upload a single reel video post.
  Future<void> createReelPost({
    required VPlatformFile file,
    String? caption,
  }) async {
    debugPrint('createReelPost');
    final data = await _multipartUpload(
      postType: 'reel',
      caption: caption,
      files: [file],
      isReel: true,
    );
    final post = await _postFromCreateResponse(data);
    await _postMutationSucceeded(includeReels: true, createdPost: post);
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
    final post = await _postFromCreateResponse(extractDataFromResponse(res));
    await _postMutationSucceeded(createdPost: post);
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
    final data = await _multipartUpload(
      postType: postType.name,
      caption: caption,
      files: [file],
      isReel: isReel,
      locationJson: location != null ? jsonEncode(location) : null,
    );
    final post = await _postFromCreateResponse(data);
    await _postMutationSucceeded(
      includeReels: isReel || postType == PostType.reel,
      createdPost: post,
    );
  }

  Future<PostModel?> _postFromCreateResponse(dynamic data) async {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final id = (map['_id'] ?? map['id'] ?? '').toString();
    if (id.isEmpty) return null;
    try {
      return await getPostById(id);
    } catch (_) {
      return PostModel.fromMap(map);
    }
  }

  Future<void> _postMutationSucceeded({
    bool includeReels = false,
    PostModel? createdPost,
  }) async {
    await invalidateSocialFeedCache(includeReels: includeReels);
    if (createdPost != null) {
      newlyPublishedPost.value = createdPost;
    }
    notifySocialFeedRefresh();
    Future<void>.delayed(const Duration(milliseconds: 900), () async {
      await invalidateSocialFeedCache(includeReels: includeReels);
      notifySocialFeedRefresh();
    });
  }

  // ─── raw multipart upload ────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _multipartUpload({
    required String postType,
    String? caption,
    List<VPlatformFile> files = const [],
    bool isReel = false,
    String? locationJson,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: '${SConstants.sApiBaseUrl.path}/posts/upload',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authHeaders());

    request.fields['postType'] = postType;
    if (caption != null && caption.isNotEmpty) {
      request.fields['caption'] = caption;
    }
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
      final msg =
          (err?['data'] ?? err?['message'] ?? 'Upload failed').toString();
      if (body.statusCode == 401) {
        unAuthStream450Error.add(true);
      }
      throw SuperHttpBadRequest(exception: msg);
    }

    try {
      final decoded = jsonDecode(body.body);
      final data = decoded is Map ? decoded['data'] : null;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
  }
}
