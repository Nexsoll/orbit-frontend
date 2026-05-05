import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/api_service/story/story_api_service.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up/app/core/models/story/create_story_dto.dart';
import 'package:super_up/app/core/services/story_status_service.dart';
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up/app/modules/home/mobile/story_tab/controllers/story_tab_controller.dart';
import 'package:super_up/app/modules/social/controllers/social_story_tab_controller.dart';
import 'package:super_up/app/modules/post/post_caption_text.dart';
import 'package:super_up/app/modules/post/post_comment_sheet.dart';
import 'package:super_up/app/modules/post/services/post_saved_posts_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/widgets/custom_circle_avatar.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:video_player/video_player.dart';
import 'package:super_up/app/modules/post/post_photo_delete_screen.dart';


class PostFeedWidget extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onAuthorTap;
  final ValueChanged<String>? onHashtagTap;
  final ValueChanged<String>? onMentionTap;
  final ValueChanged<String>? onDeleted;
  final ValueChanged<bool>? onSaveChanged;

  const PostFeedWidget({
    super.key,
    required this.post,
    this.onAuthorTap,
    this.onHashtagTap,
    this.onMentionTap,
    this.onDeleted,
    this.onSaveChanged,
    this.onUpdated,
  });

  final ValueChanged<PostModel>? onUpdated;

  @override
  State<PostFeedWidget> createState() => _PostFeedWidgetState();
}

class _PostFeedWidgetState extends State<PostFeedWidget> {
  static const double _feedMediaAspectRatio = 4 / 3;

  late bool _isLiked;
  late int _likesCount;
  late int _commentsCount;
  late int _sharesCount;
  bool _isLiking = false;
  bool _isSharing = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isDeleted = false;
  bool _isSaved = false;
  bool _isSaving = false;

  final _postApiService = GetIt.I.get<PostApiService>();
  final _savedPostsService = PostSavedPostsService.instance;

