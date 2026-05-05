// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
// Removed platform gating for web; live streaming is now supported on web

import 'go_live_view.dart';
import 'watch_live_view.dart';
import 'saved_lives_view.dart';
import 'all_saved_streams_view.dart';

class LiveStreamOptionsView extends StatelessWidget {
  const LiveStreamOptionsView({super.key});

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
        middle: Text(S.of(context).liveStreaming),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Live streaming icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFB48648).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.video_camera_solid,
                  size: 60,
                  color: Color(0xFFB48648),
                ),
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                S.of(context).liveStreaming,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                S.of(context).connectRealtime,
                style: const TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.secondaryLabel,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),

              // Go Live Button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFFB48648),
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: () {
                    context.toPage(const GoLiveView());
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.play_circle_fill,
                        color: CupertinoColors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        S.of(context).goLive,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Watch Live Button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFFB48648),
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: () {
                    context.toPage(const WatchLiveView());
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.eye_fill,
                        color: CupertinoColors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        S.of(context).watchLive,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Saved Streams Button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFFB48648),
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: () {
                    context.toPage(const SavedLivesView());
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.folder_fill,
                        color: CupertinoColors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        S.of(context).myStreams,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // All Saved Streams Button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFFB48648),
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: () {
                    context.toPage(const AllSavedStreamsView());
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.eye,
                        color: CupertinoColors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        S.of(context).allSavedStreams,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Info text (grey background with white text)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.info_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        S.of(context).infoLiveStreaming,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
