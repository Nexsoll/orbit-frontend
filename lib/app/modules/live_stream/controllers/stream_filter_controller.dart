// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/stream_filter_model.dart';

class StreamFilterController extends ChangeNotifier {
  StreamFilterModel _currentFilter = const StreamFilterModel();
  bool _isFilterPanelVisible = false;
  bool _isApplyingFilter = false;

  // Callback for broadcasting filter changes to other participants
  Function(StreamFilterModel)? _onFilterChanged;

  // Getters
  StreamFilterModel get currentFilter => _currentFilter;
  bool get isFilterPanelVisible => _isFilterPanelVisible;
  bool get isApplyingFilter => _isApplyingFilter;
  bool get hasActiveFilter =>
      _currentFilter.filterType != FilterType.none ||
      _currentFilter.faceFilterType != FaceFilterType.none;

  // Setter for filter change callback
  void setOnFilterChangedCallback(Function(StreamFilterModel)? callback) {
    _onFilterChanged = callback;
  }

  // Helper method to broadcast filter changes
  void _broadcastFilterChange() {
    if (_onFilterChanged != null) {
      _onFilterChanged!(_currentFilter);
    }
  }

  // Toggle filter panel visibility
  void toggleFilterPanel() {
    _isFilterPanelVisible = !_isFilterPanelVisible;
    notifyListeners();
  }

  void hideFilterPanel() {
    _isFilterPanelVisible = false;
    notifyListeners();
  }

  void showFilterPanel() {
    _isFilterPanelVisible = true;
    notifyListeners();
  }

  // Apply color filter
  Future<void> applyColorFilter(FilterType filterType) async {
    if (_isApplyingFilter) return;

    _isApplyingFilter = true;
    notifyListeners();

    try {
      _currentFilter = _currentFilter.copyWith(
        filterType: filterType,
        isEnabled: filterType != FilterType.none,
      );

      // Simulate filter processing delay
      await Future.delayed(const Duration(milliseconds: 100));

      if (kDebugMode) {
        print('Applied color filter: ${filterType.displayName}');
      }

      // Broadcast filter change to participants
      _broadcastFilterChange();
    } catch (e) {
      if (kDebugMode) {
        print('Error applying color filter: $e');
      }
    } finally {
      _isApplyingFilter = false;
      notifyListeners();
    }
  }

  // Apply face filter
  Future<void> applyFaceFilter(FaceFilterType faceFilterType) async {
    if (_isApplyingFilter) return;

    _isApplyingFilter = true;
    notifyListeners();

    try {
      _currentFilter = _currentFilter.copyWith(
        faceFilterType: faceFilterType,
        isEnabled: faceFilterType != FaceFilterType.none ||
            _currentFilter.filterType != FilterType.none,
      );

      // Simulate filter processing delay
      await Future.delayed(const Duration(milliseconds: 100));

      if (kDebugMode) {
        print('Applied face filter: ${faceFilterType.displayName}');
      }

      // Broadcast filter change to participants
      _broadcastFilterChange();
    } catch (e) {
      if (kDebugMode) {
        print('Error applying face filter: $e');
      }
    } finally {
      _isApplyingFilter = false;
      notifyListeners();
    }
  }

  // Adjust filter intensity
  void adjustFilterIntensity(double intensity) {
    _currentFilter =
        _currentFilter.copyWith(intensity: intensity.clamp(0.0, 2.0));
    notifyListeners();

    // Broadcast filter change to participants
    _broadcastFilterChange();
  }

  // Clear all filters
  void clearAllFilters() {
    _currentFilter = const StreamFilterModel();
    notifyListeners();

    if (kDebugMode) {
      print('Cleared all filters');
    }

    // Broadcast filter change to participants
    _broadcastFilterChange();
  }

  // Update filter from external source (for participants)
  void updateFilterFromHost(StreamFilterModel filter) {
    _currentFilter = filter;
    notifyListeners();

    if (kDebugMode) {
      print(
          'Updated filter from host: ${filter.filterType.displayName}, ${filter.faceFilterType.displayName}');
    }
  }

