import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:just_audio/just_audio.dart';
import 'package:get_it/get_it.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:story_view/controller/story_controller.dart';
import 'package:story_view/widgets/story_view.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/api_service/story/story_api_service.dart';
import 'package:super_up/app/core/models/story/story_model.dart';
import 'package:super_up/app/core/models/story/story_reaction_model.dart';
import 'package:super_up/app/core/models/story/story_reply_model.dart';
import 'package:super_up/app/core/models/story/story_view_count_model.dart';
import 'package:super_up/app/core/services/story_media_cache_service.dart';
import 'package:flutter_parsed_text/flutter_parsed_text.dart';
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up/app/modules/post/post_feed_widget.dart';
import 'package:super_up/app/modules/tickets/views/ticket_detail_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:share_plus/share_plus.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:v_chat_voice_player/v_chat_voice_player.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/services/screenshot_protection_service.dart';
import '../../../core/utils/enums.dart';
import 'story_viewers_screen.dart';
import 'widgets/emoji_reaction_picker.dart';

class StoryViewpage extends StatefulWidget {
  final List<UserStoryModel> userStoryModels;
  final int initialUserIndex;
  final Function(UserStoryModel current)? onComplete;
  final Function()? onDelete;
  final Function(String storyId)? onStoryViewed;

  const StoryViewpage({
    super.key,
    required this.userStoryModels,
    this.initialUserIndex = 0,
    this.onComplete,
    this.onDelete,
    this.onStoryViewed,
  });

  @override
  State<StoryViewpage> createState() => _StoryViewpageState();
}

class _StoryViewpageState extends State<StoryViewpage> {
  final controller = StoryController();
  static const double _swipeVelocityThreshold = 350;

  late int _currentUserIndex;
  late UserStoryModel _currentStoryModel;
  late StoryModel current;
  bool _isPreparingStories = true;
  List<StoryItem> stories = [];
  final _api = GetIt.I.get<StoryApiService>();
  final _replyController = TextEditingController();
  final _replyFocusNode = FocusNode();
  VVoiceMessageController? _voiceController; // for voice stories
  // State for reactions and replies
  String? _selectedEmoji; // Store the selected emoji reaction
  bool _isReacting = false;
  bool _isReplying = false;
  bool _isTypingReply = false; // Track if user is typing a reply
  bool _isMuted = false; // Track mute state for video stories
  bool _isCurrentVideoReady = false; // Hold story progress until video is ready
  double? _originalVolume; // Store original volume to restore later
  Timer? _videoHoldPauseTicker;
  
  AudioPlayer? _bgMusicPlayer;
  StreamSubscription? _bgMusicPositionSubscription;

  // Pinch-to-zoom state
  final _zoomController = TransformationController();
  double _currentZoom = 1.0;

  // Map to store emoji reactions for each story
  static final Map<String, String> _storyReactions = {};

  // State for view count
  int? _viewsCount;
  bool _isLoadingViewCount = false;
  final Map<String, String> _postCaptionCache = <String, String>{};
  final Set<String> _loadingPostCaptionIds = <String>{};

