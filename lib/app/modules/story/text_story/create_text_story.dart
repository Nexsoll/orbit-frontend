import 'dart:math';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/core/api_service/story/story_api_service.dart';
import 'package:super_up/app/core/models/story/create_story_dto.dart';
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up/app/core/services/story_status_service.dart';
import 'package:super_up_core/super_up_core.dart';

import '../story_privacy/story_privacy_selection_screen.dart';
import '../../../modules/social/controllers/social_story_tab_controller.dart';

class _CreateStoryState {
  Color backgroundColor = const Color(0xFFA68888);
  StoryFontType fontType = StoryFontType.normal;
}

class CreateTextStory extends StatefulWidget {
  final String storySource;
  const CreateTextStory({super.key, this.storySource = 'main'});

  @override
  State<CreateTextStory> createState() => _CreateTextStoryState();
}

class _CreateTextStoryState extends State<CreateTextStory> {
  final state = _CreateStoryState();
  final random = Random();

  final _api = GetIt.I.get<StoryApiService>();
  final _storyStatusService = GetIt.I.get<StoryStatusService>();
  final _txtController = TextEditingController();
  final _focusNode = FocusNode();

  StoryPrivacy _storyPrivacy = StoryPrivacy.public;
  List<String>? _selectedUserIds;
  List<String>? _excludedUserIds;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    super.dispose();
    _focusNode.dispose();
    _txtController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: state.backgroundColor,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ListTile(
              dense: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              leading: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: const Icon(
                  CupertinoIcons.clear,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _generateRandomColor,
                    child: const Icon(
                      Icons.color_lens,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  InkWell(
                    onTap: _randomFontType,
                    child: const Icon(
                      CupertinoIcons.f_cursive,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: CupertinoTextField(
                  controller: _txtController,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  maxLines: 7,
                  minLines: 1,
                  maxLength: 200,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 35,
                    fontStyle: state.fontType == StoryFontType.italic
                        ? FontStyle.italic
                        : null,
                    textBaseline: TextBaseline.alphabetic,
                    fontWeight: state.fontType == StoryFontType.bold
                        ? FontWeight.bold
                        : null,
                  ),
                  cursorColor: Colors.white,
                  placeholderStyle: const TextStyle(
                    color: Colors.grey,
                    fontSize: 35,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    border: Border(),
                  ),
                  placeholder: S.of(context).createYourStory,
                ),
              ),
            ),
            Container(
              color: Colors.black.withOpacity(.5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      S.of(context).shareYourStatus,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
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
                  // Send Button
                  GestureDetector(
                    onTap: uploadTextStory,
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
            )
          ],
        ),
      ),
    );
  }

  void _generateRandomColor() {
    final color = Color.fromRGBO(
      random.nextInt(256),
      256,
      random.nextInt(256),
      1,
    );
    state.backgroundColor = color;
    setState(() {});
  }

  void _randomFontType() {
    state.fontType =
        StoryFontType.values[random.nextInt(StoryFontType.values.length)];
    setState(() {});
  }

  void _showPrivacySelection() async {
    print('Privacy button tapped!'); // Debug print
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => StoryPrivacySelectionScreen(
          onPrivacySelected: (privacy, selectedUserIds, excludedUserIds) {
            print(
                'Privacy selected: $privacy, selected: $selectedUserIds, excluded: $excludedUserIds'); // Debug print
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

  void uploadTextStory() async {
    if (_txtController.text.isEmpty) return;

    // Debug: Print the story data being sent
    print('Creating story with privacy: $_storyPrivacy');
    print('Selected users: $_selectedUserIds');

    await vSafeApiCall(
      onLoading: () {
        VAppAlert.showLoading(context: context);
      },
      request: () async {
        final dto = CreateStoryDto(
          storyType: StoryType.text,
          content: _txtController.text,
          backgroundColor: state.backgroundColor.value.toRadixString(16),
          storyFontType: state.fontType,
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
