// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:super_up/app/core/services/user_verification_service.dart';
import '../../../../../core/models/channel/channel_suggestion.dart';
import '../../../../../core/utils/enums.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/widgets/app_logo.dart';
import 'package:v_platform/v_platform.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../../core/models/story/story_model.dart';
import '../../../../story/view/story_view.dart';
import '../controllers/story_tab_controller.dart';
import 'package:s_translation/generated/l10n.dart';
import 'explore_channels_view.dart';

class StoryTabView extends StatefulWidget {
  const StoryTabView({super.key});

  @override
  State<StoryTabView> createState() => _StoryTabViewState();
}

class _StoryTabViewState extends State<StoryTabView> {
  late final StoryTabController controller;
  late final UserVerificationService _verificationService;

  @override
  void initState() {
    super.initState();
    controller = GetIt.I.get<StoryTabController>();
    _verificationService = GetIt.I.get<UserVerificationService>();
    controller.onInit();

    // Preload verification data for story users
    _preloadVerificationData();
  }

  Widget _buildChannelTile(BuildContext context, ChannelSuggestion item) {
    return GestureDetector(
      onTap: () => controller.openChannelIfJoined(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: item.image.isNotEmpty
                  ? NetworkImage(item.thumbImageS3)
                  : null,
              child: item.image.isEmpty
                  ? const Icon(CupertinoIcons.person_2_fill)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: context.cupertinoTextTheme.textStyle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.followers} ${S.of(context).followersLabel}',
                    style: context.cupertinoTextTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!item.isJoined)
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: const Color(0xFFB48648),
                onPressed: () => controller.joinAndOpenChannel(context, item),
                child: Text(
                  S.of(context).follow,
                  style: const TextStyle(color: Colors.white),
                ),
              )
          ],
        ),
      ),
    );
  }

  /// Preload verification data for users with stories
  void _preloadVerificationData() async {
    controller.addListener(() async {
      final allStories = controller.data.allStories;
      if (allStories.isNotEmpty) {
        final userIds =
            allStories.map((story) => story.userData.id).toSet().toList();

        if (userIds.isNotEmpty) {
          await _verificationService.preloadVerificationStatus(userIds);
          if (mounted) {
            setState(() {});
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false, // 👈 disables Hero animation
            largeTitle: Text(
              S.of(context).stories,
              style: context.cupertinoTextTheme.textStyle.copyWith(
                fontSize: 25,
                fontWeight: FontWeight.w600,
              ),
            ),
            middle: const AppLogo(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 6),
              ],
            ),
          )
        ],
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdsBannerWidget(
                adsId: VPlatforms.isAndroid
                    ? SConstants.androidBannerAdsUnitId
                    : SConstants.iosBannerAdsUnitId,
                isEnableAds: VAppConfigController.appConfig.enableAds,
              ),

              Expanded(
                child: StreamBuilder<SLoadingState<StoryTabState>>(
                  stream: controller.stream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CupertinoActivityIndicator());
                    }

                    final value = snapshot.data!;

                    return VAsyncWidgetsBuilder(
                      loadingState: value.loadingState,
                      onRefresh: controller.getStories,
                      successWidget: () {
                        final storyState = value.data;

                        return ListView(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                                 child: Text(
                                   'Recent Updates',
                                style: context.cupertinoTextTheme.textStyle
                                    .copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: CupertinoColors.black,
                                ),
                              ),
                            ),
                            _MainTrendingStoriesSection(
                              state: storyState,
                              onCreateStory: () {
                                controller.toCreateStory(context);
                              },
                              onStoryTap: (storyModel, allRelevantStories) {
                                if (storyModel.stories.isEmpty) return;
                                final isMe =
                                    storyModel.userData.id == AppAuth.myId;
                                final initialIndex =
                                    allRelevantStories.indexOf(storyModel);
                                context.toPage(
                                  StoryViewpage(
                                    userStoryModels: allRelevantStories,
                                    initialUserIndex:
                                        initialIndex != -1 ? initialIndex : 0,
                                    onComplete: (current) {},
                                    onDelete: isMe
                                        ? () async {
                                            controller.data.myStories =
                                                UserStoryModel(
                                              stories: [],
                                              userData:
                                                  AppAuth.myProfile.baseUser,
                                            );
                                            controller.update();
                                            await controller.getMyStoryFromApi();
                                          }
                                        : null,
                                    onStoryViewed:
                                        controller.markStoryAsViewed,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // Channels Section
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                S.of(context).channels,
                                style: context.cupertinoTextTheme.textStyle
                                    .copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.black,
                                ),
                              ),
                            ),
                            if (value.data.isChannelsLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: CupertinoActivityIndicator(),
                                ),
                              )
                            else if (value.data.channelSuggestions.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'No channels available right now',
                                        style: context
                                            .cupertinoTextTheme.textStyle
                                            .copyWith(
                                          color: CupertinoColors.systemGrey,
                                        ),
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      onPressed:
                                          controller.getChannelSuggestions,
                                      child: const Text('Refresh'),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              ...value.data.channelSuggestions
                                  .take(3)
                                  .map((ch) => _buildChannelTile(context, ch))
                                  .toList(),
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 8, bottom: 12),
                                child: CupertinoButton(
                                  color: const Color(0xFFB48648),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  onPressed: () =>
                                      context.toPage(const ExploreChannelsView()),
                                  child: Text(
                                    S.of(context).exploreMore,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _MainTrendingStoriesSection extends StatelessWidget {
  final StoryTabState state;
  final Function(UserStoryModel userStory, List<UserStoryModel> allRelevantStories) onStoryTap;
  final VoidCallback onCreateStory;

  const _MainTrendingStoriesSection({
    required this.state,
    required this.onStoryTap,
    required this.onCreateStory,
  });

  @override
  Widget build(BuildContext context) {
    final myStories = state.myStories;
    final allStories = state.allStories;
    final orderedStories = <UserStoryModel>[
      ...allStories.where(
        (userStory) =>
            userStory.stories.isEmpty ||
            userStory.stories.any((story) => !story.viewedByMe),
      ),
      ...allStories.where(
        (userStory) =>
            userStory.stories.isNotEmpty &&
            userStory.stories.every((story) => story.viewedByMe),
      ),
    ];
    final isMyLoading = state.isMyStoriesLoading;
    final allRelevantStories = <UserStoryModel>[
      if (myStories.stories.isNotEmpty) myStories,
      ...orderedStories,
    ];

    final storyItems = <Widget>[];

    storyItems.add(
      GestureDetector(
        onTap: onCreateStory,
        child: Container(
          width: 100,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFB48648),
                Color(0xFFD4A574),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.add,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add Story',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (myStories.stories.isNotEmpty) {
      storyItems.add(
        _MainStoryCard(
          userStory: myStories,
          isMe: true,
          isLoading: isMyLoading,
          onTap: () => onStoryTap(myStories, allRelevantStories),
        ),
      );
    } else if (isMyLoading) {
      storyItems.add(
        Container(
          width: 100,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 60,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (final userStory in orderedStories) {
      storyItems.add(
        _MainStoryCard(
          userStory: userStory,
          isMe: false,
          isLoading: false,
          onTap: () => onStoryTap(userStory, allRelevantStories),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: storyItems,
      ),
    );
  }
}

class _MainStoryCard extends StatefulWidget {
  final UserStoryModel userStory;
  final bool isMe;
  final bool isLoading;
  final VoidCallback onTap;

  const _MainStoryCard({
    required this.userStory,
    required this.isMe,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_MainStoryCard> createState() => _MainStoryCardState();
}

class _MainStoryCardState extends State<_MainStoryCard> {
  bool _isVideoPlaying = false;
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  Timer? _playTimer;
  String? _videoThumbnail;
  String? _resolvedPostShareThumb;
  bool _isResolvingPostShareThumb = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _resolvePostShareThumbnail();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  String? _generateVideoThumbnail(String videoUrl) {
    if (videoUrl.contains('cloudinary.com')) {
      return videoUrl.replaceAll(RegExp(r'\.(mov|mp4|avi|mkv|webm)$'), '.jpg');
    }
    return null;
  }

  String? _deriveCloudinaryVideoThumbnailUrl(String rawUrl) {
    try {
      if (rawUrl.isEmpty) return null;
      final fullUrl =
          rawUrl.startsWith('http') ? rawUrl : '${SConstants.baseMediaUrl}$rawUrl';
      final uri = Uri.parse(fullUrl);
      if (!uri.host.contains('res.cloudinary.com')) return null;
      final path = uri.path;
      final idx = path.indexOf('/upload/');
      if (idx == -1) return null;
      final prefix =
          '${uri.scheme}://${uri.host}${path.substring(0, idx + '/upload/'.length)}';
      final tail =
          path.substring(idx + '/upload/'.length).replaceFirst(RegExp(r'^/+'), '');
      final jpgTail = tail.replaceAll(RegExp(r'\.[^./]+$'), '.jpg');
      const transform = 'so_1,w_640,h_360,c_fill,f_jpg';
      return '$prefix$transform/$jpgTail';
    } catch (_) {
      return null;
    }
  }

  Future<void> _initVideo() async {
    final story = widget.userStory.stories.first;
    if (story.storyType != StoryType.video) return;

    final rawUrl = (story.att?['url'] ?? '').toString();
    if (rawUrl.isEmpty) return;

    final fullVideoUrl =
        rawUrl.startsWith('http') ? rawUrl : '${SConstants.baseMediaUrl}$rawUrl';
    _videoThumbnail = _generateVideoThumbnail(fullVideoUrl) ??
        _deriveCloudinaryVideoThumbnailUrl(fullVideoUrl);

    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(fullVideoUrl));
      await _videoController!.initialize();
      await _videoController!.setVolume(0);
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
    } catch (_) {
      // Keep image fallback if video initialization fails.
    }
  }

  Future<void> _resolvePostShareThumbnail() async {
    if (_isResolvingPostShareThumb) return;

    final story = widget.userStory.stories.first;
    final att = story.att ?? const <String, dynamic>{};
    final postId =
        (att['postId'] ?? att['post_id'] ?? att['postID'] ?? '').toString();
    if (postId.isEmpty) return;

    final existingThumb =
        (att['thumbnailUrl'] ?? att['thumbUrl'] ?? '').toString();
    if (existingThumb.isNotEmpty) return;

    _isResolvingPostShareThumb = true;
    try {
      if (!GetIt.I.isRegistered<PostApiService>()) return;

      final api = GetIt.I.get<PostApiService>();
      final post = await api.getPostById(postId);
      final isVideoPost =
          post.postType.name == 'video' || post.postType.name == 'reel';

      String rawThumb;
      if (isVideoPost) {
        rawThumb = (post.media?.thumbnail ?? '').toString();
        if (rawThumb.isEmpty) {
          rawThumb = _deriveCloudinaryVideoThumbnailUrl(
                (post.media?.url ?? '').toString(),
              ) ??
              '';
        }
      } else {
        rawThumb = post.mediaUrls.isNotEmpty
            ? post.mediaUrls.first
            : (post.media?.url ?? '').toString();
      }

      if (rawThumb.isNotEmpty && mounted) {
        final fullThumb = rawThumb.startsWith('http')
            ? rawThumb
            : '${SConstants.baseMediaUrl}$rawThumb';
        setState(() {
          _resolvedPostShareThumb = fullThumb;
        });
      }
    } catch (_) {
      // Keep placeholder if preview cannot be resolved.
    } finally {
      _isResolvingPostShareThumb = false;
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_videoController == null || !_isInitialized) return;

    final isVisible = info.visibleFraction > 0.5;

    if (isVisible && !_isVideoPlaying) {
      _playTimer?.cancel();
      _playTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted || _videoController == null) return;
        setState(() {
          _isVideoPlaying = true;
        });
        _videoController!.setVolume(0);
        _videoController!.play();
        _videoController!.setLooping(true);
      });
    } else if (!isVisible && _isVideoPlaying) {
      _playTimer?.cancel();
      setState(() {
        _isVideoPlaying = false;
      });
      _videoController!.pause();
      _videoController!.seekTo(Duration.zero);
    }
  }

  String _formatVoiceDuration(dynamic raw) {
    if (raw == null) return '';

    if (raw is String) {
      final v = raw.trim();
      if (v.isEmpty) return '';
      if (v.contains(':')) return v;
      final parsed = double.tryParse(v);
      if (parsed == null) return '';
      raw = parsed;
    }

    double seconds;
    if (raw is Duration) {
      seconds = raw.inSeconds.toDouble();
    } else if (raw is num) {
      seconds = raw.toDouble();
      if (seconds > 1000) {
        seconds = seconds / 1000.0;
      }
    } else {
      return '';
    }

    final total = seconds.round().clamp(0, 60 * 60);
    final mins = (total ~/ 60).toString().padLeft(2, '0');
    final secs = (total % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Container(
        width: 140,
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    if (widget.userStory.stories.isEmpty) {
      return const SizedBox.shrink();
    }

    final story = widget.userStory.stories.first;
    final att = story.att ?? const <String, dynamic>{};
    final isTextStory = story.storyType == StoryType.text;
    final isVideo = story.storyType == StoryType.video;
    final isVoice = story.storyType == StoryType.voice;
    final isPostShare =
      (att['postId'] ?? att['post_id'] ?? att['postID'] ?? '')
        .toString()
        .isNotEmpty;

    final postType = (att['postType'] ?? '').toString();
    final postCaption =
      (att['caption'] ?? story.caption ?? story.content).toString();
    final isPostVideo = postType == 'video' || postType == 'reel';
    final rawPostMedia = (att['mediaUrl'] ?? att['url'] ?? '').toString();
    final derivedVideoThumb = isPostVideo
      ? (_deriveCloudinaryVideoThumbnailUrl(rawPostMedia) ?? '')
      : '';
    final rawPostThumb = isPostVideo
      ? (att['thumbnailUrl'] ?? att['thumbUrl'] ?? derivedVideoThumb)
            .toString()
        : (att['thumbnailUrl'] ?? att['mediaUrl'] ?? att['thumbUrl'] ?? '')
            .toString();

    final postThumbUrl = _resolvedPostShareThumb ??
      (rawPostThumb.isEmpty
        ? null
        : (rawPostThumb.startsWith('http')
          ? rawPostThumb
          : '${SConstants.baseMediaUrl}$rawPostThumb'));

    final postPlaceName = (att['placeName'] ?? '').toString();
    final postAddress = (att['address'] ?? '').toString();
    final postLat = (att['latitude'] ?? '').toString();
    final postLong = (att['longitude'] ?? '').toString();
    final hasPostThumbnail = postThumbUrl != null && postThumbUrl.isNotEmpty;

    final thumbUrl = isVideo
        ? (_videoThumbnail ??
            (att['thumbUrl'] as String?) ??
            _deriveCloudinaryVideoThumbnailUrl((att['url'] ?? '').toString()))
        : (att['url'] as String?);

    final selectedThumbUrl = isPostShare ? postThumbUrl : thumbUrl;
    final hasSelectedThumb =
        selectedThumbUrl != null && selectedThumbUrl.isNotEmpty;
    final voiceDuration = _formatVoiceDuration(att['duration']);
    final voiceTitle = (story.caption ?? '').trim().isNotEmpty
        ? (story.caption ?? '').trim()
        : 'Voice Story';

    Widget cardContent = GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 140,
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isPostShare
              ? Colors.black
              : (isTextStory && story.backgroundColor != null
                  ? Color(story.colorValue ?? 0xFF222222)
                  : (isVideo ? Colors.black : Colors.grey[800])),
          image: (!isPostShare && !(_isVideoPlaying && isVideo)) &&
                  hasSelectedThumb
              ? DecorationImage(
                  image: NetworkImage(selectedThumbUrl),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Stack(
          children: [
            if (isPostShare)
              Positioned(
                left: 8,
                right: 8,
                top: 10,
                bottom: 44,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFB48648).withOpacity(0.65),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            postType == 'location'
                                ? CupertinoIcons.map_pin_ellipse
                                : CupertinoIcons.square_grid_2x2,
                            size: 11,
                            color: const Color(0xFFB48648),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              postType == 'reel'
                                  ? 'Shared Reel'
                                  : (postType == 'video'
                                      ? 'Shared Video'
                                      : (postType == 'location'
                                          ? 'Shared Location'
                                          : 'Shared Post')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFB48648),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: postType == 'location'
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFB48648).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(CupertinoIcons.map_pin,
                                        size: 14,
                                        color: Color(0xFFB48648)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        postPlaceName.isNotEmpty
                                            ? (postAddress.isNotEmpty
                                                ? '$postPlaceName, $postAddress'
                                                : postPlaceName)
                                            : (postAddress.isNotEmpty
                                                ? postAddress
                                                : ((postLat.isNotEmpty &&
                                                        postLong.isNotEmpty)
                                                    ? '$postLat, $postLong'
                                                    : 'Location')),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : hasPostThumbnail
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          postThumbUrl,
                                          fit: BoxFit.cover,
                                        ),
                                        if (isPostVideo)
                                          const Center(
                                            child: Icon(
                                              CupertinoIcons.play_circle_fill,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFB48648)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isPostVideo
                                            ? CupertinoIcons.play_rectangle
                                            : CupertinoIcons.doc_text,
                                        color: const Color(0xFFB48648),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                      ),
                      if (postCaption.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            postCaption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (isVideo && _isVideoPlaying && _isInitialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 140,
                  height: 200,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                ),
              ),
            if (isTextStory && !isPostShare)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    story.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            if (isVoice && !isPostShare)
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.mic_fill,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(8, (i) {
                          final heights = [7.0, 12.0, 9.0, 15.0, 8.0, 13.0, 10.0, 6.0];
                          return Container(
                            width: 3,
                            height: heights[i],
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB48648),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        voiceTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (voiceDuration.isNotEmpty)
                        Text(
                          voiceDuration,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (!isPostShare && (postType == 'video' || postType == 'reel') &&
                !(_isVideoPlaying && _isInitialized))
              const Center(
                child: Icon(
                  CupertinoIcons.play_circle_fill,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    VCircleAvatar(
                      radius: 14,
                      vFileSource: VPlatformFile.fromUrl(
                        networkUrl: widget.userStory.userData.userImage,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.isMe ? 'Your Story' : widget.userStory.userData.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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
      ),
    );

    if (isVideo) {
      return VisibilityDetector(
        key: Key('main_story_video_${widget.userStory.userData.id}_${story.id}'),
        onVisibilityChanged: _onVisibilityChanged,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
