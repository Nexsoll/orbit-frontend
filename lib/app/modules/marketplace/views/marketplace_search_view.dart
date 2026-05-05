import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:super_up/app/modules/marketplace/services/marketplace_api_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import 'marketplace_listing_details_view.dart';

class MarketplaceSearchView extends StatefulWidget {
  final double? lat;
  final double? lng;
  final double? radiusKm;
  final int? minPrice;
  final int? maxPrice;
  final String? condition;

  const MarketplaceSearchView({
    super.key,
    this.lat,
    this.lng,
    this.radiusKm,
    this.minPrice,
    this.maxPrice,
    this.condition,
  });

  @override
  State<MarketplaceSearchView> createState() => _MarketplaceSearchViewState();
}

class _MarketplaceSearchViewState extends State<MarketplaceSearchView> {
  late final MarketplaceApiService _api;

  final _ctrl = TextEditingController();

  Timer? _suggestDebounce;
  bool _suggestLoading = false;
  List<String> _suggestions = const [];
  String _lastSuggestQ = '';

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  List<String> _recent = const [];

  static const List<String> _fallbackKeywords = [
    'shirt',
    'shoes',
    'shorts',
    'sweater',
    'suit',
    'socks',
    'skirt',
    'sandal',
    'samsung',
    'sony',
    'iphone',
    'ipad',
    'infinix',
    'tecno',
    'laptop',
    'macbook',
    'keyboard',
    'mouse',
    'monitor',
    'tv',
    'headphones',
    'earbuds',
    'speaker',
    'watch',
    'smartwatch',
    'bag',
    'backpack',
    'wallet',
    'perfume',
    'camera',
    'bicycle',
    'motorbike',
    'car',
    'sofa',
    'chair',
    'table',
    'bed',
    'mattress',
    'microwave',
    'fridge',
    'oven',
    'blender',
    'fan',
    'ac',
  ];

  @override
  void initState() {
    super.initState();
    _api = GetIt.I.get<MarketplaceApiService>();
    _loadRecent();
  }

  bool _isStopWord(String w) {
    switch (w) {
      case 'the':
      case 'and':
      case 'or':
      case 'for':
      case 'with':
      case 'a':
      case 'an':
      case 'to':
      case 'in':
      case 'of':
      case 'on':
      case 'at':
      case 'by':
      case 'from':
      case 'new':
        return true;
      default:
        return false;
    }
  }

  Iterable<String> _tokenizeWords(String input) sync* {
    final re = RegExp(r'[A-Za-z0-9]+');
    for (final m in re.allMatches(input)) {
      final w = m.group(0) ?? '';
      if (w.length < 2) continue;
      if (RegExp(r'^\d+$').hasMatch(w)) continue;
      yield w;
    }
  }

  String _norm(String w) => w.trim().toLowerCase();

