// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:http/http.dart' show MultipartFile;

import '../api_service/user_files/user_files_api.dart';
import '../models/storage/user_file_model.dart';

class UserFilesService {
  static final UserFilesApi _api = UserFilesApi.create();

  static Future<List<UserFileModel>> getUserFiles({
    int page = 1,
    int limit = 20,
    String? fileType,
  }) async {
    try {
      final response = await _api.getUserFiles(
        page: page,
        limit: limit,
        fileType: fileType,
      );

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        final filesData = data['data']['files'] as List<dynamic>;

        return filesData
            .map((fileJson) =>
                UserFileModel.fromJson(fileJson as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load files: ${response.error}');
      }
    } catch (e) {
      throw Exception('Error loading files: $e');
    }
  }

  static Future<void> deleteFile(String fileId) async {
    try {
      // First get the file details to know which local file to delete
      final files = await getUserFiles(page: 1, limit: 1000);
      final fileToDelete = files.where((file) => file.id == fileId).firstOrNull;

      final response = await _api.deleteFile(fileId);

      if (!response.isSuccessful) {
        throw Exception('Failed to delete file: ${response.error}');
      }

      // Delete local cached file if found
      if (fileToDelete != null) {
        await _deleteLocalFiles([fileToDelete]);
      }
    } catch (e) {
      throw Exception('Error deleting file: $e');
    }
  }

  static Future<void> deleteMultipleFiles(List<String> fileIds) async {
    try {
      // First get the file details to know which local files to delete
      final files = await getUserFiles(page: 1, limit: 1000);
      final filesToDelete =
          files.where((file) => fileIds.contains(file.id)).toList();

      // Delete from server first
      final response = await _api.deleteMultipleFiles({
        'fileIds': fileIds,
      });

      if (!response.isSuccessful) {
        throw Exception('Failed to delete files: ${response.error}');
      }

      // Delete local cached files
      await _deleteLocalFiles(filesToDelete);
    } catch (e) {
      throw Exception('Error deleting files: $e');
    }
  }

  static Future<void> testEndpoint() async {
    try {
      final response = await _api.testEndpoint({'test': 'data'});
      print('Test endpoint response: ${response.body}');
    } catch (e) {
      print('Test endpoint error: $e');
    }
  }

  static Future<void> testUploadSimple() async {
    try {
      final response = await _api.uploadSimple({'test': 'upload'});
      print('Upload simple response: ${response.body}');
    } catch (e) {
      print('Upload simple error: $e');
    }
  }

  static Future<void> testUploadAny(VPlatformFile file) async {
    try {
      final multipartFile = await VPlatforms.getMultipartFile(source: file);
      final response = await _api.uploadAny(multipartFile);
      print('Upload any response: ${response.body}');
    } catch (e) {
      print('Upload any error: $e');
    }
  }

  static Future<List<UserFileModel>> uploadFiles(
      List<VPlatformFile> files) async {
    try {
      final uploadedFiles = <UserFileModel>[];

      // Upload files one by one
      for (final file in files) {
        final multipartFile = await VPlatforms.getMultipartFile(source: file);

        final response = await _api.uploadFiles(multipartFile);

        if (response.isSuccessful && response.body != null) {
          final data = response.body as Map<String, dynamic>;

          // Check if uploadedFiles exists and is not null
          final uploadedFilesData = data['data']?['uploadedFiles'];

          if (uploadedFilesData != null && uploadedFilesData is List) {
            final fileModels = uploadedFilesData
                .map((fileJson) =>
                    UserFileModel.fromJson(fileJson as Map<String, dynamic>))
                .toList();

            uploadedFiles.addAll(fileModels);
          } else {
            // If there's an error message, show it
            if (data['data']?['error'] != null) {
              throw Exception('Upload failed: ${data['data']['error']}');
            }
          }
        } else {
          throw Exception(
              'Failed to upload file ${file.name}: ${response.error}');
        }
      }

      return uploadedFiles;
    } catch (e) {
      throw Exception('Error uploading files: $e');
    }
  }

  static Future<void> _deleteLocalFiles(List<UserFileModel> files) async {
    try {
      final rootPath = VFileUtils.downloadPath();
      print('🔍 Root storage path: $rootPath');

      // List all files in the directory for debugging
      final dir = Directory(rootPath);
      if (await dir.exists()) {
        final allFiles = await dir.list(recursive: true).toList();
        print('📁 Total files in storage: ${allFiles.length}');
        for (var file in allFiles.take(10)) {
          // Show first 10 files
          if (file is File) {
            final stat = await file.stat();
            print('📄 File: ${file.path.split('/').last} (${stat.size} bytes)');
          }
        }
      }

      for (final file in files) {
        print('🗑️ Trying to delete file: ${file.fileName}');
        print('   - File hash: ${file.fileHash}');
        print('   - Extension: ${file.extension}');
        print('   - Network URL: ${file.networkUrl}');

        // Try multiple possible local file paths
        final possiblePaths = <String>[];

        // Method 1: fileHash + extension
        if (file.fileHash != null && file.extension != null) {
          possiblePaths.add(file.fileHash! + file.extension!);
        }

        // Method 2: Extract filename from networkUrl
        if (file.networkUrl != null) {
          final urlParts = file.networkUrl!.split('/');
          if (urlParts.isNotEmpty) {
            possiblePaths.add(urlParts.last);
          }
        }

        // Method 3: Use original fileName
        possiblePaths.add(file.fileName);

        bool deleted = false;
        for (final possiblePath in possiblePaths) {
          final localFilePath = VFileUtils.getLocalPath(possiblePath);
          final localFile = File(localFilePath);

          print('   - Checking path: $localFilePath');
          if (await localFile.exists()) {
            await localFile.delete();
            print('   ✅ Deleted: $possiblePath');
            deleted = true;
            break;
          }
        }

        if (!deleted) {
          print('   ❌ File not found locally: ${file.fileName}');
        }

        // Also try to remove from cache manager
        if (file.networkUrl != null) {
          try {
            // Import DefaultCacheManager from super_up_core
            final cacheManager = DefaultCacheManager();
            await cacheManager.removeFile(file.networkUrl!);
            print('   🗑️ Removed from cache manager: ${file.networkUrl}');
          } catch (e) {
            print('   ⚠️ Cache manager removal failed: $e');
          }
        }
      }
    } catch (e) {
      print('❌ Error deleting local files: $e');
      // Don't throw error for local file deletion failures
      // Server deletion is more important
    }
  }

  static Future<Map<String, dynamic>> cleanupOrphanedFiles() async {
    try {
      final response = await _api.cleanupOrphanedFiles();

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to cleanup files: ${response.error}');
      }
    } catch (e) {
      throw Exception('Error cleaning up files: $e');
    }
  }

  static Future<String> downloadFile(UserFileModel file) async {
    try {
      if (file.networkUrl == null || file.networkUrl!.isEmpty) {
        throw Exception('File URL is not available');
      }

      // Create a VPlatformFile from the UserFileModel using fromMap
      final platformFile = VPlatformFile.fromMap({
        'name': file.fileName,
        'networkUrl': file.networkUrl,
        'size': file.fileSize,
        'mimeType': file.mimeType ?? '',
        'fileHash': file.fileHash ?? '',
        'extension': file.extension ?? '',
      });

      // Use the existing VFileUtils.saveFileToPublicPath method
      final result = await VFileUtils.saveFileToPublicPath(
        fileAttachment: platformFile,
      );

      return result.isEmpty ? 'File downloaded successfully' : result;
    } catch (e) {
      throw Exception('Error downloading file: $e');
    }
  }
}
