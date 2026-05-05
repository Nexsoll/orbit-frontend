// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service/profile/profile_api_service.dart';

class ClaimedGiftsService {
  static ClaimedGiftsService? _instance;
  static ClaimedGiftsService get instance =>
      _instance ??= ClaimedGiftsService._();

  ClaimedGiftsService._();

  static const String _claimedGiftsKey = 'claimed_gifts';
  late ProfileApiService _profileApiService;

  /// Initialize the service
  void init() {
    _profileApiService = ProfileApiService.init();
  }

  /// Get all claimed gift message IDs
  Future<Set<String>> getClaimedGifts() async {
    final prefs = await SharedPreferences.getInstance();
    final claimedGiftsJson = prefs.getString(_claimedGiftsKey);

    if (claimedGiftsJson == null) {
      return <String>{};
    }

    try {
      final List<dynamic> claimedList = jsonDecode(claimedGiftsJson);
      return claimedList.cast<String>().toSet();
    } catch (e) {
      // If there's an error parsing, return empty set
      return <String>{};
    }
  }

  /// Mark a gift message as claimed
  Future<void> markGiftAsClaimed(String messageId) async {
    // Keep local storage as backup
    final claimedGifts = await getClaimedGifts();
    claimedGifts.add(messageId);
    await _saveClaimedGifts(claimedGifts);
  }

  /// Check if a gift message is already claimed
  Future<bool> isGiftClaimed(String messageId) async {
    try {
      // Try to check from backend first
      final response = await _profileApiService.isGiftClaimed(messageId);
      return response['isClaimed'] as bool? ?? false;
    } catch (e) {
      // Fallback to local storage if API fails
      final claimedGifts = await getClaimedGifts();
      return claimedGifts.contains(messageId);
    }
  }

  /// Claim a gift (combines marking as claimed and adding to balance)
  Future<Map<String, dynamic>> claimGift(
      String messageId, double amount) async {
    try {
      print(
          'ClaimedGiftsService: Claiming gift $messageId with amount $amount');
      final response = await _profileApiService.claimGift(messageId, amount);
      print('ClaimedGiftsService: Claim response: $response');

      // Also update local storage as backup
      final claimedGifts = await getClaimedGifts();
      claimedGifts.add(messageId);
      await _saveClaimedGifts(claimedGifts);

      return response;
    } catch (e) {
      print('ClaimedGiftsService: Failed to claim gift: $e');
      // If API fails, still mark as claimed locally
      await markGiftAsClaimed(messageId);
      rethrow;
    }
  }

  /// Remove a gift from claimed list (if needed for testing or admin purposes)
  Future<void> removeClaimedGift(String messageId) async {
    final claimedGifts = await getClaimedGifts();
    claimedGifts.remove(messageId);
    await _saveClaimedGifts(claimedGifts);
  }

  /// Clear all claimed gifts (for testing or logout purposes)
  Future<void> clearAllClaimedGifts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claimedGiftsKey);
  }

  /// Save claimed gifts to shared preferences
  Future<void> _saveClaimedGifts(Set<String> claimedGifts) async {
    final prefs = await SharedPreferences.getInstance();
    final claimedGiftsJson = jsonEncode(claimedGifts.toList());
    await prefs.setString(_claimedGiftsKey, claimedGiftsJson);
  }
}
