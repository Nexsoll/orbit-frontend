import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/api_service/story/story_api_service.dart';
import 'package:super_up/app/core/models/story/story_model.dart';
import 'package:super_up/app/modules/story/view/story_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class StoryShareMessageWidget extends StatelessWidget {
  final bool isMeSender;
  final Map<String, dynamic> data;

  const StoryShareMessageWidget({
    super.key,
    required this.isMeSender,
    required this.data,
  });

  String get _title =>
      (data['title'] ?? data['caption'] ?? 'Shared story').toString();

  String get _mediaUrl => (data['mediaUrl'] ?? '').toString();

  String get _thumbnailUrl => (data['thumbnailUrl'] ?? '').toString();

  String get _mediaType => (data['mediaType'] ?? '').toString().toLowerCase();

  String get _link => (data['link'] ?? '').toString();

  String get _storyId => (data['storyId'] ?? data['id'] ?? '').toString();

  String get _uploaderName =>
      (data['uploaderName'] ?? data['userName'] ?? '').toString();

  String get _uploaderImage =>
      (data['uploaderImage'] ?? data['userImage'] ?? '').toString();

  String get _uploaderId => (data['uploaderId'] ?? data['userId'] ?? '').toString();

  bool get _isVideo => _mediaType == 'video' || _mediaUrl.toLowerCase().contains('.mp4');

  String _fullUrl(String raw) {
    if (raw.isEmpty) return raw;
    return raw.startsWith('http') ? raw : SConstants.baseMediaUrl + raw;
  }

  Future<void> _openStory(BuildContext context) async {
    final id = _storyId;
    if (id.isNotEmpty) {
      try {
        final userStoryModel = await _fetchStoryWithUserInfo(id);
        if (userStoryModel != null && context.mounted) {
          context.toPage(
            StoryViewpage(
              userStoryModels: [userStoryModel],
              onComplete: (current) {},
              onDelete: null,
            ),
          );
          return;
        }
      } catch (e) {
        if (context.mounted) {
          VAppAlert.showErrorSnackBar(context: context, message: e.toString());
        }
      }
    }

    if (_link.isNotEmpty) {
      await VStringUtils.lunchLink(_link);
    }
  }

  Future<UserStoryModel?> _fetchStoryWithUserInfo(String storyId) async {
    try {
      final storyService = StoryApiService.init();

      final myStories = await storyService.getMyStories();
      if (myStories != null) {
        for (final story in myStories.stories) {
          if (story.id == storyId) {
            return UserStoryModel(
              userData: myStories.userData,
              stories: [story],
            );
          }
        }
      }

      for (int page = 1; page <= 3; page++) {
        final allUserStories = await storyService.getUsersStories(page: page);
        for (final userStory in allUserStories) {
          for (final story in userStory.stories) {
            if (story.id == storyId) {
              return UserStoryModel(
                userData: userStory.userData,
                stories: [story],
              );
            }
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openUploaderChat(BuildContext context) async {
    if (_uploaderId.isEmpty) return;
    try {
      await VChatController.I.roomApi.openChatWith(peerId: _uploaderId);
    } catch (e) {
      if (context.mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _title;
    final thumb = _fullUrl(_thumbnailUrl);
    final uploaderName = _uploaderName;
    final uploaderImg = _fullUrl(_uploaderImage);

    final icon = _isVideo ? CupertinoIcons.play_rectangle : CupertinoIcons.photo;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openStory(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: const Color(0xFFB48648).withOpacity(0.12),
                    child: thumb.isNotEmpty
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.network(
                                thumb,
                                fit: BoxFit.cover,
                                width: 56,
                                height: 56,
                                errorBuilder: (c, e, s) => Icon(
                                  icon,
                                  color: const Color(0xFFB48648),
                                  size: 26,
                                ),
                              ),
                              if (_isVideo)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.play_fill,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                            ],
                          )
                        : Icon(
                            icon,
                            color: const Color(0xFFB48648),
                            size: 26,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.photo_on_rectangle,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Story',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (uploaderImg.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.network(
                                uploaderImg,
                                width: 18,
                                height: 18,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(
                                  CupertinoIcons.person_alt_circle,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              CupertinoIcons.person_alt_circle,
                              size: 18,
                              color: Colors.grey,
                            ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              uploaderName.isEmpty ? 'Shared story' : uploaderName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFB48648),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to view story',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            if (!isMeSender && _uploaderId.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _openUploaderChat(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB48648).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFB48648).withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Chat with uploader',
                    style: TextStyle(
                      color: Color(0xFFB48648),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