  List<String> _fallbackMatches(String q) {
    final qq = q.trim().toLowerCase();
    if (qq.isEmpty) return const [];
    return _fallbackKeywords.where((e) => e.startsWith(qq)).take(10).toList();
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double toRad(double d) => d * 3.141592653589793 / 180.0;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) + cos(toRad(lat1)) * cos(toRad(lat2)) * (sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  List<Map<String, dynamic>> _applyLocalDistanceFilter(List<Map<String, dynamic>> items) {
    final lat = widget.lat;
    final lng = widget.lng;
    final radius = widget.radiusKm;
    if (lat == null || lng == null || radius == null || radius <= 0) return items;

    return items.where((it) {
      final dLat = (it['locationLat'] as num?)?.toDouble();
      final dLng = (it['locationLng'] as num?)?.toDouble();
      if (dLat == null || dLng == null) return false;
      return _haversineKm(lat, lng, dLat, dLng) <= radius;
    }).toList();
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  String _recentKey() {
    try {
      final uid = AppAuth.myProfile.baseUser.id;
      if (uid.isNotEmpty) return 'marketplace_recent_searches_$uid';
    } catch (_) {}
    return 'marketplace_recent_searches_guest';
  }

  Future<void> _loadRecent() async {
    final list = VAppPref.getList(_recentKey());
    if (list == null || list.isEmpty) {
      setState(() => _recent = const []);
      return;
    }

    final out = <String>[];
    for (final item in list) {
      final s = item.toString().trim();
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
      if (out.length >= 10) break;
    }
    setState(() => _recent = out);
  }

  Future<void> _saveRecent(String q) async {
    final t = q.trim();
    if (t.isEmpty) return;

    final list = VAppPref.getList(_recentKey()) ?? [];
    final out = <String>[t];
    for (final item in list) {
      final s = item.toString().trim();
      if (s.isEmpty) continue;
      if (s.toLowerCase() == t.toLowerCase()) continue;
      out.add(s);
      if (out.length >= 10) break;
    }
    await VAppPref.setList(_recentKey(), out);
    if (!mounted) return;
    setState(() => _recent = out);
  }

  Future<void> _clearRecent() async {
    await VAppPref.setList(_recentKey(), const []);
    if (!mounted) return;
    setState(() => _recent = const []);
  }

  void _onQueryChanged(String v) {
    final q = v.trim();
    if (!mounted) return;

    _suggestDebounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _error = null;
        _items = const [];
        _suggestLoading = false;
        _suggestions = const [];
        _lastSuggestQ = '';
      });
      return;
    }

    // Show suggestions instantly (like Google) while we debounce the API call
    final local = _recentMatches(q);
    final fb = _fallbackMatches(q);
    final merged = <String>[];
    for (final s in local.expand(_tokenizeWords)) {
      final w = _norm(s);
      if (w.isEmpty) continue;
      if (!merged.contains(w) && w.startsWith(q.toLowerCase())) merged.add(w);
      if (merged.length >= 10) break;
    }
    for (final w in fb) {
      if (!merged.contains(w)) merged.add(w);
      if (merged.length >= 10) break;
    }
    setState(() {
      _error = null;
      _items = const [];
      _suggestions = merged;
      _suggestLoading = q.length >= 2;
    });

    // Avoid hitting API for 1-letter queries, but still show recent matches
    if (q.length < 2) return;

