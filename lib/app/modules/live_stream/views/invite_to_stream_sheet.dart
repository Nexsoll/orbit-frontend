// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../../core/api_service/profile/profile_api_service.dart';
import '../services/live_stream_api_service.dart';

class InviteToStreamSheet extends StatefulWidget {
  final String streamId;

  const InviteToStreamSheet({super.key, required this.streamId});

  @override
  State<InviteToStreamSheet> createState() => _InviteToStreamSheetState();
}

class _InviteToStreamSheetState extends State<InviteToStreamSheet> {
  final ProfileApiService _profileApiService = GetIt.I.get<ProfileApiService>();
  final LiveStreamApiService _liveApi = GetIt.I.get<LiveStreamApiService>();

  final TextEditingController _searchController = TextEditingController();

  List<SSearchUser> _users = [];
  List<SSearchUser> _filteredUsers = [];
  bool _isLoading = true;
  bool _isInviting = false;
  final Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoading = true);

      // Fetch paginated users similar to ShareLiveStreamSheet
      int page = 1;
      const int limit = 45;
      final List<SSearchUser> allUsers = [];

      while (true) {
        final filterDto = UserFilterDto(limit: limit, page: page);
        final pageUsers = await _profileApiService.appUsers(filterDto);
        if (pageUsers.isEmpty) break;
        allUsers.addAll(pageUsers);
        if (pageUsers.length < limit) break;
        page++;
      }

      setState(() {
        _users = allUsers;
        _filteredUsers = allUsers;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading users for invite: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users
            .where((u) => u.baseUser.fullName
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _inviteSelected() async {
    if (_selectedUserIds.isEmpty) {
      VAppAlert.showErrorSnackBar(
        message: 'Please select at least one user',
        context: context,
      );
      return;
    }

    setState(() => _isInviting = true);
    try {
      for (final userId in _selectedUserIds) {
        try {
          await _liveApi.inviteUserToStream(
            streamId: widget.streamId,
            userId: userId,
            requestType: 'cohost',
          );
        } catch (e) {
          if (kDebugMode) {
            print('Failed to invite $userId: $e');
          }
        }
      }

      if (mounted) {
        VAppAlert.showSuccessSnackBar(
          message: 'Invite(s) sent successfully',
          context: context,
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: CupertinoColors.separator,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                const Text(
                  'Invite to Join',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _isInviting ? null : _inviteSelected,
                  child: _isInviting
                      ? const CupertinoActivityIndicator()
                      : Text(
                          'Invite (${_selectedUserIds.length})',
                          style: TextStyle(
                            color: _selectedUserIds.isEmpty
                                ? CupertinoColors.inactiveGray
                                : CupertinoColors.activeBlue,
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Search users...',
              onChanged: _filterUsers,
            ),
          ),

          // Users list
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(
                        child: Text(
                          'No users found',
                          style: TextStyle(color: CupertinoColors.inactiveGray),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final isSelected =
                              _selectedUserIds.contains(user.baseUser.id);
                          return CupertinoListTile(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: CupertinoColors.systemGrey4,
                              backgroundImage: user.baseUser.userImage.isNotEmpty
                                  ? NetworkImage(_fullUrl(user.baseUser.userImage))
                                  : null,
                              child: user.baseUser.userImage.isEmpty
                                  ? Text(
                                      user.baseUser.fullName.isNotEmpty
                                          ? user.baseUser.fullName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : null,
                            ),
                            title: SUserNameWithBadge(
                              fullName: user.baseUser.fullName,
                              isVerified: user.hasBadge,
                            ),
                            trailing: isSelected
                                ? const Icon(CupertinoIcons.checkmark_circle_fill,
                                    color: CupertinoColors.activeBlue)
                                : const Icon(CupertinoIcons.circle,
                                    color: CupertinoColors.inactiveGray),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedUserIds.remove(user.baseUser.id);
                                } else {
                                  _selectedUserIds.add(user.baseUser.id);
                                }
                              });
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _fullUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${SConstants.baseMediaUrl}$imageUrl';
  }
}
