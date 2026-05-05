// Copyright 2024, Orbit App
// Firebase Phone Authentication Service for WEB
// Uses Firebase JS SDK loaded in index.html

import 'dart:async';
import 'package:flutter/foundation.dart';

// Conditional imports - only import web libraries on web platform
import 'firebase_auth_service_web_stub.dart'
    if (dart.library.html) 'firebase_auth_service_web_impl.dart';

/// Firebase Auth service for Web platform only
/// This is a stub class that delegates to platform-specific implementation
class FirebaseAuthServiceWeb {
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
    required Function() onAutoVerified,
  }) async {
    if (!kIsWeb) {
      onError('Firebase Phone Auth Web only works on web platform');
      return;
    }
    return FirebaseAuthServiceWebImpl.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
      onAutoVerified: onAutoVerified,
    );
  }

  static Future<String?> verifyCode(String smsCode) async {
    if (!kIsWeb) throw Exception('Not available on this platform');
    return FirebaseAuthServiceWebImpl.verifyCode(smsCode);
  }

  static Future<void> resendCode({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
  }) async {
    if (!kIsWeb) return;
    return FirebaseAuthServiceWebImpl.resendCode(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
    );
  }

  static Future<void> signOut() async {
    if (!kIsWeb) return;
    return FirebaseAuthServiceWebImpl.signOut();
  }

  static dynamic get currentUser {
    if (!kIsWeb) return null;
    return FirebaseAuthServiceWebImpl.currentUser;
  }

  static bool get isSignedIn {
    if (!kIsWeb) return false;
    return FirebaseAuthServiceWebImpl.isSignedIn;
  }

  static Future<String?> getIdToken() async {
    if (!kIsWeb) return null;
    return FirebaseAuthServiceWebImpl.getIdToken();
  }

  static void clearState() {
    if (!kIsWeb) return;
    FirebaseAuthServiceWebImpl.clearState();
  }

  static bool get isAvailable {
    if (!kIsWeb) return false;
    return FirebaseAuthServiceWebImpl.isAvailable;
  }
}
