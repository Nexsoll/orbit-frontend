// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:get_it/get_it.dart';
import '../api_service/api_service.dart';

/// Service to manage user verification status checking
class UserVerificationService {
  final ProfileApiService _profileApiService = GetIt.I.get<ProfileApiService>();
  
  // Cache to store verification status to avoid repeated API calls
  final Map<String, bool> _verificationCache = {};
  final Map<String, DateTime> _cacheTimes = {};
  Duration _ttl = const Duration(seconds: 60);
  
  /// Check if a user is verified by their user ID
  /// Returns cached result if available, otherwise fetches from API
  Future<bool> isUserVerified(String userId) async {
    // Return cached result if available and not expired
    final cached = _verificationCache[userId];
    final cachedAt = _cacheTimes[userId];
    if (cached != null && cachedAt != null) {
      final age = DateTime.now().difference(cachedAt);
      if (age < _ttl) return cached;
    }
    
    try {
      // Fetch user profile to check verification status
      final profile = await _profileApiService.peerProfile(userId);
      final isVerified = profile.searchUser.hasBadge;
      
      // Cache the result with timestamp
      _verificationCache[userId] = isVerified;
      _cacheTimes[userId] = DateTime.now();
      
      return isVerified;
    } catch (e) {
      // If API call fails, serve stale cache if exists; otherwise false
      if (cached != null) return cached;
      return false;
    }
  }
  
  /// Synchronous method to check verification from cache only
  /// Returns false if not cached
  bool isUserVerifiedSync(String userId) {
    return _verificationCache[userId] ?? false;
  }
  
  /// Get cached verification status, returns null if not cached
  bool? getCachedVerificationStatus(String userId) {
    return _verificationCache[userId];
  }
  
  /// Preload verification status for multiple users
  /// Useful for batch loading verification status for chat lists
  Future<void> preloadVerificationStatus(List<String> userIds) async {
    final uncachedUserIds = userIds.where((id) => !_verificationCache.containsKey(id)).toList();
    
    if (uncachedUserIds.isEmpty) return;
    
    // Load verification status for uncached users
    for (final userId in uncachedUserIds) {
      try {
        await isUserVerified(userId);
      } catch (e) {
        // Continue with next user if one fails
        continue;
      }
    }
  }
  
  /// Clear verification cache
  void clearCache() {
    _verificationCache.clear();
    _cacheTimes.clear();
  }
  
  /// Update verification status in cache
  void updateVerificationStatus(String userId, bool isVerified) {
    _verificationCache[userId] = isVerified;
    _cacheTimes[userId] = DateTime.now();
  }

  /// Invalidate one user cache (force next call to refetch)
  void invalidate(String userId) {
    _verificationCache.remove(userId);
    _cacheTimes.remove(userId);
  }

  /// Configure TTL for cache entries
  void setTtl(Duration ttl) {
    _ttl = ttl;
  }
}
