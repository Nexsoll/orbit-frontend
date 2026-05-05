// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/modules/chat_settings/chat_media_docs_voice/controllers/chat_media_controller.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class ChatMediaView extends StatefulWidget {
  const ChatMediaView({super.key, required this.roomId});
  final String roomId;

  @override
  State<ChatMediaView> createState() => _ChatMediaViewState();
}

class _ChatMediaViewState extends State<ChatMediaView> {
  late final ChatMediaController controller;

  @override
  void initState() {
    super.initState();
    controller = ChatMediaController(widget.roomId);
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  int sharedValue = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Row(
            children: [
              Icon(CupertinoIcons.chevron_back, color: Color(0xFFB48648)),
            ],
          ),
        ),
        middle: const Text('Media, Docs, Links'),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: CupertinoSegmentedControl<int>(
                children: <int, Widget>{
                  0: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      S.current.media,
                      style: TextStyle(
                        color: sharedValue == 0 ? CupertinoColors.white : const Color(0xFFB48648),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  1: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      S.current.docs,
                      style: TextStyle(
                        color: sharedValue == 1 ? CupertinoColors.white : const Color(0xFFB48648),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  2: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      S.current.links,
                      style: TextStyle(
                        color: sharedValue == 2 ? CupertinoColors.white : const Color(0xFFB48648),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                },
                onValueChanged: (int val) {
                  setState(() {
                    sharedValue = val;
                  });
                },
                groupValue: sharedValue,
                selectedColor: const Color(0xFFB48648),
                unselectedColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                borderColor: const Color(0xFFB48648),
                pressedColor: const Color(0xFFB48648).withOpacity(0.15),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, child) => VAsyncWidgetsBuilder(
                  loadingState: controller.loadingState,
                  successWidget: () {
                    if (sharedValue == 0) {
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 30),
                        itemCount: controller.data.media.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10.0,
                          mainAxisSpacing: 10.0,
                          childAspectRatio: 1.0,
                        ),
                        itemBuilder: (context, index) {
                          final item = controller.data.media[index];
                          return _GridMediaItem(
                            message: item,
                            onTap: () => _openMediaViewer(context, index),
                          );
                        },
                      );
                    } else if (sharedValue == 1) {
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 30),
                        itemBuilder: (context, index) {
                          return FileMessageItem(
                            message: controller.data.files[index] as VFileMessage,
                            backgroundColor: controller.data.files[index].isMeSender
                                ? context.vMessageTheme.senderBubbleColor
                                : context.vMessageTheme.receiverBubbleColor,
                          );
                        },
                        separatorBuilder: (context, index) => const Divider(color: Colors.grey),
                        itemCount: controller.data.files.length,
                      );
                    } else {
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 30),
                        itemBuilder: (context, index) {
                          return LinkViewerWidget(
                            data: controller.data.links[index].linkAtt,
                            isMeSender: controller.data.links[index].isMeSender,
                          );
                        },
                        separatorBuilder: (context, index) => const Divider(color: Colors.grey),
                        itemCount: controller.data.links.length,
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMediaViewer(BuildContext context, int index) {
    final mediaMessages = controller.data.media
        .where((m) => m.messageType.isImage || m.messageType.isVideo)
        .toList();
    final currentIndex = mediaMessages.indexWhere((m) => m.id == controller.data.media[index].id);
    
    if (mediaMessages.isEmpty) return;

    final initialIndex = currentIndex >= 0 ? currentIndex : 0;
    final firstMessage = mediaMessages[initialIndex];

    if (firstMessage.messageType.isImage) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VMediaViewerPage(
            mediaMessages: mediaMessages,
            initialIndex: initialIndex,
            downloadingLabel: S.of(context).downloading,
            successfullyDownloadedInLabel: S.of(context).successfullyDownloadedIn,
            showDownload: true,
          ),
        ),
      );
    } else {
      final msg = firstMessage as VVideoMessage;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VVideoPlayer(
            platformFileSource: msg.data.fileSource,
            downloadingLabel: S.of(context).downloading,
            successfullyDownloadedInLabel: S.of(context).successfullyDownloadedIn,
            showDownload: true,
          ),
        ),
      );
    }
  }
}

class _GridMediaItem extends StatelessWidget {
  final VBaseMessage message;
  final VoidCallback onTap;

  const _GridMediaItem({
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.grey.shade300,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (message.messageType.isImage)
                _buildImage(message as VImageMessage)
              else if (message.messageType.isVideo)
                _buildVideo(message as VVideoMessage),
              if (message.messageType.isVideo)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(VImageMessage msg) {
    return VPlatformCacheImageWidget(
      source: msg.data.fileSource,
      fit: BoxFit.cover,
    );
  }

  Widget _buildVideo(VVideoMessage msg) {
    final thumb = msg.data.thumbImage;
    if (thumb != null) {
      return VPlatformCacheImageWidget(
        source: thumb.fileSource,
        fit: BoxFit.cover,
      );
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.white, size: 30),
      ),
    );
  }
}
