import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up/app/modules/post/hashtag_posts_screen.dart';
import 'package:super_up/app/modules/reels/reels_screen.dart';
import 'package:super_up_core/super_up_core.dart';

class SocialExploreView extends StatefulWidget {
  const SocialExploreView({super.key});

  @override
  State<SocialExploreView> createState() => _SocialExploreViewState();
}

class _SocialExploreViewState extends State<SocialExploreView> {
  final _postApiService = GetIt.I.get<PostApiService>();

  bool _isLoading = true;
  List<PostModel> _topReels = const [];
  List<_HashtagCount> _topHashtags = const [];

  @override
  void initState() {
    super.initState();
    _loadExploreData();
  }

  Future<void> _loadExploreData() async {
    setState(() => _isLoading = true);
    try {
      final reelsFuture = _postApiService.getReels(page: 1, limit: 80);
      final hashtagsFuture = _loadTopHashtags();
      final results = await Future.wait([reelsFuture, hashtagsFuture]);

      final reels = List<PostModel>.from(results[0] as List<PostModel>);
      reels.sort((a, b) {
        final viewsCmp = _viewsOf(b).compareTo(_viewsOf(a));
        if (viewsCmp != 0) return viewsCmp;
        return _engagementOf(b).compareTo(_engagementOf(a));
      });

      if (!mounted) return;
      setState(() {
        _topReels = reels.take(12).toList();
        _topHashtags = results[1] as List<_HashtagCount>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  int _viewsOf(PostModel post) => post.viewsCount;

  int _engagementOf(PostModel post) =>
      post.likesCount + post.commentsCount + (post.sharesCount * 2);

  Future<List<_HashtagCount>> _loadTopHashtags() async {
    final counts = <String, int>{};
    const pageSize = 50;
    var page = 1;

    while (page <= 5) {
      final posts = await _postApiService.getPosts(page: page, limit: pageSize);
      if (posts.isEmpty) break;

      for (final post in posts) {
        for (final raw in post.hashtags) {
          final tag = raw.replaceAll('#', '').trim().toLowerCase();
          if (tag.isEmpty) continue;
          counts[tag] = (counts[tag] ?? 0) + 1;
        }
      }

      if (posts.length < pageSize) break;
      page++;
    }

    final list = counts.entries
        .map((e) => _HashtagCount(tag: e.key, postsCount: e.value))
        .toList()
      ..sort((a, b) => b.postsCount.compareTo(a.postsCount));
    return list.take(16).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            largeTitle: const Text('Explore'),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TrendingReelsSection(reels: _topReels),
                  const SizedBox(height: 20),
                  _TrendingHashtagsSection(hashtags: _topHashtags),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendingReelsSection extends StatelessWidget {
  final List<PostModel> reels;

  const _TrendingReelsSection({required this.reels});

  String _fullMedia(String raw) {
    if (raw.isEmpty) return raw;
    return raw.startsWith('http') ? raw : '${SConstants.baseMediaUrl}$raw';
  }

  String _deriveCloudinaryThumb(String url) {
    if (url.isEmpty || !url.startsWith('http')) return '';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains('res.cloudinary.com')) return '';
    final path = uri.path;
    const upload = '/upload/';
    final idx = path.indexOf(upload);
    if (idx == -1) return '';
    final prefix =
        '${uri.scheme}://${uri.host}${path.substring(0, idx + upload.length)}';
    final tail =
        path.substring(idx + upload.length).replaceFirst(RegExp(r'^/+'), '');
    final jpgTail = tail.replaceFirst(RegExp(r'\.[^./]+$'), '.jpg');
    return '${prefix}so_1,w_640,h_360,c_fill,f_jpg/$jpgTail';
  }

  String _thumbFor(PostModel post) {
    final mediaUrl = _fullMedia(post.media?.url ?? '');
    final explicit = _fullMedia(post.media?.thumbnail ?? '');
    if (explicit.isNotEmpty) return explicit;
    final derived = _deriveCloudinaryThumb(mediaUrl);
    if (derived.isNotEmpty) return derived;
    final first = post.mediaUrls.isNotEmpty ? _fullMedia(post.mediaUrls.first) : '';
    return first;
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Trending Reels',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (reels.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'No reels found yet.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: reels.length,
              itemBuilder: (context, index) {
                final reel = reels[index];
                final thumb = _thumbFor(reel);
                final views = reel.viewsCount > 0
                    ? reel.viewsCount
                    : reel.likesCount + reel.commentsCount + reel.sharesCount;

                return GestureDetector(
                  onTap: () => context.toPage(ReelsScreen(initialReelIndex: index)),
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black,
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: thumb.isNotEmpty
                              ? Image.network(
                                  thumb,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFF222222),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFf093fb).withValues(alpha: 0.8),
                                        const Color(0xFFf5576c).withValues(alpha: 0.8),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0),
                                  Colors.black.withValues(alpha: 0.75),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.play_circle_fill,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_formatCount(views)} views',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '🔥 Trending',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TrendingHashtagsSection extends StatelessWidget {
  final List<_HashtagCount> hashtags;

  const _TrendingHashtagsSection({required this.hashtags});

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Trending Hashtags',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (hashtags.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'No hashtags found yet.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hashtags.map((item) {
                return GestureDetector(
                  onTap: () => context.toPage(
                    HashtagPostsScreen(hashtag: item.tag),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF667eea).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '#',
                          style: TextStyle(
                            color: Color(0xFF667eea),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          item.tag,
                          style: const TextStyle(
                            color: Color(0xFF667eea),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_formatCount(item.postsCount)} posts',
                          style: const TextStyle(
                            color: Color(0xFF667eea),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _HashtagCount {
  final String tag;
  final int postsCount;

  const _HashtagCount({
    required this.tag,
    required this.postsCount,
  });
}
