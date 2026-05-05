import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:super_up/app/modules/ride/views/ride_tracking_view.dart';
import 'package:super_up/app/core/api_service/drivers/drivers_api_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import '../../../main.dart';

class RideSocketService {
  RideSocketService._();
  static final RideSocketService instance = RideSocketService._();
  bool _bound = false;

  void init() {
    if (_bound) return;
    try {
      final socket = VChatController.I.nativeApi.remote.socketIo.socket;
      socket.off('ride_assigned');
      socket.on('ride_assigned', (data) async {
        print('[RideSocket] ride_assigned raw: ' + data.toString());
        try {
          Map<String, dynamic>? map;
          if (data is Map) {
            map = Map<String, dynamic>.from(data);
          } else if (data is String) {
            final decoded = jsonDecode(data);
            if (decoded is Map) {
              map = Map<String, dynamic>.from(decoded);
            }
          }
          if (map == null) return;
          final m = map;
          print('[RideSocket] decoded keys: ' + m.keys.join(','));
          print('[RideSocket] vehicleModel(p): ' + (m['vehicleModel']?.toString() ?? 'null') + ', vehiclePlate(p): ' + (m['vehiclePlate']?.toString() ?? 'null'));
          // Navigate passenger to tracking view
          final ctxNav = navigatorKey.currentState;
          if (ctxNav == null) return;
          // Defensive extraction for vehicle fields
          final vehicleModel = (m['vehicleModel'] as String?) ?? (m['vehicle_model'] as String?) ?? (m['carModel'] as String?);
          final vehiclePlate = (m['vehiclePlate'] as String?) ?? (m['plateNumber'] as String?) ?? (m['vehicle_plate'] as String?) ?? (m['plate'] as String?);
          final vehicleType = (m['vehicleType'] as String?) ?? (m['vehicle_type'] as String?);

          String rid = (m['rideId'] ?? '') as String? ?? '';
          if ((vehicleModel == null || vehicleModel.isEmpty) || (vehiclePlate == null || vehiclePlate.isEmpty)) {
            print('[RideSocket] missing vehicle fields, fetching ride $rid');
            try {
              final ride = await DriversApiService.getRideById(rid);
              print('[RideSocket] fetched ride: ' + (ride?.toString() ?? 'null'));
              if (ride != null) {
                m['vehicleModel'] = ride['vehicleModel'] ?? ride['vehicle_model'];
                m['vehiclePlate'] = ride['vehiclePlate'] ?? ride['vehicle_plate'] ?? ride['plate'];
                m['vehicleType'] = ride['vehicleType'] ?? ride['vehicle_type'];
              }
            } catch (_) {}
          }
          ctxNav.push(CupertinoPageRoute(
            builder: (_) => RideTrackingView(
              role: RideTrackingRole.passenger,
              rideId: rid,
              passengerId: AppAuth.myProfile.baseUser.id,
              driverId: (m['driverId'] ?? '') as String? ?? '',
              driverName: (m['driverName'] ?? '') as String? ?? '',
              driverPhotoUrl: (m['driverPhotoUrl'] as String?),
              vehicleModel: (m['vehicleModel'] as String?) ?? vehicleModel,
              vehiclePlate: (m['vehiclePlate'] as String?) ?? vehiclePlate,
              vehicleType: (m['vehicleType'] as String?) ?? vehicleType,
              fareKes: (m['fareKes'] as num?)?.toDouble() ?? 0,
              pickupAddress: (m['pickupAddress'] ?? '') as String? ?? '',
              dropoffAddress: (m['dropoffAddress'] ?? '') as String? ?? '',
              pickupLat: (m['pickupLat'] as num).toDouble(),
              pickupLng: (m['pickupLng'] as num).toDouble(),
              dropoffLat: (m['dropoffLat'] as num).toDouble(),
              dropoffLng: (m['dropoffLng'] as num).toDouble(),
              rideType: (m['rideType'] as String?),
              passengersCount: ((m['passengersCount'] as num?) ?? (m['passengers_count'] as num?))?.toInt() ?? 1,
              acceptedByDriver: true,
              preTrip: (m['preTrip'] == true),
            ),
          ));
        } catch (e) {
          // ignore
        }
      });
      _bound = true;
    } catch (_) {}
  }
}
