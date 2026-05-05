import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:super_up/app/core/services/location_service.dart';
import 'package:http/http.dart' as http;
import 'web_places_stub.dart' if (dart.library.html) 'web_places_web.dart'
    as web_places;

class LocationSearchResult {
  final LatLng latLng;
  final String address;
  const LocationSearchResult(this.latLng, this.address);
}

class LocationSearchView extends StatefulWidget {
  final String title;
  final String? initialQuery;
  final bool allowUseCurrentLocation;

  const LocationSearchView({
    super.key,
    this.title = 'Search location',
    this.initialQuery,
    this.allowUseCurrentLocation = true,
  });

  @override
  State<LocationSearchView> createState() => _LocationSearchViewState();
}

class _LocationSearchViewState extends State<LocationSearchView> {
  final TextEditingController _queryCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  List<_Candidate> _results = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _queryCtrl.text = widget.initialQuery!.trim();
      // Fire initial search with a tiny delay to allow first frame
      Future.delayed(const Duration(milliseconds: 10), () => _onSearch());
    }
  }

  Future<void> _selectCandidate(_Candidate c) async {
    if (kIsWeb && c.placeId != null) {
      try {
        setState(() {
          _loading = true;
          _error = null;
        });
        final res = await web_places.placesDetailsRaw(c.placeId!);
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
        if (res != null) {
          final formatted = (res['formatted_address'] ?? c.address).toString();
          final dlat = (res['lat'] as num?)?.toDouble();
          final dlng = (res['lng'] as num?)?.toDouble();
          if (dlat != null && dlng != null) {
            Navigator.of(context)
                .pop(LocationSearchResult(LatLng(dlat, dlng), formatted));
            return;
          }
        }
        // Fallback: return address without geometry
        Navigator.of(context).pop(LocationSearchResult(c.latLng, c.address));
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
        Navigator.of(context).pop(LocationSearchResult(c.latLng, c.address));
      }
    } else {
      Navigator.of(context).pop(LocationSearchResult(c.latLng, c.address));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final pos = await LocationService.instance.getCurrentLocation();
      if (pos == null) {
        setState(() {
          _loading = false;
          _error =
              'Unable to get current location. Please enable location services and permissions.';
        });
        return;
      }
      final placemarks =
          await geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = placemarks.isNotEmpty ? placemarks.first : null;
      final parts = [
        if ((p?.street ?? '').isNotEmpty) p!.street,
        if ((p?.subLocality ?? '').isNotEmpty) p!.subLocality,
        if ((p?.locality ?? '').isNotEmpty) p!.locality,
      ].whereType<String>().toList();
      final address = parts.isNotEmpty
          ? parts.join(', ')
          : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      if (!mounted) return;
      Navigator.of(context).pop(
          LocationSearchResult(LatLng(pos.latitude, pos.longitude), address));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to use current location';
      });
    }
  }

  Future<void> _onSearch() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    if (q.length < 3) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = const [];
        _error = 'Type at least 3 characters';
      });
      return;
    }
    await _searchAutocomplete(q);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    if (q.length < 3) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = 'Type at least 3 characters';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _results = const [];
    });
    _debounce =
        Timer(const Duration(milliseconds: 350), () => _searchAutocomplete(q));
  }

  // Web-only autocomplete via Google Maps JavaScript Places API (predictions-only; resolve lat/lng on select)
  Future<List<_Candidate>> _webPlacesAutocomplete(String q) async {
    try {
      // ignore: avoid_print
      print('[Places] autocomplete start: ' + q);
      final preds = await web_places.placesAutocompleteRaw(q);
      if (preds.isEmpty) {
        // Fallback to text search when autocomplete returns no predictions
        return await _webTextSearch(q);
      }

      final List<_Candidate> out = [];
      for (final p in preds) {
        try {
          final m = p as Map<dynamic, dynamic>;
          final placeId = (m['place_id'] ?? m['placeId'])?.toString();
          final desc = m['description']?.toString();
          if (placeId == null || desc == null || desc.isEmpty) continue;
          out.add(_Candidate(const LatLng(0, 0), desc, placeId: placeId));
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  // Web-only fallback: Places textSearch for free-form queries
  Future<List<_Candidate>> _webTextSearch(String q) async {
    try {
      final res = await web_places.placesTextSearchRaw(q);
      if (res.isEmpty) return const [];
      final out = <_Candidate>[];
      for (final r in res) {
        try {
          final m = r as Map<dynamic, dynamic>;
          final dlat = (m['lat'] as num?)?.toDouble();
          final dlng = (m['lng'] as num?)?.toDouble();
          if (dlat == null || dlng == null) continue;
          final name = (m['name'] ?? '').toString();
          final formatted =
              (m['formatted_address'] ?? m['vicinity'] ?? '').toString();
          final address =
              [name, formatted].where((s) => s.isNotEmpty).join(', ');
          out.add(_Candidate(
              LatLng(dlat, dlng), address.isNotEmpty ? address : formatted));
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _searchAutocomplete(String q) async {
    setState(() {
      _loading = true;
      _error = null;
      _results = const [];
    });
    try {
      if (kIsWeb) {
        // Use Google Places JS API on web to avoid CORS
        final cand = await _webPlacesAutocomplete(q);
        if (!mounted) return;
        setState(() {
          _loading = false;
          _results = cand;
          if (cand.isEmpty) {
            _error = 'No suggestions for "$q"';
          }
        });
        return;
      }
      // Try to bias results near current location via viewbox
      String extra = '';
      try {
        final pos = await LocationService.instance.getCurrentLocation();
        if (pos != null) {
          // Use a wider bias for the current region, but remove strict bounding
          // so the user can search across all of Kenya.
          final left = (pos.longitude - 1.0).toStringAsFixed(6);
          final right = (pos.longitude + 1.0).toStringAsFixed(6);
          final top = (pos.latitude + 1.0).toStringAsFixed(6);
          final bottom = (pos.latitude - 1.0).toStringAsFixed(6);
          extra = '&viewbox=' + left + ',' + top + ',' + right + ',' + bottom;
        }
      } catch (_) {}

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
                '?q=' +
            Uri.encodeQueryComponent(q) +
            '&format=json&addressdetails=1&limit=20&accept-language=en&countrycodes=ke&email=contact@orbit.ke' +
            extra,
      );
      // Avoid custom headers on web to prevent CORS preflight and forbidden headers like User-Agent
      final Map<String, String>? reqHeaders = kIsWeb
          ? null
          : const {'User-Agent': 'OrbitApp/1.0 (+https://orbit.ke)'};
      final resp = await http
          .get(url, headers: reqHeaders)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) throw Exception('status ${resp.statusCode}');
      final data = jsonDecode(resp.body) as List<dynamic>;
      final List<_Candidate> candidates = [];
      for (final item in data) {
        final latStr = item['lat'] as String?;
        final lonStr = item['lon'] as String?;
        final name = (item['display_name'] as String?)?.trim();
        if (latStr == null || lonStr == null || name == null || name.isEmpty)
          continue;
        final lat = double.tryParse(latStr);
        final lon = double.tryParse(lonStr);
        if (lat == null || lon == null) continue;
        candidates.add(_Candidate(LatLng(lat, lon), name));
      }
      if (!mounted) return;
      if (candidates.isEmpty) {
        // Fallback to geocoding if Nominatim returns nothing
        await _searchGeocoding(q);
      } else {
        setState(() {
          _loading = false;
          _results = candidates;
        });
      }
    } catch (e) {
      // Fallback to geocoding if request fails
      await _searchGeocoding(q);
    }
  }

  Future<void> _searchGeocoding(String q) async {
    try {
      final String query = q.toLowerCase().contains('kenya') ? q : '$q, Kenya';
      final locations = await geocoding.locationFromAddress(query);
      final List<_Candidate> candidates = [];
      for (final loc in locations.take(8)) {
        try {
          final placemarks = await geocoding.placemarkFromCoordinates(
              loc.latitude, loc.longitude);
          final p = placemarks.isNotEmpty ? placemarks.first : null;
          final parts = [
            if ((p?.street ?? '').isNotEmpty) p!.street,
            if ((p?.subLocality ?? '').isNotEmpty) p!.subLocality,
            if ((p?.locality ?? '').isNotEmpty) p!.locality,
          ].whereType<String>().toList();
          final address = parts.isNotEmpty
              ? parts.join(', ')
              : '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}';
          candidates
              .add(_Candidate(LatLng(loc.latitude, loc.longitude), address));
        } catch (_) {
          candidates.add(_Candidate(
            LatLng(loc.latitude, loc.longitude),
            '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
          ));
        }
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = candidates;
        if (candidates.isEmpty) {
          _error = 'No suggestions for "$q"';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = const [];
        _error = 'No suggestions for "$q"';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = <Widget>[
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CupertinoSearchTextField(
          controller: _queryCtrl,
          onChanged: _onQueryChanged,
          onSubmitted: (_) => _onSearch(),
          onSuffixTap: () {
            _queryCtrl.clear();
            setState(() {
              _results = const [];
              _error = null;
            });
          },
        ),
      ),
      const SizedBox(height: 8),
      if (_loading) ...[
        const Center(child: CupertinoActivityIndicator()),
        const SizedBox(height: 6),
        const Center(child: Text('Searching...')),
      ],
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      if (!_loading && _results.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text('Results',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        ..._results.map((c) => ListTile(
              leading:
                  const Icon(CupertinoIcons.map_pin, color: Color(0xFFB48648)),
              title:
                  Text(c.address, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => _selectCandidate(c),
            )),
      ],
      const SizedBox(height: 12),
      CupertinoButton.filled(
        onPressed: _onSearch,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: const Text('Search'),
      ),
      if (widget.allowUseCurrentLocation) ...[
        const SizedBox(height: 12),
        CupertinoButton(
          onPressed: _loading ? null : _useCurrentLocation,
          child: const Text('Use Current Location'),
        ),
      ],
    ];

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child:
              const Icon(CupertinoIcons.chevron_back, color: Color(0xFFB48648)),
        ),
      ),
      child: SafeArea(
        top: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
          children: list,
        ),
      ),
    );
  }
}

class _Candidate {
  final LatLng latLng;
  final String address;
  // Web-only: Google Places prediction identifier
  final String? placeId;
  const _Candidate(this.latLng, this.address, {this.placeId});
}
