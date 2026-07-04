import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../live_stream/views/live_stream_options_view.dart';
import '../../post/create_post_screen.dart';
import 'social_home_view.dart';
import 'social_explore_view.dart';
import 'social_featured_view.dart';
import 'social_saved_posts_view.dart';
import '../../reels/reels_screen.dart';

class SocialMainView extends StatefulWidget {
  const SocialMainView({super.key});

  @override
  State<SocialMainView> createState() => _SocialMainViewState();
}

class _SocialMainViewState extends State<SocialMainView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabBgColor = isDark ? const Color(0xFF131313) : Colors.white;
    final tabItemColor = isDark ? Colors.white : Colors.black;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 94),
            child: IndexedStack(
              index: _currentIndex,
              children: [
                const SocialHomeView(),
                const SocialSavedPostsView(),
                ReelsScreen(key: const ValueKey('reels'), isActive: _currentIndex == 2),
                const SocialFeaturedView(),
                const SocialExploreView(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                height: 64 + bottomInset,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: tabBgColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(6, 7, 6, 8 + bottomInset),
                  child: Row(
                    children: [
                      // Left side - 3 items
                      Expanded(
                        child: _buildTabItem(
                          icon: CupertinoIcons.house,
                          label: 'Home',
                          isSelected: _currentIndex == 0,
                          tabItemColor: tabItemColor,
                          onTap: () => setState(() => _currentIndex = 0),
                        ),
                      ),
                      Expanded(
                        child: _buildTabItem(
                          icon: CupertinoIcons.bookmark,
                          label: 'Saved',
                          isSelected: _currentIndex == 1,
                          tabItemColor: tabItemColor,
                          onTap: () => setState(() => _currentIndex = 1),
                        ),
                      ),
                      Expanded(
                        child: _buildTabItem(
                          icon: CupertinoIcons.compass,
                          label: 'Explore',
                          isSelected: _currentIndex == 4,
                          tabItemColor: tabItemColor,
                          onTap: () => setState(() => _currentIndex = 4),
                        ),
                      ),
                      // Center - Post button
                      Expanded(
                        child: _buildPostButton(
                          onTap: () => _openCreatePost(context),
                        ),
                      ),
                      // Right side - 3 items
                      Expanded(
                        child: _buildLiveButton(
                          onTap: () => _openLiveStream(context),
                        ),
                      ),
                      Expanded(
                        child: _buildTabItem(
                          icon: CupertinoIcons.film,
                          label: 'Reels',
                          isSelected: _currentIndex == 2,
                          tabItemColor: tabItemColor,
                          onTap: () => setState(() => _currentIndex = 2),
                        ),
                      ),
                      Expanded(
                        child: _buildTabItem(
                          icon: CupertinoIcons.star,
                          label: 'Featured',
                          isSelected: _currentIndex == 3,
                          tabItemColor: tabItemColor,
                          onTap: () => setState(() => _currentIndex = 3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color tabItemColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(
              color: isSelected ? const Color(0xFFB48648) : tabItemColor,
              size: 24,
            ),
            child: Icon(icon),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFFB48648) : tabItemColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD3A362), Color(0xFFB48648)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              CupertinoIcons.add,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Post',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB48648),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(
              color: Colors.red,
              size: 24,
            ),
            child: Icon(CupertinoIcons.video_camera),
          ),
          SizedBox(height: 2),
          Text(
            'Live',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreatePost(BuildContext context) async {
    final created = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (_) => const CreatePostScreen(initialTab: 'text'),
      ),
    );
    if (created == true && mounted) {
      setState(() {
        _currentIndex = 0;
      });
      PostApiService.notifySocialFeedRefresh();
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Post published successfully',
      );
    }
  }

  void _openLiveStream(BuildContext context) {
    context.toPage(const LiveStreamOptionsView());
  }

}

