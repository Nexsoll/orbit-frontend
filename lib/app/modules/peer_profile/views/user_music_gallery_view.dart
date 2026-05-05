// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up/app/modules/post/hashtag_posts_screen.dart';
import 'package:super_up/app/modules/post/post_feed_widget.dart';
import 'package:super_up/app/modules/music/services/music_api_service.dart';
import 'package:super_up/app/modules/music/views/music_audio_player_page.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

class UserMusicGalleryView extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userImage;

  const UserMusicGalleryView({
    super.key,
    required this.userId,
    required this.userName,
    this.userImage,
  });

  @override
  State<UserMusicGalleryView> createState() => _UserMusicGalleryViewState();
}

class _UserMusicGalleryViewState extends State<UserMusicGalleryView> {
  final List<Map<String, dynamic>> _items = [];
  final List<PostModel> _socialPosts = [];
  bool _loading = true;
  bool _isFetchingItems = false;
  bool _loadMoreQueued = false;
  bool _isSocialLoading = false;
  bool _socialLoaded = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _pageSize = 20;

  late final MusicApiService _api;
  late final PostApiService _postApi;

  @override
  void initState() {
    super.initState();
    _api = MusicApiService.init();
    _postApi = GetIt.I.get<PostApiService>();
    _fetchItems();
  }

  DateTime _postDate(PostModel post) {
    return DateTime.tryParse(post.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _fetchSocialPosts({bool reset = false}) async {
    if (reset) {
      _socialLoaded = false;
      _socialPosts.clear();
    }

    if (_socialLoaded && !reset) return;

    setState(() => _isSocialLoading = true);
    try {
      final collected = <PostModel>[];
      final seen = <String>{};
      const postPageLimit = 40;

      for (var page = 1; page <= 8; page++) {
        final posts = await _postApi.getPosts(page: page, limit: postPageLimit);
        if (posts.isEmpty) break;

        for (final post in posts) {
          if (post.userId == widget.userId && seen.add(post.id)) {
            collected.add(post);
          }
        }

        if (posts.length < postPageLimit) break;
      }

      collected.sort((a, b) => _postDate(b).compareTo(_postDate(a)));

      if (!mounted) return;
      setState(() {
        _socialPosts
          ..clear()
          ..addAll(collected);
        _socialLoaded = true;
      });
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Failed to load social posts: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  Future<void> _fetchItems({bool reset = false}) async {
    if (_isFetchingItems) return;

    if (reset) {
      _page = 1;
      _hasMore = true;
      _items.clear();
      _socialLoaded = false;
    }

    if (!_hasMore && !reset) return;

    _isFetchingItems = true;
    setState(() => _loading = true);

    try {
      final result = await _api.listMusic(
        uploaderId: widget.userId,
        page: _page,
        limit: _pageSize,
      );

      final docs = result['docs'] as List<Map<String, dynamic>>? ?? [];
      final total = result['total'] as int? ?? 0;

      // Normalize data fields like the main music screen
      for (final item in docs) {
        item['likesCount'] = (item['likesCount'] ?? 0) as int;
        item['commentsCount'] = (item['commentsCount'] ?? 0) as int;
        item['playsCount'] = (item['playsCount'] ?? 0) as int;
        item['isLiked'] = item['isLiked'] == true;
      }

      setState(() {
        _items.addAll(docs);
        _hasMore = _items.length < total;
        _page++;
      });

      await _fetchSocialPosts(reset: reset);
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Failed to load music: $e',
        );
      }
    } finally {
      _isFetchingItems = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scheduleLoadMore() {
    if (_loadMoreQueued || _isFetchingItems || !_hasMore || !mounted) {
      return;
    }
    _loadMoreQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreQueued = false;
      if (!mounted) return;
      _fetchItems();
    });
  }

  String _idOf(Map<String, dynamic> item) {
    return (item['_id'] ?? item['id'] ?? '').toString();
  }

  String _titleOf(Map<String, dynamic> item) {
    return (item['title'] ?? 'Untitled').toString();
  }

  String? _thumbOf(Map<String, dynamic> item) {
    final thumb = (item['thumbnailUrl'] ??
            item['thumbUrl'] ??
            item['thumb'] ??
            item['thumbImage']?['url'] ??
            '')
        .toString();
    if (thumb.isEmpty) return null;
    // Prefix with baseMediaUrl if not already a full URL
    if (thumb.startsWith('http')) return thumb;
    return SConstants.baseMediaUrl + thumb;
  }

  bool _isVideo(Map<String, dynamic> item) {
    final mediaType = (item['mediaType'] ?? '').toString().toLowerCase();
    final mimeType = (item['mimeType'] ?? '').toString().toLowerCase();
    return mediaType == 'video' ||
        mediaType == 'music_video' ||
        mimeType.startsWith('video/');
  }

  bool _isAudio(Map<String, dynamic> item) {
    final mediaType = (item['mediaType'] ?? '').toString().toLowerCase();
    final mimeType = (item['mimeType'] ?? '').toString().toLowerCase();
    return mediaType == 'audio' ||
        mediaType == 'music' ||
        mimeType.startsWith('audio/');
  }

  bool _isOwner(Map<String, dynamic> item) {
    final uploaderId = (item['uploaderId'] ??
            item['uploaderData']?['_id'] ??
            item['uploaderData']?['id'] ??
            '')
        .toString();
    return uploaderId == AppAuth.myId;
  }

  Future<void> _toggleLike(Map<String, dynamic> item) async {
    final id = _idOf(item);
    if (id.isEmpty) return;

    final currentIsLiked = item['isLiked'] == true;
    final currentLikes = item['likesCount'] as int? ?? 0;

    // Optimistic update
    setState(() {
      item['isLiked'] = !currentIsLiked;
      item['likesCount'] =
          currentIsLiked ? (currentLikes - 1).clamp(0, 999999) : currentLikes + 1;
    });

    try {
      final res = await _api.toggleLike(id);
      setState(() {
        item['isLiked'] = res['liked'] == true;
        item['likesCount'] = res['likesCount'] ?? item['likesCount'];
      });
    } catch (e) {
      // Revert on error
      setState(() {
        item['isLiked'] = currentIsLiked;
        item['likesCount'] = currentLikes;
      });
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Failed to like: $e',
        );
      }
    }
  }

