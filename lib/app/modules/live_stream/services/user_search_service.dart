// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../../core/api_service/profile/profile_api_service.dart';

class UserSearchService {
  static UserSearchService? _instance;
  late final ProfileApiService _profileApiService;

  UserSearchService._() {
    _profileApiService = GetIt.I.get<ProfileApiService>();
  }

  static UserSearchService init() {
    _instance ??= UserSearchService._();
    return _instance!;
  }

  /// Search for users that can be invited to private streams
  /// This calls your existing user search API
  Future<List<SBaseUser>> searchUsers({
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final filterDto = UserFilterDto(
        limit: limit,
        page: page,
        fullName: query,
      );

      final searchUsers = await _profileApiService.appUsers(filterDto);

      // Convert SSearchUser to SBaseUser
      return searchUsers.map((searchUser) => searchUser.baseUser).toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  /// Get users from contacts/friends list for private stream invites
  Future<List<SBaseUser>> getContactsForInvite() async {
    try {
      // Get all users from the app (you can modify this to get contacts/friends only)
      final filterDto = UserFilterDto.init();

      final searchUsers = await _profileApiService.appUsers(filterDto);

      // Convert SSearchUser to SBaseUser
      return searchUsers.map((searchUser) => searchUser.baseUser).toList();
    } catch (e) {
      throw Exception('Failed to get contacts: $e');
    }
  }
}
