// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../controllers/live_stream_chat_controller.dart';
import '../../models/live_stream_model.dart';
import 'dart:developer';

class LiveStreamChat extends StatefulWidget {
  final String streamId;
  final VoidCallback onToggleChat;
  final bool isStreamer;

  const LiveStreamChat({
    super.key,
    required this.streamId,
    required this.onToggleChat,
    this.isStreamer = true,
  });

  @override
  State<LiveStreamChat> createState() => _LiveStreamChatState();
}

class _LiveStreamChatState extends State<LiveStreamChat> {
  late final LiveStreamChatController controller;
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = GetIt.I.get<LiveStreamChatController>();
    controller.initializeChat(widget.streamId);
  }

  String _formatGiftText(Map<String, dynamic> giftData) {
    final name = giftData['giftName']?.toString() ?? 'Gift';
    final price = giftData['giftPrice'];
    final currency = (giftData['currency']?.toString() ?? 'KES').toUpperCase();
    final symbol = currency == 'KES' ? 'KSh' : currency == 'USD' ? '\$' : currency;
    if (price == null) return name;
    return '$name ($symbol${price.toString()})';
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    // Don't dispose the singleton controller, just reset its state
    controller.resetController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log('-----chech is streamer boolean what is this -------------${widget.isStreamer}');
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          // Pinned message
          ValueListenableBuilder<LiveStreamMessageModel?>(
            valueListenable: controller.pinnedMessage,
            builder: (context, pinnedMessage, child) {
              if (pinnedMessage == null) return const SizedBox.shrink();

              return _buildPinnedMessage(pinnedMessage);
            },
          ),

          // Chat messages
          Expanded(
            child: ValueListenableBuilder<List<LiveStreamMessageModel>>(
              valueListenable: controller.messages,
              builder: (context, messages, child) {
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageItem(message);
                  },
                );
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Message input field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: CupertinoTextField(
                      controller: messageController,
                      placeholder: 'Say something...',
                      placeholderStyle: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: const BoxDecoration(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      maxLines: 1,
                      onSubmitted: _sendMessage,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: () => _sendMessage(messageController.text),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.paperplane_fill,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Toggle chat button
                GestureDetector(
                  onTap: widget.onToggleChat,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.chevron_down,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedMessage(LiveStreamMessageModel message) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemYellow.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.systemYellow.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.pin_fill,
            color: CupertinoColors.systemYellow,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pinned Message',
                  style: const TextStyle(
                    color: CupertinoColors.systemYellow,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${message.userData.fullName}: ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: message.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.isStreamer)
            GestureDetector(
              onTap: () => _unpinMessage(message.id),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  CupertinoIcons.xmark,
                  color: Colors.white54,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(LiveStreamMessageModel message) {
    return GestureDetector(
      onLongPress: widget.isStreamer ? () => _showPinOptions(message) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Username and message
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${message.userData.fullName}: ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: message.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Gift display (if it's a gift message)
            if (message.messageType == 'gift' && message.giftData != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gift image
                    if (message.giftData!['giftImage'] != null)
                      Image.network(
                        message.giftData!['giftImage'],
                        width: 16,
                        height: 16,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            CupertinoIcons.gift,
                            color: Colors.amber,
                            size: 16,
                          );
                        },
                      ),
                    const SizedBox(width: 4),
                    // Gift name and price
                    Text(
                      _formatGiftText(message.giftData!),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
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

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    controller.sendMessage(text.trim());
    messageController.clear();

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showPinOptions(LiveStreamMessageModel message) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text('Message Options'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                _pinMessage(message.id);
              },
              child: const Text('Pin Message'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }

  void _pinMessage(String messageId) async {
    try {
      await controller.pinMessage(messageId);
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: const Text('Failed to pin message. Please try again.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  void _unpinMessage(String messageId) async {
    try {
      await controller.unpinMessage(messageId);
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: const Text('Failed to unpin message. Please try again.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }
}
