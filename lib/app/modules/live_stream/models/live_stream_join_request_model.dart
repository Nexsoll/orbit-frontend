// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class LiveStreamJoinRequestModel {
  final String id;
  final String streamId;
  final String userId;
  final JoinRequestUserData userData;
  final String status; // 'pending', 'approved', 'denied'
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final String? respondedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LiveStreamJoinRequestModel({
    required this.id,
    required this.streamId,
    required this.userId,
    required this.userData,
    required this.status,
    required this.requestedAt,
    this.respondedAt,
    this.respondedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LiveStreamJoinRequestModel.fromMap(Map<String, dynamic> map) {
    return LiveStreamJoinRequestModel(
      id: map['_id'] ?? '',
      streamId: map['streamId'] ?? '',
      userId: map['userId'] ?? '',
      userData: JoinRequestUserData.fromMap(map['userData'] ?? {}),
      status: map['status'] ?? 'pending',
      requestedAt: map['requestedAt'] != null 
          ? DateTime.parse(map['requestedAt']) 
          : DateTime.now(),
      respondedAt: map['respondedAt'] != null 
          ? DateTime.parse(map['respondedAt']) 
          : null,
      respondedBy: map['respondedBy'],
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'streamId': streamId,
      'userId': userId,
      'userData': userData.toMap(),
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'respondedBy': respondedBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  LiveStreamJoinRequestModel copyWith({
    String? id,
    String? streamId,
    String? userId,
    JoinRequestUserData? userData,
    String? status,
    DateTime? requestedAt,
    DateTime? respondedAt,
    String? respondedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LiveStreamJoinRequestModel(
      id: id ?? this.id,
      streamId: streamId ?? this.streamId,
      userId: userId ?? this.userId,
      userData: userData ?? this.userData,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      respondedBy: respondedBy ?? this.respondedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class JoinRequestUserData {
  final String id;
  final String fullName;
  final String userImage;

  const JoinRequestUserData({
    required this.id,
    required this.fullName,
    required this.userImage,
  });

  factory JoinRequestUserData.fromMap(Map<String, dynamic> map) {
    return JoinRequestUserData(
      id: map['_id'] ?? '',
      fullName: map['fullName'] ?? '',
      userImage: map['userImage'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'fullName': fullName,
      'userImage': userImage,
    };
  }

  JoinRequestUserData copyWith({
    String? id,
    String? fullName,
    String? userImage,
  }) {
    return JoinRequestUserData(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      userImage: userImage ?? this.userImage,
    );
  }
}
