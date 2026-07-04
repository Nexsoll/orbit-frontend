import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:super_up/app/core/services/location_service.dart';
import 'package:super_up/app/modules/ride/views/location_search_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;
import 'package:super_up/app/widgets/balance_widget.dart';
import 'package:super_up/app/modules/ride/views/become_driver_view.dart';
import 'package:super_up/app/core/api_service/drivers/drivers_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:super_up/app/modules/driver/views/driver_dashboard_view.dart';
import 'package:super_up/app/core/services/ride_mode_service.dart';
import 'package:super_up/app/modules/ride/views/ride_history_view.dart';
import 'package:super_up/app/modules/ride/views/ride_tracking_view.dart';
import 'package:super_up/app/modules/ride/views/scheduled_rides_view.dart';
import 'package:super_up/app/modules/ride/views/favorite_locations_view.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class OrbitRideView extends StatefulWidget {
  final LatLng? prefillDropoff;
  final String? prefillDropoffAddress;
  const OrbitRideView(
      {super.key, this.prefillDropoff, this.prefillDropoffAddress});

  @override
  State<OrbitRideView> createState() => _OrbitRideViewState();
}

class _OrbitRideViewState extends State<OrbitRideView> {
  GoogleMapController? _mapController;
  Position? _position;
  bool _loading = true;
  String? _error;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  String? _currentAddress;
  LatLng? _pickupLatLng;
  String? _pickupAddress;
  LatLng? _dropoffLatLng;
  LatLng? _pendingPrefillDropoff;
  String? _pendingPrefillAddress;
  double? _routeDistanceKm;
  double? _routeDurationMin;
  double? _suggestedFareKes;
  bool _becomeDisabled = false;
  bool _isDriverMode =
      false; // Drawer toggle: false = Passenger (default), true = Driver

  // Finding driver state
  bool _isFindingDriver = false;
  bool _findingDriverSocketBound = false;
  String? _currentRequestId;

  final TextEditingController _dropoffCtrl = TextEditingController();
  final TextEditingController _fareCtrl = TextEditingController();
  int _selectedRide = 0;
  // Draggable bottom sheet offset (distance from bottom in px)
  double _sheetLift = 0.0;
  static const double _sheetLiftMax = 300.0;
  bool _isEndDrawerOpen = false;

  RideGroup _selectedGroup = RideGroup.cars;
  final List<_RideOption> _carsOptions = const [
    _RideOption(
        title: 'Orbit Comfort', icon: CupertinoIcons.car_detailed, count: 4),
    _RideOption(title: 'OrbitX', icon: CupertinoIcons.car, count: 6),
    _RideOption(title: 'OrbitXL', icon: Icons.airport_shuttle, count: 3),
    _RideOption(title: 'OrbitGreen', icon: Icons.ev_station, count: 5),
    _RideOption(
        title: 'Women only', icon: CupertinoIcons.person_fill, count: 2),
    _RideOption(title: 'Orbit Share', icon: Icons.group, count: 7),
    _RideOption(title: 'Orbit Vans', icon: Icons.airport_shuttle, count: 2),
  ];

  // Payment method: 'cash' or 'online' (default cash)
  String _paymentMethod = 'cash';
  DateTime? _scheduledAt;
  int _passengersCount = 1;

  // Ratings summary (for current user)
  double? _myRatingAvg;
  int? _myRatingCount;

  Future<void> _loadMyRatingSummary() async {
    try {
      final s = await DriversApiService.myRatingSummary();
      if (!mounted) return;
      setState(() {
        _myRatingAvg = (s['avg'] as num?)?.toDouble();
        _myRatingCount = (s['count'] as num?)?.toInt();
      });
    } catch (_) {}
  }

  Future<void> _openFavoritesPicker() async {
    final res = await Navigator.of(context).push<LocationSearchResult>(
      CupertinoPageRoute(builder: (_) => const FavoriteLocationsView()),
    );
    if (res == null || !mounted) return;
    setState(() {
      _dropoffLatLng = res.latLng;
      _dropoffCtrl.text = res.address;
      _updateMarkers();
    });
    await _updateRoutePolylineIfReady();
    await _fitCameraToPoints();
  }

  Future<void> _applyPrefillDropoff() async {
    if (_pendingPrefillDropoff == null) return;
    setState(() {
      _dropoffLatLng = _pendingPrefillDropoff;
      _dropoffCtrl.text = _pendingPrefillAddress ?? '';
      _updateMarkers();
    });
    await _updateRoutePolylineIfReady();
    await _fitCameraToPoints();
  }

