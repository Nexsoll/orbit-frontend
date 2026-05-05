import 'package:dashed_circle/dashed_circle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/models/story/story_model.dart';
import 'package:super_up/app/core/services/user_verification_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:s_translation/generated/l10n.dart';

class StoryWidget extends StatelessWidget {
  final UserStoryModel storyModel;
  final Function(UserStoryModel storyModel) onTap;
  final Function(UserStoryModel storyModel) onLongTap;
  final VoidCallback? toCreateStory;
  final bool isMe;
  final bool isLoading;
  final bool isViewed;

  const StoryWidget({
    super.key,
    required this.storyModel,
    required this.onTap,
    required this.onLongTap,
    this.toCreateStory,
    this.isMe = false,
    this.isLoading = false,
    this.isViewed = false,
  });

  @override
  Widget build(BuildContext context) {
    final verificationService = GetIt.I.get<UserVerificationService>();
    final isVerified = !isMe && verificationService.isUserVerifiedSync(storyModel.userData.id);
    
    return ListTile(
      onLongPress: () {
        onLongTap(storyModel);
      },
      onTap: () {
        onTap(storyModel);
      },
      dense: false,
      contentPadding: const EdgeInsets.all(0),
      leading: Stack(
        children: [
          DashedCircle(
            dashes: storyModel.stories.length,
            color:
                isMe ? Colors.green : (isViewed ? Colors.grey : Colors.green),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: isLoading
                  ? const CupertinoActivityIndicator(
                      radius: 15,
                    )
                  : VCircleAvatar(
                      radius: 25,
                      vFileSource: VPlatformFile.fromUrl(
                        networkUrl: storyModel.userData.userImage,
                      ),
                    ),
            ),
          ),
          if (isMe && !isLoading)
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: InkWell(
                onTap: toCreateStory,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            )
        ],
      ),
      title: isMe
          ? Text(
              storyModel.userData.fullName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            )
          : SUserNameWithBadge(
              fullName: storyModel.userData.fullName,
              isVerified: isVerified,
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
              badgeSize: 16.0,
            ),
      subtitle: isMe
          ? Text(
              S.of(context).addNewStory,
              style: const TextStyle(
                fontSize: 12,
              ),
            )
          : Text(
              format(
                DateTime.parse(storyModel.stories.last.createdAt).toLocal(),
                locale: Localizations.localeOf(context).languageCode,
              ),
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
    );
  }
}
