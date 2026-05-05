// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

/// Service for managing live location sharing
class LiveLocationService {
  static LiveLocationService? _instance;
  static LiveLocationService get instance => _instance ??= LiveLocationService._();
  LiveLocationService._();

  /// Active live location sessions keyed by messageId
  final Map<String, LiveLocationSession> _activeSessions = {};

  /// Stream controller for location updates
  final _locationUpdateController = StreamController<LiveLocationUpdate>.broadcast();
  Stream<LiveLocationUpdate> get locationUpdates => _locationUpdateController.stream;

  StreamSubscription? _insertSub;

  /// Start sharing live location
  Future<void> startLiveLocation({
    required String roomId,
    required String messageId,
    required int durationMinutes,
    required LatLng initialLocation,
  }) async {
    log('Starting live location: roomId=$roomId, messageId=$messageId, duration=$durationMinutes');

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    // Create session
    final session = LiveLocationSession(
      roomId: roomId,
      messageId: messageId,
      durationMinutes: durationMinutes,
      startedAt: DateTime.now(),
      endsAt: DateTime.now().add(Duration(minutes: durationMinutes)),
    );

    _activeSessions[messageId] = session;

    // Emit start event via socket
    final socket = VChatController.I.nativeApi.remote.socketIo.socket;
    socket.emit('v1LiveLocationStart', {
      'roomId': roomId,
      'messageId': messageId,
      'duration': durationMinutes,
      'lat': initialLocation.latitude.toString(),
      'long': initialLocation.longitude.toString(),
    });

    // Start location updates
    _startLocationUpdates(messageId);

    // Auto-stop after duration
    Future.delayed(Duration(minutes: durationMinutes), () {
      stopLiveLocation(messageId);
    });
  }

  /// Start sending location updates
  void _startLocationUpdates(String messageId) {
    final session = _activeSessions[messageId];
    if (session == null) return;

    // Ensure any previous stream is cancelled
    session.positionSub?.cancel();

    // Hard stop at expiry
    session.timer?.cancel();
    session.timer = Timer(session.endsAt.difference(DateTime.now()), () {
      stopLiveLocation(messageId);
    });

    // Subscribe to location stream and throttle updates
    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // meters
    );

