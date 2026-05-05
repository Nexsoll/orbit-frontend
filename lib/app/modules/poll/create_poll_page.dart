import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/utils/current_room_holder.dart';
import 'package:super_up/app/utils/poll_message_helper.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_room_page/v_chat_room_page.dart';

class CreatePollPage extends StatefulWidget {
  const CreatePollPage({super.key});

  @override
  State<CreatePollPage> createState() => _CreatePollPageState();
}

class _CreatePollPageState extends State<CreatePollPage> {
  final _qCtrl = TextEditingController();
  final _optCtrls = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  bool _allowMulti = false;
  bool _sending = false;

  @override
  void dispose() {
    _qCtrl.dispose();
    for (final c in _optCtrls) c.dispose();
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optCtrls.add(TextEditingController());
    });
  }

  Future<void> _submit() async {
    final question = _qCtrl.text.trim();
    final options = _optCtrls.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();
    
    if (question.isEmpty || options.length < 2) {
      VAppAlert.showErrorSnackBarWithoutContext(
        message: 'Please enter a question and at least 2 options',
      );
      return;
    }

    if (_allowMulti) {
      // Open room picker for multiple room selection
      await _openRoomPickerAndSend(question, options);
    } else {
      // Send to current room only
      final roomId = CurrentRoomHolder.id;
      if (roomId == null) {
        Navigator.pop(context);
        return;
      }
      setState(() => _sending = true);
      try {
        await PollMessageHelper.sendPoll(
          roomId: roomId,
          question: question,
          options: options,
          allowMulti: _allowMulti,
        );
        if (mounted) Navigator.pop(context);
      } finally {
        if (mounted) setState(() => _sending = false);
      }
    }
  }

  Future<void> _openRoomPickerAndSend(String question, List<String> options) async {
    final currentRoomId = CurrentRoomHolder.id;
    
    // Open room picker
    final selectedRoomIds = await Navigator.push<List<String>>(
      context,
      CupertinoPageRoute(
        builder: (context) => VChooseRoomsPage(
          currentRoomId: currentRoomId,
        ),
      ),
    );

    debugPrint('=== POLL SHARE DEBUG ===');
    debugPrint('Selected room IDs from picker: $selectedRoomIds');
    debugPrint('Selected count: ${selectedRoomIds?.length ?? 0}');

    if (selectedRoomIds == null || selectedRoomIds.isEmpty) {
      debugPrint('No rooms selected, returning');
      return;
    }

    setState(() => _sending = true);
    try {
      // Send poll to all selected rooms with delay between each
      for (var i = 0; i < selectedRoomIds.length; i++) {
        final roomId = selectedRoomIds[i];
        debugPrint('[$i] Starting send to room: $roomId');
        
        try {
          await PollMessageHelper.sendPoll(
            roomId: roomId,
            question: question,
            options: options,
            allowMulti: _allowMulti,
          );
          debugPrint('[$i] Successfully sent to room: $roomId');
        } catch (e, stackTrace) {
          debugPrint('[$i] ERROR sending to room $roomId: $e');
          debugPrint('[$i] Stack trace: $stackTrace');
          // Continue with other rooms even if one fails
        }
        
        // Longer delay to avoid backend rate limiting and ensure proper processing
        if (i < selectedRoomIds.length - 1) {
          debugPrint('[$i] Waiting 1 second before next send...');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      
      debugPrint('=== Finished sending to all rooms ===');
      
      if (mounted) {
        VAppAlert.showSuccessSnackBarWithoutContext(
          message: 'Poll sent to ${selectedRoomIds.length} chat${selectedRoomIds.length > 1 ? 's' : ''}',
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('CRITICAL ERROR in poll sending: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        VAppAlert.showErrorSnackBarWithoutContext(
          message: 'Failed to send poll: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Create Poll'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Question', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _qCtrl,
                placeholder: 'Type your question...',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Options', style: TextStyle(fontWeight: FontWeight.w600)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _addOption,
                    child: const Text('Add option'),
                  ),
                ],
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _optCtrls.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    return Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: _optCtrls[i],
                            placeholder: 'Option ${i + 1}',
                          ),
                        ),
                        if (_optCtrls.length > 2)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: () {
                              setState(() {
                                _optCtrls.removeAt(i).dispose();
                              });
                            },
                            child: const Icon(CupertinoIcons.minus_circle),
                          )
                      ],
                    );
                  },
                ),
              ),
              Row(
                children: [
                  CupertinoSwitch(
                    value: _allowMulti,
                    onChanged: (v) => setState(() => _allowMulti = v),
                  ),
                  const SizedBox(width: 8),
                  const Text('Allow multiple selections'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _sending ? null : _submit,
                  child: _sending
                      ? const CupertinoActivityIndicator()
                      : const Text('Send Poll'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
