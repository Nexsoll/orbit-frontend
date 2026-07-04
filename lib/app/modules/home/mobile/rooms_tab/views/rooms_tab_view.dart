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
import 'package:super_up/app/core/api_service/election/election_api_service.dart';
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
import '../../../settings_modules/wallet/views/wallet_page.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _isRecording = false;
  bool _isMenuOpen = false;
  _ChatListFilter _selectedChatFilter = _ChatListFilter.all;
  late final AnimationController _drawerAnimationController;
  late final Animation<Offset> _drawerSlideAnimation;
  int? _dismissedAnnouncementUpdatedAt;
  List<Map<String, dynamic>> _activeElections = [];
  bool _loadingElections = false;
  final Set<String> _expandedElections = {};

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
        .where((event) =>
            event is VInsertMessageEvent || event is VUpdateMessageEvent)
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
      _loadElections();

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

  Future<void> _loadElections() async {
    if (VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name) == null) {
      return;
    }
    if (mounted) {
      setState(() {
        _loadingElections = true;
      });
    }
    try {
      final list = await ElectionApiService.I.getActiveElections();
      if (mounted) {
        setState(() {
          _activeElections = list;
          _loadingElections = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingElections = false;
        });
      }
    }
  }

  Future<void> _voteElection(String electionId, String optionId) async {
    try {
      final updatedResult = await ElectionApiService.I.vote(
        electionId: electionId,
        optionId: optionId,
      );
      if (mounted) {
        setState(() {
          final index = _activeElections.indexWhere((e) => e['_id'] == electionId);
          if (index != -1) {
            _activeElections[index] = updatedResult;
          }
        });
      }
    } catch (e) {
      VAppAlert.showErrorSnackBarWithoutContext(message: 'Failed to vote: $e');
    }
  }

  Future<void> _removeElectionVote(String electionId) async {
    try {
      final updatedResult = await ElectionApiService.I.removeVote(
        electionId: electionId,
      );
      if (mounted) {
        setState(() {
          final index = _activeElections.indexWhere((e) => e['_id'] == electionId);
          if (index != -1) {
            _activeElections[index] = updatedResult;
          }
        });
      }
    } catch (e) {
      VAppAlert.showErrorSnackBarWithoutContext(message: 'Failed to remove vote: $e');
    }
  }

  String? _getMyVotedOptionId(Map<String, dynamic> election) {
    final myId = AppAuth.myId;
    if (myId == null) return null;
    final options = election['options'] as List? ?? [];
    for (final opt in options) {
      final voters = (opt['voters'] as List? ?? []).cast<String>();
      if (voters.contains(myId)) {
        return opt['id'] as String?;
      }
    }
    return null;
  }

  Widget _buildElectionBanners() {
    if (_activeElections.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _activeElections.map((election) {
        final electionId = election['_id'] as String;
        final question = election['question'] as String? ?? '';
        final options = (election['options'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        
        final votedOptionId = _getMyVotedOptionId(election);
        final hasVoted = votedOptionId != null;

        if (hasVoted && !_expandedElections.contains(electionId)) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF1E1E24) : const Color(0xFFF9F6F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFB48648).withOpacity(0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedElections.add(electionId);
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.how_to_vote,
                      color: Color(0xFFB48648),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Election: $question (Voted)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'View Results',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB48648),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFFB48648),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final totalVotes = options.fold<int>(0, (sum, opt) => sum + (opt['count'] as int? ?? 0));
        final displayTotal = totalVotes == 0 ? 1 : totalVotes;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF1E1E24) : const Color(0xFFF9F6F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFB48648).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.how_to_vote,
                    color: Color(0xFFB48648),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Active Election',
                    style: TextStyle(
                      color: Color(0xFFB48648),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (hasVoted) ...[
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 20, color: Color(0xFFB48648)),
                      onPressed: () {
                        setState(() {
                          _expandedElections.remove(electionId);
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _removeElectionVote(electionId),
                      icon: const Icon(Icons.undo, size: 14, color: Colors.redAccent),
                      label: const Text(
                        'Remove Vote',
                        style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                question,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.isDark ? Colors.white : const Color(0xFF2C2C2C),
                ),
              ),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final optId = opt['id'] as String;
                final text = opt['text'] as String? ?? '';
                final count = opt['count'] as int? ?? 0;
                final isSelected = votedOptionId == optId;
                final percentage = (count / displayTotal) * 100;
                final fraction = count / displayTotal;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _voteElection(electionId, optId),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFB48648)
                              : (context.isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        children: [
                          if (hasVoted)
                            Positioned.fill(
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: fraction.clamp(0, 1),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB48648).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: context.isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (hasVoted) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${percentage.toStringAsFixed(0)}% ($count)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? const Color(0xFFB48648) : Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$totalVotes total votes',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showElectionVoters(election),
                    child: const Text(
                      'View all votes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB48648),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showElectionVoters(Map<String, dynamic> election) {
    final question = election['question'] as String? ?? 'Election';
    final options = (election['options'] as List? ?? []).cast<Map>();

    showCupertinoModalPopup(
      context: context,
      builder: (_) {
        return CupertinoActionSheet(
          title: Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          message: SizedBox(
            height: 380,
            child: Material(
              color: Colors.transparent,
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (ctx, i) {
                  final o = options[i];
                  final voterProfiles = (o['voterProfiles'] as List? ?? []).cast<Map>();
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFB48648),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${o['text']} • ${o['count']} votes',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (voterProfiles.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: Text(
                              'No votes yet',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: voterProfiles.map((p) {
                                final name = (p['name'] ?? 'User').toString();
                                final image = p['image'] as String?;
                                
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: context.isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: context.isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (image != null && image.isNotEmpty) ...[
                                        CircleAvatar(
                                          radius: 8,
                                          backgroundImage: NetworkImage(image),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: context.isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Divider(color: Colors.grey.withOpacity(0.2)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
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
      unawaited(_loadElections());

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
                          onTap: () => context.toPage(const WalletPage()),
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
                                  Icons.account_balance_wallet,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Wallet',
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
                      CupertinoIcons.person,
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
                _buildElectionBanners(),
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
                        onScreenRecordPress: null,
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
              child: Image.asset(
                'assets/ai-logo.png',
                width: 40,
                height: 40,
              ),
            ),
          ),
          // Stop Screen Recording Floating Panel
          if (_isRecording)
            Positioned(
              bottom: 150,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFB48648), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _PulsingRecordDot(),
                      const SizedBox(width: 10),
                      const Text(
                        'REC',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 16,
                        width: 1,
                        color: Colors.white30,
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          backgroundColor: Colors.red.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _stopScreenRecording,
                        icon: const Icon(Icons.stop, color: Colors.white, size: 16),
                        label: const Text(
                          'Stop',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
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

  void _navigateToJobs(BuildContext context) {
    context.toPage(const JobsHomeView());
  }

  void _navigateToMusic(BuildContext context) {
    context.toPage(const MusicHomeView());
  }

  void _navigateToTickets(BuildContext context) {
    context.toPage(const TicketsHomeView());
  }

  // ignore: unused_element
  Future<void> _startScreenRecording() async {
    if (_isRecording) return;

    // Check gallery permission first
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        if (mounted) {
          VAppAlert.showErrorSnackBar(
            context: context,
            message: 'Gallery permission is required to save recording',
          );
        }
        return;
      }
    }

    // Request notification permission for the foreground service notification on Android 13+
    await Permission.notification.request();

    try {
      if (mounted) {
        VAppAlert.showLoading(context: context, message: 'Preparing recorder...');
      }

      final fileName = 'orbit_record_${DateTime.now().millisecondsSinceEpoch}';
      final started = await FlutterScreenRecording.startRecordScreen(
        fileName,
        titleNotification: 'Orbit Screen Recording',
        messageNotification: 'Recording is in progress...',
      );

      if (mounted) {
        context.pop(); // close loader
      }

      if (started == true) {
        setState(() {
          _isRecording = true;
        });
        if (mounted) {
          VAppAlert.showSuccessSnackBar(
            context: context,
            message: 'Recording started!',
          );
        }
      } else {
        if (mounted) {
          VAppAlert.showErrorSnackBar(
            context: context,
            message: 'Could not start screen recording',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        context.pop(); // close loader
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Error starting recording: $e',
        );
      }
    }
  }

  Future<void> _stopScreenRecording() async {
    if (!_isRecording) return;

    try {
      if (mounted) {
        VAppAlert.showLoading(context: context, message: 'Saving video to gallery...');
      }

      final String path = await FlutterScreenRecording.stopRecordScreen;

      if (path.isNotEmpty) {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          final granted = await Gal.requestAccess();
          if (!granted) {
            if (mounted) {
              context.pop(); // close loader
              VAppAlert.showErrorSnackBar(
                context: context,
                message: 'Gallery permission is required to save recording',
              );
            }
            setState(() {
              _isRecording = false;
            });
            return;
          }
        }

        await Gal.putVideo(path);

        if (mounted) {
          context.pop(); // close loader
          VAppAlert.showSuccessSnackBar(
            context: context,
            message: 'Recording saved to gallery!',
          );
        }
      } else {
        if (mounted) {
          context.pop(); // close loader
          VAppAlert.showErrorSnackBar(
            context: context,
            message: 'Recording path was empty',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        context.pop(); // close loader
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Error saving video: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

class _PulsingRecordDot extends StatefulWidget {
  const _PulsingRecordDot();

  @override
  State<_PulsingRecordDot> createState() => _PulsingRecordDotState();
}

class _PulsingRecordDotState extends State<_PulsingRecordDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8 + (4 * _controller.value),
          height: 8 + (4 * _controller.value),
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.5 * (1 - _controller.value)),
                blurRadius: 8,
                spreadRadius: 4 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
