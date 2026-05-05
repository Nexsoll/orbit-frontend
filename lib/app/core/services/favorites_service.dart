import 'dart:convert';

import 'package:super_up_core/super_up_core.dart';

class FavoriteLocation {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;

  const FavoriteLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
      };

  factory FavoriteLocation.fromJson(Map<String, dynamic> m) => FavoriteLocation(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        address: (m['address'] ?? '').toString(),
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
      );
}

class FavoritesService {
  FavoritesService._();
  static final FavoritesService instance = FavoritesService._();

  String _keyFor(String userId) => 'favorite_locations_$userId';

  Future<List<FavoriteLocation>> getAll() async {
    final uid = AppAuth.myProfile.baseUser.id;
    final key = _keyFor(uid);
    final list = VAppPref.getList(key);
    if (list == null || list.isEmpty) return const [];
    final out = <FavoriteLocation>[];
    for (final item in list) {
      try {
        if (item is String) {
          final map = jsonDecode(item) as Map<String, dynamic>;
          out.add(FavoriteLocation.fromJson(map));
        } else if (item is Map) {
          out.add(FavoriteLocation.fromJson((item as Map).cast<String, dynamic>()));
        }
      } catch (_) {}
    }
    return out;
  }

  Future<void> _saveAll(List<FavoriteLocation> items) async {
    final uid = AppAuth.myProfile.baseUser.id;
    final key = _keyFor(uid);
    final list = items.map((e) => jsonEncode(e.toJson())).toList();
    await VAppPref.setList(key, list);
  }

  Future<void> add(FavoriteLocation fav) async {
    final all = await getAll();
    final next = [...all, fav];
    await _saveAll(next);
  }

  Future<void> remove(String id) async {
    final all = await getAll();
    final next = all.where((e) => e.id != id).toList();
    await _saveAll(next);
  }

  Future<void> rename(String id, String newName) async {
    final all = await getAll();
    final next = all
        .map((e) => e.id == id
            ? FavoriteLocation(id: e.id, name: newName, address: e.address, lat: e.lat, lng: e.lng)
            : e)
        .toList();
    await _saveAll(next);
  }
}
