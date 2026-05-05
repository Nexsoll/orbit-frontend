// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';

import '../controllers/saved_lives_controller.dart';
import '../models/live_stream_recording_model.dart';
import 'widgets/recording_card.dart';
import 'recording_player_view.dart';
import '../models/live_category_model.dart';

class SavedLivesView extends StatefulWidget {
  const SavedLivesView({super.key});

  @override
  State<SavedLivesView> createState() => _SavedLivesViewState();
}

class _SavedLivesViewState extends State<SavedLivesView> {
  late final SavedLivesController controller;

  @override
  void initState() {
    super.initState();
    controller = GetIt.I.get<SavedLivesController>();
    
    // Load recordings when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadRecordings();
      controller.loadCategories();
    });
  }

  @override
  void dispose() {
    // Don't dispose the singleton controller, just clean up local references
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Saved Lives'),
        backgroundColor: Colors.transparent,
        border: null,
      ),
      child: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: controller.isLoading,
          builder: (context, isLoading, child) {
            if (isLoading) {
              return const Center(
                child: CupertinoActivityIndicator(
                  radius: 20,
                  color: CupertinoColors.systemBlue,
                ),
              );
            }

            return ValueListenableBuilder<List<LiveStreamRecordingModel>>(
              valueListenable: controller.recordings,
              builder: (context, recordings, child) {
                if (recordings.isEmpty) {
                  return _buildEmptyState();
                }

                return CustomScrollView(
                  slivers: [
                    // Filter options
                    SliverToBoxAdapter(
                      child: _buildFilterSection(),
                    ),
                    
                    // Recordings grid
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final recording = recordings[index];
                            return RecordingCard(
                              recording: recording,
                              onTap: () => _playRecording(recording),
                              onDelete: () => _deleteRecording(recording),
                            );
                          },
                          childCount: recordings.length,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showCategoryFilter() {
    final categories = controller.availableCategories.value;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Filter by Category'),
        message: const Text('Choose a category to filter saved lives'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              controller.selectCategory(null);
              Navigator.pop(context);
            },
            child: const Text('All Categories'),
          ),
          ...categories.map((c) => CupertinoActionSheetAction(
                onPressed: () {
                  controller.selectCategory(c);
                  Navigator.pop(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.tag,
                      size: 16,
                      color: controller.selectedCategory.value?.id == c.id
                          ? const Color(0xFFB48648)
                          : CupertinoColors.label,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      c.name,
                      style: TextStyle(
                        color: controller.selectedCategory.value?.id == c.id
                            ? const Color(0xFFB48648)
                            : CupertinoColors.label,
                        fontWeight: controller.selectedCategory.value?.id == c.id
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              )),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.video_camera,
            size: 80,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 24),
          const Text(
            'No Saved Lives',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your recorded live streams will appear here.\nStart a live stream and tap the record button to save it.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 32),
          CupertinoButton.filled(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Start Live Stream'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: CupertinoSearchTextField(
              placeholder: 'Search recordings...',
              onChanged: controller.searchRecordings,
            ),
          ),
          const SizedBox(width: 12),
          // Category filter button
          ValueListenableBuilder<LiveCategoryModel?>(
            valueListenable: controller.selectedCategory,
            builder: (context, selected, _) {
              final label = selected?.name ?? 'Category';
              return CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: const Color(0xFFB48648),
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.tag, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                onPressed: () => _showCategoryFilter(),
              );
            },
          ),
          const SizedBox(width: 8),
          // Sort button – brand brown
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFB48648),
            borderRadius: BorderRadius.circular(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(CupertinoIcons.sort_down, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text('Sort', style: TextStyle(fontSize: 14, color: Colors.white)),
              ],
            ),
            onPressed: () => _showSortOptions(),
          ),
        ],
      ),
    );
  }

  void _showSortOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Sort Recordings'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Newest First'),
            onPressed: () {
              Navigator.pop(context);
              controller.sortRecordings('newest');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Oldest First'),
            onPressed: () {
              Navigator.pop(context);
              controller.sortRecordings('oldest');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Most Viewed'),
            onPressed: () {
              Navigator.pop(context);
              controller.sortRecordings('views');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Most Liked'),
            onPressed: () {
              Navigator.pop(context);
              controller.sortRecordings('likes');
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _playRecording(LiveStreamRecordingModel recording) {
    if (recording.status != 'completed') {
      VAppAlert.showErrorSnackBar(
        message: 'Recording is ${recording.status}. Please try again later.',
        context: context,
      );
      return;
    }

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => RecordingPlayerView(recording: recording),
      ),
    );
  }

  void _deleteRecording(LiveStreamRecordingModel recording) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Delete Recording'),
          content: Text('Are you sure you want to delete "${recording.title}"? This action cannot be undone.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await controller.deleteRecording(recording.id);
                  VAppAlert.showSuccessSnackBar(
                    message: 'Recording deleted successfully',
                    context: context,
                  );
                } catch (e) {
                  VAppAlert.showErrorSnackBar(
                    message: 'Failed to delete recording: ${e.toString()}',
                    context: context,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
