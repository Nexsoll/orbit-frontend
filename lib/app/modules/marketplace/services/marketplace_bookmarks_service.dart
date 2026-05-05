import 'dart:convert';

import 'package:super_up_core/super_up_core.dart';

class MarketplaceBookmarksService {
  MarketplaceBookmarksService._();
  static final MarketplaceBookmarksService instance = MarketplaceBookmarksService._();

  String _keyFor(String userId) => 'marketplace_bookmarks_$userId';

  String? _myUserIdOrNull() {
    try {
      return AppAuth.myProfile.baseUser.id;
    } catch (_) {
      return null;
    }
  }

  String _idOf(Map<String, dynamic> listing) {
    return (listing['_id'] ?? listing['id'] ?? '').toString();
  }

  Map<String, dynamic> _minify(Map<String, dynamic> listing) {
    final media = listing['media'];
    final outMedia = <Map<String, dynamic>>[];
    if (media is List) {
      for (final m in media) {
        if (m is Map) {
          final url = (m['url'] ?? '').toString();
          final type = (m['type'] ?? '').toString();
          if (url.isNotEmpty && type.isNotEmpty) {
            outMedia.add({'url': url, 'type': type});
          }
          if (outMedia.length >= 3) break;
        }
      }
    }

    return {
      '_id': _idOf(listing),
      'title': listing['title'],
      'price': listing['price'],
      'priceType': listing['priceType'],
      'category': listing['category'],
      'brand': listing['brand'],
      'condition': listing['condition'],
      'locationLabel': listing['locationLabel'],
      'locationLat': listing['locationLat'],
      'locationLng': listing['locationLng'],
      'media': outMedia,
      'userId': listing['userId'],
    };
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final uid = _myUserIdOrNull();
    if (uid == null || uid.isEmpty) return const [];
    final key = _keyFor(uid);
    final list = VAppPref.getList(key);
    if (list == null || list.isEmpty) return const [];

    final out = <Map<String, dynamic>>[];
    for (final item in list) {
      try {
        final map = jsonDecode(item.toString()) as Map<String, dynamic>;
        out.add(Map<String, dynamic>.from(map));
      } catch (_) {}
    }
    return out;
  }

  Future<bool> isBookmarked(String listingId) async {
    if (listingId.trim().isEmpty) return false;
    final all = await getAll();
    return all.any((e) => _idOf(e) == listingId);
  }

  Future<void> add(Map<String, dynamic> listing) async {
    final uid = _myUserIdOrNull();
    if (uid == null || uid.isEmpty) return;
    final key = _keyFor(uid);

    final id = _idOf(listing);
    if (id.isEmpty) return;

    final all = await getAll();
    if (all.any((e) => _idOf(e) == id)) return;

    final next = [...all, _minify(listing)];
    final serialized = next.map((e) => jsonEncode(e)).toList();
    await VAppPref.setList(key, serialized);
  }

  Future<void> remove(String listingId) async {
    final uid = _myUserIdOrNull();
    if (uid == null || uid.isEmpty) return;
    final key = _keyFor(uid);

    final all = await getAll();
    final next = all.where((e) => _idOf(e) != listingId).toList();
    final serialized = next.map((e) => jsonEncode(e)).toList();
    await VAppPref.setList(key, serialized);
  }

  Future<bool> toggle(Map<String, dynamic> listing) async {
    final id = _idOf(listing);
    if (id.isEmpty) return false;

    final bookmarked = await isBookmarked(id);
    if (bookmarked) {
      await remove(id);
      return false;
    }

    await add(listing);
    return true;
  }
}