  Future<void> _onScheduleRide() async {
    if (_pickupLatLng == null || _dropoffLatLng == null) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Please select pickup and destination',
      );
      return;
    }
    if (_scheduledAt == null) {
      await _pickScheduleTime();
      if (_scheduledAt == null) return;
    }
    final min = DateTime.now().add(const Duration(minutes: 5));
    if (_scheduledAt!.isBefore(min)) {
      VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Schedule must be at least 5 minutes from now');
      return;
    }
    await _recomputeFareIfPossible();
    final fare = _suggestedFareKes ?? double.tryParse(_fareCtrl.text) ?? 0.0;
    try {
      await DriversApiService.scheduleRide(
        pickupAddress: (_pickupAddress ?? _currentAddress) ?? 'Pickup',
        dropoffAddress:
            _dropoffCtrl.text.isNotEmpty ? _dropoffCtrl.text : 'Destination',
        pickupLat: _pickupLatLng!.latitude,
        pickupLng: _pickupLatLng!.longitude,
        dropoffLat: _dropoffLatLng!.latitude,
        dropoffLng: _dropoffLatLng!.longitude,
        fareKes: fare,
        rideType: _currentRideTitle(),
        paymentMethod: _paymentMethod,
        passengersCount: _passengersCount,
        scheduledAtIso: _scheduledAt!.toUtc().toIso8601String(),
      );
      if (!mounted) return;
      VAppAlert.showSuccessSnackBar(
          context: context, message: 'Ride scheduled');
    } catch (_) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(
          context: context, message: 'Failed to schedule ride');
    }
  }

  Future<void> _pickScheduleTime() async {
    DateTime temp = DateTime.now().add(const Duration(minutes: 15));
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Pick Date & Time'),
        message: SizedBox(
          height: 220,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.dateAndTime,
            minimumDate: DateTime.now().add(const Duration(minutes: 5)),
            initialDateTime: _scheduledAt ?? temp,
            use24hFormat: true,
            onDateTimeChanged: (v) => temp = v,
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _scheduledAt = temp);
            },
            child: const Text('Set'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _pickPaymentMethod() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Payment Method'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _paymentMethod = 'cash');
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.account_balance_wallet,
                    color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('Cash'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _paymentMethod = 'online');
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(CupertinoIcons.creditcard, color: Color(0xFF3B82F6)),
                SizedBox(width: 8),
                Text('Orbit Money'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  final List<_RideOption> _motorbikeOptions = const [
    _RideOption(title: 'Orbit Motorbikes', icon: Icons.two_wheeler, count: 12),
    _RideOption(title: 'Orbit Electric', icon: Icons.electric_bike, count: 5),
    _RideOption(title: 'Orbit Send', icon: Icons.local_shipping, count: 6),
    _RideOption(title: 'Orbit Food', icon: Icons.fastfood, count: 9),
  ];

  Future<void> _refreshDriverApplicationStatus() async {
    try {
      final latest = await DriversApiService.myLatest();
      if (!mounted) return;
      final status = latest?['status']?.toString().toLowerCase();
      if (status == 'approved') {
        setState(() => _becomeDisabled = true);
      }
    } catch (_) {}
  }

  void _onRideSelected(int i) {
    setState(() => _selectedRide = i);
    _recomputeFareIfPossible();
  }

  String _currentRideTitle() {
    final list =
        _selectedGroup == RideGroup.cars ? _carsOptions : _motorbikeOptions;
    if (_selectedRide < 0 || _selectedRide >= list.length) return 'Ride';
    return list[_selectedRide].title;
  }

  Future<void> _recomputeFareIfPossible() async {
    if (_pickupLatLng == null || _dropoffLatLng == null) return;
    if (_routeDistanceKm == null) return; // wait until route loaded
    final fare = await _computeSuggestedFare();
    if (!mounted) return;
    setState(() {
      _suggestedFareKes = fare;
      _fareCtrl.text = fare.toStringAsFixed(0);
    });
  }

  Future<double> _computeSuggestedFare() async {
    final title = _currentRideTitle();
    final isBike = _selectedGroup == RideGroup.motorbikes;

    // Base fare by group, and global per-km rate from constants
    double base = isBike ? 60 : 150; // KES
    double perKm =
        SConstants.ridePerKmKes; // unified distance fare (KES per km)
    double minFare = isBike ? 100.0 : 200.0;

    // Map specific titles
    final t = title.toLowerCase();
    if (t.contains('xl') || t.contains('vans')) {
      base = 200;
    } else if (t.contains('economy')) {
      base = 120;
    } else if (t.contains('x')) {
      base = 160;
    } else if (t.contains('share')) {
      base = 100;
    } else if (t.contains('green')) {
      base = 140;
    } else if (t.contains('women')) {
      base = 150;
    }
    // bikes
    if (isBike) {
      if (t.contains('electric')) {
        base = 50;
        minFare = 80;
      } else if (t.contains('send')) {
        base = 80;
        minFare = 130;
      } else if (t.contains('food')) {
        base = 70;
        minFare = 120;
      } else {
        base = 60;
        minFare = 100;
      }
    }

    final distanceKm = _routeDistanceKm ?? 0;
    double price = base + perKm * distanceKm;

    // Capacity factor (approx based on title)
    double capacityFactor = 1.0;
    if (t.contains('xl') || t.contains('vans')) capacityFactor = 1.20;

    // Fuel factor (electric cheaper)
    double fuelFactor =
        (t.contains('green') || t.contains('electric')) ? 0.90 : 1.00;

    // Time-of-day factor
    final now = DateTime.now();
    final hour = now.hour;
    double timeFactor = 1.0;
    if (hour >= 21 || hour < 5)
      timeFactor = 1.20; // night
    else if ((hour >= 7 && hour < 9) || (hour >= 17 && hour < 19))
      timeFactor = 1.10; // peak

    // Weather factor
    double weatherFactor = await _getWeatherFactor(_pickupLatLng!);

    // Road condition factor based on average speed
    double roadFactor = 1.0;
    if (distanceKm > 0 && (_routeDurationMin ?? 0) > 0) {
      final avgSpeed = distanceKm / ((_routeDurationMin!) / 60.0); // km/h
      if (avgSpeed < 20)
        roadFactor = 1.25;
      else if (avgSpeed < 30) roadFactor = 1.10;
    }

    price = price *
        capacityFactor *
        fuelFactor *
        timeFactor *
        weatherFactor *
        roadFactor;

    // Minimum fares
    if (price < minFare) price = minFare;

    // Round to nearest 10 KES
    price = (price / 10.0).round() * 10.0;
    return price;
  }

  Future<double> _getWeatherFactor(LatLng at) async {
    try {
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude='
          '${at.latitude.toStringAsFixed(5)}&longitude=${at.longitude.toStringAsFixed(5)}&current=precipitation,weather_code,wind_speed_10m');
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        final cur = d['current'] as Map<String, dynamic>?;
        final precip = (cur?['precipitation'] as num?)?.toDouble() ?? 0.0;
        final code = (cur?['weather_code'] as num?)?.toInt() ?? 0;
        final windy = (cur?['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
        bool bad = precip > 0.1 || windy > 30 || _isBadWeatherCode(code);
        return bad ? 1.25 : 1.0;
      }
    } catch (_) {}
    return 1.0;
  }

  bool _isBadWeatherCode(int code) {
    // Open-Meteo weather codes: treat rain/snow/thunderstorm as bad
    if (code >= 51 && code <= 67) return true; // drizzle/rain
    if (code >= 71 && code <= 77) return true; // snow
    if (code >= 80 && code <= 82) return true; // rain showers
    if (code >= 95) return true; // thunder
    return false;
  }

  /// Try reverse geocoding without the platform plugin (useful on web)
  Future<String?> _reverseGeocodeFallback(LatLng at) async {
    // 1) Try OpenStreetMap Nominatim (no key)
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=${at.latitude}&lon=${at.longitude}&addressdetails=1&zoom=18&accept-language=en',
      );
      final r = await http.get(
        uri,
        headers: {'User-Agent': 'OrbitApp/1.0 (reverse-geocode)'},
      ).timeout(const Duration(seconds: 6));
      if (r.statusCode == 200 && r.body.isNotEmpty) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        final addr = d['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final formatted = _formatNominatimAddress(addr);
          if (formatted != null && formatted.isNotEmpty) return formatted;
        }
        final display = d['display_name'] as String?;
        if (display != null && display.isNotEmpty) return display;
      }
    } catch (_) {}

    // 2) Try Google Geocoding HTTP API using our key (may require enabling Geocoding API)
    try {
      final key = SConstants.googleMapsApiKey;
      if (key.isNotEmpty) {
        final gUri = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng='
          '${at.latitude},${at.longitude}&key=$key',
        );
        final gr = await http.get(gUri).timeout(const Duration(seconds: 6));
        if (gr.statusCode == 200 && gr.body.isNotEmpty) {
          final gd = jsonDecode(gr.body) as Map<String, dynamic>;
          final results = gd['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            final first = results.first as Map<String, dynamic>;
            final fa = first['formatted_address'] as String?;
            if (fa != null && fa.isNotEmpty) return fa;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  String? _formatNominatimAddress(Map<String, dynamic> a) {
    final house = (a['house_number'] as String?)?.trim();
    final road =
        ((a['road'] ?? a['residential'] ?? a['pedestrian']) as String?)?.trim();
    final suburb = ((a['suburb'] ?? a['neighbourhood']) as String?)?.trim();
    final city = ((a['city'] ?? a['town'] ?? a['village']) as String?)?.trim();
    final state = (a['state'] as String?)?.trim();
    final postcode = (a['postcode'] as String?)?.trim();

    final parts = <String>[];
    final street = [
      if (house != null && house.isNotEmpty) house,
      if (road != null && road.isNotEmpty) road
    ].where((e) => e.isNotEmpty).join(' ').trim();
    if (street.isNotEmpty) parts.add(street);
    if (suburb != null && suburb.isNotEmpty) parts.add(suburb);
    if (city != null && city.isNotEmpty) parts.add(city);
    final tail = [
      if (state != null && state.isNotEmpty) state,
      if (postcode != null && postcode.isNotEmpty) postcode
    ].where((e) => e.isNotEmpty).join(' ').trim();
    if (tail.isNotEmpty) parts.add(tail);

    return parts.isEmpty ? null : parts.join(', ');
  }

  Future<void> _openLocationPicker({required bool isPickup}) async {
    final res = await Navigator.push<LocationSearchResult>(
      context,
      CupertinoPageRoute(
        builder: (_) => LocationSearchView(
          title: isPickup ? 'Pick-up location' : 'Drop-off location',
          initialQuery: isPickup ? _pickupAddress : _dropoffCtrl.text,
        ),
      ),
    );
    if (!mounted || res == null) return;
    setState(() {
      if (isPickup) {
        _pickupLatLng = res.latLng;
        _pickupAddress = res.address;
      } else {
        _dropoffLatLng = res.latLng;
        _dropoffCtrl.text = res.address;
      }
      _updateMarkers();
    });
    await _updateRoutePolylineIfReady();
    await _fitCameraToPoints();
  }

  void _updateMarkers() {
    final Set<Marker> next = {};
    if (_pickupLatLng != null) {
      next.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng!,
        infoWindow: const InfoWindow(title: 'Pickup'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    if (_dropoffLatLng != null) {
      next.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffLatLng!,
        infoWindow: const InfoWindow(title: 'Drop-off'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    setState(() {
      _markers
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _updateRoutePolylineIfReady() async {
    // Support route from current position -> pickup when dropoff is not set yet
    LatLng? a;
    LatLng? b;
    if (_pickupLatLng != null && _dropoffLatLng != null) {
      a = _pickupLatLng!;
      b = _dropoffLatLng!;
    } else if (_pickupLatLng != null && _position != null) {
      a = LatLng(_position!.latitude, _position!.longitude);
      b = _pickupLatLng!;
    } else {
      setState(() => _polylines.clear());
      return;
    }
    try {
      final pts = await _fetchRoutePolyline(a, b);
      if (!mounted) return;
      if (pts.isEmpty) {
        setState(() => _polylines.clear());
        return;
      }
      setState(() {
        _polylines
          ..clear()
          ..add(Polyline(
            polylineId: const PolylineId('route'),
            color: Colors.blue,
            width: 5,
            points: pts,
          ));
      });
      await _recomputeFareIfPossible();
    } catch (_) {
      if (!mounted) return;
      setState(() => _polylines.clear());
    }
  }

  Future<List<LatLng>> _fetchRoutePolyline(LatLng from, LatLng to) async {
    // Web-first: use Google Directions Web Service if API key is available
    if (kIsWeb) {
      final key = SConstants.googleMapsApiKey;
      if (key.isNotEmpty) {
        try {
          final gUri = Uri.parse(
            'https://maps.googleapis.com/maps/api/directions/json'
                    '?origin=${from.latitude},${from.longitude}'
                    '&destination=${to.latitude},${to.longitude}'
                    '&mode=driving&key=' +
                key,
          );
          final gr = await http.get(gUri).timeout(const Duration(seconds: 10));
          if (gr.statusCode == 200 && gr.body.isNotEmpty) {
            final gd = jsonDecode(gr.body) as Map<String, dynamic>;
            final routes = gd['routes'] as List<dynamic>?;
            if (routes != null && routes.isNotEmpty) {
              final first = routes.first as Map<String, dynamic>;
              final overview =
                  first['overview_polyline'] as Map<String, dynamic>?;
              final points =
                  overview != null ? overview['points']?.toString() : null;
              final legs = first['legs'] as List<dynamic>?;
              final leg = (legs != null && legs.isNotEmpty)
                  ? legs.first as Map<String, dynamic>
                  : null;
              final distVal =
                  (leg?['distance'] as Map<String, dynamic>?)?['value'] as num?;
              final durVal =
                  (leg?['duration'] as Map<String, dynamic>?)?['value'] as num?;
              if (distVal != null || durVal != null) {
                setState(() {
                  _routeDistanceKm =
                      distVal != null ? (distVal.toDouble() / 1000.0) : null;
                  _routeDurationMin =
                      durVal != null ? (durVal.toDouble() / 60.0) : null;
                });
              }
              if (points != null && points.isNotEmpty) {
                return _decodePolyline(points);
              }
            }
          }
        } catch (_) {}
      }
    }

    // Otherwise, use OSRM (GeoJSON geometry)
    // Prefer GeoJSON geometry to avoid precision/order pitfalls on web
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );
    final resp = await http.get(url).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return const [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return const [];
    final first = routes.first as Map<String, dynamic>;
    final geometry = first['geometry'];
    final distanceM = (first['distance'] as num?)?.toDouble();
    final durationS = (first['duration'] as num?)?.toDouble();
    if (distanceM != null || durationS != null) {
      setState(() {
        _routeDistanceKm = distanceM != null ? (distanceM / 1000.0) : null;
        _routeDurationMin = durationS != null ? (durationS / 60.0) : null;
      });
    }
    // GeoJSON path
    try {
      if (geometry is Map<String, dynamic>) {
        final coords = geometry['coordinates'] as List<dynamic>?;
        if (coords != null && coords.isNotEmpty) {
          final points = <LatLng>[];
          for (final c in coords) {
            if (c is List && c.length >= 2) {
              final lon = (c[0] as num).toDouble();
              final lat = (c[1] as num).toDouble();
              points.add(LatLng(lat, lon));
            }
          }
          if (points.isNotEmpty) return points;
        }
      }
    } catch (_) {}
    // Fallback: try polyline if geometry came as string (older behavior)
    if (geometry is String && geometry.isNotEmpty) {
      return _decodePolyline(geometry);
    }
    return const [];
  }

  List<LatLng> _decodePolyline(String polyline) {
    // Polyline decoding (precision 5)
    final List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;
    while (index < polyline.length) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  Future<void> _fitCameraToPoints() async {
    if (_mapController == null) return;
    final a = _pickupLatLng;
    final b = _dropoffLatLng;
    if (a == null && b == null) return;
    if (a != null && b == null) {
      // If we only have pickup and we also know current location, fit both
      if (_position != null) {
        final cur = LatLng(_position!.latitude, _position!.longitude);
        final sw = LatLng(
          math.min(cur.latitude, a.latitude),
          math.min(cur.longitude, a.longitude),
        );
        final ne = LatLng(
          math.max(cur.latitude, a.latitude),
          math.max(cur.longitude, a.longitude),
        );
        final bounds = LatLngBounds(southwest: sw, northeast: ne);
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 80),
        );
      } else {
        await _mapController!.animateCamera(CameraUpdate.newLatLngZoom(a, 15));
      }
      return;
    }
    if (a == null && b != null) {
      await _mapController!.animateCamera(CameraUpdate.newLatLngZoom(b, 15));
      return;
    }
    // both non-null
    final sw = LatLng(
      math.min(a!.latitude, b!.latitude),
      math.min(a.longitude, b.longitude),
    );
    final ne = LatLng(
      math.max(a.latitude, b.latitude),
      math.max(a.longitude, b.longitude),
    );
    final bounds = LatLngBounds(southwest: sw, northeast: ne);
    // padding to account for bottom sheet
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
    // Start fully visible so user can drag DOWN to hide
    _sheetLift = _sheetLiftMax;
    // Prefetch driver application status
    _refreshDriverApplicationStatus();
    // Capture prefill and apply after first frame
    _pendingPrefillDropoff = widget.prefillDropoff;
    _pendingPrefillAddress = widget.prefillDropoffAddress;
    if (_pendingPrefillDropoff != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _applyPrefillDropoff());
    }
  }

  void _onSheetDragUpdate(DragUpdateDetails details) {
    // Allow both UP/DOWN drags
    final next = (_sheetLift - details.delta.dy).clamp(0.0, _sheetLiftMax);
    if (next != _sheetLift) setState(() => _sheetLift = next);
  }

  void _onSheetDragEnd(DragEndDetails details) {
    // Snap to collapsed (partial) or hidden (full) states
    final hideThreshold = _sheetLiftMax * 0.3;
    final target = _sheetLift < hideThreshold ? 0.0 : _sheetLiftMax;
    setState(() => _sheetLift = target);
  }

  void _showRideMenu(BuildContext context) {
    _loadMyRatingSummary();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Orbit Ride Menu'),
        message: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User profile section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoTheme.of(context).barBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // User avatar placeholder
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child:
                        const Icon(CupertinoIcons.person, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppAuth.myProfile.baseUser.fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Balance chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB48648),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.money_dollar_circle_fill,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('KES 500',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.star_fill,
                                color: Color(0xFFF59E0B), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              _myRatingAvg == null
                                  ? 'My Rating'
                                  : '${_myRatingAvg!.toStringAsFixed(1)} (${_myRatingCount ?? 0})',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Menu options
            CupertinoListSection(
              backgroundColor:
                  CupertinoTheme.of(context).scaffoldBackgroundColor,
              dividerMargin: 0,
              hasLeading: false,
              children: [
                CupertinoListTile.notched(
                  title: const Text('Ride History'),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.car_fill,
                        color: Colors.white),
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_forward,
                      color: Color(0xFFB48648)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                          builder: (_) =>
                              const RideHistoryView(isDriver: false)),
                    );
                  },
                ),
                CupertinoListTile.notched(
                  title: const Text('Favourite Locations'),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB48648),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.placemark_fill,
                        color: Colors.white),
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_forward,
                      color: Color(0xFFB48648)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final res = await Navigator.push<LocationSearchResult>(
                      context,
                      CupertinoPageRoute(
                          builder: (_) => const FavoriteLocationsView()),
                    );
                    if (res != null && mounted) {
                      setState(() {
                        _dropoffLatLng = res.latLng;
                        _dropoffCtrl.text = res.address;
                      });
                      await _updateRoutePolylineIfReady();
                      await _fitCameraToPoints();
                    }
                  },
                ),
                CupertinoListTile.notched(
                  title: const Text('Payment Methods'),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.creditcard_fill,
                        color: Colors.white),
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_forward,
                      color: Color(0xFFB48648)),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
                CupertinoListTile.notched(
                  title: const Text('Settings'),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.settings,
                        color: Colors.white),
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_forward,
                      color: Color(0xFFB48648)),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
                CupertinoListTile.notched(
                  title: const Text('Help & Support'),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.question_circle_fill,
                        color: Colors.white),
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_forward,
                      color: Color(0xFFB48648)),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _onFindRide() async {
    // Validate inputs
    if (_pickupLatLng == null || _dropoffLatLng == null) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Please select pickup and destination',
      );
      return;
    }

    // Ensure fare is computed
    await _recomputeFareIfPossible();

    // Send request via backend (real-time to online drivers)
    final fare = _suggestedFareKes ?? double.tryParse(_fareCtrl.text) ?? 0.0;
    try {
      final sent = await DriversApiService.sendRideRequest(
        pickupAddress:
            (_pickupAddress ?? _currentAddress) ?? 'Current location',
        dropoffAddress:
            _dropoffCtrl.text.isNotEmpty ? _dropoffCtrl.text : 'Destination',
        pickupLat: _pickupLatLng!.latitude,
        pickupLng: _pickupLatLng!.longitude,
        dropoffLat: _dropoffLatLng!.latitude,
        dropoffLng: _dropoffLatLng!.longitude,
        fareKes: fare,
        rideType: _currentRideTitle(),
        paymentMethod: _paymentMethod,
        passengersCount: _passengersCount,
      );
      if (!mounted) return;
      if (sent > 0) {
        // Start finding driver animation and listen for driver acceptance
        setState(() {
          _isFindingDriver = true;
          _currentRequestId = DateTime.now().millisecondsSinceEpoch.toString();
        });
        _bindFindingDriverSocket();
      } else {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'No nearby drivers online. Please try again shortly.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Could not send ride request. Please try again.',
      );
    }
  }

  void _bindFindingDriverSocket() {
    if (_findingDriverSocketBound) return;
    try {
      final socket = VChatController.I.nativeApi.remote.socketIo.socket;
      socket.off('ride_assigned');
      socket.on('ride_assigned', (data) {
        // Driver accepted - hide finding overlay and navigate to tracking view
        try {
          Map<String, dynamic>? map;
          if (data is Map) {
            map = Map<String, dynamic>.from(data);
          } else if (data is String) {
            map = Map<String, dynamic>.from(jsonDecode(data) as Map);
          }
          if (map != null && mounted) {
            setState(() {
              _isFindingDriver = false;
              _currentRequestId = null;
            });
            _unbindFindingDriverSocket();

            // Navigate to passenger ride tracking view
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => RideTrackingView(
                  role: RideTrackingRole.passenger,
                  rideId: (map!['rideId'] ?? '').toString(),
                  passengerId: AppAuth.myProfile.baseUser.id,
                  driverId: (map['driverId'] ?? '').toString(),
                  pickupAddress: (map['pickupAddress'] ?? '').toString(),
                  dropoffAddress: (map['dropoffAddress'] ?? '').toString(),
                  pickupLat: (map['pickupLat'] as num).toDouble(),
                  pickupLng: (map['pickupLng'] as num).toDouble(),
                  dropoffLat: (map['dropoffLat'] as num).toDouble(),
                  dropoffLng: (map['dropoffLng'] as num).toDouble(),
                  fareKes: (map['fareKes'] as num).toDouble(),
                  rideType: map['rideType'] as String?,
                  passengersCount: ((map['passengersCount'] as num?) ?? (map['passengers_count'] as num?))?.toInt() ?? 1,
                  driverName: (map['driverName'] ?? '').toString(),
                  driverPhotoUrl: map['driverPhotoUrl'] as String?,
                  vehicleModel: map['vehicleModel'] as String?,
                  vehiclePlate: map['vehiclePlate'] as String?,
                  vehicleType: map['vehicleType'] as String?,
                  acceptedByDriver: true,
                  preTrip: map['preTrip'] == true,
                ),
              ),
            );
          }
        } catch (_) {}
      });
      _findingDriverSocketBound = true;
    } catch (_) {}
  }

  void _unbindFindingDriverSocket() {
    try {
      final socket = VChatController.I.nativeApi.remote.socketIo.socket;
      socket.off('ride_assigned');
      _findingDriverSocketBound = false;
    } catch (_) {}
  }

  void _cancelFindingDriver() {
    setState(() {
      _isFindingDriver = false;
      _currentRequestId = null;
    });
    _unbindFindingDriverSocket();
    // Optionally notify backend to cancel the request
    VAppAlert.showSuccessSnackBar(
      context: context,
      message: 'Searching cancelled',
    );
  }

  Future<void> _initLocation({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await LocationService.instance
          .getCurrentLocation(forceRefresh: forceRefresh);
      if (!mounted) return;
      if (pos == null) {
        setState(() {
          _error =
              'Location unavailable. Please enable location services and permissions.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _position = pos;
        _pickupLatLng = LatLng(pos.latitude, pos.longitude);
        _markers
          ..clear()
          ..add(
            Marker(
              markerId: const MarkerId('pickup'),
              position: _pickupLatLng!,
              infoWindow: const InfoWindow(title: 'Pickup'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
            ),
          );
        // Do not set coordinates as address; keep waiting for a human-readable address
        // via plugin reverse geocoding or HTTP fallbacks
        _loading = false; // success: stop loading spinner
      });

      // Reverse geocode for a human-readable address (plugin first, then fallbacks)
      try {
        final placemarks = await geocoding.placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String?>[
            (p.street ?? '').trim().isNotEmpty ? p.street : null,
            (p.subLocality ?? '').trim().isNotEmpty ? p.subLocality : null,
            (p.locality ?? '').trim().isNotEmpty ? p.locality : null,
          ].whereType<String>().toList();
          setState(() {
            _currentAddress = parts.isNotEmpty
                ? parts.join(', ')
                : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
            _pickupAddress ??= _currentAddress;
          });
        } else {
          final alt = await _reverseGeocodeFallback(
              LatLng(pos.latitude, pos.longitude));
          if (alt != null && mounted) {
            setState(() {
              _currentAddress = alt;
              _pickupAddress ??= _currentAddress;
            });
          }
        }
      } catch (_) {
        // If plugin reverse geocoding fails (common on web), try fallbacks
        final alt =
            await _reverseGeocodeFallback(LatLng(pos.latitude, pos.longitude));
        if (alt != null && mounted) {
          setState(() {
            _currentAddress = alt;
            _pickupAddress ??= _currentAddress;
          });
        } else if (mounted) {
          // Keep the coordinates fallback
          setState(() {
            _currentAddress ??=
                '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
            _pickupAddress ??= _currentAddress;
          });
        }
      }
      // Move camera if map already created
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(pos.latitude, pos.longitude),
            15,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to get location';
        _loading = false;
      });
    }
  }

  Future<void> _recenter() async {
    if (_position == null) {
      await _initLocation(forceRefresh: true);
      return;
    }
    final pos = _position!;
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(pos.latitude, pos.longitude),
        15,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    // Web is supported: map is rendered via google_maps_flutter_web

    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.location_slash,
                size: 64,
                color: const Color(0xFFB48648),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: context.isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              CupertinoButton.filled(
                onPressed: () async {
                  // Try to open app settings so user can enable permission
                  await LocationService.instance.openAppSettings();
                },
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Text('Open Settings'),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                onPressed: () => _initLocation(forceRefresh: true),
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      );
    }

    final pos = _position!;

    return Stack(
      children: [
        GoogleMap(
          mapToolbarEnabled: false,
          buildingsEnabled: true,
          myLocationEnabled: true,
          // The default Google Maps "my location" button on web may hang showing
          // a loading spinner if the browser blocks or delays geolocation.
          // We use our own recenter button wired to LocationService with
          // timeouts/fallbacks, so hide the default on web to avoid confusion.
          myLocationButtonEnabled: !kIsWeb,
          compassEnabled: true,
          zoomControlsEnabled: false,
          trafficEnabled: false,
          initialCameraPosition: CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 15,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            _enableWebMapPointerEvents();
          },
          markers: _markers,
          polylines: _polylines,
        ),
        // Recenter button (keep it a little higher to avoid sheet)
        Positioned(
          right: 16,
          top: 110,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.isDark
                  ? Colors.black.withOpacity(0.7)
                  : Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: CupertinoButton(
              padding: const EdgeInsets.all(10),
              onPressed: _recenter,
              child: Icon(
                CupertinoIcons.location_fill,
                color: const Color(0xFFB48648),
              ),
            ),
          ),
        ),

        // Draggable bottom ride sheet (grab handle at top)
        AnimatedPositioned(
          left: 0,
          right: 0,
          bottom: _sheetLift - _sheetLiftMax,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              color: CupertinoTheme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, -6),
                )
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle area
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: _onSheetDragUpdate,
                      onVerticalDragEnd: _onSheetDragEnd,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                        child: Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _locationRow(
                      context,
                      icon: CupertinoIcons.location_solid,
                      iconColor: const Color(0xFF3B82F6),
                      title: (_pickupAddress ?? _currentAddress)?.isNotEmpty ==
                              true
                          ? (_pickupAddress ?? _currentAddress)!
                          : 'Current location',
                      subtitle: (_pickupAddress ?? _currentAddress) == null
                          ? 'Locating address...'
                          : (_pickupAddress == null
                              ? 'House No. — (Current location)'
                              : null),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _openLocationPicker(isPickup: true),
                        child: const Text('Edit'),
                      ),
                    ),
                    const Divider(height: 20),
                    _locationRow(
                      context,
                      icon: CupertinoIcons.map_pin_ellipse,
                      iconColor: const Color(0xFF22C55E),
                      title: _dropoffCtrl.text.isEmpty
                          ? 'Choose destination'
                          : _dropoffCtrl.text,
                      subtitle: _dropoffCtrl.text.isEmpty
                          ? 'Where are you headed?'
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _openFavoritesPicker,
                            child: const Icon(CupertinoIcons.star,
                                color: Color(0xFFB48648)),
                          ),
                          const SizedBox(width: 6),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () =>
                                _openLocationPicker(isPickup: false),
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pick Your Ride',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CupertinoSlidingSegmentedControl<RideGroup>(
                      groupValue: _selectedGroup,
                      children: const <RideGroup, Widget>{
                        RideGroup.cars: Text('Cars'),
                        RideGroup.motorbikes: Text('Motorbikes'),
                      },
                      onValueChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _selectedGroup = val;
                          _selectedRide = 0;
                        });
                        _recomputeFareIfPossible();
                      },
                    ),
                    const SizedBox(height: 10),
                    Builder(builder: (context) {
                      final list = _selectedGroup == RideGroup.cars
                          ? _carsOptions
                          : _motorbikeOptions;
                      return LayoutBuilder(
                        builder: (c, constraints) {
                          // Grid metrics
                          const int crossAxisCount = 4;
                          const double mainAxisSpacing = 8.0;
                          final double childAspectRatio = kIsWeb ? 0.8 : 0.9;

                          final totalSpacing =
                              (crossAxisCount - 1) * mainAxisSpacing;
                          final tileWidth =
                              (constraints.maxWidth - totalSpacing) /
                                  crossAxisCount;
                          final tileHeight = (tileWidth / childAspectRatio) +
                              (kIsWeb ? 6.0 : 0.0);
                          // One row items height computed from childAspectRatio; used for horizontal lists

                          if (_selectedGroup == RideGroup.cars) {
                            // Single row with HORIZONTAL scroll for Cars
                            return SizedBox(
                              height: tileHeight,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.zero,
                                physics: const BouncingScrollPhysics(),
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (c, i) {
                                  final opt = list[i];
                                  final selected = i == _selectedRide;
                                  return SizedBox(
                                    width: tileWidth,
                                    child: GestureDetector(
                                      onTap: () => _onRideSelected(i),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? (CupertinoTheme.of(context)
                                                  .scaffoldBackgroundColor)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.5),
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFFB48648)
                                                : Theme.of(context)
                                                    .dividerColor
                                                    .withOpacity(0.2),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(opt.icon,
                                                size: 22,
                                                color: Colors.grey.shade800),
                                            const SizedBox(height: 6),
                                            Text(
                                              opt.title,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          } else {
                            // Motorbikes: single row with HORIZONTAL scroll (aligned with Cars)
                            return SizedBox(
                              height: tileHeight,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.zero,
                                physics: const BouncingScrollPhysics(),
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (c, i) {
                                  final opt = list[i];
                                  final selected = i == _selectedRide;
                                  return SizedBox(
                                    width: tileWidth,
                                    child: GestureDetector(
                                      onTap: () => _onRideSelected(i),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? (CupertinoTheme.of(context)
                                                  .scaffoldBackgroundColor)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.5),
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFFB48648)
                                                : Theme.of(context)
                                                    .dividerColor
                                                    .withOpacity(0.2),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(opt.icon,
                                                size: 22,
                                                color: Colors.grey.shade800),
                                            const SizedBox(height: 6),
                                            Text(
                                              opt.title,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(CupertinoIcons.person_2_fill,
                            size: 18, color: Color(0xFFB48648)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Passengers',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minSize: 0,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                          onPressed: _passengersCount <= 1
                              ? null
                              : () => setState(() => _passengersCount =
                                  (_passengersCount - 1).clamp(1, 20).toInt()),
                          child: const Text('-',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _passengersCount.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 10),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minSize: 0,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                          onPressed: () => setState(() => _passengersCount =
                              (_passengersCount + 1).clamp(1, 20).toInt()),
                          child: const Text('+',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'KES ',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Expanded(
                                  child: CupertinoTextField.borderless(
                                    controller: _fareCtrl,
                                    placeholder: 'Auto',
                                    readOnly: true,
                                    enableInteractiveSelection: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _roundIconButton(
                          context,
                          icon: _paymentMethod == 'cash'
                              ? Icons.account_balance_wallet
                              : CupertinoIcons.creditcard,
                          color: _paymentMethod == 'cash'
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6),
                          onPressed: _pickPaymentMethod,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: _onFindRide,
                        borderRadius: BorderRadius.circular(12),
                        child: const Text('Find Ride'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: const Color(0xFF3B82F6),
                        onPressed: () async {
                          if (_scheduledAt == null) {
                            await _pickScheduleTime();
                          }
                          if (_scheduledAt != null) {
                            await _onScheduleRide();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Text(
                          _scheduledAt == null
                              ? 'Schedule Ride'
                              : 'Schedule: ${_scheduledAt!.toLocal().toString().substring(0, 16)}',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _enableWebMapPointerEvents() {
    if (!kIsWeb) return;
    try {
      // Give DOM time to build, then enable pointer events for the Google Map host
      Future.delayed(const Duration(milliseconds: 50), () {
        try {
          final candidates = html.document.querySelectorAll(
              'flt-platform-view, .flt-platform-view, .platform-view, .flt-platform-element');
          for (final el in candidates) {
            final hasGoogleMap = el.querySelector('.gm-style') != null ||
                el.querySelector('div[aria-label*="Google"]') != null;
            if (hasGoogleMap) {
              // override global pointer-events: none !important from index.html
              try {
                el.style.setProperty('pointer-events', 'auto', 'important');
              } catch (_) {
                el.style.pointerEvents = 'auto';
              }
              try {
                el.style.setProperty('z-index', '0', 'important');
              } catch (_) {
                el.style.zIndex = '0';
              }
              el.classes.add('gm-interactive');
            }
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Width of the end drawer (responsive)
    final double drawerWidth =
        math.min(340.0, MediaQuery.of(context).size.width * 0.88);

    final scaffold = CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Row(
            children: [
              Icon(CupertinoIcons.chevron_back, color: Color(0xFFB48648)),
              SizedBox(width: 2),
              Text('Back', style: TextStyle(color: Color(0xFFB48648))),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Become Driver button (only for non-driver users)
            if (!AppAuth.myProfile.roles.contains(UserRoles.driver))
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: _becomeDisabled
                    ? null
                    : () async {
                        _refreshDriverApplicationStatus();
                        try {
                          final latest = await DriversApiService.myLatest();
                          if (!mounted) return;
                          final status =
                              latest?['status']?.toString().toLowerCase();
                          if (status == 'pending') {
                            await showCupertinoDialog(
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: const Text('Application Pending'),
                                content: const Text(
                                    'Your driver application is pending review. We will notify you once approved.'),
                                actions: [
                                  CupertinoDialogAction(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }
                          if (status == 'approved') {
                            setState(() => _becomeDisabled = true);
                            await showCupertinoDialog(
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: const Text('Application Approved'),
                                content: const Text(
                                    'Congratulations! You are now approved as a driver.'),
                                actions: [
                                  CupertinoDialogAction(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }
                        } catch (_) {}
                        await Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => const BecomeDriverView(),
                          ),
                        );
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB48648),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Become Driver',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: () {
                _refreshDriverApplicationStatus();
                _loadMyRatingSummary();
                setState(() => _isEndDrawerOpen = true);
              },
              child: const Icon(CupertinoIcons.line_horizontal_3,
                  color: Color(0xFFB48648)),
            ),
          ],
        ),
        middle: const Text(
          'Orbit Ride',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        top: false,
        child: _buildBody(context),
      ),
    );

    return Stack(
      children: [
        scaffold,
        // Finding Driver overlay - shows while searching for drivers
        if (_isFindingDriver)
          FindingDriverOverlay(
            onCancel: _cancelFindingDriver,
          ),
        // Global scrim (covers nav bar too)
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_isEndDrawerOpen,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _isEndDrawerOpen ? 0.35 : 0.0,
              child: GestureDetector(
                onTap: () => setState(() => _isEndDrawerOpen = false),
                child: Container(color: Colors.black),
              ),
            ),
          ),
        ),
        // Global right-side sliding drawer (Balance only)
        AnimatedPositioned(
          top: 0,
          bottom: 0,
          right: _isEndDrawerOpen ? 0 : -drawerWidth,
          width: drawerWidth,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              color: CupertinoTheme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(-4, 0),
                ),
              ],
            ),
            child: SafeArea(
              top: true,
              bottom: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Balance',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(6),
                          onPressed: () =>
                              setState(() => _isEndDrawerOpen = false),
                          child: const Icon(CupertinoIcons.xmark, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const BalanceWidget(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.star_fill,
                              color: Color(0xFFF59E0B)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _myRatingAvg == null
                                  ? 'My Rating'
                                  : 'My Rating: ${_myRatingAvg!.toStringAsFixed(1)} (${_myRatingCount ?? 0})',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Favourite Locations tile (passenger)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () async {
                        if (mounted) setState(() => _isEndDrawerOpen = false);
                        final res = await Navigator.of(context)
                            .push<LocationSearchResult>(
                          CupertinoPageRoute(
                              builder: (_) => const FavoriteLocationsView()),
                        );
                        if (res != null && mounted) {
                          setState(() {
                            _dropoffLatLng = res.latLng;
                            _dropoffCtrl.text = res.address;
                          });
                          await _updateRoutePolylineIfReady();
                          await _fitCameraToPoints();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(0.2)),
                        ),
                        child: Row(
                          children: const [
                            Icon(CupertinoIcons.placemark_fill,
                                color: Color(0xFFB48648)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Favourite Locations',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Icon(CupertinoIcons.chevron_forward),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Ride History tile (passenger)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () {
                        if (mounted) setState(() => _isEndDrawerOpen = false);
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                              builder: (_) =>
                                  const RideHistoryView(isDriver: false)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(0.2)),
                        ),
                        child: Row(
                          children: const [
                            Icon(CupertinoIcons.time_solid,
                                color: Color(0xFF3B82F6)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Ride History',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Icon(CupertinoIcons.chevron_forward),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Scheduled Rides tile (passenger)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () {
                        if (mounted) setState(() => _isEndDrawerOpen = false);
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                              builder: (_) => const ScheduledRidesView()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(0.2)),
                        ),
                        child: Row(
                          children: const [
                            Icon(CupertinoIcons.calendar_today,
                                color: Color(0xFF10B981)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Scheduled Rides',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Icon(CupertinoIcons.chevron_forward),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Driver/Passenger toggle (only for users with driver role)
                  if (AppAuth.myProfile.roles.contains(UserRoles.driver)) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Mode',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: _isDriverMode ? 1 : 0,
                        children: const {
                          0: Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 6),
                            child: Text('Passenger'),
                          ),
                          1: Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 6),
                            child: Text('Driver'),
                          ),
                        },
                        onValueChanged: (v) {
                          if (v == null) return;
                          if (v == 1) {
                            RideModeService.instance.setDriverMode(true);
                            if (mounted)
                              setState(() => _isEndDrawerOpen = false);
                            Navigator.of(context).pushReplacement(
                              CupertinoPageRoute(
                                  builder: (_) => const DriverDashboardView()),
                            );
                          } else {
                            RideModeService.instance.setDriverMode(false);
                            setState(() => _isDriverMode = false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RideOption {
  final String title;
  final IconData icon;
  final int count;
  const _RideOption(
      {required this.title, required this.icon, required this.count});
}

enum RideGroup { cars, motorbikes }

Widget _roundIconButton(BuildContext context,
    {required IconData icon,
    required Color color,
    required VoidCallback onPressed}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      shape: BoxShape.circle,
    ),
    child: IconButton(
      icon: Icon(icon, color: color),
      onPressed: onPressed,
      splashRadius: 22,
    ),
  );
}

Widget _locationRow(
  BuildContext context, {
  required IconData icon,
  required Color iconColor,
  required String title,
  String? subtitle,
  Widget? trailing,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) trailing,
    ],
  );
}

/// Animated overlay shown while searching for a driver
class FindingDriverOverlay extends StatefulWidget {
  final VoidCallback onCancel;

  const FindingDriverOverlay({
    super.key,
    required this.onCancel,
  });

  @override
  State<FindingDriverOverlay> createState() => _FindingDriverOverlayState();
}

class _FindingDriverOverlayState extends State<FindingDriverOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated car and ripple effect
              SizedBox(
                height: 180,
                width: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ripple rings
                    AnimatedBuilder(
                      animation: _rippleAnimation,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            for (int i = 0; i < 3; i++)
                              Opacity(
                                opacity: (1 - ((_rippleAnimation.value + i * 0.33) % 1.0)) * 0.3,
                                child: Transform.scale(
                                  scale: 0.5 + ((_rippleAnimation.value + i * 0.33) % 1.0) * 0.8,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFB48648).withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    // Pulsing car icon
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFB48648),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFB48648).withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.car_fill,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Title
              const Text(
                'Finding your driver...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle
              Text(
                'Connecting you with nearby drivers',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 48),
              // Cancel button
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                onPressed: widget.onCancel,
                child: const Text(
                  'Cancel Search',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
