// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../../core/models/storage/user_file_model.dart';
import '../../../core/services/user_files_service.dart';
import '../../../core/services/storage_warning_service.dart';
import '../../../core/services/subscription_manager.dart';
import '../widgets/file_list_item.dart';
import 'premium_upgrade_page.dart';

class ManageStoragePage extends StatefulWidget {
  const ManageStoragePage({super.key});

  @override
  State<ManageStoragePage> createState() => _ManageStoragePageState();
}

class _ManageStoragePageState extends State<ManageStoragePage> {
  List<UserFileModel> _files = [];
  List<String> _selectedFiles = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  bool _isUploading = false;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await UserFilesService.getUserFiles(
        page: 1,
        limit: 100,
        fileType: _selectedFilter == 'all' ? null : _selectedFilter,
      );
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      VAppAlert.showOkAlertDialog(
        context: context,
        title: "Error",
        content: "Error loading files: $e",
      );
    }
  }

  void _toggleSelection(String fileId) {
    setState(() {
      if (_selectedFiles.contains(fileId)) {
        _selectedFiles.remove(fileId);
      } else {
        _selectedFiles.add(fileId);
      }
      _isSelectionMode = _selectedFiles.isNotEmpty;
    });
  }

  void _selectAll() {
    setState(() {
      _selectedFiles = _files.map((f) => f.id).toList();
      _isSelectionMode = true;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFiles.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;

    final confirmed = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: "Delete Files",
      content:
          "Are you sure you want to permanently delete ${_selectedFiles.length} file(s)? This action cannot be undone.",
    );

    if (confirmed != 1) return;

    try {
      await UserFilesService.deleteMultipleFiles(_selectedFiles);

      setState(() {
        _files.removeWhere((file) => _selectedFiles.contains(file.id));
        _selectedFiles.clear();
        _isSelectionMode = false;
      });

      // Refresh storage usage after deletion
      final storageService = StorageWarningService();
      await storageService.checkStorageUsage();

      VAppAlert.showOkAlertDialog(
        context: context,
        title: "Success",
        content: "Files deleted successfully",
      );
    } catch (e) {
      VAppAlert.showOkAlertDialog(
        context: context,
        title: "Error",
        content: "Error deleting files: $e",
      );
    }
  }

  Future<void> _uploadFiles() async {
    try {
      // Check storage limit first
      final storageService = StorageWarningService();
      await storageService.checkStorageUsage();

      if (storageService.isStorageFull) {
        final subscriptionManager = SubscriptionManager();
        final currentLimit = subscriptionManager.storageLimit;

        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text("Storage Full"),
            content: Text(
              "You have reached your ${currentLimit}GB storage limit. Please delete some files or upgrade to a higher plan to continue uploading.",
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(context).pop(),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text("Upgrade Plan"),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => const PremiumUpgradePage(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
        return;
      }

      // Show file picker options
      final result = await showCupertinoModalPopup<String>(
        context: context,
        builder: (BuildContext context) => CupertinoActionSheet(
          title: const Text('Upload Files'),
          message: const Text('Choose the type of files to upload'),
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'files'),
              child: const Text('Documents & Files'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'media'),
              child: const Text('Photos & Videos'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      );

      if (result == null) return;

      List<VPlatformFile>? selectedFiles;

      switch (result) {
        case 'files':
          selectedFiles = await VAppPick.getFiles();
          break;
        case 'media':
          selectedFiles = await VAppPick.getMedia();
          break;
      }

      if (selectedFiles == null || selectedFiles.isEmpty) return;

      // Check if selected files would exceed storage limit
      final fileSizes = selectedFiles.map((file) => file.fileSize).toList();
      if (!storageService.canUploadFiles(fileSizes)) {
        final totalSize = fileSizes.fold<int>(0, (sum, size) => sum + size);
        final remainingSpace = storageService.remainingStorageBytes;

        VAppAlert.showOkAlertDialog(
          context: context,
          title: "Storage Limit Exceeded",
          content:
              "Selected files (${storageService.formatBytes(totalSize.toDouble())}) would exceed your storage limit. You have ${storageService.formatBytes(remainingSpace.toDouble())} remaining. Please select smaller files or delete existing files first.",
        );
        return;
      }

      setState(() {
        _isUploading = true;
      });

      // Show loading dialog
      VAppAlert.showLoading(context: context);

      try {
        final uploadedFiles = await UserFilesService.uploadFiles(selectedFiles);

        setState(() {
          _files.insertAll(0, uploadedFiles); // Add to beginning of list
          _isUploading = false;
        });

        // Refresh storage usage after upload
        await storageService.checkStorageUsage();

        Navigator.of(context).pop(); // Close loading dialog

        VAppAlert.showOkAlertDialog(
          context: context,
          title: "Success",
          content: "Successfully uploaded ${uploadedFiles.length} file(s)",
        );
      } catch (e) {
        setState(() {
          _isUploading = false;
        });

        Navigator.of(context).pop(); // Close loading dialog

        VAppAlert.showOkAlertDialog(
          context: context,
          title: "Upload Error",
          content: "Failed to upload files: $e",
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      VAppAlert.showOkAlertDialog(
        context: context,
        title: "Error",
        content: "Error selecting files: $e",
      );
    }
  }

  Future<void> _downloadFile(UserFileModel file) async {
    try {
      // Show loading indicator
      VAppAlert.showLoading(context: context);

      final result = await UserFilesService.downloadFile(file);

      Navigator.of(context).pop(); // Close loading dialog

      VAppAlert.showOkAlertDialog(
        context: context,
        title: "Download Complete",
        content: result,
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog

      VAppAlert.showOkAlertDialog(
        context: context,
        title: "Download Error",
        content: "Failed to download file: $e",
      );
    }
  }

  Widget _buildFilterTab({
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color:
                isSelected ? CupertinoColors.white : CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? CupertinoColors.white
                  : CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              CupertinoSliverNavigationBar(
                transitionBetweenRoutes: false, // 👈 disables Hero animation
                largeTitle: const Text('Manage Storage'),
                leading: _isSelectionMode
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _clearSelection,
                        child: const Text('Cancel'),
                      )
                    : null,
              )
            ],
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Filter tabs
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CupertinoSegmentedControl<String>(
                        borderColor: CupertinoColors.systemGrey4,
                        selectedColor: CupertinoColors.activeGreen,
                        unselectedColor: CupertinoColors.systemBackground,
                        pressedColor: CupertinoColors.systemGrey5,
                        children: {
                          'all': _buildFilterTab(
                            icon: CupertinoIcons.square_grid_2x2,
                            label: 'All',
                            isSelected: _selectedFilter == 'all',
                          ),
                          'image': _buildFilterTab(
                            icon: CupertinoIcons.photo,
                            label: 'Images',
                            isSelected: _selectedFilter == 'image',
                          ),
                          'video': _buildFilterTab(
                            icon: CupertinoIcons.videocam,
                            label: 'Videos',
                            isSelected: _selectedFilter == 'video',
                          ),
                          'file': _buildFilterTab(
                            icon: CupertinoIcons.doc_text,
                            label: 'Docs',
                            isSelected: _selectedFilter == 'file',
                          ),
                        },
                        onValueChanged: (value) {
                          setState(() {
                            _selectedFilter = value;
                          });
                          _loadFiles();
                        },
                        groupValue: _selectedFilter,
                      ),
                    ),
                  ),

                  // Action bar
                  if (_files.isNotEmpty && !_isSelectionMode)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_files.length} files',
                            style: const TextStyle(
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _selectAll,
                            child: const Text('Select All'),
                          ),
                        ],
                      ),
                    ),

                  if (_isSelectionMode)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedFiles.length} selected',
                            style: const TextStyle(
                              color: CupertinoColors.activeBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _deleteSelectedFiles,
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Files list
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CupertinoActivityIndicator(),
                          )
                        : _files.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.cloud_upload,
                                      size: 64,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No files found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Tap the + button to upload files to your storage',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _files.length,
                                itemBuilder: (context, index) {
                                  final file = _files[index];
                                  final isSelected =
                                      _selectedFiles.contains(file.id);

                                  return FileListItem(
                                    file: file,
                                    isSelected: isSelected,
                                    isSelectionMode: _isSelectionMode,
                                    onTap: () => _toggleSelection(file.id),
                                    onLongPress: () {
                                      if (!_isSelectionMode) {
                                        _toggleSelection(file.id);
                                      }
                                    },
                                    onDownload: () => _downloadFile(file),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Action Button
          if (!_isSelectionMode)
            Positioned(
              bottom: 30,
              right: 20,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isUploading ? null : _uploadFiles,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isUploading
                        ? CupertinoColors.systemGrey
                        : CupertinoColors.activeBlue,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isUploading
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        )
                      : const Icon(
                          CupertinoIcons.add,
                          color: CupertinoColors.white,
                          size: 28,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
