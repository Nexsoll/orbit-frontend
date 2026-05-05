// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

class UserFileModel {
  final String id;
  final String messageId;
  final String senderId;
  final String senderName;
  final String roomId;
  final String messageType;
  final String fileName;
  final int fileSize;
  final String? fileHash;
  final String? extension;
  final String? mimeType;
  final String? networkUrl;
  final DateTime createdAt;
  final String fileType;

  UserFileModel({
    required this.id,
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.roomId,
    required this.messageType,
    required this.fileName,
    required this.fileSize,
    this.fileHash,
    this.extension,
    this.mimeType,
    this.networkUrl,
    required this.createdAt,
    required this.fileType,
  });

  factory UserFileModel.fromJson(Map<String, dynamic> json) {
    return UserFileModel(
      id: json['id']?.toString() ?? '',
      messageId: json['messageId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      roomId: json['roomId']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
      fileHash: json['fileHash']?.toString(),
      extension: json['extension']?.toString(),
      mimeType: json['mimeType']?.toString(),
      networkUrl: json['networkUrl']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      fileType: json['fileType']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'roomId': roomId,
      'messageType': messageType,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileHash': fileHash,
      'extension': extension,
      'mimeType': mimeType,
      'networkUrl': networkUrl,
      'createdAt': createdAt.toIso8601String(),
      'fileType': fileType,
    };
  }

  String get readableSize {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String get fileTypeDisplayName {
    switch (fileType.toLowerCase()) {
      case 'image':
        return 'Image';
      case 'video':
        return 'Video';
      case 'file':
        return 'Document';
      default:
        return 'File';
    }
  }

  IconData get fileTypeIcon {
    switch (fileType.toLowerCase()) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'file':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get fileTypeColor {
    switch (fileType.toLowerCase()) {
      case 'image':
        return Colors.green;
      case 'video':
        return Colors.blue;
      case 'file':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
