import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:super_up/app/core/api_service/drivers/drivers_api_service.dart';
import 'package:super_up/app/core/services/location_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:http/http.dart' as http;
import 'package:super_up/app/modules/ride/views/orbit_ride_view.dart';
import 'package:super_up/app/modules/driver/views/driver_dashboard_view.dart';

enum RideTrackingRole { passenger, driver }

class RideTrackingView extends StatefulWidget {
  final RideTrackingRole role;
  final String rideId;
  final String passengerId;
  final String driverId;

  // Shared ride meta
  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final double fareKes;
  final String? rideType;
  final int passengersCount;

  // Passenger sees driver info
  final String driverName;
  final String? driverPhotoUrl;
  final String? vehicleModel;
  final String? vehiclePlate;
  final String? vehicleType;

  // Driver sees passenger info
  final String? passengerName;
  final String? passengerPhotoUrl;
  final bool acceptedByDriver;
  final bool preTrip;

  const RideTrackingView({
    super.key,
    required this.role,
    required this.rideId,
    required this.passengerId,
    required this.driverId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.fareKes,
    this.rideType,
    this.passengersCount = 1,
    required this.driverName,
    this.driverPhotoUrl,
    this.vehicleModel,
    this.vehiclePlate,
    this.vehicleType,
    this.passengerName,
    this.passengerPhotoUrl,
    this.acceptedByDriver = false,
    this.preTrip = false,
  });

  @override
  State<RideTrackingView> createState() => _RideTrackingViewState();
}

class _RideTrackingViewState extends State<RideTrackingView> {
  GoogleMapController? _map;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _driverLatLng;
  bool _driverArrived = false;
  Timer? _driverLocationTimer;
  StreamSubscription? _socketLocSub;
  bool _socketBound = false;
  String? _vehicleModel;
  String? _vehiclePlate;
  String? _vehicleType;
  bool _inTrip = true;
  // Custom driver marker icon and heading state
  BitmapDescriptor? _driverIcon;
  LatLng? _lastDriverLatLng;
  double _driverHeading = 0;

