import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TimeLockMessageWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isMeSender;
  const TimeLockMessageWidget({super.key, required this.data, required this.isMeSender});

  @override
  State<TimeLockMessageWidget> createState() => _TimeLockMessageWidgetState();
}

class _TimeLockMessageWidgetState extends State<TimeLockMessageWidget> {
  Timer? _timer;
  bool _unlocked = false;

  String get _content => (widget.data['content'] as String?) ?? '';
  DateTime? get _unlockAtUtc => widget.data['unlockAt'] is String
      ? DateTime.tryParse(widget.data['unlockAt'] as String)
      : null;

  @override
  void initState() {
    super.initState();
    _setupTimer();
  }

  void _setupTimer() {
    final unlockAt = _unlockAtUtc;
    if (unlockAt == null) return;
    final now = DateTime.now().toUtc();
    if (now.isAfter(unlockAt)) {
      _unlocked = true;
      return;
    }
    final diff = unlockAt.difference(now);
    _timer?.cancel();
    _timer = Timer(diff, () {
      if (!mounted) return;
      setState(() => _unlocked = true);
    });
  }

  @override
  void didUpdateWidget(covariant TimeLockMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlockAtLocal = _unlockAtUtc?.toLocal();
    if (_unlocked) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
        ),
        child: Text(_content),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.lock, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Locked message', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  unlockAtLocal == null
                      ? 'Opens soon'
                      : 'Opens at ${unlockAtLocal.toString()}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
