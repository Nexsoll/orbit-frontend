import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/models/memory/memory_model.dart';
import 'package:super_up/app/core/models/story/story_model.dart';
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up/app/modules/memory/controllers/memory_controller.dart';
import 'package:super_up/app/modules/story/view/story_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

class MemoryView extends StatefulWidget {
  const MemoryView({super.key});

  @override
  State<MemoryView> createState() => _MemoryViewState();
}

class _MemoryViewState extends State<MemoryView> {
  late final MemoryController controller;
  final ScrollController _scrollController = ScrollController();

  String? _resolveStoryMediaUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final v = rawUrl.toString().trim();
    if (v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    if (v.startsWith('/')) {
      return '${SConstants.baseMediaUrl}$v';
    }
    if (v.startsWith('media/')) {
      return '${SConstants.baseMediaUrl}/$v';
    }
    if (v.startsWith('v-public/')) {
      return '${SConstants.baseMediaUrl}/$v';
    }
    return '${SConstants.baseMediaUrl}/media/$v';
  }

  @override
  void initState() {
    super.initState();
    controller = GetIt.I.get<MemoryController>();
    // Always refresh memories when screen is opened
    controller.getMemories(refresh: true);
    controller.getTodayReminders();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      controller.getMemories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        middle: const Text('Memories'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back),
        ),
      ),
      child: SafeArea(
        child: ValueListenableBuilder<SLoadingState<MemoryState>>(
          valueListenable: controller,
          builder: (_, value, __) {
            if (controller.data.isLoading && controller.data.memories.isEmpty) {
              return const Center(
                child: CupertinoActivityIndicator(),
              );
            }

            if (controller.data.error != null &&
                controller.data.memories.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      size: 48,
                      color: CupertinoColors.systemRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading memories',
                      style: context.cupertinoTextTheme.textStyle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.data.error ?? 'Unknown error',
                      style: context.cupertinoTextTheme.textStyle.copyWith(
                        color: CupertinoColors.systemGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    CupertinoButton.filled(
                      onPressed: () => controller.getMemories(refresh: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (controller.data.memories.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.memories,
                      size: 64,
                      color: CupertinoColors.systemGrey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Memories Yet',
                      style: context.cupertinoTextTheme.textStyle.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save your favorite stories to memories\nto view them anytime',
                      style: context.cupertinoTextTheme.textStyle.copyWith(
                        color: CupertinoColors.systemGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await controller.getMemories(refresh: true);
                await controller.getTodayReminders();
              },
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Today's Reminders Section
                  if (controller.data.todayReminders.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'On This Day',
                              style:
                                  context.cupertinoTextTheme.textStyle.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount:
                                    controller.data.todayReminders.length,
                                itemBuilder: (context, index) {
                                  final memory =
                                      controller.data.todayReminders[index];
                                  return _buildReminderCard(memory);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Divider(height: 1),
                    ),
                  ],

                  // All Memories Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'All Memories',
                        style: context.cupertinoTextTheme.textStyle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= controller.data.memories.length) {
                          return const Center(
                            child: CupertinoActivityIndicator(),
                          );
                        }
                        final memory = controller.data.memories[index];
                        return _buildMemoryCard(memory);
                      },
                      childCount: controller.data.memories.length +
                          (controller.data.isLoading ? 1 : 0),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReminderCard(MemoryModel memory) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => _viewMemory(memory),
        child: Column(
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CupertinoColors.systemBlue,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildStoryPreview(memory),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatReminderDate(memory.savedAt),
              style: context.cupertinoTextTheme.textStyle.copyWith(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryCard(MemoryModel memory) {
    return GestureDetector(
      onTap: () => _viewMemory(memory),
      onLongPress: () => _showMemoryOptions(memory),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CupertinoColors.systemGrey4,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            children: [
              Expanded(
                child: _buildStoryPreview(memory),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatMemoryDate(memory.savedAt),
                      style: context.cupertinoTextTheme.textStyle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (memory.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        memory.tags.join(', '),
                        style: context.cupertinoTextTheme.textStyle.copyWith(
                          fontSize: 10,
                          color: CupertinoColors.systemGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryPreview(MemoryModel memory) {
    final story = memory.originalStoryData;

    if (story.storyType == StoryType.text || story.att == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: story.colorValue != null
            ? Color(story.colorValue!)
            : CupertinoColors.systemBlue,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              story.content,
              style: context.cupertinoTextTheme.textStyle.copyWith(
                color: CupertinoColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    if (story.storyType == StoryType.voice) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: CupertinoColors.systemGrey4,
        child: const Center(
          child: Icon(
            CupertinoIcons.mic_fill,
            color: CupertinoColors.white,
            size: 42,
          ),
        ),
      );
    }

    if (story.storyType == StoryType.video) {
      final thumb = story.att?['thumbUrl']?.toString();
      final resolvedThumb = _resolveStoryMediaUrl(thumb);
      if (resolvedThumb == null) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: CupertinoColors.systemGrey4,
          child: const Center(
            child: Icon(
              CupertinoIcons.play_circle_fill,
              color: CupertinoColors.white,
              size: 44,
            ),
          ),
        );
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          VPlatformCacheImageWidget(
            source: VPlatformFile.fromUrl(networkUrl: resolvedThumb),
            fit: BoxFit.cover,
          ),
          const Center(
            child: Icon(
              CupertinoIcons.play_circle_fill,
              color: CupertinoColors.white,
              size: 44,
            ),
          ),
        ],
      );
    }

    final resolved = _resolveStoryMediaUrl(story.att?['url']?.toString());
    if (resolved == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: CupertinoColors.systemGrey4,
      );
    }

    return VPlatformCacheImageWidget(
      source: VPlatformFile.fromUrl(networkUrl: resolved),
      fit: BoxFit.cover,
    );
  }

  void _viewMemory(MemoryModel memory) {
    // Create a UserStoryModel from the memory to view it
    final userStoryModel = UserStoryModel(
      userData: AppAuth.myProfile.baseUser,
      stories: [memory.originalStoryData],
    );

    context.toPage(
      StoryViewpage(
        userStoryModels: [userStoryModel],
        onComplete: (_) {},
        onDelete: null,
        onStoryViewed: null,
      ),
    );
  }

  void _showMemoryOptions(MemoryModel memory) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _deleteMemory(memory);
            },
            isDestructiveAction: true,
            child: const Text('Delete Memory'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _deleteMemory(MemoryModel memory) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Memory'),
        content: const Text(
            'Are you sure you want to delete this memory? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final success = await controller.deleteMemory(memory.id);
              if (success && mounted) {
                // Show success message
                showCupertinoDialog(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: const Text('Memory Deleted'),
                    content:
                        const Text('The memory has been deleted successfully.'),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatMemoryDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${(difference.inDays / 365).floor()} years ago';
    }
  }

  String _formatReminderDate(DateTime date) {
    final now = DateTime.now();
    final years = now.year - date.year;

    if (years == 1) {
      return '1 year ago';
    } else {
      return '$years years ago';
    }
  }
}
