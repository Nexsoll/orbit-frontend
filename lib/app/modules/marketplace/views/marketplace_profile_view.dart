import 'package:flutter/cupertino.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'dart:async';

import 'marketplace_bookmarked_listings_view.dart';
import 'marketplace_messages_view.dart';

class MarketplaceProfileView extends StatefulWidget {
  const MarketplaceProfileView({super.key});

  @override
  State<MarketplaceProfileView> createState() => _MarketplaceProfileViewState();
}

class _MarketplaceProfileViewState extends State<MarketplaceProfileView> {
  static const _accent = Color(0xFFB48648);

  bool _authed = false;
  String _name = 'Guest';
  String? _imageUrl;
  bool _isSeller = false;
  bool _loadingSeller = false;
  int _unreadMarketRooms = 0;
  StreamSubscription<VRoomEvents>? _roomSub;
  StreamSubscription<VMessageEvents>? _messageSub;
  bool _refreshingUnread = false;

  @override
  void initState() {
    super.initState();
    try {
      final p = AppAuth.myProfile;
      _authed = true;
      _name = p.baseUser.fullName;
      _imageUrl = p.baseUser.userImageS3;
    } catch (_) {
      _authed = false;
      _name = 'Guest';
      _imageUrl = null;
    }

    if (_authed) {
      _loadSellerStatus();
      _listenUnread();
    }
  }

  void _listenUnread() {
    unawaited(_refreshUnread());
    try {
      _roomSub?.cancel();
      _roomSub = VChatController.I.nativeApi.streams.roomStream
          .where(
            (event) =>
                event is VUpdateRoomUnReadCountByOneEvent ||
                event is VUpdateRoomUnReadCountToZeroEvent ||
                event is VInsertRoomEvent ||
                event is VDeleteRoomEvent,
          )
          .listen((_) {
        unawaited(_refreshUnread());
      });
    } catch (_) {}
    try {
      _messageSub?.cancel();
      _messageSub = VChatController.I.nativeApi.streams.messageStream
          .where((e) => e is VInsertMessageEvent)
          .listen((_) {
        unawaited(_refreshUnread());
      });
    } catch (_) {}
  }

  Future<void> _refreshUnread() async {
    if (_refreshingUnread) return;
    _refreshingUnread = true;
    try {
      final rooms = await VChatController.I.nativeApi.local.room.getRooms(limit: 200);
      final count = rooms
          .where((r) => r.roomType == VRoomType.o && !r.isArchived && r.unReadCount > 0)
          .length;
      if (!mounted) return;
      if (_unreadMarketRooms != count) {
        setState(() => _unreadMarketRooms = count);
      }
    } catch (_) {
      if (!mounted) return;
    } finally {
      _refreshingUnread = false;
    }
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _messageSub?.cancel();
    super.dispose();
  }

  Widget _redDot() {
    if (_unreadMarketRooms <= 0) return const SizedBox.shrink();
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Color(0xFFFF3B30),
        shape: BoxShape.circle,
      ),
    );
  }

  Future<void> _loadSellerStatus() async {
    if (_loadingSeller) return;
    setState(() => _loadingSeller = true);
    try {
      if (!mounted) return;
      setState(() {
        _isSeller = true;
      });
    } finally {
      if (mounted) setState(() => _loadingSeller = false);
    }
  }

  Widget _badge() {
    final label = _isSeller ? 'Seller' : 'Buyer';
    final bg = _isSeller ? _accent.withValues(alpha: 0.12) : CupertinoColors.systemGrey5;
    final fg = _isSeller ? _accent : CupertinoColors.label;
    final icon = _isSeller ? CupertinoIcons.tag_fill : CupertinoIcons.bag;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final url = (_imageUrl ?? '').trim();
    final has = url.isNotEmpty;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _accent.withValues(alpha: 0.35), width: 2),
        color: CupertinoColors.systemGrey5,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: has
            ? VPlatformCacheImageWidget(
                source: VPlatformFile.fromUrl(networkUrl: url),
                fit: BoxFit.cover,
              )
            : const Center(
                child: Icon(
                  CupertinoIcons.person_fill,
                  size: 28,
                  color: _accent,
                ),
              ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 18,
                  color: _accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 10),
            ],
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: CupertinoColors.systemGrey,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Profile')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _avatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (_loadingSeller)
                              const CupertinoActivityIndicator(radius: 8)
                            else
                              _badge(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _actionTile(
              icon: CupertinoIcons.chat_bubble_2,
              title: 'Messages',
              onTap: !_authed
                  ? null
                  : () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const MarketplaceMessagesView(),
                        ),
                      );
                    },
              trailing: _redDot(),
            ),
            const SizedBox(height: 10),
            _actionTile(
              icon: CupertinoIcons.bookmark,
              title: 'Bookmarks',
              onTap: !_authed
                  ? null
                  : () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const MarketplaceBookmarkedListingsView(),
                        ),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}
