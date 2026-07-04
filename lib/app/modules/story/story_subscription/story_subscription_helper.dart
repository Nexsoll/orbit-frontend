// Copyright 2026
// Story subscription helper

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up_core/super_up_core.dart';
import '../../../core/api_service/story/story_api.dart';

import 'story_subscription_page.dart';

class StorySubscriptionHelper {
  static const dailyLimitMessage =
      'Daily limit is 1 story. Deleting a story does not reset today\'s limit; you can post again tomorrow.';

  static bool isRequired(String error) {
    return error.contains('STORY_SUBSCRIPTION_REQUIRED') ||
        error.contains('STORY_DAILY_LIMIT_REACHED');
  }

  static bool isDailyLimit(String error) {
    return error.contains('STORY_DAILY_LIMIT_REACHED');
  }

  static String userMessage(String error) {
    if (isDailyLimit(error)) return dailyLimitMessage;
    if (isRequired(error)) {
      return 'You have used your free story. Subscribe to post more stories.';
    }
    return error;
  }

  static bool openIfRequired(BuildContext context, String error) {
    if (!isRequired(error)) return false;
    Future.microtask(() {
      _showLimitDialog(context);
    });
    return true;
  }

  static Future<bool> guardCreateStory(
    BuildContext context,
    StoryType storyType,
  ) async {
    try {
      final eligibility = await _checkEligibility(storyType);
      if (eligibility?['allowed'] == true) return true;
      await _showLimitDialog(context);
      return false;
    } catch (_) {
      return true; // Fail open; backend will still enforce limits
    }
  }

  static Future<bool> guardCreateMediaStory(BuildContext context) async {
    try {
      final image = await _checkEligibility(StoryType.image);
      final video = await _checkEligibility(StoryType.video);
      final imageAllowed = image?['allowed'] == true;
      final videoAllowed = video?['allowed'] == true;
      if (imageAllowed || videoAllowed) return true;
      await _showLimitDialog(context);
      return false;
    } catch (_) {
      return true; // Fail open; backend will still enforce limits
    }
  }

  static Future<void> _showLimitDialog(BuildContext context) async {
    final upgrade = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Story limit reached'),
            content: const Text(dailyLimitMessage),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Upgrade'),
              ),
            ],
          ),
        ) ??
        false;

    if (upgrade && context.mounted) {
      await _openPlans(context);
    }
  }

  static Future<void> _openPlans(BuildContext context) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const StorySubscriptionPage(),
      ),
    );
  }

  static Future<Map<String, dynamic>?> _checkEligibility(
    StoryType storyType,
  ) async {
    final url = Uri.parse(
      '${StoryApi.storyReelsServiceBaseUrl}/story-subscriptions/eligibility?storyType=${storyType.name}',
    );
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw Exception('Login required. Please login again.');
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final res = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to check story eligibility');
    }

    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000) {
      throw Exception('Failed to check story eligibility');
    }

    return parsed['data'] as Map<String, dynamic>?;
  }
}
