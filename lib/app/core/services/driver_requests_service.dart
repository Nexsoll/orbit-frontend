import 'dart:async';

import 'package:super_up/app/core/services/location_service.dart';
import 'package:super_up/app/core/api_service/drivers/drivers_api_service.dart';

class DriverOnline {
  final String driverId;
  final String name;
  final String? avatarUrl;
  double lat;
  double lng;
  DateTime lastUpdated;
  final String? vehicleType; // e.g. OrbitGreen, OrbitX, Economy

  DriverOnline({
    required this.driverId,
    required this.name,
    required this.avatarUrl,
    required this.lat,
    required this.lng,
    this.vehicleType,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();
}

class RideRequestModel {
  final String id;
  final String passengerId;
  final String passengerName;
  final String? passengerPhotoUrl;
  final int passengersCount;
  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final double fareKes;
  final DateTime createdAt;
  final String? rideType; // requested ride type title
  final String? paymentMethod; // 'cash' | 'online'
  final bool isScheduled;
  final DateTime? scheduledAt;

  RideRequestModel({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhotoUrl,
    this.passengersCount = 1,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.fareKes,
    this.rideType,
    this.paymentMethod,
    this.isScheduled = false,
    this.scheduledAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class DriverRequestsService {
  DriverRequestsService._();
  static final DriverRequestsService instance = DriverRequestsService._();

  // Online drivers map
  final Map<String, DriverOnline> _onlineDrivers = {};

  // Requests per driver
  final Map<String, List<RideRequestModel>> _requestsByDriver = {};

  // Streams per driver
  final Map<String, StreamController<List<RideRequestModel>>> _controllers = {};

  Stream<List<RideRequestModel>> watchDriverRequests(String driverId) {
    final ctrl = _controllers.putIfAbsent(
      driverId,
      () => StreamController<List<RideRequestModel>>.broadcast(),
    );
    ctrl.add(List.unmodifiable(_requestsByDriver[driverId] ?? const []));
    return ctrl.stream;
  }

  int get onlineCount => _onlineDrivers.length;
  bool isDriverOnline(String driverId) => _onlineDrivers.containsKey(driverId);

  Future<bool> goOnline({
    required String driverId,
    required String name,
    required String? avatarUrl,
    double? overrideLat,
    double? overrideLng,
  }) async {
    // Try to obtain a usable location (current or cached)
    final pos = await LocationService.instance.getCurrentLocation(forceRefresh: true);
    final cached = LocationService.instance.currentPosition;
    final use = pos ?? cached;
    final double? lat = overrideLat ?? use?.latitude;
    final double? lng = overrideLng ?? use?.longitude;
    if (lat == null || lng == null) {
      return false;
    }

    // Try to get vehicle type from latest application (optional)
    String? vType;
    try {
      final latest = await DriversApiService.myLatest();
      vType = latest?['vehicleType']?.toString();
    } catch (_) {}

    _onlineDrivers[driverId] = DriverOnline(
      driverId: driverId,
      name: name,
      avatarUrl: avatarUrl,
      lat: lat,
      lng: lng,
      vehicleType: vType,
    );
    // Notify backend presence (best-effort)
    try {
      await DriversApiService.presenceOnline(lat: lat, lng: lng, vehicleType: vType);
    } catch (_) {}
    return true;
  }

  void goOffline(String driverId) {
    _onlineDrivers.remove(driverId);
    // Keep requests list intact (driver can still see them); Alternatively clear:
    // _requestsByDriver.remove(driverId);
    // Notify backend presence (best-effort)
    DriversApiService.presenceOffline().catchError((_) {});
  }

  Future<void> updateLocation(String driverId) async {
    final pos = await LocationService.instance.getCurrentLocation();
    if (pos == null) return;
    final d = _onlineDrivers[driverId];
    if (d != null) {
      d.lat = pos.latitude;
      d.lng = pos.longitude;
      d.lastUpdated = DateTime.now();
    }
  }

  int broadcastRideRequest({
    required RideRequestModel request,
    double radiusKm = 5.0,
  }) {
    int dispatched = 0;
    bool isBike(String s) => s.contains('bike') || s.contains('motor');
    final reqType = (request.rideType ?? '').toLowerCase();

    void dispatchToEntry(String driverId, DriverOnline d) {
      final list = _requestsByDriver.putIfAbsent(driverId, () => <RideRequestModel>[]);
      list.add(request);
      dispatched++;
      _controllers[driverId]?.add(List.unmodifiable(list));
    }

    // Round 1: radiusKm with family filtering
    for (final e in _onlineDrivers.entries) {
      final d = e.value;
      final drvType = (d.vehicleType ?? '').toLowerCase();
      if (reqType.isNotEmpty && drvType.isNotEmpty) {
        // Exact category match first
        if (drvType != reqType) continue;
      } else if (reqType.isNotEmpty) {
        // If driver type unknown but request has type, skip
        continue;
      }
      final distanceKm = LocationService.instance.calculateDistance(
        request.pickupLat,
        request.pickupLng,
        d.lat,
        d.lng,
      );
      if (distanceKm <= radiusKm) dispatchToEntry(e.key, d);
    }
    if (dispatched > 0) return dispatched;

    // Round 2: widen radius to 50km (still family filtered)
    for (final e in _onlineDrivers.entries) {
      final d = e.value;
      final drvType = (d.vehicleType ?? '').toLowerCase();
      if (reqType.isNotEmpty && drvType.isNotEmpty) {
        if (drvType != reqType) continue;
      } else if (reqType.isNotEmpty) {
        continue;
      }
      final distanceKm = LocationService.instance.calculateDistance(
        request.pickupLat,
        request.pickupLng,
        d.lat,
        d.lng,
      );
      if (distanceKm <= 50.0) dispatchToEntry(e.key, d);
    }
    if (dispatched > 0) return dispatched;

    // Round 3: dev fallback — still enforce exact type if provided
    for (final e in _onlineDrivers.entries) {
      final drvType = (e.value.vehicleType ?? '').toLowerCase();
      if (reqType.isNotEmpty) {
        if (drvType != reqType) continue;
      }
      dispatchToEntry(e.key, e.value);
    }
    return dispatched;
  }

  /// Ingest a real-time incoming request for a specific driver (from socket)
  void onIncomingRequest({required String driverId, required RideRequestModel request}) {
    final list = _requestsByDriver.putIfAbsent(driverId, () => <RideRequestModel>[]);
    final exists = list.any((r) => r.id == request.id);
    if (!exists) {
      list.add(request);
      _controllers[driverId]?.add(List.unmodifiable(list));
    }
  }

  void acceptRequest({required String driverId, required String requestId}) {
    // Remove this request from all other drivers (winner takes it)
    for (final k in _requestsByDriver.keys) {
      _requestsByDriver[k] = (_requestsByDriver[k] ?? [])
          .where((r) => r.id != requestId)
          .toList(growable: true);
      _controllers[k]?.add(List.unmodifiable(_requestsByDriver[k]!));
    }
  }

  void declineRequest({required String driverId, required String requestId}) {
    final list = _requestsByDriver[driverId];
    if (list == null) return;
    list.removeWhere((r) => r.id == requestId);
    _controllers[driverId]?.add(List.unmodifiable(list));
  }
}
