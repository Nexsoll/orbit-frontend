import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up/app/modules/post/post_feed_widget.dart';
import 'package:super_up/app/modules/post/services/post_saved_posts_service.dart';
import 'package:super_up_core/super_up_core.dart';

class SocialSavedPostsView extends StatefulWidget {
  const SocialSavedPostsView({super.key});

  @override
  State<SocialSavedPostsView> createState() => _SocialSavedPostsViewState();
}

class _SocialSavedPostsViewState extends State<SocialSavedPostsView> {
  final _savedService = PostSavedPostsService.instance;

  bool _isLoading = false;
  List<PostModel> _posts = const [];

  @override
  void initState() {
    super.initState();
    _savedService.changes.addListener(_onSavedPostsChanged);
    _loadSavedPosts();
  }

  @override
  void dispose() {
    _savedService.changes.removeListener(_onSavedPostsChanged);
    super.dispose();
  }

  void _onSavedPostsChanged() {
    if (!mounted) return;
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final posts = await _savedService.getAll();
      if (!mounted) return;
      setState(() {
        _posts = posts.reversed.toList();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSavedPosts,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Icon(CupertinoIcons.bookmark, size: 52, color: Colors.grey),
            SizedBox(height: 12),
            Center(
              child: Text(
                'No saved posts yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Save posts from feed or reels and view them here.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavedPosts,
      child: ListView.builder(
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return PostFeedWidget(
            key: ValueKey('saved_${post.id}'),
            post: post,
            onAuthorTap: () => context.toPage(PeerProfileView(peerId: post.userId)),
            onSaveChanged: (saved) {
              if (!saved && mounted) {
                setState(() {
                  _posts = _posts.where((p) => p.id != post.id).toList();
                });
              }
            },
            onDeleted: (postId) {
              setState(() {
                _posts = _posts.where((p) => p.id != postId).toList();
              });
            },
            onUpdated: (updatedPost) {
              setState(() {
                final idx = _posts.indexWhere((p) => p.id == updatedPost.id);
                if (idx != -1) {
                  final newList = List<PostModel>.from(_posts);
                  newList[idx] = updatedPost;
                  _posts = newList;
                }
              });
            },
          );
        },
      ),
    );
  }
}
