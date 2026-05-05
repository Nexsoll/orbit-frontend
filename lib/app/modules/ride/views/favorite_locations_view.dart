import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:super_up/app/core/services/favorites_service.dart';
import 'package:super_up/app/modules/ride/views/location_search_view.dart';

class FavoriteLocationsView extends StatefulWidget {
  const FavoriteLocationsView({super.key});

  @override
  State<FavoriteLocationsView> createState() => _FavoriteLocationsViewState();
}

class _FavoriteLocationsViewState extends State<FavoriteLocationsView> {
  List<FavoriteLocation> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await FavoritesService.instance.getAll();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _add() async {
    // 1) Pick a map location using the existing search flow
    final picked = await Navigator.push<LocationSearchResult>(
      context,
      CupertinoPageRoute(builder: (_) => const LocationSearchView(title: 'Add favourite')),
    );
    if (!mounted || picked == null) return;

    // 2) Ask for a friendly name
    final nameCtrl = TextEditingController();
    String? name = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text('Name your favourite'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: CupertinoTextField(
              controller: nameCtrl,
              placeholder: 'e.g. Home, Work, Gym',
            ),
          ),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (!mounted || name == null) return;

    final fav = FavoriteLocation(
      id: 'fav_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      address: picked.address,
      lat: picked.latLng.latitude,
      lng: picked.latLng.longitude,
    );
    await FavoritesService.instance.add(fav);
    await _load();
  }

  Future<void> _rename(FavoriteLocation fav) async {
    final ctrl = TextEditingController(text: fav.name);
    final newName = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text('Rename favourite'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: CupertinoTextField(controller: ctrl),
          ),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (newName == null) return;
    await FavoritesService.instance.rename(fav.id, newName);
    await _load();
  }

  Future<void> _delete(FavoriteLocation fav) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text('Remove favourite?'),
          content: Text('"${fav.name}" will be removed'),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
          ],
        );
      },
    );
    if (ok != true) return;
    await FavoritesService.instance.remove(fav.id);
    await _load();
  }

  void _select(FavoriteLocation fav) {
    Navigator.of(context).pop(LocationSearchResult(LatLng(fav.lat, fav.lng), fav.address));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Favourite locations'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _add,
          child: const Icon(CupertinoIcons.add, color: Color(0xFFB48648)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView.builder(
                itemCount: _items.length,
                itemBuilder: (ctx, i) {
                  final fav = _items[i];
                  return ListTile(
                    leading: const Icon(CupertinoIcons.placemark, color: Color(0xFFB48648)),
                    title: Text(fav.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(fav.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => _select(fav),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          onPressed: () => _rename(fav),
                          child: const Icon(CupertinoIcons.pencil, size: 20),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          onPressed: () => _delete(fav),
                          child: const Icon(CupertinoIcons.delete, size: 20, color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
