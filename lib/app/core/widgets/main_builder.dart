// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';
import '../services/app_lock_service.dart';
import '../../modules/lock/views/app_locked_page.dart';
import '../../modules/music/widgets/music_mini_player.dart';
import 'package:super_up/main.dart';

class MainBuilder extends StatefulWidget {
  final Widget? child;
  final ThemeMode themeMode;

  const MainBuilder({
    super.key,
    required this.child,
    required this.themeMode,
  });

  @override
  State<MainBuilder> createState() => _MainBuilderState();
}

class _MainBuilderState extends State<MainBuilder> with WidgetsBindingObserver {
  DateTime? _lastPromptAt;
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Apply pending notification actions that were executed in background isolate
      // (e.g. Mark as read) so the rooms list state refreshes on main isolate.
      unawaited(consumePendingMarkReadRoom());
      _maybeGuardOnResume();
    } else if (state == AppLifecycleState.paused) {
      // Reset only when app actually goes to background
      AppLockService.instance.resetSession();
    }
  }

  Future<void> _maybeGuardOnResume() async {
    if (!mounted) return;
    if (_authInProgress) return;
    if (!AppLockService.instance.isEnabled) return;
    // Throttle prompts that may happen due to rapid state changes
    if (_lastPromptAt != null &&
        DateTime.now().difference(_lastPromptAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastPromptAt = DateTime.now();

    _authInProgress = true;
    try {
      final supported = await AppLockService.instance.isSupported();
      if (!supported) return;
      if (!AppLockService.instance.sessionUnlocked) {
        // Push a blocking full-screen lock page; hide main UI behind it
        await navigatorKey.currentState?.push<bool>(
          MaterialPageRoute(builder: (_) => const AppLockedPage(), fullscreenDialog: true),
        );
      }
    } finally {
      _authInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizer = GetIt.I.isRegistered<AppSizeHelper>()
        ? GetIt.I.get<AppSizeHelper>()
        : null;
    final isWide = sizer?.isWide(context) ?? false;
    if (!isWide) {
      return AndroidStatusBarColor(
        themeMode: widget.themeMode,
        child: PointerDownUnFocus(
          child: Stack(
            children: [
              widget.child!,
              const VActiveCallOverlay(),
              MusicMiniPlayerOverlay(
                navigatorProvider: () => navigatorKey.currentState,
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        widget.child!,
        const VActiveCallOverlay(),
        MusicMiniPlayerOverlay(
          navigatorProvider: () => navigatorKey.currentState,
        ),
      ],
    );
  }
}
