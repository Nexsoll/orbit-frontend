// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class StorageMetadataModel {
  final String id;
  final String userId;
  final String fileId;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String fileType;
  final String mimeType;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final Map<String, dynamic>? additionalMetadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  StorageMetadataModel({
    required this.id,
    required this.userId,
    required this.fileId,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.fileType,
    required this.mimeType,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.locationName,
    this.additionalMetadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StorageMetadataModel.fromJson(Map<String, dynamic> json) {
    return StorageMetadataModel(
      id: json['_id'] ?? json['id'],
      userId: json['userId'],
      fileId: json['fileId'],
      fileName: json['fileName'],
      filePath: json['filePath'],
      fileSize: json['fileSize'],
      fileType: json['fileType'],
      mimeType: json['mimeType'],
      capturedAt: DateTime.parse(json['capturedAt']),
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      locationName: json['locationName'],
      additionalMetadata: json['additionalMetadata'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fileId': fileId,
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
      'fileType': fileType,
      'mimeType': mimeType,
      'capturedAt': capturedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'additionalMetadata': additionalMetadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get readableSize {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  bool get hasLocation => latitude != null && longitude != null;

  StorageFileType get storageFileType {
    if (mimeType.startsWith('image/')) return StorageFileType.image;
    if (mimeType.startsWith('video/')) return StorageFileType.video;
    if (mimeType.startsWith('audio/')) return StorageFileType.audio;
    return StorageFileType.document;
  }
}

enum StorageFileType {
  image,
  video,
  audio,
  document,
}

extension StorageFileTypeExtension on StorageFileType {
  String get displayName {
    switch (this) {
      case StorageFileType.image:
        return 'Images';
      case StorageFileType.video:
        return 'Videos';
      case StorageFileType.audio:
        return 'Audio';
      case StorageFileType.document:
        return 'Documents';
    }
  }

  String get icon {
    switch (this) {
      case StorageFileType.image:
        return '📷';
      case StorageFileType.video:
        return '🎥';
      case StorageFileType.audio:
        return '🎵';
      case StorageFileType.document:
        return '📄';
    }
  }
}
