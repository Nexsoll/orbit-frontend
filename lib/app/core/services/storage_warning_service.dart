import 'package:flutter/foundation.dart';
import 'package:super_up_core/super_up_core.dart';
import 'user_files_service.dart';
import 'subscription_manager.dart';

class StorageWarningService extends ChangeNotifier {
  static final StorageWarningService _instance =
      StorageWarningService._internal();
  factory StorageWarningService() => _instance;
  StorageWarningService._internal();

  bool _showWarning = false;
  double _storagePercentage = 0.0;
  int _currentStorageBytes = 0;
  static const double _warningThreshold = 0.7; // 70%
  final SubscriptionManager _subscriptionManager = SubscriptionManager();

  bool get showWarning => _showWarning;
  double get storagePercentage => _storagePercentage;
  int get currentStorageBytes => _currentStorageBytes;

  // Dynamic storage limit based on subscription plan
  double get maxStorageBytes {
    final limitInGB = _subscriptionManager.storageLimit;
    return limitInGB * 1024 * 1024 * 1024; // Convert GB to bytes
  }

  Future<void> checkStorageUsage() async {
    try {
      // Get all uploaded files from the server
      final files = await UserFilesService.getUserFiles(
        page: 1,
        limit: 1000, // Get all files
      );

      // Calculate total size from uploaded files
      int totalSize = 0;
      for (var file in files) {
        totalSize += file.fileSize;
      }

      _updateStorageInfo(totalSize);
    } catch (e) {
      // If there's an error fetching files, set size to 0
      _updateStorageInfo(0);
    }
  }

  void _updateStorageInfo(int sizeInBytes) {
    _currentStorageBytes = sizeInBytes;
    _storagePercentage = (sizeInBytes / maxStorageBytes).clamp(0.0, 1.0);
    _showWarning =
        _storagePercentage >= _warningThreshold; // Show warning at 70%
    notifyListeners();
  }

  void dismissWarning() {
    _showWarning = false;
    notifyListeners();
  }

  /// Check if user can upload files based on current storage usage
  /// Returns true if upload is allowed, false if storage limit exceeded
  bool canUploadFiles(List<int> fileSizes) {
    final totalNewSize = fileSizes.fold<int>(0, (sum, size) => sum + size);
    final projectedSize = _currentStorageBytes + totalNewSize;
    return projectedSize <= maxStorageBytes;
  }

  /// Get remaining storage in bytes
  int get remainingStorageBytes {
    return (maxStorageBytes - _currentStorageBytes)
        .round()
        .clamp(0, maxStorageBytes.round());
  }

  /// Check if storage is at capacity (100% full)
  bool get isStorageFull {
    return _storagePercentage >= 1.0;
  }

  String formatBytes(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(1)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get storageUsageText {
    return '${formatBytes(_currentStorageBytes.toDouble())} / ${formatBytes(maxStorageBytes)}';
  }

  String get warningMessage {
    final percentage = (_storagePercentage * 100).toStringAsFixed(0);
    return 'Storage is $percentage% full. Upgrade plan or clear storage to free up space.';
  }
}
