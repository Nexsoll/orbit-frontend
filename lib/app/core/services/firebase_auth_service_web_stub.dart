// Copyright 2024, Orbit App
// Stub for non-web platforms

import 'package:flutter/foundation.dart';

class FirebaseAuthServiceWebImpl {
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
    required Function() onAutoVerified,
  }) async {
    onError('Not available on this platform');
  }

  static Future<String?> verifyCode(String smsCode) async {
    throw Exception('Not available on this platform');
  }

  static Future<void> resendCode({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
  }) async {}

  static Future<void> signOut() async {}

  static dynamic get currentUser => null;

  static bool get isSignedIn => false;

  static Future<String?> getIdToken() async => null;

  static void clearState() {}

  static bool get isAvailable => false;
}
