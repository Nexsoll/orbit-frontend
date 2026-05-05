// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import '../../../../../v_chat_v2/translations.dart';
import '../../../../core/app_config/app_config_controller.dart';
import '../controllers/chat_star_messages_controller.dart';

class ChatStarMessagesPage extends StatefulWidget {
  final String? roomId;

  const ChatStarMessagesPage({
    super.key,
    this.roomId,
  });

  @override
  State<ChatStarMessagesPage> createState() => _ChatStarMessagesPageState();
}

class _ChatStarMessagesPageState extends State<ChatStarMessagesPage> {
  late final ChatStarMessagesController controller;

  @override
  void initState() {
    super.initState();
    controller = ChatStarMessagesController(widget.roomId);
    controller.onInit();
    AdsBannerWidget.loadAd(
      VPlatforms.isAndroid
          ? SConstants.androidInterstitialId
          : SConstants.iosInterstitialId,
      enableAds: VAppConfigController.appConfig.enableAds,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: context.vMessageTheme.scaffoldDecoration,
      child: CupertinoPageScaffold(
        backgroundColor: Colors.transparent,
        navigationBar: CupertinoNavigationBar(
          transitionBetweenRoutes: false, // 👈 disables Hero animation
          leading: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(CupertinoIcons.chevron_back, color: Color(0xFFB48648)),
            ),
          ),
          middle: Text(S.of(context).starMessage),
        ),
        child: SafeArea(
          bottom: false,
          child: ValueListenableBuilder<SLoadingState<List<VBaseMessage>>>(
            valueListenable: controller,
            builder: (_, data, ___) => VAsyncWidgetsBuilder(
              loadingState: data.loadingState,
              onRefresh: controller.getData,
              successWidget: () {
                final value = data.data;
                return Scrollbar(
                  interactive: true,
                  thickness: 5,
                  controller: controller.scrollController,
                  child: ListView.separated(
                    separatorBuilder: (context, index) => SizedBox(
                      height: VPlatforms.isWeb ? 12 : 10,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    controller: controller.scrollController,
                    // key: const PageStorageKey("VListViewItems"),
                    cacheExtent: 300,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final message = value[index];
                      final language = vMessageLocalizationPageModel(
                        context,
                      );
                      return Builder(
                        key: UniqueKey(),
                        builder: (context) {
                          // Determine theme brightness to style name text appropriately
                          final bool isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          if (message.isDeleted) {
                            return const SizedBox.shrink();
                          }
                          final isMyMessage = message.isMeSender;
                          final msgItem = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Sender info row
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Row(
                                  mainAxisAlignment: isMyMessage 
                                      ? MainAxisAlignment.end 
                                      : MainAxisAlignment.start,
                                  children: [
                                    if (!isMyMessage) ...[
                                      // Profile picture for other users
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey[300],
                                        ),
                                        child: ClipOval(
                                          child: VCircleAvatar(
                                            vFileSource: VPlatformFile.fromUrl(
                                              networkUrl: message.senderImageThumb,
                                            ),
                                            radius: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    // Sender name
                                    Text(
                                      isMyMessage ? 'You' : message.senderName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (isMyMessage) ...[
                                      const SizedBox(width: 8),
                                      // Profile picture for current user
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey[300],
                                        ),
                                        child: ClipOval(
                                          child: VCircleAvatar(
                                            vFileSource: VPlatformFile.fromUrl(
                                              networkUrl: message.senderImageThumb,
                                            ),
                                            radius: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Message item
                              VMessageItem(
                                language: language,
                                onLongTap: (message) =>
                                    controller.onLongTab(context, message),
                                roomType: VRoomType.s,
                                message: message,
                                voiceController: (message) {
                                  if (message is VVoiceMessage) {
                                    return controller.voiceControllers
                                        .getVoiceController(message);
                                  }
                                  return null;
                                },
                              ),
                            ],
                          );

                          final isTopMessage =
                              _isTopMessage(value.length, index);
                          final dividerDate = _getDateDiff(
                            bigDate: message.createdAtDate,
                            smallDate: isTopMessage
                                ? value[index].createdAtDate
                                : value[index + 1].createdAtDate,
                          );
                          if (dividerDate != null || isTopMessage) {
                            //set date divider
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DateDividerItem(
                                  dateTime:
                                      dividerDate ?? message.createdAtDate,
                                  today: language.today,
                                  yesterday: language.yesterday,
                                ),
                                msgItem,
                              ],
                            );
                          }
                          return msgItem;
                        },
                      );
                    },
                    itemCount: value.length,
                    // reverse: true,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  bool _isTopMessage(int listLength, int index) {
    return listLength - 1 == index;
  }

  DateTime? _getDateDiff({
    required DateTime bigDate,
    required DateTime smallDate,
  }) {
    final difference = bigDate.difference(smallDate);
    if (difference.isNegative) {
      return null;
    }
    if (difference.inHours < 24) {
      final d1 = bigDate.day;
      final d2 = smallDate.day;
      if (d1 == d2) {
        return null;
      } else {
        return bigDate;
      }
    }
    return bigDate;
  }
}
