// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:super_up_core/super_up_core.dart';

class MutualGroup {
  final String id;
  final String title;
  final String? image;
  final String? description;

  const MutualGroup({
    required this.id,
    required this.title,
    this.image,
    this.description,
  });

  factory MutualGroup.fromMap(Map<String, dynamic> map) {
    return MutualGroup(
      id: map['id'] as String,
      title: map['title'] as String,
      image: map['image'] as String?,
      description: map['description'] as String?,
    );
  }
}

class PeerProfileModel {
  final SSearchUser searchUser;
  final String lastSeenAt;
  final bool isMeBanner;
  final bool isPeerBanner;
  final bool isOnline;
  final String? roomId;
  final UserPrivacy userPrivacy;
  final List<MutualGroup> mutualGroups;
  final bool isFollowing;
  final bool canViewFollowers;
  final bool canViewFollowing;
  final bool canViewGallery;
  final int followersCount;
  final int followingCount;

//<editor-fold desc="Data Methods">
  const PeerProfileModel({
    required this.searchUser,
    required this.isOnline,
    required this.lastSeenAt,
    required this.isMeBanner,
    required this.isPeerBanner,
    required this.userPrivacy,
    required this.roomId,
    required this.mutualGroups,
    required this.isFollowing,
    required this.canViewFollowers,
    required this.canViewFollowing,
    required this.canViewGallery,
    required this.followersCount,
    required this.followingCount,
  });

  bool get getIsThereBan => isMeBanner || isPeerBanner;

  PeerProfileModel copyWith({
    SSearchUser? searchUser,
    String? lastSeenAt,
    UserPrivacy? userPrivacy,
    bool? isMeBanner,
    bool? isOnline,
    bool? isPeerBanner,
    String? roomId,
    List<MutualGroup>? mutualGroups,
    bool? isFollowing,
    bool? canViewFollowers,
    bool? canViewFollowing,
    bool? canViewGallery,
    int? followersCount,
    int? followingCount,
  }) {
    return PeerProfileModel(
      searchUser: searchUser ?? this.searchUser,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isMeBanner: isMeBanner ?? this.isMeBanner,
      userPrivacy: userPrivacy ?? this.userPrivacy,
      isOnline: isOnline ?? this.isOnline,
      isPeerBanner: isPeerBanner ?? this.isPeerBanner,
      roomId: roomId ?? this.roomId,
      mutualGroups: mutualGroups ?? this.mutualGroups,
      isFollowing: isFollowing ?? this.isFollowing,
      canViewFollowers: canViewFollowers ?? this.canViewFollowers,
      canViewFollowing: canViewFollowing ?? this.canViewFollowing,
      canViewGallery: canViewGallery ?? this.canViewGallery,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }

  factory PeerProfileModel.fromMap(Map<String, dynamic> map) {
    return PeerProfileModel(
      searchUser: SSearchUser.fromMap(map),
      lastSeenAt: map['lastSeenAt'] as String,
      isMeBanner: map['isMeBanner'] as bool,
      userPrivacy:
          UserPrivacy.fromMap(map['userPrivacy'] as Map<String, dynamic>),
      isOnline: map['isOnline'] as bool,
      isPeerBanner: map['isPeerBanner'] as bool,
      roomId: map['roomId'] == "" ? null : map['roomId'] as String?,
      mutualGroups: (map['mutualGroups'] as List<dynamic>? ?? [])
          .map((group) => MutualGroup.fromMap(group as Map<String, dynamic>))
          .toList(),
      isFollowing: map['isFollowing'] == true,
      canViewFollowers: map['canViewFollowers'] != false,
      canViewFollowing: map['canViewFollowing'] != false,
      canViewGallery: map['canViewGallery'] != false,
      followersCount: (map['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (map['followingCount'] as num?)?.toInt() ?? 0,
    );
  }

//</editor-fold>
}
