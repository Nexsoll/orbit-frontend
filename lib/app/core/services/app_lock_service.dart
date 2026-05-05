// App Lock service using device biometrics or passcode via local_auth

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _sessionUnlocked = false;

  bool get isEnabled => VAppPref.getBool(SStorageKeys.appLockEnabled.name);
  bool get sessionUnlocked => _sessionUnlocked;
  void resetSession() => _sessionUnlocked = false;

  Future<void> setEnabled(bool enabled) async {
    await VAppPref.setBool(SStorageKeys.appLockEnabled.name, enabled);
  }

  Future<bool> isSupported() async {
    if (!VPlatforms.isMobile) return false;
    try {
      final deviceSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return deviceSupported || canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateOnce({BuildContext? context}) async {
    if (!VPlatforms.isMobile) return true; // Not applicable on web/desktop
    try {
      final supported = await isSupported();
      if (!supported) {
        if (context != null) {
          VAppAlert.showErrorSnackBar(
            context: context,
            message: 'Device authentication not available on this device',
          );
        }
        return false;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to unlock Orbit',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device passcode/pattern fallback on Android
          stickyAuth: false,
          useErrorDialogs: true,
          // Use non-sensitive to allow weak biometrics on older devices and face unlock variants
          sensitiveTransaction: false,
        ),
      );
      if (didAuthenticate) {
        _sessionUnlocked = true;
      }
      return didAuthenticate;
    } on PlatformException catch (e) {
      if (context != null) {
        final msg = _platformErrorMessage(e);
        VAppAlert.showErrorSnackBar(
          context: context,
          message: msg,
        );
      }
      return false;
    } catch (e) {
      if (context != null) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Authentication failed',
        );
      }
      return false;
    }
  }

  String _platformErrorMessage(PlatformException e) {
    switch (e.code) {
      case auth_error.notAvailable:
        return 'Authentication not available on this device';
      case auth_error.notEnrolled:
        return 'No biometrics enrolled. Add Face/Fingerprint or set a screen lock.';
      case auth_error.lockedOut:
        return 'Too many attempts. Try again later.';
      case auth_error.permanentlyLockedOut:
        return 'Authentication is permanently locked. Restart device or use device passcode.';
      default:
        return 'Authentication error: ${e.message ?? e.code}';
    }
  }

  Future<bool> enableWithPrompt(BuildContext context) async {
    final ok = await authenticateOnce(context: context);
    if (ok) await setEnabled(true);
    return ok;
  }

  Future<void> disable() async {
    await setEnabled(false);
  }

  Future<bool> requireOnAppStart(BuildContext context) async {
    if (!isEnabled) return true;
    return await authenticateOnce(context: context);
  }
}
