import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up/app/modules/post/hashtag_posts_screen.dart';
import 'package:super_up/app/modules/post/post_feed_widget.dart';
import 'package:super_up/app/modules/post/create_post_screen.dart';
import 'package:super_up_core/super_up_core.dart';

class PostFeedScreen extends StatefulWidget {
  const PostFeedScreen({super.key});

  @override
  State<PostFeedScreen> createState() => _PostFeedScreenState();
}

class _PostFeedScreenState extends State<PostFeedScreen> {
  final _postApiService = GetIt.I.get<PostApiService>();
  final _scrollController = ScrollController();

  final List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final posts = await _postApiService.getPosts(
        page: 1,
        limit: _limit,
      );
      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(posts);
          _currentPage = 1;
          _hasMore = posts.length >= _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load posts: $e'),
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
      final posts = await _postApiService.getPosts(
        page: nextPage,
        limit: _limit,
      );
      if (mounted) {
        setState(() {
          _posts.addAll(posts);
          _currentPage = nextPage;
          _hasMore = posts.length >= _limit;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more posts: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    await _loadPosts();
  }

  void _onPostDeleted(String postId) {
    if (!mounted) return;
    setState(() {
      _posts.removeWhere((p) => p.id == postId);
    });
  }

  void _createPost() async {
    final created = await Navigator.push<bool>(
          context,
          CupertinoPageRoute(
            builder: (_) => const CreatePostScreen(initialTab: 'text'),
          ),
        ) ??
        false;
    if (created && mounted) {
      _loadPosts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post published successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _posts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _posts.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _posts.length) {
                              return _buildLoadingMoreIndicator();
                            }
                            final post = _posts[index];
                            return PostFeedWidget(
                              key: ValueKey(post.id),
                              post: post,
                              onAuthorTap: () => context.toPage(
                                  PeerProfileView(peerId: post.userId)),
                              onHashtagTap: (tag) => context.toPage(
                                  HashtagPostsScreen(hashtag: tag)),
                              onMentionTap: (mention) =>
                                  _navigateByMention(context, mention),
                              onDeleted: _onPostDeleted,
                              onUpdated: (updatedPost) {
                                if (!mounted) return;
                                setState(() {
                                  final index = _posts.indexWhere((p) => p.id == updatedPost.id);
                                  if (index != -1) {
                                    _posts[index] = updatedPost;
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Feed',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _createPost,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Post'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB48648),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
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
            Icons.post_add,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share something!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _createPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB48648),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text('Create Post'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CupertinoActivityIndicator(),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading more...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
