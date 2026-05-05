// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class LiveStreamRecordingModel {
  final String id;
  final String streamId;
  final String title;
  final String? description;
  final String streamerId;
  final StreamerData streamerData;
  final String recordingUrl;
  final String? thumbnailUrl;
  final int duration; // Duration in seconds
  final DateTime recordedAt;
  final int viewCount;
  final int likesCount;
  final List<String> likedBy;
  final List<String> tags;
  final bool isPrivate;
  final List<String> allowedViewers;
  final String status; // 'processing', 'completed', 'failed'
  final int? fileSize;
  final String? quality;
  // Optional price in the app's primary currency (e.g., KES). If null or 0 => free
  final double? price;
  final DateTime createdAt;
  final DateTime updatedAt;

  LiveStreamRecordingModel({
    required this.id,
    required this.streamId,
    required this.title,
    this.description,
    required this.streamerId,
    required this.streamerData,
    required this.recordingUrl,
    this.thumbnailUrl,
    required this.duration,
    required this.recordedAt,
    required this.viewCount,
    required this.likesCount,
    required this.likedBy,
    required this.tags,
    required this.isPrivate,
    required this.allowedViewers,
    required this.status,
    this.fileSize,
    this.quality,
    this.price,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LiveStreamRecordingModel.fromMap(Map<String, dynamic> map) {
    return LiveStreamRecordingModel(
      id: map['_id'] ?? map['id'] ?? '',
      streamId: map['streamId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      streamerId: map['streamerId'] ?? '',
      streamerData: StreamerData.fromMap(map['streamerData'] ?? {}),
      recordingUrl: map['recordingUrl'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      duration: map['duration'] ?? 0,
      recordedAt: DateTime.parse(map['recordedAt'] ?? DateTime.now().toIso8601String()),
      viewCount: map['viewCount'] ?? 0,
      likesCount: map['likesCount'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      isPrivate: map['isPrivate'] ?? false,
      allowedViewers: List<String>.from(map['allowedViewers'] ?? []),
      status: map['status'] ?? 'processing',
      fileSize: map['fileSize'],
      quality: map['quality'],
      price: map['price'] == null
          ? null
          : (map['price'] is int
              ? (map['price'] as int).toDouble()
              : (map['price'] as num?)?.toDouble()),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'streamId': streamId,
      'title': title,
      'description': description,
      'streamerId': streamerId,
      'streamerData': streamerData.toMap(),
      'recordingUrl': recordingUrl,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'recordedAt': recordedAt.toIso8601String(),
      'viewCount': viewCount,
      'likesCount': likesCount,
      'likedBy': likedBy,
      'tags': tags,
      'isPrivate': isPrivate,
      'allowedViewers': allowedViewers,
      'status': status,
      'fileSize': fileSize,
      'quality': quality,
      'price': price,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get formattedRecordedAt {
    final now = DateTime.now();
    final difference = now.difference(recordedAt);
    
    if (difference.inDays > 7) {
      return '${recordedAt.day}/${recordedAt.month}/${recordedAt.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  String get formattedFileSize {
    if (fileSize == null) return 'Unknown';
    
    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;
    
    if (fileSize! >= gb) {
      return '${(fileSize! / gb).toStringAsFixed(1)} GB';
    } else if (fileSize! >= mb) {
      return '${(fileSize! / mb).toStringAsFixed(1)} MB';
    } else if (fileSize! >= kb) {
      return '${(fileSize! / kb).toStringAsFixed(1)} KB';
    } else {
      return '$fileSize B';
    }
  }

  // Recording is considered paid when price > 0
  bool get isPaid => (price ?? 0) > 0;

  String get formattedPrice {
    if (!isPaid) return 'Free';
    // Keep it simple; backend can later provide currency formatting
    final p = price!;
    final isInt = p == p.truncateToDouble();
    return isInt ? 'KES ${p.toStringAsFixed(0)}' : 'KES ${p.toStringAsFixed(2)}';
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
      id: map['_id'] ?? map['id'] ?? '',
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
