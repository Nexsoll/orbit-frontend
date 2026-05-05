// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_platform/v_platform.dart';

import '../controllers/watch_live_controller.dart';
import '../controllers/live_stream_controller.dart';
import '../services/live_stream_api_service.dart';
import '../models/live_stream_model.dart';
import 'live_stream_view.dart';
import 'share_live_stream_sheet.dart';

class WatchLiveView extends StatefulWidget {
  const WatchLiveView({super.key});

  @override
  State<WatchLiveView> createState() => _WatchLiveViewState();
}

class _WatchLiveViewState extends State<WatchLiveView> {
  late final WatchLiveController controller;
  bool _joiningLoaderOpen = false;

  @override
  void initState() {
    super.initState();
    controller = GetIt.I.get<WatchLiveController>();
    controller.onInit();
    controller.addListener(_handlePendingApproval);
    controller.addListener(_handlePendingInvite);
  }

  void _handlePendingInvite() async {
    final invite = controller.pendingInvite;
    if (invite == null || !mounted) return;

    final requestId = invite['requestId'] as String?;
    final streamId = invite['streamId'] as String?;
    final message = invite['message'] as String? ?? 'You are invited to join the live stream';

    if (requestId == null || streamId == null) {
      controller.clearPendingInvite();
      return;
    }

    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Live Stream Invite'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('Decline'),
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final api = GetIt.I.get<LiveStreamApiService>();
                await api.respondToInvite(requestId: requestId, action: 'reject');
                if (mounted) {
                  VAppAlert.showErrorSnackBar(
                    message: 'Invite declined',
                    context: context,
                  );
                }
              } catch (e) {
                if (mounted) {
                  VAppAlert.showErrorSnackBar(
                    message: 'Failed to decline invite: ${e.toString()}',
                    context: context,
                  );
                }
              } finally {
                controller.clearPendingInvite();
              }
            },
          ),
          CupertinoDialogAction(
            child: const Text('Accept'),
            isDefaultAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final api = GetIt.I.get<LiveStreamApiService>();
                await api.respondToInvite(requestId: requestId, action: 'accept');

                // If the user is already inside this stream as a viewer, LEAVE and REJOIN as broadcaster
                // This ensures the host's onUserJoined fires and remoteUsers is populated
                final liveCtrl = GetIt.I.get<LiveStreamController>();
                if (liveCtrl.currentStream?.id == streamId && liveCtrl.agoraEngine != null) {
                  try {
                    if (kDebugMode) {
                      print('🔄 Co-host escalation: leaving channel to rejoin as broadcaster');
                    }
                    final channelName = liveCtrl.currentStream!.channelName;
                    // Leave the channel first
                    await liveCtrl.agoraEngine!.leaveChannel();
                    await Future.delayed(const Duration(milliseconds: 300));
                    
                    if (kDebugMode) {
                      print('🔄 Fetching fresh token from backend...');
                    }
                    // Update backend role and fetch fresh token for this user
                    final joinRes = await api.joinLiveStream(streamId);
                    final freshToken = joinRes['agoraToken'] as String;
                    
                    if (kDebugMode) {
                      print('🔄 Setting client role to BROADCASTER...');
                    }
                    // Rejoin as broadcaster
                    await liveCtrl.agoraEngine!.setClientRole(
                      role: ClientRoleType.clientRoleBroadcaster,
                    );
                    
                    if (kDebugMode) {
                      print('🔄 Rejoining channel as broadcaster with publish flags...');
                    }
                    await liveCtrl.agoraEngine!.joinChannel(
                      token: freshToken,
                      channelId: channelName,
                      uid: 0,
                      options: const ChannelMediaOptions(
                        clientRoleType: ClientRoleType.clientRoleBroadcaster,
                        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
                        publishCameraTrack: true,
                        publishMicrophoneTrack: true,
                        autoSubscribeVideo: true,
                        autoSubscribeAudio: true,
                      ),
                    );
                    
                    // Enable video/audio
                    try { await liveCtrl.agoraEngine!.enableVideo(); } catch (_) {}
                    await liveCtrl.agoraEngine!.muteLocalVideoStream(false);
                    await liveCtrl.agoraEngine!.muteLocalAudioStream(false);
                    if (!VPlatforms.isWeb) {
                      try { await liveCtrl.agoraEngine!.startPreview(); } catch (_) {}
                    }
                    
                    if (mounted) {
                      liveCtrl.isCameraOn.value = true;
                      liveCtrl.isMuted.value = false;
                      liveCtrl.isBroadcaster.value = true;
                      if (kDebugMode) {
                        print('✅ Co-host status updated: isBroadcaster=true, isCameraOn=true');
                      }
                    }
                    if (mounted) {
                      VAppAlert.showSuccessSnackBar(
                        message: 'You are now co-hosting',
                        context: context,
                      );
                    }
                    // Force UI rebuild to show local camera
                    if (mounted) {
                      setState(() {});
                    }
                  } catch (err) {
                    // Fallback: if escalation fails, perform a standard join flow
                    final joined = await controller.joinStream(streamId);
                    if (mounted && joined != null) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => LiveStreamView(
                            stream: joined,
                            isStreamer: false,
                          ),
                        ),
                      );
                    }
                  }
                } else {
                  // Not currently in the stream: proceed with normal join + navigate
                  final joined = await controller.joinStream(streamId);
                  if (mounted && joined != null) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => LiveStreamView(
                          stream: joined,
                          isStreamer: false,
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  VAppAlert.showErrorSnackBar(
                    message: 'Failed to accept invite: ${e.toString()}',
                    context: context,
                  );
                }
              } finally {
                controller.clearPendingInvite();
              }
            },
          ),
        ],
      ),
    );
  }

  void _handlePendingApproval() {
    final pendingApproval = controller.pendingApproval;
    if (pendingApproval != null && mounted) {
      final approved = pendingApproval['approved'] as bool;
      final message = pendingApproval['message'] as String;
      final streamId = pendingApproval['streamId'] as String;

      if (approved) {
        // Show success notification
        VAppAlert.showSuccessSnackBar(
          message: message,
          context: context,
        );

        // Auto-join the stream after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            final stream = controller.getStreamById(streamId);
            if (stream != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LiveStreamView(
                    stream: stream,
                    isStreamer: false,
                  ),
                ),
              );
            }
          }
        });
      } else {
        // Show rejection notification
        VAppAlert.showErrorSnackBar(
          message: message,
          context: context,
        );
      }

      // Clear the pending approval
      controller.clearPendingApproval();
    }
  }

  @override
  void dispose() {
    controller.removeListener(_handlePendingApproval);
    controller.removeListener(_handlePendingInvite);
    controller.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Row(
            children: [
              const Icon(CupertinoIcons.chevron_back, color: Color(0xFFB48648)),
              const SizedBox(width: 2),
              Text(S.of(context).back, style: const TextStyle(color: Color(0xFFB48648))),
            ],
          ),
        ),
        middle: Text(
          S.of(context).liveStreams,
          style: context.cupertinoTextTheme.textStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: controller.refreshStreams,
          child: const Icon(
            CupertinoIcons.refresh,
            size: 24,
            color: Color(0xFFB48648),
          ),
        ),
      ),
      child: SafeArea(
        child: ValueListenableBuilder<SLoadingState<List<LiveStreamModel>>>(
          valueListenable: controller,
          builder: (context, state, child) {
            return VAsyncWidgetsBuilder(
              loadingState: state.loadingState,
              onRefresh: controller.refreshStreams,
              successWidget: () {
                final streams = state.data;

                if (streams.isEmpty) {
                  return _buildEmptyState(context);
                }

                return RefreshIndicator(
                  onRefresh: controller.refreshStreams,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: streams.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final stream = streams[index];
                      return _buildStreamCard(context, stream);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.video_camera,
                size: 40,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              S.of(context).noLiveStreams,
              style: context.cupertinoTextTheme.textStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context).noLiveStreamsSubtitle,
              style: context.cupertinoTextTheme.textStyle.copyWith(
                fontSize: 14,
                color: CupertinoColors.systemGrey2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CupertinoButton(
              color: const Color(0xFFB48648),
              borderRadius: BorderRadius.circular(8),
              onPressed: controller.refreshStreams,
              child: Text(S.of(context).refreshBtn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamCard(BuildContext context, LiveStreamModel stream) {
    return GestureDetector(
      onTap: () => _joinStream(context, stream),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stream thumbnail/preview
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: CupertinoColors.black,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Stack(
                children: [
                  // Thumbnail or placeholder
                  if (stream.thumbnailUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: Image.network(
                        stream.thumbnailUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              CupertinoIcons.video_camera,
                              size: 48,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    )
                  else
                    const Center(
                      child: Icon(
                        CupertinoIcons.video_camera,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),

                  // Live indicator
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Viewer count
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.eye,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stream.viewerCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stream info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Streamer info
                  Row(
                    children: [
                      ClipOval(
                        child: Image.network(
                          _getFullImageUrl(stream.streamerData.userImage),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: CupertinoColors.systemGrey,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.person_fill,
                                color: Colors.white,
                                size: 20,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stream.streamerData.fullName,
                              style:
                                  context.cupertinoTextTheme.textStyle.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _formatDuration(stream.startedAt),
                              style:
                                  context.cupertinoTextTheme.textStyle.copyWith(
                                fontSize: 12,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Share button
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _showShareSheet(context, stream),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.share,
                            size: 18,
                            color: Color(0xFFB48648),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Stream title
                  Text(
                    stream.title,
                    style: context.cupertinoTextTheme.textStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (stream.description != null &&
                      stream.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      stream.description!,
                      style: context.cupertinoTextTheme.textStyle.copyWith(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(DateTime? startedAt) {
    if (startedAt == null) return 'Starting soon';

    final duration = DateTime.now().difference(startedAt);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ago';
    } else {
      return 'Just started';
    }
  }

  void _joinStream(BuildContext context, LiveStreamModel stream) async {
    // Show loading indicator
    _joiningLoaderOpen = true;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(width: 16),
            Text(S.of(context).joiningStream),
          ],
        ),
      ),
    );

    try {
      // Try to join the stream via API first to check for ban
      final result = await controller.joinStream(stream.id);

      // Close loading dialog
      if (_joiningLoaderOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _joiningLoaderOpen = false;
      }

      if (result != null && context.mounted) {
        // Successfully joined, navigate to stream view
        if (VPlatforms.isWeb) {
          // On web, use a constrained dialog that doesn't take full screen
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LiveStreamView(
                    stream: result,
                    isStreamer: false,
                  ),
                ),
              ),
            ),
          );
        } else {
          // On mobile, use normal navigation
          await context.toPage(LiveStreamView(
            stream: result,
            isStreamer: false,
          ));
        }

        // After leaving the stream, ensure any pending loader is closed
        if (_joiningLoaderOpen && context.mounted) {
          try {
            Navigator.of(context, rootNavigator: true).pop();
          } catch (_) {}
          _joiningLoaderOpen = false;
        }
      }
    } catch (error) {
      // Close loading dialog
      if (_joiningLoaderOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _joiningLoaderOpen = false;
      }

      // Show ban error dialog
      if (context.mounted) {
        String errorMessage = 'Unable to join stream';

        // Check if it's a ban error
        if (error.toString().toLowerCase().contains('banned') ||
            error
                .toString()
                .toLowerCase()
                .contains('you are banned from this stream')) {
          errorMessage = 'You are banned from this stream';
          _showErrorDialog(context, errorMessage);
        } else if (error.toString().toLowerCase().contains('forbidden')) {
          errorMessage = 'Access denied to this stream';
          _showErrorDialog(context, errorMessage);
        } else if (error.toString().toLowerCase().contains('approval') ||
            error.toString().toLowerCase().contains('need approval')) {
          // Show join request dialog for approval-required streams
          _showJoinRequestDialog(context, stream);
        } else {
          errorMessage = 'Failed to join stream: ${error.toString()}';
          _showErrorDialog(context, errorMessage);
        }
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(S.of(context).unableToJoinStream),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: Text(S.of(context).ok),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showJoinRequestDialog(BuildContext context, LiveStreamModel stream) {
    final ageController = TextEditingController();
    final amountController = TextEditingController(
      text: stream.joinPrice == null || stream.joinPrice == 0
          ? ''
          : ((stream.joinPrice! % 1 == 0)
              ? stream.joinPrice!.toStringAsFixed(0)
              : stream.joinPrice!.toStringAsFixed(2)),
    );

    showCupertinoDialog(
      context: context,
      builder: (BuildContext ctx) {
        return CupertinoAlertDialog(
          title: Text(S.of(ctx).joinRequestRequired),
          content: Column(
            children: [
              const SizedBox(height: 8),
              Text(S.of(ctx).joinRequestPrompt),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: ageController,
                placeholder: 'Your age (18+)',
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: amountController,
                placeholder: stream.hasJoinFee ? 'Amount to pay (KES)' : 'Amount to pay (optional)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(S.of(ctx).cancel),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: Text(S.of(ctx).requestToJoin),
              onPressed: () async {
                final age = int.tryParse(ageController.text.trim());
                final amount = double.tryParse(amountController.text.trim());

                if (age == null || age < 18) {
                  VAppAlert.showErrorSnackBar(message: 'You must be 18 or older to request joining', context: ctx);
                  return;
                }
                if (stream.hasJoinFee) {
                  final required = stream.joinPrice ?? 0;
                  if (amount == null || amount < required) {
                    VAppAlert.showErrorSnackBar(message: 'Please pay KES ${required.toStringAsFixed(0)} to request joining', context: ctx);
                    return;
                  }
                }

                Navigator.of(ctx).pop();
                await _sendJoinRequest(ctx, stream, age: age, amountPaid: amount ?? 0);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendJoinRequest(
      BuildContext context, LiveStreamModel stream, {int? age, double? amountPaid}) async {
    // Show loading
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(width: 16),
            Text(S.of(context).sendingRequest),
          ],
        ),
      ),
    );

    try {
      // Use the API service directly instead of creating a controller
      final apiService = GetIt.I.get<LiveStreamApiService>();
      await apiService
          .requestJoinStream(
            stream.id,
            requestType: 'viewer',
            age: age,
            amountPaid: amountPaid,
          )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception(S.of(context).requestTimedOut);
        },
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show success dialog
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(S.of(context).requestSent),
            content: Text(S.of(context).joinRequestSentMessage),
            actions: [
              CupertinoDialogAction(
                child: Text(S.of(context).ok),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error
      if (context.mounted) {
        VAppAlert.showErrorSnackBar(
          message: '${S.of(context).failedToSendJoinRequest}: ${e.toString()}',
          context: context,
        );
      }
    }
  }

  void _showShareSheet(BuildContext context, LiveStreamModel stream) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => ShareLiveStreamSheet(
        stream: stream,
        isHost: false, // Viewers are not hosts
      ),
    );
  }

  String _getFullImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl; // Already a full URL
    }
    // Construct full URL: baseMediaUrl + imageUrl
    return '${SConstants.baseMediaUrl}$imageUrl';
  }
}
