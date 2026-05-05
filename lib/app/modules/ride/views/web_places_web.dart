// ignore_for_file: avoid_web_libraries_in_flutter, uri_does_not_exist
import 'dart:async';
import 'dart:js_util' as js_util;
import 'package:universal_html/html.dart' as html;

Future<List<dynamic>> placesAutocompleteRaw(String q) async {
  try {
    final google = js_util.getProperty(html.window, 'google');
    if (google == null) return const [];
    final maps = js_util.getProperty(google, 'maps');
    if (maps == null) return const [];
    final places = js_util.getProperty(maps, 'places');
    if (places == null) return const [];

    final service = js_util.callConstructor(
      js_util.getProperty(places, 'AutocompleteService'),
      const [],
    );
    final completer = Completer<List<dynamic>>();
    final req = js_util.jsify({
      'input': q,
      'componentRestrictions': {'country': 'ke'}
    });
    js_util.callMethod(service, 'getPlacePredictions', [
      req,
      js_util.allowInterop((predictions, status) {
        try {
          final list = js_util.dartify(predictions) as List<dynamic>?;
          // Normalize minimal fields
          final out = <Map<String, dynamic>>[];
          for (final p in (list ?? const [])) {
            try {
              final m = p as Map<dynamic, dynamic>;
              final placeId = (m['place_id'] ?? m['placeId'])?.toString();
              final desc = m['description']?.toString();
              if (placeId != null && (desc != null && desc.isNotEmpty)) {
                out.add({'place_id': placeId, 'description': desc});
              }
            } catch (_) {}
          }
          completer.complete(out);
        } catch (_) {
          completer.complete(const []);
        }
      })
    ]);
    return await completer.future;
  } catch (_) {
    return const [];
  }
}

Future<List<dynamic>> placesTextSearchRaw(String q) async {
  try {
    final google = js_util.getProperty(html.window, 'google');
    if (google == null) return const [];
    final maps = js_util.getProperty(google, 'maps');
    if (maps == null) return const [];
    final places = js_util.getProperty(maps, 'places');
    if (places == null) return const [];

    final placesService = js_util.callConstructor(
      js_util.getProperty(places, 'PlacesService'),
      [html.document.createElement('div')],
    );

    final completer = Completer<List<dynamic>>();
    final req = js_util.jsify({
      'query': q,
      'location': js_util.callConstructor(
        js_util.getProperty(maps, 'LatLng'),
        [-1.286389, 36.817223], // Nairobi as center for bias
      ),
      'radius': 500000, // 500km to cover most of Kenya population centers
    });
    js_util.callMethod(placesService, 'textSearch', [
      req,
      js_util.allowInterop((results, status) {
        try {
          final list = js_util.dartify(results) as List<dynamic>?;
          final out = <Map<String, dynamic>>[];
          for (final r in (list ?? const [])) {
            try {
              final m = r as Map<dynamic, dynamic>;
              final geom = m['geometry'] as Map<dynamic, dynamic>?;
              final loc = geom != null ? geom['location'] : null;
              if (loc != null) {
                final lat = js_util.callMethod(loc, 'lat', const []);
                final lng = js_util.callMethod(loc, 'lng', const []);
                final dlat = (lat is num)
                    ? lat.toDouble()
                    : double.tryParse(lat.toString());
                final dlng = (lng is num)
                    ? lng.toDouble()
                    : double.tryParse(lng.toString());
                if (dlat != null && dlng != null) {
                  out.add({
                    'lat': dlat,
                    'lng': dlng,
                    'name': (m['name'] ?? '').toString(),
                    'formatted_address':
                        (m['formatted_address'] ?? '').toString(),
                    'vicinity': (m['vicinity'] ?? '').toString(),
                  });
                }
              }
            } catch (_) {}
          }
          completer.complete(out);
        } catch (_) {
          completer.complete(const []);
        }
      })
    ]);

    return await completer.future;
  } catch (_) {
    return const [];
  }
}

Future<Map<String, dynamic>?> placesDetailsRaw(String placeId) async {
  try {
    final google = js_util.getProperty(html.window, 'google');
    if (google == null) return null;
    final maps = js_util.getProperty(google, 'maps');
    if (maps == null) return null;
    final places = js_util.getProperty(maps, 'places');
    if (places == null) return null;

    final placesService = js_util.callConstructor(
      js_util.getProperty(places, 'PlacesService'),
      [html.document.createElement('div')],
    );

    final comp = Completer<Map<String, dynamic>?>();
    final dreq = js_util.jsify({
      'placeId': placeId,
      'fields': ['formatted_address', 'geometry']
    });
    js_util.callMethod(placesService, 'getDetails', [
      dreq,
      js_util.allowInterop((result, status) {
        try {
          final res = result == null
              ? null
              : js_util.dartify(result) as Map<dynamic, dynamic>?;
          if (res == null) {
            comp.complete(null);
            return;
          }
          final formatted = (res['formatted_address'] ?? '').toString();
          final geometry = res['geometry'] as Map<dynamic, dynamic>?;
          final location = geometry != null ? geometry['location'] : null;
          if (location != null) {
            final lat = js_util.callMethod(location, 'lat', const []);
            final lng = js_util.callMethod(location, 'lng', const []);
            final dlat =
                (lat is num) ? lat.toDouble() : double.tryParse(lat.toString());
            final dlng =
                (lng is num) ? lng.toDouble() : double.tryParse(lng.toString());
            if (dlat != null && dlng != null) {
              comp.complete(
                  {'formatted_address': formatted, 'lat': dlat, 'lng': dlng});
              return;
            }
          }
          comp.complete({'formatted_address': formatted});
        } catch (_) {
          comp.complete(null);
        }
      })
    ]);

    return await comp.future;
  } catch (_) {
    return null;
  }
}
