import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up_core/super_up_core.dart';

/// Caches the social feed (posts & reels) locally using SharedPreferences.
/// Implements a stale-while-revalidate pattern: cached data is shown instantly,
/// then fresh data is fetched from the API and the cache is updated silently.
class SocialFeedCacheService {
  SocialFeedCacheService._();
  static final SocialFeedCacheService instance = SocialFeedCacheService._();

  /// Incremented whenever cache is updated so listeners can rebuild.
  final ValueNotifier<int> postsChanged = ValueNotifier<int>(0);
  final ValueNotifier<int> reelsChanged = ValueNotifier<int>(0);

  static const _postsKey = 'cached_social_posts';
  static const _reelsKey = 'cached_social_reels';
  static const _postsTimestampKey = 'cached_social_posts_ts';
  static const _reelsTimestampKey = 'cached_social_reels_ts';

  /// Maximum cache age before considering it stale (5 minutes).
  static const _staleDuration = Duration(minutes: 5);

  String? _userId() {
    try {
      return AppAuth.myProfile.baseUser.id;
    } catch (_) {
      return null;
    }
  }

  // ─── Posts ──────────────────────────────────────────────────────────────────

  List<PostModel> getPosts() {
    final uid = _userId();
    if (uid == null) return [];
    final list = VAppPref.getList('${_postsKey}_$uid');
    if (list == null || list.isEmpty) return [];
    return _parsePostList(list);
  }

  Future<void> savePosts(List<PostModel> posts) async {
    final uid = _userId();
    if (uid == null || uid.isEmpty) return;
    final key = '${_postsKey}_$uid';
    final encoded = posts.map(_toStoreMap).map(jsonEncode).toList();
    await VAppPref.setList(key, encoded);
    await VAppPref.setInt(
        '${_postsTimestampKey}_$uid', DateTime.now().millisecondsSinceEpoch);
    postsChanged.value++;
  }

  bool arePostsStale() {
    final uid = _userId();
    if (uid == null) return true;
    final ts = VAppPref.getIntOrNull('${_postsTimestampKey}_$uid');
    if (ts == null) return true;
    return DateTime.now().millisecondsSinceEpoch - ts >
        _staleDuration.inMilliseconds;
  }

  Future<void> clearPosts() async {
    final uid = _userId();
    if (uid == null || uid.isEmpty) return;
    await VAppPref.removeKey('${_postsKey}_$uid');
    await VAppPref.removeKey('${_postsTimestampKey}_$uid');
    postsChanged.value++;
  }

  // ─── Reels ─────────────────────────────────────────────────────────────────

  List<PostModel> getReels() {
    final uid = _userId();
    if (uid == null) return [];
    final list = VAppPref.getList('${_reelsKey}_$uid');
    if (list == null || list.isEmpty) return [];
    return _parsePostList(list);
  }

  Future<void> saveReels(List<PostModel> reels) async {
    final uid = _userId();
    if (uid == null || uid.isEmpty) return;
    final key = '${_reelsKey}_$uid';
    final encoded = reels.map(_toStoreMap).map(jsonEncode).toList();
    await VAppPref.setList(key, encoded);
    await VAppPref.setInt(
        '${_reelsTimestampKey}_$uid', DateTime.now().millisecondsSinceEpoch);
    reelsChanged.value++;
  }

  bool areReelsStale() {
    final uid = _userId();
    if (uid == null) return true;
    final ts = VAppPref.getIntOrNull('${_reelsTimestampKey}_$uid');
    if (ts == null) return true;
    return DateTime.now().millisecondsSinceEpoch - ts >
        _staleDuration.inMilliseconds;
  }

  Future<void> clearReels() async {
    final uid = _userId();
    if (uid == null || uid.isEmpty) return;
    await VAppPref.removeKey('${_reelsKey}_$uid');
    await VAppPref.removeKey('${_reelsTimestampKey}_$uid');
    reelsChanged.value++;
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  List<PostModel> _parsePostList(List<String> list) {
    final out = <PostModel>[];
    for (final item in list) {
      try {
        final map = jsonDecode(item);
        if (map is Map) {
          out.add(PostModel.fromMap(Map<String, dynamic>.from(map)));
        }
      } catch (_) {}
    }
    return out;
  }

  Map<String, dynamic> _toStoreMap(PostModel post) {
    return {
      '_id': post.id,
      'userId': {
        '_id': post.author.id,
        'fullName': post.author.fullName,
        'userImage': post.author.userImage,
        'username': post.author.username,
        'isFollowing': post.author.isFollowing,
      },
      'postType': post.postType.name,
      'caption': post.caption,
      'mentionedUsers': post.mentionedUserIds,
      'hashtags': post.hashtags,
      'media': post.media?.toMap(),
      'mediaUrls': post.mediaUrls,
      'location': post.location?.toMap(),
      'likesCount': post.likesCount,
      'viewsCount': post.viewsCount,
      'commentsCount': post.commentsCount,
      'sharesCount': post.sharesCount,
      'likedBy': const <String>[],
      'isReel': post.isReel,
      'createdAt': post.createdAt,
    };
  }

  /// Clear all cached data (e.g. on logout).
  Future<void> clearAll() async {
    final uid = _userId();
    if (uid == null || uid.isEmpty) return;
    await VAppPref.removeKey('${_postsKey}_$uid');
    await VAppPref.removeKey('${_reelsKey}_$uid');
    await VAppPref.removeKey('${_postsTimestampKey}_$uid');
    await VAppPref.removeKey('${_reelsTimestampKey}_$uid');
    postsChanged.value++;
    reelsChanged.value++;
  }
}
