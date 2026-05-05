// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CallBackgroundService {
  static const String _backgroundImagePathKey = 'call_background_image_path';
  static const String _backgroundEnabledKey = 'call_background_enabled';
  
  static CallBackgroundService? _instance;
  static CallBackgroundService get instance => _instance ??= CallBackgroundService._();
  
  CallBackgroundService._();
  
  SharedPreferences? _prefs;
  
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  /// Get background image path for a specific user ID
  String? getUserBackgroundImagePath(String userId) {
    return _prefs?.getString('${_backgroundImagePathKey}_$userId');
  }
  
  /// Check if background is enabled for a specific user ID
  bool isUserBackgroundEnabled(String userId) {
    return _prefs?.getBool('${_backgroundEnabledKey}_$userId') ?? false;
  }
  
  /// Get the current user's background image path
  String? get backgroundImagePath {
    return _prefs?.getString(_backgroundImagePathKey);
  }
  
  /// Check if current user's background is enabled
  bool get isBackgroundEnabled {
    return _prefs?.getBool(_backgroundEnabledKey) ?? false;
  }
  
  /// Set background enabled/disabled for current user
  Future<void> setBackgroundEnabled(bool enabled) async {
    await _prefs?.setBool(_backgroundEnabledKey, enabled);
  }
  
  /// Set background for a specific user (for caching other users' backgrounds)
  Future<void> setUserBackground(String userId, String imagePath, bool enabled) async {
    await _prefs?.setString('${_backgroundImagePathKey}_$userId', imagePath);
    await _prefs?.setBool('${_backgroundEnabledKey}_$userId', enabled);
  }
  
  /// Get current user's background data for sharing
  Map<String, dynamic>? getCurrentUserBackgroundData() {
    final imagePath = backgroundImagePath;
    final enabled = isBackgroundEnabled;
    
    if (!enabled || imagePath == null) return null;
    
    if (kIsWeb && imagePath.startsWith('web_')) {
      // For web, get base64 data
      final base64Data = _prefs?.getString(imagePath);
      if (base64Data != null) {
        return {
          'type': 'base64',
          'data': base64Data,
          'enabled': enabled,
        };
      }
    } else if (!kIsWeb) {
      // For mobile, we'd need to convert file to base64 for sharing
      // For now, just indicate that user has a background
      return {
        'type': 'file',
        'path': imagePath,
        'enabled': enabled,
      };
    }
    
    return null;
  }
  
  /// Cache received background data from another user
  Future<void> cacheUserBackgroundFromCall(String userId, Map<String, dynamic> backgroundData) async {
    try {
      final bool enabled = backgroundData['enabled'] ?? false;
      if (!enabled) return;
      
      if (backgroundData['type'] == 'base64') {
        final String base64Data = backgroundData['data'];
        final String webKey = 'web_call_${userId}_${DateTime.now().millisecondsSinceEpoch}';
        
        // Store the base64 data
        await _prefs?.setString(webKey, base64Data);
        
        // Set user background reference
        await setUserBackground(userId, webKey, true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error caching user background: $e');
      }
    }
  }
  
  /// Pick and save a background image
  Future<String?> pickAndSaveBackgroundImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image == null) return null;
      
      if (kIsWeb) {
        // On web, store image as base64 string in SharedPreferences
        final Uint8List imageBytes = await image.readAsBytes();
        final String base64Image = base64Encode(imageBytes);
        final String webImageKey = 'web_$_backgroundImagePathKey';
        
        await _prefs?.setString(webImageKey, base64Image);
        await _prefs?.setString(_backgroundImagePathKey, webImageKey);
        await setBackgroundEnabled(true);
        
        return webImageKey;
      } else {
        // Mobile/Desktop: Use file system
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String backgroundsDir = path.join(appDir.path, 'call_backgrounds');
        
        // Create directory if it doesn't exist
        final Directory dir = Directory(backgroundsDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        
        // Generate unique filename
        final String fileName = 'background_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String savedPath = path.join(backgroundsDir, fileName);
        
        // Copy image to app directory
        final File sourceFile = File(image.path);
        final File savedFile = await sourceFile.copy(savedPath);
        
        // Save path to preferences
        await _prefs?.setString(_backgroundImagePathKey, savedFile.path);
        await setBackgroundEnabled(true);
        
        return savedFile.path;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking background image: $e');
      }
      return null;
    }
  }
  
  /// Remove current background image
  Future<void> removeBackgroundImage() async {
    final String? currentPath = backgroundImagePath;
    if (currentPath != null) {
      try {
        if (kIsWeb) {
          // On web, remove base64 data from SharedPreferences
          if (currentPath.startsWith('web_')) {
            await _prefs?.remove(currentPath);
          }
        } else {
          // Mobile/Desktop: Delete file
          final File file = File(currentPath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error deleting background image: $e');
        }
      }
    }
    
    await _prefs?.remove(_backgroundImagePathKey);
    await setBackgroundEnabled(false);
  }
  
  /// Check if background image file exists
  Future<bool> backgroundImageExists() async {
    final String? imagePath = backgroundImagePath;
    if (imagePath == null) return false;
    
    if (kIsWeb) {
      // On web, check if base64 data exists in SharedPreferences
      if (imagePath.startsWith('web_')) {
        final String? base64Data = _prefs?.getString(imagePath);
        return base64Data != null && base64Data.isNotEmpty;
      }
      return false;
    } else {
      // Mobile/Desktop: Check file existence
      final File file = File(imagePath);
      return await file.exists();
    }
  }
  
  /// Get image bytes for web platform
  Uint8List? getWebImageBytes(String imagePath) {
    if (!kIsWeb || !imagePath.startsWith('web_')) return null;
    
    final String? base64Data = _prefs?.getString(imagePath);
    if (base64Data == null) return null;
    
    try {
      return base64Decode(base64Data);
    } catch (e) {
      if (kDebugMode) {
        print('Error decoding web image: $e');
      }
      return null;
    }
  }
  
  /// Get default background colors for when no image is set
  static const List<int> defaultBackgroundColors = [
    0xFF1E3A8A, // Blue
    0xFF059669, // Green  
    0xFF7C3AED, // Purple
    0xFFDC2626, // Red
    0xFFEA580C, // Orange
    0xFF0891B2, // Cyan
    0xFF7C2D12, // Brown
    0xFF374151, // Gray
  ];
}
