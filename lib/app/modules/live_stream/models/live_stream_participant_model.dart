// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class LiveStreamParticipantModel {
  final String id;
  final String streamId;
  final String userId;
  final ParticipantUserData userData;
  final String role;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final bool isActive;

  const LiveStreamParticipantModel({
    required this.id,
    required this.streamId,
    required this.userId,
    required this.userData,
    required this.role,
    required this.joinedAt,
    this.leftAt,
    required this.isActive,
  });

  factory LiveStreamParticipantModel.fromMap(Map<String, dynamic> map) {
    return LiveStreamParticipantModel(
      id: map['_id'] ?? '',
      streamId: map['streamId'] ?? '',
      userId: map['userId'] ?? '',
      userData: ParticipantUserData.fromMap(map['userData'] ?? {}),
      role: map['role'] ?? 'viewer',
      joinedAt: map['joinedAt'] != null 
          ? DateTime.parse(map['joinedAt']) 
          : DateTime.now(),
      leftAt: map['leftAt'] != null 
          ? DateTime.parse(map['leftAt']) 
          : null,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'streamId': streamId,
      'userId': userId,
      'userData': userData.toMap(),
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  LiveStreamParticipantModel copyWith({
    String? id,
    String? streamId,
    String? userId,
    ParticipantUserData? userData,
    String? role,
    DateTime? joinedAt,
    DateTime? leftAt,
    bool? isActive,
  }) {
    return LiveStreamParticipantModel(
      id: id ?? this.id,
      streamId: streamId ?? this.streamId,
      userId: userId ?? this.userId,
      userData: userData ?? this.userData,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiveStreamParticipantModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'LiveStreamParticipantModel(id: $id, userId: $userId, role: $role, isActive: $isActive)';
  }
}

class ParticipantUserData {
  final String id;
  final String fullName;
  final String userImage;

  const ParticipantUserData({
    required this.id,
    required this.fullName,
    required this.userImage,
  });

  factory ParticipantUserData.fromMap(Map<String, dynamic> map) {
    return ParticipantUserData(
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

  ParticipantUserData copyWith({
    String? id,
    String? fullName,
    String? userImage,
  }) {
    return ParticipantUserData(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      userImage: userImage ?? this.userImage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantUserData && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ParticipantUserData(id: $id, fullName: $fullName)';
  }
}
