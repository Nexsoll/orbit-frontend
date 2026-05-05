// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import '../models/live_stream_model.dart';
import '../../../core/api_service/profile/profile_api_service.dart';

class ShareLiveStreamSheet extends StatefulWidget {
  final LiveStreamModel stream;
  final bool isHost;

  const ShareLiveStreamSheet({
    super.key,
    required this.stream,
    required this.isHost,
  });

  @override
  State<ShareLiveStreamSheet> createState() => _ShareLiveStreamSheetState();
}

class _ShareLiveStreamSheetState extends State<ShareLiveStreamSheet> {
  final ProfileApiService _profileApiService = GetIt.I.get<ProfileApiService>();
  final TextEditingController _searchController = TextEditingController();

  List<SSearchUser> _users = [];
  List<SSearchUser> _filteredUsers = [];
  bool _isLoading = true;
  bool _isSending = false;
  final Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _sharePublicLink() async {
    try {
      // Build frontend base from API base: scheme://host[:port], stripping 'api.' if present
      final api = SConstants.sApiBaseUrl;
      final host = api.host.startsWith('api.') ? api.host.substring(4) : api.host;
      final base = '${api.scheme}://$host${api.hasPort ? ':${api.port}' : ''}';
      final url = '$base/live/${widget.stream.id}';
      await Share.share(url);
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(message: e.toString(), context: context);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Future<void> _loadUsers() async {
  //   try {
  //     setState(() {
  //       _isLoading = true;
  //     });

  //     var filterDto = UserFilterDto.init();

  //     log('-======================${filterDto.toMap()}');
  //     final users = await _profileApiService.appUsers(filterDto);

  //     setState(() {
  //       _users = users;
  //       _filteredUsers = users;
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error loading users: $e');
  //     }
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }
  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      int page = 1;
      int limit = 45;
      List<SSearchUser> allUsers = [];

      while (true) {
        var filterDto = UserFilterDto(limit: limit, page: page);
        log("Fetching page $page with limit $limit");

        final pageUsers = await _profileApiService.appUsers(filterDto);

        if (pageUsers.isEmpty) {
          log('-----end page ------}');
          // No more users, stop
          break;
        }

        allUsers.addAll(pageUsers);

        if (pageUsers.length < limit) {
          log('Last page reached (${pageUsers.length} items)');
          break; // stop loop if fewer than limit
        }

        page++; // move to next page
      }

      setState(() {
        _users = allUsers;
        _filteredUsers = allUsers;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading users: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final name = user.baseUser.fullName.toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _shareWithSelectedUsers() async {
    if (_selectedUserIds.isEmpty) {
      VAppAlert.showErrorSnackBar(
        message: 'Please select at least one user to share with',
        context: context,
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final message = widget.isHost
          ? "I'm live! Come and join me 🎥✨"
          : "Join ${widget.stream.streamerData} live! 🎥";
      log('=================================            ${widget.stream.id}');
      log('=================================            ${widget.stream.streamerData}');

      for (final userId in _selectedUserIds) {
        try {
          // Create or get existing room with the user
          final room =
              await VChatController.I.nativeApi.remote.room.getPeerRoom(userId);

          // Create and send the message
          final textMessage = VTextMessage.buildMessage(
            roomId: room.id,
            content: message,
            isEncrypted: false,
            linkAtt: VLinkPreviewData(
                title: widget.stream.title,
                description: widget.stream.description ?? '',
                link: widget.stream.id),
          );

          // Insert message locally
          await VChatController.I.nativeApi.local.message
              .insertMessage(textMessage);

          // Add to upload queue to send to server
          VMessageUploaderQueue.instance.addToQueue(
            await MessageFactory.createUploadMessage(textMessage),
          );

          if (kDebugMode) {
            print('Shared live stream with user: $userId');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error sharing with user $userId: $e');
          }
        }
      }

      if (mounted) {
        VAppAlert.showSuccessSnackBar(
          message:
              'Live stream shared with ${_selectedUserIds.length} user(s)!',
          context: context,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing live stream: $e');
      }
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          message: 'Failed to share live stream',
          context: context,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 360;
                final isTiny = constraints.maxWidth < 320;
                final titleText = isTiny
                    ? 'Share'
                    : (isSmall ? 'Share Live' : 'Share Live Stream');
                final linkLabel = isSmall ? 'Link' : 'Share link';
                final shareLabel = isTiny
                    ? 'Share'
                    : 'Share (${_selectedUserIds.length})';

                return Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 0),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmall ? 4 : 8,
                              ),
                              onPressed: () => _sharePublicLink(),
                              child: Text(
                                linkLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: CupertinoColors.activeBlue,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmall ? 4 : 0,
                              ),
                              onPressed:
                                  _isSending ? null : _shareWithSelectedUsers,
                              child: _isSending
                                  ? const CupertinoActivityIndicator()
                                  : Text(
                                      shareLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                    ),
                  ],
                );
              },
            ),
          ),

          // Search bar
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
                          style: TextStyle(
                            color: CupertinoColors.inactiveGray,
                          ),
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
                              backgroundImage: user
                                      .baseUser.userImage.isNotEmpty
                                  ? NetworkImage(
                                      _getFullImageUrl(user.baseUser.userImage))
                                  : null,
                              child: user.baseUser.userImage.isEmpty
                                  ? Text(
                                      user.baseUser.fullName.isNotEmpty
                                          ? user.baseUser.fullName[0]
                                              .toUpperCase()
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
                            subtitle:
                                null, // Remove bio since it's not available
                            trailing: isSelected
                                ? const Icon(
                                    CupertinoIcons.checkmark_circle_fill,
                                    color: CupertinoColors.activeBlue,
                                  )
                                : const Icon(
                                    CupertinoIcons.circle,
                                    color: CupertinoColors.inactiveGray,
                                  ),
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

  String _getFullImageUrl(String imageUrl) {
    print('ShareLiveStreamSheet: Original imageUrl: $imageUrl');
    print(
        'ShareLiveStreamSheet: SConstants.baseMediaUrl: ${SConstants.baseMediaUrl}');

    if (imageUrl.startsWith('http')) {
      print('ShareLiveStreamSheet: Already full URL, returning: $imageUrl');
      return imageUrl; // Already a full URL
    }

    // Construct full URL: baseMediaUrl + imageUrl
    final fullUrl = '${SConstants.baseMediaUrl}$imageUrl';
    print('ShareLiveStreamSheet: Constructed full URL: $fullUrl');
    return fullUrl;
  }
}
