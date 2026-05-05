// Copyright 2025, the OrbitChat project authors.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:loadmore/loadmore.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../../core/api_service/profile/profile_api_service.dart';

class SendMoneyUserPicker extends StatefulWidget {
  const SendMoneyUserPicker({super.key});

  @override
  State<SendMoneyUserPicker> createState() => _SendMoneyUserPickerState();
}

class _SendMoneyUserPickerState extends State<SendMoneyUserPicker> {
  late final ProfileApiService _profileApiService;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _users = <SSearchUser>[];
  UserFilterDto _filter = UserFilterDto.init();
  bool _isLoading = false;
  bool _isLoadMoreActive = false;
  bool _isFinishLoadMore = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _profileApiService = GetIt.I.get<ProfileApiService>();
    _fetchUsers(reset: true);
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
      _isFinishLoadMore = true;
    } finally {
      _isLoadMoreActive = false;
    }
    return true;
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      _filter = UserFilterDto.init();
      final q = query.trim();
      if (q.isNotEmpty) {
        _filter.fullName = q;
      }
      await _fetchUsers(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        automaticallyImplyLeading: false,
        middle: const Text('Send Money'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFFB48648)),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                focusNode: _focusNode,
                placeholder: 'Search users',
                onChanged: _onSearchChanged,
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
                        textBuilder: (status) => '',
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          itemBuilder: (context, index) {
                            final item = _users[index];
                            return SUserItem(
                              onTap: () => Navigator.of(context).pop(item),
                              baseUser: item.baseUser,
                              hasBadge: item.hasBadge,
                              subtitle: item.getUserBio,
                              trailing: const Icon(
                                CupertinoIcons.arrow_right_circle,
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
