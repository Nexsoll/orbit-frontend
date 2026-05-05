// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../models/live_stream_recording_model.dart';
import '../models/live_category_model.dart';
import '../services/live_stream_api_service.dart';

class SavedLivesController {
  final LiveStreamApiService _apiService = GetIt.I.get<LiveStreamApiService>();
  
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<List<LiveStreamRecordingModel>> recordings = ValueNotifier([]);
  final ValueNotifier<String> searchQuery = ValueNotifier('');
  final ValueNotifier<List<LiveCategoryModel>> availableCategories = ValueNotifier([]);
  final ValueNotifier<LiveCategoryModel?> selectedCategory = ValueNotifier(null);
  final ValueNotifier<bool> isLoadingCategories = ValueNotifier(false);
  
  List<LiveStreamRecordingModel> _allRecordings = [];
  String _currentSortBy = 'newest';
  bool _isDisposed = false;
  String? _currentCategoryTag; // filter by category name (stored as tag)

  Future<void> loadRecordings({
    int page = 1,
    int limit = 20,
    String? searchQuery,
  }) async {
    if (_isDisposed) return;
    
    try {
      isLoading.value = true;
      
      if (kDebugMode) {
        print('Loading recordings with params: page=$page, limit=$limit, search=$searchQuery, sortBy=$_currentSortBy');
      }

      final recordingList = await _apiService.getRecordings(
        page: page,
        limit: limit,
        search: searchQuery,
        tags: _currentCategoryTag == null ? null : <String>[_currentCategoryTag!],
        sortBy: _sortByToField(_currentSortBy),
        sortOrder: _sortOrderFor(_currentSortBy),
        // Backend will filter by authenticated user automatically
      );
      
      if (kDebugMode) {
        print('Loaded ${recordingList.length} recordings');
        for (var recording in recordingList) {
          print('Recording: ${recording.title} - ${recording.recordedAt}');
        }
      }
      
      _allRecordings = recordingList;
      recordings.value = recordingList;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading recordings: $e');
        print('Error type: ${e.runtimeType}');
        if (e is Exception) {
          print('Exception details: $e');
        }
      }
      recordings.value = [];
    } finally {
      if (!_isDisposed) {
        isLoading.value = false;
      }
    }
  }

  Future<void> updateRecordingPrice({
    required String recordingId,
    double? price,
  }) async {
    if (_isDisposed) return;
    try {
      final updated = await _apiService.updateRecordingPrice(
        recordingId: recordingId,
        price: price,
      );

      // Update local cache
      final allIdx = _allRecordings.indexWhere((r) => r.id == recordingId);
      if (allIdx != -1) {
        _allRecordings[allIdx] = updated;
      }
      final shownIdx = recordings.value.indexWhere((r) => r.id == recordingId);
      if (shownIdx != -1) {
        final newShown = List<LiveStreamRecordingModel>.from(recordings.value);
        newShown[shownIdx] = updated;
        recordings.value = newShown;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating recording price: $e');
      }
      rethrow;
    }
  }

  // Map human sort options to backend fields
  String? _sortByToField(String sortBy) {
    switch (sortBy) {
      case 'views':
        return 'viewCount';
      case 'likes':
        return 'likesCount';
      case 'duration':
        return 'duration';
      case 'newest':
      case 'oldest':
      default:
        return 'recordedAt';
    }
  }

  String? _sortOrderFor(String sortBy) {
    switch (sortBy) {
      case 'oldest':
        return 'asc';
      default:
        return 'desc';
    }
  }

  Future<void> loadCategories() async {
    if (_isDisposed) return;
    isLoadingCategories.value = true;
    try {
      final categories = await _apiService.getLiveCategories();
      if (!_isDisposed) {
        availableCategories.value = categories;
      }
    } catch (_) {
      availableCategories.value = [];
    } finally {
      if (!_isDisposed) isLoadingCategories.value = false;
    }
  }

  Future<void> selectCategory(LiveCategoryModel? category) async {
    if (_isDisposed) return;
    selectedCategory.value = category;
    _currentCategoryTag = category?.name;
    await loadRecordings(
      searchQuery: searchQuery.value.isEmpty ? null : searchQuery.value,
    );
  }

  void searchRecordings(String query) {
    if (_isDisposed) return;
    
    searchQuery.value = query;
    
    if (query.isEmpty) {
      recordings.value = _allRecordings;
    } else {
      final filteredRecordings = _allRecordings.where((recording) {
        return recording.title.toLowerCase().contains(query.toLowerCase()) ||
               recording.description?.toLowerCase().contains(query.toLowerCase()) == true ||
               recording.streamerData.fullName.toLowerCase().contains(query.toLowerCase());
      }).toList();
      
      recordings.value = filteredRecordings;
    }
  }

  void sortRecordings(String sortBy) {
    if (_isDisposed) return;
    
    _currentSortBy = sortBy;
    
    final sortedRecordings = List<LiveStreamRecordingModel>.from(_allRecordings);
    
    switch (sortBy) {
      case 'newest':
        sortedRecordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        sortedRecordings.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'views':
        sortedRecordings.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
      case 'likes':
        sortedRecordings.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
      case 'duration':
        sortedRecordings.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }
    
    _allRecordings = sortedRecordings;
    
    // Apply current search if any
    if (searchQuery.value.isNotEmpty) {
      searchRecordings(searchQuery.value);
    } else {
      recordings.value = sortedRecordings;
    }
  }

  Future<void> deleteRecording(String recordingId) async {
    if (_isDisposed) return;
    
    try {
      await _apiService.deleteRecording(recordingId);
      
      // Remove from local lists
      _allRecordings.removeWhere((recording) => recording.id == recordingId);
      recordings.value = recordings.value
          .where((recording) => recording.id != recordingId)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting recording: $e');
      }
      rethrow;
    }
  }

  Future<void> updateRecordingPrivacy({
    required String recordingId,
    required bool isPrivate,
    List<String>? allowedViewers,
  }) async {
    if (_isDisposed) return;
    try {
      final updated = await _apiService.updateRecordingPrivacy(
        recordingId: recordingId,
        isPrivate: isPrivate,
        allowedViewers: allowedViewers,
      );

      // Update local cache
      final allIdx = _allRecordings.indexWhere((r) => r.id == recordingId);
      if (allIdx != -1) {
        _allRecordings[allIdx] = updated;
      }
      final shownIdx = recordings.value.indexWhere((r) => r.id == recordingId);
      if (shownIdx != -1) {
        final newShown = List<LiveStreamRecordingModel>.from(recordings.value);
        newShown[shownIdx] = updated;
        recordings.value = newShown;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating recording privacy: $e');
      }
      rethrow;
    }
  }

  Future<void> likeRecording(String recordingId) async {
    if (_isDisposed) return;
    
    try {
      await _apiService.likeRecording(recordingId);
      
      // Update local data
      final recordingIndex = _allRecordings.indexWhere((r) => r.id == recordingId);
      if (recordingIndex != -1) {
        // Note: This is a simplified update. In a real app, you'd get the updated data from the server
        loadRecordings(); // Refresh the list
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error liking recording: $e');
      }
      rethrow;
    }
  }

  Future<void> incrementViews(String recordingId) async {
    if (_isDisposed) return;
    
    try {
      await _apiService.incrementRecordingViews(recordingId);
    } catch (e) {
      if (kDebugMode) {
        print('Error incrementing views: $e');
      }
      // Don't rethrow as this is not critical
    }
  }

  Future<void> refreshRecordings() async {
    await loadRecordings();
  }

  void dispose() {
    _isDisposed = true;
    isLoading.dispose();
    recordings.dispose();
    searchQuery.dispose();
    availableCategories.dispose();
    selectedCategory.dispose();
    isLoadingCategories.dispose();
  }
}
