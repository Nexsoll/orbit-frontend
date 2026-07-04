import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:super_up/app/core/models/story/story_model.dart';
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up_core/super_up_core.dart';

class StoryMediaCacheService {
  StoryMediaCacheService._();

  static final StoryMediaCacheService I = StoryMediaCacheService._();

  final CacheManager _cacheManager = CacheManager(
    Config(
      'story_media_cache_v1',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 700,
    ),
  );

  String resolveStoryUrl(String? rawUrl) {
    final raw = (rawUrl ?? '').trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return '${SConstants.baseMediaUrl}${raw.startsWith('/') ? '' : '/'}$raw';
  }

  Future<void> prefetchStoryMedia(List<UserStoryModel> users) async {
    if (kIsWeb) return;

    final urls = <String>{};
    for (final user in users) {
      for (final story in user.stories) {
        final att = story.att ?? const <String, dynamic>{};
        // Skip prefetching full video files; stream them directly for fast start.
        if (story.storyType != StoryType.video) {
          final mediaUrl = resolveStoryUrl(att['url']?.toString());
          if (mediaUrl.isNotEmpty) {
            urls.add(mediaUrl);
          }
        }
        final thumbUrl = resolveStoryUrl(
          (att['thumbnailUrl'] ?? att['thumbUrl'])?.toString(),
        );
        if (thumbUrl.isNotEmpty) {
          urls.add(thumbUrl);
        }
      }
    }

    if (urls.isEmpty) return;

    // Keep bandwidth pressure low while still warming cache in the background.
    const maxConcurrent = 3;
    final queue = urls.toList();
    var index = 0;

    Future<void> worker() async {
      while (index < queue.length) {
        final current = queue[index++];
        try {
          await _cacheManager.getSingleFile(
            current,
            key: _cacheKeyFor(current),
          );
        } catch (_) {
          // Best effort caching only.
        }
      }
    }

    final workers = List.generate(
      queue.length < maxConcurrent ? queue.length : maxConcurrent,
      (_) => worker(),
    );
    await Future.wait(workers);
  }

  Future<String?> getCachedVideoPath(String url) async {
    if (kIsWeb) return null;
    try {
      final cached = await _cacheManager.getFileFromCache(_cacheKeyFor(url));
      if (cached == null) return null;
      return cached.file.path;
    } catch (_) {
      return null;
    }
  }

  String _cacheKeyFor(String url) => url.trim();
}
