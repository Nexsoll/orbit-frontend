// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:super_up_core/super_up_core.dart';

class LiveStreamModel {
  final String id;
  final String title;
  final String? description;
  final String streamerId;
  final StreamerData streamerData;
  final String channelName;
  final String agoraToken;
  final LiveStreamStatus status;
  final int viewerCount;
  final int maxViewers;
  final int likesCount;
  final List<String> likedBy;
  final bool isPrivate;
  final bool requiresApproval;
  final double? joinPrice; // price required to join when approval is on
  final List<String> allowedViewers;
  final List<String> tags;
  final String? thumbnailUrl;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? duration;
  final String? pinnedMessageId;
  final DateTime createdAt;
  final DateTime updatedAt;

  LiveStreamModel({
    required this.id,
    required this.title,
    this.description,
    required this.streamerId,
    required this.streamerData,
    required this.channelName,
    required this.agoraToken,
    required this.status,
    required this.viewerCount,
    required this.maxViewers,
    required this.likesCount,
    required this.likedBy,
    required this.isPrivate,
    required this.requiresApproval,
    this.joinPrice,
    required this.allowedViewers,
    required this.tags,
    this.thumbnailUrl,
    this.startedAt,
    this.endedAt,
    this.duration,
    this.pinnedMessageId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LiveStreamModel.fromMap(Map<String, dynamic> map) {
    return LiveStreamModel(
      id: map['_id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      streamerId: map['streamerId'] ?? '',
      streamerData: StreamerData.fromMap(map['streamerData'] ?? {}),
      channelName: map['channelName'] ?? '',
      agoraToken: map['agoraToken'] ?? '',
      status: LiveStreamStatus.fromString(map['status'] ?? 'scheduled'),
      viewerCount: map['viewerCount'] ?? 0,
      maxViewers: map['maxViewers'] ?? 0,
      likesCount: map['likesCount'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      isPrivate: map['isPrivate'] ?? false,
      requiresApproval: map['requiresApproval'] ?? false,
      joinPrice: map['joinPrice'] == null
          ? null
          : (map['joinPrice'] is int
              ? (map['joinPrice'] as int).toDouble()
              : (map['joinPrice'] as num?)?.toDouble()),
      allowedViewers: List<String>.from(map['allowedViewers'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      thumbnailUrl: map['thumbnailUrl'],
      startedAt:
          map['startedAt'] != null ? DateTime.parse(map['startedAt']) : null,
      endedAt: map['endedAt'] != null ? DateTime.parse(map['endedAt']) : null,
      duration: map['duration'],
      pinnedMessageId: map['pinnedMessageId'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  bool get hasJoinFee => (joinPrice ?? 0) > 0;

  String get formattedJoinPrice {
    final p = joinPrice ?? 0;
    if (p <= 0) return 'Free';
    final isInt = p == p.truncateToDouble();
    return isInt ? 'KES ${p.toStringAsFixed(0)}' : 'KES ${p.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'streamerId': streamerId,
      'streamerData': streamerData.toMap(),
      'channelName': channelName,
      'agoraToken': agoraToken,
      'status': status.toString(),
      'viewerCount': viewerCount,
      'maxViewers': maxViewers,
      'likesCount': likesCount,
      'likedBy': likedBy,
      'isPrivate': isPrivate,
      'requiresApproval': requiresApproval,
      'joinPrice': joinPrice,
      'allowedViewers': allowedViewers,
      'tags': tags,
      'thumbnailUrl': thumbnailUrl,
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'duration': duration,
      'pinnedMessageId': pinnedMessageId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  LiveStreamModel copyWith({
    String? id,
    String? title,
    String? description,
    String? streamerId,
    StreamerData? streamerData,
    String? channelName,
    String? agoraToken,
    LiveStreamStatus? status,
    int? viewerCount,
    int? maxViewers,
    int? likesCount,
    List<String>? likedBy,
    bool? isPrivate,
    bool? requiresApproval,
    double? joinPrice,
    List<String>? allowedViewers,
    List<String>? tags,
    String? thumbnailUrl,
    DateTime? startedAt,
    DateTime? endedAt,
    int? duration,
    String? pinnedMessageId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LiveStreamModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      streamerId: streamerId ?? this.streamerId,
      streamerData: streamerData ?? this.streamerData,
      channelName: channelName ?? this.channelName,
      agoraToken: agoraToken ?? this.agoraToken,
      status: status ?? this.status,
      viewerCount: viewerCount ?? this.viewerCount,
      maxViewers: maxViewers ?? this.maxViewers,
      likesCount: likesCount ?? this.likesCount,
      likedBy: likedBy ?? this.likedBy,
      isPrivate: isPrivate ?? this.isPrivate,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      joinPrice: joinPrice ?? this.joinPrice,
      allowedViewers: allowedViewers ?? this.allowedViewers,
      tags: tags ?? this.tags,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      pinnedMessageId: pinnedMessageId ?? this.pinnedMessageId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StreamerData {
  final String id;
  final String fullName;
  final String userImage;

  StreamerData({
    required this.id,
    required this.fullName,
    required this.userImage,
  });

  factory StreamerData.fromMap(Map<String, dynamic> map) {
    return StreamerData(
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
}

enum LiveStreamStatus {
  scheduled,
  live,
  ended,
  cancelled;

  static LiveStreamStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return LiveStreamStatus.scheduled;
      case 'live':
        return LiveStreamStatus.live;
      case 'ended':
        return LiveStreamStatus.ended;
      case 'cancelled':
        return LiveStreamStatus.cancelled;
      default:
        return LiveStreamStatus.scheduled;
    }
  }

  @override
  String toString() {
    switch (this) {
      case LiveStreamStatus.scheduled:
        return 'scheduled';
      case LiveStreamStatus.live:
        return 'live';
      case LiveStreamStatus.ended:
        return 'ended';
      case LiveStreamStatus.cancelled:
        return 'cancelled';
    }
  }
}

class LiveStreamParticipantModel {
  final String id;
  final String streamId;
  final String userId;
  final StreamerData userData;
  final ParticipantRole role;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final bool isActive;

  LiveStreamParticipantModel({
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
      userData: StreamerData.fromMap(map['userData'] ?? {}),
      role: ParticipantRole.fromString(map['role'] ?? 'viewer'),
      joinedAt: DateTime.parse(map['joinedAt']),
      leftAt: map['leftAt'] != null ? DateTime.parse(map['leftAt']) : null,
      isActive: map['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'streamId': streamId,
      'userId': userId,
      'userData': userData.toMap(),
      'role': role.toString(),
      'joinedAt': joinedAt.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
      'isActive': isActive,
    };
  }
}

enum ParticipantRole {
  streamer,
  viewer,
  moderator;

  static ParticipantRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'streamer':
        return ParticipantRole.streamer;
      case 'viewer':
        return ParticipantRole.viewer;
      case 'moderator':
        return ParticipantRole.moderator;
      default:
        return ParticipantRole.viewer;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ParticipantRole.streamer:
        return 'streamer';
      case ParticipantRole.viewer:
        return 'viewer';
      case ParticipantRole.moderator:
        return 'moderator';
    }
  }
}

class LiveStreamMessageModel {
  final String id;
  final String streamId;
  final String userId;
  final StreamerData userData;
  final String message;
  final String messageType;
  final Map<String, dynamic>? giftData;
  final bool isPinned;
  final DateTime? pinnedAt;
  final String? pinnedBy;
  final DateTime createdAt;

  LiveStreamMessageModel({
    required this.id,
    required this.streamId,
    required this.userId,
    required this.userData,
    required this.message,
    required this.messageType,
    this.giftData,
    this.isPinned = false,
    this.pinnedAt,
    this.pinnedBy,
    required this.createdAt,
  });

  factory LiveStreamMessageModel.fromMap(Map<String, dynamic> map) {
    return LiveStreamMessageModel(
      id: map['_id'] ?? '',
      streamId: map['streamId'] ?? '',
      userId: map['userId'] ?? '',
      userData: StreamerData.fromMap(map['userData'] ?? {}),
      message: map['message'] ?? '',
      messageType: map['messageType'] ?? 'text',
      giftData: map['giftData'],
      isPinned: map['isPinned'] ?? false,
      pinnedAt:
          map['pinnedAt'] != null ? DateTime.parse(map['pinnedAt']) : null,
      pinnedBy: map['pinnedBy'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'streamId': streamId,
      'userId': userId,
      'userData': userData.toMap(),
      'message': message,
      'messageType': messageType,
      'giftData': giftData,
      'isPinned': isPinned,
      'pinnedAt': pinnedAt?.toIso8601String(),
      'pinnedBy': pinnedBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
