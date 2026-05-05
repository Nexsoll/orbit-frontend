// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:video_player/video_player.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';

import '../models/live_stream_recording_model.dart';
import '../services/live_stream_api_service.dart';

class RecordingPlayerView extends StatefulWidget {
  final LiveStreamRecordingModel recording;
  // Optional playlist support to enable autoplay of next free item
  final List<LiveStreamRecordingModel>? playlist;
  final int? initialIndex;

  const RecordingPlayerView({
    super.key,
    required this.recording,
    this.playlist,
    this.initialIndex,
  });

  @override
  State<RecordingPlayerView> createState() => _RecordingPlayerViewState();
}

class _RecordingPlayerViewState extends State<RecordingPlayerView> {
  late final LiveStreamApiService _apiService;
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _viewsIncremented = false;
  // Keep track of the currently playing item and index inside the optional playlist
  late LiveStreamRecordingModel _currentRecording;
  int _currentIndex = 0;
  bool _didComplete = false;
  // Dedicated listener so we can remove it on dispose
  void _onControllerUpdate() {
    final v = _controller?.value;
    final isPlaying = v?.isPlaying ?? false;
    if (isPlaying && !_viewsIncremented) {
      _viewsIncremented = true;
      // Fire and forget
      unawaited(_apiService.incrementRecordingViews(_currentRecording.id));
    }

    // Detect completion to trigger autoplay of next free recording
    if (v != null && v.isInitialized) {
      final dur = v.duration;
      final pos = v.position;
      // When position reaches (or exceeds) duration and controller is not playing, consider complete
      if (dur.inMilliseconds > 0 &&
          pos >= dur - const Duration(milliseconds: 200) &&
          !v.isPlaying &&
          !_didComplete) {
        _didComplete = true;
        unawaited(_handlePlaybackCompleted());
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _apiService = GetIt.I.get<LiveStreamApiService>();
    _currentRecording = widget.recording;
    _currentIndex = widget.initialIndex ?? 0;
    _initializePlayer();
  }

  String _normalizeUrl(String url) {
    // Keep a simple normalizer for widgets that only need a single URL (e.g. watermark image)
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final base = SConstants.baseMediaUrl;
    if (trimmed.startsWith('/')) {
      return '$base$trimmed';
    }
    return '$base/$trimmed';
  }

  List<String> _buildUrlCandidates(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return const [];
    // Absolute URL: try it as-is only
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return [trimmed];
    }

    // Ensure path begins with '/'
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';

    // We will try a few safe, non-breaking origins in order:
    // 1) https Production domain
    // 2) http Production domain
    // 3) SConstants.baseMediaUrl (may point to IP:port)
    // 4) Same as (3) but without an explicit port (use default for scheme)
    final candidates = <String>[];
    const prodDomainHttps = 'https://api.orbit.ke';
    const prodDomainHttp = 'http://api.orbit.ke';
    candidates.add('$prodDomainHttps$path');
    candidates.add('$prodDomainHttp$path');

    final base = SConstants.baseMediaUrl; // e.g. http://165.227.106.75:3000
    // Avoid double slashes
    final fromBase = base.endsWith('/') ? '${base.substring(0, base.length - 1)}$path' : '$base$path';
    candidates.add(fromBase);

    // Add variant without the port if any
    try {
      final uri = Uri.parse(base);
      if (uri.hasPort) {
        final originNoPort = '${uri.scheme}://${uri.host}';
        candidates.add('$originNoPort$path');
      }
    } catch (_) {}

    // Deduplicate while preserving order
    final seen = <String>{};
    final unique = <String>[];
    for (final c in candidates) {
      if (seen.add(c)) unique.add(c);
    }
    return unique;
  }

  Future<void> _initializePlayer() async {
    final rawUrl = _currentRecording.recordingUrl;
    if (rawUrl.trim().isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Recording URL is missing';
        _isInitializing = false;
      });
      return;
    }

    if (_currentRecording.status != 'completed') {
      setState(() {
        _hasError = true;
        _errorMessage = 'Recording is ${_currentRecording.status}. Please try again later.';
        _isInitializing = false;
      });
      return;
    }

