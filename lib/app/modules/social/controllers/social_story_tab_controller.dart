import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_media_editor/v_chat_media_editor.dart';
import 'package:v_platform/v_platform.dart';

import '../../../core/api_service/story/story_api_service.dart';
import '../../../core/models/story/story_model.dart';
import '../../../core/utils/enums.dart';
import '../../../core/utils/permission_manager.dart';
import '../../story/media_story/create_media_story.dart';
import '../../story/text_story/create_text_story.dart';
import '../../story/voice_story/create_voice_story.dart';
import '../../story/story_subscription/story_subscription_helper.dart';

class SocialStoryTabState {
  List<UserStoryModel> allStories = [];
  UserStoryModel myStories =
      UserStoryModel(stories: [], userData: AppAuth.myProfile.baseUser);
  bool isMyStoriesLoading = false;
}

class SocialStoryTabController extends SLoadingController<SocialStoryTabState> {
  SocialStoryTabController() : super(SLoadingState(SocialStoryTabState())) {
    debugPrint('SocialStoryTabController created');
  }
  final _apiService = GetIt.I.get<StoryApiService>();
  Timer? _timer;
  bool _didInit = false;
  final _streamController =
      StreamController<SLoadingState<SocialStoryTabState>>.broadcast();

  Stream<SLoadingState<SocialStoryTabState>> get stream =>
      _streamController.stream;

  @override
  void onInit() {
    debugPrint('SocialStoryTabController onInit called');
    if (_didInit) return;
    _didInit = true;
    getStories();
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      getStoriesFromApi();
    });
    getMyStoryFromApi();
  }

  @override
  void onClose() {
    debugPrint('SocialStoryTabController onClose called');
    _timer?.cancel();
    _didInit = false;
  }

  @override
  void update() {
    debugPrint('SocialStoryTabController update called');
    super.update();
    _streamController.add(value);
  }

  @override
  void setStateSuccess() {
    debugPrint('SocialStoryTabController setStateSuccess called');
    super.setStateSuccess();
    _streamController.add(value);
  }

  void getStories() async {
    try {
      final oldStories = VAppPref.getMap("api/stories/social_all");
      if (oldStories != null) {
        final list = oldStories['data'] as List;
        data.allStories = list.map((e) => UserStoryModel.fromMap(e)).toList();
        setStateSuccess();
      }
    } catch (err) {
      // ignore
    }
    await getStoriesFromApi();
  }

  Future<void> getStoriesFromApi() async {
    vSafeApiCall(
      request: () {
        return _apiService.getUsersStories(
          page: 1,
          limit: 50,
          storySource: 'social',
        );
      },
      onSuccess: (response) {
        debugPrint('getStoriesFromApi onSuccess: ${response.length} stories');
        data.allStories = response;
        if (response.isEmpty) {
          data.allStories.clear();
          unawaited(VAppPref.removeKey("api/stories/social_all"));
        } else {
          unawaited(VAppPref.setMap("api/stories/social_all", {
            "data": response.map((e) => e.toMap()).toList(),
          }));
        }
        setStateSuccess();
        update();
      },
    );
  }

  Future getMyStoryFromApi() async {
    vSafeApiCall<UserStoryModel?>(
      request: () {
        return _apiService.getMyStories(storySource: 'social');
      },
      onSuccess: (response) {
        debugPrint(
            'getMyStoryFromApi onSuccess: ${response?.stories.length ?? 0} stories');
        if (response == null) {
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
        const CreateTextStory(storySource: 'social'),
      );
    }
    if (res.id == "2") {
      final ok = await StorySubscriptionHelper.guardCreateMediaStory(context);
      if (!ok) return;
      if (kIsWeb || VPlatforms.isDeskTop) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Media stories are available on mobile only',
        );
      } else {
        await _handleMediaStory(context);
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
          const CreateVoiceStory(storySource: 'social'),
        );
      }
    }
    await getMyStoryFromApi();
    await getStoriesFromApi();
    update();
  }

  Future<void> _handleMediaStory(BuildContext context) async {
    final pickRes = await VAppAlert.showModalSheetWithActions(
      content: [
        ModelSheetItem(title: S.of(context).camera, id: "1"),
        ModelSheetItem(title: S.of(context).gallery, id: "2"),
      ],
      context: context,
    );
    if (pickRes == null) return;

    VPlatformFile? mediaFile;
    if (pickRes.id == "1") {
      mediaFile = await _onCameraPress(context);
    } else {
      mediaFile = await _pickFromGallery(context);
    }
    if (mediaFile == null || !context.mounted) return;

    final isVideo = _isVideoFile(mediaFile);
    debugPrint('Picked file is video: $isVideo');

    if (isVideo) {
      await context.toPage(CreateMediaStory(
        media: VMediaVideoRes(
          data: MessageVideoData(
            fileSource: mediaFile,
            duration: 0,
            thumbImage: null,
          ),
        ),
        storySource: 'social',
      ));
    } else {
      await context.toPage(CreateMediaStory(
        media: VMediaImageRes(
          data: MessageImageData(
            fileSource: mediaFile,
            width: 0,
            height: 0,
            blurHash: null,
          ),
        ),
        storySource: 'social',
      ));
    }
    await getMyStoryFromApi();
    await getStoriesFromApi();
    update();
  }

  bool _isVideoFile(VPlatformFile file) {
    final extension = file.name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'].contains(extension);
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
    return entity;
  }

  Future<VPlatformFile?> _pickFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickMedia();
      if (xFile == null) return null;
      if (xFile.path.isEmpty) return null;
      return VPlatformFile.fromPath(fileLocalPath: xFile.path);
    } catch (e) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        if (file.path != null && file.path!.isNotEmpty) {
          return VPlatformFile.fromPath(fileLocalPath: file.path!);
        } else if (file.bytes != null) {
          return VPlatformFile.fromBytes(
            name: file.name,
            bytes: file.bytes!,
          );
        }
      }
      return null;
    }
  }

  void markStoryAsViewed(String storyId) {
    Future.delayed(Duration.zero, () {
      for (int i = 0; i < data.allStories.length; i++) {
        final userStory = data.allStories[i];
        final stories = List<StoryModel>.from(userStory.stories);
        var updatedAny = false;

        for (int j = 0; j < stories.length; j++) {
          final s = stories[j];
          if (s.id == storyId && !s.viewedByMe) {
            stories[j] = StoryModel(
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
            updatedAny = true;
            break;
          }
        }

        if (updatedAny) {
          data.allStories[i] = UserStoryModel(
            userData: userStory.userData,
            stories: stories,
          );
          unawaited(VAppPref.setMap("api/stories/social_all", {
            "data": data.allStories.map((e) => e.toMap()).toList(),
          }));
          setStateSuccess();
          update();
          return;
        }
      }
    });
  }
}
