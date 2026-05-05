// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:get_it/get_it.dart';
import '../../services/live_stream_api_service.dart';

import '../../models/live_stream_participant_model.dart' as participant_model;
import '../../controllers/live_stream_controller.dart';

class ParticipantsSheet extends StatefulWidget {
  final String streamId;
  final bool isStreamer;
  final LiveStreamController controller;

  const ParticipantsSheet({
    super.key,
    required this.streamId,
    required this.isStreamer,
    required this.controller,
  });

  @override
  State<ParticipantsSheet> createState() => _ParticipantsSheetState();
}

class _ParticipantsSheetState extends State<ParticipantsSheet> {
  List<participant_model.LiveStreamParticipantModel> participants = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _inviteToCohost(
      participant_model.LiveStreamParticipantModel participant) async {
    try {
      final api = GetIt.I.get<LiveStreamApiService>();
      await api.inviteUserToStream(
        streamId: widget.streamId,
        userId: participant.userId,
        requestType: 'cohost',
      );

      if (mounted) {
        VAppAlert.showSuccessSnackBar(
          message: 'Invited ${participant.userData.fullName} to co-host',
          context: context,
        );
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          message: 'Failed to invite: $e',
          context: context,
        );
      }
    }
  }

  Future<void> _loadParticipants() async {
    try {
      final result = await widget.controller.getParticipants(widget.streamId);
      setState(() {
        participants = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Participants',
                  style: context.cupertinoTextTheme.navTitleTextStyle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${participants.length}',
                  style: context.cupertinoTextTheme.textStyle.copyWith(
                    color: CupertinoColors.systemGrey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Participants list
          Expanded(
            child: isLoading
                ? const Center(
                    child: CupertinoActivityIndicator(),
                  )
                : participants.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: participants.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          color: CupertinoColors.systemGrey5,
                        ),
                        itemBuilder: (context, index) {
                          final participant = participants[index];
                          return _buildParticipantItem(participant);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.person_2,
            size: 48,
            color: CupertinoColors.systemGrey3,
          ),
          const SizedBox(height: 16),
          Text(
            'No participants yet',
            style: context.cupertinoTextTheme.textStyle.copyWith(
              color: CupertinoColors.systemGrey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantItem(
      participant_model.LiveStreamParticipantModel participant) {
    final isHost = participant.role == 'host';
    final isCurrentUser = participant.userId == widget.controller.currentUserId;

    return CupertinoListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage:
                NetworkImage(_getFullImageUrl(participant.userData.userImage)),
            backgroundColor: CupertinoColors.systemGrey5,
          ),
          if (isHost)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemYellow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.star_fill,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              participant.userData.fullName,
              style: context.cupertinoTextTheme.textStyle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: CupertinoColors.systemYellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Host',
                style: context.cupertinoTextTheme.textStyle.copyWith(
                  fontSize: 12,
                  color: CupertinoColors.systemYellow,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        'Joined ${_formatJoinTime(participant.joinedAt)}',
        style: context.cupertinoTextTheme.textStyle.copyWith(
          fontSize: 14,
          color: CupertinoColors.systemGrey,
        ),
      ),
      trailing: widget.isStreamer && !isHost && !isCurrentUser
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showParticipantActions(participant),
              child: const Icon(
                CupertinoIcons.ellipsis,
                color: CupertinoColors.systemGrey,
              ),
            )
          : null,
    );
  }

  String _formatJoinTime(DateTime joinedAt) {
    final now = DateTime.now();
    final difference = now.difference(joinedAt);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  void _showParticipantActions(
      participant_model.LiveStreamParticipantModel participant) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(participant.userData.fullName),
        message: const Text('Choose an action'),
        actions: [
          if (widget.isStreamer && participant.role == 'viewer')
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _inviteToCohost(participant);
              },
              child: const Text(
                'Invite to Co-host',
                style: TextStyle(color: CupertinoColors.activeBlue),
              ),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _removeParticipant(participant);
            },
            child: const Text(
              'Remove from Stream',
              style: TextStyle(color: CupertinoColors.systemOrange),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _banParticipant(participant);
            },
            isDestructiveAction: true,
            child: const Text('Ban from Stream'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _removeParticipant(
      participant_model.LiveStreamParticipantModel participant) async {
    try {
      await widget.controller.removeParticipant(
        streamId: widget.streamId,
        participantId: participant.id,
        reason: 'Removed by host',
      );

      // Remove from local list
      setState(() {
        participants.removeWhere((p) => p.id == participant.id);
      });

      // Show success message
      if (mounted) {
        VAppAlert.showSuccessSnackBar(
          message: '${participant.userData.fullName} has been removed',
          context: context,
        );
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          message: 'Failed to remove participant: $e',
          context: context,
        );
      }
    }
  }

  Future<void> _banParticipant(
      participant_model.LiveStreamParticipantModel participant) async {
    try {
      await widget.controller.banParticipant(
        streamId: widget.streamId,
        participantId: participant.id,
        reason: 'Banned by host',
        duration: 'permanent',
      );

      // Remove from local list
      setState(() {
        participants.removeWhere((p) => p.id == participant.id);
      });

      // Show success message
      if (mounted) {
        VAppAlert.showSuccessSnackBar(
          message: '${participant.userData.fullName} has been banned',
          context: context,
        );
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          message: 'Failed to ban participant: $e',
          context: context,
        );
      }
    }
  }

  String _getFullImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl; // Already a full URL
    }
    // Construct full URL: baseMediaUrl + imageUrl
    return '${SConstants.baseMediaUrl}$imageUrl';
  }
}
