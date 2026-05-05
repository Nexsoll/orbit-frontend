// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class CreateStorageMetadataDto {
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

  CreateStorageMetadataDto({
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
  });

  Map<String, dynamic> toJson() {
    return {
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
    };
  }
}

class CreateFileReminderDto {
  final String fileId;
  final String fileName;
  final int fileSize;
  final DateTime fileCreatedAt;
  final String reminderType; // 'oldFile', 'storageLimit', 'custom'
  final DateTime reminderDate;
  final String? customMessage;

  CreateFileReminderDto({
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    required this.fileCreatedAt,
    required this.reminderType,
    required this.reminderDate,
    this.customMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'fileId': fileId,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileCreatedAt': fileCreatedAt.toIso8601String(),
      'reminderType': reminderType,
      'reminderDate': reminderDate.toIso8601String(),
      'customMessage': customMessage,
    };
  }
}

class UpdateFileReminderDto {
  final bool? isActive;
  final bool? isCompleted;
  final DateTime? reminderDate;
  final String? customMessage;

  UpdateFileReminderDto({
    this.isActive,
    this.isCompleted,
    this.reminderDate,
    this.customMessage,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (isActive != null) data['isActive'] = isActive;
    if (isCompleted != null) data['isCompleted'] = isCompleted;
    if (reminderDate != null) data['reminderDate'] = reminderDate!.toIso8601String();
    if (customMessage != null) data['customMessage'] = customMessage;
    return data;
  }
}

class UpgradeToPremiumDto {
  final String planType; // 'monthly', 'yearly'
  final String? paymentMethodId;
  final Map<String, dynamic>? paymentMetadata;

  UpgradeToPremiumDto({
    required this.planType,
    this.paymentMethodId,
    this.paymentMetadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'planType': planType,
      'paymentMethodId': paymentMethodId,
      'paymentMetadata': paymentMetadata,
    };
  }
}

class StorageUsageQueryDto {
  final String? fileType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? page;
  final int? limit;

  StorageUsageQueryDto({
    this.fileType,
    this.startDate,
    this.endDate,
    this.page,
    this.limit,
  });

  Map<String, dynamic> toQueryParams() {
    final Map<String, dynamic> params = {};
    if (fileType != null) params['fileType'] = fileType;
    if (startDate != null) params['startDate'] = startDate!.toIso8601String();
    if (endDate != null) params['endDate'] = endDate!.toIso8601String();
    if (page != null) params['page'] = page.toString();
    if (limit != null) params['limit'] = limit.toString();
    return params;
  }
}

class FileRemindersQueryDto {
  final bool? isActive;
  final bool? isCompleted;
  final String? reminderType;
  final int? page;
  final int? limit;

  FileRemindersQueryDto({
    this.isActive,
    this.isCompleted,
    this.reminderType,
    this.page,
    this.limit,
  });

  Map<String, dynamic> toQueryParams() {
    final Map<String, dynamic> params = {};
    if (isActive != null) params['isActive'] = isActive.toString();
    if (isCompleted != null) params['isCompleted'] = isCompleted.toString();
    if (reminderType != null) params['reminderType'] = reminderType;
    if (page != null) params['page'] = page.toString();
    if (limit != null) params['limit'] = limit.toString();
    return params;
  }
}
