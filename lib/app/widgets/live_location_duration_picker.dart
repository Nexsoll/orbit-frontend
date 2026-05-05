// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';

/// Duration option for live location sharing
class LiveLocationDuration {
  final int minutes;
  final String label;
  final IconData icon;

  const LiveLocationDuration({
    required this.minutes,
    required this.label,
    required this.icon,
  });
}

/// Bottom sheet for selecting live location duration
class LiveLocationDurationPicker extends StatelessWidget {
  const LiveLocationDurationPicker({super.key});

  static const List<LiveLocationDuration> _durations = [
    LiveLocationDuration(
      minutes: 15,
      label: '15 minutes',
      icon: CupertinoIcons.clock,
    ),
    LiveLocationDuration(
      minutes: 60,
      label: '1 hour',
      icon: CupertinoIcons.time,
    ),
    LiveLocationDuration(
      minutes: 480,
      label: '8 hours',
      icon: CupertinoIcons.sun_max,
    ),
  ];

  static Future<int?> show(BuildContext context) async {
    return showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => const LiveLocationDurationPicker(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.systemGrey5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.location_fill,
                          color: CupertinoColors.systemGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share Live Location',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label.resolveFrom(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose how long to share your real-time location',
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Duration options
            ..._durations.map((duration) => _buildDurationTile(context, duration)),
            // Cancel button
            Container(
              margin: const EdgeInsets.all(16),
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: CupertinoColors.systemGrey5,
                borderRadius: BorderRadius.circular(10),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationTile(BuildContext context, LiveLocationDuration duration) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => Navigator.pop(context, duration.minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.systemGrey5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              duration.icon,
              color: CupertinoColors.systemGreen,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                duration.label,
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey3,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
