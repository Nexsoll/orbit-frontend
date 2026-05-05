import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/story/story_api_service.dart';
import 'package:super_up/app/modules/live_stream/services/live_stream_api_service.dart';
import 'package:super_up/app/modules/home/mobile/story_tab/controllers/story_tab_controller.dart';
import 'package:super_up/app/core/models/story/story_model.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

/// Service to manage story status and live status for users
class StoryStatusService {
  static final StoryStatusService _instance = StoryStatusService._internal();
  factory StoryStatusService() => _instance;
  StoryStatusService._internal();

  final _storyApiService = GetIt.I.get<StoryApiService>();

  // Cache for user stories
  final Map<String, UserStoryModel> _userStoriesCache = {};

  // Keep local optimistic "seen" flags so UI doesn't flicker when the API lags
  final Set<String> _optimisticSeenStoryIds = <String>{};

  // Signature cache for change detection (UserStoryModel == ignores stories list)
  final Map<String, String> _userStoriesSignatureCache = <String, String>{};

  // Cache for live status
  final Set<String> _liveUsersCache = {};
  final Map<String, String> _liveUserToStreamId = {};

  // Stream controllers for real-time updates
  final _storyUpdatesController =
      StreamController<Map<String, UserStoryModel>>.broadcast();
  final _liveStatusController = StreamController<Set<String>>.broadcast();

  // Getters for streams
  Stream<Map<String, UserStoryModel>> get storyUpdates =>
      _storyUpdatesController.stream;
  Stream<Set<String>> get liveStatusUpdates => _liveStatusController.stream;

  Timer? _refreshTimer;
  bool _isInitialized = false;
  bool _liveSocketListening = false;

  /// Initialize the service
  void initialize() {
    if (_isInitialized) return;

    _isInitialized = true;
    _startPeriodicRefresh();

    // Start listening to live socket events for instant updates
    _setupLiveSocketListeners();

    if (kDebugMode) {
      print('StoryStatusService initialized');
    }
  }

