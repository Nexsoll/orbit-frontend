// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:developer';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_media_editor/v_chat_media_editor.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../../../../core/api_service/story/story_api_service.dart';
import '../../../../../core/models/channel/channel_suggestion.dart';
import '../../../../../core/models/story/story_model.dart';
import '../../../../../core/utils/enums.dart';
import '../../../../../core/utils/permission_manager.dart';
import '../../../../story/media_story/create_media_story.dart';
import '../../../../story/text_story/create_text_story.dart';
import '../../../../story/voice_story/create_voice_story.dart';
import '../../../../story/story_subscription/story_subscription_helper.dart';

class StoryTabState {
  List<UserStoryModel> allStories = [];
  List<UserStoryModel> viewedStories = [];
  UserStoryModel myStories =
      UserStoryModel(stories: [], userData: AppAuth.myProfile.baseUser);
  bool isMyStoriesLoading = false;
  // Channels suggestions
  List<ChannelSuggestion> channelSuggestions = [];
  bool isChannelsLoading = false;

  // Helper methods to separate viewed and unviewed stories
  List<UserStoryModel> get unviewedStories {
    return allStories.where((userStory) {
      // Show in recent updates if ANY story is unviewed
      return userStory.stories.any((story) => !story.viewedByMe);
    }).toList();
  }

  List<UserStoryModel> get completelyViewedStories {
    return allStories.where((userStory) {
      // Show in viewed updates if ALL stories are viewed
      return userStory.stories.isNotEmpty &&
          userStory.stories.every((story) => story.viewedByMe);
    }).toList();
  }
}

class StoryTabController extends SLoadingController<StoryTabState> {
  StoryTabController() : super(SLoadingState(StoryTabState()));
  final _apiService = GetIt.I.get<StoryApiService>();
  Timer? _timer;
  bool _didInit = false;
  final Set<String> _processingStoryIds = <String>{};
  final Set<String> _optimisticSeenStoryIds = <String>{};
  StreamSubscription<VStoryEvents>? _storyEventSubscription;
  StreamSubscription<VDeleteRoomEvent>? _roomDeleteSub;
  StreamSubscription<VInsertRoomEvent>? _roomInsertSub;
  final _streamController =
      StreamController<SLoadingState<StoryTabState>>.broadcast();

  /// 🔹 Expose the stream
  Stream<SLoadingState<StoryTabState>> get stream => _streamController.stream;

