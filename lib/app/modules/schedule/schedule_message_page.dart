import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/api_service/scheduled_message/scheduled_message_api_service.dart';
import 'package:super_up/app/utils/current_room_holder.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

class ScheduleMessagePage extends StatefulWidget {
  const ScheduleMessagePage({super.key});

  @override
  State<ScheduleMessagePage> createState() => _ScheduleMessagePageState();
}

class _ScheduleMessagePageState extends State<ScheduleMessagePage> {
  final _textCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(hours: 1));
  bool _asTimeLock = false; // if true -> send immediately as locked custom message
  bool _sending = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (_) {
        return Container(
          color: CupertinoColors.systemBackground,
          height: 280,
          child: Column(
            children: [
              SizedBox(
                height: 220,
                child: CupertinoDatePicker(
                  initialDateTime: _date,
                  minimumDate: DateTime.now().add(const Duration(minutes: 1)),
                  use24hFormat: true,
                  mode: CupertinoDatePickerMode.dateAndTime,
                  onDateTimeChanged: (v) => setState(() => _date = v),
                ),
              ),
              CupertinoButton(
                child: const Text('Done'),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final roomId = CurrentRoomHolder.id;
    if (roomId == null) {
      Navigator.pop(context);
      return;
    }
    final content = _textCtrl.text.trim();
    if (content.isEmpty) return;

    setState(() => _sending = true);
    try {
      if (_asTimeLock) {
        // Send immediately as a time-locked custom message; other clients will see lock card
        // We reuse custom message flow. The unlock UI will be handled by custom message renderer.
        final data = {
          'type': 'time_lock',
          'content': content,
          'unlockAt': _date.toUtc().toIso8601String(),
        };
        // Build a minimal local custom message and enqueue via SDK
        final msg = VCustomMessage.buildMessage(
          roomId: roomId,
          data: VCustomMsgData(data: data),
          // Prevent previews from showing the actual content
          content: '🔒 Locked message',
        );
        await VChatController.I.nativeApi.local.message.insertMessage(msg);
        VMessageUploaderQueue.instance.addToQueue(await MessageFactory.createUploadMessage(msg));
        VAppAlert.showSuccessSnackBarWithoutContext(message: 'Time-locked message sent');
      } else {
        // Server-side scheduled send
        final localId = 'sched_${DateTime.now().microsecondsSinceEpoch}';
        String platform = 'other';
        if (VPlatforms.isAndroid) platform = 'android';
        else if (VPlatforms.isIOS) platform = 'ios';
        else if (VPlatforms.isWeb) platform = 'web';
        else if (VPlatforms.isMacOs) platform = 'macOs';
        else if (VPlatforms.isWindows) platform = 'windows';
        else if (VPlatforms.isLinux) platform = 'linux';

        await ScheduledMessageApiService.I.schedule(
          roomId: roomId,
          content: content,
          localId: localId,
          scheduledAt: _date,
          isOneSeen: false,
          platform: platform,
        );
        VAppAlert.showSuccessSnackBarWithoutContext(message: 'Message scheduled');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      VAppAlert.showErrorSnackBarWithoutContext(message: 'Failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Schedule Message'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Message', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _textCtrl,
                placeholder: 'Write your message...'
              ),
              const SizedBox(height: 16),
              const Text('Deliver/Open at', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(_date.toLocal().toString())),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _pickDateTime,
                    child: const Text('Change'),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CupertinoSwitch(
                    value: _asTimeLock,
                    onChanged: (v) => setState(() => _asTimeLock = v),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Send now as locked (opens at date/time)')),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _sending ? null : _submit,
                  child: _sending
                      ? const CupertinoActivityIndicator()
                      : Text(_asTimeLock ? 'Send Locked Now' : 'Schedule Send'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
