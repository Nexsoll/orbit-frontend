import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up_core/super_up_core.dart';

class PostSavedPostsService {
  PostSavedPostsService._();
  static final PostSavedPostsService instance = PostSavedPostsService._();

  /// Incremented whenever saved posts are mutated so views can refresh instantly.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  String _keyFor(String userId) => 'saved_posts_$userId';

  String? _myUserIdOrNull() {
    try {
      return AppAuth.myProfile.baseUser.id;
    } catch (_) {
      return null;
    }
  }

  void _emitChanged() {
    changes.value = changes.value + 1;
  }

  Future<List<PostModel>> getAll() async {
    final uid = _myUserIdOrNull();
    if (uid == null || uid.isEmpty) return const [];

    final list = VAppPref.getList(_keyFor(uid));
    if (list == null || list.isEmpty) return const [];

    final out = <PostModel>[];
    for (final item in list) {
      try {
        final map = jsonDecode(item.toString());
        if (map is Map) {
          out.add(PostModel.fromMap(Map<String, dynamic>.from(map)));
        }
      } catch (_) {}
    }
    return out;
  }

  Future<Set<String>> getSavedIds() async {
    final posts = await getAll();
    return posts.map((e) => e.id).where((e) => e.isNotEmpty).toSet();
  }

  Future<bool> isSaved(String postId) async {
    if (postId.trim().isEmpty) return false;
    final ids = await getSavedIds();
    return ids.contains(postId);
  }

  Map<String, dynamic> _toStoreMap(PostModel post) {
    return {
      '_id': post.id,
      'userId': {
        '_id': post.author.id,
        'fullName': post.author.fullName,
        'userImage': post.author.userImage,
        'username': post.author.username,
      },
      'postType': post.postType.name,
      'caption': post.caption,
      'mentionedUsers': post.mentionedUserIds,
      'hashtags': post.hashtags,
      'media': post.media?.toMap(),
      'mediaUrls': post.mediaUrls,
      'location': post.location?.toMap(),
      'likesCount': post.likesCount,
      'commentsCount': post.commentsCount,
      'sharesCount': post.sharesCount,
      'likedBy': const <String>[],
      'isReel': post.isReel,
      'createdAt': post.createdAt,
    };
  }

  Future<void> add(PostModel post) async {
    if (post.id.isEmpty) return;

    final uid = _myUserIdOrNull();
    if (uid == null || uid.isEmpty) return;
    final key = _keyFor(uid);

    final all = await getAll();
    if (all.any((e) => e.id == post.id)) return;

    final next = [...all.map(_toStoreMap), _toStoreMap(post)];
    await VAppPref.setList(key, next.map((e) => jsonEncode(e)).toList());
    _emitChanged();
  }

  Future<void> remove(String postId) async {
    if (postId.trim().isEmpty) return;

    final uid = _myUserIdOrNull();
    if (uid == null || uid.isEmpty) return;
    final key = _keyFor(uid);

    final all = await getAll();
    final next = all.where((e) => e.id != postId).map(_toStoreMap).toList();
    if (next.length == all.length) return;
    await VAppPref.setList(key, next.map((e) => jsonEncode(e)).toList());
    _emitChanged();
  }

  Future<bool> toggle(PostModel post) async {
    final saved = await isSaved(post.id);
    if (saved) {
      await remove(post.id);
      return false;
    }
    await add(post);
    return true;
  }
}