  @override
  void onInit() {
    if (_didInit) return;
    _didInit = true;
    getStories();
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      getStoriesFromApi();
    });
    getMyStoryFromApi();
    // fetch channels suggestions
    getChannelSuggestions();

    // Listen for story deletion events
    _storyEventSubscription =
        VChatController.I.nativeApi.streams.storyStream.listen((event) {
      if (event is VStoryDeletedEvent) {
        _handleStoryDeleted(event);
      }
    });

    // When a room is deleted locally (e.g., a channel deleted), remove it from channels suggestions instantly
    _roomDeleteSub =
        VEventBusSingleton.vEventBus.on<VDeleteRoomEvent>().listen((event) {
      final index = value.data.channelSuggestions
          .indexWhere((e) => e.roomId == event.roomId);
      if (index != -1) {
        value.data.channelSuggestions.removeAt(index);
        setStateSuccess();
        update();
      }
    });

    // When a room is inserted (e.g., new channel created), refresh suggestions so it appears immediately if applicable
    _roomInsertSub =
        VEventBusSingleton.vEventBus.on<VInsertRoomEvent>().listen((event) {
      getChannelSuggestions();
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    _storyEventSubscription?.cancel();
    _roomDeleteSub?.cancel();
    _roomInsertSub?.cancel();
    _processingStoryIds.clear();
    _optimisticSeenStoryIds.clear();
    _didInit = false;
  }

  @override
  void update() {
    super.update();
    _streamController.add(value);
  }

  @override
  void setStateSuccess() {
    super.setStateSuccess();
    _streamController.add(value);
  }

  void _handleStoryDeleted(VStoryDeletedEvent event) {
    // Remove the deleted story from all stories
    _optimisticSeenStoryIds.remove(event.storyId);
    for (int i = 0; i < data.allStories.length; i++) {
      final userStory = data.allStories[i];

      // Remove the story from this user's stories
      userStory.stories.removeWhere((story) => story.id == event.storyId);

      // If this user has no more stories, remove the entire user story
      if (userStory.stories.isEmpty) {
        data.allStories.removeAt(i);
        i--; // Adjust index after removal
      }
    }

    // Also remove from my stories if it's my story
    if (data.myStories.userData.id == event.userId) {
      data.myStories.stories.removeWhere((story) => story.id == event.storyId);
    }

    // Update the UI
    update();

    // Update cached data
    VAppPref.setMap("api/stories/all", {
      "data": data.allStories.map((e) => e.toMap()).toList(),
    });
  }

  void getStories() async {
    try {
      final oldStories = VAppPref.getMap("api/stories/all");
      if (oldStories != null) {
        final list = oldStories['data'] as List;
        data.allStories = list.map((e) => UserStoryModel.fromMap(e)).toList();
        setStateSuccess();
      }
    } catch (err) {
      if (kDebugMode) {
        print(err);
      }
    }
    await Future.wait([
      getStoriesFromApi(),
      getChannelSuggestions(),
    ]);
  }

  Future<void> getStoriesFromApi() async {
    vSafeApiCall(
      request: () {
        return _apiService.getUsersStories(
            page: 1, limit: 50, storySource: 'main');
      },
      onSuccess: (response) {
        // Fully replace list, but keep optimistic local "seen" flags to avoid UI flicker
        final seenIdsInResponse = <String>{};
        final merged = response.map((userStory) {
          final updatedStories = userStory.stories.map((s) {
            seenIdsInResponse.add(s.id);
            if (_optimisticSeenStoryIds.contains(s.id)) {
              if (!s.viewedByMe) {
                return StoryModel(
                  id: s.id,
                  userId: s.userId,
                  content: s.content,
                  backgroundColor: s.backgroundColor,
                  caption: s.caption,
                  att: s.att,
                  expireAt: s.expireAt,
                  createdAt: s.createdAt,
                  updatedAt: s.updatedAt,
                  storyType: s.storyType,
                  fontType: s.fontType,
                  viewedByMe: true,
                  viewsCount: s.viewsCount,
                );
              }
              // Server already reflects seen; drop from optimistic set to prevent growth
              _optimisticSeenStoryIds.remove(s.id);
            }
            return s;
          }).toList();

          return UserStoryModel(
            userData: userStory.userData,
            stories: updatedStories,
          );
        }).toList();

        // Cleanup optimistic seen ids for stories no longer present (expired/deleted)
        _optimisticSeenStoryIds
            .removeWhere((id) => !seenIdsInResponse.contains(id));

        data.allStories = merged;

        // Persist to cache
        if (response.isEmpty) {
          data.allStories.clear();
          unawaited(VAppPref.removeKey("api/stories/all"));
        } else {
          unawaited(VAppPref.setMap("api/stories/all", {
            "data": merged.map((e) => e.toMap()).toList(),
          }));
        }

        // Notify UI
        setStateSuccess();
        update();
      },
    );
  }

  Future getMyStoryFromApi() async {
    vSafeApiCall<UserStoryModel?>(
      request: () {
        return _apiService.getMyStories(storySource: 'main');
      },
      onSuccess: (response) {
        if (response == null) {
          // If no stories, create empty story model
          data.myStories =
              UserStoryModel(stories: [], userData: AppAuth.myProfile.baseUser);
        } else {
          data.myStories = response;
        }
        setStateSuccess();
        update();
      },
    );
  }

  void toCreateStory(BuildContext context) async {
    final res = await VAppAlert.showModalSheetWithActions(
      content: [
        ModelSheetItem(
          title: S.of(context).createTextStory,
          id: "1",
        ),
        ModelSheetItem(
          title: S.of(context).createMediaStory,
          id: "2",
        ),
        ModelSheetItem(
          title: 'Create Voice Story',
          id: "3",
        ),
      ],
      context: context,
    );
    if (res == null) return;
    if (res.id == "1") {
      final ok = await StorySubscriptionHelper.guardCreateStory(
        context,
        StoryType.text,
      );
      if (!ok) return;
      await context.toPage(
        const CreateTextStory(),
      );
    }
    if (res.id == "2") {
      final ok = await StorySubscriptionHelper.guardCreateMediaStory(context);
      if (!ok) return;
      // For web, show media picker options in a way that preserves user gesture
      if (kIsWeb) {
        await _handleWebMediaStoryCreation(context);
      } else {
        final pickOption = await _processPickMedia(context);
        if (pickOption == null) {
          return; // User canceled initial camera/gallery choice
        }
        await _handleMediaStoryCreation(context, pickOption);
      }
    }
    if (res.id == "3") {
      if (kIsWeb || VPlatforms.isDeskTop) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Voice stories are available on mobile only',
        );
      } else {
        final ok = await StorySubscriptionHelper.guardCreateStory(
          context,
          StoryType.voice,
        );
        if (!ok) return;
        await context.toPage(
          const CreateVoiceStory(),
        );
      }
    }
    getMyStoryFromApi();
  }

  Future<void> _handleWebMediaStoryCreation(BuildContext context) async {
    while (true) {
      // For web, show camera/gallery options and immediately trigger file picker
      final res = await VAppAlert.showModalSheetWithActions(
        content: [
          ModelSheetItem(
            title: S.of(context).camera,
            id: "1",
          ),
          ModelSheetItem(
            title: S.of(context).gallery,
            id: "2",
          ),
        ],
        context: context,
      );

      if (res == null) return;

      VPlatformFile? mediaFile;
      if (res.id == "1") {
        mediaFile = await _onCameraPress(context);
      } else {
        // Call file picker immediately to preserve user gesture
        mediaFile = await _pickFromGallery(context);
      }

      if (mediaFile == null) {
        // User canceled media picking, exit completely
        return;
      }

      if (kDebugMode) {
        print(
            'Web: Media file selected: ${mediaFile.name}, calling onSubmitMedia...');
      }

      final mediaAfterEdit = await onSubmitMedia(context, [mediaFile]);
      if (mediaAfterEdit == null) {
        // User canceled from the editor. Loop will continue to re-prompt for media picking.
        if (kDebugMode) {
          print('Web: Media editor returned null, retrying...');
        }
        continue;
      }

      if (kDebugMode) {
        print('Web: Media editor completed, navigating to CreateMediaStory...');
      }

      // If we reach here, mediaAfterEdit is not null, so we proceed to CreateMediaStory
      await context.toPage(
        CreateMediaStory(
          media: mediaAfterEdit,
        ),
      );
      return; // Exit the loop and the function after successful story creation
    }
  }

  Future<void> _handleMediaStoryCreation(
      BuildContext context, int pickOption) async {
    while (true) {
      // Loop to allow re-picking media
      VPlatformFile? mediaFile;
      if (pickOption == 1) {
        mediaFile = await _onCameraPress(context);
      } else {
        mediaFile = await _pickFromGallery(context);
      }

      if (mediaFile == null) {
        // User canceled media picking (from camera or gallery)
        return; // Exit the loop and the function
      }

      final mediaAfterEdit = await onSubmitMedia(context, [mediaFile]);
      if (mediaAfterEdit == null) {
        // User canceled from the editor. Loop will continue to re-prompt for media picking.
        continue;
      }

      // If we reach here, mediaAfterEdit is not null, so we proceed to CreateMediaStory
      await context.toPage(
        CreateMediaStory(
          media: mediaAfterEdit,
        ),
      );
      return; // Exit the loop and the function after successful story creation
    }
  }

  Future<VPlatformFile?> _onCameraPress(BuildContext context) async {
    final isCameraAllowed = await PermissionManager.isCameraAllowed();
    if (!isCameraAllowed) {
      final x = await PermissionManager.askForCamera();
      if (!x) return null;
    }
    final entity = await VAppPick.pickFromWeAssetCamera(
      context: context,
    );
    if (entity == null) return null;
    return entity;
  }

  Future<VPlatformFile?> _pickFromGallery(BuildContext context) async {
    try {
      if (kDebugMode) {
        print(
            '_pickFromGallery called - platform: ${kIsWeb ? "web" : "mobile"}');
      }

      if (!kIsWeb && VPlatforms.isMobile) {
        final picker = ImagePicker();
        final xFile = await picker.pickMedia();
        if (xFile == null) return null;
        if (xFile.path.isEmpty) return null;
        return VPlatformFile.fromPath(fileLocalPath: xFile.path);
      }

      // Call FilePicker immediately to preserve user gesture context
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media, // This allows both images and videos
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        if (kDebugMode) {
          print('File picked: ${file.name}, size: ${file.size}');
        }

        // Convert PlatformFile to VPlatformFile
        // On web, path is not available, so use bytes instead
        if (file.path != null && file.path!.isNotEmpty) {
          return VPlatformFile.fromPath(
            fileLocalPath: file.path!,
          );
        } else if (file.bytes != null) {
          return VPlatformFile.fromBytes(
            name: file.name,
            bytes: file.bytes!,
          );
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error picking file from gallery: $e');
      }
      // For web, don't fallback to avoid additional user gesture issues
      if (kIsWeb) {
        return null;
      }
      // Fallback to the original image picker if FilePicker fails on mobile
      return await VAppPick.getImage(isFromCamera: false);
    }
  }

  Future<VBaseMediaRes?> onSubmitMedia(
    BuildContext context,
    List<VPlatformFile> files,
  ) async {
    if (kDebugMode) {
      print('onSubmitMedia called with ${files.length} files');
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        log('File $i: ${file.name}, isFromBytes: ${file.isFromBytes}, isFromPath: ${file.isFromPath}, size: ${file.isFromBytes ? file.bytes?.length : 'N/A'}');
      }
    }

    try {
      final result = await context.toPage(VMediaEditorView(
        files: files,
        config: const VMediaEditorConfig(
          showTextInput: false, // Don't show text input for stories
          showOneTimeToggle: false, // Don't show one-time toggle for stories
        ),
      )) as VMediaEditorResult?;

      if (kDebugMode) {
        print(
            'VMediaEditorView result: ${result != null ? 'not null' : 'null'}');
        if (result != null) {
          print('Result has ${result.mediaFiles.length} media files');
        }
      }

      if (result == null || result.mediaFiles.isEmpty) return null;
      return result.mediaFiles.first;
    } catch (e) {
      if (kDebugMode) {
        print('Error in onSubmitMedia: $e');
      }
      return null;
    }
  }

  Future<int?> _processPickMedia(BuildContext context) async {
    final res = await VAppAlert.showModalSheetWithActions(
      content: [
        ModelSheetItem(
          title: S.of(context).camera,
          id: "1",
        ),
        ModelSheetItem(
          title: S.of(context).gallery,
          id: "2",
        ),
      ],
      context: context,
    );
    if (res == null) return null;
    return res.id == "1" ? 1 : 2;
  }

  // Method to mark a story as viewed
  void markStoryAsViewed(String storyId) {
    // Use delayed call to avoid setState during build
    Future.delayed(Duration.zero, () {
      _updateStoryViewStatus(storyId);
    });
  }

  void _updateStoryViewStatus(String storyId) {
    // Prevent duplicate processing
    if (_processingStoryIds.contains(storyId)) return;
    _processingStoryIds.add(storyId);
    _optimisticSeenStoryIds.add(storyId);

    try {
      for (int i = 0; i < data.allStories.length; i++) {
        final userStory = data.allStories[i];
        for (int j = 0; j < userStory.stories.length; j++) {
          if (userStory.stories[j].id == storyId) {
            // Skip if already viewed
            if (userStory.stories[j].viewedByMe) {
              _processingStoryIds.remove(storyId);
              return;
            }

            // Create a new story with viewedByMe = true
            final updatedStory = StoryModel(
              id: userStory.stories[j].id,
              userId: userStory.stories[j].userId,
              content: userStory.stories[j].content,
              backgroundColor: userStory.stories[j].backgroundColor,
              caption: userStory.stories[j].caption,
              att: userStory.stories[j].att,
              expireAt: userStory.stories[j].expireAt,
              createdAt: userStory.stories[j].createdAt,
              updatedAt: userStory.stories[j].updatedAt,
              storyType: userStory.stories[j].storyType,
              fontType: userStory.stories[j].fontType,
              viewedByMe: true,
            );

            // Create a new list with the updated story
            final updatedStories = List<StoryModel>.from(userStory.stories);
            updatedStories[j] = updatedStory;

            // Create a new UserStoryModel with updated stories
            final updatedUserStory = UserStoryModel(
              userData: userStory.userData,
              stories: updatedStories,
            );

            // Update the allStories list
            data.allStories[i] = updatedUserStory;

            // Persist optimistic seen into cache so it doesn't revert before server refresh
            unawaited(VAppPref.setMap("api/stories/all", {
              "data": data.allStories.map((e) => e.toMap()).toList(),
            }));

            // Trigger UI update
            setStateSuccess();
            update();
            _processingStoryIds.remove(storyId);
            return;
          }
        }
      }
    } finally {
      _processingStoryIds.remove(storyId);
    }
  }

  /// Force refresh all stories from API (called from external services)
  Future<void> forceRefreshStories() async {
    await getStoriesFromApi();
    setStateSuccess();
    update();
  }

  // -------------------- Channels --------------------
  Future<void> getChannelSuggestions({int limit = 20}) async {
    value.data.isChannelsLoading = true;
    update();
    try {
      final list =
          await VChatController.I.roomApi.getSuggestedChannels(limit: limit);
      final suggested = list.map((e) => ChannelSuggestion.fromMap(e)).toList();
      if (suggested.isNotEmpty) {
        value.data.channelSuggestions = suggested;
      } else {
        value.data.channelSuggestions = await _fallbackChannelsFromRooms(limit);
      }
      setStateSuccess();
      update();
    } catch (e) {
      debugPrint('getChannelSuggestions error: $e');
      value.data.channelSuggestions = await _fallbackChannelsFromRooms(limit);
    } finally {
      value.data.isChannelsLoading = false;
      update();
    }
  }

  Future<List<ChannelSuggestion>> _fallbackChannelsFromRooms(int limit) async {
    try {
      final roomsRes =
          await VChatController.I.nativeApi.remote.room.getRooms(VRoomsDto(limit: limit));
      final rooms = roomsRes.data;
      return rooms
          .where((r) => r.roomType == VRoomType.g && !r.isArchived)
          .take(limit)
          .map(
            (r) => ChannelSuggestion(
              roomId: r.id,
              title: r.title,
              image: r.thumbImage,
              followers: 0,
              isJoined: false,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('fallbackChannelsFromRooms error: $e');
      return [];
    }
  }

  Future<void> joinAndOpenChannel(
      BuildContext context, ChannelSuggestion item) async {
    try {
      // Join if needed
      VRoom vRoom;
      if (!item.isJoined) {
        vRoom =
            await VChatController.I.roomApi.joinChannel(roomId: item.roomId);
        item.isJoined = true;
      } else {
        final localRoom = await VChatController.I.nativeApi.local.room
            .getOneWithLastMessageByRoomId(item.roomId);
        if (localRoom != null) {
          vRoom = localRoom;
        } else {
          // Fallback: fetch room by id through channel api getRoomById
          vRoom = await VChatController.I.nativeApi.remote.room
              .getRoomById(item.roomId);
        }
      }
      VChatController.I.vNavigator.messageNavigator
          .toMessagePage(context, vRoom);
    } catch (e) {
      // ignore open failures
    }
  }

  /// Open channel only if already joined. Otherwise show a message and do nothing.
  Future<void> openChannelIfJoined(
      BuildContext context, ChannelSuggestion item) async {
    try {
      VRoom vRoom;
      if (item.isJoined) {
        final localRoom = await VChatController.I.nativeApi.local.room
            .getOneWithLastMessageByRoomId(item.roomId);
        if (localRoom != null) {
          vRoom = localRoom;
        } else {
          // Fallback (requires membership)
          vRoom = await VChatController.I.nativeApi.remote.room
              .getRoomById(item.roomId);
        }
      } else {
        // Build a lightweight preview room so the user can view messages without following
        vRoom = VRoom(
          id: item.roomId,
          title: item.title,
          enTitle: item.title,
          roomType: VRoomType.g,
          thumbImage: item.image.isNotEmpty ? item.image : 'empty!.png',
          mentionsCount: 0,
          transTo: null,
          isArchived: false,
          unReadCount: 0,
          isOneSeen: false,
          lastMessage: VEmptyMessage(),
          createdAt: DateTime.now(),
          isMuted: false,
          peerId: null,
          nickName: null,
        );
      }
      VChatController.I.vNavigator.messageNavigator
          .toMessagePage(context, vRoom);
    } catch (e) {
      // ignore open failures
    }
  }
}
