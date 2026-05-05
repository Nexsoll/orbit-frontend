import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:super_up/app/modules/marketplace/services/marketplace_api_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import 'create_marketplace_listing_view.dart';

class MarketplaceMyListingsView extends StatefulWidget {
  const MarketplaceMyListingsView({super.key});

  @override
  State<MarketplaceMyListingsView> createState() => _MarketplaceMyListingsViewState();
}

class _MarketplaceMyListingsViewState extends State<MarketplaceMyListingsView> {
  late final MarketplaceApiService _api;

  bool _loading = false;
  int _tab = 0;

  List<Map<String, dynamic>> _items = const [];

  static const _tabs = <String>['draft', 'published'];

  @override
  void initState() {
    super.initState();
    _api = GetIt.I.get<MarketplaceApiService>();
    _load();
  }

  Future<num?> _askSoldPrice(num? initial) async {
    final c = TextEditingController(text: initial == null ? '' : initial.toString());
    final res = await showCupertinoDialog<String?>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Mark as sold'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: c,
            placeholder: 'Sold price (KES)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Sold'),
          ),
        ],
      ),
    );

    if (res == null) return null;
    final raw = res.trim();
    if (raw.isEmpty) {
      if (initial != null && initial > 0) return initial;
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Enter a valid sold price');
      }
      return null;
    }
    final parsed = num.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Enter a valid sold price');
      }
      return null;
    }
    return parsed;
  }

  Future<void> _markSold(Map<String, dynamic> it, String id) async {
    final isSold = (it['isSold'] == true) ||
        (it['isSold']?.toString().trim().toLowerCase() == 'true');
    if (isSold) return;

    final soldPrice = await _askSoldPrice(it['price'] as num?);
    if (soldPrice == null) return;

    VAppAlert.showLoading(context: context);
    try {
      await _api.markListingSold(id, soldPrice: soldPrice);
      if (!mounted) return;
      context.pop();
      await _load();
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Marked as sold. Payment will be released by admin.',
      );
    } catch (e) {
      if (!mounted) return;
      context.pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  Future<void> _toggleHide(Map<String, dynamic> it, String id) async {
    final isSold = (it['isSold'] == true) ||
        (it['isSold']?.toString().trim().toLowerCase() == 'true');
    if (isSold) {
      VAppAlert.showErrorSnackBar(context: context, message: 'This listing is sold');
      return;
    }
    final isHidden = (it['isHidden'] == true) ||
        (it['isHidden']?.toString().trim().toLowerCase() == 'true');

    VAppAlert.showLoading(context: context);
    try {
      if (isHidden) {
        await _api.unhideListing(id);
      } else {
        await _api.hideListing(id);
      }
      if (!mounted) return;
      context.pop();
      await _load();
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: isHidden ? 'Listing is now visible' : 'Listing hidden',
      );
    } catch (e) {
      if (!mounted) return;
      context.pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  String _formatKes(num? value) {
    if (value == null) return '';
    final f = NumberFormat('#,##0', 'en_KE');
    return 'KES ${f.format(value)}';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = _tabs[_tab];
      final list = await _api.myListings(status: status);
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteListing(String id) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete listing'),
        content: const Text('Are you sure you want to delete this listing?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            isDestructiveAction: true,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    VAppAlert.showLoading(context: context);
    try {
      await _api.deleteListing(id);
      if (!mounted) return;
      context.pop();
      await _load();
      VAppAlert.showSuccessSnackBar(context: context, message: 'Deleted');
    } catch (e) {
      if (!mounted) return;
      context.pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => CreateMarketplaceListingView(initialListing: item),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _tabs[_tab];

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Your listings'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loading
              ? null
              : () async {
                  final changed = await Navigator.of(context).push<bool>(
                    CupertinoPageRoute(builder: (_) => const CreateMarketplaceListingView()),
                  );
                  if (changed == true) {
                    await _load();
                  }
                },
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _tab,
                onValueChanged: (v) {
                  if (v == null) return;
                  setState(() => _tab = v);
                  _load();
                },
                children: const {
                  0: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Drafts')),
                  1: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Published')),
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _items.isEmpty
                      ? Center(
                          child: Text(
                            'No $current listings',
                            style: const TextStyle(color: CupertinoColors.systemGrey),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final it = _items[index];
                            final id = (it['_id'] ?? it['id']).toString();
                            return _tile(it, id);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> it, String id) {
    final title = (it['title'] ?? '').toString();
    final category = (it['category'] ?? '').toString();
    final status = (it['status'] ?? '').toString();
    final price = (it['price'] as num?);
    final isSold = (it['isSold'] == true) ||
        (it['isSold']?.toString().trim().toLowerCase() == 'true');
    final isHidden = (it['isHidden'] == true) ||
        (it['isHidden']?.toString().trim().toLowerCase() == 'true');

    String? thumbUrl;
    final media = it['media'];
    if (media is List) {
      final img = media.whereType<Map>().firstWhere(
            (m) => (m['type'] ?? '').toString() == 'image' && (m['url'] ?? '').toString().isNotEmpty,
            orElse: () => const {},
          );
      thumbUrl = (img['url'] ?? '').toString();
      if (thumbUrl.isEmpty) thumbUrl = null;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: thumbUrl == null
                ? Container(
                    width: 66,
                    height: 66,
                    color: CupertinoColors.systemGrey5,
                    child: const Icon(CupertinoIcons.photo),
                  )
                : VPlatformCacheImageWidget(
                    source: VPlatformFile.fromUrl(networkUrl: thumbUrl),
                    size: const Size(66, 66),
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.isEmpty ? 'Untitled' : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (price != null) Text(_formatKes(price), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                if (category.isNotEmpty) Text(category, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                const SizedBox(height: 4),
                Text(
                  isSold
                      ? 'sold'
                      : (isHidden ? 'hidden' : status),
                  style: TextStyle(
                    fontSize: 11,
                    color: isSold
                        ? CupertinoColors.activeGreen
                        : (isHidden ? CupertinoColors.destructiveRed : CupertinoColors.systemGrey),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (_tab == 1)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: isSold ? null : () => _toggleHide(it, id),
                  child: Icon(
                    isHidden ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                    size: 20,
                    color: isHidden ? CupertinoColors.destructiveRed : CupertinoColors.systemGrey,
                  ),
                ),
              if (_tab == 1 && !isSold)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _markSold(it, id),
                  child: const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    size: 20,
                    color: CupertinoColors.activeGreen,
                  ),
                ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: isSold ? null : () => _edit(it),
                child: const Icon(CupertinoIcons.pencil, size: 20),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _deleteListing(id),
                child: const Icon(CupertinoIcons.delete, size: 20, color: CupertinoColors.destructiveRed),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
