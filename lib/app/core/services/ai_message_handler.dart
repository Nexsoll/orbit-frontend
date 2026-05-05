// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import 'openai_service.dart';
import 'dart:developer';

class AiMessageHandler {
  static final AiMessageHandler _instance = AiMessageHandler._internal();
  factory AiMessageHandler() => _instance;
  AiMessageHandler._internal();

  static const String aiRoomId = "ai_assistant_room";
  static const String aiPeerId = "ai_assistant_peer";

  StreamSubscription? _messageSubscription;
  final OpenAIService _openAIService = OpenAIService();
  bool _isInitialized = false;
  bool _hasWelcomed = false;

  void initialize() {
    if (_isInitialized) return;

    _openAIService.initialize();
    _startListening();
    _interceptUploadQueue();
    _isInitialized = true;

    if (kDebugMode) {
      log('AI Message Handler initialized');
    }
  }

  void _startListening() {
    _messageSubscription = VEventBusSingleton.vEventBus
        .on<VInsertMessageEvent>()
        .listen((event) async {
      await _handleNewMessage(event.messageModel);
    });
  }

  void _interceptUploadQueue() {
    // Listen for message insertions and immediately mark AI room messages as sent
    VEventBusSingleton.vEventBus
        .on<VInsertMessageEvent>()
        .listen((event) async {
      if (event.roomId == aiRoomId && event.messageModel.isMeSender) {
        // Small delay to ensure message is fully inserted
        await Future.delayed(const Duration(milliseconds: 200));
        await _markMessageAsDelivered(event.messageModel);

        // Also try to remove from upload queue
        _removeFromUploadQueue(event.messageModel.localId);
      }
    });

    // Periodically clean the upload queue of AI room messages
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _cleanUploadQueue();
    });
  }

  void _removeFromUploadQueue(String localId) {
    try {
      VMessageUploaderQueue.instance.removeFromQueue(localId);
      if (kDebugMode) {
        log('Removed AI message from upload queue: $localId');
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error removing from upload queue: $e');
      }
    }
  }

  void _cleanUploadQueue() {
    // This is a periodic cleanup to ensure no AI room messages remain in queue
    try {
      // We can't directly access the queue, but removeFromQueue should help
      // The queue will be cleaned by the periodic removal
    } catch (e) {
      if (kDebugMode) {
        log('Error cleaning upload queue: $e');
      }
    }
  }

  Future<void> _markMessageAsDelivered(VBaseMessage message) async {
    try {
      // Mark as sent (server confirmed)
      await VChatController.I.nativeApi.local.message
          .updateMessageSendingStatus(
        VUpdateMessageStatusEvent(
          roomId: message.roomId,
          localId: message.localId,
          emitState: VMessageEmitStatus.serverConfirm,
        ),
      );

      // Mark as delivered to show blue checkmark
      await VChatController.I.nativeApi.local.message.updateMessagesSetDeliver(
        VUpdateMessageDeliverEvent(
          roomId: message.roomId,
          localId: message.localId,
          model: VSocketOnDeliverMessagesModel(
            roomId: message.roomId,
            userId: message.senderId,
            date: DateTime.now().toIso8601String(),
          ),
        ),
      );

      // Mark as seen (read) to show blue double tick icons
      await VChatController.I.nativeApi.local.message.updateMessagesSetSeen(
        VUpdateMessageSeenEvent(
          roomId: message.roomId,
          localId: message.localId,
          model: VSocketOnRoomSeenModel(
            roomId: message.roomId,
            userId: message.senderId,
            date: DateTime.now().toIso8601String(),
          ),
        ),
      );

      if (kDebugMode) {
        log('Marked AI room message as delivered and seen: ${message.localId}');
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error marking AI message as delivered and seen: $e');
      }
    }
  }

  Future<void> _handleNewMessage(VBaseMessage message) async {
    // Only handle messages in the AI Assistant room
    if (message.roomId != aiRoomId) return;

    // Only respond to user messages (not AI responses)
    if (!message.isMeSender) return;

    // Skip if this is an AI response (prevent infinite loop)
    if (message.senderId == aiPeerId) return;

    // User message status will be handled by AiUploadInterceptor

    try {
      String messageContent = '';

      // Handle different message types
      if (message is VTextMessage) {
        messageContent = message.realContent;
        if (kDebugMode) {
          log('AI Assistant received text message: $messageContent');
        }
      } else if (message is VVoiceMessage) {
        if (kDebugMode) {
          log('AI Assistant received voice message, converting to text...');
        }

        // Send a "processing voice" message first
        await _sendAiResponse("🎤 Converting your voice message to text...");

        // Convert voice to text
        messageContent = await _handleVoiceMessage(message);

        if (messageContent.isEmpty) {
          await _sendAiResponse(
              "Sorry, I couldn't understand your voice message. Please try again or send a text message.");
          return;
        }

        // Send the transcribed text as a confirmation
        await _sendAiResponse("📝 I heard: \"$messageContent\"");
      } else if (message is VImageMessage) {
        if (kDebugMode) {
          log('AI Assistant received image message, analyzing...');
        }

        // Send a "processing image" message first
        await _sendAiResponse("🖼️ Analyzing your image...");

        // Analyze the image
        await _handleImageMessage(message);
        return;
      } else {
        // Unsupported message type
        await _sendAiResponse(
            "I can process text, voice, and image messages. Please send a text, voice, or image message.");
        return;
      }

      // Check if user wants to generate an image
      if (_isImageGenerationRequest(messageContent)) {
        await _handleImageGeneration(messageContent);
        return;
      }

      // Simulate typing delay for better UX
      await _openAIService.simulateTyping();

      // Get AI response with room context for conversation history
      final aiResponse =
          await _openAIService.sendMessage(messageContent, roomId: aiRoomId);

      if (kDebugMode) {
        log('AI Assistant responding: $aiResponse');
      }

      // Create AI response message
      await _sendAiResponse(aiResponse);
    } catch (e) {
      if (kDebugMode) {
        log('Error handling AI message: $e');
      }

      // Send error response
      await _sendAiResponse(
          "Sorry, I'm having trouble processing your message. Please try again.");
    }
  }

  Future<void> _sendAiResponse(String responseText) async {
    try {
      // Create AI response message using the correct constructor
      final aiMessage = VTextMessage.buildMessage(
        roomId: aiRoomId,
        content: responseText,
        isEncrypted: false,
        linkAtt: null,
      );

      // Set the sender ID to AI peer to identify it as AI message
      aiMessage.senderId = aiPeerId;
      aiMessage.senderName = "Orbit AI";

      // Mark as already sent to prevent backend sync and show read icon
      aiMessage.emitStatus = VMessageEmitStatus.serverConfirm;
      aiMessage.id = "ai_${DateTime.now().millisecondsSinceEpoch}";

      // Insert the message locally (this will appear in the chat)
      await VChatController.I.nativeApi.local.message.insertMessage(aiMessage);

      // Fire the event to update the UI
      VEventBusSingleton.vEventBus.fire(VInsertMessageEvent(
        messageModel: aiMessage,
        roomId: aiRoomId,
        localId: aiMessage.localId,
      ));

      if (kDebugMode) {
        log('AI response sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error sending AI response: $e');
      }
    }
  }

  // Send welcome message when AI Assistant room is opened
  Future<void> sendWelcomeMessage() async {
    if (_hasWelcomed) return;

    _hasWelcomed = true;

    const welcomeMessage = "Hello! I'm Orbit AI. How can I help you today?";
    await _sendAiResponse(welcomeMessage);

    if (kDebugMode) {
      log('AI Assistant welcome message sent');
    }
  }

  // Clear all messages in the AI Assistant room
  Future<void> clearAllMessages() async {
    try {
      // Delete all messages in the AI room
      await VChatController.I.nativeApi.local.message
          .deleteMessageByRoomId(aiRoomId);

      // Clear conversation history in OpenAI service
      _openAIService.clearConversationHistory(aiRoomId);

      // Reset welcome flag so welcome message will be sent again
      _hasWelcomed = false;

      if (kDebugMode) {
        log('Cleared all AI Assistant messages and conversation history');
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error clearing AI messages: $e');
      }
    }
  }

  // Handle voice message conversion to text
  Future<String> _handleVoiceMessage(VVoiceMessage voiceMessage) async {
    try {
      // Get the voice file from the message
      final voiceFile = voiceMessage.data.fileSource;

      if (voiceFile.fileLocalPath == null) {
        if (kDebugMode) {
          log('Voice file local path is null');
        }
        return '';
      }

      // Create File object from the local path
      final audioFile = File(voiceFile.fileLocalPath!);

      if (!await audioFile.exists()) {
        if (kDebugMode) {
          log('Voice file does not exist at path: ${voiceFile.fileLocalPath}');
        }
        return '';
      }

      if (kDebugMode) {
        log('Converting voice file to text: ${voiceFile.fileLocalPath}');
      }

      // Convert speech to text using OpenAI Whisper
      final transcribedText = await _openAIService.speechToText(audioFile);

      if (transcribedText == null || transcribedText.trim().isEmpty) {
        if (kDebugMode) {
          log('Speech to text returned empty result');
        }
        return '';
      }

      return transcribedText.trim();
    } catch (e) {
      if (kDebugMode) {
        log('Error handling voice message: $e');
      }
      return '';
    }
  }

  // Handle image message analysis using OpenAI Vision API
  Future<void> _handleImageMessage(VImageMessage imageMessage) async {
    try {
      // Check if web search is enabled and user text suggests web search
      final userText = imageMessage.realContent;
      final isWebSearchEnabled = _openAIService.isWebSearchEnabled;

      if (isWebSearchEnabled && _shouldPerformWebSearchForImage(userText)) {
        if (kDebugMode) {
          log('Web search enabled for image message with text: $userText');
        }

        // Send a "analyzing image" message first
        await _sendAiResponse("🔍 Analyzing your image...");

        // Get the image file and analyze it first
        final imageFile = imageMessage.data.fileSource;

        if (imageFile.fileLocalPath != null) {
          final file = File(imageFile.fileLocalPath!);
          if (await file.exists()) {
            // First, analyze the image to understand what's in it
            final imageAnalysis = await _openAIService.analyzeImage(file,
                "Describe what you see in this image, focusing on any products, items, or objects that could be purchased.");

            if (imageAnalysis != null && imageAnalysis.trim().isNotEmpty) {
              // Send a web search message
              await _sendAiResponse("🔍 Searching the web for information...");

              // Perform web search using the regular sendMessage with web search enabled
              final webSearchPrompt =
                  "Based on this image analysis: \"$imageAnalysis\" and the user's question: \"$userText\", please search the web and provide helpful information about where to buy or find similar items.";

              final finalResponse = await _openAIService
                  .sendMessage(webSearchPrompt, roomId: aiRoomId);
              await _sendAiResponse(finalResponse);
              return;
            }
          }
        }

        // Fallback if image analysis fails
        await _sendAiResponse(
            "Sorry, I couldn't analyze the image. Please try again.");
        return;
      }

      // Get the image file from the message
      final imageFile = imageMessage.data.fileSource;

      if (imageFile.fileLocalPath == null) {
        if (kDebugMode) {
          log('Image file local path is null');
        }
        await _sendAiResponse(
            "Sorry, I couldn't access the image file. Please try uploading the image again.");
        return;
      }

      // Create File object from the local path
      final file = File(imageFile.fileLocalPath!);

      if (!await file.exists()) {
        if (kDebugMode) {
          log('Image file does not exist at path: ${imageFile.fileLocalPath}');
        }
        await _sendAiResponse(
            "Sorry, I couldn't find the image file. Please try uploading the image again.");
        return;
      }

      if (kDebugMode) {
        log('Analyzing image file: ${imageFile.fileLocalPath}');
      }

      // Analyze the image using OpenAI Vision API
      final analysisResult =
          await _openAIService.analyzeImage(file, imageMessage.realContent);

      if (analysisResult == null || analysisResult.trim().isEmpty) {
        if (kDebugMode) {
          log('Image analysis returned empty result');
        }
        await _sendAiResponse(
            "Sorry, I couldn't analyze the image. Please try again with a different image.");
        return;
      }

      // Send the analysis result
      await _sendAiResponse(analysisResult);
    } catch (e) {
      if (kDebugMode) {
        log('Error handling image message: $e');
      }
      await _sendAiResponse(
          "Sorry, I encountered an error while analyzing the image. Please try again.");
    }
  }

  // Check if image message should use web search
  bool _shouldPerformWebSearchForImage(String userText) {
    if (userText.isEmpty) return false;

    final lowerText = userText.toLowerCase();
    final webSearchKeywords = [
      'link',
      'buy',
      'purchase',
      'where to buy',
      'find',
      'search',
      'shop',
      'store',
      'website',
      'online',
      'price',
      'cost',
      'similar',
      'like this',
      'where can i',
      'how to get',
      'available',
    ];

    return webSearchKeywords.any((keyword) => lowerText.contains(keyword));
  }

  // Check if the message is requesting image generation
  bool _isImageGenerationRequest(String message) {
    final lowerMessage = message.toLowerCase();
    final imageKeywords = [
      'generate image',
      'create image',
      'draw',
      'make image',
      'generate picture',
      'create picture',
      'draw picture',
      'make picture',
      'image of',
      'picture of',
      'show me',
      'visualize',
    ];

    return imageKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  // Handle image generation request
  Future<void> _handleImageGeneration(String userMessage) async {
    try {
      if (kDebugMode) {
        log('Handling image generation request: $userMessage');
      }

      // Send a "generating image" message first
      await _sendAiResponse(
          "🎨 Generating image for you... This may take a moment.");

      // Extract the image prompt from the user message
      String imagePrompt = _extractImagePrompt(userMessage);

      // Generate the image
      final imageBase64 = await _openAIService.generateImage(imagePrompt);

      if (imageBase64 != null) {
        // Send the image as a message
        await _sendImageMessage(imageBase64, imagePrompt);
      } else {
        await _sendAiResponse(
            "Sorry, I couldn't generate the image. Please try again with a different description.");
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error handling image generation: $e');
      }
      await _sendAiResponse(
          "Sorry, there was an error generating the image. Please try again.");
    }
  }

  // Extract image prompt from user message
  String _extractImagePrompt(String message) {
    final lowerMessage = message.toLowerCase();

    // Remove common prefixes to get the actual prompt
    final prefixesToRemove = [
      'generate image of',
      'create image of',
      'draw',
      'make image of',
      'generate picture of',
      'create picture of',
      'draw picture of',
      'make picture of',
      'image of',
      'picture of',
      'show me',
      'visualize',
      'generate image',
      'create image',
      'make image',
      'generate picture',
      'create picture',
      'make picture',
    ];

    String prompt = message;
    for (final prefix in prefixesToRemove) {
      if (lowerMessage.startsWith(prefix)) {
        prompt = message.substring(prefix.length).trim();
        break;
      }
      if (lowerMessage.contains(prefix)) {
        final index = lowerMessage.indexOf(prefix);
        prompt = message.substring(index + prefix.length).trim();
        break;
      }
    }

    // If prompt is empty or too short, use the original message
    if (prompt.isEmpty || prompt.length < 3) {
      prompt = message;
    }

    return prompt;
  }

  // Send an image message from AI
  Future<void> _sendImageMessage(String imageBase64, String prompt) async {
    try {
      if (kDebugMode) {
        log('Sending AI image message with base64 data');
      }

      // Create image from base64 data and send as proper image message
      await _createAndSendImageFromBase64(imageBase64, prompt);

      if (kDebugMode) {
        log('AI image sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error sending AI image message: $e');
      }

      // Fallback to text message
      await _sendAiResponse(
          "🖼️ I generated an image for you, but there was an error displaying it.\n\n📝 Prompt: $prompt");
    }
  }

  // Create image from base64 data and send as proper image message
  Future<void> _createAndSendImageFromBase64(
      String imageBase64, String prompt) async {
    try {
      // Decode base64 to bytes
      final imageBytes = base64Decode(imageBase64);

      if (kDebugMode) {
        log('Decoded base64 image, size: ${imageBytes.length} bytes');
      }

      // Create a temporary file to save the image
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'ai_generated_image_$timestamp.png';
      final fileHash = 'ai_generated_image_$timestamp';

      // Save the image bytes to a temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(imageBytes);

      // Copy file to app's media directory
      await VFileUtils.copyFileToAppFolder(fileName, tempFile.path);

      // Clean up temporary file
      await tempFile.delete();

      // Create VPlatformFile with proper metadata using fromMap
      final platformFile = VPlatformFile.fromMap({
        'name': fileName,
        'size': imageBytes.length,
        'extension': '.png',
        'fileHash': fileHash,
        'mimeType': 'image/png',
        'filePath': VFileUtils.getLocalPath(fileName),
      });

      // Get image dimensions using VFileUtils
      final imageInfo = await VFileUtils.getImageInfo(fileSource: platformFile);

      // Create VMessageImageData
      final imageData = VMessageImageData(
        fileSource: platformFile,
        width: imageInfo.image.width,
        height: imageInfo.image.height,
        blurHash: null,
      );

      // Create AI image message
      final aiImageMessage = VImageMessage.buildMessage(
        roomId: aiRoomId,
        data: imageData,
        content: "🖼️ Here's your generated image:\n\n📝 Prompt: $prompt",
      );

      // Set the sender ID to AI peer to identify it as AI message
      aiImageMessage.senderId = aiPeerId;
      aiImageMessage.senderName = "Orbit AI";

      // Mark as already sent to prevent backend sync and show read icon
      aiImageMessage.emitStatus = VMessageEmitStatus.serverConfirm;
      aiImageMessage.id = "ai_img_${DateTime.now().millisecondsSinceEpoch}";

      // Insert the message locally (this will appear in the chat)
      await VChatController.I.nativeApi.local.message
          .insertMessage(aiImageMessage);

      // Fire the event to update the UI
      VEventBusSingleton.vEventBus.fire(VInsertMessageEvent(
        messageModel: aiImageMessage,
        roomId: aiRoomId,
        localId: aiImageMessage.localId,
      ));

      if (kDebugMode) {
        log('AI image message sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error creating and sending image from base64: $e');
      }
      rethrow;
    }
  }

  void dispose() {
    _messageSubscription?.cancel();
    _isInitialized = false;
    _hasWelcomed = false;

    if (kDebugMode) {
      log('AI Message Handler disposed');
    }
  }
}