    // Try multiple candidate URLs until one initializes successfully
    final candidates = _buildUrlCandidates(rawUrl);
    Exception? lastError;
    for (final candidate in candidates) {
      try {
        final c = VideoPlayerController.networkUrl(Uri.parse(candidate));
        await c.initialize();
        _controller = c;
        // Listen to play state to increment views once
        _controller!.addListener(_onControllerUpdate);
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
        await _controller!.play();
        return; // success
      } catch (e) {
        // Dispose the failed controller, if any
        try { await _controller?.dispose(); } catch (_) {}
        _controller = null;
        lastError = e is Exception ? e : Exception(e.toString());
        // Try next candidate
      }
    }

    // If we reach here, all candidates failed
    setState(() {
      _hasError = true;
      _errorMessage = 'Failed to load video';
      _isInitializing = false;
    });
    final tried = candidates.join("\n");
    VAppAlert.showErrorSnackBar(
      context: context,
      message: 'Could not play recording. Tried URLs:\n$tried\nError: ${lastError?.toString() ?? 'unknown'}',
    );
  }

  Future<void> _handlePlaybackCompleted() async {
    // Try to find next auto-playable recording in the provided playlist
    final next = _findNextAutoPlayable();
    if (next == null) return;
    await _setCurrentRecording(next.item, index: next.index);
  }

  ({LiveStreamRecordingModel item, int index})? _findNextAutoPlayable() {
    final list = widget.playlist;
    if (list == null || list.isEmpty) return null;
    for (int i = _currentIndex + 1; i < list.length; i++) {
      final r = list[i];
      if (_canAutoPlay(r)) {
        return (item: r, index: i);
      }
    }
    return null;
  }

  bool _canAutoPlay(LiveStreamRecordingModel r) {
    // Only auto-play free and completed recordings that the user can access
    final isAccessible = !r.isPrivate || r.allowedViewers.contains(AppAuth.myId);
    return !r.isPaid && r.status == 'completed' && isAccessible;
  }

  Future<void> _setCurrentRecording(LiveStreamRecordingModel r, {int? index}) async {
    // Dispose previous controller first
    _controller?.removeListener(_onControllerUpdate);
    await _controller?.dispose();
    _controller = null;

    _currentRecording = r;
    if (index != null) _currentIndex = index;
    _isInitializing = true;
    _hasError = false;
    _errorMessage = null;
    _viewsIncremented = false;
    _didComplete = false;
    if (mounted) setState(() {});
    await _initializePlayer();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_currentRecording.title),
        backgroundColor: Colors.black,
        border: null,
        trailing: GestureDetector(
          onTap: _togglePlayPause,
          child: Icon(
            _controller?.value.isPlaying == true
                ? CupertinoIcons.pause_fill
                : CupertinoIcons.play_fill,
            color: Colors.white,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back, color: Colors.white),
        ),
      ),
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Center(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const CupertinoActivityIndicator(radius: 18, color: Colors.white);
    }
    if (_hasError || _controller == null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to play this recording',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final aspect = _controller!.value.aspectRatio == 0
        ? 16 / 9
        : _controller!.value.aspectRatio;

    // Use Expanded to allocate remaining height to the video and keep controls inside SafeArea
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: aspect,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoPlayer(_controller!),
                  _buildWatermarkOverlay(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SafeArea(
          top: false,
          child: _buildControls(),
        ),
      ],
    );
  }

  Widget _buildWatermarkOverlay() {
    final url = VAppConfigController.appConfig.liveWatermarkUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    final fullUrl = _normalizeUrl(url);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Opacity(
            opacity: 0.5,
            child: Image.network(
              fullUrl,
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (_controller == null) return const SizedBox.shrink();
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: _togglePlayPause,
                child: Icon(
                  _controller!.value.isPlaying
                      ? CupertinoIcons.pause_solid
                      : CupertinoIcons.play_arrow_solid,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(_formatDuration(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                    min: 0,
                    max: duration.inMilliseconds.toDouble(),
                    onChanged: (v) async {
                      await _controller!.seekTo(Duration(milliseconds: v.toInt()));
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ),
              Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