  @override
  void initState() {
    super.initState();
    _inTrip = !widget.preTrip;
    _initMarkers();
    _bindPassengerSocketIfNeeded();
    _bindDriverSocketIfNeeded();
    if (_inTrip) _maybeStartDriverLocationTimer();
    _vehicleModel = widget.vehicleModel;
    _vehiclePlate = widget.vehiclePlate;
    _vehicleType = widget.vehicleType;
    debugPrint('[RideTracking] init vehicleModel=${_vehicleModel}, plate=${_vehiclePlate}, type=${_vehicleType}');
    _loadRideDetailsIfMissing();
    if (widget.role == RideTrackingRole.passenger && widget.acceptedByDriver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          VAppAlert.showSuccessSnackBar(context: context, message: 'Accepted by driver');
        }
      });
    }
    // Preload the custom driver marker icon
    _loadDriverIcon();
  }

  Future<void> _promptRatingAndClose({required String rateeId}) async {
    try {
      await _showRatingDialog(rateeId: rateeId);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _showRatingDialog({required String rateeId}) async {
    int stars = 0;
    final commentCtrl = TextEditingController();
    await showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return CupertinoAlertDialog(
            title: const Text('Rate your trip'),
            content: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < stars;
                    return GestureDetector(
                      onTap: () => setState(() => stars = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Icon(
                          filled ? CupertinoIcons.star_fill : CupertinoIcons.star,
                          color: const Color(0xFFF59E0B),
                          size: 24,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: commentCtrl,
                  placeholder: 'Optional comment',
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Skip'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: stars == 0
                    ? null
                    : () async {
                        try {
                          await DriversApiService.submitRating(
                            rideId: widget.rideId,
                            rateeId: rateeId,
                            stars: stars,
                            comment: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
                          );
                        } catch (_) {}
                        if (context.mounted) Navigator.of(ctx).pop();
                      },
                child: const Text('Submit'),
              ),
            ],
          );
        });
      },
    );
  }

  void _initMarkers() {
    final pickup = LatLng(widget.pickupLat, widget.pickupLng);
    final dropoff = LatLng(widget.dropoffLat, widget.dropoffLng);
    _markers.addAll([
      Marker(markerId: const MarkerId('pickup'), position: pickup, infoWindow: const InfoWindow(title: 'Pickup')),
      Marker(markerId: const MarkerId('dropoff'), position: dropoff, infoWindow: const InfoWindow(title: 'Dropoff')),
    ]);
    // initial driver position near pickup (for passenger until first update)
    if (widget.role == RideTrackingRole.passenger) {
      _driverLatLng = pickup;
      _setOrUpdateDriverMarker();
    }
  }

  void _bindPassengerSocketIfNeeded() {
    if (widget.role != RideTrackingRole.passenger || _socketBound) return;
    try {
      final socket = VChatController.I.nativeApi.remote.socketIo.socket;
      socket.off('ride_driver_location');
      socket.on('ride_driver_location', (data) {
        try {
          Map<String, dynamic>? map;
          if (data is Map) {
            map = Map<String, dynamic>.from(data);
          } else if (data is String) {
            map = Map<String, dynamic>.from(jsonDecode(data) as Map);
          }
          if (map == null) return;
          if ((map['rideId'] ?? '').toString() != widget.rideId) return;
          final lat = (map['lat'] as num).toDouble();
          final lng = (map['lng'] as num).toDouble();
          setState(() {
            _driverLatLng = LatLng(lat, lng);
            _setOrUpdateDriverMarker();
          });
          _rebuildRoute();
        } catch (_) {}
      });
      socket.off('ride_driver_arrived');
      socket.on('ride_driver_arrived', (data) {
        try {
          Map<String, dynamic>? map;
          if (data is Map) {
            map = Map<String, dynamic>.from(data);
          } else if (data is String) {
            map = Map<String, dynamic>.from(jsonDecode(data) as Map);
          }
          if (map == null) return;
          if ((map['rideId'] ?? '').toString() != widget.rideId) return;
          setState(() => _driverArrived = true);
          if (mounted) {
            VAppAlert.showSuccessSnackBar(context: context, message: 'Your driver has arrived');
          }
          _rebuildRoute();
        } catch (_) {}
      });
      socket.off('ride_completed');
      socket.on('ride_completed', (data) async {
        try {
          Map<String, dynamic>? map;
          if (data is Map) {
            map = Map<String, dynamic>.from(data);
          } else if (data is String) {
            map = Map<String, dynamic>.from(jsonDecode(data) as Map);
          }
          if (map == null) return;
          if ((map['rideId'] ?? '').toString() != widget.rideId) return;
          if (!mounted) return;
          VAppAlert.showSuccessSnackBar(context: context, message: 'Trip complete');
          // Ask passenger to rate driver before closing
          await _promptRatingAndClose(rateeId: widget.driverId);
        } catch (_) {}
      });
      socket.off('ride_canceled');
      socket.on('ride_canceled', (data) async {
        try {
          Map<String, dynamic>? map;
          if (data is Map) {
            map = Map<String, dynamic>.from(data);
          } else if (data is String) {
            map = Map<String, dynamic>.from(jsonDecode(data) as Map);
          }
          if (map == null) return;
          if ((map['rideId'] ?? '').toString() != widget.rideId) return;
          if (!mounted) return;
          final canceledBy = (map['canceledBy'] ?? '').toString();
          VAppAlert.showErrorSnackBar(context: context, message: canceledBy == 'driver' ? 'Driver canceled ride' : 'Ride canceled');
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (_) => const OrbitRideView()),
            (route) => false,
          );
        } catch (_) {}
      });
      socket.off('ride_started');
      socket.on('ride_started', (data) async {
        try {
          Map<String, dynamic>? map;
          if (data is Map) {
            map = Map<String, dynamic>.from(data);
          } else if (data is String) {
            map = Map<String, dynamic>.from(jsonDecode(data) as Map);
          }
          if (map == null) return;
          if ((map['rideId'] ?? '').toString() != widget.rideId) return;
          if (!mounted) return;
          setState(() => _inTrip = true);
          _maybeStartDriverLocationTimer();
          VAppAlert.showSuccessSnackBar(context: context, message: 'Trip started');
        } catch (_) {}
      });
      _socketBound = true;
    } catch (_) {}
  }

  void _bindDriverSocketIfNeeded() {
    if (widget.role != RideTrackingRole.driver) return;
    try {
      final socket = VChatController.I.nativeApi.remote.socketIo.socket;
      socket.off('ride_canceled');
      socket.on('ride_canceled', (data) async {
        try {
          Map<String, dynamic>? map;
          if (data is Map) {
            map = Map<String, dynamic>.from(data);
          } else if (data is String) {
            map = Map<String, dynamic>.from(jsonDecode(data) as Map);
          }
          if (map == null) return;
          if ((map['rideId'] ?? '').toString() != widget.rideId) return;
          if (!mounted) return;
          final canceledBy = (map['canceledBy'] ?? '').toString();
          if (canceledBy == 'passenger') {
            VAppAlert.showErrorSnackBar(context: context, message: 'Passenger canceled ride');
            Navigator.of(context).pushAndRemoveUntil(
              CupertinoPageRoute(builder: (_) => const DriverDashboardView()),
              (route) => false,
            );
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _setOrUpdateDriverMarker() {
    if (_driverLatLng == null) return;
    // Compute heading from last position to current for rotation
    if (_lastDriverLatLng != null) {
      _driverHeading = _bearingBetween(_lastDriverLatLng!, _driverLatLng!);
    }
    _lastDriverLatLng = _driverLatLng;
    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: _driverLatLng!,
      icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'Driver'),
      rotation: _driverHeading,
      anchor: const Offset(0.5, 0.5),
      zIndex: 10,
    ));
    _fitCamera();
  }

  void _fitCamera() async {
    if (_map == null) return;
    final pts = <LatLng>[];
    pts.add(LatLng(widget.pickupLat, widget.pickupLng));
    pts.add(LatLng(widget.dropoffLat, widget.dropoffLng));
    if (_driverLatLng != null) pts.add(_driverLatLng!);
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pts) {
      minLat = (minLat == null) ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = (maxLat == null) ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = (minLng == null) ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = (maxLng == null) ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    if (minLat == null || minLng == null || maxLat == null || maxLng == null) return;
    final double sMinLat = minLat, sMinLng = minLng, sMaxLat = maxLat, sMaxLng = maxLng;
    final bounds = LatLngBounds(
      southwest: LatLng(sMinLat, sMinLng),
      northeast: LatLng(sMaxLat, sMaxLng),
    );
    final controller = _map; // copy to local for sound null-safety promotion
    if (controller == null) return;
    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    } catch (_) {}
  }

  Future<void> _loadRideDetailsIfMissing() async {
    final hasModel = _vehicleModel != null && _vehicleModel!.trim().isNotEmpty;
    final hasPlate = _vehiclePlate != null && _vehiclePlate!.trim().isNotEmpty;
    final hasType = _vehicleType != null && _vehicleType!.trim().isNotEmpty;
    if (hasModel && hasPlate && hasType) return;
    try {
      debugPrint('[RideTracking] fetching ride details for ${widget.rideId}');
      final ride = await DriversApiService.getRideById(widget.rideId);
      debugPrint('[RideTracking] fetched ride: ' + (ride?.toString() ?? 'null'));
      if (ride == null) return;
      if (!mounted) return;
      setState(() {
        _vehicleModel = (ride['vehicleModel'] as String?) ?? (ride['vehicle_model'] as String?);
        _vehiclePlate = (ride['vehiclePlate'] as String?) ?? (ride['vehicle_plate'] as String?) ?? (ride['plate'] as String?);
        _vehicleType = (ride['vehicleType'] as String?) ?? (ride['vehicle_type'] as String?);
      });
      debugPrint('[RideTracking] after fetch vehicleModel=${_vehicleModel}, plate=${_vehiclePlate}, type=${_vehicleType}');
    } catch (_) {}
  }

  // Load custom car icon for driver marker
  Future<void> _loadDriverIcon() async {
    try {
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(devicePixelRatio: 2.5),
        'assets/Car.png',
      );
      if (!mounted) return;
      setState(() {
        _driverIcon = icon;
      });
      // Refresh marker to apply icon if position already set
      _setOrUpdateDriverMarker();
    } catch (_) {}
  }

  // Bearing helpers to rotate the car marker toward movement direction
  double _degToRad(double deg) => deg * (math.pi / 180.0);
  double _radToDeg(double rad) => rad * (180.0 / math.pi);
  double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = _degToRad(from.latitude);
    final lon1 = _degToRad(from.longitude);
    final lat2 = _degToRad(to.latitude);
    final lon2 = _degToRad(to.longitude);
    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x);
    return (_radToDeg(brng) + 360.0) % 360.0;
  }

  // Build or update route polyline: before arrival -> driver to pickup, after arrival -> driver to dropoff
  Future<void> _rebuildRoute() async {
    if (_driverLatLng == null) return;
    final from = _driverLatLng!;
    final to = _driverArrived ? LatLng(widget.dropoffLat, widget.dropoffLng) : LatLng(widget.pickupLat, widget.pickupLng);
    try {
      final points = await _fetchRoute(from, to);
      if (!mounted) return;
      setState(() {
        _polylines.removeWhere((p) => p.polylineId.value == 'route');
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          color: const Color(0xFF2563EB),
          width: 6,
          points: points,
        ));
      });
    } catch (_) {
      // swallow; keep old route if any
    }
  }

  // Use OSRM public demo server to compute a driving route between from -> to
  Future<List<LatLng>> _fetchRoute(LatLng from, LatLng to) async {
    final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=polyline');
    final res = await http.get(url).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return [];
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = map['routes'] as List?;
    if (routes == null || routes.isEmpty) return [];
    final geometry = routes.first['geometry'] as String?;
    if (geometry == null || geometry.isEmpty) return [];
    return _decodePolyline(geometry);
  }

  // Polyline decoding per Google Encoded Polyline Algorithm
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }

  void _maybeStartDriverLocationTimer() {
    if (widget.role != RideTrackingRole.driver) return;
    if (!_inTrip) return;
    _driverLocationTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final pos = await LocationService.instance.getCurrentLocation();
      if (pos == null) return;
      setState(() {
        _driverLatLng = LatLng(pos.latitude, pos.longitude);
        _setOrUpdateDriverMarker();
      });
      await _rebuildRoute();
      await DriversApiService.sendDriverLocation(
        rideId: widget.rideId,
        passengerId: widget.passengerId,
        lat: pos.latitude,
        lng: pos.longitude,
      );
    });
  }

  @override
  void dispose() {
    _driverLocationTimer?.cancel();
    _socketLocSub?.cancel();
    super.dispose();
  }

  CameraPosition get _initialCamera => CameraPosition(target: LatLng(widget.pickupLat, widget.pickupLng), zoom: 14);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_inTrip
            ? (widget.role == RideTrackingRole.driver ? 'Pickup Navigation' : 'Your Ride')
            : (widget.role == RideTrackingRole.driver ? 'Pre-Trip' : 'Driver Assigned')),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _inTrip
                  ? GoogleMap(
                      initialCameraPosition: _initialCamera,
                      onMapCreated: (c) => _map = c,
                      markers: _markers,
                      polylines: _polylines,
                      myLocationEnabled: widget.role == RideTrackingRole.driver,
                      myLocationButtonEnabled: true,
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(CupertinoIcons.clock, size: 36, color: Color(0xFF3B82F6)),
                          SizedBox(height: 8),
                          Text('Trip not started yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
            ),
            _buildBottomSheet(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    if (widget.role == RideTrackingRole.passenger) {
      return _PassengerSheet(
        driverName: widget.driverName,
        driverPhotoUrl: widget.driverPhotoUrl,
        vehicleModel: _vehicleModel,
        vehiclePlate: _vehiclePlate,
        vehicleType: _vehicleType,
        fareKes: widget.fareKes,
        pickupAddress: widget.pickupAddress,
        dropoffAddress: widget.dropoffAddress,
        passengersCount: widget.passengersCount,
        onCall: () => _callNumber(widget.driverId),
        onMessage: () => _openChatWith(widget.driverId, context),
        driverArrived: _driverArrived,
        onCancel: _cancelRide,
      );
    }
    // driver view
    return _DriverSheet(
      passengerName: widget.passengerName ?? 'Passenger',
      passengerPhotoUrl: widget.passengerPhotoUrl,
      pickupAddress: widget.pickupAddress,
      dropoffAddress: widget.dropoffAddress,
      fareKes: widget.fareKes,
      passengersCount: widget.passengersCount,
      onCall: () => _callNumber(widget.passengerId),
      onMessage: () => _openChatWith(widget.passengerId, context),
      inTrip: _inTrip,
      onStart: () async {
        try {
          await DriversApiService.startRide(rideId: widget.rideId, passengerId: widget.passengerId);
          if (!mounted) return;
          setState(() => _inTrip = true);
          _maybeStartDriverLocationTimer();
        } catch (_) {
          if (context.mounted) {
            VAppAlert.showErrorSnackBar(context: context, message: 'Failed to start trip');
          }
        }
      },
      onArrived: () async {
        if (!_driverArrived) {
          await DriversApiService.driverArrived(rideId: widget.rideId, passengerId: widget.passengerId);
          if (!mounted) return;
          setState(() {
            _driverArrived = true;
          });
          await _rebuildRoute();
          VAppAlert.showSuccessSnackBar(context: context, message: "Marked as arrived");
        } else {
          await DriversApiService.completeRide(rideId: widget.rideId, passengerId: widget.passengerId);
          if (!mounted) return;
          VAppAlert.showSuccessSnackBar(context: context, message: "Trip completed");
          // Ask driver to rate passenger before closing
          await _promptRatingAndClose(rateeId: widget.passengerId);
        }
      },
      onCancel: _cancelRide,
    );
  }

  Future<void> _openChatWith(String peerId, BuildContext context) async {
    try {
      await VChatController.I.roomApi.openChatWith(peerId: peerId);
    } catch (_) {}
  }

  Future<void> _callNumber(String userId) async {
    try {
      String? rid;
      try {
        final room = await VChatController.I.nativeApi.local.room.getRoomByPeerId(userId);
        rid = room?.id;
      } catch (_) {}
      if (rid == null) {
        try {
          await VChatController.I.roomApi.openChatWith(peerId: userId);
          final room = await VChatController.I.nativeApi.local.room.getRoomByPeerId(userId);
          rid = room?.id;
        } catch (_) {}
      }
      if (rid == null) {
        if (!mounted) return;
        VAppAlert.showErrorSnackBar(context: context, message: 'Unable to start call');
        return;
      }
      final bool isPassenger = widget.role == RideTrackingRole.passenger;
      final String name = isPassenger ? widget.driverName : (widget.passengerName ?? 'Passenger');
      final String image = (isPassenger ? (widget.driverPhotoUrl ?? '') : (widget.passengerPhotoUrl ?? ''));
      await VChatController.I.vNavigator.callNavigator.toCall(
        context,
        VCallDto(
          isVideoEnable: false,
          isCaller: true,
          roomId: rid,
          peerUser: SBaseUser(userImage: image, fullName: name, id: userId),
        ),
      );
    } catch (_) {}
  }

  Future<void> _cancelRide() async {
    try {
      await DriversApiService.cancelRide(rideId: widget.rideId);
    } catch (_) {}
    if (!mounted) return;
    VAppAlert.showErrorSnackBar(context: context, message: 'Ride canceled');
    if (widget.role == RideTrackingRole.passenger) {
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const OrbitRideView()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const DriverDashboardView()),
        (route) => false,
      );
    }
  }
}

