import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, BoxShadow;
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up/app/modules/post/post_feed_widget.dart';
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up_core/super_up_core.dart';

class HashtagPostsScreen extends StatefulWidget {
  final String hashtag; // without the leading #

  const HashtagPostsScreen({super.key, required this.hashtag});

  @override
  State<HashtagPostsScreen> createState() => _HashtagPostsScreenState();
}

class _HashtagPostsScreenState extends State<HashtagPostsScreen> {
  final _svc = GetIt.I.get<PostApiService>();
  final List<PostModel> _posts = [];
  bool _loading = true;
  bool _hasMore = true;
  int _page = 1;
  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_hasMore) return;
    try {
      final page = await _svc.getPosts(
        page: _page,
        limit: _limit,
        hashtag: widget.hashtag,
      );
      if (mounted) {
        setState(() {
          _posts.addAll(page);
          _hasMore = page.length >= _limit;
          _page++;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToProfile(String userId) {
    context.toPage(PeerProfileView(peerId: userId));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('#${widget.hashtag}'),
        transitionBetweenRoutes: false,
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _posts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.tag,
                            size: 48, color: CupertinoColors.systemGrey),
                        const SizedBox(height: 12),
                        Text(
                          'No posts with #${widget.hashtag}',
                          style: const TextStyle(
                              color: CupertinoColors.systemGrey),
                        ),
                      ],
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollEndNotification &&
                          n.metrics.pixels >=
                              n.metrics.maxScrollExtent - 300) {
                        _load();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _posts.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _posts.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                                child: CupertinoActivityIndicator()),
                          );
                        }
                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          decoration: BoxDecoration(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: PostFeedWidget(
                            key: ValueKey(_posts[i].id),
                            post: _posts[i],
                            onAuthorTap: () =>
                                _navigateToProfile(_posts[i].userId),
                            onMentionTap: (mention) async {
                              final handle = mention.startsWith('@')
                                  ? mention.substring(1)
                                  : mention;
                              _navigateByHandle(handle);
                            },
                            onHashtagTap: (tag) => context.toPage(
                                HashtagPostsScreen(hashtag: tag)),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Future<void> _navigateByHandle(String handle) async {
    if (!GetIt.I.isRegistered<ProfileApiService>()) return;
    final profileSvc = GetIt.I.get<ProfileApiService>();
    try {
      final users = await profileSvc.appUsers(
        UserFilterDto.init().copyWith(fullName: handle, limit: 5, page: 1),
      );
      if (!mounted || users.isEmpty) return;
      context.toPage(PeerProfileView(peerId: users.first.baseUser.id));
    } catch (_) {}
  }
}
