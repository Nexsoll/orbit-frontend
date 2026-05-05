import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:super_up/app/modules/marketplace/views/marketplace_listing_details_view.dart';
import 'package:super_up_core/super_up_core.dart';

class MarketplaceMapPreviewView extends StatefulWidget {
  final List<Map<String, dynamic>> listings;
  final double? centerLat;
  final double? centerLng;

  const MarketplaceMapPreviewView({
    super.key,
    required this.listings,
    this.centerLat,
    this.centerLng,
  });

  @override
  State<MarketplaceMapPreviewView> createState() => _MarketplaceMapPreviewViewState();
}

class _MarketplaceMapPreviewViewState extends State<MarketplaceMapPreviewView> {
  GoogleMapController? _map;
  late final List<Map<String, dynamic>> _mappable;
  final Map<String, BitmapDescriptor> _iconCache = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _mappable = widget.listings.where((it) {
      final lat = (it['locationLat'] as num?)?.toDouble();
      final lng = (it['locationLng'] as num?)?.toDouble();
      return lat != null && lng != null;
    }).toList();

    unawaited(_buildMarkers());
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
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

  String _normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http')) return trimmed;
    if (trimmed.startsWith('/')) return SConstants.baseMediaUrl + trimmed;
    return SConstants.baseMediaUrl + '/media/' + trimmed;
  }

  Future<BitmapDescriptor?> _circleMarkerFromUrl(String url) async {
    final u = _normalizeUrl(url);
    if (u.isEmpty) return null;

    final cached = _iconCache[u];
    if (cached != null) return cached;

    try {
      final res = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final bytes = res.bodyBytes;

      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 120,
        targetHeight: 120,
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 120.0;

      final rrect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, size, size),
        const Radius.circular(size / 2),
      );
      canvas.clipRRect(rrect);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        const Rect.fromLTWH(0, 0, size, size),
        Paint(),
      );

      // Add a subtle border
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFB48648)
        ..strokeWidth = 6;
      canvas.drawRRect(rrect, borderPaint);

      final picture = recorder.endRecording();
      final outImage = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final outBytes = byteData.buffer.asUint8List();
      final icon = BitmapDescriptor.fromBytes(outBytes);
      _iconCache[u] = icon;
      return icon;
    } catch (_) {
      return null;
    }
  }

  Future<void> _buildMarkers() async {
    final out = <Marker>{};

    for (final it in _mappable) {
      final id = (it['_id'] ?? it['id']).toString();
      final lat = (it['locationLat'] as num).toDouble();
      final lng = (it['locationLng'] as num).toDouble();
      final title = (it['title'] ?? '').toString();
      final price = (it['price'] as num?)?.toInt();
      final imgUrl = _firstImageUrl(it);

      final icon = imgUrl == null ? null : await _circleMarkerFromUrl(imgUrl);

      out.add(
        Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lng),
          icon: icon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: title.isEmpty ? 'Listing' : title,
            snippet: price == null ? null : 'KES $price',
          ),
          onTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => MarketplaceListingDetailsView(listing: it),
              ),
            );
          },
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _markers = out;
    });
  }

  void _fitBoundsIfPossible() {
    final map = _map;
    if (map == null) return;
    if (_mappable.isEmpty) return;

    double? minLat;
    double? maxLat;
    double? minLng;
    double? maxLng;

    for (final it in _mappable) {
      final lat = (it['locationLat'] as num?)?.toDouble();
      final lng = (it['locationLng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      minLat = minLat == null ? lat : (lat < minLat ? lat : minLat);
      maxLat = maxLat == null ? lat : (lat > maxLat ? lat : maxLat);
      minLng = minLng == null ? lng : (lng < minLng ? lng : minLng);
      maxLng = maxLng == null ? lng : (lng > maxLng ? lng : maxLng);
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) return;

    if ((minLat - maxLat).abs() < 1e-6 && (minLng - maxLng).abs() < 1e-6) {
      map.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(minLat, minLng), zoom: 14),
        ),
      );
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    map.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
  }

  @override
  Widget build(BuildContext context) {
    final center = (widget.centerLat != null && widget.centerLng != null)
        ? LatLng(widget.centerLat!, widget.centerLng!)
        : (_mappable.isNotEmpty
            ? LatLng(
                (_mappable.first['locationLat'] as num).toDouble(),
                (_mappable.first['locationLng'] as num).toDouble(),
              )
            : const LatLng(0, 0));

    if (_mappable.isEmpty) {
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('Map preview')),
        child: SafeArea(
          child: Center(child: Text('No listings with location to show on map')),
        ),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Map preview')),
      child: SafeArea(
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 12),
          markers: _markers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (c) {
            _map = c;
            WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoundsIfPossible());
          },
        ),
      ),
    );
  }
}
