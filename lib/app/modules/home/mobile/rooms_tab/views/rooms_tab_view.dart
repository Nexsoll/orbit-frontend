// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:super_up/app/core/widgets/storage_warning_banner.dart';
import 'package:super_up/app/core/services/storage_warning_service.dart';
import 'package:super_up/app/core/services/story_status_service.dart';
import 'package:super_up/app/core/services/user_verification_service.dart';
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';
import 'package:super_up/app/core/models/story/story_model.dart';
import 'package:super_up/v_chat_v2/translations.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_room_page/v_chat_room_page.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'dart:async';
import '../controllers/rooms_tab_controller.dart';
import '../../../../story/view/story_view.dart';
import '../../story_tab/controllers/story_tab_controller.dart';
import '../../../../live_stream/controllers/watch_live_controller.dart';
import '../../../../live_stream/views/live_stream_view.dart';
import '../../settings_tab/views/settings_tab_view.dart';
import '../../../../ride/views/orbit_ride_view.dart';
import '../../../../driver/views/driver_dashboard_view.dart';
import '../../../../../core/api_service/drivers/drivers_api_service.dart';
import '../../../../../core/services/ride_mode_service.dart';
import '../../../../jobs/views/jobs_home_view.dart';
import '../../../../music/views/music_home_view.dart';
import 'package:super_up/app/core/widgets/app_logo.dart';
import '../../../../marketplace/views/marketplace_splash_view.dart';
import '../../../../tickets/views/tickets_home_view.dart';
import '../../../../send_money/views/send_money_user_picker.dart';

class RoomsTabView extends StatefulWidget {
  const RoomsTabView({super.key});

  @override
  State<RoomsTabView> createState() => _RoomsTabViewState();
}

enum _ChatListFilter { all, unread }

