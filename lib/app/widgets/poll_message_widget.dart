import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/api_service/poll/poll_api_service.dart';
import 'package:super_up_core/super_up_core.dart';

class PollMessageWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isMeSender;
  const PollMessageWidget({super.key, required this.data, required this.isMeSender});

  @override
  State<PollMessageWidget> createState() => _PollMessageWidgetState();
}

class _PollMessageWidgetState extends State<PollMessageWidget> {
  bool _submitting = false;

  String get _question => widget.data['question'] as String? ?? 'Poll';
  List<Map<String, dynamic>> get _options {
    final raw = widget.data['options'];
    if (raw is List) {
      return raw.cast<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  Map<String, dynamic> get _votes => (widget.data['votes'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as List).map((e) => e.toString()).toList())) ?? {};
  int get _totalVotes => _votes.values.fold<int>(0, (p, e) => p + (e as List).length);

  String? get _roomId => widget.data['_roomId'] as String?;
  String? get _messageId => widget.data['_messageId'] as String?;

  Future<void> _vote(String optionId) async {
    if (_roomId == null || _messageId == null) return;
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await PollApiService.I.vote(roomId: _roomId!, messageId: _messageId!, optionId: optionId);
      // Socket will push updated message; no local update required
    } catch (e) {
      VAppAlert.showErrorSnackBarWithoutContext(message: 'Failed to vote: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showResults() async {
    if (_roomId == null || _messageId == null) return;
    try {
      final res = await PollApiService.I.results(roomId: _roomId!, messageId: _messageId!);
      if (!mounted) return;
      final options = (res['options'] as List?) ?? [];
      await showCupertinoModalPopup(
        context: context,
        builder: (_) {
          return CupertinoActionSheet(
            title: Text(_question),
            message: SizedBox(
              height: 350,
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (ctx, i) {
                  final o = options[i] as Map;
                  final voters = (o['voterProfiles'] as List? ?? [])
                      .cast<Map>()
                      .map((p) => (p['name'] ?? p['id']).toString())
                      .toList();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${o['text']} • ${o['count']} votes', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        if (voters.isEmpty)
                          const Text('No votes yet', style: TextStyle(color: Colors.grey))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: voters.map((n) => Chip(label: Text(n), visualDensity: VisualDensity.compact)).toList(),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      VAppAlert.showErrorSnackBarWithoutContext(message: 'Failed to fetch results: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _totalVotes == 0 ? 1 : _totalVotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_question, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ..._options.map((o) {
          final id = o['id'] as String;
          final text = (o['text'] as String?) ?? '';
          final count = (_votes[id] as List?)?.length ?? 0;
          final frac = count / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: _submitting ? null : () => _vote(id),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
                ),
                child: Stack(
                  children: [
                    // progress background
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: frac.clamp(0, 1),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFB48648).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text('$count'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_totalVotes} votes', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showResults,
              child: const Text('View votes'),
            ),
          ],
        )
      ],
    );
  }
}
