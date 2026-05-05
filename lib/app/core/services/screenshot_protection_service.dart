// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

class ScreenshotProtectionService {
  static bool _isProtectionEnabled = false;
  
  /// Enable screenshot protection for the current screen
  static Future<void> enableProtection() async {
    if (_isProtectionEnabled) return;
    
    try {
      // Enable data leakage protection for both Android and iOS
      await ScreenProtector.protectDataLeakageOn();
      _isProtectionEnabled = true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to enable screenshot protection: $e');
      }
    }
  }
  
  /// Disable screenshot protection for the current screen
  static Future<void> disableProtection() async {
    if (!_isProtectionEnabled) return;
    
    try {
      // Disable data leakage protection
      await ScreenProtector.protectDataLeakageOff();
      _isProtectionEnabled = false;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to disable screenshot protection: $e');
      }
    }
  }
  
  /// Check if protection is currently enabled
  static bool get isProtectionEnabled => _isProtectionEnabled;
  
  /// Enable screenshot prevention with blur/black overlay
  static Future<void> enableScreenshotPreventionWithBlur() async {
    try {
      // Enable data leakage protection with blur effect
      await ScreenProtector.protectDataLeakageWithBlur();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to enable screenshot prevention with blur: $e');
      }
    }
  }
}
