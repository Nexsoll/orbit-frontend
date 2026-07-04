import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/widgets/balance_widget.dart';
import 'package:super_up/app/modules/ride/views/become_driver_view.dart';
import 'package:super_up/app/core/api_service/drivers/drivers_api_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/modules/ride/views/orbit_ride_view.dart';
import 'package:super_up/app/modules/home/mobile/rooms_tab/views/rooms_tab_view.dart';
import 'package:super_up/app/core/services/ride_mode_service.dart';
import 'package:super_up/app/core/services/driver_requests_service.dart';
import 'package:super_up/app/modules/driver/views/vehicle_details_view.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:super_up/app/modules/ride/views/ride_tracking_view.dart';
import 'package:super_up/app/modules/ride/views/ride_history_view.dart';
import 'package:intl/intl.dart';
import 'package:super_up/app/modules/ride/views/favorite_locations_view.dart';
import 'package:super_up/app/modules/ride/views/location_search_view.dart';

class DriverDashboardView extends StatefulWidget {
  const DriverDashboardView({super.key});

  @override
  State<DriverDashboardView> createState() => _DriverDashboardViewState();
}

String _fmtShort(DateTime dt) {
  final f = DateFormat('MMM d, HH:mm');
  return f.format(dt);
}

class _DriverDashboardViewState extends State<DriverDashboardView> {
  bool _isEndDrawerOpen = false;
  bool _isDriverMode = true; // on this screen we are Driver
  bool _becomeDisabled = false;
  bool _isOnline = false;
  bool _socketBound = false;
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

  @override
  void initState() {
    super.initState();
    _bindRideRequestSocket();
    _loadMyRatingSummary();
  }

