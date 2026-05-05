// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class UserDeviceModel {
  final String id;
  final String userDeviceId;
  final String platform;
  final String language;
  final String createdAt;
  final String lastSeenAt;
  final int visits;

//<editor-fold desc="Data Methods">
  const UserDeviceModel({
    required this.id,
    required this.userDeviceId,
    required this.platform,
    required this.language,
    required this.createdAt,
    required this.lastSeenAt,
    required this.visits,
  });

  DateTime get createdAtLocal => DateTime.parse(createdAt).toLocal();
  DateTime get lastSeenAtLocal => DateTime.parse(lastSeenAt).toLocal();

  @override
  String toString() {
    return 'UserDeviceModel{ userDeviceId: $userDeviceId, platform: $platform, language: $language,}';
  }

  Map<String, dynamic> toMap() {
    return {
      'userDeviceId': userDeviceId,
      '_id': id,
      'platform': platform,
      'language': language,
      'createdAt': createdAt,
      'visits': visits,
      'lastSeenAt': lastSeenAt,
    };
  }

  factory UserDeviceModel.fromMap(Map<String, dynamic> map) {
    return UserDeviceModel(
      userDeviceId: map['userDeviceId'] as String,
      id: map['_id'] as String,
      platform: map['platform'] as String,
      language: map['language'] as String,
      createdAt: map['createdAt'] as String,
      lastSeenAt: map['lastSeenAt'] as String,
      visits: map['visits'] as int,
    );
  }

//</editor-fold>
}
