// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'community_api.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$CommunityApi extends CommunityApi {
  _$CommunityApi([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = CommunityApi;

  @override
  Future<Response<dynamic>> createCommunity(
    List<PartValue<dynamic>> body,
    MultipartFile? file,
  ) {
    final Uri $url = Uri.parse('community/');
    final List<PartValue> $parts = <PartValue>[
      PartValueFile<MultipartFile?>(
        'file',
        file,
      )
    ];
    $parts.addAll(body);
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
  Future<Response<dynamic>> myCommunities() {
    final Uri $url = Uri.parse('community/mine');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getCommunity(String communityId) {
    final Uri $url = Uri.parse('community/${communityId}');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getMembers(
    String communityId,
    int page,
    int limit,
    String? search,
  ) {
    final Uri $url = Uri.parse('community/${communityId}/members');
    final Map<String, dynamic> $params = <String, dynamic>{
      'page': page,
      'limit': limit,
      'search': search,
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
  Future<Response<dynamic>> getRequests(
    String communityId,
    int page,
    int limit,
    String? search,
  ) {
    final Uri $url = Uri.parse('community/${communityId}/requests');
    final Map<String, dynamic> $params = <String, dynamic>{
      'page': page,
      'limit': limit,
      'search': search,
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
  Future<Response<dynamic>> addMembers(
    String communityId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('community/${communityId}/members');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> joinCommunity(String communityId) {
    final Uri $url = Uri.parse('community/${communityId}/join');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> respondRequest(
    String communityId,
    String targetId,
    String action,
  ) {
    final Uri $url =
        Uri.parse('community/${communityId}/requests/${targetId}/${action}');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getCommunityGroups(String communityId) {
    final Uri $url = Uri.parse('community/${communityId}/groups');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getMyRole(String communityId) {
    final Uri $url = Uri.parse('community/${communityId}/role');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> createGroup(
    String communityId,
    String groupName,
    String peerIdsJson,
    String? groupDescription,
    String? extraData,
    MultipartFile? file,
  ) {
    final Uri $url = Uri.parse('community/${communityId}/groups');
    final List<PartValue> $parts = <PartValue>[
      PartValue<String>(
        'groupName',
        groupName,
      ),
      PartValue<String>(
        'peerIds',
        peerIdsJson,
      ),
      PartValue<String?>(
        'groupDescription',
        groupDescription,
      ),
      PartValue<String?>(
        'extraData',
        extraData,
      ),
      PartValueFile<MultipartFile?>(
        'file',
        file,
      ),
    ];
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
  Future<Response<dynamic>> updateExtra(
    String communityId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('community/${communityId}/extra');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateImage(
    String communityId,
    MultipartFile file,
  ) {
    final Uri $url = Uri.parse('community/${communityId}/image');
    final List<PartValue> $parts = <PartValue>[
      PartValueFile<MultipartFile>(
        'file',
        file,
      )
    ];
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> attachExisting(
    String communityId,
    String roomId,
  ) {
    final Uri $url = Uri.parse('community/${communityId}/attach/${roomId}');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getAnnouncements(
    String communityId,
    int page,
    int limit,
  ) {
    final Uri $url = Uri.parse('community/${communityId}/announcements');
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
  Future<Response<dynamic>> createAnnouncement(
    String communityId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('community/${communityId}/announcements');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getMyAnnouncements(
    int page,
    int limit,
  ) {
    final Uri $url = Uri.parse('community/my/announcements');
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
  Future<Response<dynamic>> deleteAnnouncement(
    String communityId,
    String id,
  ) {
    final Uri $url = Uri.parse('community/${communityId}/announcements/${id}');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
