// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';

import '../controllers/all_saved_streams_controller.dart';
import '../models/live_stream_recording_model.dart';
import '../models/live_category_model.dart';
import 'widgets/recording_card.dart';
import 'widgets/stream_payment_modal.dart';
import 'recording_player_view.dart';
import '../services/live_stream_api_service.dart';

class AllSavedStreamsView extends StatefulWidget {
  const AllSavedStreamsView({super.key});

  @override
  State<AllSavedStreamsView> createState() => _AllSavedStreamsViewState();
}

class _AllSavedStreamsViewState extends State<AllSavedStreamsView> {
  late final AllSavedStreamsController controller;
  late final LiveStreamApiService _apiService;

  @override
  void initState() {
    super.initState();
    controller = GetIt.I.get<AllSavedStreamsController>();
    _apiService = GetIt.I.get<LiveStreamApiService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadRecordings();
      controller.loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('All Saved Streams'),
        backgroundColor: Colors.transparent,
        border: null,
      ),
      child: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: controller.isLoading,
          builder: (context, isLoading, _) {
            if (isLoading) {
              return const Center(
                child: CupertinoActivityIndicator(radius: 20, color: CupertinoColors.systemBlue),
              );
            }

            return ValueListenableBuilder<List<LiveStreamRecordingModel>>(
              valueListenable: controller.recordings,
              builder: (context, items, _) {
                if (items.isEmpty) {
                  return _buildEmptyState();
                }

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildFilterSection()),
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
                            final recording = items[index];
                            return RecordingCard(
                              recording: recording,
                              onTap: () => _playRecording(recording, index, items),
                              onDelete: () {},
                              allowDelete: false,
                              showPriceBadge: true,
                              showMoreMenu: true,
                              shareOnlyMenu: false,
                            );
                          },
                          childCount: items.length,
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

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: CupertinoSearchTextField(
              placeholder: 'Search all recordings...',
              onChanged: controller.searchRecordings,
            ),
          ),
          const SizedBox(width: 12),
          ValueListenableBuilder<LiveCategoryModel?>(
            valueListenable: controller.selectedCategory,
            builder: (context, selected, _) {
              final label = selected?.name ?? 'Category';
              return CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: const Color(0xFFB48648),
                borderRadius: BorderRadius.circular(20),
                onPressed: _showCategoryFilter,
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
              );
            },
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFB48648),
            borderRadius: BorderRadius.circular(20),
            onPressed: _showSortOptions,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.sort_down, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text('Sort', style: TextStyle(fontSize: 14, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryFilter() {
    final categories = controller.availableCategories.value;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filter by Category'),
        message: const Text('Public saved streams by category'),
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

  void _showSortOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
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
          CupertinoActionSheetAction(
            child: const Text('Longest Duration'),
            onPressed: () {
              Navigator.pop(context);
              controller.sortRecordings('duration');
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(CupertinoIcons.video_camera, size: 80, color: CupertinoColors.systemGrey),
          SizedBox(height: 24),
          Text(
            'No Saved Streams Yet',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: CupertinoColors.label),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'When users end their live streams and save recordings, they will appear here for everyone to watch.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: CupertinoColors.secondaryLabel),
            ),
          ),
        ],
      ),
    );
  }

  void _playRecording(
    LiveStreamRecordingModel recording,
    int index,
    List<LiveStreamRecordingModel> playlist,
  ) {
    if (recording.status != 'completed') {
      VAppAlert.showErrorSnackBar(
        message: 'Recording is ${recording.status}. Please try again later.',
        context: context,
      );
      return;
    }

    final isOwner = recording.streamerId == AppAuth.myId;
    final isPaid = recording.isPaid;
    if (isPaid && !isOwner) {
      // Check if already purchased / accessible
      _checkAccessAndMaybePlay(recording, index, playlist);
      return;
    }

    _navigateToPlayer(recording, index, playlist);
  }

  Future<void> _checkAccessAndMaybePlay(
    LiveStreamRecordingModel recording,
    int index,
    List<LiveStreamRecordingModel> playlist,
  ) async {
    try {
      final access = await _apiService.getRecordingAccess(recording.id);
      final canView = access['canView'] == true;
      if (canView) {
        _navigateToPlayer(recording, index, playlist);
        return;
      }
    } catch (_) {}

    // Not purchased: show payment modal
    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (_) => StreamPaymentModal(
        recording: recording,
        onPayNow: (phone) async {
          Navigator.of(context).pop();
          await _initiatePurchaseAndPoll(recording, phone);
          if (!mounted) return;
          // Re-check access
          try {
            final access = await _apiService.getRecordingAccess(recording.id);
            if (access['canView'] == true) {
              VAppAlert.showSuccessSnackBar(context: context, message: 'Payment confirmed');
              _navigateToPlayer(recording, index, playlist);
            } else {
              VAppAlert.showErrorSnackBar(context: context, message: 'Payment not confirmed yet. Please approve in M-Pesa and try again.');
            }
          } catch (e) {
            VAppAlert.showErrorSnackBar(context: context, message: e.toString());
          }
        },
      ),
    );
  }

  Future<void> _initiatePurchaseAndPoll(
    LiveStreamRecordingModel recording,
    String phone,
  ) async {
    try {
      final res = await _apiService.initiateRecordingPurchase(
        recordingId: recording.id,
        phone: phone,
      );
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: res['message'] ?? 'STK push sent. Approve the payment on your phone.',
      );

      // Light polling to update UX
      const attempts = 6; // ~60s
      for (int i = 0; i < attempts; i++) {
        await Future.delayed(const Duration(seconds: 10));
        try {
          final access = await _apiService.getRecordingAccess(recording.id);
          if (access['canView'] == true) {
            VAppAlert.showSuccessSnackBarWithoutContext(message: 'Payment confirmed');
            break;
          }
        } catch (_) {}
      }
    } catch (e) {
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  void _navigateToPlayer(
    LiveStreamRecordingModel recording,
    int index,
    List<LiveStreamRecordingModel> playlist,
  ) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => RecordingPlayerView(
          recording: recording,
          playlist: playlist,
          initialIndex: index,
        ),
      ),
    );
  }
}
