// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../services/user_search_service.dart';

class UserMultiSelectSheet extends StatefulWidget {
  final Set<String> initialSelected;

  const UserMultiSelectSheet({super.key, required this.initialSelected});

  static Future<List<String>?> show(
    BuildContext context, {
    List<String>? initialSelected,
  }) async {
    return await showCupertinoModalPopup<List<String>>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: CupertinoColors.systemBackground,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: UserMultiSelectSheet(
              initialSelected: {...?initialSelected},
            ),
          ),
        );
      },
    );
  }

  @override
  State<UserMultiSelectSheet> createState() => _UserMultiSelectSheetState();
}

class _UserMultiSelectSheetState extends State<UserMultiSelectSheet> {
  late final UserSearchService _searchService;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  final ValueNotifier<List<SBaseUser>> _users = ValueNotifier([]);
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _searchService = GetIt.I.get<UserSearchService>();
    _selectedIds = {...widget.initialSelected};
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    _isLoading.value = true;
    try {
      final users = await _searchService.getContactsForInvite();
      _users.value = users;
    } catch (_) {
      _users.value = [];
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _onSearchChanged(String q) async {
    _isLoading.value = true;
    try {
      final users = await _searchService.searchUsers(query: q);
      _users.value = users;
    } catch (_) {
      _users.value = [];
    } finally {
      _isLoading.value = false;
    }
  }

  void _toggle(String userId) {
    setState(() {
      if (_selectedIds.contains(userId)) {
        _selectedIds.remove(userId);
      } else {
        _selectedIds.add(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Select Users',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop<List<String>>(null),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CupertinoSearchTextField(
            controller: _searchController,
            placeholder: 'Search users...',
            onChanged: _onSearchChanged,
          ),
        ),

        const SizedBox(height: 8),

        // Selected count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(CupertinoIcons.person_2, size: 16),
              const SizedBox(width: 6),
              Text('${_selectedIds.length} selected'),
              const Spacer(),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: const Color(0xFFB48648),
                borderRadius: BorderRadius.circular(20),
                onPressed: () {
                  if (_selectedIds.isEmpty) {
                    Navigator.of(context).pop<List<String>>(<String>[]);
                  } else {
                    Navigator.of(context).pop<List<String>>(_selectedIds.toList());
                  }
                },
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, isLoading, _) {
              if (isLoading) {
                return const Center(child: CupertinoActivityIndicator());
              }
              return ValueListenableBuilder<List<SBaseUser>>(
                valueListenable: _users,
                builder: (context, users, _) {
                  if (users.isEmpty) {
                    return const Center(child: Text('No users found'));
                  }
                  return ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final u = users[index];
                      final selected = _selectedIds.contains(u.id);
                      return ListTile(
                        onTap: () => _toggle(u.id),
                        leading: CircleAvatar(
                          backgroundImage: u.userImage.isNotEmpty
                              ? NetworkImage(u.userImage)
                              : null,
                          child: u.userImage.isEmpty
                              ? const Icon(CupertinoIcons.person)
                              : null,
                        ),
                        title: Text(u.fullName),
                        trailing: CupertinoSwitch(
                          value: selected,
                          onChanged: (_) => _toggle(u.id),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
