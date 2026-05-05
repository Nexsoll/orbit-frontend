// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_platform/v_platform.dart';
import 'dart:async';
import 'dart:developer';
import 'package:wakelock_plus/wakelock_plus.dart';
// Conditional import for Agora
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../controllers/live_stream_controller.dart';
import '../controllers/live_stream_chat_controller.dart';
import '../models/live_stream_model.dart';
import 'widgets/live_stream_chat.dart';
import 'widgets/live_stream_controls.dart';
import 'widgets/stream_filter_panel.dart';
import 'widgets/web_shadow_host.dart';
import 'share_live_stream_sheet.dart';
import 'saved_lives_view.dart';
import '../../home/home_controller/views/home_view.dart';
import '../../home/home_controller/controllers/home_controller.dart';
import 'package:v_chat_message_page/src/agora/pages/widgets/web_camera_view.dart';

class LiveStreamView extends StatefulWidget {
  final LiveStreamModel stream;
  final bool isStreamer;

  const LiveStreamView({
    super.key,
    required this.stream,
    required this.isStreamer,
  });

  @override
  State<LiveStreamView> createState() => _LiveStreamViewState();
}

class _LiveStreamViewState extends State<LiveStreamView> {
  late final LiveStreamController controller;
  late final LiveStreamChatController chatController;
  bool _showChat = true;
  bool _showControls = true;
  Timer? _controlsTimer;
  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  Widget _buildVideoGrid(List<Widget> tiles) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        // 1 tile -> 1x1, 2-4 tiles -> 2x2 grid
        final crossAxisCount = tiles.length == 1 ? 1 : 2;
        final rows = (tiles.length / crossAxisCount).ceil();
        final childAspectRatio = (constraints.maxWidth / crossAxisCount) /
            (constraints.maxHeight / rows);
        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                color: Colors.black,
                child: tiles[index],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Keep screen awake during live stream
    unawaited(WakelockPlus.enable());
    log('-----chech the isStream bool------${widget.isStreamer}');
    controller = GetIt.I.get<LiveStreamController>();
    chatController = GetIt.I.get<LiveStreamChatController>();

    // Set up stream ended callback for participants
    if (!widget.isStreamer) {
      controller.onStreamEndedCallback = () {
        if (mounted) {
          _showStreamEndedDialog();
        }
      };

      // Set up callback for when user is removed/banned
      controller.onStreamEndedWithReasonCallback =
          (String? reason, bool isBanned) {
        if (mounted) {
          _handleRemovalFromStream(reason, isBanned);
        }
      };
    }

