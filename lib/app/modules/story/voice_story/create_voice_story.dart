import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/story/story_api_service.dart';
import 'package:super_up/app/core/models/story/create_story_dto.dart';
import 'package:super_up/app/core/services/story_status_service.dart';
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_input_ui/src/recorder/record_widget.dart';

import '../story_privacy/story_privacy_selection_screen.dart';
import '../../social/controllers/social_story_tab_controller.dart';
import '../story_subscription/story_subscription_helper.dart';

class CreateVoiceStory extends StatefulWidget {
  final String storySource;
  const CreateVoiceStory({super.key, this.storySource = 'main'});

  @override
  State<CreateVoiceStory> createState() => _CreateVoiceStoryState();
}

class _CreateVoiceStoryState extends State<CreateVoiceStory> {
  final _txtController = TextEditingController();
  final _recordKey = GlobalKey<RecordWidgetState>();
  final _api = GetIt.I.get<StoryApiService>();
  final _storyStatusService = GetIt.I.get<StoryStatusService>();

  StoryPrivacy _storyPrivacy = StoryPrivacy.public;
  List<String>? _selectedUserIds;
  List<String>? _excludedUserIds;

  @override
  void dispose() {
    _txtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: Colors.black,
        middle: Text(
          'Create Voice Story',
          style: TextStyle(color: Colors.white),
        ),
      ),
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Recorder widget
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: RecordWidget(
                  key: _recordKey,
                  maxTime: const Duration(minutes: 2),
                  onMaxTime: () {},
                  onCancel: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Caption + actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _txtController,
                      placeholder: 'Write a caption',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      placeholderStyle: const TextStyle(color: Colors.white70),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Privacy button
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
                        children: const [
                          Icon(CupertinoIcons.lock_fill,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Privacy',
                            style: TextStyle(
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
                  // Send button
                  GestureDetector(
                    onTap: uploadVoiceStory,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacySelection() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => StoryPrivacySelectionScreen(
          onPrivacySelected: (privacy, selectedUserIds, excludedUserIds) {
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

  Future<void> uploadVoiceStory() async {
    final state = _recordKey.currentState;
    if (state == null) return;

    await vSafeApiCall(
      onLoading: () {
        VAppAlert.showLoading(context: context);
      },
      request: () async {
        // Stop and obtain voice data
        final data = await state.stopRecord();
        final dto = CreateStoryDto(
          storyType: StoryType.voice,
          content: StoryType.voice.name,
          caption: _txtController.text,
          image: data.fileSource,
          attachment: {
            'duration': data.duration,
          },
          storyPrivacy: _storyPrivacy,
          somePeople: _selectedUserIds,
          exceptPeople: _excludedUserIds,
          storySource: widget.storySource,
        );
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
          message: 'Story created successfully',
        );
      },
      onError: (exception, trace) {
        context.pop();
        final msg = exception.toString();
        if (StorySubscriptionHelper.openIfRequired(context, msg)) return;
        VAppAlert.showErrorSnackBar(context: context, message: msg);
      },
    );
  }
}
