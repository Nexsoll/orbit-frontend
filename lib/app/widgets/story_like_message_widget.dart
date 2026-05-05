import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:super_up/app/core/models/story/story_model.dart';
import 'package:super_up/app/modules/story/view/story_view.dart';
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up/app/core/api_service/story/story_api_service.dart';
import 'package:super_up/app/widgets/post_share_message_widget.dart';

/// Widget to display story like messages in chat
class StoryLikeMessageWidget extends StatelessWidget {
  final bool isMeSender;
  final Map<String, dynamic> data;
  final Map<String, dynamic>? messageData;

  const StoryLikeMessageWidget({
    super.key,
    required this.isMeSender,
    required this.data,
    this.messageData,
  });

  @override
  Widget build(BuildContext context) {
    // Debug: Print all available data keys to understand the structure
    print('StoryLikeMessageWidget data keys: ${data.keys.toList()}');
    print('StoryLikeMessageWidget full data: $data');
    
    // Extract story information from the data
    final storyType = data['storyType'] as String?;
    final storyContent = data['storyContent'] as String?;
    final storyCaption = data['storyCaption'] as String?;
    final backgroundColor = data['backgroundColor'] as String?;
    final textColor = data['textColor'] as String?;
    final storyAtt = data['storyAtt'] as Map<String, dynamic>?;
    final isPostShare = _isPostShareStory(storyAtt);
    final emoji =
        data['emoji'] as String? ?? '❤️'; // Default to heart if no emoji

    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Story preview container
          Container(
            width: 280,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMeSender
                  ? Colors.black.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Story content preview
                isPostShare
                    ? _buildStoryPreview(context, storyType, storyContent,
                        storyCaption, backgroundColor, textColor, storyAtt)
                    : GestureDetector(
                        onTap: () {
                          print('GestureDetector onTap triggered!');
                          _openStory(context);
                        },
                        child: _buildStoryPreview(context, storyType, storyContent,
                            storyCaption, backgroundColor, textColor, storyAtt),
                      ),
                const SizedBox(height: 8),
                // "Reacted to your story" header
                Row(
                  children: [
                    Text(
                      emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reacted to story',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
                      color: Colors.black.withValues(alpha: 0.5),
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
                    color: Colors.black.withValues(alpha: 0.6),
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
          color: Colors.black.withValues(alpha: 0.8),
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

  Widget _buildMediaWidget(
    String? imageUrl,
    String? networkUrl,
    String? filePath,
    String? storyType,
    String? thumbUrl,
    Map<String, dynamic>? thumbImage,
  ) {
    // For videos prefer: thumbImage(VPlatformFile) -> thumbUrl. Avoid mp4 images.
    String? displayUrl;
    if (storyType == 'video') {
      // Prefer server/network thumbnails to avoid missing local files on receivers
      if (thumbUrl != null && thumbUrl.isNotEmpty) {
        displayUrl = thumbUrl;
      } else if (thumbImage != null &&
          thumbImage['url'] != null &&
          (thumbImage['url'] as String).isNotEmpty) {
        displayUrl = thumbImage['url'] as String?;
      } else if (thumbImage != null &&
          thumbImage['networkUrl'] != null &&
          (thumbImage['networkUrl'] as String).isNotEmpty) {
        displayUrl = thumbImage['networkUrl'] as String?;
      } else if (thumbImage != null &&
          thumbImage['filePath'] != null &&
          (thumbImage['filePath'] as String).isNotEmpty) {
        final localPath = thumbImage['filePath'] as String;
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
      // For images: networkUrl > imageUrl > filePath
      displayUrl = networkUrl ?? imageUrl;
    }
    
    if (displayUrl != null && displayUrl.isNotEmpty) {
      // Construct full URL if it's a relative path
      String fullUrl = displayUrl;
      if (!displayUrl.startsWith('http')) {
        fullUrl = '${SConstants.baseMediaUrl}$displayUrl';
      }
      
      // Network image
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
      // Local file - try both asset and file approaches
      if (filePath.startsWith('/')) {
        // Absolute file path - use platform-aware image loader
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
        // Asset path
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
      // No image available, show placeholder
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
          storyType == 'video'
              ? CupertinoIcons.play_circle
              : CupertinoIcons.photo,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  void _openStory(BuildContext context) async {
    print('=== STORY THUMBNAIL CLICKED ===');
    print('Story click data: $data');
    
    try {
      final storyId = data['storyId'] as String?;
      print('Story ID: $storyId');
      
      if (storyId == null) {
        print('Story ID is null, returning');
        return;
      }

      // Fetch the actual story with user information from API
      final userStoryModel = await _fetchStoryWithUserInfo(storyId);
      print('Fetched UserStoryModel: ${userStoryModel?.userData.fullName}');
      
      if (userStoryModel != null) {
        print('Navigating to StoryViewpage');
        context.toPage(
          StoryViewpage(
            userStoryModels: [userStoryModel],
            onComplete: (current) {},
            onDelete: null,
          ),
        );
      } else {
        print('UserStoryModel is null, using fallback');
        // Fallback to the old method if API fails
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
      }
      
    } catch (e) {
      print('Error in _openStory: $e');
      // Fallback - just show a simple dialog since ScaffoldMessenger isn't available
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Story'),
          content: Text('This story may no longer be available.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
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
      
      return null; // Story not found
    } catch (e) {
      print('Error fetching story: $e');
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
      
      // Since this is a story reaction message, the story author info isn't in the data
      // We need to fetch it or use the reaction sender as a fallback
      // For now, we'll show "You" if it's the current user's story, otherwise show a generic name
      final isMyStory = !isMeSender; // If someone reacted to my story, it's my story
      final storyUserId = isMyStory ? AppAuth.myId : 'story_author';
      final storyUserName = isMyStory ? 'You' : 'Story Author';
      final storyUserImage = 'default_user_image.png';
      
      if (storyId == null || storyType == null) return null;

      // Create a mock story model with the available data
      final storyModel = StoryModel(
        id: storyId,
        userId: storyUserId,
        content: storyContent ?? '',
        backgroundColor: null,
        caption: storyCaption,
        storyType: _parseStoryType(storyType),
        att: storyAtt,
        expireAt: DateTime.now().add(Duration(hours: 24)).toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        fontType: StoryFontType.normal,
        viewedByMe: false,
      );

      // Create user data from the message data
      final userData = SBaseUser(
        id: storyUserId,
        fullName: storyUserName,
        userImage: storyUserImage,
      );

      return UserStoryModel(
        userData: userData,
        stories: [storyModel],
      );
    } catch (e) {
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
        return StoryType.image;
    }
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
}
