// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  static final OpenAIService _instance = OpenAIService._internal();
  factory OpenAIService() => _instance;
  OpenAIService._internal();

  static const String _apiKey = "YOUR_OPENAI_API_KEY_HERE";

  bool _isInitialized = false;
  bool _isWebSearchEnabled = true; // Enable web search by default

  // Conversation history storage - maps roomId to list of messages
  final Map<String, List<OpenAIChatCompletionChoiceMessageModel>>
      _conversationHistory = {};

  void initialize() {
    if (!_isInitialized) {
      OpenAI.apiKey = _apiKey;
      _isInitialized = true;
      if (kDebugMode) {
        print('OpenAI Service initialized');
      }
    }
  }

  // Web search toggle methods
  void enableWebSearch() {
    _isWebSearchEnabled = true;
    if (kDebugMode) {
      print('Web search enabled');
    }
  }

  void disableWebSearch() {
    _isWebSearchEnabled = false;
    if (kDebugMode) {
      print('Web search disabled');
    }
  }

  bool get isWebSearchEnabled => _isWebSearchEnabled;

  // Clear conversation history for a specific room
  void clearConversationHistory(String roomId) {
    _conversationHistory.remove(roomId);
    if (kDebugMode) {
      print('Cleared conversation history for room: $roomId');
    }
  }

  // Clear all conversation history
  void clearAllConversationHistory() {
    _conversationHistory.clear();
    if (kDebugMode) {
      print('Cleared all conversation history');
    }
  }

  Future<String> sendMessage(String message, {String? roomId}) async {
    try {
      if (kDebugMode) {
        print('OpenAI sendMessage called with: "$message"');
      }

      if (!_isInitialized) {
        initialize();
      }

      // Check if API key is set
      if (_apiKey == "YOUR_OPENAI_API_KEY_HERE") {
        return "Please configure your OpenAI API key in the OpenAIService class.";
      }

      // Use default roomId if not provided
      final conversationId = roomId ?? 'default';

      // Get or create conversation history for this room
      if (!_conversationHistory.containsKey(conversationId)) {
        _conversationHistory[conversationId] = [];

        // Add system message only for new conversations
        final systemPrompt = _isWebSearchEnabled
            ? "You are a helpful, intelligent AI assistant with web search capabilities. When users ask questions about current events, recent news, latest releases, real-time information, or anything that requires up-to-date data, you will automatically search the web to provide accurate, current information. Always give specific, accurate information - never use placeholder text or templates. Be friendly, concise, and genuinely helpful. Respond as if you're having a real conversation with a friend."
            : "You are a helpful, intelligent AI assistant. Provide natural, conversational responses. Always give specific, accurate information - never use placeholder text or templates. When asked about dates, times, or current information, use the context provided. Be friendly, concise, and genuinely helpful. Respond as if you're having a real conversation with a friend.";

        final systemMessage = OpenAIChatCompletionChoiceMessageModel(
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
                systemPrompt),
          ],
          role: OpenAIChatMessageRole.system,
        );

        _conversationHistory[conversationId]!.add(systemMessage);
      }

      // Add current date context to the message
      final now = DateTime.now();
      final currentDate = "${now.day}/${now.month}/${now.year}";
      final currentDay = _getDayName(now.weekday);
      final contextualMessage = "Today is $currentDay, $currentDate. $message";

      final userMessage = OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
              contextualMessage),
        ],
        role: OpenAIChatMessageRole.user,
      );

      // Add user message to conversation history
      _conversationHistory[conversationId]!.add(userMessage);

      // Limit conversation history to last 20 messages to avoid token limits
      if (_conversationHistory[conversationId]!.length > 20) {
        // Keep system message and last 19 messages
        final systemMsg = _conversationHistory[conversationId]!.first;
        final recentMessages = _conversationHistory[conversationId]!
            .skip(_conversationHistory[conversationId]!.length - 19)
            .toList();
        _conversationHistory[conversationId] = [systemMsg, ...recentMessages];
      }

      // Create chat completion with web search tools if enabled
      final chatCompletion = _isWebSearchEnabled
          ? await _createChatCompletionWithWebSearch(conversationId)
          : await OpenAI.instance.chat.create(
              model: "gpt-4o",
              messages: _conversationHistory[conversationId]!,
              maxTokens: 500,
              temperature: 0.7,
            );

      final response =
          chatCompletion.choices.first.message.content?.first.text ??
              "I'm sorry, I couldn't process your request at the moment.";

      // Add AI response to conversation history
      final aiMessage = OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(response),
        ],
        role: OpenAIChatMessageRole.assistant,
      );
      _conversationHistory[conversationId]!.add(aiMessage);

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('OpenAI Error: $e');
      }

      // Return a friendly error message
      if (e.toString().contains('API key')) {
        return "Please configure your OpenAI API key to use the AI assistant.";
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        return "Sorry, I'm having trouble connecting. Please check your internet connection.";
      } else {
        return "Sorry, I'm experiencing some technical difficulties. Please try again later.";
      }
    }
  }

  // Create chat completion with web search tools using Responses API
  Future<OpenAIChatCompletionModel> _createChatCompletionWithWebSearch(
      String conversationId) async {
    try {
      // Get the latest user message for web search
      final userMessage = _conversationHistory[conversationId]!.last;
      final userInput = userMessage.content?.first.text ?? "";

      // Create request body using Responses API format with web search tool
      final requestBody = {
        "model": "gpt-4o",
        "input": userInput,
        "tools": [
          {"type": "web_search"}
        ],
        "tool_choice": {"type": "web_search"}, // Force web search usage
      };

      if (kDebugMode) {
        print('Making web search request to OpenAI Responses API');
        print('User input: $userInput');
      }

      // Make HTTP request to Responses API with web search tools
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/responses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          print('Web search response received: ${responseData.toString()}');
        }

        // Extract the final response from the outputs
        String finalResponse = "Sorry, I couldn't find any information.";

        if (responseData['output'] != null) {
          final outputs = responseData['output'] as List;

          // Look for the message type output with content
          for (final output in outputs) {
            if (output['type'] == 'message' &&
                output['content'] != null &&
                output['content'] is List) {
              final contentList = output['content'] as List;

              // Find the text content in the message
              for (final content in contentList) {
                if (content['type'] == 'output_text' &&
                    content['text'] != null) {
                  finalResponse = content['text'];
                  break;
                }
              }

              if (finalResponse != "Sorry, I couldn't find any information.") {
                break;
              }
            }
          }
        }

        // Create a compatible OpenAIChatCompletionModel
        return OpenAIChatCompletionModel(
          id: responseData['id'] ?? 'web_search_response',
          choices: [
            OpenAIChatCompletionChoiceModel(
              index: 0,
              message: OpenAIChatCompletionChoiceMessageModel(
                role: OpenAIChatMessageRole.assistant,
                content: [
                  OpenAIChatCompletionChoiceMessageContentItemModel.text(
                      finalResponse),
                ],
              ),
              finishReason: 'stop',
            ),
          ],
          created: DateTime.now(),
          systemFingerprint: null,
          usage: OpenAIChatCompletionUsageModel(
            promptTokens: 0,
            completionTokens: 0,
            totalTokens: 0,
          ),
        );
      } else {
        if (kDebugMode) {
          print(
              'Web search request failed with status: ${response.statusCode}');
          print('Response body: ${response.body}');
        }

        // Fallback to regular chat completion
        return await OpenAI.instance.chat.create(
          model: "gpt-4o",
          messages: _conversationHistory[conversationId]!,
          maxTokens: 500,
          temperature: 0.7,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Web search error: $e');
      }

      // Fallback to regular chat completion
      return await OpenAI.instance.chat.create(
        model: "gpt-4o",
        messages: _conversationHistory[conversationId]!,
        maxTokens: 500,
        temperature: 0.7,
      );
    }
  }

  // Method to simulate typing delay for better UX
  Future<void> simulateTyping() async {
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  // Generate image using GPT-4.1 with image generation tool
  Future<String?> generateImage(String prompt) async {
    try {
      if (kDebugMode) {
        print('Generating image with GPT-4.1 and prompt: $prompt');
      }

      // Use the new Responses API with GPT-4.1 and image generation tool
      final requestBody = {
        "model": "gpt-4.1-mini",
        "input": "Generate an image: $prompt",
        "tools": [
          {"type": "image_generation"}
        ],
        "tool_choice": {"type": "image_generation"}, // Force image generation
      };

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/responses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final outputs = responseData['output'] as List;

        // Find image generation call in outputs
        for (final output in outputs) {
          if (output['type'] == 'image_generation_call' &&
              output['status'] == 'completed') {
            final imageBase64 = output['result'] as String;

            if (kDebugMode) {
              print('Generated image with GPT-4.1 successfully');
              if (output['revised_prompt'] != null) {
                print('Revised prompt: ${output['revised_prompt']}');
              }
            }

            return imageBase64; // Return base64 encoded image
          }
        }
      } else {
        if (kDebugMode) {
          print('Image generation failed with status: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Image generation error: $e');
      }
      return null;
    }
  }

  Future<Map<String, String>?> generateMarketplaceTitleDescriptionFromImage({
    required Uint8List imageBytes,
    String? context,
  }) async {
    try {
      if (!_isInitialized) {
        initialize();
      }

      final base64Image = base64Encode(imageBytes);

      final sys =
          'You write marketplace listings. Return ONLY valid JSON with exactly these keys: "title", "description". '
          'No markdown, no code fences, no extra keys.';

      final userText =
          'Create a concise, accurate title (max 70 chars) and a helpful description (2-5 short lines) based only on the image.'
          '${(context == null || context.trim().isEmpty) ? '' : "\nContext: ${context.trim()}"}';

      final requestBody = {
        "model": "gpt-4o",
        "messages": [
          {"role": "system", "content": sys},
          {
            "role": "user",
            "content": [
              {"type": "text", "text": userText},
              {
                "type": "image_url",
                "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
              }
            ]
          }
        ],
        "max_tokens": 300,
        "temperature": 0.3
      };

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('Marketplace text generation failed: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
        return null;
      }

      final responseData = jsonDecode(response.body);
      final content = responseData['choices']?[0]?['message']?['content'];
      if (content is! String) return null;

      final trimmed = content.trim();
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;

      final jsonStr = trimmed.substring(start, end + 1);
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return null;

      final t = (decoded['title'] ?? '').toString().trim();
      final d = (decoded['description'] ?? '').toString().trim();
      if (t.isEmpty && d.isEmpty) return null;

      return {
        'title': t,
        'description': d,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Marketplace text generation error: $e');
      }
      return null;
    }
  }

  Future<Uint8List?> upscaleImage(Uint8List imageBytes) async {
    try {
      if (!_isInitialized) {
        initialize();
      }

      final base64Image = base64Encode(imageBytes);

      final requestBody = {
        'model': 'gpt-4.1-mini',
        'input': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_text',
                'text':
                    'Upscale and enhance this image for better quality. Keep the content identical and realistic. Improve sharpness and clarity. Return only the enhanced image.',
              },
              {
                'type': 'input_image',
                'image_url': 'data:image/jpeg;base64,$base64Image',
              },
            ],
          }
        ],
        'tools': [
          {'type': 'image_generation'}
        ],
        'tool_choice': {'type': 'image_generation'},
      };

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/responses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('Upscale failed with status: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
        return null;
      }

      final responseData = jsonDecode(response.body);
      final outputs = responseData['output'];
      if (outputs is! List) return null;

      String? base64Out;

      for (final output in outputs) {
        if (output is! Map) continue;

        final type = output['type'];
        if (type == 'image_generation_call' && output['status'] == 'completed') {
          final result = output['result'];
          if (result is String && result.trim().isNotEmpty) {
            base64Out = result;
            break;
          }
        }

        if (type == 'message' && output['content'] is List) {
          for (final c in (output['content'] as List)) {
            if (c is! Map) continue;
            if (c['type'] == 'output_image') {
              final img = c['image_base64'] ?? c['base64'] ?? c['image'] ?? c['data'];
              if (img is String && img.trim().isNotEmpty) {
                base64Out = img;
                break;
              }
            }
          }
          if (base64Out != null) break;
        }
      }

      if (base64Out == null) return null;

      var cleaned = base64Out.trim();
      final idx = cleaned.indexOf('base64,');
      if (idx != -1) {
        cleaned = cleaned.substring(idx + 'base64,'.length);
      }
      return base64Decode(cleaned);
    } catch (e) {
      if (kDebugMode) {
        print('Upscale image error: $e');
      }
      return null;
    }
  }

  // Convert speech to text using Whisper API
  Future<String?> speechToText(File audioFile) async {
    try {
      if (kDebugMode) {
        print('Converting speech to text with Whisper API');
      }

      final audioTranscription =
          await OpenAI.instance.audio.createTranscription(
        file: audioFile,
        model: "whisper-1",
        responseFormat: OpenAIAudioResponseFormat.json,
      );

      final transcribedText = audioTranscription.text;

      if (kDebugMode) {
        print('Speech to text result: $transcribedText');
      }

      return transcribedText;
    } catch (e) {
      if (kDebugMode) {
        print('Speech to text error: $e');
      }
      return null;
    }
  }

  // Analyze image using OpenAI Vision API with direct HTTP call
  Future<String?> analyzeImage(File imageFile, String? userPrompt) async {
    try {
      if (kDebugMode) {
        print('Analyzing image with OpenAI Vision API');
      }

      // Read image file as bytes
      final imageBytes = await imageFile.readAsBytes();

      // Convert to base64
      final base64Image = base64Encode(imageBytes);

      // Prepare the text content
      String textContent = userPrompt != null && userPrompt.trim().isNotEmpty
          ? "User's question about this image: ${userPrompt.trim()}"
          : "Please analyze this image and describe what you see in detail.";

      // Create system prompt for image analysis
      String systemPrompt =
          "You are a helpful AI assistant that can analyze images. Describe what you see in the image in detail. Be specific and accurate about objects, people, text, colors, and any other relevant details you observe.";

      // Create the request body with proper format
      final requestBody = {
        "model": "gpt-4o",
        "messages": [
          {"role": "system", "content": systemPrompt},
          {
            "role": "user",
            "content": [
              {"type": "text", "text": textContent},
              {
                "type": "image_url",
                "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
              }
            ]
          }
        ],
        "max_tokens": 500,
        "temperature": 0.7
      };

      // Make the HTTP request
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final content = responseData['choices'][0]['message']['content'];

        if (kDebugMode) {
          print('Image analysis successful: $content');
        }

        return content;
      } else {
        if (kDebugMode) {
          print('Image analysis failed with status: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Image analysis error: $e');
      }
      return null;
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }
}
