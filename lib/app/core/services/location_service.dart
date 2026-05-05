import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  Position? _currentPosition;
  DateTime? _lastLocationUpdate;

  Position? get currentPosition => _currentPosition;
  bool get hasLocation => _currentPosition != null;

  /// Get current location with permission handling
  Future<Position?> getCurrentLocation({bool forceRefresh = false}) async {
    try {
      // Check if we have a recent location (less than 5 minutes old)
      if (!forceRefresh && 
          _currentPosition != null && 
          _lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!).inMinutes < 5) {
        return _currentPosition;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        log('Location services are disabled.');
        // Try last known as a graceful fallback
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) {
            _currentPosition = last;
            _lastLocationUpdate = DateTime.now();
          }
          return last;
        } catch (_) {
          return null;
        }
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          log('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        log('Location permissions are permanently denied');
        return null;
      }

      // Get current position with a hard timeout guard to avoid hanging on web
      // Some browsers keep the permission prompt pending indefinitely; we bail out
      // after a short timeout and fall back to last known if available
      try {
        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        ).timeout(const Duration(seconds: 12));
      } on TimeoutException catch (e) {
        log('getCurrentPosition timeout: $e');
        _currentPosition = await Geolocator.getLastKnownPosition();
        if (_currentPosition == null && kIsWeb) {
          // As a final web-only fallback, try a low-accuracy position stream once
          try {
            _currentPosition = await Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                distanceFilter: 50,
              ),
            ).first.timeout(const Duration(seconds: 5));
          } catch (_) {}
        }
      } catch (e) {
        log('Error getting current position: $e');
        _currentPosition = await Geolocator.getLastKnownPosition();
      }

      _lastLocationUpdate = DateTime.now();

      log('Location updated: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      return _currentPosition;
    } catch (e) {
      log('Error getting location: $e');
      return null;
    }
  }

  /// Calculate distance between two points in kilometers
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    ) / 1000; // Convert meters to kilometers
  }

  /// Format distance for display
  String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceKm.round()}km';
    }
  }

  /// Check if location permissions are granted
  Future<bool> hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  /// Open app settings for location permissions
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app settings for app permissions
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
