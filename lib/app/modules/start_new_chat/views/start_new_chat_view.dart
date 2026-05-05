// Copyright 2025, the OrbitChat project authors.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:loadmore/loadmore.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import '../../../core/app_config/app_config_controller.dart';
import '../../../core/api_service/profile/profile_api_service.dart';

class StartNewChatView extends StatefulWidget {
  const StartNewChatView({super.key});

  @override
  State<StartNewChatView> createState() => _StartNewChatViewState();
}

class _StartNewChatViewState extends State<StartNewChatView> {
  late final ProfileApiService _profileApiService;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _users = <SSearchUser>[];
  UserFilterDto _filter = UserFilterDto.init();
  String? _selectedProfession;
  bool _isLoading = false;
  bool _isLoadMoreActive = false;
  bool _isFinishLoadMore = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _profileApiService = GetIt.I.get<ProfileApiService>();
    _fetchUsers(reset: true);
    // focus search after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _filter.page = 1;
        _users.clear();
        _isFinishLoadMore = false;
      });
    }
    try {
      final res = await _profileApiService.appUsers(_filter);
      setState(() {
        if (reset) {
          _users.clear();
        }
        _users.addAll(res);
        // Shuffle users every time the list is refreshed
        _users.shuffle();
      });
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _onLoadMore() async {
    if (_isLoadMoreActive || _isFinishLoadMore) return false;
    _isLoadMoreActive = true;
    _filter.page = _filter.page + 1;
    try {
      final res = await _profileApiService.appUsers(_filter);
      if (mounted) {
        setState(() {
          if (res.isEmpty) {
            _isFinishLoadMore = true;
          } else {
            _users.addAll(res);
          }
        });
      }
    } catch (_) {
      // ignore and stop loading more
      _isFinishLoadMore = true;
    } finally {
      _isLoadMoreActive = false;
    }
    return true;
  }

  Future<void> _showProfessionFilter(BuildContext context) async {
    final professions =
        VAppConfigController.appConfig.professions ?? SConstants.commonProfessions;
    final res = await VAppAlert.showModalSheetWithActions(
      title: 'Filter by Profession',
      context: context,
      content: [
        ModelSheetItem(title: 'All', id: 'all'),
        ...professions.map(
          (p) => ModelSheetItem(title: p, id: p),
        ),
      ],
    );
    if (!mounted || res == null) return;

    if (res.id == 'all') {
      setState(() {
        _selectedProfession = null;
      });
    } else {
      setState(() {
        _selectedProfession = res.id;
      });
    }

    _filter = UserFilterDto.init();
    _filter.profession = _selectedProfession;
    final q = _searchController.text.trim();
    if (q.isNotEmpty) {
      _filter.fullName = q;
    }
    await _fetchUsers(reset: true);
  }

  void _clearProfessionFilter() {
    setState(() {
      _selectedProfession = null;
    });
    _filter = UserFilterDto.init();
    final q = _searchController.text.trim();
    if (q.isNotEmpty) {
      _filter.fullName = q;
    }
    _fetchUsers(reset: true);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      _filter = UserFilterDto.init();
      final q = query.trim();
      if (q.isNotEmpty) {
        _filter.fullName = q;
      }
      _filter.profession = _selectedProfession;
      await _fetchUsers(reset: true);
    });
  }

  Future<void> _openChatWith(String peerId) async {
    try {
      // Open chat directly to avoid flashing the home screen before navigation
      await VChatController.I.roomApi.openChatWith(peerId: peerId);
    } catch (e) {
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        automaticallyImplyLeading: false,
        middle: const Text('New chat'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text(
            S.of(context).cancel,
            style: const TextStyle(color: Color(0xFFB48648)),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoSearchTextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      placeholder: S.of(context).search,
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showProfessionFilter(context),
                    child: const Icon(
                      CupertinoIcons.briefcase,
                      color: Color(0xFFB48648),
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedProfession != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey.shade300,
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.briefcase,
                      size: 16,
                      color: Colors.grey.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Profession: $_selectedProfession',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _clearProfessionFilter,
                      child: Icon(
                        CupertinoIcons.clear_circled_solid,
                        size: 20,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading && _users.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _fetchUsers(reset: true),
                      child: LoadMore(
                        onLoadMore: _onLoadMore,
                        isFinish: _isFinishLoadMore,
                        textBuilder: (status) => "",
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          itemBuilder: (context, index) {
                            final item = _users[index];
                            return SUserItem(
                              onTap: () => _openChatWith(item.baseUser.id),
                              baseUser: item.baseUser,
                              hasBadge: item.hasBadge,
                              subtitle: item.getUserBio,
                              trailing: const Icon(
                                CupertinoIcons.chat_bubble_2,
                                color: Color(0xFFB48648),
                              ),
                            );
                          },
                          separatorBuilder: (context, index) => Divider(
                            height: 10,
                            thickness: 1,
                            color: Colors.grey.withOpacity(.2),
                          ),
                          itemCount: _users.length,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
