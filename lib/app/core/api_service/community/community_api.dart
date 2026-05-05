// Copyright 2025, Orbit
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:http/io_client.dart';
import 'package:http/http.dart' hide Response, Request;
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../interceptors.dart';

part 'community_api.chopper.dart';

@ChopperApi(baseUrl: 'community')
abstract class CommunityApi extends ChopperService {
  // Create community
  @Post(path: '/')
  @multipart
  Future<Response> createCommunity(
    @PartMap() List<PartValue> body,
    @PartFile('file') MultipartFile? file,
  );

  // List my communities
  @Get(path: '/mine')
  Future<Response> myCommunities();

  // Get one community
  @Get(path: '/{communityId}')
  Future<Response> getCommunity(
    @Path('communityId') String communityId,
  );

  // List members
  @Get(path: '/{communityId}/members')
  Future<Response> getMembers(
    @Path('communityId') String communityId,
    @Query('page') int page,
    @Query('limit') int limit,
    @Query('search') String? search,
  );

  // List pending requests
  @Get(path: '/{communityId}/requests')
  Future<Response> getRequests(
    @Path('communityId') String communityId,
    @Query('page') int page,
    @Query('limit') int limit,
    @Query('search') String? search,
  );

  // Add members
  @Post(path: '/{communityId}/members')
  Future<Response> addMembers(
    @Path('communityId') String communityId,
    @Body() Map<String, dynamic> body,
  );

  // Join community
  @Post(path: '/{communityId}/join')
  Future<Response> joinCommunity(
    @Path('communityId') String communityId,
  );

  // Approve/decline join request
  @Post(path: '/{communityId}/requests/{targetId}/{action}')
  Future<Response> respondRequest(
    @Path('communityId') String communityId,
    @Path('targetId') String targetId,
    @Path('action') String action, // approve | decline
  );

  // List groups under community
  @Get(path: '/{communityId}/groups')
  Future<Response> getCommunityGroups(
    @Path('communityId') String communityId,
  );

  // Get my role in the community
  @Get(path: '/{communityId}/role')
  Future<Response> getMyRole(
    @Path('communityId') String communityId,
  );

  // Create group in community
  @Post(path: '/{communityId}/groups')
  @multipart
  Future<Response> createGroup(
    @Path('communityId') String communityId,
    @Part('groupName') String groupName,
    @Part('peerIds') String peerIdsJson,
    @Part('groupDescription') String? groupDescription,
    @Part('extraData') String? extraData,
    @PartFile('file') MultipartFile? file,
  );

  // Update extra data
  @Patch(path: '/{communityId}/extra')
  Future<Response> updateExtra(
    @Path('communityId') String communityId,
    @Body() Map<String, dynamic> body,
  );

  // Update image
  @Patch(path: '/{communityId}/image')
  @multipart
  Future<Response> updateImage(
    @Path('communityId') String communityId,
    @PartFile('file') MultipartFile file,
  );

  // Attach existing group/channel to community
  @Post(path: '/{communityId}/attach/{roomId}')
  Future<Response> attachExisting(
    @Path('communityId') String communityId,
    @Path('roomId') String roomId,
  );

  // List announcements for a community
  @Get(path: '/{communityId}/announcements')
  Future<Response> getAnnouncements(
    @Path('communityId') String communityId,
    @Query('page') int page,
    @Query('limit') int limit,
  );

  // Create an announcement (admin only)
  @Post(path: '/{communityId}/announcements')
  Future<Response> createAnnouncement(
    @Path('communityId') String communityId,
    @Body() Map<String, dynamic> body,
  );

  // Aggregated announcements across my communities
  @Get(path: '/my/announcements')
  Future<Response> getMyAnnouncements(
    @Query('page') int page,
    @Query('limit') int limit,
  );

  // Delete an announcement (admin only)
  @Delete(path: '/{communityId}/announcements/{id}')
  Future<Response> deleteAnnouncement(
    @Path('communityId') String communityId,
    @Path('id') String id,
  );

  static CommunityApi create({
    Uri? baseUrl,
    String? accessToken,
  }) {
    final client = ChopperClient(
      baseUrl: SConstants.sApiBaseUrl,
      services: [
        _$CommunityApi(),
      ],
      converter: const JsonConverter(),
      interceptors: [AuthInterceptor()],
      errorConverter: ErrorInterceptor(),
      client: VPlatforms.isWeb
          ? null
          : IOClient(
              HttpClient()..connectionTimeout = const Duration(seconds: 10),
            ),
    );
    return _$CommunityApi(client);
  }
}
