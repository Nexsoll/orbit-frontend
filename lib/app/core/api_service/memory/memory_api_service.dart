// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/models/memory/create_memory_dto.dart';
import 'package:super_up/app/core/models/memory/memory_model.dart';
import 'package:super_up_core/super_up_core.dart';

import '../interceptors.dart';
import 'memory_api.dart';

class MemoryApiService {
  static MemoryApi? _memoryApi;

  MemoryApiService._();

  Future<void> createMemory(CreateMemoryDto dto) async {
    final body = dto.toListOfPartValue();
    final res = await _memoryApi!.createMemory(body);
    throwIfNotSuccess(res);
  }

  Future<List<MemoryModel>> getMemories({int page = 1, int limit = 20}) async {
    final res = await _memoryApi!.getMemories(page, limit);
    throwIfNotSuccess(res);

    final data = res.body['data'] as Map<String, dynamic>;
    final docs = data['docs'] as List;

    return docs
        .map((e) => MemoryModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<MemoryModel> getMemory(String id) async {
    final res = await _memoryApi!.getMemory(id);
    throwIfNotSuccess(res);

    return MemoryModel.fromMap(res.body['data'] as Map<String, dynamic>);
  }

  Future<void> deleteMemory(String id) async {
    final res = await _memoryApi!.deleteMemory(id);
    throwIfNotSuccess(res);
  }

  Future<void> deleteMemoryByStoryId(String storyId) async {
    final res = await _memoryApi!.deleteMemoryByStoryId(storyId);
    throwIfNotSuccess(res);
  }

  Future<List<MemoryModel>> getTodayReminders() async {
    final res = await _memoryApi!.getTodayReminders();
    throwIfNotSuccess(res);

    final data = res.body['data'] as List;
    return data
        .map((e) => MemoryModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static MemoryApiService? _instance;

  static MemoryApiService get instance {
    _instance ??= MemoryApiService._();
    return _instance!;
  }

  static void init() {
    _memoryApi = MemoryApi.create();
    GetIt.I.registerSingleton<MemoryApiService>(instance);
  }
}
