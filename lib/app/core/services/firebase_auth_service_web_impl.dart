// Copyright 2024, Orbit App
// Web implementation using dart:js and dart:html

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

class FirebaseAuthServiceWebImpl {
  static js.JsObject? _confirmationResult;

  static bool get isAvailable {
    try {
      final firebase = js.context['firebase'];
      final hasAuth = firebase != null && firebase['auth'] != null;
      print('FirebaseAuthServiceWebImpl: isAvailable check - firebase=$firebase, hasAuth=$hasAuth');
      return hasAuth;
    } catch (e) {
      print('FirebaseAuthServiceWebImpl: isAvailable error - $e');
      return false;
    }
  }

  static dynamic get _auth {
    try {
      // First try window.firebase.auth()
      final firebase = js.context['firebase'];
      if (firebase != null) {
        final auth = firebase['auth'];
        if (auth != null) {
          print('FirebaseAuthServiceWebImpl: _auth found via firebase.auth()');
          return auth;
        }
      }
      
      // Fallback to window.firebaseAuthWeb
      final authWeb = js.context['firebaseAuthWeb'];
      if (authWeb != null) {
        print('FirebaseAuthServiceWebImpl: _auth found via firebaseAuthWeb');
        return authWeb;
      }
      
      print('FirebaseAuthServiceWebImpl: _auth not found');
      return null;
    } catch (e) {
      print('FirebaseAuthServiceWebImpl: _auth getter error - $e');
      return null;
    }
  }

  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
    required Function() onAutoVerified,
  }) async {
    print('FirebaseAuthServiceWebImpl: verifyPhoneNumber called with $phoneNumber');
    
    try {
      final auth = _auth;
      print('FirebaseAuthServiceWebImpl: auth=$auth');
      
      if (auth == null) {
        print('FirebaseAuthServiceWebImpl: auth is null');
        onError('Firebase Auth not available. Please refresh the page.');
        return;
      }

      print('FirebaseAuthServiceWebImpl: ensuring reCAPTCHA container');
      _ensureRecaptchaContainer();

      print('FirebaseAuthServiceWebImpl: creating RecaptchaVerifier');
      final firebase = js.context['firebase'];
      print('FirebaseAuthServiceWebImpl: firebase=$firebase');
      
      if (firebase == null) {
        onError('Firebase not initialized');
        return;
      }
      
      final firebaseAuth = firebase['auth'];
      print('FirebaseAuthServiceWebImpl: firebaseAuth=$firebaseAuth');
      
      if (firebaseAuth == null) {
        onError('Firebase Auth not initialized');
        return;
      }
      
      final RecaptchaVerifier = firebaseAuth['RecaptchaVerifier'];
      print('FirebaseAuthServiceWebImpl: RecaptchaVerifier=$RecaptchaVerifier');
      
      if (RecaptchaVerifier == null) {
        onError('RecaptchaVerifier not available');
        return;
      }

      // Get auth instance first for RecaptchaVerifier
      final authInstance = (auth as js.JsFunction).apply([]);
      print('FirebaseAuthServiceWebImpl: authInstance for RecaptchaVerifier=$authInstance');

      final recaptchaVerifier = js.JsObject(
        RecaptchaVerifier as js.JsFunction,
        [
          'recaptcha-container',
          js.JsObject.jsify({'size': 'invisible'}),
        ],
      );
      print('FirebaseAuthServiceWebImpl: recaptchaVerifier created with auth');

      print('FirebaseAuthServiceWebImpl: calling signInWithPhoneNumber');
      final authObj = js.JsObject.fromBrowserObject(authInstance);
      print('FirebaseAuthServiceWebImpl: authObj=$authObj');
      print('FirebaseAuthServiceWebImpl: authObj keys=${js.context['Object'].callMethod('keys', [authInstance])}');
      
      final signInMethod = authObj['signInWithPhoneNumber'];
      print('FirebaseAuthServiceWebImpl: signInMethod=$signInMethod');
      
      if (signInMethod == null) {
        onError('signInWithPhoneNumber method not found on auth object');
        return;
      }
      
      final promise = authObj.callMethod('signInWithPhoneNumber', [phoneNumber, recaptchaVerifier]);
      print('FirebaseAuthServiceWebImpl: promise=$promise');
      
      final result = await _waitForJsPromise(promise);
      print('FirebaseAuthServiceWebImpl: result=$result');
      
      _confirmationResult = js.JsObject.fromBrowserObject(result);

      onCodeSent('web-verification', null);
    } catch (e, stackTrace) {
      print('FirebaseAuthServiceWebImpl: Error in verifyPhoneNumber - $e');
      print('FirebaseAuthServiceWebImpl: StackTrace - $stackTrace');
      onError('Failed to send verification code: $e');
    }
  }

  static Future<dynamic> _waitForJsPromise(dynamic promise) {
    print('FirebaseAuthServiceWebImpl: _waitForJsPromise called with promise=$promise');
    final completer = Completer<dynamic>();

    if (promise == null) {
      completer.completeError('Promise is null');
      return completer.future;
    }

    try {
      // Call then/catch directly on the promise object, preserving 'this' context
      final jsPromise = js.JsObject.fromBrowserObject(promise);
      
      jsPromise.callMethod('then', [
        (result) {
          print('FirebaseAuthServiceWebImpl: promise success - $result');
          completer.complete(result);
          return null;
        }
      ]);
      
      jsPromise.callMethod('catch', [
        (error) {
          print('FirebaseAuthServiceWebImpl: promise error - $error');
          completer.completeError(error);
          return null;
        }
      ]);
    } catch (e) {
      print('FirebaseAuthServiceWebImpl: Error setting up promise handlers - $e');
      completer.completeError(e);
    }

    return completer.future;
  }

  static void _ensureRecaptchaContainer() {
    try {
      final container = html.document.getElementById('recaptcha-container');
      if (container == null) {
        print('FirebaseAuthServiceWebImpl: creating recaptcha-container div');
        final div = html.DivElement()
          ..id = 'recaptcha-container'
          ..style.display = 'none';
        html.document.body?.append(div);
        print('FirebaseAuthServiceWebImpl: recaptcha-container created');
      } else {
        print('FirebaseAuthServiceWebImpl: recaptcha-container already exists');
      }
    } catch (e) {
      print('FirebaseAuthServiceWebImpl: Error creating reCAPTCHA container: $e');
    }
  }

  static Future<String?> verifyCode(String smsCode) async {
    print('FirebaseAuthServiceWebImpl: verifyCode called');
    try {
      if (_confirmationResult == null) {
        throw Exception('No verification in progress. Please request code again.');
      }

      final promise = _confirmationResult!.callMethod('confirm', [smsCode]);
      final result = await _waitForJsPromise(promise);

      final resultObj = js.JsObject.fromBrowserObject(result);
      final user = resultObj['user'];
      if (user == null) {
        throw Exception('Failed to sign in');
      }

      final userObj = js.JsObject.fromBrowserObject(user);
      final tokenPromise = userObj.callMethod('getIdToken', []);
      final idToken = await _waitForJsPromise(tokenPromise);

      return idToken?.toString();
    } catch (e) {
      print('FirebaseAuthServiceWebImpl: Error verifying code: $e');
      throw Exception('Invalid verification code: $e');
    }
  }

  static Future<void> resendCode({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
  }) async {
    await verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
      onAutoVerified: () {},
    );
  }

  static Future<void> signOut() async {
    try {
      final auth = _auth;
      if (auth != null) {
        final authInstance = (auth as js.JsFunction).apply([]);
        if (authInstance != null) {
          final promise = (authInstance as js.JsObject).callMethod('signOut', []);
          await _waitForJsPromise(promise);
        }
      }
    } catch (e) {
      // Ignore
    }
    _confirmationResult = null;
  }

  static dynamic get currentUser {
    try {
      final auth = _auth;
      if (auth != null) {
        final authInstance = (auth as js.JsFunction).apply([]);
        if (authInstance != null) {
          return (authInstance as js.JsObject)['currentUser'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static bool get isSignedIn => currentUser != null;

  static Future<String?> getIdToken() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final userObj = js.JsObject.fromBrowserObject(user);
      final promise = userObj.callMethod('getIdToken', []);
      final idToken = await _waitForJsPromise(promise);
      return idToken?.toString();
    } catch (e) {
      return null;
    }
  }

  static void clearState() {
    _confirmationResult = null;
  }
}
