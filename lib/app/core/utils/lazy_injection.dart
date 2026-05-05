// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';

import '../api_service/auth/auth_api_service.dart';
import '../api_service/gifts/gifts_api_service.dart';
import '../api_service/loyalty_points/loyalty_points_api_service.dart';
import '../api_service/profile/profile_api_service.dart';
import '../api_service/story/story_api_service.dart';
import '../api_service/post/post_api_service.dart';
import '../api_service/community/community_api_service.dart';
import '../services/story_status_service.dart';
import 'package:super_up/app/modules/home/mobile/story_tab/controllers/story_tab_controller.dart';
import 'package:super_up/app/modules/music/services/articles_api_service.dart';

import '../../modules/live_stream/api/live_stream_api.dart';
import '../../modules/live_stream/services/live_stream_api_service.dart';
import '../../modules/live_stream/services/user_search_service.dart';
import '../../modules/live_stream/controllers/watch_live_controller.dart';
import '../../modules/live_stream/controllers/go_live_controller.dart';
import '../../modules/live_stream/controllers/live_stream_controller.dart';
import '../../modules/live_stream/controllers/live_stream_chat_controller.dart';
import '../../modules/live_stream/controllers/saved_lives_controller.dart';
import '../../modules/live_stream/controllers/all_saved_streams_controller.dart';

import '../app_config/app_config_controller.dart';
import '../controllers/version_checker_controller.dart';
import '../../modules/jobs/services/jobs_api_service.dart';
import '../../modules/music/services/music_api_service.dart';
import '../../modules/marketplace/services/marketplace_api_service.dart';
import '../../modules/tickets/services/tickets_api_service.dart';

import '../services/user_verification_service.dart';

void registerSingletons() {
  GetIt.I.registerSingleton<AuthApiService>(AuthApiService.init());
  GetIt.I.registerSingleton<StoryApiService>(StoryApiService.init());
  GetIt.I.registerSingleton<PostApiService>(PostApiService.init());
  GetIt.I.registerSingleton<StoryStatusService>(StoryStatusService());
  // Eagerly initialize story status periodic refresh
  GetIt.I.get<StoryStatusService>().initialize();
  GetIt.I.registerSingleton<LoyaltyPointsApiService>(
      LoyaltyPointsApiService.init());
  final ProfileApiService profileApiService = ProfileApiService.init();
  GetIt.I.registerSingleton<ProfileApiService>(profileApiService);
  // Initialize CommunityApiService; it registers itself if needed
  CommunityApiService.init();
  GetIt.I.registerSingleton<AppSizeHelper>(AppSizeHelper());
  GetIt.I.registerSingleton<VAppConfigController>(
    VAppConfigController(profileApiService),
  );
  GetIt.I.registerSingleton<GiftsApiService>(GiftsApiService.init());
  GetIt.I.registerSingleton<UserVerificationService>(UserVerificationService());
  GetIt.I.registerSingleton<JobsApiService>(JobsApiService.init());
  GetIt.I.registerSingleton<MusicApiService>(MusicApiService.init());
  GetIt.I
      .registerSingleton<MarketplaceApiService>(MarketplaceApiService.init());
  GetIt.I.registerSingleton<TicketsApiService>(TicketsApiService.init());
  GetIt.I.registerSingleton<ArticlesApiService>(ArticlesApiService.init());
  // Make StoryTabController available globally so other pages can refresh it
  GetIt.I.registerLazySingleton<StoryTabController>(() => StoryTabController());

  // Live Stream Services and Controllers (now supported on web as well)
  GetIt.I.registerSingleton<LiveStreamApi>(LiveStreamApi.create());
  GetIt.I.registerSingleton<LiveStreamApiService>(LiveStreamApiService.init());
  GetIt.I.registerSingleton<UserSearchService>(UserSearchService.init());
  GetIt.I.registerSingleton<WatchLiveController>(WatchLiveController());
  GetIt.I.registerSingleton<GoLiveController>(GoLiveController());
  GetIt.I.registerSingleton<LiveStreamController>(LiveStreamController());
  GetIt.I
      .registerSingleton<LiveStreamChatController>(LiveStreamChatController());
  GetIt.I.registerSingleton<SavedLivesController>(SavedLivesController());
  GetIt.I.registerSingleton<AllSavedStreamsController>(
      AllSavedStreamsController());

  GetIt.I.registerSingleton<VersionCheckerController>(
      VersionCheckerController(profileApiService));
}
