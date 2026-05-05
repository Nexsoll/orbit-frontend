import 'dart:io';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_media_editor/v_chat_media_editor.dart';
import 'package:v_platform/v_platform.dart';
import 'package:video_player/video_player.dart';

import '../../../core/api_service/story/story_api_service.dart';
import '../../../core/models/story/create_story_dto.dart';
import '../../../core/utils/enums.dart';
import '../../../core/services/story_status_service.dart';
import '../story_privacy/story_privacy_selection_screen.dart';
import '../../social/controllers/social_story_tab_controller.dart';

class CreateMediaStory extends StatefulWidget {
  final VBaseMediaRes media;
  final String storySource;

  const CreateMediaStory(
      {super.key, required this.media, this.storySource = 'main'});

  @override
  State<CreateMediaStory> createState() => _CreateMediaStoryState();
}

class _CreateMediaStoryState extends State<CreateMediaStory> {
  final _txtController = TextEditingController();
  final _api = GetIt.I.get<StoryApiService>();
  final _storyStatusService = GetIt.I.get<StoryStatusService>();
  VideoPlayerController? _videoController;
  bool _isVideo = false;

  StoryPrivacy _storyPrivacy = StoryPrivacy.public;
  List<String>? _selectedUserIds;
  List<String>? _excludedUserIds;

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _initializeMedia() {
    final file = widget.media.getVPlatformFile();
    final fileName = file.name.toLowerCase();

    // Check if the file is a video based on extension
    _isVideo = fileName.endsWith('.mp4') ||
        fileName.endsWith('.mov') ||
        fileName.endsWith('.avi') ||
        fileName.endsWith('.mkv') ||
        widget.media is VMediaVideoRes;

    if (_isVideo) {
      // Handle both local and network videos
      if (VPlatforms.isWeb) {
        // On web, video preview is not supported for local files
        // We'll show a placeholder instead
        return;
      } else if (file.fileLocalPath != null && file.fileLocalPath!.isNotEmpty) {
        // Local file (only for non-web platforms)
        _videoController = VideoPlayerController.file(
          File(file.fileLocalPath!),
        )..initialize().then((_) {
            setState(() {});
            _videoController!.play();
            _videoController!.setLooping(true);
          });
      } else if (file.fullNetworkUrl != null) {
        // Network video
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(file.fullNetworkUrl!),
        )..initialize().then((_) {
            setState(() {});
            _videoController!.play();
            _videoController!.setLooping(true);
          });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        backgroundColor: Colors.black,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            context.pop();
          },
          child: const Icon(
            CupertinoIcons.clear,
            color: Colors.white,
          ),
        ),
        middle: S.of(context).createStory.text.color(Colors.white),
      ),
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(),
                _buildMediaWidget(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          placeholder: S.of(context).writeACaption,
                          controller: _txtController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          placeholderStyle: const TextStyle(
                            color: Colors.white,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.all(
                              Radius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Privacy Button
                      GestureDetector(
                        onTap: _showPrivacySelection,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.blue.withOpacity(0.7),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _storyPrivacy == StoryPrivacy.public
                                    ? Icons.public
                                    : _storyPrivacy == StoryPrivacy.somePeople
                                        ? Icons.people
                                        : Icons.people_alt_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _storyPrivacy == StoryPrivacy.public
                                    ? 'Everyone'
                                    : _storyPrivacy == StoryPrivacy.somePeople
                                        ? 'Selected'
                                        : 'Except',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Done Button
                      GestureDetector(
                        onTap: uploadMediaStory,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                          child: const Icon(
                            Icons.done,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaWidget() {
    if (_isVideo) {
      if (VPlatforms.isWeb) {
        // Show placeholder for video on web
        return Container(
          width: 500,
          height: 500,
          color: Colors.grey[800],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam,
                  size: 64,
                  color: Colors.white70,
                ),
                SizedBox(height: 16),
                Text(
                  'Video Preview',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Video will be uploaded as story',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (_videoController != null &&
          _videoController!.value.isInitialized) {
        return SizedBox(
          width: 500,
          height: 500,
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        );
      } else {
        return Container(
          width: 500,
          height: 500,
          color: Colors.grey[800],
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        );
      }
    } else {
      return VPlatformCacheImageWidget(
        source: widget.media.getVPlatformFile(),
        size: const Size(500, 500),
      );
    }
  }

  void _showPrivacySelection() async {
    print('Media story privacy button tapped!'); // Debug print
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => StoryPrivacySelectionScreen(
          onPrivacySelected: (privacy, selectedUserIds, excludedUserIds) {
            print(
                'Media story privacy selected: $privacy, selected: $selectedUserIds, excluded: $excludedUserIds'); // Debug print
            setState(() {
              _storyPrivacy = privacy;
              _selectedUserIds = selectedUserIds;
              _excludedUserIds = excludedUserIds;
            });
          },
        ),
      ),
    );
  }

  void uploadMediaStory() async {
    // Debug: Print the story data being sent
    print('Creating media story with privacy: $_storyPrivacy');
    print('Selected users: $_selectedUserIds');

    await vSafeApiCall(
      onLoading: () {
        VAppAlert.showLoading(
          context: context,
          message: _isVideo
              ? 'Uploading video story...\nLarge videos may take up to 10 minutes'
              : 'Uploading image story...',
        );
      },
      request: () async {
        final storyType = _isVideo ? StoryType.video : StoryType.image;

        Map<String, dynamic>? attachment;
        if (_isVideo) {
          final videoRes = widget.media as VMediaVideoRes;
          var durationMs = videoRes.data.duration;
          if ((durationMs == null || durationMs <= 0) && !VPlatforms.isWeb) {
            durationMs = await VMediaFileUtils.getVideoDurationMill(
              videoRes.data.fileSource,
            );
          }
          if ((durationMs == null || durationMs <= 0) && !VPlatforms.isWeb) {
            durationMs = await VMediaFileUtils.getVideoDurationMill(
              widget.media.getVPlatformFile(),
            );
          }
          if (durationMs != null && durationMs > 0) {
            videoRes.data.duration = durationMs;
          }
          attachment = videoRes.data.toMap();
        } else {
          attachment = (widget.media as VMediaImageRes).data.toMap();
        }

        final dto = CreateStoryDto(
          storyType: storyType,
          content: storyType.name,
          caption: _txtController.text,
          image: widget.media.getVPlatformFile(),
          secondImage: _isVideo
              ? (widget.media as VMediaVideoRes).data.thumbImage?.fileSource
              : null,
          attachment: attachment,
          storyPrivacy: _storyPrivacy,
          somePeople: _selectedUserIds,
          exceptPeople: _excludedUserIds,
          storySource: widget.storySource,
        );

        // Debug: Print the DTO data
        print(
            'CreateStoryDto: storyPrivacy=${dto.storyPrivacy}, somePeople=${dto.somePeople}');

        return _api.createStory(dto);
      },
      onSuccess: (response) async {
        if (widget.storySource == 'social') {
          if (GetIt.I.isRegistered<SocialStoryTabController>()) {
            await GetIt.I.get<SocialStoryTabController>().getMyStoryFromApi();
          }
        } else {
          await _storyStatusService.refreshMyStories();
          unawaited(_storyStatusService.forceRefreshStoryStatus());
        }

        context.pop();
        context.pop();

        VAppAlert.showSuccessSnackBar(
          context: context,
          message: S.of(context).storyCreatedSuccessfully,
        );
      },
      onError: (exception, trace) {
        context.pop();
        VAppAlert.showErrorSnackBar(
          context: context,
          message: exception.toString(),
        );
      },
    );
  }
}
