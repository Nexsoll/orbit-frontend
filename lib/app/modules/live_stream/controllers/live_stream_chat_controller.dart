// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import '../models/live_stream_model.dart';
import '../services/live_stream_api_service.dart';
import '../../../core/services/balance_service.dart';

class LiveStreamChatController extends ChangeNotifier {
  final LiveStreamApiService _apiService = GetIt.I.get<LiveStreamApiService>();

  String? currentStreamId;
  final ValueNotifier<List<LiveStreamMessageModel>> messages =
      ValueNotifier([]);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<LiveStreamMessageModel?> pinnedMessage =
      ValueNotifier(null);

  Timer? _refreshTimer;
  StreamSubscription? _socketSubscription;
  bool _isDisposed = false;

  void initializeChat(String streamId) {
    // Reset disposal flag when starting a new chat session
    _isDisposed = false;

    currentStreamId = streamId;
    _loadMessages();
    _loadPinnedMessage();
    _startAutoRefresh();
    _listenToSocketEvents();
  }

  void _startAutoRefresh() {
    // Refresh messages every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (currentStreamId != null && !isLoading.value) {
        _loadMessagesFromApi();
      }
    });
  }

  void _listenToSocketEvents() {
    // Listen for new message events from socket
    _socketSubscription =
        VChatController.I.nativeStreams.socketStatusStream.listen((event) {
      if (event.isConnected) {
        // Socket connected, refresh messages
        _loadMessagesFromApi();
        _loadPinnedMessage();
      }
    });

    // Listen for live stream specific events
    final socket = VChatController.I.nativeApi.remote.socketIo.socket;

    // Listen for new messages
    socket.on('new_stream_message', (data) {
      if (_isDisposed) return;

      try {
        final message = LiveStreamMessageModel.fromMap(data);
        if (message.streamId == currentStreamId) {
          addNewMessage(message);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error handling new stream message: $e');
        }
      }
    });

    // Listen for message pinned events
    socket.on('message_pinned', (data) {
      if (_isDisposed) return;

      try {
        final streamId = data['streamId'] as String?;
        if (streamId == currentStreamId) {
          final messageData = data['message'];
          final message = LiveStreamMessageModel.fromMap(messageData);
          if (!_isDisposed) {
            pinnedMessage.value = message;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error handling message pinned: $e');
        }
      }
    });

    // Listen for message unpinned events
    socket.on('message_unpinned', (data) {
      if (_isDisposed) return;

      try {
        final streamId = data['streamId'] as String?;
        if (streamId == currentStreamId && !_isDisposed) {
          pinnedMessage.value = null;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error handling message unpinned: $e');
        }
      }
    });

    // Listen for gift auto-claimed events (for hosts)
    socket.on('gift_auto_claimed', (data) {
      if (_isDisposed) return;

      try {
        final streamId = data['streamId'] as String?;
        final giftData = data['giftData'];
        final senderName = data['senderName'] as String?;
        final message = data['message'] as String?;

        if (streamId == currentStreamId) {
          // Show notification to host about received gift
          _showGiftReceivedNotification(giftData, senderName, message);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error handling gift auto-claimed: $e');
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    if (currentStreamId == null) return;

    try {
      // Try to load cached messages first
      final cachedData =
          VAppPref.getMap("api/live_stream_messages_$currentStreamId");
      if (cachedData != null) {
        final list = cachedData['data'] as List;
        messages.value =
            list.map((e) => LiveStreamMessageModel.fromMap(e)).toList();
      }
    } catch (err) {
      if (kDebugMode) {
        print('Error loading cached messages: $err');
      }
    }

    await _loadMessagesFromApi();
  }

  Future<void> _loadMessagesFromApi() async {
    if (currentStreamId == null || _isDisposed) return;

    try {
      final newMessages = await _apiService.getStreamMessages(
        streamId: currentStreamId!,
        page: 1,
        limit: 100,
      );

      if (_isDisposed) return;

      // Sort messages by creation time (newest first for API, but we want oldest first for display)
      newMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      messages.value = newMessages;

      // Cache the messages
      unawaited(VAppPref.setMap("api/live_stream_messages_$currentStreamId", {
        "data": newMessages.map((e) => e.toMap()).toList(),
      }));
    } catch (e) {
      if (kDebugMode) {
        print('Error loading messages from API: $e');
      }
    }
  }

  Future<void> sendMessage(String messageText) async {
    if (currentStreamId == null || messageText.trim().isEmpty || _isDisposed) {
      return;
    }

    try {
      // Send message to backend - the socket event will add it to the UI
      await _apiService.sendMessage(
        streamId: currentStreamId!,
        message: messageText.trim(),
        messageType: 'text',
      );

      // Don't add the message locally - let the socket event handle it
      // This prevents duplicate messages
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
    }
  }

  Future<void> sendGift({
    required String giftId,
    required String giftName,
    required String giftImage,
    required double giftPrice,
  }) async {
    if (currentStreamId == null) return;

    try {
      // Send gift message to backend - the socket event will add it to the UI
      await _apiService.sendMessage(
        streamId: currentStreamId!,
        message: 'sent a gift',
        messageType: 'gift',
        giftData: {
          'giftId': giftId,
          'giftName': giftName,
          'giftImage': giftImage,
          'giftPrice': giftPrice,
        },
      );

      // Don't add the message locally - let the socket event handle it
      // This prevents duplicate messages
    } catch (e) {
      if (kDebugMode) {
        print('Error sending gift: $e');
      }
    }
  }

  void addNewMessage(LiveStreamMessageModel message) {
    if (_isDisposed) return;

    // This method can be called from socket events
    final currentMessages = List<LiveStreamMessageModel>.from(messages.value);

    // Check for duplicates to prevent the same message appearing twice
    final isDuplicate = currentMessages
        .any((existingMessage) => existingMessage.id == message.id);

    if (!isDuplicate) {
      currentMessages.add(message);
      messages.value = currentMessages;

      // Update cache
      if (currentStreamId != null) {
        unawaited(VAppPref.setMap("api/live_stream_messages_$currentStreamId", {
          "data": currentMessages.map((e) => e.toMap()).toList(),
        }));
      }
    }
  }

  void clearMessages() {
    if (_isDisposed) return;

    messages.value = [];
    pinnedMessage.value = null;
    if (currentStreamId != null) {
      VAppPref.removeKey("api/live_stream_messages_$currentStreamId");
    }
  }

  Future<void> _loadPinnedMessage() async {
    if (currentStreamId == null || _isDisposed) return;

    try {
      final pinned = await _apiService.getPinnedMessage(currentStreamId!);
      if (!_isDisposed) {
        pinnedMessage.value = pinned;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading pinned message: $e');
      }
    }
  }

  Future<void> pinMessage(String messageId) async {
    if (currentStreamId == null || _isDisposed) return;

    try {
      final pinned = await _apiService.pinMessage(
        streamId: currentStreamId!,
        messageId: messageId,
      );

      if (!_isDisposed) {
        pinnedMessage.value = pinned;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error pinning message: $e');
      }
      rethrow;
    }
  }

  Future<void> unpinMessage(String messageId) async {
    if (currentStreamId == null || _isDisposed) return;

    try {
      await _apiService.unpinMessage(
        streamId: currentStreamId!,
        messageId: messageId,
      );

      if (!_isDisposed) {
        pinnedMessage.value = null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unpinning message: $e');
      }
      rethrow;
    }
  }

  void _showGiftReceivedNotification(
    Map<String, dynamic>? giftData,
    String? senderName,
    String? message,
  ) {
    if (giftData == null || senderName == null) return;

    try {
      final giftPrice = giftData['giftPrice'] as num?;
      final giftName = giftData['giftName'] as String?;

      if (giftPrice != null) {
        if (kDebugMode) {
          print(
              'Host received gift: $giftName (\$${giftPrice.toStringAsFixed(2)}) from $senderName');
        }

        // Refresh balance to show the updated amount immediately
        _refreshBalance();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error showing gift notification: $e');
      }
    }
  }

  /// Refresh the balance from backend when gifts are received
  Future<void> _refreshBalance() async {
    try {
      if (kDebugMode) {
        print(
            'LiveStreamChatController: Refreshing balance after gift received');
      }

      // Fetch fresh balance from backend
      await BalanceService.instance.init();

      if (kDebugMode) {
        print('LiveStreamChatController: Balance refreshed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('LiveStreamChatController: Error refreshing balance: $e');
      }
    }
  }

  void resetController() {
    // Reset state without disposing ValueNotifiers
    if (!_isDisposed) {
      _refreshTimer?.cancel();
      _socketSubscription?.cancel();

      // Reset values to defaults
      messages.value = [];
      isLoading.value = false;
      pinnedMessage.value = null;

      // Reset other properties
      currentStreamId = null;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _refreshTimer?.cancel();
    _socketSubscription?.cancel();
    messages.dispose();
    isLoading.dispose();
    pinnedMessage.dispose();
    super.dispose();
  }
}
