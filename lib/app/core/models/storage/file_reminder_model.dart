// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class FileReminderModel {
  final String id;
  final String userId;
  final String fileId;
  final String fileName;
  final int fileSize;
  final DateTime fileCreatedAt;
  final ReminderType reminderType;
  final DateTime reminderDate;
  final bool isActive;
  final bool isCompleted;
  final String? customMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  FileReminderModel({
    required this.id,
    required this.userId,
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    required this.fileCreatedAt,
    required this.reminderType,
    required this.reminderDate,
    required this.isActive,
    required this.isCompleted,
    this.customMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FileReminderModel.fromJson(Map<String, dynamic> json) {
    return FileReminderModel(
      id: json['_id'] ?? json['id'],
      userId: json['userId'],
      fileId: json['fileId'],
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      fileCreatedAt: DateTime.parse(json['fileCreatedAt']),
      reminderType: ReminderType.values.firstWhere(
        (e) => e.name == json['reminderType'],
        orElse: () => ReminderType.oldFile,
      ),
      reminderDate: DateTime.parse(json['reminderDate']),
      isActive: json['isActive'] ?? true,
      isCompleted: json['isCompleted'] ?? false,
      customMessage: json['customMessage'],
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
      'fileSize': fileSize,
      'fileCreatedAt': fileCreatedAt.toIso8601String(),
      'reminderType': reminderType.name,
      'reminderDate': reminderDate.toIso8601String(),
      'isActive': isActive,
      'isCompleted': isCompleted,
      'customMessage': customMessage,
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

  bool get isDue => DateTime.now().isAfter(reminderDate);
  bool get isOverdue => isDue && !isCompleted;

  String get defaultMessage {
    switch (reminderType) {
      case ReminderType.oldFile:
        return 'This file is ${_getFileAge()} old. Consider deleting it to free up space.';
      case ReminderType.storageLimit:
        return 'Your storage is almost full. Consider deleting this file.';
      case ReminderType.custom:
        return customMessage ?? 'File reminder';
    }
  }

  String _getFileAge() {
    final now = DateTime.now();
    final difference = now.difference(fileCreatedAt);
    
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years} year${years > 1 ? 's' : ''}';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months} month${months > 1 ? 's' : ''}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else {
      return 'less than a day';
    }
  }

  FileReminderModel copyWith({
    String? id,
    String? userId,
    String? fileId,
    String? fileName,
    int? fileSize,
    DateTime? fileCreatedAt,
    ReminderType? reminderType,
    DateTime? reminderDate,
    bool? isActive,
    bool? isCompleted,
    String? customMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FileReminderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileCreatedAt: fileCreatedAt ?? this.fileCreatedAt,
      reminderType: reminderType ?? this.reminderType,
      reminderDate: reminderDate ?? this.reminderDate,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      customMessage: customMessage ?? this.customMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum ReminderType {
  oldFile,
  storageLimit,
  custom,
}

extension ReminderTypeExtension on ReminderType {
  String get displayName {
    switch (this) {
      case ReminderType.oldFile:
        return 'Old File';
      case ReminderType.storageLimit:
        return 'Storage Limit';
      case ReminderType.custom:
        return 'Custom';
    }
  }

  String get icon {
    switch (this) {
      case ReminderType.oldFile:
        return '🗓️';
      case ReminderType.storageLimit:
        return '⚠️';
      case ReminderType.custom:
        return '📝';
    }
  }
}
