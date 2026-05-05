// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/services/story_status_service.dart';

import '../models/live_stream_model.dart';
import '../models/live_category_model.dart';
import '../services/live_stream_api_service.dart';

class GoLiveController extends ChangeNotifier {
  final LiveStreamApiService _apiService = GetIt.I.get<LiveStreamApiService>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final joinPriceController = TextEditingController();

  final ValueNotifier<bool> isCreatingStream = ValueNotifier(false);
  final ValueNotifier<bool> isPrivate = ValueNotifier(false);
  final ValueNotifier<bool> requiresApproval = ValueNotifier(false);
  final ValueNotifier<bool> isMuted = ValueNotifier(false);
  final ValueNotifier<bool> isCameraOn = ValueNotifier(true);
  final ValueNotifier<List<SBaseUser>> selectedMembers = ValueNotifier([]);
  final ValueNotifier<List<LiveCategoryModel>> availableCategories = ValueNotifier([]);
  final ValueNotifier<LiveCategoryModel?> selectedCategory = ValueNotifier(null);
  final ValueNotifier<bool> isLoadingCategories = ValueNotifier(false);

  bool _isDisposed = false;

  void onInit() {
    // Reset disposal flag when starting
    _isDisposed = false;

    // Initialize camera and microphone permissions
    _initializeCamera();
    
    // Load live categories
    _loadLiveCategories();
  }

  void resetController() {
    // Reset state without disposing ValueNotifiers
    if (!_isDisposed) {
      // Clear text controllers
      titleController.clear();
      descriptionController.clear();
      joinPriceController.clear();

      // Reset values to defaults
      isCreatingStream.value = false;
      isPrivate.value = false;
      requiresApproval.value = false;
      isMuted.value = false;
      isCameraOn.value = true;
      selectedMembers.value = [];
      selectedCategory.value = null;
    }
  }

  void onClose() {
    _isDisposed = true;
    titleController.dispose();
    descriptionController.dispose();
    joinPriceController.dispose();
    isCreatingStream.dispose();
    isPrivate.dispose();
    isMuted.dispose();
    isCameraOn.dispose();
    selectedMembers.dispose();
    availableCategories.dispose();
    selectedCategory.dispose();
    isLoadingCategories.dispose();
  }

  Future<void> _initializeCamera() async {
    // Initialize camera preview here
    // This would integrate with your existing camera/video functionality
  }

  Future<void> _loadLiveCategories() async {
    if (_isDisposed) return;
    
    isLoadingCategories.value = true;
    
    try {
      final categories = await _apiService.getLiveCategories();
      if (!_isDisposed) {
        availableCategories.value = categories;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading live categories: $e');
      }
    } finally {
      if (!_isDisposed) {
        isLoadingCategories.value = false;
      }
    }
  }

  void togglePrivacy(bool value) {
    if (!_isDisposed) {
      isPrivate.value = value;
      // Clear selected members when switching to public
      if (!value) {
        selectedMembers.value = [];
      } else {
        // Clear approval requirement when switching to private
        requiresApproval.value = false;
      }
      notifyListeners();
    }
  }

  void toggleApprovalRequirement(bool value) {
    if (!_isDisposed) {
      requiresApproval.value = value;
      notifyListeners();
    }
  }

  void addSelectedMember(SBaseUser user) {
    if (!_isDisposed) {
      final currentMembers = List<SBaseUser>.from(selectedMembers.value);
      if (!currentMembers.any((member) => member.id == user.id)) {
        currentMembers.add(user);
        selectedMembers.value = currentMembers;
        notifyListeners();
      }
    }
  }

  void removeSelectedMember(SBaseUser user) {
    if (!_isDisposed) {
      final currentMembers = List<SBaseUser>.from(selectedMembers.value);
      currentMembers.removeWhere((member) => member.id == user.id);
      selectedMembers.value = currentMembers;
      notifyListeners();
    }
  }

  void clearSelectedMembers() {
    if (!_isDisposed) {
      selectedMembers.value = [];
      notifyListeners();
    }
  }

  void selectCategory(LiveCategoryModel? category) {
    if (!_isDisposed) {
      selectedCategory.value = category;
      notifyListeners();
    }
  }

  void toggleMute() {
    if (!_isDisposed) {
      isMuted.value = !isMuted.value;
      // Implement actual mute/unmute logic here
    }
  }

  void switchCamera() {
    // Implement camera switching logic here
  }

  void toggleCamera() {
    if (!_isDisposed) {
      isCameraOn.value = !isCameraOn.value;
      // Implement camera on/off logic here
    }
  }

  Future<LiveStreamModel?> createLiveStream() async {
    if (titleController.text.trim().isEmpty || _isDisposed) {
      return null;
    }

    // Require a category to be selected before creating a stream
    if (selectedCategory.value == null) {
      if (kDebugMode) {
        print('createLiveStream blocked: category not selected');
      }
      return null;
    }

    if (!_isDisposed) {
      isCreatingStream.value = true;
      notifyListeners();
    }

    try {
      // Parse join price when approval required
      double? joinPrice;
      if (requiresApproval.value) {
        final raw = joinPriceController.text.trim();
        if (raw.isEmpty) {
          return null;
        }
        final parsed = double.tryParse(raw);
        if (parsed == null || parsed <= 0) {
          return null;
        }
        joinPrice = parsed;
      }

      final stream = await _apiService.createLiveStream(
        title: titleController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        isPrivate: isPrivate.value,
        requiresApproval: requiresApproval.value,
        joinPrice: joinPrice,
        allowedViewers: isPrivate.value
            ? selectedMembers.value.map((user) => user.id).toList()
            : null,
        tags: [selectedCategory.value!.name],
      );

      // Start the stream immediately after creation
      await _apiService.startLiveStream(stream.id);

      // Immediately broadcast live status so red circle appears instantly
      try {
        final storyStatus = GetIt.I.get<StoryStatusService>();
        storyStatus.setUserLiveNow(userId: stream.streamerId, streamId: stream.id);
      } catch (_) {}

      return stream.copyWith(status: LiveStreamStatus.live);
    } catch (e) {
      if (kDebugMode) {
        print('Error creating live stream: $e');
      }
      return null;
    } finally {
      if (!_isDisposed) {
        isCreatingStream.value = false;
        notifyListeners();
      }
    }
  }
}