  void _setupLiveSocketListeners() {
    if (_liveSocketListening) return;
    try {
      final socket = VChatController.I.nativeApi.remote.socketIo.socket;
      socket.on('live_stream_started', (data) {
        try {
          final userId = data is Map && data['streamerId'] is String
              ? data['streamerId'] as String
              : null;
          final streamId = data is Map && data['streamId'] is String
              ? data['streamId'] as String
              : null;
          if (userId != null && streamId != null) {
            setUserLiveNow(userId: userId, streamId: streamId);
          }
        } catch (_) {}
      });

      socket.on('live_stream_ended', (data) {
        try {
          final userId = data is Map && data['streamerId'] is String
              ? data['streamerId'] as String
              : null;
          if (userId != null) {
            setUserLiveEnded(userId: userId);
          }
        } catch (_) {}
      });
      _liveSocketListening = true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to setup live socket listeners: $e');
      }
    }
  }

  /// Start periodic refresh of story and live status
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_hasAuthToken()) {
        return;
      }
      _refreshStoryStatus();
      _refreshLiveStatus();
    });

    // Initial load
    if (_hasAuthToken()) {
      _refreshStoryStatus();
      _refreshLiveStatus();
    }
  }

  bool _hasAuthToken() {
    final token = VAppPref.getHashedString(
      key: SStorageKeys.vAccessToken.name,
    );
    return token != null && token.isNotEmpty;
  }

  /// Refresh story status from API
  Future<void> _refreshStoryStatus() async {
    try {
      final stories =
          await _storyApiService.getUsersStories(page: 1, limit: 50);

      // Create new cache to compare
      final newStoriesCache = <String, UserStoryModel>{};
      final newSignatures = <String, String>{};
      final seenIdsInResponse = <String>{};

      for (final userStory in stories) {
        final updatedStories = userStory.stories.map((s) {
          seenIdsInResponse.add(s.id);
          if (_optimisticSeenStoryIds.contains(s.id)) {
            if (!s.viewedByMe) {
              return StoryModel(
                id: s.id,
                userId: s.userId,
                content: s.content,
                backgroundColor: s.backgroundColor,
                caption: s.caption,
                att: s.att,
                expireAt: s.expireAt,
                createdAt: s.createdAt,
                updatedAt: s.updatedAt,
                storyType: s.storyType,
                fontType: s.fontType,
                viewedByMe: true,
                viewsCount: s.viewsCount,
              );
            }
            // Server already reflects seen; drop from optimistic set
            _optimisticSeenStoryIds.remove(s.id);
          }
          return s;
        }).toList();

        final mergedUserStory = UserStoryModel(
          userData: userStory.userData,
          stories: updatedStories,
        );

        newStoriesCache[userStory.userData.id] = mergedUserStory;
        newSignatures[userStory.userData.id] = _signatureOfUserStory(mergedUserStory);
      }

      // Cleanup optimistic seen ids for stories no longer present (expired/deleted)
      _optimisticSeenStoryIds.removeWhere((id) => !seenIdsInResponse.contains(id));

      // Only update and notify if there are actual changes
      if (!_mapsEqual(_userStoriesSignatureCache, newSignatures)) {
        _userStoriesCache
          ..clear()
          ..addAll(newStoriesCache);
        _userStoriesSignatureCache
          ..clear()
          ..addAll(newSignatures);

        _storyUpdatesController.add(Map.from(_userStoriesCache));

        if (kDebugMode) {
          print('Story status refreshed: ${stories.length} users have stories');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing story status: $e');
      }
    }
  }

  String _signatureOfUserStory(UserStoryModel u) {
    final sb = StringBuffer();
    sb.write(u.userData.id);
    sb.write('|');
    for (final s in u.stories) {
      sb
        ..write(s.id)
        ..write(':')
        ..write(s.viewedByMe ? '1' : '0')
        ..write(':')
        ..write(s.updatedAt)
        ..write(',');
    }
    return sb.toString();
  }

  /// Force refresh story status (called when stories are viewed)
  Future<void> forceRefreshStoryStatus() async {
    await _refreshStoryStatus();
  }

  /// Force refresh live status (called when app resumes or manually requested)
  Future<void> forceRefreshLiveStatus() async {
    await _refreshLiveStatus();
  }

  /// Refresh only current user's stories and broadcast immediately.
  /// Use this after a successful upload to avoid waiting for the periodic poll.
  Future<void> refreshMyStories() async {
    try {
      final myStories = await _storyApiService.getMyStories();
      if (myStories != null) {
        _userStoriesCache[myStories.userData.id] = myStories;
        _storyUpdatesController.add(Map.from(_userStoriesCache));
        if (kDebugMode) {
          print('Refreshed my stories and broadcasted instantly');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing my stories: $e');
      }
    }
  }

  /// Refresh live status from API (placeholder - implement with actual live API)
  Future<void> _refreshLiveStatus() async {
    try {
      if (!GetIt.I.isRegistered<LiveStreamApiService>()) {
        // Live stream service not available on this platform (e.g. web), skip
        return;
      }

      final liveApi = GetIt.I.get<LiveStreamApiService>();
      final streams = await liveApi.getLiveStreams(status: 'live', page: 1, limit: 50);

      final newLiveUsers = <String>{};
      final newLiveUserToStreamId = <String, String>{};
      
      for (final s in streams) {
        // Primary ID from stream
        newLiveUsers.add(s.streamerId);
        newLiveUserToStreamId[s.streamerId] = s.id;

        // Fallback to base user id from embedded streamerData if different
        final embeddedId = s.streamerData.id;
        if (embeddedId.isNotEmpty) {
          newLiveUsers.add(embeddedId);
          newLiveUserToStreamId[embeddedId] = s.id;
        }
      }

      // Only update and notify if there are actual changes
      if (!_setsEqual(_liveUsersCache, newLiveUsers)) {
        _liveUsersCache.clear();
        _liveUsersCache.addAll(newLiveUsers);
        _liveUserToStreamId.clear();
        _liveUserToStreamId.addAll(newLiveUserToStreamId);
        
        // Notify listeners only when there are changes
        _liveStatusController.add(Set.from(_liveUsersCache));

        if (kDebugMode) {
          print('Live status refreshed: ${_liveUsersCache.length} users are live');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing live status: $e');
      }
    }
  }

  /// Helper method to compare two sets for equality
  bool _setsEqual<T>(Set<T> set1, Set<T> set2) {
    if (set1.length != set2.length) return false;
    return set1.containsAll(set2) && set2.containsAll(set1);
  }

  /// Helper method to compare two maps for equality
  bool _mapsEqual<K, V>(Map<K, V> map1, Map<K, V> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) {
        return false;
      }
    }
    return true;
  }

  /// Check if user has unviewed story
  bool hasUnviewedStory(String userId) {
    final userStory = _userStoriesCache[userId];
    if (userStory == null || userStory.stories.isEmpty) {
      return false;
    }

    // Check if any story is not viewed by me
    return userStory.stories.any((story) => !story.viewedByMe);
  }

  /// Check if user is currently live
  bool isUserLive(String userId) {
    return _liveUsersCache.contains(userId);
  }

  /// Get current live stream id for a user, if any
  String? getLiveStreamIdForUser(String userId) {
    return _liveUserToStreamId[userId];
  }

  /// Immediately mark a user as live with the given stream id and broadcast
  void setUserLiveNow({required String userId, required String streamId}) {
    _liveUsersCache.add(userId);
    _liveUserToStreamId[userId] = streamId;
    _liveStatusController.add(Set.from(_liveUsersCache));
    if (kDebugMode) {
      print('setUserLiveNow -> user:$userId stream:$streamId');
    }
  }

  /// Immediately mark a user as not live and broadcast
  void setUserLiveEnded({required String userId}) {
    _liveUsersCache.remove(userId);
    _liveUserToStreamId.remove(userId);
    _liveStatusController.add(Set.from(_liveUsersCache));
    if (kDebugMode) {
      print('setUserLiveEnded -> user:$userId');
    }
  }


  /// Get user story model
  UserStoryModel? getUserStory(String userId) {
    return _userStoriesCache[userId];
  }

  /// Get all user stories from cache
  List<UserStoryModel> getAllUserStories() {
    return _userStoriesCache.values.toList();
  }

  /// Mark story as viewed
  Future<void> markStoryAsViewed(String storyId) async {
    try {
      // Optimistically apply seen state before the server round-trip
      _optimisticSeenStoryIds.add(storyId);

      // Update local cache - mark story as viewed
      bool storyUpdated = false;
      for (final userStory in _userStoriesCache.values) {
        for (int i = 0; i < userStory.stories.length; i++) {
          if (userStory.stories[i].id == storyId) {
            // Create updated story with viewedByMe = true
            final updatedStory = StoryModel(
              id: userStory.stories[i].id,
              userId: userStory.stories[i].userId,
              content: userStory.stories[i].content,
              backgroundColor: userStory.stories[i].backgroundColor,
              caption: userStory.stories[i].caption,
              att: userStory.stories[i].att,
              expireAt: userStory.stories[i].expireAt,
              createdAt: userStory.stories[i].createdAt,
              updatedAt: userStory.stories[i].updatedAt,
              storyType: userStory.stories[i].storyType,
              fontType: userStory.stories[i].fontType,
              viewedByMe: true,
              viewsCount: userStory.stories[i].viewsCount,
            );

            // Update the story in the list
            userStory.stories[i] = updatedStory;
            storyUpdated = true;
            break;
          }
        }
      }

      // IMMEDIATELY broadcast the updated cache to trigger UI updates
      if (storyUpdated) {
        _storyUpdatesController.add(Map.from(_userStoriesCache));
        if (kDebugMode) {
          print('Story status broadcasted immediately for real-time UI update');
        }
      }

      // Persist seen state on server
      await _storyApiService.setSeen(storyId);

      // Notify Story Tab to refresh its data
      await _notifyStoryTabRefresh();
      
      // Then force refresh to get latest data from server
      await forceRefreshStoryStatus();

      if (kDebugMode) {
        print('Story marked as viewed: $storyId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error marking story as viewed: $e');
      }
    }
  }

  /// Mark all stories of a user as viewed
  Future<void> markUserStoriesAsViewed(String userId) async {
    final userStory = _userStoriesCache[userId];
    if (userStory == null) return;

    try {
      // Optimistically mark all stories as seen locally
      for (final s in userStory.stories) {
        _optimisticSeenStoryIds.add(s.id);
      }

      // Mark all unviewed stories as viewed
      for (final story in userStory.stories) {
        if (!story.viewedByMe) {
          await _storyApiService.setSeen(story.id);
        }
      }

      // Update local cache immediately
      for (int i = 0; i < userStory.stories.length; i++) {
        final updatedStory = StoryModel(
          id: userStory.stories[i].id,
          userId: userStory.stories[i].userId,
          content: userStory.stories[i].content,
          backgroundColor: userStory.stories[i].backgroundColor,
          caption: userStory.stories[i].caption,
          att: userStory.stories[i].att,
          expireAt: userStory.stories[i].expireAt,
          createdAt: userStory.stories[i].createdAt,
          updatedAt: userStory.stories[i].updatedAt,
          storyType: userStory.stories[i].storyType,
          fontType: userStory.stories[i].fontType,
          viewedByMe: true, // Mark as viewed
          viewsCount: userStory.stories[i].viewsCount,
        );
        userStory.stories[i] = updatedStory;
      }

      // IMMEDIATELY broadcast the updated cache to trigger UI updates
      _storyUpdatesController.add(Map.from(_userStoriesCache));
      if (kDebugMode) {
        print('User stories status broadcasted immediately for real-time UI update');
      }

      // Notify Story Tab to refresh its data
      await _notifyStoryTabRefresh();
      
      // Then force refresh to get latest data from server
      await forceRefreshStoryStatus();

      if (kDebugMode) {
        print('All stories marked as viewed for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error marking user stories as viewed: $e');
      }
    }
  }

  /// Notify Story Tab to refresh its data
  Future<void> _notifyStoryTabRefresh() async {
    try {
      // Ensure StoryTabController is registered before access (avoid GetIt crash)
      if (!GetIt.I.isRegistered<StoryTabController>()) {
        GetIt.I.registerLazySingleton<StoryTabController>(() => StoryTabController());
      }
      final storyTabController = GetIt.I.get<StoryTabController>();

      // Use forceRefreshStories which includes API refresh and categorization
      await storyTabController.forceRefreshStories();

      if (kDebugMode) {
        print('Story Tab notified to refresh and recategorize');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error notifying Story Tab refresh: $e');
      }
    }
  }

  /// Add user to live status
  void addLiveUser(String userId) {
    _liveUsersCache.add(userId);
    _liveStatusController.add(Set.from(_liveUsersCache));
  }

  /// Remove user from live status
  void removeLiveUser(String userId) {
    _liveUsersCache.remove(userId);
    _liveStatusController.add(Set.from(_liveUsersCache));
  }

  /// Dispose the service
  void dispose() {
    _refreshTimer?.cancel();
    _storyUpdatesController.close();
    _liveStatusController.close();
    _isInitialized = false;
  }
}