    // Initialize stream asynchronously
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchFunction().then((value) {
        setState(() {
          controller.isCameraOn.value = true;
          log('-----=========================================================------${controller.agoraEngine}');
        });
        // Show controls initially for a few seconds
        _showControlsTemporarily();
      });
    });
  }

  fetchFunction() async {
    await controller
        .initializeStream(
      stream: widget.stream,
      isStreamer: widget.isStreamer,
    )
        .catchError((error) {
      if (mounted) {
        String errorMessage = 'Failed to initialize stream';

        if (error.toString().toLowerCase().contains('banned') ||
            error
                .toString()
                .toLowerCase()
                .contains('you are banned from this stream')) {
          errorMessage = 'You are banned from this stream';
        } else if (error.toString().toLowerCase().contains('forbidden')) {
          errorMessage = 'Access denied to this stream';
        } else {
          errorMessage = 'Failed to join stream: ${error.toString()}';
        }

        _showErrorDialog(errorMessage);
      }
    });
  }

  @override
  void dispose() {
    // Release wakelock when leaving stream
    unawaited(WakelockPlus.disable());
    _controlsTimer?.cancel();
    // Clear callbacks immediately to prevent any further UI updates
    controller.onStreamEndedCallback = null;
    controller.onStreamEndedWithReasonCallback = null;

    // End the stream properly before disposing
    if (controller.currentStream != null) {
      controller.endStream().catchError((error) {
        // Silently handle any errors during stream ending
        if (kDebugMode) {
          print('Error ending stream during dispose: $error');
        }
      });
    }

    // Reset controller state safely
    Future.microtask(() {
      try {
        if (!controller.isDisposed) {
          controller.resetController();
        }
      } catch (e) {
        // Silently handle any disposal errors
        if (kDebugMode) {
          print('Error resetting controller during dispose: $e');
        }
      }
    });

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log('>>>>>>>>>>>>>>>>>>>>>>>>>>>>==============  ${controller.agoraEngine}');

    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackPress(context);
      },
      child: CupertinoPageScaffold(
        backgroundColor: Colors.black,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: Colors.transparent,
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _handleBackPress(context),
            child: Row(
              children: [
                const Icon(CupertinoIcons.chevron_back,
                    color: Color(0xFFB48648)),
                const SizedBox(width: 2),
                Text(S.of(context).back,
                    style: const TextStyle(color: Color(0xFFB48648))),
              ],
            ),
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () {
              // Hide filter panel when tapping outside
              if (widget.isStreamer &&
                  controller.filterController.isFilterPanelVisible) {
                controller.filterController.hideFilterPanel();
              }
            },
            child: Stack(
              children: [
                // Video view
                _buildVideoView(),

                // Top bar with stream info
                _buildTopBar(),

                // Likes counter for host
                if (widget.isStreamer) _buildLikesCounter(),

                // Join requests notification for host
                if (widget.isStreamer) _buildJoinRequestsNotification(),

                // Chat overlay
                if (_showChat) _buildChatOverlay(),

                // Controls overlay - always visible on web
                if (_showControls || VPlatforms.isWeb) _buildControlsOverlay(),

                // Web-specific close button (always visible)
                if (VPlatforms.isWeb)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          CupertinoIcons.xmark,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),

                // Filter panel (only for streamers)
                if (widget.isStreamer)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: StreamFilterPanel(
                      filterController: controller.filterController,
                    ),
                  ),

                // Like button for viewers (on top of everything)
                if (!widget.isStreamer) _buildLikeButton(),

                // Loading overlay
                ValueListenableBuilder<bool>(
                  valueListenable: controller.isLoading,
                  builder: (context, isLoading, child) {
                    if (isLoading) {
                      return Container(
                        color: Colors.black.withValues(alpha: 0.7),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CupertinoActivityIndicator(
                                radius: 20,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 16),
                              ValueListenableBuilder<String>(
                                valueListenable: controller.loadingStatus,
                                builder: (context, status, child) {
                                  return Text(
                                    status,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    return GestureDetector(
      onTap: () {
        if (_showControls) {
          setState(() {
            _showControls = false;
          });
          _controlsTimer?.cancel();
        } else {
          _showControlsTemporarily();
        }
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: ValueListenableBuilder<bool>(
          valueListenable: controller.isBroadcaster,
          builder: (context, isBroadcaster, _) {
            final asBroadcaster = widget.isStreamer || isBroadcaster;
            return ValueListenableBuilder<List<int>>(
              valueListenable: controller.remoteUsers,
              builder: (context, remoteUsers, _) {
                if (asBroadcaster) {
                  if (controller.agoraEngine == null && !VPlatforms.isWeb) {
                    return const Center(
                      child: CupertinoActivityIndicator(
                        radius: 20,
                        color: Colors.white,
                      ),
                    );
                  }

                  // Always render local full-screen; render remote(s) as overlays (avoids blank screen if audience joins)
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: Colors.black,
                          child: VPlatforms.isWeb
                              ? const WebCameraView()
                              : ValueListenableBuilder<bool>(
                                  valueListenable: controller.isCameraOn,
                                  builder: (context, isOn, _) {
                                    return RepaintBoundary(
                                      child: AgoraVideoView(
                                        controller: VideoViewController(
                                          rtcEngine: controller.agoraEngine!,
                                          canvas: const VideoCanvas(uid: 0),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      ...remoteUsers.asMap().entries.map((e) {
                        final index = e.key;
                        final uid = e.value;
                        // Show up to 3 PiP tiles
                        if (index > 2) return const SizedBox.shrink();
                        return Positioned(
                          top: 16.0 + index * 12,
                          right: 16.0 + index * 12,
                          width: 120,
                          height: 168,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              color: Colors.black,
                              child: AgoraVideoView(
                                controller: VideoViewController.remote(
                                  rtcEngine: controller.agoraEngine!,
                                  canvas: VideoCanvas(uid: uid),
                                  connection: RtcConnection(
                                    channelId: widget.stream.channelName,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                } else {
                  // Viewer
                  if (controller.agoraEngine == null && !VPlatforms.isWeb) {
                    return const Center(
                      child: CupertinoActivityIndicator(
                        radius: 20,
                        color: Colors.white,
                      ),
                    );
                  }

                  if (remoteUsers.isNotEmpty) {
                    // On web without plugin, use shadow host; grid not supported via pluginless path
                    if (VPlatforms.isWeb && controller.agoraEngine == null) {
                      return const Positioned.fill(child: WebShadowHost());
                    }
                    // Viewer sees all remote broadcasters (host + co-hosts)
                    final tiles = remoteUsers
                        .map((uid) => AgoraVideoView(
                              controller: VideoViewController.remote(
                                rtcEngine: controller.agoraEngine!,
                                canvas: VideoCanvas(uid: uid),
                                connection: RtcConnection(
                                  channelId: widget.stream.channelName,
                                ),
                              ),
                            ))
                        .toList();
                    return _buildVideoGrid(tiles);
                  }

                  if (VPlatforms.isWeb) {
                    return Stack(
                      children: [
                        const Positioned.fill(child: WebShadowHost()),
                        if (controller.agoraEngine != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: true,
                              child: Opacity(
                                opacity: 0.01,
                                child: AgoraVideoView(
                                  controller: VideoViewController(
                                    rtcEngine: controller.agoraEngine!,
                                    canvas: const VideoCanvas(uid: 0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }

                  return ValueListenableBuilder<bool>(
                    valueListenable: controller.streamEnded,
                    builder: (context, streamEnded, __) {
                      if (streamEnded) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.xmark_circle,
                                size: 64,
                                color: Colors.red.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                S.of(context).streamHasEnded,
                                style: TextStyle(
                                  color: Colors.red.withValues(alpha: 0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              image: widget
                                      .stream.streamerData.userImage.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(
                                          widget.stream.streamerData.userImage),
                                      fit: BoxFit.cover,
                                      colorFilter: ColorFilter.mode(
                                        Colors.black.withValues(alpha: 0.3),
                                        BlendMode.darken,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                VCircleAvatar(
                                  radius: 50,
                                  vFileSource: VPlatformFile.fromUrl(
                                    networkUrl:
                                        widget.stream.streamerData.userImage,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const CupertinoActivityIndicator(
                                  radius: 15,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  S.of(context).connectingToName(
                                      widget.stream.streamerData.fullName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  S.of(context).pleaseWaitConnectingLiveStream,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            // Stream info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.stream.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.stream.streamerData.fullName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Live indicator and viewer count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  Text(
                    S.of(context).liveLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Viewer count
            ValueListenableBuilder<int>(
              valueListenable: controller.viewerCount,
              builder: (context, count, child) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
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
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(width: 8),

            // Share button
            GestureDetector(
              onTap: _showShareSheet,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.share,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),

            // Saved Lives button (only for streamers)
            if (widget.isStreamer) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _navigateToSavedLives,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.collections,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],

            // Filter button (only for streamers)
            if (widget.isStreamer) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => controller.filterController.toggleFilterPanel(),
                child: AnimatedBuilder(
                  animation: controller.filterController,
                  builder: (context, child) {
                    final hasActiveFilter =
                        controller.filterController.hasActiveFilter;
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: hasActiveFilter
                            ? Colors.purple.withValues(alpha: 0.8)
                            : Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: hasActiveFilter
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: Icon(
                        CupertinoIcons.sparkles,
                        color: Colors.white,
                        size: 18,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatOverlay() {
    return ValueListenableBuilder<bool>(
        valueListenable: controller.isBroadcaster,
        builder: (context, isBroadcaster, _) {
          final asBroadcaster = widget.isStreamer || isBroadcaster;
          return Positioned(
            bottom: asBroadcaster ? 120 : 80,
            left: 16,
            right: 16,
            height: 200,
            child: LiveStreamChat(
              streamId: widget.stream.id,
              isStreamer: asBroadcaster,
              onToggleChat: () {
                setState(() {
                  _showChat = !_showChat;
                });
              },
            ),
          );
        });
  }

  Widget _buildControlsOverlay() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: ValueListenableBuilder<bool>(
        valueListenable: controller.isBroadcaster,
        builder: (context, isBroadcaster, _) {
          final asBroadcaster = widget.isStreamer || isBroadcaster;
          return LiveStreamControls(
            isStreamer: asBroadcaster,
            controller: controller,
            chatController: chatController,
            streamId: widget.stream.id,
            onToggleChat: () {
              setState(() {
                _showChat = !_showChat;
              });
            },
            onEndStream: () {
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }

  void _showStreamEndedDialog() {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Stream Ended'),
          content: const Text(
            'The live stream has ended. You will be redirected back to the streams list.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close stream view
              },
            ),
          ],
        );
      },
    );
  }

  void _handleRemovalFromStream(String? reason, bool isBanned) {
    final action = isBanned ? 'banned from' : 'removed from';
    final message = reason ?? 'You were $action the stream by the host';

    // Show a brief message and automatically redirect
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(isBanned ? 'Banned from Stream' : 'Removed from Stream'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                _navigateToStoriesTab();
              },
            ),
          ],
        );
      },
    );

    // Also automatically redirect after a short delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateToStoriesTab();
      }
    });
  }

  void _navigateToStoriesTab() {
    // First close any dialogs
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }

    // Navigate to home and set stories tab
    context.toPageAndRemoveAllWithOutAnimation(const HomeView());

    // Set the tab to stories (index 1) after navigation completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        try {
          final homeController = GetIt.I.get<HomeController>();
          homeController.value.data = 1;
          homeController.update();
        } catch (e) {
          if (kDebugMode) {
            print('Error setting stories tab: $e');
          }
        }
      });
    });
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Unable to Join Stream'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close stream view
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildLikesCounter() {
    return Positioned(
      top: 100, // Below the top bar
      right: 16,
      child: ValueListenableBuilder<int>(
        valueListenable: controller.likesCount,
        builder: (context, likesCount, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.heart_fill,
                  color: CupertinoColors.systemRed,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$likesCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLikeButton() {
    return Positioned(
      right: 16,
      bottom: 160, // Moved up a bit to avoid overlapping with the arrow button
      child: ValueListenableBuilder<bool>(
        valueListenable: controller.isLiked,
        builder: (context, isLiked, child) {
          return ValueListenableBuilder<int>(
            valueListenable: controller.likesCount,
            builder: (context, likesCount, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Likes count display
                  if (likesCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$likesCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  if (likesCount > 0) const SizedBox(height: 4),

                  // Like button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        print('Like button tapped!'); // Debug
                        _handleLikePressed();
                      },
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isLiked
                              ? CupertinoColors.systemRed.withValues(alpha: 0.9)
                              : Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isLiked
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _handleLikePressed() async {
    print('_handleLikePressed called'); // Debug
    try {
      print('Calling controller.likeStream()'); // Debug
      await controller.likeStream();
      print('Like stream completed successfully'); // Debug
    } catch (e) {
      print('Error in _handleLikePressed: $e'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to like stream: $e'),
            backgroundColor: CupertinoColors.systemRed,
          ),
        );
      }
    }
  }

  Widget _buildJoinRequestsNotification() {
    return Positioned(
      top: 160, // Below the likes counter
      right: 16,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          final joinRequests = controller.joinRequests;
          if (kDebugMode) {
            print(
                "Join requests notification - count: ${joinRequests.length}, requests: $joinRequests");
          }
          if (joinRequests.isEmpty) {
            return const SizedBox.shrink();
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.person_add,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${joinRequests.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showJoinRequestsSheet(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'View',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showJoinRequestsSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Join Requests'),
        message: const Text('Approve or reject join requests'),
        actions: controller.joinRequests.map((request) {
          if (kDebugMode) {
            print("Processing join request: $request");
          }

          final userName = request['userData']?['fullName'] ??
              request['user']?['name'] ??
              request['user']?['username'] ??
              request['userName'] ??
              'Unknown User';
          final requestId =
              request['id'] ?? request['_id'] ?? request['requestId'] ?? '';

          if (kDebugMode) {
            print("Extracted - userName: $userName, requestId: $requestId");
          }

          return CupertinoActionSheetAction(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: CupertinoColors.systemGrey4,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    userName,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      color: CupertinoColors.systemGreen,
                      borderRadius: BorderRadius.circular(16),
                      child: const Text(
                        'Approve',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.white,
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        if (requestId.isEmpty) {
                          if (mounted) {
                            VAppAlert.showErrorSnackBar(
                              message: 'Invalid request ID',
                              context: context,
                            );
                          }
                          return;
                        }
                        try {
                          await controller.respondToJoinRequest(
                              requestId, true);
                          if (mounted) {
                            VAppAlert.showErrorSnackBar(
                              message: 'Join request approved',
                              context: context,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            VAppAlert.showErrorSnackBar(
                              message:
                                  'Failed to approve request: ${e.toString()}',
                              context: context,
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      color: CupertinoColors.systemRed,
                      borderRadius: BorderRadius.circular(16),
                      child: const Text(
                        'Reject',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.white,
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        try {
                          await controller.respondToJoinRequest(
                              requestId, false);
                          if (mounted) {
                            VAppAlert.showErrorSnackBar(
                              message: 'Join request rejected',
                              context: context,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            VAppAlert.showErrorSnackBar(
                              message:
                                  'Failed to reject request: ${e.toString()}',
                              context: context,
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            onPressed:
                () {}, // Empty onPressed since we handle it in the buttons
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showShareSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => ShareLiveStreamSheet(
        stream: widget.stream,
        isHost: widget.isStreamer,
      ),
    );
  }

  Future<void> _handleBackPress(BuildContext context) async {
    // If user is a streamer, show confirmation dialog before ending stream
    if (widget.isStreamer) {
      final shouldEndStream = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('End Live Stream'),
          content: const Text(
            'Are you sure you want to end your live stream? This action cannot be undone.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('End Stream'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (shouldEndStream == true) {
        try {
          // End the stream
          await controller.endStream();

          // Navigate back to home
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              CupertinoPageRoute(
                builder: (context) => HomeView(),
              ),
              (route) => false,
            );
          }
        } catch (e) {
          if (mounted) {
            VAppAlert.showErrorSnackBar(
              message: 'Failed to end stream: ${e.toString()}',
              context: context,
            );
          }
        }
      }
    } else {
      // If user is a viewer, just leave the stream
      try {
        await controller.endStream(); // This handles both streamers and viewers

        // Navigate back
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          VAppAlert.showErrorSnackBar(
            message: 'Failed to leave stream: ${e.toString()}',
            context: context,
          );
          // Still navigate back even if leaving fails
          Navigator.of(context).pop();
        }
      }
    }
  }

  void _navigateToSavedLives() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const SavedLivesView(),
      ),
    );
  }
}