class _PassengerSheet extends StatelessWidget {
  final String driverName;
  final String? driverPhotoUrl;
  final String? vehicleModel;
  final String? vehiclePlate;
  final String? vehicleType;
  final double fareKes;
  final String pickupAddress;
  final String dropoffAddress;
  final int passengersCount;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final bool driverArrived;
  final VoidCallback onCancel;
  const _PassengerSheet({
    required this.driverName,
    required this.driverPhotoUrl,
    required this.vehicleModel,
    required this.vehiclePlate,
    this.vehicleType,
    required this.fareKes,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.passengersCount,
    required this.onCall,
    required this.onMessage,
    required this.driverArrived,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: (driverPhotoUrl != null && driverPhotoUrl!.isNotEmpty) ? NetworkImage(driverPhotoUrl!) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driverName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(
                      '${((vehicleModel != null && vehicleModel!.trim().isNotEmpty) ? vehicleModel!.trim() : ((vehicleType != null && vehicleType!.trim().isNotEmpty) ? vehicleType!.trim() : 'Car'))}'
                      '${(vehiclePlate != null && vehiclePlate!.trim().isNotEmpty) ? ' • ${vehiclePlate!.trim()}' : ''}',
                      style: const TextStyle(color: Colors.black),
                    ),
                    const SizedBox(height: 2),
                    const Text('Rating 4.9', style: TextStyle(color: Colors.black)),
                  ],
                ),
              ),
              Text('KES ${fareKes.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(CupertinoIcons.person_2_fill, size: 18, color: Color(0xFFB48648)),
            const SizedBox(width: 8),
            Text(
              '${(passengersCount <= 0 ? 1 : passengersCount)} passenger${(passengersCount <= 1) ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(CupertinoIcons.location_solid, size: 18, color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            Expanded(child: Text(pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(CupertinoIcons.map_pin_ellipse, size: 18, color: Color(0xFF22C55E)),
            const SizedBox(width: 8),
            Expanded(child: Text(dropoffAddress, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: CupertinoButton(color: const Color(0xFF2563EB), onPressed: onMessage, child: const Text('Message', style: TextStyle(color: Colors.white)))),
            const SizedBox(width: 10),
            Expanded(child: CupertinoButton(color: const Color(0xFF22C55E), onPressed: onCall, child: const Text('Call', style: TextStyle(color: Colors.white)))),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: const Color(0xFFEF4444),
              onPressed: onCancel,
              child: const Text('Cancel ride', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverSheet extends StatelessWidget {
  final String passengerName;
  final String? passengerPhotoUrl;
  final String pickupAddress;
  final String dropoffAddress;
  final double fareKes;
  final int passengersCount;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final bool inTrip;
  final VoidCallback onStart;
  final VoidCallback onArrived;
  final VoidCallback onCancel;
  const _DriverSheet({
    required this.passengerName,
    required this.passengerPhotoUrl,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.fareKes,
    required this.passengersCount,
    required this.onCall,
    required this.onMessage,
    required this.inTrip,
    required this.onStart,
    required this.onArrived,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: (passengerPhotoUrl != null && passengerPhotoUrl!.isNotEmpty) ? NetworkImage(passengerPhotoUrl!) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(passengerName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const Text('Rating 4.9', style: TextStyle(color: Colors.black)),
                  ],
                ),
              ),
              Text('KES ${fareKes.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(CupertinoIcons.person_2_fill, size: 18, color: Color(0xFFB48648)),
            const SizedBox(width: 8),
            Text(
              '${(passengersCount <= 0 ? 1 : passengersCount)} passenger${(passengersCount <= 1) ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(CupertinoIcons.location_solid, size: 18, color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            Expanded(child: Text(pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(CupertinoIcons.map_pin_ellipse, size: 18, color: Color(0xFF22C55E)),
            const SizedBox(width: 8),
            Expanded(child: Text(dropoffAddress, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: CupertinoButton(color: const Color(0xFF2563EB), onPressed: onMessage, child: const Text('Message', style: TextStyle(color: Colors.white)))),
            const SizedBox(width: 10),
            Expanded(child: CupertinoButton(color: const Color(0xFF22C55E), onPressed: onCall, child: const Text('Call', style: TextStyle(color: Colors.white)))),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: const Color(0xFFB48648),
              onPressed: inTrip ? onArrived : onStart,
              child: Text(
                // Change button text depending on stage
                inTrip
                    ? ((context.findAncestorStateOfType<_RideTrackingViewState>()?._driverArrived ?? false)
                        ? 'Complete trip'
                        : "I'm arrived")
                    : 'Start Trip',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: const Color(0xFFEF4444),
              onPressed: onCancel,
              child: const Text('Cancel ride', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
