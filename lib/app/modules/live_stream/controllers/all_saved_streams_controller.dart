// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../models/live_stream_recording_model.dart';
import '../models/live_category_model.dart';
import '../services/live_stream_api_service.dart';

class AllSavedStreamsController {
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
        print('Loading ALL recordings with params: page=$page, limit=$limit, search=$searchQuery, sortBy=$_currentSortBy');
      }

      final recordingList = await _apiService.getRecordings(
        page: page,
        limit: limit,
        search: searchQuery,
        tags: _currentCategoryTag == null ? null : <String>[_currentCategoryTag!],
        sortBy: _sortByToField(_currentSortBy),
        sortOrder: _sortOrderFor(_currentSortBy),
        scope: 'all', // fetch all public/accessible recordings
      );

      _allRecordings = recordingList;
      recordings.value = recordingList;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading ALL recordings: $e');
      }
      recordings.value = [];
    } finally {
      if (!_isDisposed) {
        isLoading.value = false;
      }
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

    if (searchQuery.value.isNotEmpty) {
      searchRecordings(searchQuery.value);
    } else {
      recordings.value = sortedRecordings;
    }
  }

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

  Future<void> likeRecording(String recordingId) async {
    if (_isDisposed) return;
    try {
      await _apiService.likeRecording(recordingId);
      // Refresh list to reflect changes
      loadRecordings();
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
    }
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