  Future<void> _shareCurrentStoryLink() async {
    try {
      final id = current.id;
      if (id.isEmpty) return;

      final uploaderName = _currentStoryModel.userData.fullName;
      final title = (current.caption ?? 'Shared story').toString();
      final link = 'https://api.orbit.ke/api/v1/public/stories/share/$id';

      await Share.share(
        uploaderName.isEmpty
            ? '$title\n$link'
            : '$title\nby $uploaderName\n$link',
        subject: title,
      );
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future<void> _shareStoryToChat() async {
    try {
      final roomsIds =
          await VChatController.I.vNavigator.roomNavigator.toForwardPage(
        context,
        null,
      );

      if (roomsIds == null || roomsIds.isEmpty) return;

      final id = current.id;
      if (id.isEmpty) return;

      final uploaderName = _currentStoryModel.userData.fullName;
      final uploaderImage = _currentStoryModel.userData.userImage;
      final uploaderId = _currentStoryModel.userData.id;
      final title = (current.caption ?? 'Shared story').toString();
      final link = 'https://api.orbit.ke/api/v1/public/stories/share/$id';

      // Get media info from current story's att map
      final att = current.att ?? {};
      final mediaUrl = att['url']?.toString() ?? '';
      final thumbnailUrl = att['thumbUrl']?.toString() ?? '';
      final mediaType = current.storyType.name;

      final payload = <String, dynamic>{
        'type': 'story_share',
        'storyId': id,
        'title': title,
        'link': link,
        'mediaUrl': mediaUrl,
        'thumbnailUrl': thumbnailUrl,
        'mediaType': mediaType,
        'uploaderName': uploaderName,
        'uploaderImage': uploaderImage,
        'uploaderId': uploaderId,
      };

      final previewText = 'Shared story: $title';

      VAppAlert.showLoading(context: context);
      try {
        for (final roomId in roomsIds) {
          final message = VCustomMessage.buildMessage(
            roomId: roomId,
            content: previewText,
            data: VCustomMsgData(data: payload),
          );
          await VChatController.I.nativeApi.local.message
              .insertMessage(message);
          try {
            VMessageUploaderQueue.instance.addToQueue(
              await MessageFactory.createUploadMessage(message),
            );
          } catch (_) {
            // message remains local only
          }
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Shared to chat',
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialUserIndex;
    _currentStoryModel = widget.userStoryModels[_currentUserIndex];
    current = _currentStoryModel.stories.first;

    unawaited(_parseStories());
    _initializeAudioSession();

    // Enable wakelock to keep screen awake during story playback
    unawaited(WakelockPlus.enable());
    // Robustness: re-enable after a short delay to ensure transitioning from a previous
    // StoryViewpage doesn't accidentally disable it in its dispose() call.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) WakelockPlus.enable();
    });

    unawaited(_syncScreenshotProtectionForCurrentUser());

    // Add listener to reply focus node to pause/resume story when clicking input field
    _replyFocusNode.addListener(_onReplyFocusChanged);

    // Mark the first story as viewed after the build is complete
    // First-story seen handling is triggered after story items are prepared.
  }

  int _durationMsFromAtt(dynamic d) {
    if (d is int) return d;
    if (d is double) return d.toInt();
    if (d is String) {
      final parsed = int.tryParse(d);
      if (parsed != null) return parsed;
      final parsedDouble = double.tryParse(d);
      if (parsedDouble != null) return parsedDouble.toInt();
    }
    return -1;
  }

  String _storyPostId(StoryModel story) {
    final att = story.att;
    if (att == null) return '';
    return (att['postId'] ?? att['post_id'] ?? att['postID'] ?? '').toString();
  }

  bool _isSharedPostStory(StoryModel story) {
    return _storyPostId(story).isNotEmpty;
  }

  String _storyTicketId(StoryModel story) {
    final att = story.att;
    if (att == null) return '';
    return (att['ticketId'] ?? att['ticket_id'] ?? att['ticketID'] ?? '').toString();
  }

  bool _isSharedTicketStory(StoryModel story) {
    return _storyTicketId(story).isNotEmpty;
  }

  String _postShareCaption(StoryModel story) {
    final att = story.att ?? const <String, dynamic>{};
    final candidates = <String>[
      (att['caption'] ?? '').toString(),
      (att['postCaption'] ?? '').toString(),
      (att['description'] ?? '').toString(),
      (att['text'] ?? '').toString(),
      (att['content'] ?? '').toString(),
      (story.caption ?? '').toString(),
      story.content.toString(),
    ];

    for (final raw in candidates) {
      final value = raw.trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _resolvedPostShareCaption(StoryModel story) {
    final localCaption = _postShareCaption(story);
    if (localCaption.isNotEmpty) return localCaption;

    final postId = _storyPostId(story);
    if (postId.isEmpty) return '';
    return (_postCaptionCache[postId] ?? '').trim();
  }

  Future<void> _ensurePostCaptionLoaded(StoryModel story) async {
    if (!_isSharedPostStory(story)) return;
    if (_postShareCaption(story).isNotEmpty) return;

    final postId = _storyPostId(story);
    if (postId.isEmpty) return;
    if (_postCaptionCache.containsKey(postId)) return;
    if (_loadingPostCaptionIds.contains(postId)) return;

    _loadingPostCaptionIds.add(postId);
    try {
      final api = GetIt.I.get<PostApiService>();
      final post = await api.getPostById(postId);
      final caption = post.caption.trim();
      if (caption.isEmpty || !mounted) return;
      setState(() {
        _postCaptionCache[postId] = caption;
      });
    } catch (_) {
      // Ignore caption fetch failures and keep card usable.
    } finally {
      _loadingPostCaptionIds.remove(postId);
    }
  }

  Future<int?> _probeNetworkVideoDurationMs(String url) async {
    VideoPlayerController? c;
    try {
      c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize().timeout(const Duration(seconds: 5));
      final ms = c.value.duration.inMilliseconds;
      if (ms <= 0) return null;
      return ms;
    } catch (_) {
      return null;
    } finally {
      try {
        await c?.dispose();
      } catch (_) {}
    }
  }

  void _setupVoiceForCurrent() {
    try {
      _voiceController?.dispose();
      _voiceController = null;
      if (current.storyType != StoryType.voice) return;

      final url = current.att?['url'];
      if (url == null) return;
      final raw = url.toString();
      final fullUrl =
          raw.startsWith('http') ? raw : '${SConstants.baseMediaUrl}$raw';
      _voiceController = VVoiceMessageController(
        id: current.id,
        audioSrc: VPlatformFile.fromUrl(networkUrl: fullUrl),
        maxDuration: const Duration(minutes: 25),
        onComplete: (_) {
          if (!mounted) return;
          if (_replyFocusNode.hasFocus) return;
          controller.next();
        },
        onPlaying: (_) {
          if (!mounted) return;
          if (current.storyType != StoryType.voice) return;
          if (_replyFocusNode.hasFocus) return;
          controller.pause();
        },
      );
      // Auto play
      _voiceController!.initAndPlay();

      Future.delayed(const Duration(milliseconds: 30), () {
        if (!mounted) return;
        if (current.storyType != StoryType.voice) return;
        if (_replyFocusNode.hasFocus) return;
        final isPlaying = _voiceController?.value.isPlaying == true;
        if (isPlaying) {
          controller.pause();
        }
      });
    } catch (_) {
      _playStoriesIfAllowed();
    }
  }

  void _startVideoHold() {
    _videoHoldPauseTicker?.cancel();
    _videoHoldPauseTicker =
        Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      if (current.storyType != StoryType.video || _isCurrentVideoReady) {
        _stopVideoHold();
        return;
      }
      controller.pause();
    });
  }

  void _stopVideoHold() {
    _videoHoldPauseTicker?.cancel();
    _videoHoldPauseTicker = null;
  }

  void _playStoriesIfAllowed() {
    if (current.storyType == StoryType.video && !_isCurrentVideoReady) return;
    controller.play();
  }

  Future<void> _syncScreenshotProtectionForCurrentUser() async {
    final shouldProtect = !_currentStoryModel.userData.isMe &&
        !_currentStoryModel.allowStoryScreenshot;

    if (shouldProtect) {
      await ScreenshotProtectionService.enableProtection();
    } else {
      await ScreenshotProtectionService.disableProtection();
    }
  }

  void _switchToUserAt(int userIndex) {
    if (_isPreparingStories) return;
    if (userIndex < 0 || userIndex >= widget.userStoryModels.length) return;
    if (userIndex == _currentUserIndex) return;

    setState(() {
      _currentUserIndex = userIndex;
      _currentStoryModel = widget.userStoryModels[_currentUserIndex];
      _isPreparingStories = true;
    });
    unawaited(_syncScreenshotProtectionForCurrentUser());
    unawaited(_parseStories());
  }

  void _goToNextUserStory() {
    _switchToUserAt(_currentUserIndex + 1);
  }

  void _goToPreviousUserStory() {
    _switchToUserAt(_currentUserIndex - 1);
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    if (_isPreparingStories) return;
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (velocity <= -_swipeVelocityThreshold) {
      _goToNextUserStory();
      return;
    }
    if (velocity >= _swipeVelocityThreshold) {
      _goToPreviousUserStory();
    }
  }

  void _handleCurrentStoryChanged() {
    if (current.storyType == StoryType.video) {
      _isCurrentVideoReady = false;
      controller.pause();
      _startVideoHold();
      return;
    }
    _stopVideoHold();
    _isCurrentVideoReady = true;
  }

  String? _getCurrentVideoUrl() {
    try {
      final url = current.att?['url'];
      if (url == null) return null;
      final full = StoryMediaCacheService.I.resolveStoryUrl(url.toString());
      return full.isEmpty ? null : full;
    } catch (_) {
      return null;
    }
  }

  void _stopBgMusic() {
    _bgMusicPositionSubscription?.cancel();
    _bgMusicPositionSubscription = null;
    _bgMusicPlayer?.stop();
    _bgMusicPlayer?.dispose();
    _bgMusicPlayer = null;
  }

  void _pauseBgMusic() {
    _bgMusicPlayer?.pause();
  }

  void _resumeBgMusic() {
    if (current.att?['backgroundMusic'] != null && 
        !_replyFocusNode.hasFocus && 
        !_isTypingReply && 
        _currentZoom <= 1.0) {
      _bgMusicPlayer?.play();
    }
  }

  void _startBgMusicForCurrent() async {
    _stopBgMusic();

    final bgMusic = current.att?['backgroundMusic'];
    if (bgMusic == null) return;

    final rawUrl = bgMusic['musicUrl']?.toString() ?? '';
    if (rawUrl.isEmpty) return;

    final fullUrl = rawUrl.startsWith('http') ? rawUrl : SConstants.baseMediaUrl + rawUrl;
    final startMs = bgMusic['startMs'] as int? ?? 0;
    final endMs = bgMusic['endMs'] as int? ?? (startMs + 15000);

    try {
      _bgMusicPlayer = AudioPlayer();
      if (_isMuted) {
        await _bgMusicPlayer!.setVolume(0.0);
      } else {
        await _bgMusicPlayer!.setVolume(1.0);
      }
      await _bgMusicPlayer!.setUrl(fullUrl);
      await _bgMusicPlayer!.seek(Duration(milliseconds: startMs));
      
      if (!_replyFocusNode.hasFocus && !_isTypingReply && _currentZoom <= 1.0) {
        await _bgMusicPlayer!.play();
      }

      _bgMusicPositionSubscription = _bgMusicPlayer!.positionStream.listen((pos) {
        if (!mounted || _bgMusicPlayer == null) return;
        if (pos.inMilliseconds >= endMs) {
          _bgMusicPlayer!.seek(Duration(milliseconds: startMs));
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    // Disable wakelock when leaving story viewer
    WakelockPlus.disable();

    _stopBgMusic();

    // Restore audio session if it was muted when leaving the story
    if (_isMuted) {
      _restoreAudio();
    }
    _voiceController?.dispose();
    _stopVideoHold();
    // Pause the story controller to stop any playing video/audio before disposing
    controller.pause();
    controller.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    _zoomController.dispose();
    // Restore screenshot/screen recording behavior when leaving story viewer.
    ScreenshotProtectionService.disableProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreparingStories) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator.adaptive(),
          ),
        ),
      );
    }
    final protocolIdentifierRegex = RegExp(
      r'^((http|ftp|https):\/\/)',
      caseSensitive: false,
    );
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: _handleHorizontalSwipe,
          child: Stack(
            children: [
              // Pinch-to-zoom wrapper for media stories
              InteractiveViewer(
                transformationController: _zoomController,
                minScale: 1.0,
                maxScale: 4.0,
                onInteractionUpdate: (details) {
                  final newZoom = _zoomController.value.getMaxScaleOnAxis();
                  if (newZoom != _currentZoom) {
                    setState(() {
                      _currentZoom = newZoom;
                    });
                    // Pause story when zoomed in
                    if (newZoom > 1.0) {
                      controller.pause();
                      _pauseBgMusic();
                      if (current.storyType == StoryType.voice) {
                        _voiceController?.pausePlaying();
                      }
                    } else {
                      // Resume when zoom reset
                      if (!_replyFocusNode.hasFocus) {
                        _resumeBgMusic();
                        _playStoriesIfAllowed();
                      }
                    }
                  }
                },
                child: KeyedSubtree(
                  key: ValueKey(_currentUserIndex),
                  child: StoryView(
                    onComplete: () {
                      if (_currentUserIndex <
                          widget.userStoryModels.length - 1) {
                        _goToNextUserStory();
                      } else {
                        context.pop();
                        widget.onComplete?.call(_currentStoryModel);
                      }
                    },
                    onStoryShow: (storyItem, index) {
                      // Ensure wakelock is enabled for every story shown
                      WakelockPlus.enable();

                      // Reset zoom when story changes
                      if (_currentZoom > 1.0) {
                        _zoomController.value = Matrix4.identity();
                        _currentZoom = 1.0;
                      }

                      int pos = stories.indexOf(storyItem);
                      current = _currentStoryModel.stories[pos];
                      _handleCurrentStoryChanged();
                      unawaited(_ensurePostCaptionLoaded(current));
                      unawaited(_setSeen(current.id));
                      // Reset mute state when story changes
                      if (_isMuted) {
                        _restoreAudio();
                        _isMuted = false;
                      }
                      // Prepare voice playback when current is voice
                      _setupVoiceForCurrent();
                      // Notify the controller that this story was viewed using delayed call
                      Future.delayed(Duration.zero, () {
                        if (mounted) {
                          // Load saved emoji reaction for this story
                          setState(() {
                            _selectedEmoji = _storyReactions[current.id];
                          });
                          widget.onStoryViewed?.call(current.id);
                          // Load view count for own stories when story changes
                          if (_currentStoryModel.userData.isMe) {
                            _loadViewCount();
                          }
                          // Check for existing reaction
                          _checkExistingReaction();

                          _startBgMusicForCurrent();
                        }
                      });
                    },
                    storyItems: stories,
                    controller: controller,
                  ),
                ),
              ),
              // Clickable text story overlay: hide for shared-post and shared-ticket stories
              if (current.storyType == StoryType.text &&
                  !_isSharedPostStory(current) &&
                  !_isSharedTicketStory(current))
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: AutoDirection(
                        text: current.content,
                        child: ParsedText(
                          text: current.content,
                          alignment: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 35,
                            fontStyle: current.fontType == StoryFontType.italic
                                ? FontStyle.italic
                                : null,
                            textBaseline: TextBaseline.alphabetic,
                            fontWeight: current.fontType == StoryFontType.bold
                                ? FontWeight.bold
                                : null,
                            shadows: const [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          regexOptions:
                              const RegexOptions(multiLine: true, dotAll: true),
                          parse: [
                            MatchText(
                              pattern: r'((http|https):\/\/[^\s]+|www\.[^\s]+)',
                              style: TextStyle(
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                                fontSize: 35,
                                fontStyle:
                                    current.fontType == StoryFontType.italic
                                        ? FontStyle.italic
                                        : null,
                                fontWeight:
                                    current.fontType == StoryFontType.bold
                                        ? FontWeight.bold
                                        : null,
                                shadows: const [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                              onTap: (url) async {
                                if (!url.startsWith(protocolIdentifierRegex)) {
                                  url = 'https://$url';
                                }
                                await VStringUtils.lunchLink(url);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Custom caption overlay (hide it for shared-post/ticket stories to avoid duplicate text)
              if (current.caption != null &&
                  current.caption!.isNotEmpty &&
                  !_isSharedPostStory(current) &&
                  !_isSharedTicketStory(current))
                Positioned(
                  bottom: _currentStoryModel.userData.isMe
                      ? 20 // Story owner: position at bottom of screen for better visibility
                      : 80, // Story viewer: position above reply section (60px reply height + 20px gap)
                  left: 20,
                  right: 20,
                  child: ParsedText(
                    text: current.caption!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    alignment: TextAlign.center,
                    parse: [
                      MatchText(
                        pattern: r'((http|https):\/\/[^\s]+|www\.[^\s]+)',
                        style: const TextStyle(
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        onTap: (url) async {
                          final protocolIdentifierRegex = RegExp(
                            r'^((http|ftp|https):\/\/)',
                            caseSensitive: false,
                          );
                          if (!url.startsWith(protocolIdentifierRegex)) {
                            url = 'https://$url';
                          }
                          await VStringUtils.lunchLink(url);
                        },
                      ),
                    ],
                  ),
                ),
              // Post card overlay for stories shared from a post
              if (_isSharedPostStory(current))
                Positioned(
                  bottom: _currentStoryModel.userData.isMe ? 170 : 240,
                  left: 16,
                  right: 16,
                  child: _StoryPostCard(
                    att: current.att!,
                    caption: _resolvedPostShareCaption(current),
                    onTap: () async {
                      final postId = _storyPostId(current);
                      if (postId.isEmpty) return;
                      controller.pause();
                      _pauseBgMusic();
                      VAppAlert.showLoading(context: context);
                      try {
                        final api = GetIt.I.get<PostApiService>();
                        final post = await api.getPostById(postId);
                        if (!mounted) return;
                        Navigator.of(context).pop(); // dismiss loading
                        await Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => CupertinoPageScaffold(
                              navigationBar: const CupertinoNavigationBar(
                                middle: Text('Post'),
                              ),
                              child: SafeArea(
                                child: SingleChildScrollView(
                                  child: PostFeedWidget(post: post),
                                ),
                              ),
                            ),
                          ),
                        );
                      } catch (_) {
                        if (mounted) {
                          Navigator.of(context).pop();
                          VAppAlert.showErrorSnackBar(
                              context: context, message: 'Could not load post');
                        }
                      }
                      if (mounted) {
                        _resumeBgMusic();
                        _playStoriesIfAllowed();
                      }
                    },
                  ),
                ),
              // Ticket card overlay for stories shared from a ticket
              if (_isSharedTicketStory(current))
                Positioned(
                  bottom: _currentStoryModel.userData.isMe ? 220 : 290,
                  left: 16,
                  right: 16,
                  child: _StoryTicketCard(
                    att: current.att!,
                    onTap: () async {
                      final ticketId = _storyTicketId(current);
                      if (ticketId.isEmpty) return;
                      controller.pause();
                      _pauseBgMusic();
                      if (current.storyType == StoryType.voice) {
                        _voiceController?.pausePlaying();
                      }
                      await Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => TicketDetailView(
                            ticketId: ticketId,
                            initialTicket: current.att!,
                          ),
                        ),
                      );
                      if (mounted) {
                        _resumeBgMusic();
                        _playStoriesIfAllowed();
                      }
                    },
                  ),
                ),
              // Voice story player overlay (centered)
              if (current.storyType == StoryType.voice &&
                  _voiceController != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: VVoiceMessageView(
                      controller: _voiceController!,
                    ),
                  ),
                ),
              // Inline video player overlay (all platforms)
              // Wrapped in IgnorePointer to allow tap-to-skip gestures to pass through to StoryView
              if (current.storyType == StoryType.video &&
                  _getCurrentVideoUrl() != null)
                IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: _InlineStoryVideoPlayer(
                        key: ValueKey(current.id),
                        url: _getCurrentVideoUrl()!,
                        muted: _isMuted,
                        onReady: () {
                          if (!mounted) return;
                          if (current.storyType != StoryType.video) return;
                          if (_isCurrentVideoReady) return;
                          setState(() {
                            _isCurrentVideoReady = true;
                          });
                          _stopVideoHold();
                          if (!_replyFocusNode.hasFocus &&
                              _currentZoom <= 1.0) {
                            _playStoriesIfAllowed();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 25,
                left: 10,
                right: 50,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        context.pop();
                      },
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (_currentStoryModel.userData.isMe) return;
                          context.toPage(
                            PeerProfileView(
                                peerId: _currentStoryModel.userData.id),
                          );
                        },
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 10,
                            ),
                            VCircleAvatar(
                              vFileSource: VPlatformFile.fromUrl(
                                networkUrl: _currentStoryModel.userData.userImage,
                              ),
                              radius: 20,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentStoryModel.userData.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 3,
                                  ),
                                  format(
                                    DateTime.parse(current.createdAt),
                                    locale: Localizations.localeOf(context)
                                        .languageCode,
                                  ).cap.color(Colors.white),
                                  if (current.att?['backgroundMusic'] != null) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.music_note,
                                          color: Color(0xFFB48648),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Builder(
                                            builder: (context) {
                                              final bgm = current.att!['backgroundMusic'];
                                              final title = bgm['title'] ?? 'Untitled';
                                              final artist = bgm['artist'];
                                              final text = (artist == null || artist == 'Unknown' || artist.toString().trim().isEmpty)
                                                  ? '$title'
                                                  : '$title - $artist';
                                              return Text(
                                                text,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              );
                                            }
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Show view count for own stories - positioned on left side
              if (_currentStoryModel.userData.isMe)
                Positioned(
                  left: 20,
                  top: 100,
                  child: GestureDetector(
                    onTap: () {
                      if (!_isLoadingViewCount && (_viewsCount ?? 0) > 0) {
                        context.toPage(
                          StoryViewersScreen(
                            storyId: current.id,
                            storyTitle: S.of(context).storyViewsTitle,
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isLoadingViewCount
                                ? "..."
                                : S.of(context).viewsCount(_viewsCount ?? 0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Mute button for video stories - positioned on right side (not shown on web)
              if (current.storyType == StoryType.video && !VPlatforms.isWeb)
                Positioned(
                  right: 20,
                  top: 100,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 3,
                top: 20,
                child: InkWell(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: PopupMenuButton<int>(
                      icon: Icon(
                        Icons.more_vert_sharp,
                        size: 30,
                        color: Colors.white,
                      ),
                      onSelected: (int result) async {
                        if (result == 0) {
                          await _shareCurrentStoryLink();
                        }
                        if (result == 1) {
                          // Share to chat for other users' stories
                          await _shareStoryToChat();
                        }
                        if (result == 2) {
                          // Share to chat for own stories
                          await _shareStoryToChat();
                        }
                        if (result == 3) {
                          final x = await VAppAlert.showAskYesNoDialog(
                            context: context,
                            title: S.of(context).delete,
                            content: S.of(context).areYouSure,
                          );
                          if (x == 1) {
                            await GetIt.I
                                .get<StoryApiService>()
                                .deleteStory(current.id);
                            VAppAlert.showSuccessSnackBar(
                                message: S.of(context).deleted,
                                context: context);
                            if (widget.onDelete != null) {
                              widget.onDelete!();
                            }

                            context.pop();
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        List<PopupMenuEntry<int>> items = [];

                        // Share link option (for everyone)
                        items.add(
                          PopupMenuItem<int>(
                            value: 0,
                            child: Row(
                              children: [
                                const Icon(Icons.link,
                                    size: 20, color: Colors.black),
                                const SizedBox(width: 8),
                                Text('Share Link',
                                    style:
                                        const TextStyle(color: Colors.black)),
                              ],
                            ),
                          ),
                        );
                        // Share to chat option (for everyone)
                        items.add(
                          PopupMenuItem<int>(
                            value: 1,
                            child: Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline,
                                    size: 20, color: Colors.black),
                                const SizedBox(width: 8),
                                Text('Share to Chat',
                                    style:
                                        const TextStyle(color: Colors.black)),
                              ],
                            ),
                          ),
                        );
                        // Delete option (only for own stories)
                        if (_currentStoryModel.userData.isMe) {
                          items.add(
                            PopupMenuItem<int>(
                              value: 3,
                              child: Row(
                                children: [
                                  const Icon(Icons.delete,
                                      size: 20, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(S.of(context).delete,
                                      style:
                                          const TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          );
                        }

                        return items;
                      },
                    ),
                  ),
                ),
              ),
              // Reaction and Reply UI (only for other people's stories)
              if (!_currentStoryModel.userData.isMe)
                Positioned(
                  bottom: 10, // Keep it at bottom with small margin
                  left: 10,
                  right: 10,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        // Emoji reaction button
                        GestureDetector(
                          onTap: _showEmojiReactionPicker,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _selectedEmoji != null
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: _isReacting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : _selectedEmoji != null
                                    ? Text(
                                        _selectedEmoji!,
                                        style: const TextStyle(fontSize: 24),
                                      )
                                    : const Icon(
                                        Icons.emoji_emotions_outlined,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Reply input field
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            focusNode: _replyFocusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: S.of(context).replyToName(
                                  _currentStoryModel.userData.fullName),
                              hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onChanged: (_) {
                              // Pause story immediately when user starts typing
                              if (!_isTypingReply) {
                                setState(() {
                                  _isTypingReply = true;
                                });
                                controller.pause();
                                _pauseBgMusic();
                                if (current.storyType == StoryType.voice) {
                                  _voiceController?.pausePlaying();
                                }
                              }
                            },
                            onSubmitted: (_) => _replyToStory(),
                          ),
                        ),
                        // Send reply button
                        GestureDetector(
                          onTap: _replyToStory,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: _isReplying
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future _setSeen(String id) async {
    vSafeApiCall(
      request: () async {
        await _api.setSeen(current.id);
      },
      onSuccess: (response) {},
    );
  }

  Future<void> _loadViewCount() async {
    if (!_currentStoryModel.userData.isMe || _isLoadingViewCount) return;

    setState(() {
      _isLoadingViewCount = true;
    });

    await vSafeApiCall<StoryViewCountModel>(
      request: () async {
        return await _api.getStoryViewsCount(current.id);
      },
      onSuccess: (response) {
        setState(() {
          _viewsCount = response.viewsCount;
        });
      },
      onError: (exception, trace) {
        // Silently handle error - view count is not critical
      },
    );

    setState(() {
      _isLoadingViewCount = false;
    });
  }

  void _showEmojiReactionPicker() {
    if (_isReacting || _currentStoryModel.userData.isMe) return;

    // Pause the story when reaction picker is shown
    controller.pause();
    _pauseBgMusic();

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return EmojiReactionOverlay(
          onEmojiSelected: (emoji) {
            Navigator.of(context).pop();
            // Resume story after selecting emoji
            _resumeBgMusic();
            _playStoriesIfAllowed();
            _reactToStoryWithEmoji(emoji);
          },
          onCancel: () {
            Navigator.of(context).pop();
            // Resume story when canceling
            _resumeBgMusic();
            _playStoriesIfAllowed();
          },
        );
      },
    );
  }

  /// Check if user has an existing reaction for the current story
  /// This is a fallback for cases where local storage might be empty
  void _checkExistingReaction() {
    if (_selectedEmoji != null) return;
    // For now, we'll rely on the local storage approach
  }

  Future<void> _reactToStoryWithEmoji(String emoji) async {
    if (_isReacting || _currentStoryModel.userData.isMe) return;

    setState(() {
      _isReacting = true;
    });

    await vSafeApiCall<StoryReactionModel>(
      request: () async {
        return await _api.reactToStory(current.id, emoji: emoji);
      },
      onSuccess: (response) {
        setState(() {
          // Store the selected emoji if liked, clear if unliked
          _selectedEmoji = response.liked ? emoji : null;
          // Save to local storage
          if (response.liked) {
            _storyReactions[current.id] = emoji;
          } else {
            _storyReactions.remove(current.id);
          }
        });

        // Show feedback to user with the selected emoji
        VAppAlert.showSuccessSnackBar(
          message: response.liked
              ? S.of(context).reactedWith(emoji)
              : S.of(context).reactionRemoved,
          context: context,
        );
      },
      onError: (exception, trace) {
        VAppAlert.showErrorSnackBar(
          message: S.of(context).failedToReactToStory,
          context: context,
        );
      },
    );

    setState(() {
      _isReacting = false;
    });
  }

  void _toggleMute() async {
    try {
      if (!_isMuted) {
        await _muteAudio();
        setState(() {
          _isMuted = true;
        });
        _bgMusicPlayer?.setVolume(0.0);
        VAppAlert.showSuccessSnackBar(
          message: S.of(context).storyMuted,
          context: context,
        );
      } else {
        await _restoreAudio();
        setState(() {
          _isMuted = false;
        });
        _bgMusicPlayer?.setVolume(1.0);
        VAppAlert.showSuccessSnackBar(
          message: S.of(context).storyUnmuted,
          context: context,
        );
      }
    } catch (e) {
      // Fallback: just toggle the visual state if audio control fails
      setState(() {
        _isMuted = !_isMuted;
      });
      if (_isMuted) {
        _bgMusicPlayer?.setVolume(0.0);
      } else {
        _bgMusicPlayer?.setVolume(1.0);
      }
      VAppAlert.showSuccessSnackBar(
        message: _isMuted
            ? S.of(context).mutedVisualOnly
            : S.of(context).unmutedVisualOnly,
        context: context,
      );
    }
  }

  Future<void> _replyToStory() async {
    if (_isReplying || _currentStoryModel.userData.isMe) return;

    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isReplying = true;
    });

    await vSafeApiCall<StoryReplyResponse>(
      request: () async {
        return await _api.replyToStory(current.id, text);
      },
      onSuccess: (response) async {
        _replyController.clear();

        // Remove focus from text field which will automatically resume the story
        _replyFocusNode.unfocus();

        // Show success feedback
        VAppAlert.showSuccessSnackBar(
          message: S.of(context).replySent,
          context: context,
        );

        // Navigate to chat with the story owner and create a story reply message
        await _navigateToStoryOwnerChat(text);
      },
      onError: (exception, trace) {
        VAppAlert.showErrorSnackBar(
          message: S.of(context).failedToSendReply,
          context: context,
        );
      },
    );

    setState(() {
      _isReplying = false;
    });
  }

  Future<void> _navigateToStoryOwnerChat(String replyText) async {
    try {
      // Navigate to chat with the story owner
      await VChatController.I.roomApi.openChatWith(
        peerId: _currentStoryModel.userData.id,
      );

      // Close the story view after navigating to chat
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      VAppAlert.showErrorSnackBar(
        message: S.of(context).failedToOpenChat,
        context: context,
      );
    }
  }

  Future<void> _parseStories() async {
    final built = <StoryItem>[];
    unawaited(
      StoryMediaCacheService.I.prefetchStoryMedia([_currentStoryModel]),
    );
    for (final story in _currentStoryModel.stories) {
      if (story.storyType == StoryType.image) {
        final storyUrl = story.att!['url']!;
        final fullNetworkUrl =
            StoryMediaCacheService.I.resolveStoryUrl(storyUrl.toString());

        print('=== STORY IMAGE DEBUG ===');
        print('Story ID: ${story.id}');
        print('Story URL from API: $storyUrl');
        print('Full Network URL: $fullNetworkUrl');
        print('========================');

        built.add(
          StoryItem.pageImage(
            url: fullNetworkUrl,
            controller: controller,
            caption: null, // Remove built-in caption, we'll use custom overlay
            duration: const Duration(seconds: 7),
          ),
        );
        continue;
      }

      if (story.storyType == StoryType.video) {
        final rawUrl = story.att?['url']?.toString() ?? '';
        final fullNetworkUrl = StoryMediaCacheService.I.resolveStoryUrl(rawUrl);

        // Prefer a thumbnail for web placeholder if available
        final rawThumb = story.att?['thumbUrl']?.toString();
        final fullThumbUrl = (rawThumb != null && rawThumb.isNotEmpty)
            ? StoryMediaCacheService.I.resolveStoryUrl(rawThumb)
            : null;

        print('=== STORY VIDEO DEBUG ===');
        print('Story ID: ${story.id}');
        print('Original URL from backend: $rawUrl');
        print('Constructed full URL: $fullNetworkUrl');
        print('Thumb (raw): $rawThumb | full: ${fullThumbUrl ?? 'none'}');
        print('=========================');

        final attDurationMs = _durationMsFromAtt(story.att?['duration']);
        final probedDurationMs = attDurationMs > 0
            ? attDurationMs
            : (await _probeNetworkVideoDurationMs(fullNetworkUrl) ?? -1);
        final videoDuration = probedDurationMs > 0
            ? Duration(milliseconds: probedDurationMs)
            : const Duration(minutes: 10);

        if (fullThumbUrl != null && fullThumbUrl.isNotEmpty) {
          built.add(
            StoryItem.pageImage(
              url: fullThumbUrl,
              controller: controller,
              caption: null,
              duration: videoDuration,
            ),
          );
        } else {
          built.add(
            StoryItem.text(
              title: '',
              duration: videoDuration,
              textStyle: const TextStyle(color: Colors.transparent),
              backgroundColor: Colors.black,
            ),
          );
        }
        continue;
      }
      if (story.storyType == StoryType.voice) {
        // Add a neutral placeholder; real player overlays on top and controls timeline
        final attDurationMs = _durationMsFromAtt(story.att?['duration']);
        final voiceDuration = attDurationMs > 0
            ? Duration(milliseconds: attDurationMs)
            : const Duration(minutes: 25);
        built.add(
          StoryItem.text(
            title: '',
            duration: voiceDuration,
            textStyle: const TextStyle(color: Colors.transparent),
            backgroundColor: Colors.black,
          ),
        );
        continue;
      }
      if (story.storyType == StoryType.text) {
        built.add(
          StoryItem.text(
            title: '',
            duration: const Duration(seconds: 10),
            textStyle: const TextStyle(color: Colors.transparent),
            backgroundColor: story.colorValue == null
                ? Colors.green
                : Color(story.colorValue!),
          ),
        );
        continue;
      }
    }

    if (!mounted) return;
    setState(() {
      stories = built;
      _isPreparingStories = false;
    });

    if (_currentStoryModel.stories.isNotEmpty) {
      current = _currentStoryModel.stories.first;
      _handleCurrentStoryChanged();
      Future.delayed(Duration.zero, () {
        if (!mounted) return;
        setState(() {
          _selectedEmoji = _storyReactions[current.id];
        });
        unawaited(_setSeen(current.id));
        widget.onStoryViewed?.call(current.id);
        _setupVoiceForCurrent();
        if (_currentStoryModel.userData.isMe) {
          _loadViewCount();
        }
        _checkExistingReaction();
        _startBgMusicForCurrent();
      });
    }
  }

  void _onReplyFocusChanged() {
    // If focus is gained, pause the story
    if (_replyFocusNode.hasFocus) {
      if (!_isTypingReply) {
        setState(() {
          _isTypingReply = true;
        });
        controller.pause();
        _pauseBgMusic();
        // Pause voice playback if current is voice
        if (current.storyType == StoryType.voice) {
          _voiceController?.pausePlaying();
        }
      }
    }
    // If focus is lost, resume the story
    else if (!_replyFocusNode.hasFocus) {
      if (_isTypingReply) {
        setState(() {
          _isTypingReply = false;
        });
        _resumeBgMusic();
        if (current.storyType == StoryType.voice) {
          _voiceController?.initAndPlay();
          controller.pause();
        } else {
          _playStoriesIfAllowed();
        }
      }
    }
  }

  /// Initialize audio components for controlling app audio
  Future<void> _initializeAudioSession() async {
    try {
      // Get current volume for restoration
      _originalVolume = await FlutterVolumeController.getVolume();
    } catch (e) {
      // Audio initialization failed - mute will fall back to visual only
    }
  }

  /// Mute the app's audio output using volume control only
  Future<void> _muteAudio() async {
    try {
      // Get current volume before muting (ensure it's not 0)
      final currentVolume = await FlutterVolumeController.getVolume();

      // If current volume is 0 or very low, set a default restore volume
      if (currentVolume != null && currentVolume <= 0.1) {
        _originalVolume = 0.5; // Default to 50% volume
      } else {
        _originalVolume = currentVolume ?? 0.5;
      }

      // Mute the device
      await FlutterVolumeController.setVolume(0.0);
    } catch (e) {
      // Audio muting failed - will show visual feedback only
      rethrow;
    }
  }

  /// Restore the app's audio output
  Future<void> _restoreAudio() async {
    try {
      // Restore to original volume or default if not set
      final volumeToRestore = _originalVolume ?? 0.5;
      await FlutterVolumeController.setVolume(volumeToRestore);
    } catch (e) {
      // Audio restoration failed - will show visual feedback only
    }
  }
}

class _InlineStoryVideoPlayer extends StatefulWidget {
  final String url;
  final bool muted;
  final VoidCallback? onReady;

  const _InlineStoryVideoPlayer({
    super.key,
    required this.url,
    required this.muted,
    this.onReady,
  });

  @override
  State<_InlineStoryVideoPlayer> createState() =>
      _InlineStoryVideoPlayerState();
}

class _InlineStoryVideoPlayerState extends State<_InlineStoryVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await controller.initialize().timeout(const Duration(seconds: 15));
      controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0 : 1);
      await controller.play();
      widget.onReady?.call();
      if (mounted) {
        setState(() {
          _controller = controller;
          _initialized = true;
        });
      }
    } catch (_) {
      // ignore inline video init failures
    }
  }

  @override
  void didUpdateWidget(covariant _InlineStoryVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _initialized = false;
      _init();
      return;
    }
    if (oldWidget.muted != widget.muted && _controller != null) {
      _controller!.setVolume(widget.muted ? 0 : 1);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator.adaptive(),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio == 0
          ? 9 / 16
          : _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}

// ---------------------------------------------------------------------------
// Post card shown over shared-post stories — tapping navigates to the post
// ---------------------------------------------------------------------------
class _StoryPostCard extends StatelessWidget {
  final Map<String, dynamic> att;
  final String caption;
  final VoidCallback onTap;

  const _StoryPostCard({
    required this.att,
    required this.onTap,
    this.caption = '',
  });

  String get _postType => (att['postType'] ?? 'image').toString();
  String get _authorName => (att['authorName'] ?? '').toString();
  String get _authorImage => (att['authorImage'] ?? '').toString();
  String get _placeName => (att['placeName'] ?? '').toString();
  String get _address => (att['address'] ?? '').toString();
  String get _latitude => (att['latitude'] ?? '').toString();
  String get _longitude => (att['longitude'] ?? '').toString();
  String get _rawThumb =>
      (att['thumbnailUrl'] ?? att['thumbUrl'] ?? att['url'] ?? '').toString();
  String get _rawMedia => (att['mediaUrl'] ?? '').toString();

  String _deriveCloudinaryThumb(String url) {
    if (url.isEmpty || !url.startsWith('http')) return '';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains('res.cloudinary.com')) return '';
    final path = uri.path;
    const upload = '/upload/';
    final idx = path.indexOf(upload);
    if (idx == -1) return '';
    final prefix =
        '${uri.scheme}://${uri.host}${path.substring(0, idx + upload.length)}';
    final tail =
        path.substring(idx + upload.length).replaceFirst(RegExp(r'^/+'), '');
    final jpgTail = tail.replaceFirst(RegExp(r'\.[^./]+$'), '.jpg');
    return '${prefix}so_1,w_640,h_360,c_fill,f_jpg/$jpgTail';
  }

  String get _displayThumb {
    final thumb =
        _rawThumb.isNotEmpty ? _rawThumb : _deriveCloudinaryThumb(_rawMedia);
    if (thumb.isEmpty) return '';
    return thumb.startsWith('http')
        ? thumb
        : '${SConstants.baseMediaUrl}$thumb';
  }

  String get _cardCaption {
    if (caption.trim().isNotEmpty) return caption.trim();
    final candidates = <String>[
      (att['caption'] ?? '').toString(),
      (att['postCaption'] ?? '').toString(),
      (att['description'] ?? '').toString(),
      (att['text'] ?? '').toString(),
      (att['content'] ?? '').toString(),
    ];
    for (final raw in candidates) {
      final value = raw.trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isLocation = _postType == 'location';
    final isReel = _postType == 'reel';
    final isVideo = isReel || _postType == 'video';
    final thumb = _displayThumb;
    final hasImage = thumb.isNotEmpty;
    final cardCaption = _cardCaption;

    final headerText = isLocation
        ? 'Shared a Location'
        : (isReel
            ? 'Shared a Reel'
            : (_postType == 'video' ? 'Shared a Video' : 'Shared a Post'));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFB48648).withOpacity(0.6),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.grid_view_rounded,
                  size: 14,
                  color: Color(0xFFB48648),
                ),
                const SizedBox(width: 5),
                Text(
                  headerText,
                  style: const TextStyle(
                    color: Color(0xFFB48648),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: Colors.white54,
                ),
              ],
            ),
            if (hasImage) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Image.network(
                      thumb,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 160,
                        color: const Color(0xFFB48648).withOpacity(0.15),
                        child: const Center(
                          child: Icon(Icons.image_not_supported,
                              color: Color(0xFFB48648), size: 36),
                        ),
                      ),
                    ),
                    if (isVideo)
                      const Positioned.fill(
                        child: Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (isLocation) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on,
                      color: Color(0xFFB48648), size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _placeName.isNotEmpty
                          ? (_address.isNotEmpty
                              ? '$_placeName, $_address'
                              : _placeName)
                          : (_address.isNotEmpty
                              ? _address
                              : ((_latitude.isNotEmpty && _longitude.isNotEmpty)
                                  ? '$_latitude, $_longitude'
                                  : 'Location')),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (cardCaption.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                cardCaption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (_authorImage.isNotEmpty)
                  CircleAvatar(
                    radius: 13,
                    backgroundImage: NetworkImage(
                      _authorImage.startsWith('http')
                          ? _authorImage
                          : '${SConstants.baseMediaUrl}$_authorImage',
                    ),
                  )
                else
                  const CircleAvatar(
                    radius: 13,
                    child: Icon(Icons.person, size: 16),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryTicketCard extends StatelessWidget {
  final Map<String, dynamic> att;
  final VoidCallback onTap;

  const _StoryTicketCard({
    required this.att,
    required this.onTap,
  });

  String get _name => (att['name'] ?? 'Ticket').toString();
  String get _uploaderName => (att['uploaderName'] ?? '').toString();
  String get _uploaderImage => (att['uploaderImage'] ?? '').toString();
  String get _imageUrl => (att['imageUrl'] ?? '').toString();
  bool get _hasImage => att['hasImage'] == true || _imageUrl.isNotEmpty;
  double get _price => (att['priceKes'] ?? 0) is num ? (att['priceKes'] ?? 0).toDouble() : double.tryParse((att['priceKes'] ?? 0).toString()) ?? 0;
  String get _category => (att['category'] ?? '').toString();
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFB48648).withOpacity(0.6),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.ticket,
                  size: 14,
                  color: Color(0xFFB48648),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Shared a Ticket',
                  style: TextStyle(
                    color: Color(0xFFB48648),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: Colors.white54,
                ),
              ],
            ),
            if (_hasImage) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Image.network(
                      _imageUrl,
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        color: const Color(0xFFB48648).withOpacity(0.15),
                        child: const Center(
                          child: Icon(Icons.image_not_supported,
                              color: Color(0xFFB48648), size: 36),
                        ),
                      ),
                    ),
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Image.network(
                        _imageUrl,
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 120,
                      color: Colors.black.withOpacity(0.32),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.lock,
                          color: CupertinoColors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip('KES ${_price.toStringAsFixed(0)}', CupertinoIcons.money_dollar),
                if (_category.isNotEmpty) _chip(_category, CupertinoIcons.tag),
              ],
            ),
            if (_uploaderName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_uploaderImage.isNotEmpty)
                    CircleAvatar(
                      radius: 13,
                      backgroundImage: NetworkImage(
                        _uploaderImage.startsWith('http')
                            ? _uploaderImage
                            : '${SConstants.baseMediaUrl}$_uploaderImage',
                      ),
                    )
                  else
                    const CircleAvatar(
                      radius: 13,
                      child: Icon(Icons.person, size: 16),
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _uploaderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFB48648)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
