import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:super_up/app/core/api_service/story/story_api_service.dart';
import 'package:super_up/app/core/models/story/story_model.dart';
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up/app/modules/story/view/story_view.dart';
import 'package:super_up/app/widgets/post_share_message_widget.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

/// Widget to display story reply messages in chat
class StoryReplyMessageWidget extends StatelessWidget {
  final bool isMeSender;
  final Map<String, dynamic> data;

  const StoryReplyMessageWidget({
    super.key,
    required this.isMeSender,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    // Extract story information from the data
    final storyType = data['storyType'] as String?;
    final storyContent = data['storyContent'] as String?;
    final storyCaption = data['storyCaption'] as String?;
    final replyText = data['replyText'] as String?;
    final backgroundColor = data['backgroundColor'] as String?;
    final textColor = data['textColor'] as String?;
    final storyAtt = data['storyAtt'] as Map<String, dynamic>?;
    final isPostShare = _isPostShareStory(storyAtt);

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Story preview container
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMeSender
                  ? Colors.black.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Replied to story" header
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.reply,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Replied to story',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Story content preview
                isPostShare
                    ? _buildStoryPreview(
                        context,
                        storyType,
                        storyContent,
                        storyCaption,
                        backgroundColor,
                        textColor,
                        storyAtt,
                      )
                    : GestureDetector(
                        onTap: () {
                          _openStory(context);
                        },
                        child: _buildStoryPreview(
                          context,
                          storyType,
                          storyContent,
                          storyCaption,
                          backgroundColor,
                          textColor,
                          storyAtt,
                        ),
                      ),
              ],
            ),
          ),

          // Reply text
          if (replyText != null && replyText.isNotEmpty)
            Text(
              replyText,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaWidget(
    String? imageUrl,
    String? networkUrl,
    String? filePath,
    String? storyType,
    String? thumbUrl,
    Map<String, dynamic>? thumbImage,
  ) {
    // For videos prefer the provided thumbnail first.
    String? displayUrl;
    if (storyType == 'video') {
      // 1) Prefer server-provided thumbUrl (works for both sender and receiver)
      if (thumbUrl != null && thumbUrl.isNotEmpty) {
        // Debug
        print('[StoryReplyMessageWidget] Using thumbUrl: ' + thumbUrl);
        displayUrl = thumbUrl;
      } else if (thumbImage != null &&
          (thumbImage['url'] != null && (thumbImage['url'] as String).isNotEmpty)) {
        displayUrl = thumbImage['url'] as String?;
      } else if (thumbImage != null &&
          (thumbImage['networkUrl'] != null &&
              (thumbImage['networkUrl'] as String).isNotEmpty)) {
        // 2) If thumbImage has networkUrl, use it
        displayUrl = thumbImage['networkUrl'] as String?;
        print('[StoryReplyMessageWidget] Using thumbImage.networkUrl: ' +
            (displayUrl ?? 'null'));
      } else if (thumbImage != null &&
          (thumbImage['filePath'] != null &&
              (thumbImage['filePath'] as String).isNotEmpty)) {
        // 3) Fallback to local file path (sender device)
        final localPath = thumbImage['filePath'] as String;
        print('[StoryReplyMessageWidget] Using local thumb file: ' + localPath);
        return SizedBox(
          width: 256,
          height: 80,
          child: VPlatformCacheImageWidget(
            source: VPlatformFile.fromPath(fileLocalPath: localPath),
            size: const Size(256, 80),
            fit: BoxFit.cover,
          ),
        );
      } else {
        final rawVideoUrl = (networkUrl ?? imageUrl) ?? '';
        displayUrl = _buildCloudinaryVideoThumbnailUrl(rawVideoUrl);
      }
    } else {
      // Priority: networkUrl > imageUrl > filePath for images
      displayUrl = networkUrl ?? imageUrl;
    }

    if (displayUrl != null && displayUrl.isNotEmpty) {
      String fullUrl = displayUrl;
      if (!displayUrl.startsWith('http')) {
        fullUrl = '${SConstants.baseMediaUrl}$displayUrl';
      }
      return SizedBox(
        width: 256,
        height: 80,
        child: Image.network(
          fullUrl,
          width: 256,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(storyType);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildPlaceholder(storyType);
          },
        ),
      );
    } else if (filePath != null && filePath.isNotEmpty) {
      if (filePath.startsWith('/')) {
        // Local file image
        return SizedBox(
          width: 256,
          height: 80,
          child: VPlatformCacheImageWidget(
            source: VPlatformFile.fromPath(fileLocalPath: filePath),
            size: const Size(256, 80),
            fit: BoxFit.cover,
          ),
        );
      } else {
        return SizedBox(
          width: 256,
          height: 80,
          child: Image.asset(
            filePath,
            width: 256,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholder(storyType);
            },
          ),
        );
      }
    } else {
      return _buildPlaceholder(storyType);
    }
  }

  String? _buildCloudinaryVideoThumbnailUrl(String rawUrl) {
    try {
      if (rawUrl.isEmpty) return null;
      final fullUrl = rawUrl.startsWith('http')
          ? rawUrl
          : '${SConstants.baseMediaUrl}$rawUrl';
      final u = Uri.parse(fullUrl);
      if (!u.host.contains('res.cloudinary.com')) return null;
      final path = u.path;
      final idx = path.indexOf('/upload/');
      if (idx == -1) return null;

      final prefix = '${u.scheme}://${u.host}${path.substring(0, idx + '/upload/'.length)}';
      final tail = path.substring(idx + '/upload/'.length).replaceFirst(RegExp(r'^/+'), '');
      final jpgTail = tail.replaceAll(RegExp(r'\.[^./]+$'), '.jpg');
      const transform = 'so_1,w_640,h_360,c_fill,f_jpg';
      return '$prefix$transform/$jpgTail';
    } catch (_) {
      return null;
    }
  }

  Widget _buildPlaceholder(String? storyType) {
    return SizedBox(
      width: 256,
      height: 80,
      child: Container(
        width: 256,
        height: 80,
        color: Colors.grey[400],
        child: Icon(
          storyType == 'video' ? CupertinoIcons.play_circle : CupertinoIcons.photo,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildStoryPreview(
    BuildContext context,
    String? storyType,
    String? storyContent,
    String? storyCaption,
    String? backgroundColor,
    String? textColor,
    Map<String, dynamic>? storyAtt,
  ) {
    if (_isPostShareStory(storyAtt)) {
      return PostShareMessageWidget(
        isMeSender: isMeSender,
        data: _toPostShareData(storyAtt, storyCaption, storyContent),
      );
    }

    if (storyType == 'text') {
      // Text story preview
      return Container(
        height: 80,
        width: 256,
        decoration: BoxDecoration(
          color: backgroundColor != null
              ? _parseColor(backgroundColor)
              : Colors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            storyContent ?? '',
            style: TextStyle(
              color: textColor != null ? _parseColor(textColor) : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    } else if (storyType == 'image' || storyType == 'video') {
      // Media story preview
      final imageUrl = storyAtt?['url'] as String?;
      final networkUrl = storyAtt?['networkUrl'] as String?;
      final filePath = storyAtt?['filePath'] as String?;
      final thumbUrl = storyAtt?['thumbUrl'] as String?;
      final thumbImage = storyAtt?['thumbImage'] as Map<String, dynamic>?;

      return Container(
        height: 80,
        width: 256,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Story image/video thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildMediaWidget(
                imageUrl,
                networkUrl,
                filePath,
                storyType,
                thumbUrl,
                thumbImage,
              ),
            ),

            // Video play icon overlay
            if (storyType == 'video')
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.play_fill,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),

            // Caption overlay if exists
            if (storyCaption != null && storyCaption.isNotEmpty)
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    storyCaption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      );
    } else if (storyType == 'voice') {
      return Container(
        height: 80,
        width: 256,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(
              CupertinoIcons.mic,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                (storyCaption ?? storyContent ?? '').toString().isEmpty
                    ? 'Voice story'
                    : (storyCaption ?? storyContent ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      );
    }

    // Fallback for unknown story types
    return Container(
      height: 80,
      width: 256,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          CupertinoIcons.doc_text,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      // Remove # if present and parse hex color
      final hexColor = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      // Return default color if parsing fails
      return Colors.blue;
    }
  }

  bool _isPostShareStory(Map<String, dynamic>? storyAtt) {
    final postId = (storyAtt?['postId'] ?? '').toString();
    return postId.isNotEmpty;
  }

  Map<String, dynamic> _toPostShareData(
    Map<String, dynamic>? storyAtt,
    String? storyCaption,
    String? storyContent,
  ) {
    final att = storyAtt ?? const <String, dynamic>{};
    return <String, dynamic>{
      'postId': (att['postId'] ?? '').toString(),
      'caption': (att['caption'] ?? storyCaption ?? storyContent ?? '').toString(),
      'authorName': (att['authorName'] ?? '').toString(),
      'authorImage': (att['authorImage'] ?? '').toString(),
      'authorId': (att['authorId'] ?? '').toString(),
      'mediaUrl': (att['mediaUrl'] ?? att['url'] ?? '').toString(),
      'thumbnailUrl': (att['thumbnailUrl'] ?? att['thumbUrl'] ?? '').toString(),
      'postType': (att['postType'] ?? 'image').toString(),
      'placeName': (att['placeName'] ?? '').toString(),
      'address': (att['address'] ?? '').toString(),
      'latitude': (att['latitude'] ?? '').toString(),
      'longitude': (att['longitude'] ?? '').toString(),
    };
  }

  void _openStory(BuildContext context) async {
    try {
      final storyId = data['storyId'] as String?;
      if (storyId == null || storyId.isEmpty) return;

      final userStoryModel = await _fetchStoryWithUserInfo(storyId);
      if (userStoryModel != null) {
        context.toPage(
          StoryViewpage(
            userStoryModels: [userStoryModel],
            onComplete: (current) {},
            onDelete: null,
          ),
        );
        return;
      }

      final fallbackModel = _createUserStoryModelFromData();
      if (fallbackModel != null) {
        context.toPage(
          StoryViewpage(
            userStoryModels: [fallbackModel],
            onComplete: (current) {},
            onDelete: null,
          ),
        );
      }
    } catch (_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Story'),
          content: const Text('This story may no longer be available.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
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

  UserStoryModel? _createUserStoryModelFromData() {
    try {
      final storyId = data['storyId'] as String?;
      final storyType = data['storyType'] as String?;
      final storyContent = data['storyContent'] as String?;
      final storyCaption = data['storyCaption'] as String?;
      final storyAtt = data['storyAtt'] as Map<String, dynamic>?;

      if (storyId == null || storyId.isEmpty) return null;
      if (storyType == null || storyType.isEmpty) return null;

      final storyUserId = isMeSender ? 'story_author' : AppAuth.myId;
      final storyUserName = isMeSender ? 'Story Author' : 'You';
      final storyUserImage = 'default_user_image.png';

      final storyModel = StoryModel(
        id: storyId,
        userId: storyUserId,
        content: storyContent ?? '',
        backgroundColor: null,
        caption: storyCaption,
        storyType: _parseStoryType(storyType),
        att: storyAtt,
        expireAt: DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        fontType: StoryFontType.normal,
        viewedByMe: false,
      );

      final userData = SBaseUser(
        id: storyUserId,
        fullName: storyUserName,
        userImage: storyUserImage,
      );

      return UserStoryModel(
        userData: userData,
        stories: [storyModel],
      );
    } catch (_) {
      return null;
    }
  }

  StoryType _parseStoryType(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return StoryType.image;
      case 'video':
        return StoryType.video;
      case 'text':
        return StoryType.text;
      case 'voice':
        return StoryType.voice;
      case 'file':
        return StoryType.file;
      default:
        return StoryType.unknown;
    }
  }
}
