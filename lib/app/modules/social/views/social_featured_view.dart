import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, CircleAvatar;
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';
import 'package:super_up/app/modules/music/services/music_api_service.dart';
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up_core/super_up_core.dart';

class SocialFeaturedView extends StatefulWidget {
  const SocialFeaturedView({super.key});

  @override
  State<SocialFeaturedView> createState() => _SocialFeaturedViewState();
}

class _SocialFeaturedViewState extends State<SocialFeaturedView> {
  final _profileApiService = GetIt.I.get<ProfileApiService>();
  final _musicApi = GetIt.I.get<MusicApiService>();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  int _activeLoadId = 0;

  List<SSearchUser> _users = [];
  Map<String, int> _musicUploadCounts = {};
  Set<String> _followingIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  SSearchUser _artistToUser(Map<String, dynamic> artist) {
    final id = (artist['_id'] ?? artist['userId'] ?? artist['uploaderId'] ?? '')
        .toString();
    final fullName =
        (artist['fullName'] ?? artist['name'] ?? 'Unknown').toString();
    final image = (artist['userImage'] ?? artist['avatar'] ?? '').toString();
    return SSearchUser(
      baseUser: SBaseUser(
        id: id,
        fullName: fullName,
        userImage: image,
      ),
      bio: (artist['bio'] ?? artist['description'])?.toString(),
      phoneNumber: null,
      profession: artist['profession']?.toString(),
      roles: const [],
      createdAt:
          (artist['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
    );
  }

  List<SSearchUser> _sortUsersByUploadCount(List<SSearchUser> users) {
    final ranked = [...users]
      ..sort((a, b) {
        final aUploads = _musicUploadCounts[a.baseUser.id] ?? 0;
        final bUploads = _musicUploadCounts[b.baseUser.id] ?? 0;
        final uploadsCompare = bUploads.compareTo(aUploads);
        if (uploadsCompare != 0) return uploadsCompare;
        return a.baseUser.fullName
            .toLowerCase()
            .compareTo(b.baseUser.fullName.toLowerCase());
      });
    return ranked;
  }

  void _openProfile(SSearchUser user) {
    if (!mounted) return;
    context.toPage(PeerProfileView(peerId: user.baseUser.id));
  }

  Future<void> _loadFollowingStatusesInBackground(List<SSearchUser> users) async {
    final followingSet = Set<String>.from(_followingIds);
    const batchSize = 10;

    for (int i = 0; i < users.length; i += batchSize) {
      if (!mounted) return;
      final end = (i + batchSize) > users.length ? users.length : (i + batchSize);
      final batch = users.sublist(i, end);

      await Future.wait(batch.map((user) async {
        try {
          final isFollowing = await _profileApiService.checkIsFollowing(user.baseUser.id);
          if (isFollowing) followingSet.add(user.baseUser.id);
        } catch (_) {}
      }));

      if (!mounted) return;
      setState(() {
        _followingIds = Set<String>.from(followingSet);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = value);
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    final loadId = ++_activeLoadId;
    setState(() => _isLoading = true);
    try {
      final artists = await _musicApi.getArtists();
      if (!mounted || loadId != _activeLoadId) return;

      final q = _searchQuery.trim().toLowerCase();
      final uploadCounts = <String, int>{};
      final seenIds = <String>{};
      final users = <SSearchUser>[];

      for (final artist in artists) {
        final id = (artist['_id'] ?? artist['userId'] ?? artist['uploaderId'] ?? '')
            .toString();
        if (id.isEmpty || !seenIds.add(id)) continue;

        final uploads = _asInt(
          artist['contentCount'] ?? artist['uploadsCount'] ?? artist['count'] ?? 0,
        );
        if (uploads <= 0) continue;

        final name =
            (artist['fullName'] ?? artist['name'] ?? '').toString().trim();
        if (q.isNotEmpty && !name.toLowerCase().contains(q)) continue;

        uploadCounts[id] = uploads;
        users.add(_artistToUser(artist));
      }

      _musicUploadCounts = uploadCounts;
      final ranked = _sortUsersByUploadCount(users);
      final topUsers = ranked.take(120).toList();

      setState(() {
        _users = topUsers;
        _isLoading = false;
      });

      unawaited(_loadFollowingStatusesInBackground(topUsers));
    } catch (e) {
      if (!mounted || loadId != _activeLoadId) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(SSearchUser user) async {
    try {
      final isFollowing = _followingIds.contains(user.baseUser.id);
      if (isFollowing) {
        await _profileApiService.unfollowUser(user.baseUser.id);
        setState(() {
          _followingIds.remove(user.baseUser.id);
        });
      } else {
        await _profileApiService.followUser(user.baseUser.id);
        setState(() {
          _followingIds.add(user.baseUser.id);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            largeTitle: const Text('Featured Creators'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search creators...',
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_users.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.search,
                      size: 60,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No creators found'
                          : 'No results for "$_searchQuery"',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final user = _users[index];
                  final isFollowing = _followingIds.contains(user.baseUser.id);
                  return _UserCard(
                    user: user,
                    isFollowing: isFollowing,
                    onNameTap: () => _openProfile(user),
                    onFollow: () => _toggleFollow(user),
                  );
                },
                childCount: _users.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final SSearchUser user;
  final bool isFollowing;
  final VoidCallback onNameTap;
  final VoidCallback onFollow;

  const _UserCard({
    required this.user,
    required this.isFollowing,
    required this.onNameTap,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF667eea).withValues(alpha: 0.2),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: onNameTap,
                        child: Text(
                          user.baseUser.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (user.hasBadge) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.star_fill,
                        color: Color(0xFFB48648),
                        size: 14,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.getUserBio,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.profession != null && user.profession!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      user.profession!,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              color: isFollowing ? Colors.grey[400] : const Color(0xFFB48648),
              borderRadius: BorderRadius.circular(16),
              onPressed: onFollow,
              child: Text(
                isFollowing ? 'Unfollow' : 'Follow',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
