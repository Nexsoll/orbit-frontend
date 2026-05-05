import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/memory/memory_api_service.dart';
import 'package:super_up/app/core/models/memory/create_memory_dto.dart';
import 'package:super_up/app/core/models/memory/memory_model.dart';
import 'package:super_up_core/super_up_core.dart';

class MemoryState {
  List<MemoryModel> memories = [];
  List<MemoryModel> todayReminders = [];
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 1;
  String? error;
}

class MemoryController extends SLoadingController<MemoryState> {
  MemoryController() : super(SLoadingState(MemoryState()));

  final _apiService = GetIt.I.get<MemoryApiService>();
  Timer? _timer;

  @override
  void onInit() {
    getMemories();
    getTodayReminders();
    // Refresh memories every 5 minutes
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      getTodayReminders();
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
  }

  Future<void> getMemories({bool refresh = false}) async {
    if (refresh) {
      data.currentPage = 1;
      data.hasMore = true;
      data.memories.clear();
    }

    if (!data.hasMore || data.isLoading) return;

    data.isLoading = true;
    data.error = null;
    setStateSuccess();
    update();

    try {
      final memories = await _apiService.getMemories(
        page: data.currentPage,
        limit: 20,
      );

      if (memories.isEmpty) {
        data.hasMore = false;
      } else {
        data.memories.addAll(memories);
        data.currentPage++;
      }

      data.isLoading = false;
      setStateSuccess();
      update();
    } catch (e) {
      data.isLoading = false;
      data.error = e.toString();
      setStateError();
      update();
    }
  }

  Future<void> getTodayReminders() async {
    try {
      final reminders = await _apiService.getTodayReminders();
      data.todayReminders = reminders;
      setStateSuccess();
      update();
    } catch (e) {
      // Silently handle reminder errors
      print('Error getting today reminders: $e');
    }
  }

  Future<bool> saveStoryToMemories(String storyId, {List<String>? tags}) async {
    try {
      final dto = CreateMemoryDto(
        storyId: storyId,
        tags: tags,
        isReminderEnabled: true,
      );

      await _apiService.createMemory(dto);

      // Refresh memories to show the new one
      await getMemories(refresh: true);

      return true;
    } catch (e) {
      data.error = e.toString();
      setStateError();
      update();
      return false;
    }
  }

  Future<bool> deleteMemory(String memoryId) async {
    try {
      await _apiService.deleteMemory(memoryId);

      // Remove from local list
      data.memories.removeWhere((memory) => memory.id == memoryId);
      data.todayReminders.removeWhere((memory) => memory.id == memoryId);

      setStateSuccess();
      update();

      return true;
    } catch (e) {
      data.error = e.toString();
      setStateError();
      update();
      return false;
    }
  }

  Future<bool> deleteMemoryByStoryId(String storyId) async {
    try {
      await _apiService.deleteMemoryByStoryId(storyId);

      // Remove from local list
      data.memories.removeWhere((memory) => memory.storyId == storyId);
      data.todayReminders.removeWhere((memory) => memory.storyId == storyId);

      setStateSuccess();
      update();

      return true;
    } catch (e) {
      data.error = e.toString();
      setStateError();
      update();
      return false;
    }
  }

  bool isStorySaved(String storyId) {
    return data.memories.any((memory) => memory.storyId == storyId);
  }

  void clearError() {
    data.error = null;
    setStateSuccess();
    update();
  }
}