    _suggestDebounce = Timer(const Duration(milliseconds: 180), () {
      _fetchSuggestions(q);
    });
  }

  List<String> _recentMatches(String q) {
    if (q.trim().isEmpty) return const [];
    final qq = q.toLowerCase();
    return _recent
        .where((e) => e.toLowerCase().contains(qq))
        .take(6)
        .toList();
  }

  Future<void> _fetchSuggestions(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    if (_lastSuggestQ == query) return;

    setState(() {
      _suggestLoading = true;
      _lastSuggestQ = query;
    });

    try {
      final qLower = query.toLowerCase();

      final recWords = <String>[];
      for (final r in _recentMatches(query)) {
        for (final w in _tokenizeWords(r)) {
          final ww = _norm(w);
          if (ww.startsWith(qLower) && !recWords.contains(ww)) {
            recWords.add(ww);
          }
        }
        if (recWords.length >= 6) break;
      }

      final list = await _api.feed(
        q: query,
        limit: 12,
        lat: widget.lat,
        lng: widget.lng,
        radiusKm: widget.radiusKm,
        minPrice: widget.minPrice,
        maxPrice: widget.maxPrice,
        condition: widget.condition,
      );

      final filtered = _applyLocalDistanceFilter(list);

      final words = <String>[];
      for (final it in filtered) {
        final raw = [
          (it['title'] ?? '').toString(),
          (it['category'] ?? '').toString(),
          (it['brand'] ?? '').toString(),
          (it['condition'] ?? '').toString(),
        ].join(' ');
        for (final w in _tokenizeWords(raw)) {
          final wl = _norm(w);
          if (!wl.startsWith(qLower)) continue;
          if (_isStopWord(wl)) continue;
          if (!words.contains(wl)) {
            words.add(wl);
          }
          if (words.length >= 10) break;
        }
        if (words.length >= 10) break;
      }

      final out = <String>[];
      for (final s in recWords) {
        if (!out.contains(s)) out.add(s);
      }
      for (final s in words) {
        if (!out.contains(s)) out.add(s);
      }
      for (final s in _fallbackMatches(query)) {
        if (!out.contains(s)) out.add(s);
        if (out.length >= 12) break;
      }

      if (!mounted) return;
      setState(() {
        _suggestions = out;
        _suggestLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final qLower = query.toLowerCase();
        final out = <String>[];
        for (final w in _recentMatches(query).expand(_tokenizeWords)) {
          final ww = _norm(w);
          if (ww.startsWith(qLower) && !out.contains(ww)) out.add(ww);
          if (out.length >= 10) break;
        }
        for (final w in _fallbackMatches(query)) {
          if (!out.contains(w)) out.add(w);
          if (out.length >= 12) break;
        }
        _suggestions = out;
        _suggestLoading = false;
      });
    }
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _saveRecent(query);

      final list = await _api.feed(
        q: query,
        limit: 60,
        lat: widget.lat,
        lng: widget.lng,
        radiusKm: widget.radiusKm,
        minPrice: widget.minPrice,
        maxPrice: widget.maxPrice,
        condition: widget.condition,
      );

      final filtered = _applyLocalDistanceFilter(list);

      if (!mounted) return;
      setState(() {
        _items = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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

  Widget _recentRow(String q) {
    return GestureDetector(
      onTap: () {
        _ctrl.text = q;
        _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
        _search(q);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.clock, size: 16, color: CupertinoColors.systemGrey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                q,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(CupertinoIcons.arrow_up_left, size: 16, color: CupertinoColors.systemGrey),
          ],
        ),
      ),
    );
  }

  Widget _suggestionRow(String q) {
    return GestureDetector(
      onTap: () {
        _ctrl.text = q;
        _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
        _search(q);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.search, size: 16, color: CupertinoColors.systemGrey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                q,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(CupertinoIcons.arrow_up_left, size: 16, color: CupertinoColors.systemGrey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    final hasQuery = _ctrl.text.trim().isNotEmpty;
    final showSuggestions = hasQuery && _items.isEmpty && _error == null;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Search')),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: CupertinoSearchTextField(
                controller: _ctrl,
                placeholder: 'Search listings',
                onSubmitted: _search,
                onChanged: _onQueryChanged,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.textStyle.copyWith(
                                color: CupertinoColors.systemGrey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : (!hasQuery && _recent.isNotEmpty)
                          ? ListView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Recent',
                                      style: theme.textTheme.textStyle.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: _clearRecent,
                                      child: const Text(
                                        'Clear',
                                        style: TextStyle(color: CupertinoColors.systemGrey),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ..._recent.map((q) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _recentRow(q),
                                    )),
                              ],
                            )
                          : showSuggestions
                              ? ListView(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Suggestions',
                                          style: theme.textTheme.textStyle.copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (_suggestLoading)
                                          const CupertinoActivityIndicator(radius: 8),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (_suggestions.isEmpty && _ctrl.text.trim().length < 2)
                                      Text(
                                        'Type at least 2 letters',
                                        style: theme.textTheme.textStyle.copyWith(
                                          color: CupertinoColors.systemGrey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    if (_suggestions.isEmpty && !_suggestLoading && _ctrl.text.trim().length >= 2)
                                      Text(
                                        'No suggestions',
                                        style: theme.textTheme.textStyle.copyWith(
                                          color: CupertinoColors.systemGrey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ..._suggestions.map((q) => Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: _suggestionRow(q),
                                        )),
                                  ],
                                )
                          : _items.isEmpty
                              ? Center(
                                  child: Text(
                                    hasQuery ? 'No results' : 'Search for items',
                                    style: theme.textTheme.textStyle.copyWith(
                                      color: CupertinoColors.systemGrey,
                                      fontSize: 13,
                                    ),
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
          ],
        ),
      ),
    );
  }
}
