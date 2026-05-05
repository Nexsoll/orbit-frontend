// Copyright 2024, Orbit App
// Firebase Phone Authentication Service

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static String? _verificationId;
  static int? _resendToken;

  /// Initialize Firebase Auth (call this in main.dart before runApp)
  static void initialize() {
    // Firebase Auth is automatically initialized with Firebase Core
    if (kDebugMode) {
      print('FirebaseAuthService initialized');
    }
  }

  /// Verify phone number and send SMS code
  /// Returns verificationId that will be used to verify the code
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
    required Function() onAutoVerified,
    Function(String verificationId)? onTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval succeeded (Android only)
          if (kDebugMode) {
            print('Phone verification completed automatically');
          }
          onAutoVerified();
        },
        verificationFailed: (FirebaseAuthException e) {
          if (kDebugMode) {
            print('Phone verification failed: ${e.message}');
          }
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          if (kDebugMode) {
            print('Code sent. VerificationId: $verificationId');
          }
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (kDebugMode) {
            print('Code auto-retrieval timeout');
          }
          _verificationId = verificationId;
          onTimeout?.call(verificationId);
        },
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying phone number: $e');
      }
      onError(e.toString());
    }
  }

  /// Resend SMS code
  static Future<void> resendCode({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
  }) async {
    if (_resendToken == null) {
      onError('Cannot resend code yet. Please try again later.');
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval succeeded
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Verify the SMS code entered by user
  /// Returns Firebase ID token that should be sent to backend
  static Future<String?> verifyCode(String smsCode) async {
    try {
      if (_verificationId == null) {
        throw Exception('No verification ID. Please request code again.');
      }

      // Create credential
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      // Sign in with credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Failed to sign in');
      }

      // Get ID token
      final String? idToken = await user.getIdToken();
      return idToken;
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying code: $e');
      }
      rethrow;
    }
  }

  /// Sign out from Firebase Auth
  static Future<void> signOut() async {
    await _auth.signOut();
    _verificationId = null;
    _resendToken = null;
  }

  /// Get current Firebase user
  static User? get currentUser => _auth.currentUser;

  /// Check if user is signed in to Firebase
  static bool get isSignedIn => _auth.currentUser != null;

  /// Get ID token for current user
  static Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Clear stored verification state (call this when registration/login is complete)
  static void clearState() {
    _verificationId = null;
    _resendToken = null;
  }
}