  void _openComments(Map<String, dynamic> item) {
    final id = _idOf(item);
    if (id.isEmpty) return;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => _CommentsBottomSheet(
        item: item,
        api: _api,
        onUpdate: () => setState(() {}),
      ),
    );
  }

  Future<void> _support(Map<String, dynamic> item) async {
    final id = _idOf(item);
    if (id.isEmpty) return;

    final uploader = widget.userName;

    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Support${uploader.isNotEmpty ? ' $uploader' : ''}'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter amount to support this artist'),
              SizedBox(height: 16),
              CupertinoTextField(
                keyboardType: TextInputType.number,
                placeholder: 'Amount (KES)',
                prefix: Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('KES'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              VAppAlert.showSuccessSnackBar(
                context: context,
                message: 'Support feature coming soon!',
              );
            },
            child: const Text('Support'),
          ),
        ],
      ),
    );
  }

  void _showItemMenu(Map<String, dynamic> item) {
    final isVideo = _isVideo(item);
    final isAudio = _isAudio(item);
    final isOwner = _isOwner(item);
    final canSupport = !isOwner;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(_titleOf(item)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _openItem(item);
            },
            child: Text(isVideo ? 'Play Video' : (isAudio ? 'Play Audio' : 'Open')),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _openComments(item);
            },
            child: const Text('Comments'),
          ),
          if (canSupport)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _support(item);
              },
              child: const Text('Support'),
            ),
          if (isOwner)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _confirmDelete(item);
              },
              child: const Text('Delete'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final id = _idOf(item);
    if (id.isEmpty) return;

    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: 'Delete',
      content: 'Delete this item?',
    );
    if (res != 1) return;

    VAppAlert.showLoading(context: context);
    try {
      await _api.deleteMusic(id);
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _items.remove(item);
      });
      VAppAlert.showSuccessSnackBar(context: context, message: 'Deleted');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  void _openItem(Map<String, dynamic> item) {
    final mediaUrl = (item['mediaUrl'] ?? item['url'] ?? '').toString();
    final title = _titleOf(item);

    if (_isAudio(item) && mediaUrl.isNotEmpty) {
      context.toPage(
        MusicAudioPlayerPage(
          title: title,
          url: mediaUrl,
          autoPlay: true,
        ),
      );
    } else if (_isVideo(item) && mediaUrl.isNotEmpty) {
      // Navigate to video player
      context.toPage(
        VVideoPlayer(
          showDownload: true,
          platformFileSource: VPlatformFile.fromUrl(
            networkUrl: mediaUrl,
          ),
          downloadingLabel: 'Downloading...',
          successfullyDownloadedInLabel: 'Downloaded successfully',
        ),
      );
    }
  }

  Widget _buildGridItem(Map<String, dynamic> item) {
    final thumbUrl = _thumbOf(item);
    final isVideo = _isVideo(item);
    final isAudio = _isAudio(item);
    final isLiked = item['isLiked'] == true;
    final likesCount = item['likesCount'] as int? ?? 0;
    final commentsCount = item['commentsCount'] as int? ?? 0;
    final playsCount = item['playsCount'] as int? ?? 0;

    return GestureDetector(
      onTap: () => _openItem(item),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail or placeholder
            if (thumbUrl != null && thumbUrl.isNotEmpty)
              Image.network(
                thumbUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(isVideo, isAudio),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return _buildPlaceholder(isVideo, isAudio);
                },
              )
            else
              _buildPlaceholder(isVideo, isAudio),

            // Play icon overlay for videos
            if (isVideo)
              Container(
                color: Colors.black.withOpacity(0.2),
                child: const Icon(
                  CupertinoIcons.play_fill,
                  color: Colors.white,
                  size: 40,
                ),
              ),

            // Music note overlay for audio (subtle)
            if (isAudio && thumbUrl == null)
              Container(
                color: Colors.black.withOpacity(0.1),
                child: const Icon(
                  CupertinoIcons.music_note_2,
                  color: Color(0xFFB48648),
                  size: 40,
                ),
              ),

            // Type indicator badge
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVideo
                          ? CupertinoIcons.video_camera
                          : CupertinoIcons.music_note_2,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      isVideo ? 'VIDEO' : (isAudio ? 'AUDIO' : 'MEDIA'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Stats overlay at bottom with like/comment/play counts
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      _titleOf(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Stats row
                    Row(
                      children: [
                        // Likes
                        GestureDetector(
                          onTap: () => _toggleLike(item),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLiked
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.heart,
                                color: isLiked
                                    ? CupertinoColors.systemRed
                                    : Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$likesCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Comments
                        GestureDetector(
                          onTap: () => _openComments(item),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.chat_bubble,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$commentsCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Plays (only for non-articles)
                        if (playsCount > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.play_fill,
                                color: Colors.white70,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$playsCount',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        const Spacer(),
                        // More menu button
                        GestureDetector(
                          onTap: () => _showItemMenu(item),
                          child: const Icon(
                            CupertinoIcons.ellipsis,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isVideo, bool isAudio) {
    return Container(
      color: CupertinoColors.systemGrey5,
      child: Center(
        child: Icon(
          isVideo
              ? CupertinoIcons.video_camera
              : (isAudio
                  ? CupertinoIcons.music_note_2
                  : CupertinoIcons.music_mic),
          color: CupertinoColors.systemGrey3,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildSocialPostItem(PostModel post) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: PostFeedWidget(
        key: ValueKey('gallery_post_${post.id}'),
        post: post,
        onAuthorTap: () => context.toPage(PeerProfileView(peerId: post.userId)),
        onHashtagTap: (tag) => context.toPage(HashtagPostsScreen(hashtag: tag)),
        onMentionTap: (mention) {
          final peerId = mention.trim();
          if (peerId.isEmpty) return;
          context.toPage(PeerProfileView(peerId: peerId));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.userImage != null && widget.userImage!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: VCircleAvatar(
                  vFileSource: VPlatformFile.fromUrl(
                    networkUrl: widget.userImage!,
                  ),
                  radius: 14,
                ),
              ),
            Flexible(
              child: Text(
                widget.userName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Gallery',
              style: TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchItems(reset: true),
          child: _items.isEmpty && _socialPosts.isEmpty && !_loading && !_isSocialLoading
              ? _buildEmptyState()
              : CustomScrollView(
                  slivers: [
                    if (_items.isNotEmpty || _loading) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
                          child: Text(
                            'uploads',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.75,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index >= _items.length) {
                                if (_hasMore) {
                                  _scheduleLoadMore();
                                  return const Center(
                                    child: CupertinoActivityIndicator(),
                                  );
                                }
                                return const SizedBox.shrink();
                              }
                              return _buildGridItem(_items[index]);
                            },
                            childCount: _items.length + (_hasMore ? 1 : 0),
                          ),
                        ),
                      ),
                    ],
                    if (_socialPosts.isNotEmpty || _isSocialLoading) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: Text(
                            'Social Posts',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (_isSocialLoading && _socialPosts.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: CupertinoActivityIndicator(),
                            ),
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: _socialPosts.length,
                          itemBuilder: (context, index) =>
                              _buildSocialPostItem(_socialPosts[index]),
                        ),
                    ],
                    if (_loading && _items.isEmpty && _socialPosts.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.music_note_2,
            size: 60,
            color: CupertinoColors.systemGrey3,
          ),
          const SizedBox(height: 16),
          Text(
            'No uploads yet',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.systemGrey.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When ${widget.userName} uploads music or posts\nit will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }
}

// Comments Bottom Sheet Widget
class _CommentsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final MusicApiService api;
  final VoidCallback onUpdate;

  const _CommentsBottomSheet({
    required this.item,
    required this.api,
    required this.onUpdate,
  });

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  final TextEditingController _commentController = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    setState(() => _loading = true);
    try {
      final id = (widget.item['_id'] ?? widget.item['id'] ?? '').toString();
      final res = await widget.api.listComments(id);
      setState(() {
        _comments.clear();
        _comments.addAll(res['docs'] as List<Map<String, dynamic>>? ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _posting = true);
    try {
      final id = (widget.item['_id'] ?? widget.item['id'] ?? '').toString();
      final res = await widget.api.addComment(musicId: id, text: text);
      _commentController.clear();
      final newCount = res['commentsCount'] ?? (_comments.length + 1);
      widget.item['commentsCount'] = newCount;
      widget.onUpdate();
      await _fetchComments();
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Failed to post comment: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final id = (widget.item['_id'] ?? widget.item['id'] ?? '').toString();
      final res = await widget.api.deleteComment(musicId: id, commentId: commentId);
      final newCount = res['commentsCount'] ?? (_comments.length - 1).clamp(0, 999999);
      widget.item['commentsCount'] = newCount;
      widget.onUpdate();
      await _fetchComments();
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Failed to delete comment: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Comments (${widget.item['commentsCount'] ?? 0})'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _comments.isEmpty
                      ? const Center(
                          child: Text(
                            'No comments yet.\nBe the first to comment!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: CupertinoColors.systemGrey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final c = _comments[index];
                            final commentId = (c['_id'] ?? c['id'] ?? '').toString();
                            final userId = (c['userId'] ?? c['user']?['_id'] ?? '').toString();
                            final isMyComment = userId == AppAuth.myId;
                            final userName = (c['user']?['fullName'] ?? 'Unknown').toString();
                            final userImage = (c['user']?['userImage'] ?? '').toString();
                            final text = (c['text'] ?? c['content'] ?? '').toString();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  VCircleAvatar(
                                    vFileSource: VPlatformFile.fromUrl(
                                      networkUrl: userImage,
                                    ),
                                    radius: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          text,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isMyComment)
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      minSize: 32,
                                      onPressed: () => _deleteComment(commentId),
                                      child: const Icon(
                                        CupertinoIcons.trash,
                                        size: 18,
                                        color: CupertinoColors.destructiveRed,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: CupertinoColors.systemGrey4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _commentController,
                      placeholder: 'Add a comment...',
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _posting
                      ? const CupertinoActivityIndicator()
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _postComment,
                          child: const Icon(
                            CupertinoIcons.arrow_up_circle_fill,
                            size: 32,
                            color: CupertinoColors.activeBlue,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
