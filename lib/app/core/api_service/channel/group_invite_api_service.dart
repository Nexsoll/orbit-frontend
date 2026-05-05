// Copyright 2025, Orbit
// All rights reserved.
// Group invite API service for generating, resolving, and joining via invite links

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';

class GroupInviteApiService {
  GroupInviteApiService._();
  static final GroupInviteApiService I = GroupInviteApiService._();

  Uri _uriGetLink(String roomId) => Uri.parse(
      "${SConstants.sApiBaseUrl}/channel/$roomId/group/invite-link");
  Uri _uriRegenerate(String roomId) => Uri.parse(
      "${SConstants.sApiBaseUrl}/channel/$roomId/group/invite-link/regenerate");
  Uri _uriResolve(String code) => Uri.parse(
      "${SConstants.sApiBaseUrl}/channel/group/invite/resolve?code=$code");
  Uri get _uriJoin => Uri.parse(
      "${SConstants.sApiBaseUrl}/channel/group/invite/join");

  Map<String, String> _headers({bool jsonBody = false}) {
    final token = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    return <String, String>{
      'authorization': 'Bearer $token',
      if (jsonBody) 'content-type': 'application/json',
      'Accept-Language': 'en',
    };
  }

  Future<Map<String, dynamic>> getInviteLink(String roomId) async {
    final res = await http.get(_uriGetLink(roomId), headers: _headers()).timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to get invite link: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body);
    return (body is Map && body['data'] is Map)
        ? (body['data'] as Map<String, dynamic>)
        : (body as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> regenerateInviteLink(String roomId) async {
    final res = await http.patch(_uriRegenerate(roomId), headers: _headers()).timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to regenerate invite link: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body);
    return (body is Map && body['data'] is Map)
        ? (body['data'] as Map<String, dynamic>)
        : (body as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> resolve(String code) async {
    final res = await http.get(_uriResolve(code), headers: _headers()).timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Invalid or expired invite link');
    }
    final body = jsonDecode(res.body);
    return (body is Map && body['data'] is Map)
        ? (body['data'] as Map<String, dynamic>)
        : (body as Map<String, dynamic>);
  }

  Future<void> join(String code) async {
    final res = await http.post(_uriJoin, headers: _headers(jsonBody: true), body: jsonEncode({'code': code})).timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to join group: ${res.statusCode} ${res.body}');
    }
  }
}
