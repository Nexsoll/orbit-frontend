// Copyright 2025, Orbit
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' hide Response, Request;
import 'package:v_platform/v_platform.dart';

import '../interceptors.dart';
import 'community_api.dart';

class CommunityApiService {
  static CommunityApi? _api;

  CommunityApiService._();

  static CommunityApiService? _instance;
  static CommunityApiService get instance {
    _instance ??= CommunityApiService._();
    return _instance!;
  }

  Future<Map<String, dynamic>> getMyRole(String communityId) async {
    final res = await _api!.getMyRole(communityId);
    throwIfNotSuccess(res);
    final data = res.body['data'];
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  static CommunityApiService init() {
    _api ??= CommunityApi.create();
    final inst = CommunityApiService.instance;
    GetIt.I.registerSingleton<CommunityApiService>(inst);
    return inst;
  }

  Future<Map<String, dynamic>> createCommunity({
    required String name,
    String? desc,
    VPlatformFile? image,
    Map<String, dynamic>? extra,
  }) async {
    final parts = <PartValue>[
      PartValue('name', name),
      if (desc != null) PartValue('desc', desc),
      if (extra != null) PartValue('extraData', jsonEncode(extra)),
    ];

    MultipartFile? file;
    if (image != null) {
      file = await VPlatforms.getMultipartFile(source: image);
    }

    final res = await _api!.createCommunity(parts, file);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<List<dynamic>> myCommunities() async {
    final res = await _api!.myCommunities();
    throwIfNotSuccess(res);
    // backend returns an array in data
    final data = res.body['data'];
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> getCommunity(String communityId) async {
    final res = await _api!.getCommunity(communityId);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> getMembers(
    String communityId, {
    int page = 1,
    int limit = 30,
    String? search,
  }) async {
    final res = await _api!.getMembers(communityId, page, limit, search);
    throwIfNotSuccess(res);
    return res.body['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRequests(
    String communityId, {
    int page = 1,
    int limit = 30,
    String? search,
  }) async {
    final res = await _api!.getRequests(communityId, page, limit, search);
    throwIfNotSuccess(res);
    return res.body['data'] as Map<String, dynamic>;
  }

  Future<void> addMembers(String communityId, List<String> ids) async {
    final res = await _api!.addMembers(communityId, { 'ids': ids });
    throwIfNotSuccess(res);
  }

  Future<String> join(String communityId) async {
    final res = await _api!.joinCommunity(communityId);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res).toString();
  }

  Future<String> respondRequest(String communityId, String targetId, { required bool approve }) async {
    final res = await _api!.respondRequest(communityId, targetId, approve ? 'approve' : 'decline');
    throwIfNotSuccess(res);
    return extractDataFromResponse(res).toString();
  }

  Future<List<dynamic>> getCommunityGroups(String communityId) async {
    final res = await _api!.getCommunityGroups(communityId);
    throwIfNotSuccess(res);
    final data = res.body['data'];
    if (data is List) return data;
    return [];
  }

  Future<dynamic> createGroup({
    required String communityId,
    required String groupName,
    required List<String> peerIds,
    String? description,
    Map<String, dynamic>? extra,
    VPlatformFile? image,
  }) async {
    MultipartFile? file;
    if (image != null) {
      file = await VPlatforms.getMultipartFile(source: image);
    }
    final res = await _api!.createGroup(
      communityId,
      groupName,
      jsonEncode(peerIds),
      description,
      extra == null ? null : jsonEncode(extra),
      file,
    );
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<void> updateExtra(String communityId, Map<String, dynamic> extra) async {
    final res = await _api!.updateExtra(communityId, extra);
    throwIfNotSuccess(res);
  }

  Future<String> updateImage(String communityId, VPlatformFile image) async {
    final file = await VPlatforms.getMultipartFile(source: image);
    final res = await _api!.updateImage(communityId, file);
    throwIfNotSuccess(res);
    try {
      return (res.body as Map<String, dynamic>)['data']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<String> attachExisting(String communityId, String roomId) async {
    final res = await _api!.attachExisting(communityId, roomId);
    throwIfNotSuccess(res);
    try {
      return (res.body as Map<String, dynamic>)['data']?.toString() ?? 'attached';
    } catch (_) {
      return 'attached';
    }
  }

  Future<List<Map<String, dynamic>>> getAnnouncements(
    String communityId, {
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api!.getAnnouncements(communityId, page, limit);
    throwIfNotSuccess(res);
    final data = res.body['data'];
    if (data is List) {
      return data
          .where((e) => e is Map)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String communityId,
    String? title,
    required String content,
    bool pinned = false,
  }) async {
    final res = await _api!.createAnnouncement(communityId, {
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      'content': content.trim(),
      'pinned': pinned,
    });
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<List<Map<String, dynamic>>> getMyAnnouncements({int page = 1, int limit = 20}) async {
    final res = await _api!.getMyAnnouncements(page, limit);
    throwIfNotSuccess(res);
    final data = res.body['data'];
    if (data is List) {
      return data
          .where((e) => e is Map)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<String> deleteAnnouncement({required String communityId, required String id}) async {
    final res = await _api!.deleteAnnouncement(communityId, id);
    throwIfNotSuccess(res);
    try {
      return (res.body as Map<String, dynamic>)['data']?.toString() ?? 'deleted';
    } catch (_) {
      return 'deleted';
    }
  }
}