  bool get _isOwner {
    final myId = AppAuth.myId;
    if (myId.isEmpty) return false;
    return widget.post.userId == myId || widget.post.author.id == myId;
  }

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _commentsCount = widget.post.commentsCount;
    _sharesCount = widget.post.sharesCount;
    _loadSavedState();
    if ((widget.post.postType == PostType.video ||
            widget.post.postType == PostType.reel) &&
        _primaryVideoUrl()?.isNotEmpty == true) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(covariant PostFeedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.mediaUrls.length != widget.post.mediaUrls.length) {
      _isLiked = widget.post.isLiked;
      _likesCount = widget.post.likesCount;
      _commentsCount = widget.post.commentsCount;
      _sharesCount = widget.post.sharesCount;
      _loadSavedState();
    }
  }

  String? _primaryVideoUrl() {
    final fromMedia = (widget.post.media?.url ?? '').trim();
    if (fromMedia.isNotEmpty) return fromMedia;

    if (widget.post.mediaUrls.isNotEmpty) {
      final first = widget.post.mediaUrls.first.trim();
      if (first.isNotEmpty) return first;
    }
    return null;
  }

  Future<void> _loadSavedState() async {
    final saved = await _savedPostsService.isSaved(widget.post.id);
    if (!mounted) return;
    setState(() => _isSaved = saved);
  }

  Future<void> _toggleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final saved = await _savedPostsService.toggle(widget.post);
      if (!mounted) return;
      setState(() => _isSaved = saved);
      widget.onSaveChanged?.call(saved);
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: saved ? 'Post saved' : 'Post removed from saved',
      );
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Failed to update saved post',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _initializeVideo() async {
    try {
      final rawUrl = _primaryVideoUrl();
      if (rawUrl == null || rawUrl.isEmpty) return;
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(_resolveMediaUrl(rawUrl)),
      );
      await _videoController?.initialize();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  String _resolveMediaUrl(String raw) {
    if (raw.isEmpty) return raw;
    return raw.startsWith('http') ? raw : '${SConstants.baseMediaUrl}$raw';
  }

  Future<void> _openFullscreenImages(
    List<String> urls, {
    int initialIndex = 0,
  }) async {
    final normalized = urls
        .map(_resolveMediaUrl)
        .where((e) => e.isNotEmpty)
        .toList();
    if (normalized.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageGallery(
          urls: normalized,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _openFullscreenVideo(String rawUrl) async {
    final url = _resolveMediaUrl(rawUrl);
    if (url.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenVideoPage(url: url),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() {
      _isLiking = true;
    });
    try {
      await _postApiService.likePost(widget.post.id);
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    } catch (e) {
      debugPrint('Error liking post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to like post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }
  }

  Future<void> _openComments() async {
    await PostCommentSheet.show(
      context,
      postId: widget.post.id,
      postUserId: widget.post.userId,
      initialCount: _commentsCount,
      onCountChanged: (count) {
        if (mounted) setState(() => _commentsCount = count);
      },
    );
  }

  Future<void> _sharePost() async {
    if (_isSharing) return;

    String? action;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          widget.post.caption.isNotEmpty
              ? widget.post.caption.length > 60
                  ? '${widget.post.caption.substring(0, 60)}…'
                  : widget.post.caption
              : 'Share Post',
        ),
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
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (action == null) return;
    if (action == 'story_main') return _shareToStory(source: 'main');
    if (action == 'story_social') return _shareToStory(source: 'social');
    if (action == 'chat') return _shareToChat();
  }

  Future<void> _confirmAndDeletePost() async {
    final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Delete Post'),
            content: const Text('Are you sure you want to delete this post?'),
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
      await _postApiService.deletePost(widget.post.id);

      // Refresh story lists so post_share stories removed by backend cascade disappear immediately.
      try {
        if (GetIt.I.isRegistered<StoryTabController>()) {
          final mainStory = GetIt.I.get<StoryTabController>();
          await mainStory.getMyStoryFromApi();
          await mainStory.getStoriesFromApi();
          mainStory.update();
        }
        if (GetIt.I.isRegistered<SocialStoryTabController>()) {
          final socialStory = GetIt.I.get<SocialStoryTabController>();
          await socialStory.getMyStoryFromApi();
          await socialStory.getStoriesFromApi();
          socialStory.update();
        }
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _isDeleted = true);
      widget.onDeleted?.call(widget.post.id);
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Post deleted',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      VAppAlert.showErrorSnackBar(
        context: context,
        message: e.toString(),
      );
    }
  }

  Future<void> _deleteSelectedPhotos() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostPhotoDeleteScreen(post: widget.post),
      ),
    );

    if (result == 'deleted') {
      setState(() => _isDeleted = true);
      widget.onDeleted?.call(widget.post.id);
    } else if (result is PostModel) {
      widget.onUpdated?.call(result);
    }
  }

  Future<void> _shareToChat() async {
    if (_isSharing) return;
    try {
      final roomsIds =
          await VChatController.I.vNavigator.roomNavigator.toForwardPage(
        context,
        null,
      );
      if (roomsIds == null || roomsIds.isEmpty) return;

      final post = widget.post;
      final isVideoPost = post.postType == PostType.video ||
          post.postType == PostType.reel;
      final rawMedia = post.mediaUrls.isNotEmpty
          ? post.mediaUrls.first
          : (post.media?.url ?? '');

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
        // Use explicit thumbnail first, then derive from Cloudinary video URL when missing.
        final rawThumb = isVideoPost
          ? (post.media?.thumbnail ?? _deriveCloudinaryThumb(mediaUrl))
          : (post.media?.thumbnail ?? rawMedia);
      final thumb = _full(rawThumb);

      final payload = <String, dynamic>{
        'type': 'post_share',
        'postId': post.id,
        'caption': post.caption,
        'authorName': post.author.fullName,
        'authorImage': post.author.userImage,
        'authorId': post.userId,
        'mediaUrl': mediaUrl,
        'thumbnailUrl': thumb,
        'postType': post.postType.name,
        if (post.postType == PostType.location) ...{
          'placeName': post.location?.placeName ?? '',
          'address': post.location?.address ?? '',
          'latitude': post.location?.latitude?.toString() ?? '',
          'longitude': post.location?.longitude?.toString() ?? '',
        },
      };

      final previewText = post.caption.isNotEmpty
          ? post.caption
          : 'Shared a post by ${post.author.fullName}';

      setState(() => _isSharing = true);
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
        final res = await _postApiService.sharePost(post.id);
        final count = (res['sharesCount'] as num?)?.toInt();
        if (mounted && count != null) setState(() => _sharesCount = count);
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
      if (mounted) setState(() => _isSharing = false);
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

  Future<void> _shareToStory({required String source}) async {
    if (_isSharing) return;
    final post = widget.post;

    // Determine what media to use
    final isVideoPost = post.postType == PostType.video ||
        post.postType == PostType.reel;

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

    // Resolve the display URLs for use in the story card overlay
    final rawMediaUrl = post.mediaUrls.isNotEmpty
        ? post.mediaUrls.first
        : (post.media?.url ?? '');
    String _full(String raw) =>
        raw.isEmpty ? raw : (raw.startsWith('http') ? raw : '${SConstants.baseMediaUrl}$raw');
    final fullMediaUrl = _full(rawMediaUrl);
    final rawThumbUrl = isVideoPost
      ? (post.media?.thumbnail ?? _deriveCloudinaryThumb(fullMediaUrl))
      : (post.mediaUrls.isNotEmpty
        ? post.mediaUrls.first
        : (post.media?.url ?? ''));
    final fullThumbUrl = _full(rawThumbUrl);

    // Always use a text story with black background; the post card overlay shows on top
    VAppAlert.showLoading(context: context);
    setState(() => _isSharing = true);
    try {
      final caption = post.caption.isNotEmpty
          ? post.caption
          : 'Posted by ${post.author.fullName}';

      final dto = CreateStoryDto(
        image: null,
        storyType: StoryType.text,
        content: caption,
        caption: caption,
        backgroundColor: 'FF000000',
        attachment: {
          'postId': post.id,
          'postType': post.postType.name,
          'authorName': post.author.fullName,
          'authorImage': post.author.userImage,
          'authorId': post.userId,
          'caption': post.caption,
          'thumbnailUrl': fullThumbUrl,
          'mediaUrl': fullMediaUrl,
          if (post.postType == PostType.location) ...{
            'placeName': post.location?.placeName ?? '',
            'address': post.location?.address ?? '',
            'latitude': post.location?.latitude?.toString() ?? '',
            'longitude': post.location?.longitude?.toString() ?? '',
          },
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

        // Keep social stories in sync when sharing to social story source.
        if (source == 'social' &&
            GetIt.I.isRegistered<SocialStoryTabController>()) {
          final socialTab = GetIt.I.get<SocialStoryTabController>();
          await socialTab.getMyStoryFromApi();
          await socialTab.getStoriesFromApi();
          socialTab.update();
        }

        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(milliseconds: 1000));
          await svc.refreshMyStories();
          await tab.getMyStoryFromApi();
          tab.update();
        }
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop();
      final res = await _postApiService.sharePost(post.id);
      final count = (res['sharesCount'] as num?)?.toInt();
      if (mounted && count != null) setState(() => _sharesCount = count);
      VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Shared to your ${source == 'social' ? 'Social' : 'Main'} Story');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeleted) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (widget.post.caption.isNotEmpty) _buildCaption(),
          _buildMediaContent(),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onAuthorTap,
            child: CustomCircleAvatar(
              radius: 20,
              imageUrl: widget.post.author.userImage,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: widget.onAuthorTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.author.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatTimestamp(widget.post.createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmAndDeletePost();
                } else if (value == 'delete_photos') {
                  _deleteSelectedPhotos();
                }
              },
              itemBuilder: (context) => [
                if (widget.post.mediaUrls.length > 1)
                  const PopupMenuItem<String>(
                    value: 'delete_photos',
                    child: Row(
                      children: [
                        Icon(Icons.photo_library_outlined, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text('Delete Selected Photos'),
                      ],
                    ),
                  ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Delete Post', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCaption() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: PostCaptionText(
        caption: widget.post.caption,
        onMentionTap: widget.onMentionTap,
        onHashtagTap: widget.onHashtagTap,
      ),
    );
  }

  Widget _buildMediaContent() {
    switch (widget.post.postType) {
      case PostType.image:
        return _buildImageContent();
      case PostType.video:
        return _buildVideoContent();
      case PostType.location:
        return _buildLocationContent();
      case PostType.reel:
        return _buildVideoContent();
      case PostType.text:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImageContent() {
    // Prefer mediaUrls array (multi-photo), fallback to single media.url
    final List<String> urls = widget.post.mediaUrls.isNotEmpty
        ? List<String>.from(widget.post.mediaUrls)
        : (widget.post.media?.url != null ? [widget.post.media!.url!] : []);
    final resolvedUrls = urls.map(_resolveMediaUrl).toList();

    if (resolvedUrls.isEmpty) return const SizedBox.shrink();

    if (resolvedUrls.length == 1) {
      return GestureDetector(
        onTap: () => _openFullscreenImages(resolvedUrls),
        child: AspectRatio(
          aspectRatio: _feedMediaAspectRatio,
          child: CachedNetworkImage(
            imageUrl: resolvedUrls.first,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey.shade200,
              child: const Center(child: CupertinoActivityIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.error_outline, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // Multi-photo: horizontal PageView with dot indicator
    return _MultiPhotoViewer(
      urls: resolvedUrls,
      onTapIndex: (index) => _openFullscreenImages(resolvedUrls, initialIndex: index),
    );
  }

  Widget _buildVideoContent() {
    final rawVideoUrl = _primaryVideoUrl();
    if (rawVideoUrl == null || rawVideoUrl.isEmpty) {
      return _buildImageContent();
    }

    final rawThumb = (widget.post.media?.thumbnail ?? '').trim();
    final thumbUrl = rawThumb.isEmpty ? '' : _resolveMediaUrl(rawThumb);

    return GestureDetector(
      onTap: () => _openFullscreenVideo(rawVideoUrl),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _feedMediaAspectRatio,
            child: _isVideoInitialized
                ? VideoPlayer(_videoController!)
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black),
                      if (thumbUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: thumbUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.black,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.black,
                          ),
                        ),
                      const Center(
                        child: CupertinoActivityIndicator(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(16),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationContent() {
    final location = widget.post.location;
    if (location == null ||
        location.latitude == null ||
        location.longitude == null) {
      return const SizedBox.shrink();
    }

    final latLng = LatLng(location.latitude!, location.longitude!);

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AbsorbPointer(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: latLng,
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: MarkerId('post_${widget.post.id}_location'),
                    position: latLng,
                  ),
                },
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                liteModeEnabled: true,
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFFB48648),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location.placeName ?? location.address ?? 'Location',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildActionButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: _formatCount(_likesCount),
            color: _isLiked ? Colors.red : null,
            onTap: _toggleLike,
            isLoading: _isLiking,
          ),
          const SizedBox(width: 24),
          _buildActionButton(
            icon: Icons.mode_comment_outlined,
            label: _formatCount(_commentsCount),
            onTap: _openComments,
          ),
          const SizedBox(width: 24),
          _buildActionButton(
            icon: Icons.share_outlined,
            label: _formatCount(_sharesCount),
            onTap: _sharePost,
            isLoading: _isSharing,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _isSaving ? null : _toggleSave,
            iconSize: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CupertinoActivityIndicator(radius: 8),
            )
          else
            Icon(
              icon,
              size: 22,
              color: color,
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d, yyyy').format(date);
      }
    } catch (e) {
      return '';
    }
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

// ─── Multi-photo page viewer ──────────────────────────────────────────────────

class _MultiPhotoViewer extends StatefulWidget {
  final List<String> urls;
  final ValueChanged<int>? onTapIndex;

  const _MultiPhotoViewer({required this.urls, this.onTapIndex});

  @override
  State<_MultiPhotoViewer> createState() => _MultiPhotoViewerState();
}

class _MultiPhotoViewerState extends State<_MultiPhotoViewer> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: PageView.builder(
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => widget.onTapIndex?.call(i),
              child: CachedNetworkImage(
                imageUrl: widget.urls[i],
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: CupertinoActivityIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
        if (widget.urls.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.urls.length, (i) => Container(
                width: _current == i ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _current == i
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
          ),
        // Photo count badge top-right
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_current + 1}/${widget.urls.length}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullScreenImageGallery extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _FullScreenImageGallery({
    required this.urls,
    this.initialIndex = 0,
  });

  @override
  State<_FullScreenImageGallery> createState() => _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<_FullScreenImageGallery> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pageController = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: widget.urls[i],
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CupertinoActivityIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 42,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                top: 14,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_current + 1}/${widget.urls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenVideoPage extends StatefulWidget {
  final String url;

  const _FullScreenVideoPage({required this.url});

  @override
  State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _initialized = true;
        _isPlaying = true;
      });
    } catch (_) {}
  }

  void _toggle() {
    final c = _controller;
    if (c == null || !_initialized) return;
    if (_isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: !_initialized || _controller == null
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : GestureDetector(
                      onTap: _toggle,
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio == 0
                            ? 16 / 9
                            : _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
            ),
            if (_initialized && _controller != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFFB48648),
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            if (_initialized && !_isPlaying)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 72,
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