  void _bindRideRequestSocket() {
    if (_socketBound) return;
    try {
      final socket = VChatController.I.nativeApi.remote.socketIo.socket;
      socket.off('ride_request');
      socket.off('ride_request_removed');
      socket.on('ride_request', (data) {
        try {
          Map<String, dynamic>? map;
          if (data is Map) {
            map = Map<String, dynamic>.from(data);
          } else if (data is String) {
            map = Map<String, dynamic>.from(jsonDecode(data) as Map);
          }
          if (map != null) {
            final req = RideRequestModel(
              id: (map['id'] ?? '').toString(),
              passengerId: (map['passengerId'] ?? '').toString(),
              passengerName: (map['passengerName'] ?? '').toString(),
              passengerPhotoUrl: (map['passengerPhotoUrl'] as String?),
              passengersCount: ((map['passengersCount'] as num?) ?? (map['passengers_count'] as num?))?.toInt() ?? 1,
              pickupAddress: (map['pickupAddress'] ?? '').toString(),
              dropoffAddress: (map['dropoffAddress'] ?? '').toString(),
              pickupLat: (map['pickupLat'] as num).toDouble(),
              pickupLng: (map['pickupLng'] as num).toDouble(),
              dropoffLat: (map['dropoffLat'] as num).toDouble(),
              dropoffLng: (map['dropoffLng'] as num).toDouble(),
              fareKes: (map['fareKes'] as num).toDouble(),
              rideType: (map['rideType'] as String?),
              paymentMethod: (map['paymentMethod'] as String?)?.toLowerCase(),
              isScheduled: (map['isScheduled'] == true),
              scheduledAt: (map['scheduledAt'] != null)
                  ? DateTime.tryParse(map['scheduledAt'].toString())
                  : null,
            );
            final myId = AppAuth.myProfile.baseUser.id;
            DriverRequestsService.instance.onIncomingRequest(driverId: myId, request: req);
          }
        } catch (_) {}
      });
      socket.on('ride_request_removed', (data) {
        try {
          Map<String, dynamic>? map;
          if (data is Map) {
            map = Map<String, dynamic>.from(data);
          } else if (data is String) {
            map = Map<String, dynamic>.from(jsonDecode(data) as Map);
          }
          if (map != null) {
            final reqId = (map['requestId'] ?? '').toString();
            if (reqId.isNotEmpty) {
              final myId = AppAuth.myProfile.baseUser.id;
              DriverRequestsService.instance.removeRequest(driverId: myId, requestId: reqId);
            }
          }
        } catch (_) {}
      });
      _socketBound = true;
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      final socket = VChatController.I.nativeApi.remote.socketIo.socket;
      socket.off('ride_request');
      socket.off('ride_request_removed');
    } catch (_) {}
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final double drawerWidth = math.min(340.0, MediaQuery.of(context).size.width * 0.88);

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _OnlineTile(
          isOnline: _isOnline,
          onToggle: () async {
            final me = AppAuth.myProfile.baseUser;
            if (!_isOnline) {
              // Turn online
              final ok = await DriverRequestsService.instance.goOnline(
                driverId: me.id,
                name: me.fullName,
                avatarUrl: me.userImageS3,
              );
              if (!mounted) return;
              if (ok) {
                setState(() => _isOnline = true);
              } else {
                VAppAlert.showErrorSnackBar(
                  context: context,
                  message: 'Location unavailable. Enable location and try again.',
                );
              }
            } else {
              // Turn offline
              DriverRequestsService.instance.goOffline(me.id);
              if (!mounted) return;
              setState(() => _isOnline = false);
            }
          },
        ),
        const SizedBox(height: 16),
        // Inline requests list
        _RequestsList(driverId: AppAuth.myProfile.baseUser.id),
      ],
    );

    final scaffold = CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).pushReplacement(
              CupertinoPageRoute(builder: (_) => const RoomsTabView()),
            );
          },
          child: const Row(
            children: [
              Icon(CupertinoIcons.chevron_back, color: Color(0xFFB48648)),
              SizedBox(width: 2),
              Text('Ride', style: TextStyle(color: Color(0xFFB48648))),
            ],
          ),
        ),
        middle: const Text('Driver Dashboard'),
        trailing: CupertinoButton(
          padding: const EdgeInsets.all(8),
          onPressed: () {
            _refreshDriverApplicationStatus();
            _loadMyRatingSummary();
            setState(() => _isEndDrawerOpen = true);
          },
          child: const Icon(CupertinoIcons.line_horizontal_3, color: Color(0xFFB48648)),
        ),
      ),
      child: SafeArea(top: false, child: content),
    );

    return Stack(
      children: [
        scaffold,

        // Scrim
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

        // End drawer
        AnimatedPositioned(
          top: 0,
          bottom: 0,
          right: _isEndDrawerOpen ? 0 : -drawerWidth,
          width: drawerWidth,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoTheme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(-6, 0),
                )
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Balance',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(6),
                          onPressed: () => setState(() => _isEndDrawerOpen = false),
                          child: const Icon(CupertinoIcons.xmark, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: BalanceWidget(),
                  ),
                  const SizedBox(height: 16),
                  // Favourite Locations tile
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () async {
                        if (mounted) setState(() => _isEndDrawerOpen = false);
                        final res = await Navigator.of(context).push<LocationSearchResult>(
                          CupertinoPageRoute(builder: (_) => const FavoriteLocationsView()),
                        );
                        if (res != null && context.mounted) {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => OrbitRideView(
                                prefillDropoff: res.latLng,
                                prefillDropoffAddress: res.address,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: const [
                            Icon(CupertinoIcons.placemark_fill, color: Color(0xFFB48648)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Favourite Locations',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Icon(CupertinoIcons.chevron_forward),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Ride History tile
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () {
                        if (mounted) setState(() => _isEndDrawerOpen = false);
                        Navigator.of(context).push(
                          CupertinoPageRoute(builder: (_) => const RideHistoryView(isDriver: true)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: const [
                            Icon(CupertinoIcons.time_solid, color: Color(0xFF3B82F6)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Ride History',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Icon(CupertinoIcons.chevron_forward),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // My Rating summary
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.star_fill, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _myRatingAvg == null
                                  ? 'My Rating'
                                  : 'My Rating: ${_myRatingAvg!.toStringAsFixed(1)} (${_myRatingCount ?? 0})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (AppAuth.myProfile.roles.contains(UserRoles.driver)) ...[
                    // Mode header
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: _isDriverMode ? 1 : 0,
                        children: const {
                          0: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            child: Text('Passenger'),
                          ),
                          1: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            child: Text('Driver'),
                          ),
                        },
                        onValueChanged: (v) {
                          if (v == null) return;
                          if (v == 0) {
                            RideModeService.instance.setDriverMode(false);
                            if (mounted) setState(() => _isEndDrawerOpen = false);
                            Navigator.of(context).pushReplacement(
                              CupertinoPageRoute(builder: (_) => const OrbitRideView()),
                            );
                          } else {
                            RideModeService.instance.setDriverMode(true);
                            setState(() => _isDriverMode = true);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Vehicle Details tile
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () {
                          if (mounted) setState(() => _isEndDrawerOpen = false);
                          Navigator.of(context).push(
                            CupertinoPageRoute(builder: (_) => const VehicleDetailsView()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: const [
                              Icon(CupertinoIcons.car_detailed, color: Color(0xFFB48648)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Vehicle Details',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Icon(CupertinoIcons.chevron_forward),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (!AppAuth.myProfile.roles.contains(UserRoles.driver))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoButton.filled(
                        onPressed: _becomeDisabled ? null : () async {
                          if (mounted) setState(() => _isEndDrawerOpen = false);
                          try {
                            final latest = await DriversApiService.myLatest();
                            if (!mounted) return;
                            final status = latest?['status']?.toString().toLowerCase();
                            if (status == 'pending') {
                              await showCupertinoDialog(
                                context: context,
                                builder: (context) => const CupertinoAlertDialog(
                                  title: Text('Application Pending'),
                                  content: Text('Your driver application is pending review. We will notify you once approved.'),
                                ),
                              );
                              return;
                            }
                            if (status == 'approved') {
                              setState(() => _becomeDisabled = true);
                              await showCupertinoDialog(
                                context: context,
                                builder: (context) => const CupertinoAlertDialog(
                                  title: Text('Application Approved'),
                                  content: Text('Congratulations! You are now approved as a driver.'),
                                ),
                              );
                              return;
                            }
                          } catch (_) {}
                          await Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (context) => const BecomeDriverView()),
                          );
                        },
                        child: const Text('Become Driver'),
                      ),
                    ),

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

class _OnlineTile extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onToggle;
  const _OnlineTile({required this.isOnline, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final Color btnColor = isOnline ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final String btnText = isOnline ? 'Go Offline' : 'Go Online';
    final Color iconTint = isOnline ? const Color(0xFF22C55E) : Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconTint.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.power, color: iconTint),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Go Online', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: btnColor,
            onPressed: onToggle,
            child: Text(
              btnText,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  final String driverId;
  const _RequestsList({required this.driverId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RideRequestModel>>(
      initialData: DriverRequestsService.instance.getDriverRequests(driverId),
      stream: DriverRequestsService.instance.watchDriverRequests(driverId),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            ),
            child: Row(
              children: const [
                Icon(CupertinoIcons.bell, color: Color(0xFF3B82F6)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No ride requests yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (final r in items) ...[
              _RequestCard(driverId: driverId, request: r),
              const SizedBox(height: 12),
            ]
          ],
        );
      },
    );
  }
}

// Ensure we always render a valid absolute URL for media
String? _absImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  // Convert wrongly prefixed file:// URLs coming from backend to absolute http(s)
  if (url.startsWith('file://')) {
    final trimmed = url.substring('file://'.length);
    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    final baseOrigin = '${SConstants.sApiBaseUrl.scheme}://${SConstants.sApiBaseUrl.authority}';
    return '$baseOrigin$normalized';
  }
  final baseOrigin = '${SConstants.sApiBaseUrl.scheme}://${SConstants.sApiBaseUrl.authority}';
  final path = url.startsWith('/') ? url : '/$url';
  return '$baseOrigin$path';
}

class _RequestCard extends StatelessWidget {
  final String driverId;
  final RideRequestModel request;
  const _RequestCard({required this.driverId, required this.request});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _absImageUrl(request.passengerPhotoUrl);
    final isCash = (request.paymentMethod ?? 'cash') == 'cash';
    final pmLabel = isCash ? 'Cash' : 'Online';
    final pmIcon = isCash ? CupertinoIcons.money_dollar_circle : CupertinoIcons.creditcard;
    final pmColor = isCash ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
    final pc = request.passengersCount <= 0 ? 1 : request.passengersCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null)
                    ? Text(request.passengerName.isNotEmpty ? request.passengerName[0].toUpperCase() : '?')
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  request.passengerName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (request.isScheduled) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.time, size: 16, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 6),
                      Text(
                        request.scheduledAt != null
                            ? _fmtShort(request.scheduledAt!)
                            : 'Scheduled',
                        style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text('KES ${request.fareKes.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFB48648).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFB48648).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.person_2_fill, size: 16, color: Color(0xFFB48648)),
                    const SizedBox(width: 6),
                    Text('$pc', style: const TextStyle(color: Color(0xFFB48648), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: pmColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: pmColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(pmIcon, size: 16, color: pmColor),
                    const SizedBox(width: 6),
                    Text(pmLabel, style: TextStyle(color: pmColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(CupertinoIcons.location_solid, size: 18, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(request.pickupAddress, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(CupertinoIcons.map_pin_ellipse, size: 18, color: Color(0xFF22C55E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(request.dropoffAddress, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: const Color(0xFF22C55E),
                  onPressed: () async {
                    // Call backend to accept and create a ride, then navigate to tracking as driver
                    try {
                      final rideId = await DriversApiService.acceptRide(
                        requestId: request.id,
                        passengerId: request.passengerId,
                        pickupAddress: request.pickupAddress,
                        dropoffAddress: request.dropoffAddress,
                        pickupLat: request.pickupLat,
                        pickupLng: request.pickupLng,
                        dropoffLat: request.dropoffLat,
                        dropoffLng: request.dropoffLng,
                        fareKes: request.fareKes,
                        rideType: request.rideType,
                        passengersCount: request.passengersCount,
                      );
                      // Remove the request from lists
                      DriverRequestsService.instance.acceptRequest(
                        driverId: driverId,
                        requestId: request.id,
                      );
                      if (context.mounted) {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => RideTrackingView(
                              role: RideTrackingRole.driver,
                              rideId: rideId,
                              passengerId: request.passengerId,
                              driverId: AppAuth.myProfile.baseUser.id,
                              pickupAddress: request.pickupAddress,
                              dropoffAddress: request.dropoffAddress,
                              pickupLat: request.pickupLat,
                              pickupLng: request.pickupLng,
                              dropoffLat: request.dropoffLat,
                              dropoffLng: request.dropoffLng,
                              fareKes: request.fareKes,
                              rideType: request.rideType,
                              passengersCount: request.passengersCount,
                              // Driver info for passenger-side is not needed here; pass passenger details to driver view
                              driverName: AppAuth.myProfile.baseUser.fullName,
                              passengerName: request.passengerName,
                              passengerPhotoUrl: _absImageUrl(request.passengerPhotoUrl),
                              preTrip: request.id.startsWith('sched_'),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        VAppAlert.showErrorSnackBar(
                          context: context,
                          message: 'Failed to accept ride. Please try again.',
                        );
                      }
                    }
                  },
                  child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoButton(
                  color: const Color(0xFFEF4444),
                  onPressed: () {
                    DriverRequestsService.instance.declineRequest(
                      driverId: driverId,
                      requestId: request.id,
                    );
                  },
                  child: const Text('Decline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
