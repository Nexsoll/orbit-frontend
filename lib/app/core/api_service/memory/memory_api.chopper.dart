// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'memory_api.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$MemoryApi extends MemoryApi {
  _$MemoryApi([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = MemoryApi;

  @override
  Future<Response<dynamic>> createMemory(List<PartValue<dynamic>> body) {
    final Uri $url = Uri.parse('memories/');
    final List<PartValue> $parts = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getMemories(
    int page,
    int limit,
  ) {
    final Uri $url = Uri.parse('memories/');
    final Map<String, dynamic> $params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getMemory(String id) {
    final Uri $url = Uri.parse('memories/${id}');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> deleteMemory(String id) {
    final Uri $url = Uri.parse('memories/${id}');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> deleteMemoryByStoryId(String storyId) {
    final Uri $url = Uri.parse('memories/story/${storyId}');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getTodayReminders() {
    final Uri $url = Uri.parse('memories/reminders/today');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
