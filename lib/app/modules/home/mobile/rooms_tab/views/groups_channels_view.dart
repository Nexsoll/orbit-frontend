import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_room_page/v_chat_room_page.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import '../../../../chats_search/views/chats_search_view.dart';
import '../../../../../../v_chat_v2/translations.dart';
import '../../communities_tab/views/communities_tab_view.dart';

class GroupsChannelsView extends StatefulWidget {
  final VoidCallback? onCreateNewGroup;
  final VoidCallback? onCreateNewChannel;

  const GroupsChannelsView({
    super.key,
    this.onCreateNewGroup,
    this.onCreateNewChannel,
  });

  @override
  State<GroupsChannelsView> createState() => _GroupsChannelsViewState();
}

enum _GroupsChannelsFilter { all, unread, channel, group }

class _GroupsChannelsViewState extends State<GroupsChannelsView> {
  late final VRoomController _controller;
  _GroupsChannelsFilter _selectedFilter = _GroupsChannelsFilter.all;

  @override
  void initState() {
    super.initState();
    _controller = VRoomController();
    _applyRoomFilter();
  }

  void _applyRoomFilter() {
    _controller.setRoomFilter((room) {
      final isGroupOrChannel =
          room.roomType.isGroup || room.roomType.isBroadcast;
      if (!isGroupOrChannel) {
        return false;
      }

      switch (_selectedFilter) {
        case _GroupsChannelsFilter.all:
          return true;
        case _GroupsChannelsFilter.unread:
          return room.unReadCount > 0;
        case _GroupsChannelsFilter.channel:
          return room.roomType.isBroadcast;
        case _GroupsChannelsFilter.group:
          return room.roomType.isGroup;
      }
    });
  }

  void _onFilterChanged(_GroupsChannelsFilter filter) {
    if (_selectedFilter == filter) {
      return;
    }
    setState(() {
      _selectedFilter = filter;
    });
    _applyRoomFilter();
    unawaited(_controller.refreshFromLocal());
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? const Color(0xFFB48648) : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(20),
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
            color: selected ? CupertinoColors.white : CupertinoColors.label,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            selected: _selectedFilter == _GroupsChannelsFilter.all,
            onTap: () => _onFilterChanged(_GroupsChannelsFilter.all),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Unread',
            selected: _selectedFilter == _GroupsChannelsFilter.unread,
            onTap: () => _onFilterChanged(_GroupsChannelsFilter.unread),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Channel',
            selected: _selectedFilter == _GroupsChannelsFilter.channel,
            onTap: () => _onFilterChanged(_GroupsChannelsFilter.channel),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Group',
            selected: _selectedFilter == _GroupsChannelsFilter.group,
            onTap: () => _onFilterChanged(_GroupsChannelsFilter.group),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Groups/Channels'),
      ),
      child: SafeArea(
        child: VChatPage(
          controller: _controller,
          language: vRoomLanguageModel(context),
          onSearchClicked: () {
            context.toPage(const ChatsSearchView());
          },
          onCreateNewGroup: null,
          onCreateNewBroadcast: null,
          headerWidget: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilters(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      onPressed: widget.onCreateNewGroup,
                      child: const Text(
                        'Create group',
                        style: TextStyle(
                          color: Color(0xFFB48648),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      onPressed: () =>
                          context.toPage(const CommunitiesTabView()),
                      child: const Text(
                        'Communities',
                        style: TextStyle(
                          color: Color(0xFFB48648),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      onPressed: widget.onCreateNewChannel,
                      child: const Text(
                        'Create channel',
                        style: TextStyle(
                          color: Color(0xFFB48648),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          showDisconnectedWidget: false,
        ),
      ),
    );
  }
}