  // Get color matrix for the current filter
  List<double> getColorMatrix() {
    switch (_currentFilter.filterType) {
      case FilterType.none:
        return _identityMatrix();
      case FilterType.beauty:
        return _beautyMatrix();
      case FilterType.vintage:
        return _vintageMatrix();
      case FilterType.blackWhite:
        return _blackWhiteMatrix();
      case FilterType.sepia:
        return _sepiaMatrix();
      case FilterType.cool:
        return _coolMatrix();
      case FilterType.warm:
        return _warmMatrix();
      case FilterType.bright:
        return _brightMatrix();
      case FilterType.contrast:
        return _contrastMatrix();
      case FilterType.saturated:
        return _saturatedMatrix();
      case FilterType.blur:
        return _identityMatrix(); // Blur is handled differently
      case FilterType.sharpen:
        return _identityMatrix(); // Sharpen is handled differently
    }
  }

  // Color matrix implementations
  List<double> _identityMatrix() {
    return [
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _beautyMatrix() {
    final intensity = _currentFilter.intensity;
    return [
      1.0 + (0.1 * intensity),
      0,
      0,
      0,
      10 * intensity,
      0,
      1.0 + (0.1 * intensity),
      0,
      0,
      10 * intensity,
      0,
      0,
      1.0 + (0.05 * intensity),
      0,
      5 * intensity,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _vintageMatrix() {
    final intensity = _currentFilter.intensity;
    return [
      0.6 + (0.3 * intensity),
      0.3,
      0.1,
      0,
      0,
      0.2,
      0.5 + (0.3 * intensity),
      0.3,
      0,
      0,
      0.1,
      0.2,
      0.4 + (0.3 * intensity),
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _blackWhiteMatrix() {
    return [
      0.299,
      0.587,
      0.114,
      0,
      0,
      0.299,
      0.587,
      0.114,
      0,
      0,
      0.299,
      0.587,
      0.114,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _sepiaMatrix() {
    return [
      0.393,
      0.769,
      0.189,
      0,
      0,
      0.349,
      0.686,
      0.168,
      0,
      0,
      0.272,
      0.534,
      0.131,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _coolMatrix() {
    final intensity = _currentFilter.intensity;
    return [
      1.0 - (0.2 * intensity),
      0,
      0.2 * intensity,
      0,
      0,
      0,
      1.0 - (0.1 * intensity),
      0.1 * intensity,
      0,
      0,
      0,
      0,
      1.0 + (0.3 * intensity),
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _warmMatrix() {
    final intensity = _currentFilter.intensity;
    return [
      1.0 + (0.3 * intensity),
      0,
      0,
      0,
      0,
      0,
      1.0 + (0.1 * intensity),
      0,
      0,
      0,
      0,
      0,
      1.0 - (0.2 * intensity),
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _brightMatrix() {
    final intensity = _currentFilter.intensity;
    final brightness = 20 * intensity;
    return [
      1,
      0,
      0,
      0,
      brightness,
      0,
      1,
      0,
      0,
      brightness,
      0,
      0,
      1,
      0,
      brightness,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _contrastMatrix() {
    final intensity = _currentFilter.intensity;
    final contrast = 1.0 + (0.5 * intensity);
    final offset = (1 - contrast) * 128;
    return [
      contrast,
      0,
      0,
      0,
      offset,
      0,
      contrast,
      0,
      0,
      offset,
      0,
      0,
      contrast,
      0,
      offset,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _saturatedMatrix() {
    final intensity = _currentFilter.intensity;
    final saturation = 1.0 + intensity;
    final lumR = 0.3086;
    final lumG = 0.6094;
    final lumB = 0.0820;

    return [
      lumR * (1 - saturation) + saturation,
      lumG * (1 - saturation),
      lumB * (1 - saturation),
      0,
      0,
      lumR * (1 - saturation),
      lumG * (1 - saturation) + saturation,
      lumB * (1 - saturation),
      0,
      0,
      lumR * (1 - saturation),
      lumG * (1 - saturation),
      lumB * (1 - saturation) + saturation,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }
}
