// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:get_it/get_it.dart';

import '../../services/user_search_service.dart';

class MemberSelectionSheet extends StatefulWidget {
  final List<SBaseUser> selectedMembers;
  final Function(List<SBaseUser>) onMembersSelected;

  const MemberSelectionSheet({
    super.key,
    required this.selectedMembers,
    required this.onMembersSelected,
  });

  @override
  State<MemberSelectionSheet> createState() => _MemberSelectionSheetState();
}

class _MemberSelectionSheetState extends State<MemberSelectionSheet> {
  final TextEditingController searchController = TextEditingController();
  final UserSearchService _userSearchService = GetIt.I.get<UserSearchService>();
  List<SBaseUser> allUsers = [];
  List<SBaseUser> filteredUsers = [];
  List<SBaseUser> selectedMembers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    selectedMembers = List.from(widget.selectedMembers);
    _loadUsers();
    searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      isLoading = true;
    });

    try {
      allUsers = await _userSearchService.getContactsForInvite();
      filteredUsers = allUsers;
    } catch (e) {
      // Handle error - fallback to empty list
      allUsers = [];
      filteredUsers = [];
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterUsers() async {
    final query = searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        filteredUsers = allUsers;
      });
      return;
    }

    try {
      // Search for users with the query
      final searchResults = await _userSearchService.searchUsers(query: query);
      setState(() {
        filteredUsers = searchResults;
      });
    } catch (e) {
      // Fallback to local filtering if search fails
      setState(() {
        filteredUsers = allUsers
            .where((user) =>
                user.fullName.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  void _toggleUserSelection(SBaseUser user) {
    setState(() {
      if (selectedMembers.any((member) => member.id == user.id)) {
        selectedMembers.removeWhere((member) => member.id == user.id);
      } else {
        selectedMembers.add(user);
      }
    });
  }

  bool _isUserSelected(SBaseUser user) {
    return selectedMembers.any((member) => member.id == user.id);
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
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFFB48648))),
                ),
                const Spacer(),
                Text(
                  'Select Members',
                  style: context.cupertinoTextTheme.textStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    widget.onMembersSelected(selectedMembers);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done', style: TextStyle(color: Color(0xFFB48648))),
                ),
              ],
            ),
          ),

          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            child: CupertinoTextField(
              controller: searchController,
              placeholder: 'Search users...',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  CupertinoIcons.search,
                  color: CupertinoColors.placeholderText,
                  size: 20,
                ),
              ),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(12),
            ),
          ),

          // Selected members count
          if (selectedMembers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.person_2_fill,
                    color: Color(0xFFB48648),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${selectedMembers.length} member${selectedMembers.length == 1 ? '' : 's'} selected',
                    style: context.cupertinoTextTheme.textStyle.copyWith(
                      color: Color(0xFFB48648),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Users list
          Expanded(
            child: isLoading
                ? const Center(
                    child: CupertinoActivityIndicator(),
                  )
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final isSelected = _isUserSelected(user);

                      return CupertinoListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(user.userImageS3),
                          backgroundColor: CupertinoColors.systemGrey5,
                        ),
                        title: Text(
                          user.fullName,
                          style: context.cupertinoTextTheme.textStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                color: Color(0xFFB48648),
                                size: 24,
                              )
                            : const Icon(
                                CupertinoIcons.circle,
                                color: CupertinoColors.systemGrey3,
                                size: 24,
                              ),
                        onTap: () => _toggleUserSelection(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
