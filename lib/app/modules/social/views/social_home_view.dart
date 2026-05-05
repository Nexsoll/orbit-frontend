import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, CircleAvatar;
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up/app/core/models/story/story_model.dart';
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up/app/modules/post/hashtag_posts_screen.dart';
import 'package:super_up/app/modules/post/post_feed_widget.dart';
import 'package:super_up/app/modules/social/controllers/social_story_tab_controller.dart';
import 'package:super_up/app/modules/story/view/story_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class SocialHomeView extends StatefulWidget {
  const SocialHomeView({super.key});

  @override
  State<SocialHomeView> createState() => _SocialHomeViewState();
}

class _SocialHomeViewState extends State<SocialHomeView> {
  final _profileApiService = GetIt.I.get<ProfileApiService>();
  late final SocialStoryTabController _storyController;
  List<SSearchUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('SocialHomeView initState');
    try {
      if (!GetIt.I.isRegistered<SocialStoryTabController>()) {
        debugPrint('Registering SocialStoryTabController');
        GetIt.I.registerLazySingleton<SocialStoryTabController>(
          () => SocialStoryTabController(),
        );
      }
      _storyController = GetIt.I.get<SocialStoryTabController>();
      debugPrint('Calling _storyController.onInit()');
      _storyController.onInit();
      debugPrint('Calling _loadUsers()');
      _loadUsers();
    } catch (e, stack) {
      debugPrint('SocialHomeView initState error: $e');
      debugPrint('Stack: $stack');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final rnd = Random(DateTime.now().microsecondsSinceEpoch);
      final randomPage = rnd.nextInt(10) + 1;
      final dto = UserFilterDto.init().copyWith(limit: 30, page: randomPage);
      var users = await _profileApiService.appUsers(dto);

      if (users.isEmpty) {
        users = await _profileApiService
            .appUsers(UserFilterDto.init().copyWith(limit: 30, page: 1));
      }

      users = users.where((u) => u.baseUser.id != AppAuth.myId).toList();
      users.shuffle(rnd);

      setState(() {
        _users = users.take(12).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openChatWith(String peerId) async {
    try {
      await VChatController.I.roomApi.openChatWith(peerId: peerId);
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  void _onStoryTap(UserStoryModel userStory, List<UserStoryModel> allRelevantStories) {
    if (userStory.stories.isEmpty) return;
    final initialIndex = allRelevantStories.indexOf(userStory);
    context.toPage(StoryViewpage(
      userStoryModels: allRelevantStories,
      initialUserIndex: initialIndex != -1 ? initialIndex : 0,
      onComplete: (current) {},
      onDelete: () async {
        _storyController.data.myStories =
            UserStoryModel(stories: [], userData: AppAuth.myProfile.baseUser);
        _storyController.update();
        await _storyController.getMyStoryFromApi();
      },
      onStoryViewed: _storyController.markStoryAsViewed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            largeTitle: const Text('Discover'),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(title: 'Trending Stories'),
                _TrendingStoriesSection(
                  storyController: _storyController,
                  onStoryTap: _onStoryTap,
                  onCreateStory: () => _storyController.toCreateStory(context),
                ),
                const SizedBox(height: 20),
                const _SectionHeader(title: 'Suggested Friends'),
                if (_isLoading)
                  const _SuggestedFriendsSkeleton()
                else
                  _SuggestedFriendsSection(
                    users: _users,
                    onChatTap: _openChatWith,
                  ),
                const SizedBox(height: 20),
                const _SectionHeader(title: 'Recommended Posts'),
                const _PublicSnapFeedSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TrendingStoriesSection extends StatelessWidget {
  final SocialStoryTabController storyController;
  final Function(UserStoryModel userStory, List<UserStoryModel> allStories)
      onStoryTap;
  final VoidCallback onCreateStory;

  const _TrendingStoriesSection({
    required this.storyController,
    required this.onStoryTap,
    required this.onCreateStory,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SLoadingState<SocialStoryTabState>>(
      stream: storyController.stream,
      initialData: storyController.value,
      builder: (context, snapshot) {
        final state = snapshot.data?.data;
        final myStories = state?.myStories;
        final allStories = state?.allStories ?? [];
        final unwatchedStories = <UserStoryModel>[];
        final watchedStories = <UserStoryModel>[];
        for (final userStory in allStories) {
          final isWatched =
              userStory.stories.isNotEmpty && userStory.stories.every((s) => s.viewedByMe);
          if (isWatched) {
            watchedStories.add(userStory);
          } else {
            unwatchedStories.add(userStory);
          }
        }
        final orderedStories = <UserStoryModel>[
          ...unwatchedStories,
          ...watchedStories,
        ];
        final allRelevantStories = <UserStoryModel>[
          if (myStories != null && myStories.stories.isNotEmpty) myStories,
          ...orderedStories,
        ];

        final isMyLoading = state?.isMyStoriesLoading ?? false;

        final storyItems = <Widget>[];

        // 1st card: Create story button
        storyItems.add(
          GestureDetector(
            onTap: onCreateStory,
            child: Container(
              width: 100,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFB48648),
                    const Color(0xFFD4A574),
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

        // 2nd card: My stories
        if (myStories != null && myStories.stories.isNotEmpty) {
          storyItems.add(
            _SocialStoryCard(
              userStory: myStories,
              isMe: true,
              isLoading: isMyLoading,
              onTap: () => onStoryTap(myStories, allRelevantStories),
              toCreateStory: onCreateStory,
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

        // Other cards: Stories from other users
        for (final userStory in orderedStories) {
          storyItems.add(
            _SocialStoryCard(
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: storyItems,
          ),
        );
      },
    );
  }
}

class _SuggestedFriendsSkeleton extends StatelessWidget {
  const _SuggestedFriendsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            width: 110,
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 70,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 50,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 50,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SuggestedFriendsSection extends StatelessWidget {
  final List<SSearchUser> users;
  final Function(String peerId) onChatTap;

  const _SuggestedFriendsSection({
    required this.users,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: users.length > 8 ? 8 : users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return Container(
            width: 110,
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
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      const Color(0xFF667eea).withValues(alpha: 0.2),
                  backgroundImage: user.baseUser.userImage.isNotEmpty
                      ? NetworkImage(user.baseUser.userImageS3)
                      : null,
                  child: user.baseUser.userImage.isEmpty
                      ? Text(
                          user.baseUser.fullName.isNotEmpty
                              ? user.baseUser.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Color(0xFF667eea),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    user.baseUser.fullName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 2),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => onChatTap(user.baseUser.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB48648),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.chat_bubble_2_fill,
                          size: 12,
                          color: Colors.white,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PublicSnapFeedSection extends StatefulWidget {
  const _PublicSnapFeedSection();

  @override
  State<_PublicSnapFeedSection> createState() => _PublicSnapFeedSectionState();
}

class _PublicSnapFeedSectionState extends State<_PublicSnapFeedSection> {
  final _postApiService = GetIt.I.get<PostApiService>();
  List<PostModel> _posts = [];
  bool _isLoading = true;

  void _onFeedRefreshRequested() {
    if (!mounted) return;
    _load();
  }

  Future<void> _navigateByMention(BuildContext ctx, String mention) async {
    final handle =
        mention.startsWith('@') ? mention.substring(1) : mention;
    if (!GetIt.I.isRegistered<ProfileApiService>()) return;
    final profileSvc = GetIt.I.get<ProfileApiService>();
    try {
      final users = await profileSvc.appUsers(
        UserFilterDto.init().copyWith(fullName: handle, limit: 5, page: 1),
      );
      if (!mounted || users.isEmpty) return;
      ctx.toPage(PeerProfileView(peerId: users.first.baseUser.id));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    PostApiService.socialFeedRefreshToken
        .addListener(_onFeedRefreshRequested);
    _load();
  }

  @override
  void dispose() {
    PostApiService.socialFeedRefreshToken
        .removeListener(_onFeedRefreshRequested);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      const pageSize = 20;
      const targetCount = 10;
      final filtered = <PostModel>[];
      var page = 1;
      var hasMore = true;

      while (hasMore && filtered.length < targetCount && page <= 4) {
        final posts = await _postApiService.getPosts(page: page, limit: pageSize);
        filtered.addAll(
          posts.where((p) => p.postType != PostType.reel && p.isReel != true),
        );
        hasMore = posts.length >= pageSize;
        page++;
      }

      if (mounted) {
        setState(() {
          _posts = filtered.take(targetCount).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('PublicSnapFeed error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Center(
          child: Column(children: [
            Icon(CupertinoIcons.photo, size: 48,
                color: Colors.grey.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('No posts yet. Be the first to share!',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 0),
      itemCount: _posts.length,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: PostFeedWidget(
          key: ValueKey(_posts[i].id),
          post: _posts[i],
          onAuthorTap: () => context.toPage(
              PeerProfileView(peerId: _posts[i].userId)),
          onHashtagTap: (tag) => context.toPage(
              HashtagPostsScreen(hashtag: tag)),
          onMentionTap: (mention) => _navigateByMention(context, mention),
          onDeleted: (postId) {
            setState(() {
              _posts.removeWhere((p) => p.id == postId);
            });
          },
          onUpdated: (updatedPost) {
            setState(() {
              final idx = _posts.indexWhere((p) => p.id == updatedPost.id);
              if (idx != -1) _posts[idx] = updatedPost;
            });
          },
        ),
      ),
    );
  }
}

class _SocialStoryCard extends StatefulWidget {
  final UserStoryModel userStory;
  final bool isMe;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? toCreateStory;

  const _SocialStoryCard({
    required this.userStory,
    required this.isMe,
    required this.isLoading,
    required this.onTap,
    this.toCreateStory,
  });

  @override
  State<_SocialStoryCard> createState() => _SocialStoryCardState();
}

class _SocialStoryCardState extends State<_SocialStoryCard> {
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
    // For Cloudinary videos, generate thumbnail URL by changing extension to .jpg
    if (videoUrl.contains('cloudinary.com')) {
      // Simply change the video extension to .jpg for Cloudinary to return a thumbnail
      return videoUrl.replaceAll(RegExp(r'\.(mov|mp4|avi|mkv|webm)$'), '.jpg');
    }
    return null;
  }

  String? _deriveCloudinaryVideoThumbnailUrl(String rawUrl) {
    try {
      if (rawUrl.isEmpty) return null;
      final fullUrl =
          rawUrl.startsWith('http') ? rawUrl : '${SConstants.baseMediaUrl}$rawUrl';
      final u = Uri.parse(fullUrl);
      if (!u.host.contains('res.cloudinary.com')) return null;
      final path = u.path;
      final idx = path.indexOf('/upload/');
      if (idx == -1) return null;
      final prefix =
          '${u.scheme}://${u.host}${path.substring(0, idx + '/upload/'.length)}';
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
    final isVideo = story.storyType == StoryType.video;

    if (isVideo && story.att != null) {
      final videoUrl = story.att!['url'] as String?;
      if (videoUrl != null && videoUrl.isNotEmpty) {
        // Generate thumbnail URL for Cloudinary videos
        _videoThumbnail = _generateVideoThumbnail(videoUrl);
        debugPrint(
            '_SocialStoryCard - Generated thumbnail URL: $_videoThumbnail');

        try {
          debugPrint('_SocialStoryCard - Initializing video: $videoUrl');
          _videoController =
              VideoPlayerController.networkUrl(Uri.parse(videoUrl));
          await _videoController!.initialize();
          await _videoController!.setVolume(0);
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
            debugPrint('_SocialStoryCard - Video initialized successfully');
            debugPrint(
                '_SocialStoryCard - Video size: ${_videoController!.value.size}');
            debugPrint(
                '_SocialStoryCard - Video duration: ${_videoController!.value.duration}');
          }
        } catch (e, stack) {
          debugPrint('Error initializing video: $e');
          debugPrint('Stack: $stack');
        }
      }
    }
  }

  Future<void> _resolvePostShareThumbnail() async {
    if (_isResolvingPostShareThumb) return;

    final story = widget.userStory.stories.first;
    final att = story.att ?? const <String, dynamic>{};
    final postId = (att['postId'] ?? '').toString();
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
          post.postType == PostType.video || post.postType == PostType.reel;
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
      // keep placeholder if we couldn't resolve thumbnail
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
        if (mounted && _videoController != null) {
          setState(() {
            _isVideoPlaying = true;
          });
          _videoController!.setVolume(0);
          _videoController!.play();
          _videoController!.setLooping(true);
        }
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

  @override
  Widget build(BuildContext context) {
    if (widget.isMe && widget.isLoading) {
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

    final story = widget.userStory.stories.first;
    final att = story.att ?? const <String, dynamic>{};
    final isTextStory = story.storyType == StoryType.text;
    final isVideo = story.storyType == StoryType.video;
    final isPostShare = (att['postId'] ?? '').toString().isNotEmpty;
    final postType = (att['postType'] ?? '').toString();
    final postCaption = (att['caption'] ?? story.caption ?? story.content).toString();
    final isPostVideo = postType == 'video' || postType == 'reel';
    final rawPostMedia = (att['mediaUrl'] ?? att['url'] ?? '').toString();
    final derivedVideoThumb = isPostVideo
      ? (_deriveCloudinaryVideoThumbnailUrl(rawPostMedia) ?? '')
      : '';
    final rawPostThumb = isPostVideo
      ? (att['thumbnailUrl'] ?? att['thumbUrl'] ?? derivedVideoThumb ?? '').toString()
      : (att['thumbnailUrl'] ?? att['mediaUrl'] ?? att['thumbUrl'] ?? '').toString();
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
    // Use generated thumbnail for video, or fallback to thumbUrl from API
    final thumbUrl = isVideo
        ? (_videoThumbnail ?? (story.att?['thumbUrl'] as String?))
        : (story.att?['url'] as String?);
    final selectedThumbUrl = isPostShare ? postThumbUrl : thumbUrl;
    final hasSelectedThumb = selectedThumbUrl != null && selectedThumbUrl.isNotEmpty;

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
          image: (!isPostShare && !_isVideoPlaying && hasSelectedThumb)
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
                                  color: const Color(0xFFB48648).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(CupertinoIcons.map_pin,
                                        size: 14, color: Color(0xFFB48648)),
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
            // Video playing
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
            // Text story content
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
            // User avatar and name at bottom
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
                        widget.isMe
                            ? 'Your Story'
                            : widget.userStory.userData.fullName,
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

    // Wrap video stories with VisibilityDetector
    if (isVideo) {
      return VisibilityDetector(
        key: Key('story_video_${widget.userStory.userData.id}'),
        onVisibilityChanged: _onVisibilityChanged,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