class _RoomsTabViewState extends State<RoomsTabView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final RoomsTabController controller;
  AppConfigModel get config => VAppConfigController.appConfig;
  late final StoryStatusService _storyStatusService;
  late final UserVerificationService _verificationService;
  late final ValueNotifier<bool> _hasUnreadGroupsOrChannels;
  late final ValueNotifier<bool> _hasUnreadMarket;
  StreamSubscription? _storyUpdatesSubscription;
  StreamSubscription? _liveStatusSubscription;
  StreamSubscription<VMessageEvents>? _messageEventsSubscription;
  int _liveRev = 0;
  int _roomsRev = 0;
  bool _isMenuOpen = false;
  _ChatListFilter _selectedChatFilter = _ChatListFilter.all;
  late final AnimationController _drawerAnimationController;
  late final Animation<Offset> _drawerSlideAnimation;
  int? _dismissedAnnouncementUpdatedAt;

  @override
  void initState() {
    super.initState();
    controller = GetIt.I.get<RoomsTabController>();
    _storyStatusService = GetIt.I.get<StoryStatusService>();
    _verificationService = GetIt.I.get<UserVerificationService>();
    _hasUnreadGroupsOrChannels = ValueNotifier<bool>(false);
    _hasUnreadMarket = ValueNotifier<bool>(false);
    _dismissedAnnouncementUpdatedAt =
        VAppPref.getIntOrNull(_announcementDismissKey());
    controller.onInit();
    _applyChatListFilter();
    WidgetsBinding.instance.addObserver(this);
    _drawerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _drawerSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _drawerAnimationController,
        curve: Curves.easeOut,
      ),
    );

    // Listen to story status changes for real-time UI updates
    _setupStoryStatusListeners();
    // Listen to global message events so chat list reflects latest messages
    _messageEventsSubscription = VChatController
        .I.nativeApi.streams.messageStream
        .where((event) => event is VInsertMessageEvent)
        .listen((event) async {
      await controller.vRoomController.refreshFromLocal();
      await _refreshGroupsChannelsUnread();
      await _refreshMarketUnread();
      if (!mounted) return;
      setState(() {
        _roomsRev++;
      });
    });

    // Initialize storage warning service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StorageWarningService().checkStorageUsage();

      unawaited(() async {
        try {
          await GetIt.I.get<VAppConfigController>().refreshAppConfig();
          if (!mounted) return;
          setState(() {});
        } catch (_) {}
      }());

      _refreshGroupsChannelsUnread();
      _refreshMarketUnread();

      // Initialize story service with actual data
      _initializeStoryService();

      // Preload verification data for visible users
      _preloadVerificationData();
    });
  }

  void _closeDrawer() {
    if (!mounted) {
      return;
    }
    _drawerAnimationController.reverse().whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMenuOpen = false;
      });
    });
  }

  Future<void> _openRide(BuildContext context) async {
    try {
      final status = await DriversApiService.myRideBanStatus();
      final isBanned = status['isBanned'] == true;
      final reason = (status['reason'] ?? '').toString().trim();
      if (isBanned) {
        if (!mounted) return;
        await showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Ride access restricted'),
            content: Text(
              reason.isEmpty ? 'You are banned from using Ride.' : reason,
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (_) {}

    final isDriver = RideModeService.instance.isDriverMode;
    if (isDriver) {
      context.toPage(const DriverDashboardView());
    } else {
      context.toPage(const OrbitRideView());
    }
  }

  String _announcementDismissKey() {
    final uid = AppAuth.myId;
    return 'announcement_dismissed_updated_at_$uid';
  }

  bool _shouldShowAnnouncementBanner() {
    final text = (config.announcementText ?? '').trim();
    if (text.isEmpty) return false;
    final updatedAt = config.announcementUpdatedAt ?? 0;
    final dismissed = _dismissedAnnouncementUpdatedAt ?? 0;
    return updatedAt > dismissed;
  }

  Future<void> _dismissAnnouncement() async {
    final updatedAt =
        config.announcementUpdatedAt ?? DateTime.now().millisecondsSinceEpoch;
    await VAppPref.setInt(_announcementDismissKey(), updatedAt);
    if (!mounted) return;
    setState(() {
      _dismissedAnnouncementUpdatedAt = updatedAt;
    });
  }

  Widget _buildAnnouncementBanner() {
    final text = (config.announcementText ?? '').trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB48648).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.campaign,
            size: 18,
            color: Color(0xFFB48648),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6B4A1D),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _dismissAnnouncement,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 18,
                color: Color(0xFFB48648),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isValidSingleChatRoom(VRoom room) {
    return room.roomType == VRoomType.s && room.peerId != null;
  }

  void _applyChatListFilter() {
    controller.vRoomController.setRoomFilter((room) {
      if (!_isValidSingleChatRoom(room)) {
        return false;
      }
      if (_selectedChatFilter == _ChatListFilter.unread) {
        return room.unReadCount > 0;
      }
      return true;
    });
  }

  void _onChatFilterChanged(_ChatListFilter filter) {
    if (_selectedChatFilter == filter) {
      return;
    }
    setState(() {
      _selectedChatFilter = filter;
    });
    _applyChatListFilter();
    unawaited(controller.vRoomController.refreshFromLocal());
  }

  Widget _buildChatFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFB48648) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? const Color(0xFFB48648)
                : CupertinoColors.systemGrey3,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : CupertinoColors.label,
          ),
        ),
      ),
    );
  }

  Widget _buildChatFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChatFilterChip(
            label: 'All',
            selected: _selectedChatFilter == _ChatListFilter.all,
            onTap: () => _onChatFilterChanged(_ChatListFilter.all),
          ),
          const SizedBox(width: 10),
          _buildChatFilterChip(
            label: 'Unread',
            selected: _selectedChatFilter == _ChatListFilter.unread,
            onTap: () => _onChatFilterChanged(_ChatListFilter.unread),
          ),
        ],
      ),
    );
  }

  bool _computeHasUnreadGroupsOrChannels(List<VRoom> rooms) {
    for (final r in rooms) {
      if ((r.roomType.isGroup || r.roomType.isBroadcast) && r.unReadCount > 0) {
        return true;
      }
    }
    return false;
  }

  bool _computeHasUnreadMarket(List<VRoom> rooms) {
    for (final r in rooms) {
      if (r.roomType == VRoomType.o && r.unReadCount > 0) {
        return true;
      }
    }
    return false;
  }

  Future<void> _refreshGroupsChannelsUnread() async {
    try {
      final rooms =
          await VChatController.I.nativeApi.local.room.getRooms(limit: 500);
      final hasUnread = _computeHasUnreadGroupsOrChannels(rooms);
      if (_hasUnreadGroupsOrChannels.value != hasUnread) {
        _hasUnreadGroupsOrChannels.value = hasUnread;
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _refreshMarketUnread() async {
    try {
      final rooms =
          await VChatController.I.nativeApi.local.room.getRooms(limit: 500);
      final hasUnread = _computeHasUnreadMarket(rooms);
      if (_hasUnreadMarket.value != hasUnread) {
        _hasUnreadMarket.value = hasUnread;
      }
    } catch (_) {
      // ignore
    }
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: const Color(0xFFB48648),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFFB48648),
        ),
      ),
      onTap: onTap,
    );
  }

  /// Handle live tap navigation
  Future<void> _handleLiveTap(VRoom room) async {
    if (room.roomType != VRoomType.s || room.peerId == null) {
      return;
    }

    final userId = room.peerId!;
    final streamId = _storyStatusService.getLiveStreamIdForUser(userId);
    if (streamId == null) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Live stream not found or ended',
      );
      return;
    }

    // Optional: quick visual feedback
    VAppAlert.showLoading(context: context);
    try {
      final watchController = GetIt.I.get<WatchLiveController>();
      final stream = await watchController.joinStream(streamId);
      if (!mounted) return;
      context.pop(); // close loading
      if (stream != null) {
        context.toPage(
          LiveStreamView(
            stream: stream,
            isStreamer: false,
          ),
        );
      } else {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Unable to join live stream',
        );
      }
    } catch (e) {
      if (!mounted) return;
      context.pop();
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Failed to open live stream',
      );
    }
  }

  void _initializeStoryService() {
    // Initialize the story status service to load actual story data
    _storyStatusService.initialize();

    if (kDebugMode) {
      print('Story status service initialized with actual data');
    }
  }

  /// Preload verification data for users in chat list
  void _preloadVerificationData() async {
    // We'll preload verification data when the VChatPage renders
    // This is handled in the StreamBuilder where we have access to room data
  }

  /// Setup listeners for real-time story status updates
  void _setupStoryStatusListeners() {
    // Listen to story updates
    _storyUpdatesSubscription =
        _storyStatusService.storyUpdates.listen((storyUpdates) {
      if (mounted) {
        setState(() {
          // Trigger UI rebuild when story status changes
        });
        if (kDebugMode) {
          print('Story updates received, refreshing chats UI');
        }
      }
    });

    // Listen to live status updates with debouncing to prevent excessive rebuilds
    _liveStatusSubscription = _storyStatusService.liveStatusUpdates
        .distinct() // Only emit when the set actually changes
        .listen((liveUsers) {
      if (mounted) {
        setState(() {
          // Trigger UI rebuild when live status changes
          _liveRev++;
        });
        if (kDebugMode) {
          print('Live status updates received, refreshing chats UI');
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check storage when app comes back to foreground
      StorageWarningService().checkStorageUsage();

      unawaited(() async {
        try {
          await GetIt.I.get<VAppConfigController>().refreshAppConfig();
          if (!mounted) return;
          setState(() {});
        } catch (_) {}
      }());

      // Force a story refresh to reflect any external updates instantly
      unawaited(_storyStatusService.forceRefreshStoryStatus());

      // Force a live refresh so red rings appear instantly after returning
      unawaited(_storyStatusService.forceRefreshLiveStatus());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _storyUpdatesSubscription?.cancel();
    _liveStatusSubscription?.cancel();
    _messageEventsSubscription?.cancel();
    _hasUnreadGroupsOrChannels.dispose();
    _hasUnreadMarket.dispose();
    _drawerAnimationController.dispose();
    super.dispose();
  }

  /// Check if user has unviewed story
  bool _hasUnviewedStory(String userId) {
    // For single chat rooms, use the peer ID
    return _storyStatusService.hasUnviewedStory(userId);
  }

  /// Check if user is currently live
  bool _isUserLive(String userId) {
    // For single chat rooms, use the peer ID
    return _storyStatusService.isUserLive(userId);
  }

  /// Check if user is verified
  bool _isUserVerified(String userId) {
    // Use the verification service to check if user is verified
    return _verificationService.isUserVerifiedSync(userId);
  }

  /// Handle story tap navigation
  void _handleStoryTap(VRoom room) {
    if (room.roomType != VRoomType.s || room.peerId == null) {
      return;
    }

    final userStory = _storyStatusService.getUserStory(room.peerId!);
    final allStories = _storyStatusService.getAllUserStories();

    if (userStory != null && userStory.stories.isNotEmpty) {
      final initialIndex = allStories.indexOf(userStory);

      // Navigate to story view
      context.toPage(
        StoryViewpage(
          userStoryModels: allStories,
          initialUserIndex: initialIndex != -1 ? initialIndex : 0,
          onComplete: (completedStoryModel) async {
            // Mark all stories as viewed when story viewing is complete
            await _storyStatusService.markUserStoriesAsViewed(room.peerId!);
            // Update StoryTabController immediately for real-time UI on Stories tab
            try {
              final storyTabController = GetIt.I.get<StoryTabController>();
              for (final s in completedStoryModel.stories) {
                storyTabController.markStoryAsViewed(s.id);
              }
            } catch (_) {}

            // Refresh the UI to update story indicators
            if (mounted) {
              setState(() {});
            }
          },
          onDelete: null,
          onStoryViewed: (storyId) async {
            // Mark individual story as viewed
            await _storyStatusService.markStoryAsViewed(storyId);
            // Update StoryTabController immediately
            try {
              final storyTabController = GetIt.I.get<StoryTabController>();
              storyTabController.markStoryAsViewed(storyId);
            } catch (_) {}

            // Refresh the UI to update story indicators
            if (mounted) {
              setState(() {});
            }
          },
        ),
      );
    } else {
      // Show placeholder message
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'No stories available for ${room.realTitle}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                CupertinoSliverNavigationBar(
                  transitionBetweenRoutes: false, // 👈 disables Hero animation
                  padding: const EdgeInsetsDirectional.only(start: 7, end: 12),
                  largeTitle: Row(
                    children: [
                      Text(
                        S.of(context).chats.capitalize(),
                        style: context.cupertinoTextTheme.textStyle.copyWith(
                          fontSize: 25,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: GestureDetector(
                          onTap: _onSendMoneyTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB48648),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wallet,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Send Money',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  leading: CupertinoButton(
                    onPressed: () => _openRide(context),
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFE2A7),
                            Color(0xFFB48648),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            offset: Offset(0, 3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.car_detailed,
                              size: 16,
                              color: Color(0xFFB48648),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Ride',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  trailing: CupertinoButton(
                    onPressed: () => context.toPage(const SettingsTabView()),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    child: Icon(
                      CupertinoIcons.settings,
                      size: 26,
                      color: Color(0xFFB48648),
                    ),
                  ),
                  middle: StreamBuilder<VSocketStatusEvent>(
                      stream: VChatController
                          .I.nativeApi.streams.socketStatusStream,
                      builder: (context, snapshot) {
                        if (snapshot.data == null ||
                            snapshot.data!.isConnected) {
                          if (innerBoxIsScrolled) {
                            return Text(
                              S.of(context).chats,
                              style:
                                  context.cupertinoTextTheme.textStyle.copyWith(
                                color: const Color(0xFFB48648),
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                              ),
                            );
                          }
                          return const AppLogo();
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CupertinoActivityIndicator(),
                            const SizedBox(
                              width: 5,
                            ),
                            Text(
                              S.of(context).connecting,
                              style: context.cupertinoTextTheme.textStyle,
                            ),
                          ],
                        );
                      }),
                  backgroundColor: innerBoxIsScrolled
                      ? context.isDark
                          ? CupertinoColors.secondarySystemFill
                          : CupertinoColors.quaternarySystemFill
                      : CupertinoTheme.of(context).scaffoldBackgroundColor,
                  border: innerBoxIsScrolled
                      ? Border(
                          bottom: BorderSide(
                            color: context.isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : const Color(0x4D000000),
                            width: 0.1,
                          ),
                        )
                      : null,
                ),
              ];
            },
            body: Column(
              children: [
                if (_shouldShowAnnouncementBanner()) _buildAnnouncementBanner(),
                const StorageWarningBanner(),
                Expanded(
                  child: StreamBuilder<Map<String, UserStoryModel>>(
                    stream: _storyStatusService.storyUpdates,
                    builder: (context, snapshot) {
                      // Set the story callback for sorting
                      controller.vRoomController
                          .setStoryCallback(_hasUnviewedStory);

                      return VChatPage(
                        key: ValueKey(
                            '${snapshot.data?.length ?? -1}-$_liveRev-$_roomsRev'),
                        language: vRoomLanguageModel(context),
                        headerWidget: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildChatFilters(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _navigateToJobs(this.context),
                                  style: ButtonStyle(
                                    padding: WidgetStateProperty.all(
                                      const EdgeInsets.symmetric(
                                        horizontal: 0,
                                        vertical: 5,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.briefcase,
                                          size: 18, color: Color(0xFFB48648)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Jobs',
                                        style: TextStyle(
                                          color: Color(0xFFB48648),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                TextButton(
                                  onPressed: () =>
                                      _navigateToMusic(this.context),
                                  style: ButtonStyle(
                                    padding: WidgetStateProperty.all(
                                      const EdgeInsets.symmetric(
                                        horizontal: 0,
                                        vertical: 5,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.music_note_2,
                                          size: 18, color: Color(0xFFB48648)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Music',
                                        style: TextStyle(
                                          color: Color(0xFFB48648),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                TextButton(
                                  onPressed: () =>
                                      _navigateToTickets(this.context),
                                  style: ButtonStyle(
                                    padding: WidgetStateProperty.all(
                                      const EdgeInsets.symmetric(
                                        horizontal: 0,
                                        vertical: 5,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.ticket,
                                          size: 18, color: Color(0xFFB48648)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Tickets',
                                        style: TextStyle(
                                          color: Color(0xFFB48648),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                TextButton(
                                  onPressed: () => context
                                      .toPage(const MarketplaceSplashView()),
                                  style: ButtonStyle(
                                    padding: WidgetStateProperty.all(
                                      const EdgeInsets.symmetric(
                                        horizontal: 0,
                                        vertical: 5,
                                      ),
                                    ),
                                  ),
                                  child: ValueListenableBuilder<bool>(
                                    valueListenable: _hasUnreadMarket,
                                    builder: (context, hasUnread, _) {
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(CupertinoIcons.bag,
                                                  size: 18,
                                                  color: Color(0xFFB48648)),
                                              SizedBox(width: 6),
                                              Text(
                                                'Market',
                                                style: TextStyle(
                                                  color: Color(0xFFB48648),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (hasUnread)
                                            Positioned(
                                              right: -4,
                                              top: -2,
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onCreateNewBroadcast: null,
                        onSearchClicked: () {
                          controller.onSearchClicked(this.context);
                        },
                        onCameraPress: () {
                          controller.onCameraPress(this.context);
                        },
                        onCreateNewGroup: null,
                        appBar: null,
                        showDisconnectedWidget: false,
                        controller: controller.vRoomController,
                        hasUnviewedStoryCallback: _hasUnviewedStory,
                        isUserLiveCallback: _isUserLive,
                        isUserVerifiedCallback: _isUserVerified,
                        onStoryTap: _handleStoryTap,
                        onLiveTap: _handleLiveTap,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // New Chat Floating Action Button
          Positioned(
            bottom: 90,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'newChatFab',
              onPressed: () => controller.onNewChatPress(context),
              backgroundColor: Colors.grey.shade800,
              child: const Icon(
                Icons.chat,
                color: Colors.white,
                size: 22,
              ),
              tooltip: S.of(context).startChat,
            ),
          ),
          // AI Assistant Floating Action Button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'aiAssistantFab',
              onPressed: () => controller.onAiAssistantPress(context),
              backgroundColor: Colors.grey.shade800,
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          if (_isMenuOpen)
            Positioned.fill(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _closeDrawer,
                    child: Container(
                      color: Colors.black54,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.7,
                      heightFactor: 1.0,
                      child: SlideTransition(
                        position: _drawerSlideAnimation,
                        child: Material(
                          color: CupertinoTheme.of(context)
                              .scaffoldBackgroundColor,
                          elevation: 8,
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                  height: 60), // Push buttons down from top
                              _buildDrawerItem(
                                icon: CupertinoIcons.car_detailed,
                                label: 'Ride',
                                onTap: () {
                                  _closeDrawer();
                                  _openRide(context);
                                },
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: CupertinoColors.separator
                                    .resolveFrom(context),
                              ),
                              _buildDrawerItem(
                                icon: CupertinoIcons.briefcase,
                                label: S.of(context).jobs,
                                onTap: () {
                                  _closeDrawer();
                                  _navigateToJobs(context);
                                },
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: CupertinoColors.separator
                                    .resolveFrom(context),
                              ),
                              _buildDrawerItem(
                                icon: CupertinoIcons.music_note_2,
                                label: 'Music',
                                onTap: () {
                                  _closeDrawer();
                                  _navigateToMusic(context);
                                },
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: CupertinoColors.separator
                                    .resolveFrom(context),
                              ),
                              _buildDrawerItem(
                                icon: CupertinoIcons.bag,
                                label: 'Market',
                                onTap: () {
                                  _closeDrawer();
                                  context.toPage(const MarketplaceSplashView());
                                },
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: CupertinoColors.separator
                                    .resolveFrom(context),
                              ),
                              _buildDrawerItem(
                                icon: CupertinoIcons.ticket,
                                label: 'Tickets',
                                onTap: () {
                                  _closeDrawer();
                                  _navigateToTickets(context);
                                },
                              ),
                            ],
                          ),
                        ),
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

  Future<void> _onSendMoneyTap() async {
    final selectedUser = await showCupertinoModalBottomSheet<SSearchUser?>(
      expand: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SendMoneyUserPicker(),
    );
    if (selectedUser == null) return;

    final receiverId = selectedUser.baseUser.id;
    final receiverName = selectedUser.baseUser.fullName;

    // Amount dialog
    final amtCtrl = TextEditingController();
    String? res;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Send to $receiverName'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: amtCtrl,
            placeholder: 'Amount (KES)',
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              res = 'ok';
              Navigator.pop(ctx);
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );

    if (res != 'ok') return;
    final amount = num.tryParse(amtCtrl.text.trim());
    if (amount == null || amount <= 0) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Enter a valid amount',
      );
      return;
    }

    // Password confirmation
    final verified = await _verifyPassword();
    if (!verified) return;

    VAppAlert.showLoading(context: context);
    try {
      await GetIt.I.get<ProfileApiService>().sendMoney(
        receiverId: receiverId,
        amount: amount,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await BalanceService.instance.init();

      // Success dialog
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Success'),
          content: Text('KES ${amount.toStringAsFixed(0)} sent to $receiverName'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final err = e.toString().toLowerCase();
      final message = err.contains('insufficient') || err.contains('balance')
          ? 'Insufficient balance. Please top up your wallet.'
          : e.toString();
      VAppAlert.showErrorSnackBar(context: context, message: message);
    }
  }

  Future<bool> _verifyPassword() async {
    final passwordCtrl = TextEditingController();
    bool confirmed = false;
    bool obscure = true;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Confirm with password'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: passwordCtrl,
              placeholder: 'Password',
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              suffix: CupertinoButton(
                padding: const EdgeInsets.only(right: 8),
                minSize: 0,
                onPressed: () => setDialogState(() => obscure = !obscure),
                child: Icon(
                  obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                  size: 18,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                confirmed = true;
                Navigator.pop(ctx);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    if (!confirmed) return false;
    final password = passwordCtrl.text.trim();
    if (password.isEmpty) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Password is required',
      );
      return false;
    }
    VAppAlert.showLoading(context: context);
    try {
      await GetIt.I.get<ProfileApiService>().passwordCheck(password);
      if (!mounted) return false;
      Navigator.of(context, rootNavigator: true).pop();
      return true;
    } catch (e) {
      if (!mounted) return false;
      Navigator.of(context, rootNavigator: true).pop();
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Incorrect password',
      );
      return false;
    }
  }

  void _navigateToJobs(BuildContext context) {
    context.toPage(const JobsHomeView());
  }

  void _navigateToMusic(BuildContext context) {
    context.toPage(const MusicHomeView());
  }

  void _navigateToTickets(BuildContext context) {
    context.toPage(const TicketsHomeView());
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
