import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';
import 'package:super_up/app/core/api_service/story/story_api_service.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up/app/core/models/story/create_story_dto.dart';
import 'package:super_up/app/core/services/story_status_service.dart';
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up/app/modules/home/mobile/story_tab/controllers/story_tab_controller.dart';
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up/app/modules/post/post_caption_text.dart';
import 'package:super_up/app/modules/post/post_comment_sheet.dart';
import 'package:super_up/app/modules/post/services/post_saved_posts_service.dart';
import 'package:super_up/app/widgets/custom_circle_avatar.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ReelsScreen extends StatefulWidget {
  final bool isActive;
  final int initialReelIndex;

  const ReelsScreen({super.key, this.isActive = true, this.initialReelIndex = 0});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  final _postApiService = GetIt.I.get<PostApiService>();
  late final PageController _pageController;

  final List<PostModel> _reels = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _limit = 10;

  final Map<int, VideoPlayerController> _videoControllers = {};
  final Map<int, bool> _videoInitialized = {};
  int _currentVisibleIndex = 0;
  double _playbackSpeed = 1.0;

  // Per-reel action state
  final Map<int, bool> _likedMap = {};
  final Map<int, int> _likeCountMap = {};
  final Map<int, int> _commentCountMap = {};
  final Map<int, int> _shareCountMap = {};
  final Set<int> _likingSet = {};
  final Set<int> _sharingSet = {};
  final Map<int, bool> _savedMap = {};
  final Set<int> _savingSet = {};
  final Map<int, bool> _followingMap = {};
  final Set<int> _followingSet = {};
  final Map<int, bool> _userPaused = {};

  final _savedPostsService = PostSavedPostsService.instance;

  @override
  void initState() {
    super.initState();
    _currentVisibleIndex = widget.initialReelIndex;
    _pageController = PageController(initialPage: widget.initialReelIndex);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncScreenAwakeState());
    _loadReels();
  }

  @override
  void didUpdateWidget(covariant ReelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;

    unawaited(_syncScreenAwakeState());

    if (widget.isActive) {
      _playCurrentVideoIfPossible();
    } else {
      _pauseAllVideos();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseAllVideos();
    } else if (state == AppLifecycleState.resumed && widget.isActive) {
      _playCurrentVideoIfPossible();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable());
    _pageController.dispose();
    _disposeAllVideos();
    super.dispose();
  }

  Future<void> _syncScreenAwakeState() async {
    if (widget.isActive) {
      await WakelockPlus.enable();
      return;
    }
    await WakelockPlus.disable();
  }

  void _disposeAllVideos() {
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    _videoInitialized.clear();
  }

  void _pauseAllVideos() {
    for (final controller in _videoControllers.values) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  void _playCurrentVideoIfPossible() {
    final controller = _videoControllers[_currentVisibleIndex];
    final isInitialized = _videoInitialized[_currentVisibleIndex] == true;
    if (controller != null && isInitialized) {
      controller.seekTo(Duration.zero);
      controller.play();
    }
  }

  /// Dispose video controllers that are far from the current index to save memory.
  /// Keep only current, previous, and next 2 videos alive.
  void _disposeDistantVideos(int currentIndex) {
    final keysToRemove = <int>[];
    for (final key in _videoControllers.keys) {
      if ((key - currentIndex).abs() > 2) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      _videoControllers[key]?.dispose();
      _videoControllers.remove(key);
      _videoInitialized.remove(key);
    }
  }

  /// Preload videos around the given index: current, next 2, and previous 1
  void _preloadAround(int index) {
    // Preload current
    _initializeVideoForIndex(index);
    // Preload next 2 videos for instant scroll
    if (index + 1 < _reels.length) _initializeVideoForIndex(index + 1);
    if (index + 2 < _reels.length) _initializeVideoForIndex(index + 2);
    // Keep previous 1 alive
    if (index - 1 >= 0) _initializeVideoForIndex(index - 1);
    // Free memory from distant videos
    _disposeDistantVideos(index);
  }

  Future<void> _loadReels() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final reels = await _postApiService.getReels(
        page: 1,
        limit: _limit,
      );
      final savedIds = await _savedPostsService.getSavedIds();
      if (mounted) {
        setState(() {
          _reels.clear();
          _reels.addAll(reels);
          _currentPage = 1;
          _hasMore = reels.length >= _limit;
          _isLoading = false;
          _likedMap.clear();
          _likeCountMap.clear();
          _commentCountMap.clear();
          _shareCountMap.clear();
          _savedMap.clear();
          _followingMap.clear();
          for (var i = 0; i < reels.length; i++) {
            _likedMap[i] = reels[i].isLiked;
            _likeCountMap[i] = reels[i].likesCount;
            _commentCountMap[i] = reels[i].commentsCount;
            _shareCountMap[i] = reels[i].sharesCount;
            _savedMap[i] = savedIds.contains(reels[i].id);
            _followingMap[i] = reels[i].author.isFollowing || _isOwner(reels[i]);
          }
        });
        if (reels.isNotEmpty) {
          // Preload current + next 2 videos for instant playback
          _preloadAround(_currentVisibleIndex);
        }
      }
    } catch (e) {
      debugPrint('Error loading reels: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reels: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final nextPage = _currentPage + 1;
      final reels = await _postApiService.getReels(
        page: nextPage,
        limit: _limit,
      );
      final savedIds = await _savedPostsService.getSavedIds();
      if (mounted) {
        final offset = _reels.length;
        setState(() {
          _reels.addAll(reels);
          _currentPage = nextPage;
          _hasMore = reels.length >= _limit;
          _isLoadingMore = false;
          for (var i = 0; i < reels.length; i++) {
            final idx = offset + i;
            _likedMap[idx] = reels[i].isLiked;
            _likeCountMap[idx] = reels[i].likesCount;
            _commentCountMap[idx] = reels[i].commentsCount;
            _shareCountMap[idx] = reels[i].sharesCount;
            _savedMap[idx] = savedIds.contains(reels[i].id);
            _followingMap[idx] = reels[i].author.isFollowing || _isOwner(reels[i]);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading more reels: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    _disposeAllVideos();
    _currentVisibleIndex = 0;
    _pageController.jumpToPage(0);
    await _loadReels();
  }

  bool _isOwner(PostModel reel) {
    final myId = AppAuth.myId;
    if (myId.isEmpty) return false;
    return reel.userId == myId || reel.author.id == myId;
  }

  void _openAuthorProfile(PostModel reel) {
    if (reel.userId.isEmpty) return;
    context.toPage(PeerProfileView(peerId: reel.userId));
  }

  Future<void> _toggleFollow(int index) async {
    if (_followingSet.contains(index) || index < 0 || index >= _reels.length) return;
    final reel = _reels[index];
    if (_isOwner(reel)) return;

    final profileApiService = GetIt.I.get<ProfileApiService>();
    final wasFollowing = _followingMap[index] ?? reel.author.isFollowing;

    setState(() {
      _followingSet.add(index);
      _followingMap[index] = !wasFollowing;
    });

    try {
      if (wasFollowing) {
        await profileApiService.unfollowUser(reel.userId);
      } else {
        await profileApiService.followUser(reel.userId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _followingMap[index] = wasFollowing);
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Failed to update follow status',
        );
      }
    } finally {
      if (mounted) setState(() => _followingSet.remove(index));
    }
  }

  Future<void> _toggleSave(int index) async {
    if (_savingSet.contains(index) || index < 0 || index >= _reels.length) {
      return;
    }
    final reel = _reels[index];
    final prev = _savedMap[index] ?? false;

    setState(() {
      _savingSet.add(index);
      _savedMap[index] = !prev;
    });

    try {
      final saved = await _savedPostsService.toggle(reel);
      if (!mounted) return;
      setState(() => _savedMap[index] = saved);
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: saved ? 'Post saved' : 'Post removed from saved',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savedMap[index] = prev);
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Failed to update saved post',
      );
    } finally {
      if (mounted) setState(() => _savingSet.remove(index));
    }
  }

  Future<void> _confirmAndDeleteReel(int index) async {
    if (index < 0 || index >= _reels.length) return;
    final reel = _reels[index];
    if (!_isOwner(reel)) return;

    final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Delete Reel'),
            content: const Text('Are you sure you want to delete this reel?'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    VAppAlert.showLoading(context: context);
    try {
      await _postApiService.deletePost(reel.id);
      if (mounted) Navigator.of(context).pop();
      await _refresh();
      if (!mounted) return;
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Reel deleted',
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Failed to delete reel',
      );
    }
  }

  /// Optimize a Cloudinary video URL for fast mobile streaming.
  /// Reduces resolution to 720p and applies auto quality compression.
  /// This can reduce a 50MB 4K video to ~2-5MB, enabling near-instant playback.
  String _optimizeVideoUrl(String url) {
    if (url.isEmpty) return url;
    // Only transform Cloudinary URLs
    if (!url.contains('res.cloudinary.com') || !url.contains('/upload/')) {
      return url;
    }
    // Don't double-transform if already optimized
    if (url.contains('q_auto') || url.contains('w_720') || url.contains('w_480')) {
      return url;
    }
    // Insert transformation: 720p width, auto quality, MP4 format
    // Cloudinary automatically moves moov atom to front for transformed videos
    return url.replaceFirst('/upload/', '/upload/w_720,q_auto/');
  }

  /// Get the best available video URL for a reel, with fallback to mediaUrls.
  String? _getReelVideoUrl(PostModel reel) {
    // Try media.url first
    final mediaUrl = reel.media?.url ?? '';
    if (mediaUrl.isNotEmpty) return mediaUrl;
    // Fallback to first mediaUrl
    if (reel.mediaUrls.isNotEmpty) return reel.mediaUrls.first;
    return null;
  }

  Future<void> _initializeVideoForIndex(int index) async {
    if (index < 0 || index >= _reels.length) return;
    final reel = _reels[index];
    if (_videoControllers.containsKey(index)) return;

    final rawUrl = _getReelVideoUrl(reel);
    if (rawUrl == null || rawUrl.isEmpty) return;

    try {
      final fullUrl = rawUrl.startsWith('http')
          ? rawUrl
          : '${SConstants.baseMediaUrl}$rawUrl';

      // Use Cloudinary-optimized URL for fast streaming
      final optimizedUrl = _optimizeVideoUrl(fullUrl);
      debugPrint('Reel[$index] loading: $optimizedUrl');

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(optimizedUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
      _videoControllers[index] = controller;

      // Initialize without blocking - fire and forget for preloading
      controller.initialize().then((_) {
        if (!mounted || !_videoControllers.containsKey(index)) return;
        controller.setLooping(true);
        controller.setPlaybackSpeed(_playbackSpeed);
        if (mounted) {
          setState(() {
            _videoInitialized[index] = true;
          });
          // Auto-play if this is the currently visible reel
          if (widget.isActive && index == _currentVisibleIndex) {
            controller.play();
          }
        }
      }).catchError((e) {
        debugPrint('Error initializing video at index $index: $e');
        // Clean up failed controller so it can be retried
        if (_videoControllers.containsKey(index)) {
          _videoControllers[index]?.dispose();
          _videoControllers.remove(index);
        }
        _videoInitialized.remove(index);
      });
    } catch (e) {
      debugPrint('Error creating video controller at index $index: $e');
    }
  }

  Future<void> _downloadReel(int index) async {
    if (index < 0 || index >= _reels.length) return;
    final raw = (_reels[index].media?.url ?? '').toString();
    if (raw.isEmpty) return;
    final fullUrl =
        raw.startsWith('http') ? raw : '${SConstants.baseMediaUrl}$raw';

    try {
      await VStringUtils.lunchLink(fullUrl);
      if (!mounted) return;
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Download started',
      );
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(
        context: context,
        message: e.toString(),
      );
    }
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    for (final controller in _videoControllers.values) {
      try {
        await controller.setPlaybackSpeed(speed);
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _showSpeedPicker() async {
    double? selected;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Playback Speed'),
        message: Text('Current: ${_playbackSpeed.toStringAsFixed(_playbackSpeed == _playbackSpeed.roundToDouble() ? 0 : 1)}x'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              selected = 0.5;
              Navigator.pop(ctx);
            },
            child: const Text('0.5x'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              selected = 1.0;
              Navigator.pop(ctx);
            },
            child: const Text('1x'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              selected = 1.5;
              Navigator.pop(ctx);
            },
            child: const Text('1.5x'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              selected = 2.0;
              Navigator.pop(ctx);
            },
            child: const Text('2x'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (selected != null) {
      await _setPlaybackSpeed(selected!);
    }
  }

  Future<void> _toggleLike(int index) async {
    if (_likingSet.contains(index)) return;
    final reel = _reels[index];
    setState(() => _likingSet.add(index));
    final wasLiked = _likedMap[index] ?? reel.isLiked;
    setState(() {
      _likedMap[index] = !wasLiked;
      _likeCountMap[index] = (_likeCountMap[index] ?? reel.likesCount) + (wasLiked ? -1 : 1);
    });
    try {
      await _postApiService.likePost(reel.id);
    } catch (e) {
      // Revert optimistic update
      if (mounted) {
        setState(() {
          _likedMap[index] = wasLiked;
          _likeCountMap[index] = (_likeCountMap[index] ?? reel.likesCount) + (wasLiked ? 1 : -1);
        });
      }
      debugPrint('Like error: $e');
    } finally {
      if (mounted) setState(() => _likingSet.remove(index));
    }
  }

  Future<void> _openComments(int index) async {
    final reel = _reels[index];
    await PostCommentSheet.show(
      context,
      postId: reel.id,
      postUserId: reel.userId,
      initialCount: _commentCountMap[index] ?? reel.commentsCount,
      onCountChanged: (count) {
        if (mounted) setState(() => _commentCountMap[index] = count);
      },
    );
  }

  Future<void> _shareReel(int index) async {
    if (_sharingSet.contains(index)) return;
    final reel = _reels[index];

    String? action;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(reel.caption.isNotEmpty
            ? reel.caption.length > 60
                ? '${reel.caption.substring(0, 60)}…'
                : reel.caption
            : 'Share Reel'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'story_main';
              Navigator.pop(ctx);
            },
            child: const Text('Share to Main Story'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'story_social';
              Navigator.pop(ctx);
            },
            child: const Text('Share to Social Story'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'chat';
              Navigator.pop(ctx);
            },
            child: const Text('Share to Chat'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'link';
              Navigator.pop(ctx);
            },
            child: const Text('Share Link'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (action == null) return;
    if (action == 'story_main') return _shareReelToStory(index, source: 'main');
    if (action == 'story_social') return _shareReelToStory(index, source: 'social');
    if (action == 'chat') return _shareReelToChat(index);
    if (action == 'link') return _shareReelLink(index);
  }

  Future<void> _shareReelLink(int index) async {
    if (_sharingSet.contains(index)) return;
    final reel = _reels[index];
    final link = '${SConstants.sApiBaseUrl.origin}/posts/${reel.id}';
    setState(() => _sharingSet.add(index));
    try {
      await Share.share(
        reel.caption.isNotEmpty
            ? '${reel.caption}\nby ${reel.author.fullName}\n$link'
            : 'by ${reel.author.fullName}\n$link',
        subject: reel.caption.isNotEmpty ? reel.caption : 'Reel',
      );
      final res = await _postApiService.sharePost(reel.id);
      final count = (res['sharesCount'] as num?)?.toInt();
      if (mounted && count != null) {
        setState(() => _shareCountMap[index] = count);
      }
    } catch (e) {
      debugPrint('Share error: $e');
    } finally {
      if (mounted) setState(() => _sharingSet.remove(index));
    }
  }

  Future<void> _shareReelToChat(int index) async {
    if (_sharingSet.contains(index)) return;
    final reel = _reels[index];
    try {
      final roomsIds =
          await VChatController.I.vNavigator.roomNavigator.toForwardPage(
        context,
        null,
      );
      if (roomsIds == null || roomsIds.isEmpty) return;

      // For video/reel ONLY use the explicit thumbnail — never fall back to video URL
      final rawMedia = reel.media?.url ?? '';

      String _deriveCloudinaryThumb(String url) {
        if (url.isEmpty || !url.startsWith('http')) return '';
        final uri = Uri.tryParse(url);
        if (uri == null || !uri.host.contains('res.cloudinary.com')) return '';
        final path = uri.path;
        const upload = '/upload/';
        final idx = path.indexOf(upload);
        if (idx == -1) return '';
        final prefix = '${uri.scheme}://${uri.host}${path.substring(0, idx + upload.length)}';
        final tail = path.substring(idx + upload.length).replaceFirst(RegExp(r'^/+'), '');
        final jpgTail = tail.replaceFirst(RegExp(r'\.[^./]+$'), '.jpg');
        return '${prefix}so_1,w_640,h_360,c_fill,f_jpg/$jpgTail';
      }

      String _full(String raw) =>
          raw.isEmpty ? raw : (raw.startsWith('http') ? raw : '${SConstants.baseMediaUrl}$raw');
      final mediaUrl = _full(rawMedia);
      final rawThumb = reel.media?.thumbnail ?? _deriveCloudinaryThumb(mediaUrl);
      final thumb = _full(rawThumb);
      final payload = <String, dynamic>{
        'type': 'post_share',
        'postId': reel.id,
        'caption': reel.caption,
        'authorName': reel.author.fullName,
        'authorImage': reel.author.userImage,
        'authorId': reel.userId,
        'mediaUrl': mediaUrl,
        'thumbnailUrl': thumb,
        'postType': 'reel',
      };
      final previewText = reel.caption.isNotEmpty
          ? reel.caption
          : 'Shared a reel by ${reel.author.fullName}';

      setState(() => _sharingSet.add(index));
      VAppAlert.showLoading(context: context);
      try {
        for (final roomId in roomsIds) {
          final message = VCustomMessage.buildMessage(
            roomId: roomId,
            content: previewText,
            data: VCustomMsgData(data: payload),
          );
          await VChatController.I.nativeApi.local.message
              .insertMessage(message);
          try {
            VMessageUploaderQueue.instance.addToQueue(
              await MessageFactory.createUploadMessage(message),
            );
          } catch (_) {}
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        final res = await _postApiService.sharePost(reel.id);
        final count = (res['sharesCount'] as num?)?.toInt();
        if (mounted && count != null) {
          setState(() => _shareCountMap[index] = count);
        }
        VAppAlert.showSuccessSnackBar(
            context: context, message: 'Shared to chat');
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    } finally {
      if (mounted) setState(() => _sharingSet.remove(index));
    }
  }

  StoryTabController _ensureStoryTabController() {
    if (!GetIt.I.isRegistered<StoryTabController>()) {
      GetIt.I.registerLazySingleton<StoryTabController>(
          () => StoryTabController());
      GetIt.I.get<StoryTabController>().onInit();
    }
    return GetIt.I.get<StoryTabController>();
  }

  Future<void> _shareReelToStory(int index, {required String source}) async {
    if (_sharingSet.contains(index)) return;
    final reel = _reels[index];

    String _deriveCloudinaryThumb(String url) {
      if (url.isEmpty || !url.startsWith('http')) return '';
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.host.contains('res.cloudinary.com')) return '';
      final path = uri.path;
      const upload = '/upload/';
      final idx = path.indexOf(upload);
      if (idx == -1) return '';
      final prefix = '${uri.scheme}://${uri.host}${path.substring(0, idx + upload.length)}';
      final tail = path.substring(idx + upload.length).replaceFirst(RegExp(r'^/+'), '');
      final jpgTail = tail.replaceFirst(RegExp(r'\.[^./]+$'), '.jpg');
      return '${prefix}so_1,w_640,h_360,c_fill,f_jpg/$jpgTail';
    }

    // Resolve full URLs for the story card attachment
    final rawMediaUrl = reel.media?.url ?? '';
    String _full(String raw) =>
        raw.isEmpty ? raw : (raw.startsWith('http') ? raw : '${SConstants.baseMediaUrl}$raw');
    final fullMediaUrl = _full(rawMediaUrl);
    final rawThumbUrl = reel.media?.thumbnail ?? _deriveCloudinaryThumb(fullMediaUrl);
    final fullThumbUrl = _full(rawThumbUrl);

    // Use text story with black background; post card overlay shows on top
    setState(() => _sharingSet.add(index));
    VAppAlert.showLoading(context: context);
    try {
      final caption = reel.caption.isNotEmpty
          ? reel.caption
          : 'Posted by ${reel.author.fullName}';

      final dto = CreateStoryDto(
        image: null,
        storyType: StoryType.text,
        content: caption,
        caption: caption,
        backgroundColor: 'FF000000',
        attachment: {
          'postId': reel.id,
          'postType': 'reel',
          'authorName': reel.author.fullName,
          'authorImage': reel.author.userImage,
          'authorId': reel.userId,
          'caption': reel.caption,
          'thumbnailUrl': fullThumbUrl,
          'mediaUrl': fullMediaUrl,
        },
        storyPrivacy: StoryPrivacy.public,
        storySource: source,
      );

      if (!GetIt.I.isRegistered<StoryApiService>()) {
        GetIt.I.registerSingleton<StoryApiService>(StoryApiService.init());
      }
      await GetIt.I.get<StoryApiService>().createStory(dto);

      try {
        final svc = GetIt.I.get<StoryStatusService>();
        final tab = _ensureStoryTabController();
        await svc.refreshMyStories();
        await tab.getMyStoryFromApi();
        await tab.getStoriesFromApi();
        tab.update();
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(milliseconds: 1000));
          await svc.refreshMyStories();
          await tab.getMyStoryFromApi();
          tab.update();
        }
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop();
      final res = await _postApiService.sharePost(reel.id);
      final count = (res['sharesCount'] as num?)?.toInt();
      if (mounted && count != null) setState(() => _shareCountMap[index] = count);
      VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Shared to your ${source == 'social' ? 'Social' : 'Main'} Story');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _sharingSet.remove(index));
    }
  }

  void _onPageChanged(int index) {
    final previousIndex = _currentVisibleIndex;
    _currentVisibleIndex = index;

    // Clear pause state for both pages (scroll transition, not user pause)
    _userPaused[previousIndex] = false;
    _userPaused[index] = false;

    // Pause previous video and reset to start
    final prevController = _videoControllers[previousIndex];
    if (prevController != null && prevController.value.isPlaying) {
      prevController.pause();
    }

    // Play current video instantly if already initialized
    final currentController = _videoControllers[index];
    if (_videoInitialized[index] == true && currentController != null) {
      if (widget.isActive) {
        currentController.seekTo(Duration.zero);
        currentController.play();
      }
    }

    // Preload adjacent videos and dispose far ones
    _preloadAround(index);

    // Load more data when approaching the end
    if (index >= _reels.length - 3 && _hasMore) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('reels_screen_visibility'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5 && widget.isActive) {
          _playCurrentVideoIfPossible();
        } else if (info.visibleFraction < 0.5) {
          _pauseAllVideos();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(
                      color: Colors.white,
                      radius: 14,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading reels...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : _reels.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _refresh,
                    color: const Color(0xFFB48648),
                    child: PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      onPageChanged: _onPageChanged,
                      itemCount: _reels.length,
                      itemBuilder: (context, index) {
                        return _buildReelItem(index);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildReelItem(int index) {
    final reel = _reels[index];
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildVideoPlayer(index, reel),
        _buildOverlay(index, reel),
      ],
    );
  }

  Widget _buildVideoPlayer(int index, PostModel reel) {
    final isInitialized = _videoInitialized[index] == true;
    final controller = _videoControllers[index];

    if (!isInitialized || controller == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          if (reel.media?.thumbnail != null)
            CachedNetworkImage(
              imageUrl: reel.media!.thumbnail!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.black,
                child: const Center(
                  child: CupertinoActivityIndicator(
                    color: Colors.white,
                    radius: 14,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.black,
                child: const Icon(
                  Icons.videocam_off,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          const Center(
            child: CupertinoActivityIndicator(
              color: Colors.white,
              radius: 14,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
          setState(() => _userPaused[index] = true);
        } else {
          controller.play();
          setState(() => _userPaused[index] = false);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          // Only show play button when user manually paused
          if (_userPaused[index] == true && !controller.value.isPlaying)
            Container(
              color: Colors.black26,
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white70,
                size: 64,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay(int index, PostModel reel) {
    return Stack(
      children: [
        _buildGradientOverlay(),
        if (_isOwner(reel))
          Positioned(
            top: 48,
            right: 12,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 28,
              onPressed: () => _confirmAndDeleteReel(index),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.ellipsis,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 80,
          child: _buildBottomInfo(index, reel),
        ),
        Positioned(
          right: 12,
          bottom: 80,
          child: _buildSideActions(index, reel),
        ),
      ],
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 250,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInfo(int index, PostModel reel) {
    final isFollowing = _followingMap[index] ?? reel.author.isFollowing;
    final isOwn = _isOwner(reel);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openAuthorProfile(reel),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      CustomCircleAvatar(
                        radius: 18,
                        imageUrl: reel.author.userImage,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reel.author.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isOwn)
                GestureDetector(
                  onTap: () => _toggleFollow(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isFollowing ? Colors.white24 : null,
                      border: Border.all(
                        color: isFollowing ? Colors.transparent : Colors.white,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: TextStyle(
                        color: isFollowing ? Colors.white70 : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (reel.caption.isNotEmpty)
            PostCaptionText(
              caption: reel.caption,
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.3,
              ),
              mentionColor: const Color(0xFF1DA1F2),
              hashtagColor: const Color(0xFF17BF63),
            ),
        ],
      ),
    );
  }

  Widget _buildSideActions(int index, PostModel reel) {
    final isLiked = _likedMap[index] ?? reel.isLiked;
    final isSaved = _savedMap[index] ?? false;
    final likesCount = _likeCountMap[index] ?? reel.likesCount;
    final commentsCount = _commentCountMap[index] ?? reel.commentsCount;
    final sharesCount = _shareCountMap[index] ?? reel.sharesCount;
    return Column(
      children: [
        _buildSideActionItem(
          icon: CupertinoIcons.arrow_down_to_line,
          label: 'Download',
          onTap: () => _downloadReel(index),
        ),
        const SizedBox(height: 20),
        _buildSideActionItem(
          icon: CupertinoIcons.speedometer,
          label: '${_playbackSpeed.toStringAsFixed(_playbackSpeed == _playbackSpeed.roundToDouble() ? 0 : 1)}x',
          onTap: _showSpeedPicker,
        ),
        const SizedBox(height: 20),
        _buildSideActionItem(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: _formatCount(likesCount),
          color: isLiked ? Colors.red : Colors.white,
          onTap: () => _toggleLike(index),
        ),
        const SizedBox(height: 20),
        _buildSideActionItem(
          icon: Icons.mode_comment,
          label: _formatCount(commentsCount),
          onTap: () => _openComments(index),
        ),
        const SizedBox(height: 20),
        _buildSideActionItem(
          icon: Icons.share,
          label: _formatCount(sharesCount),
          onTap: () => _shareReel(index),
        ),
        const SizedBox(height: 20),
        _buildSideActionItem(
          icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
          label: 'Save',
          onTap: () => _toggleSave(index),
        ),
      ],
    );
  }

  Widget _buildSideActionItem({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            color: color ?? Colors.white,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No reels yet',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new content',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
