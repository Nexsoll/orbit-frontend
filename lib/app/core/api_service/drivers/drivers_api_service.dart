// Drivers API Service (mobile app)
// Provides endpoints to submit a driver application and check latest status

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/api_service/exceptions.dart';

class DriversApiService {
  static Map<String, String> _headers() {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> myRideBanStatus() async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/drivers/ride/ban-status',
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(exception: (err['data'] ?? err['message'] ?? 'Failed').toString());
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Failed with status ${res.statusCode}');
      }
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    return data ?? <String, dynamic>{};
  }

  // POST /rides/:rideId/start
  static Future<void> startRide({
    required String rideId,
    required String passengerId,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/$rideId/start',
    );
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'rideId': rideId, 'passengerId': passengerId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return;
    }
  }

  // POST /rides/scheduled/:id/reschedule
  static Future<void> rescheduleScheduledRide({required String id, required String scheduledAtIso}) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/scheduled/$id/reschedule',
    );
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'scheduledAt': scheduledAtIso}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // best-effort for now
      return;
    }
  }

  // POST /rides/schedule => {id}
  static Future<String> scheduleRide({
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required double fareKes,
    String? rideType,
    String paymentMethod = 'cash',
    int passengersCount = 1,
    required String scheduledAtIso,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/schedule',
    );
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'pickupAddress': pickupAddress,
        'dropoffAddress': dropoffAddress,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropoffLat': dropoffLat,
        'dropoffLng': dropoffLng,
        'fareKes': fareKes,
        'paymentMethod': paymentMethod,
        'passengersCount': passengersCount,
        if (rideType != null) 'rideType': rideType,
        'scheduledAt': scheduledAtIso,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(exception: (err['data'] ?? err['message'] ?? 'Failed').toString());
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Failed with status ${res.statusCode}');
      }
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    return (data['id'] ?? '').toString();
  }

  // GET /rides/scheduled
  static Future<List<Map<String, dynamic>>> getScheduledRides() async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/scheduled',
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final list = decoded['data'] as List?;
      if (list == null) return const [];
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return const [];
    }
  }

  // POST /rides/scheduled/:id/cancel
  static Future<void> cancelScheduledRide(String id) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/scheduled/$id/cancel',
    );
    final res = await http.post(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // best-effort
      return;
    }
  }

  // GET /rides/history?role=driver|passenger
  static Future<List<Map<String, dynamic>>> rideHistory({required String role}) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/history',
      queryParameters: {'role': role},
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final list = decoded['data'] as List?;
      if (list == null) return const [];
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return const [];
    }
  }

  // POST /rides/:rideId/cancel
  static Future<void> cancelRide({
    required String rideId,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/$rideId/cancel',
    );
    final res = await http.post(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return; // best-effort
    }
  }

  // GET /profile/:id => extract phoneNumber
  static Future<String?> getUserPhone(String userId) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/profile/$userId',
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>?;
      final phone = data?['phoneNumber']?.toString();
      return (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null;
    } catch (_) {
      return null;
    }
  }

  // GET /rides/:rideId => ride details
  static Future<Map<String, dynamic>?> getRideById(String rideId) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/$rideId',
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return decoded['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // POST /drivers/applications
  static Future<Map<String, dynamic>> createApplication({
    required String vehicleType,
    required String vehicleModel,
    required String vehiclePlate,
    int? vehicleCapacity,
    String? idImageUrl,
    String? selfieImageUrl,
    String? licenseUrl,
    String? logbookUrl,
    String? insuranceUrl,
    String? inspectionUrl,
    String? kraPinUrl,
    String? vehicleImageUrl,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/drivers/applications',
    );
    final body = {
      'vehicleType': vehicleType,
      'vehicleModel': vehicleModel,
      'vehiclePlate': vehiclePlate,
      if (vehicleCapacity != null) 'vehicleCapacity': vehicleCapacity,
      if (idImageUrl != null) 'idImageUrl': idImageUrl,
      if (selfieImageUrl != null) 'selfieImageUrl': selfieImageUrl,
      if (licenseUrl != null) 'licenseUrl': licenseUrl,
      if (logbookUrl != null) 'logbookUrl': logbookUrl,
      if (insuranceUrl != null) 'insuranceUrl': insuranceUrl,
      if (inspectionUrl != null) 'inspectionUrl': inspectionUrl,
      if (kraPinUrl != null) 'kraPinUrl': kraPinUrl,
      if (vehicleImageUrl != null) 'vehicleImageUrl': vehicleImageUrl,
    };
    final res = await http.post(uri, headers: _headers(), body: jsonEncode(body));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(exception: (err['data'] ?? err['message'] ?? 'Submit failed').toString());
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Submit failed with status ${res.statusCode}');
      }
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>;
  }

  // GET /drivers/applications/my-latest
  static Future<Map<String, dynamic>?> myLatest() async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/drivers/applications/my-latest',
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(exception: (err['data'] ?? err['message'] ?? 'Failed').toString());
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Failed with status ${res.statusCode}');
      }
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>?;
  }

  // POST /drivers/presence/online
  static Future<void> presenceOnline({
    required double lat,
    required double lng,
    String? vehicleType,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/drivers/presence/online',
    );
    final body = jsonEncode({
      'lat': lat,
      'lng': lng,
      if (vehicleType != null) 'vehicleType': vehicleType,
    });
    final res = await http.post(uri, headers: _headers(), body: body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(exception: (err['data'] ?? err['message'] ?? 'Failed').toString());
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Failed with status ${res.statusCode}');
      }
    }
  }

  // POST /drivers/presence/offline
  static Future<void> presenceOffline() async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/drivers/presence/offline',
    );
    final res = await http.post(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(exception: (err['data'] ?? err['message'] ?? 'Failed').toString());
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Failed with status ${res.statusCode}');
      }
    }
  }

  // POST /rides/request => {dispatched: number}
  static Future<int> sendRideRequest({
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required double fareKes,
    String? rideType,
    String paymentMethod = 'cash',
    int passengersCount = 1,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/request',
    );
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'pickupAddress': pickupAddress,
        'dropoffAddress': dropoffAddress,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropoffLat': dropoffLat,
        'dropoffLng': dropoffLng,
        'fareKes': fareKes,
        'paymentMethod': paymentMethod,
        'passengersCount': passengersCount,
        if (rideType != null) 'rideType': rideType,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(exception: (err['data'] ?? err['message'] ?? 'Failed').toString());
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Failed with status ${res.statusCode}');
      }
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    return (data['dispatched'] as num?)?.toInt() ?? 0;
  }

  // POST /rides/accept => {rideId}
  static Future<String> acceptRide({
    required String requestId,
    required String passengerId,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required double fareKes,
    String? rideType,
    int passengersCount = 1,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/accept',
    );
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'requestId': requestId,
        'passengerId': passengerId,
        'pickupAddress': pickupAddress,
        'dropoffAddress': dropoffAddress,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropoffLat': dropoffLat,
        'dropoffLng': dropoffLng,
        'fareKes': fareKes,
        'passengersCount': passengersCount,
        if (rideType != null) 'rideType': rideType,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw SuperHttpBadRequest(exception: (err['data'] ?? err['message'] ?? 'Failed').toString());
      } catch (_) {
        throw SuperHttpBadRequest(exception: 'Failed with status ${res.statusCode}');
      }
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    return (data['rideId'] ?? '').toString();
  }

  // POST /rides/:rideId/driver-location
  static Future<void> sendDriverLocation({
    required String rideId,
    required String passengerId,
    required double lat,
    required double lng,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/$rideId/driver-location',
    );
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'rideId': rideId, 'passengerId': passengerId, 'lat': lat, 'lng': lng}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // best-effort: don't throw, just log
      return;
    }
  }

  // POST /rides/:rideId/arrived
  static Future<void> driverArrived({
    required String rideId,
    required String passengerId,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/$rideId/arrived',
    );
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'rideId': rideId, 'passengerId': passengerId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return;
    }
  }

  // POST /rides/:rideId/complete
  static Future<void> completeRide({
    required String rideId,
    required String passengerId,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/rides/$rideId/complete',
    );
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'rideId': rideId, 'passengerId': passengerId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return;
    }
  }

  // POST /ratings/submit
  static Future<void> submitRating({
    required String rideId,
    required String rateeId,
    required int stars,
    String? comment,
  }) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/ratings/submit',
    );
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'rideId': rideId,
        'rateeId': rateeId,
        'stars': stars,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // best-effort, don't throw
      return;
    }
  }

  // GET /ratings/me => {avg, count}
  static Future<Map<String, dynamic>> myRatingSummary() async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/ratings/me',
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) return {'avg': 0.0, 'count': 0};
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (decoded['data'] as Map<String, dynamic>?);
    return data ?? {'avg': 0.0, 'count': 0};
  }

  // GET /ratings/summary/:userId => {avg, count}
  static Future<Map<String, dynamic>> ratingSummaryOf(String userId) async {
    final uri = SConstants.sApiBaseUrl.replace(
      path: SConstants.sApiBaseUrl.path + '/ratings/summary/$userId',
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) return {'avg': 0.0, 'count': 0};
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (decoded['data'] as Map<String, dynamic>?);
    return data ?? {'avg': 0.0, 'count': 0};
  }
}
