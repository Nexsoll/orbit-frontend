import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/modules/marketplace/services/marketplace_api_service.dart';
import 'package:super_up/app/modules/marketplace/services/marketplace_bookmarks_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import 'marketplace_listing_details_view.dart';

class MarketplaceBookmarkedListingsView extends StatefulWidget {
  const MarketplaceBookmarkedListingsView({super.key});

  @override
  State<MarketplaceBookmarkedListingsView> createState() =>
      _MarketplaceBookmarkedListingsViewState();
}

class _MarketplaceBookmarkedListingsViewState
    extends State<MarketplaceBookmarkedListingsView> {
  bool _loading = false;
  List<Map<String, dynamic>> _items = const [];
  bool _authed = true;
  late final MarketplaceApiService _api;

  @override
  void initState() {
    super.initState();
    try {
      _api = GetIt.I.get<MarketplaceApiService>();
    } catch (_) {
      _api = MarketplaceApiService.init();
    }
    try {
      AppAuth.myProfile;
      _authed = true;
    } catch (_) {
      _authed = false;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await MarketplaceBookmarksService.instance.getAll();

      final cleaned = <Map<String, dynamic>>[];
      for (final item in list) {
        final id = (item['_id'] ?? item['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        try {
          final latest = await _api.getListingPublic(id);
          cleaned.add(latest);
        } catch (_) {
          await MarketplaceBookmarksService.instance.remove(id);
        }
      }
      if (!mounted) return;
      setState(() => _items = cleaned.reversed.toList());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatKes(num? value) {
    if (value == null) return '';
    final f = NumberFormat('#,##0', 'en_KE');
    return 'KES ${f.format(value)}';
  }

  String? _firstImageUrl(Map<String, dynamic> listing) {
    final media = listing['media'];
    if (media is List) {
      for (final m in media) {
        if (m is Map) {
          final type = (m['type'] ?? '').toString();
          final url = (m['url'] ?? '').toString();
          if (type == 'image' && url.isNotEmpty) return url;
        }
      }
    }
    return null;
  }

  Widget _card(CupertinoThemeData theme, Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString();
    final price = (item['price'] as num?);
    final imgUrl = _firstImageUrl(item);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => MarketplaceListingDetailsView(listing: item),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Container(
                  width: double.infinity,
                  color: CupertinoColors.systemGrey5,
                  child: imgUrl == null
                      ? const Icon(
                          CupertinoIcons.photo,
                          size: 40,
                          color: CupertinoColors.systemGrey,
                        )
                      : VPlatformCacheImageWidget(
                          source: VPlatformFile.fromUrl(networkUrl: imgUrl),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatKes(price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.label,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Bookmarked'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loading ? null : _load,
          child: _loading
              ? const CupertinoActivityIndicator()
              : const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: !_authed
            ? const Center(
                child: Text(
                  'Please login to view bookmarks',
                  style: TextStyle(color: CupertinoColors.systemGrey),
                ),
              )
            : _items.isEmpty
            ? const Center(
                child: Text(
                  'No bookmarked listings',
                  style: TextStyle(color: CupertinoColors.systemGrey),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.72,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) => _card(theme, _items[index]),
              ),
      ),
    );
  }
}
