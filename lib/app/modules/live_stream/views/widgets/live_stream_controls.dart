// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../../controllers/live_stream_controller.dart';
import '../../controllers/live_stream_chat_controller.dart';
import 'participants_sheet.dart';
import 'live_stream_gift_picker.dart';
import 'package:get_it/get_it.dart';
import '../../services/live_stream_api_service.dart';

class LiveStreamControls extends StatefulWidget {
  final bool isStreamer;
  final LiveStreamController controller;
  final VoidCallback onToggleChat;
  final VoidCallback onEndStream;
  final String streamId;
  final LiveStreamChatController chatController;

  const LiveStreamControls({
    super.key,
    required this.isStreamer,
    required this.controller,
    required this.onToggleChat,
    required this.onEndStream,
    required this.streamId,
    required this.chatController,
  });

  @override
  State<LiveStreamControls> createState() => _LiveStreamControlsState();
}

class _LiveStreamControlsState extends State<LiveStreamControls> {
  String? _currentHint;
  Timer? _hintTimer;
  Timer? _supportTimer;

  void _showHint(String text) {
    if (text.isEmpty) return;
    _hintTimer?.cancel();
    setState(() => _currentHint = text);
    _hintTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _currentHint = null);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _supportTimer?.cancel();
    super.dispose();
  }

  void _showParticipants(BuildContext context) {
    showCupertinoModalBottomSheet<void>(
      context: context,
      builder: (context) => ParticipantsSheet(
        streamId: widget.streamId,
        isStreamer: widget.isStreamer,
        controller: widget.controller,
      ),
    );
  }

  void _showGiftPicker(BuildContext context) {
    showCupertinoModalBottomSheet<void>(
      context: context,
      builder: (context) => LiveStreamGiftPicker(
        chatController: widget.chatController,
      ),
    );
  }

  Future<void> _showSupportDialog(BuildContext context) async {
    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    final result = await showCupertinoDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Support'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: amountController,
              placeholder: 'Amount (KES)',
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: phoneController,
              placeholder: 'Phone (07XXXXXXXX)',
              keyboardType: TextInputType.phone,
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
            child: const Text('Pay'),
            onPressed: () => Navigator.of(ctx).pop({
              'amount': amountController.text.trim(),
              'phone': phoneController.text.trim(),
            }),
          ),
        ],
      ),
    );
    if (result == null) return;
    final amount = double.tryParse(result['amount'] ?? '');
    final phone = (result['phone'] ?? '').trim();
    if (amount == null || amount <= 0) {
      VAppAlert.showErrorSnackBar(message: 'Enter a valid amount', context: context);
      return;
    }
    if (phone.isEmpty) {
      VAppAlert.showErrorSnackBar(message: 'Enter phone number', context: context);
      return;
    }

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const CupertinoAlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(),
            SizedBox(width: 12),
            Text('Sending STK...'),
          ],
        ),
      ),
    );
    try {
      final api = GetIt.I.get<LiveStreamApiService>();
      final res = await api.initiateSupportDonation(
        streamId: widget.streamId,
        amount: amount,
        phone: phone,
      );
      if (mounted) Navigator.of(context).pop();
      _showHint('STK sent');
      final donationId = res['donationId'] as String?;
      if (donationId != null) {
        _startSupportPolling(context, donationId);
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      VAppAlert.showErrorSnackBar(message: 'Failed: ${e.toString()}', context: context);
    }
  }

  void _startSupportPolling(BuildContext context, String donationId) {
    _supportTimer?.cancel();
    final api = GetIt.I.get<LiveStreamApiService>();
    int ticks = 0;
    _supportTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      ticks++;
      try {
        final st = await api.getSupportDonationStatus(streamId: widget.streamId, donationId: donationId);
        final status = (st['status'] as String?)?.toLowerCase();
        if (status == 'success') {
          t.cancel();
          VAppAlert.showSuccessSnackBar(message: 'Payment successful', context: context);
        } else if (status == 'failed' || status == 'cancelled' || status == 'timeout') {
          t.cancel();
          VAppAlert.showErrorSnackBar(message: 'Payment $status', context: context);
        }
      } catch (_) {}
      if (ticks >= 60) {
        t.cancel();
        VAppAlert.showErrorSnackBar(message: 'Payment pending. Please check later.', context: context);
      }
    });
  }

  Future<void> _handleRequestToJoin(BuildContext context) async {
    try {
      await widget.controller.requestJoinStream(requestType: 'cohost');
      VAppAlert.showSuccessSnackBar(
        message: S.of(context).requestSent,
        context: context,
      );
    } catch (e) {
      VAppAlert.showErrorSnackBar(
        message: '${S.of(context).failedToSendJoinRequest}: ${e.toString()}',
        context: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hint banner
        AnimatedOpacity(
          opacity: _currentHint == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: _currentHint == null
              ? const SizedBox.shrink()
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _currentHint!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
        ),
        if (_currentHint != null) const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Chat toggle button
          _buildControlButton(
            icon: CupertinoIcons.chat_bubble_fill,
            onPressed: widget.onToggleChat,
            tooltip: S.of(context).chatLabel,
          ),

          // Participants button (for both streamers and viewers)
          _buildControlButton(
            icon: CupertinoIcons.person_2_fill,
            onPressed: () => _showParticipants(context),
            tooltip: S.of(context).participantsLabel,
          ),

          if (widget.isStreamer) ...[
            // Mute/Unmute button
            ValueListenableBuilder<bool>(
              valueListenable: widget.controller.isMuted,
              builder: (context, isMuted, child) {
                return _buildControlButton(
                  icon: isMuted
                      ? CupertinoIcons.mic_slash_fill
                      : CupertinoIcons.mic_fill,
                  onPressed: widget.controller.toggleMute,
                  isActive: !isMuted,
                  tooltip: S.of(context).micLabel,
                );
              },
            ),

            // Camera toggle button
            ValueListenableBuilder<bool>(
              valueListenable: widget.controller.isCameraOn,
              builder: (context, isCameraOn, child) {
                return _buildControlButton(
                  icon: isCameraOn
                      ? CupertinoIcons.video_camera_solid
                      : CupertinoIcons.video_camera_solid,
                  onPressed: widget.controller.toggleCamera,
                  isActive: isCameraOn,
                  tooltip: S.of(context).cameraLabel,
                );
              },
            ),

            // Switch camera button
            _buildControlButton(
              icon: CupertinoIcons.camera_rotate,
              onPressed: widget.controller.switchCamera,
              tooltip: S.of(context).flipCamera,
            ),

            // Record button
            ValueListenableBuilder<bool>(
              valueListenable: widget.controller.isRecording,
              builder: (context, isRecording, child) {
                return _buildRecordButton(
                  context,
                  isRecording: isRecording,
                  onPressed: () => _handleRecordToggle(context),
                );
              },
            ),
          ] else ...[
            // Request to join as co-host (viewer)
            _buildControlButton(
              icon: CupertinoIcons.person_add,
              onPressed: () => _handleRequestToJoin(context),
              color: Colors.blue,
              tooltip: S.of(context).requestToJoin,
            ),
            // Gift button for viewers
            _buildControlButton(
              icon: CupertinoIcons.gift,
              onPressed: () => _showGiftPicker(context),
              color: Colors.purple,
              tooltip: S.of(context).giftLabel,
            ),
            _buildControlButton(
              icon: CupertinoIcons.money_dollar,
              onPressed: () => _showSupportDialog(context),
              color: Colors.green,
              tooltip: 'Support',
            ),

            // Speaker toggle for viewers
            ValueListenableBuilder<bool>(
              valueListenable: widget.controller.isSpeakerOn,
              builder: (context, isSpeakerOn, child) {
                return _buildControlButton(
                  icon: isSpeakerOn
                      ? CupertinoIcons.speaker_3_fill
                      : CupertinoIcons.speaker_1_fill,
                  onPressed: widget.controller.toggleSpeaker,
                  isActive: isSpeakerOn,
                  tooltip: S.of(context).speakerLabel,
                );
              },
            ),
          ],

          // End/Leave stream button
          _buildControlButton(
            icon: widget.isStreamer
                ? CupertinoIcons.stop_fill
                : CupertinoIcons.xmark,
            onPressed: () => _showEndStreamDialog(context),
            color: CupertinoColors.systemRed,
            tooltip: widget.isStreamer ? S.of(context).endLabel : S.of(context).leaveLabel,
          ),
        ],
      ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = true,
    Color? color,
    String? tooltip,
  }) {
    return GestureDetector(
      onTap: () {
        if ((tooltip ?? '').isNotEmpty) {
          _showHint(tooltip!);
        }
        onPressed();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color ??
              (isActive
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white, // Always use white for icon visibility
          size: 24,
        ),
      ),
    );
  }

  void _showEndStreamDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(widget.isStreamer ? S.of(context).endLiveStream : S.of(context).leaveStream),
          content: Text(widget.isStreamer
              ? S.of(context).confirmEndLiveStream
              : S.of(context).confirmLeaveStream),
          actions: [
            CupertinoDialogAction(
              child: Text(S.of(context).cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: Text(widget.isStreamer ? S.of(context).endStream : S.of(context).leaveLabel),
              onPressed: () {
                Navigator.of(context).pop();
                _handleEndStream(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _handleEndStream(BuildContext context) async {
    try {
      await widget.controller.endStream();
      widget.onEndStream();
    } catch (e) {
      VAppAlert.showErrorSnackBar(
        message: widget.isStreamer
            ? S.of(context).failedToEndStream
            : S.of(context).failedToLeaveStream,
        context: context,
      );
    }
  }

  Widget _buildRecordButton(
    BuildContext context, {
    required bool isRecording,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: () {
        _showHint(S.of(context).recordLabel);
        onPressed();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isRecording
                  ? CupertinoColors.systemRed.withOpacity(0.8)
                  : Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: isRecording
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: Icon(
              isRecording ? CupertinoIcons.stop_fill : CupertinoIcons.circle_fill,
              color: Colors.white,
              size: isRecording ? 16 : 24,
            ),
          ),
          if (isRecording) ...[
            const SizedBox(height: 4),
            ValueListenableBuilder<String>(
              valueListenable: widget.controller.recordingDuration,
              builder: (context, duration, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _handleRecordToggle(BuildContext context) async {
    try {
      if (widget.controller.isRecording.value) {
        await widget.controller.stopRecording();
        VAppAlert.showSuccessSnackBar(
          message: S.of(context).recordingStoppedSuccessfully,
          context: context,
        );
      } else {
        await widget.controller.startRecording();
        VAppAlert.showSuccessSnackBar(
          message: S.of(context).recordingStarted,
          context: context,
        );
      }
    } catch (e) {
      VAppAlert.showErrorSnackBar(
        message: '${S.of(context).recordingError}: ${e.toString()}',
        context: context,
      );
    }
  }
}