    session.positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) async {
        if (!_activeSessions.containsKey(messageId)) return;
        if (!session.isActive) {
          await stopLiveLocation(messageId);
          return;
        }

        final now = DateTime.now();
        if (session.lastSentAt != null &&
            now.difference(session.lastSentAt!).inSeconds < 5) {
          return;
        }
        session.lastSentAt = now;

        final latLng = LatLng(position.latitude, position.longitude);

        try {
          final socket = VChatController.I.nativeApi.remote.socketIo.socket;
          socket.emit('v1LiveLocationUpdate', {
            'roomId': session.roomId,
            'messageId': messageId,
            'lat': position.latitude.toString(),
            'long': position.longitude.toString(),
          });

          // Also update my own local message so my bubble updates too
          await _applyLocationToMessage(
            messageLocalId: messageId,
            newLatLng: latLng,
          );

          log('Live location update sent: ${position.latitude}, ${position.longitude}');
        } catch (e) {
          log('Error emitting live location update: $e');
        }
      },
      onError: (e) {
        log('Live location stream error: $e');
      },
    );
  }

  /// Stop sharing live location
  Future<void> stopLiveLocation(String messageId) async {
    final session = _activeSessions.remove(messageId);
    if (session == null) return;

    session.timer?.cancel();
    await session.positionSub?.cancel();

    // Emit stop event via socket
    final socket = VChatController.I.nativeApi.remote.socketIo.socket;
    socket.emit('v1LiveLocationStop', {
      'roomId': session.roomId,
      'messageId': messageId,
    });

    log('Live location stopped: $messageId');
  }

  /// Stop all active sessions
  void stopAllSessions() {
    for (final messageId in _activeSessions.keys.toList()) {
      stopLiveLocation(messageId);
    }
  }

  /// Listen for incoming live location updates
  void listenForUpdates() {
    final socket = VChatController.I.nativeApi.remote.socketIo.socket;

    // Auto-start sender tracking when I send a live location message
    _insertSub ??= VEventBusSingleton.vEventBus.on<VInsertMessageEvent>().listen(
      (event) async {
        try {
          final msg = event.messageModel;
          if (msg is! VLocationMessage) return;
          if (!msg.isMeSender) return;
          if (!msg.data.isLive) return;
          if (!msg.data.isLiveActive) return;

          // Prevent duplicate session
          if (_activeSessions.containsKey(msg.localId)) return;

          final duration = msg.data.duration ?? 15;
          await startLiveLocation(
            roomId: msg.roomId,
            messageId: msg.localId,
            durationMinutes: duration,
            initialLocation: msg.data.latLng,
          );
        } catch (e) {
          log('LiveLocationService insert handler error: $e');
        }
      },
    );

    // Listen for live location started
    socket.on('v1OnLiveLocationStarted', (data) {
      try {
        final decoded = data is String ? jsonDecode(data) : data;
        log('Live location started received: $decoded');
      } catch (e) {
        log('Error parsing live location started: $e');
      }
    });

    // Listen for location updates
    socket.on('v1OnLiveLocationUpdate', (data) {
      try {
        final decoded = data is String ? jsonDecode(data) : data;
        final update = LiveLocationUpdate(
          roomId: decoded['roomId']?.toString() ?? '',
          messageId: decoded['messageId']?.toString() ?? '',
          senderId: decoded['senderId']?.toString() ?? '',
          lat: double.tryParse(decoded['lat'].toString()) ?? 0,
          long: double.tryParse(decoded['long'].toString()) ?? 0,
          updatedAt: DateTime.now(),
        );
        _locationUpdateController.add(update);
        // Update stored message attachment so UI refreshes
        _applyLocationToMessage(
          messageLocalId: update.messageId,
          newLatLng: update.latLng,
        );
        log('Live location update received: ${update.lat}, ${update.long}');
      } catch (e) {
        log('Error parsing live location update: $e');
      }
    });

    // Listen for live location stopped
    socket.on('v1OnLiveLocationStopped', (data) {
      try {
        final decoded = data is String ? jsonDecode(data) : data;
        log('Live location stopped received: $decoded');
      } catch (e) {
        log('Error parsing live location stopped: $e');
      }
    });
  }

  /// Dispose service
  void dispose() {
    stopAllSessions();
    _insertSub?.cancel();
    _insertSub = null;
    _locationUpdateController.close();
  }

  Future<void> _applyLocationToMessage({
    required String messageLocalId,
    required LatLng newLatLng,
  }) async {
    try {
      final msg = await VChatController.I.nativeApi.local.message
          .getMessageByLocalId(messageLocalId);
      if (msg is! VLocationMessage) return;
      if (!msg.data.isLive) return;

      msg.data = msg.data.copyWithLocation(newLatLng);

      await VChatController.I.nativeApi.local.message.updateFullMessage(msg);
    } catch (e) {
      log('LiveLocationService failed to apply update to message=$messageLocalId err=$e');
    }
  }
}

/// Live location session data
class LiveLocationSession {
  final String roomId;
  final String messageId;
  final int durationMinutes;
  final DateTime startedAt;
  final DateTime endsAt;
  Timer? timer;
  StreamSubscription<Position>? positionSub;
  DateTime? lastSentAt;

  LiveLocationSession({
    required this.roomId,
    required this.messageId,
    required this.durationMinutes,
    required this.startedAt,
    required this.endsAt,
    this.timer,
    this.positionSub,
    this.lastSentAt,
  });

  bool get isActive => DateTime.now().isBefore(endsAt);
}

/// Live location update data
class LiveLocationUpdate {
  final String roomId;
  final String messageId;
  final String senderId;
  final double lat;
  final double long;
  final DateTime updatedAt;

  LiveLocationUpdate({
    required this.roomId,
    required this.messageId,
    required this.senderId,
    required this.lat,
    required this.long,
    required this.updatedAt,
  });

  LatLng get latLng => LatLng(lat, long);
}
