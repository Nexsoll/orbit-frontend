import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/music_api_service.dart';
import '../services/music_subtitles.dart';
import '../widgets/music_mini_player.dart';
import 'music_search_suggestions_sheet.dart';

class MusicVideoPlayerPage extends StatefulWidget {
  final String title;
  final String url;
  final String? musicId;
  final Map<String, dynamic>? initialSubtitles;
  final bool autoPlay;
  final void Function(Map<String, dynamic> subtitles)? onSubtitlesUpdated;
  final Future<void> Function(BuildContext context)? onPlayNext;
  final Future<void> Function(BuildContext context)? onPlayPrevious;
  final Future<void> Function(BuildContext context)? onDownload;
  final MusicSearchSelectionHandler? onPlaySearchResult;
  final VideoPlayerController? initialController;

  const MusicVideoPlayerPage({
    super.key,
    required this.title,
    required this.url,
    this.musicId,
    this.initialSubtitles,
    this.autoPlay = true,
    this.onSubtitlesUpdated,
    this.onPlayNext,
    this.onPlayPrevious,
    this.onDownload,
    this.onPlaySearchResult,
    this.initialController,
  });

  @override
  State<MusicVideoPlayerPage> createState() => _MusicVideoPlayerPageState();
}

class _MusicVideoPlayerPageState extends State<MusicVideoPlayerPage> {
  static const Duration _subtitleLookAhead = Duration(minutes: 4);
  late final MusicApiService _musicApi;
  VideoPlayerController? _controller;
  MusicSubtitles _subtitles = MusicSubtitles.empty();
  bool _isReady = false;
  bool _isCompletedHandled = false;
  bool _subtitleLoading = false;
  bool _releasedToMiniPlayer = false;
  bool _subtitleGenerationRequested = false;
  Timer? _subtitlePollTimer;
  bool _showSubtitles = true;
  bool _showForwardIndicator = false;
  bool _showBackwardIndicator = false;
  int _forwardIndicatorKey = 0;
  int _backwardIndicatorKey = 0;

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void _performSeek({required bool isForward}) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    final current = c.value.position;
    final max = c.value.duration;

    _isCompletedHandled = false;

    final seekAmount = const Duration(seconds: 10);
    final target = isForward ? current + seekAmount : current - seekAmount;
    final clamped = _clampDuration(target, Duration.zero, max);

    c.seekTo(clamped);

    setState(() {
      if (isForward) {
        _showForwardIndicator = true;
        _showBackwardIndicator = false;
        _forwardIndicatorKey++;
      } else {
        _showBackwardIndicator = true;
        _showForwardIndicator = false;
        _backwardIndicatorKey++;
      }
    });
  }

  bool _hasLyricsForPosition(Duration position) {
    if (_subtitles.isFailed && _subtitleGenerationRequested) return true;
    if (!_subtitles.isReady) return false;
    return !_subtitles.chunked || _subtitles.hasRangeAt(position);
  }

  Future<void> _waitForLyricsBeforePlayback(Duration position) async {
    await _loadSubtitlesIfNeeded(position: position);
    for (var i = 0; i < 24; i++) {
      if (!mounted || _hasLyricsForPosition(position)) return;
      await Future<void>.delayed(const Duration(seconds: 2));
      await _loadSubtitlesIfNeeded(position: position);
    }
  }

  Future<void> _playAfterLyricsAt(Duration position) async {
    await _waitForLyricsBeforePlayback(position);
    if (!mounted) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    await c.play();
    _scheduleSubtitlePollIfNeeded();
  }

  void _stopPlayback() {
    final c = _controller;
    if (c == null) return;
    try {
      c.pause();
      c.seekTo(Duration.zero);
    } catch (_) {}
  }

  Future<void> _openSearch() async {
    if (widget.onPlaySearchResult == null) return;
    await showMusicSearchSuggestionsSheet(
      context: context,
      api: _musicApi,
      currentMusicId: widget.musicId,
      onSelected: (ctx, item, sourceItems) async {
        _stopPlayback();
        await widget.onPlaySearchResult!(ctx, item, sourceItems);
      },
    );
  }

  Future<void> _minimizeToMiniPlayer() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    c.removeListener(_onVideoTick);
    _releasedToMiniPlayer = true;
    _controller = null;

    await MusicMiniPlayerController.instance.showVideo(
      title: widget.title,
      controller: c,
      onOpenFullPlayer: (navigator, controller) async {
        await navigator.push(
          CupertinoPageRoute(
            builder: (_) => MusicVideoPlayerPage(
              title: widget.title,
              url: widget.url,
              musicId: widget.musicId,
              initialSubtitles: _subtitles.toMap(),
              autoPlay: widget.autoPlay,
              onSubtitlesUpdated: widget.onSubtitlesUpdated,
              onPlayNext: widget.onPlayNext,
              onPlayPrevious: widget.onPlayPrevious,
              onDownload: widget.onDownload,
              onPlaySearchResult: widget.onPlaySearchResult,
              initialController: controller,
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _loadSubtitlesIfNeeded({Duration? position}) async {
    final musicId = (widget.musicId ?? '').trim();
    final needsChunk = _subtitles.isReady &&
        _subtitles.chunked &&
        position != null &&
        !_subtitles.hasRangeAt(position);
    if (musicId.isEmpty ||
        _subtitleLoading ||
        (_subtitles.isReady && !needsChunk)) {
      return;
    }
    if (_subtitles.isFailed && _subtitleGenerationRequested) return;

    setState(() => _subtitleLoading = true);
    try {
      Map<String, dynamic> data;
      if (_subtitleGenerationRequested &&
          (!needsChunk ||
              (position != null && _subtitles.isProcessingAt(position)))) {
        data = await _musicApi.getSubtitles(
          musicId: musicId,
          position: position,
        );
      } else {
        _subtitleGenerationRequested = true;
        data = await _musicApi.generateSubtitles(
          musicId: musicId,
          position: position,
        );
      }
      if (!mounted) return;
      setState(() {
        _subtitles = MusicSubtitles.fromMap(data);
      });
      widget.onSubtitlesUpdated?.call(data);
      _scheduleSubtitlePollIfNeeded();
    } catch (e) {
      if (!mounted) return;
      final failed = <String, dynamic>{
        'status': 'failed',
        'text': '',
        'segments': <Map<String, dynamic>>[],
        'error': e.toString(),
      };
      setState(() {
        _subtitles = MusicSubtitles.fromMap(failed);
      });
      widget.onSubtitlesUpdated?.call(failed);
    } finally {
      if (mounted) setState(() => _subtitleLoading = false);
    }
  }

  void _scheduleSubtitlePollIfNeeded() {
    if ((_subtitles.isReady && !_subtitles.chunked) ||
        (_subtitles.isFailed && _subtitleGenerationRequested)) {
      _subtitlePollTimer?.cancel();
      _subtitlePollTimer = null;
      return;
    }
    if (_subtitlePollTimer != null) return;

    _subtitlePollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if ((_subtitles.isReady && !_subtitles.chunked) ||
          (_subtitles.isFailed && _subtitleGenerationRequested)) {
        _subtitlePollTimer?.cancel();
        _subtitlePollTimer = null;
        return;
      }
      if (_subtitleLoading) return;

      final c = _controller;
      if (c == null || !c.value.isInitialized) return;
      final currentPosition = c.value.position;
      Duration? requestPosition;
      if (_subtitles.isReady && _subtitles.chunked) {
        requestPosition = _subtitles.missingPrefetchPosition(
          currentPosition,
          lookAhead: _subtitleLookAhead,
        );
      } else if (c.value.isPlaying ||
          _subtitles.isProcessing ||
          _subtitles.status == 'not_requested') {
        requestPosition = currentPosition;
      }
      if (requestPosition == null) return;
      unawaited(_loadSubtitlesIfNeeded(position: requestPosition));
    });
  }

  String _activeSubtitleText() {
    final c = _controller;
    if (c == null || !c.value.isInitialized || !_subtitles.isReady) return '';
    final text = _subtitles.segmentAt(c.value.position)?.text;
    if (text != null && text.trim().isNotEmpty) return text;
    if (_subtitles.chunked &&
        (!_subtitles.hasRangeAt(c.value.position) ||
            _subtitles.isProcessingAt(c.value.position))) {
      return c.value.isPlaying ? '' : 'Generating lyrics';
    }
    if (_subtitles.chunked) return '';
    return _subtitles.segments.isEmpty ? _subtitles.text : '';
  }

  String _subtitleStatusText() {
    if (_subtitles.isFailed && _subtitleGenerationRequested) {
      final error = _subtitles.displayError.trim();
      return error.isEmpty ? 'Lyrics unavailable' : error;
    }
    return 'Generating lyrics';
  }

  @override
  void initState() {
    super.initState();
    unawaited(MusicMiniPlayerController.instance.close());
    WakelockPlus.enable();
    _musicApi = MusicApiService.init();
    _subtitles = MusicSubtitles.fromMap(widget.initialSubtitles);
    if (widget.initialController != null) {
      _attachInitialController(widget.initialController!);
      unawaited(_loadSubtitlesIfNeeded(position: _controller?.value.position));
      _scheduleSubtitlePollIfNeeded();
    } else {
      unawaited(_init());
    }
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    await c.initialize();
    c.setLooping(false);
    c.addListener(_onVideoTick);
    if (!mounted) return;
    setState(() {
      _isReady = true;
    });
    if (widget.autoPlay) {
      await _playAfterLyricsAt(Duration.zero);
    } else {
      unawaited(_loadSubtitlesIfNeeded(position: Duration.zero));
      _scheduleSubtitlePollIfNeeded();
    }
  }

  void _attachInitialController(VideoPlayerController controller) {
    _controller = controller;
    controller.setLooping(false);
    controller.addListener(_onVideoTick);
    _isReady = controller.value.isInitialized;
  }

  void _onVideoTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (mounted) setState(() {});

    if (_isCompletedHandled) return;

    final pos = c.value.position;
    final dur = c.value.duration;
    if (dur.inMilliseconds > 0 &&
        pos.inMilliseconds >= dur.inMilliseconds - 200) {
      _isCompletedHandled = true;
      widget.onPlayNext?.call(context);
    }
  }

  String _formatDuration(Duration d) {
    final total = d.inSeconds;
    final mins = (total ~/ 60).toString().padLeft(2, '0');
    final secs = (total % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Widget _buildSubtitleOverlay() {
    if (!_showSubtitles) return const SizedBox.shrink();

    final musicId = (widget.musicId ?? '').trim();
    if (musicId.isEmpty) return const SizedBox.shrink();
    final c = _controller;
    if (!_subtitles.isReady && c?.value.isPlaying == true) {
      return const SizedBox.shrink();
    }

    final text =
        _subtitles.isReady ? _activeSubtitleText() : _subtitleStatusText();
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: _subtitles.isReady ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subtitlePollTimer?.cancel();
    if (!_releasedToMiniPlayer) {
      _stopPlayback();
      WakelockPlus.disable();
      final c = _controller;
      if (c != null) {
        c.removeListener(_onVideoTick);
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _stopPlayback();
        return true;
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(widget.title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 30,
                onPressed: _isReady && _controller != null
                    ? _minimizeToMiniPlayer
                    : null,
                child: const Icon(
                  CupertinoIcons.chevron_down,
                  color: Color(0xFFB48648),
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 30,
                onPressed: () {
                  setState(() {
                    _showSubtitles = !_showSubtitles;
                  });
                },
                child: Icon(
                  _showSubtitles ? Icons.subtitles : Icons.subtitles_off,
                  color: const Color(0xFFB48648),
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 30,
                onPressed:
                    widget.onPlaySearchResult == null ? null : _openSearch,
                child: const Icon(
                  CupertinoIcons.search,
                  color: Color(0xFFB48648),
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 30,
                onPressed: widget.onDownload == null
                    ? null
                    : () => widget.onDownload!.call(context),
                child: const Icon(
                  CupertinoIcons.arrow_down_to_line,
                  color: Color(0xFFB48648),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: Container(
            color: Colors.black,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: _isReady && _controller != null
                        ? AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio == 0
                                ? 9 / 16
                                : _controller!.value.aspectRatio,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return GestureDetector(
                                  onTap: () async {
                                    if (_controller!.value.isPlaying) {
                                      await _controller!.pause();
                                    } else {
                                      if (_controller!.value.position >=
                                          _controller!.value.duration) {
                                        _isCompletedHandled = false;
                                        await _controller!.seekTo(Duration.zero);
                                      }
                                      await _playAfterLyricsAt(
                                        _controller!.value.position,
                                      );
                                    }
                                    if (mounted) setState(() {});
                                  },
                                  onDoubleTapDown: (details) {
                                    final width = constraints.maxWidth;
                                    final x = details.localPosition.dx;
                                    if (x < width / 2) {
                                      _performSeek(isForward: false);
                                    } else {
                                      _performSeek(isForward: true);
                                    }
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      VideoPlayer(_controller!),
                                      _buildSubtitleOverlay(),
                                      if (_showBackwardIndicator)
                                        _DoubleTapSeekIndicator(
                                          key: ValueKey(_backwardIndicatorKey),
                                          isForward: false,
                                          value: 10,
                                          onComplete: () {
                                            setState(() {
                                              _showBackwardIndicator = false;
                                            });
                                          },
                                        ),
                                      if (_showForwardIndicator)
                                        _DoubleTapSeekIndicator(
                                          key: ValueKey(_forwardIndicatorKey),
                                          isForward: true,
                                          value: 10,
                                          onComplete: () {
                                            setState(() {
                                              _showForwardIndicator = false;
                                            });
                                          },
                                        ),
                                      if (_controller!.value.isPlaying)
                                        IgnorePointer(
                                          child: Align(
                                            alignment: Alignment.topRight,
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                  right: 14, top: 14),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.28),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'Orbit',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (!_controller!.value.isPlaying)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB48648)
                                                .withValues(alpha: 0.88),
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(14),
                                          child: const Icon(
                                            CupertinoIcons.play_fill,
                                            color: Colors.white,
                                            size: 34,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        : const CupertinoActivityIndicator(),
                  ),
                ),
                if (_isReady && _controller != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        CupertinoSlider(
                          min: 0,
                          max: _controller!.value.duration.inMilliseconds <= 0
                              ? 1
                              : _controller!.value.duration.inMilliseconds
                                  .toDouble(),
                          value: _controller!.value.position.inMilliseconds
                              .clamp(
                                0,
                                _controller!.value.duration.inMilliseconds <= 0
                                    ? 1
                                    : _controller!
                                        .value.duration.inMilliseconds,
                              )
                              .toDouble(),
                          activeColor: const Color(0xFFB48648),
                          onChanged: (v) async {
                            _isCompletedHandled = false;
                            await _controller!
                                .seekTo(Duration(milliseconds: v.toInt()));
                            if (mounted) setState(() {});
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Text(
                                _formatDuration(_controller!.value.position),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatDuration(_controller!.value.duration),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoButton(
                        onPressed: widget.onPlayPrevious == null
                            ? null
                            : () => widget.onPlayPrevious!.call(context),
                        child: const Icon(
                          CupertinoIcons.backward_end_fill,
                          size: 30,
                          color: Color(0xFFB48648),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        onPressed: widget.onPlayNext == null
                            ? null
                            : () => widget.onPlayNext!.call(context),
                        child: const Icon(
                          CupertinoIcons.forward_end_fill,
                          size: 30,
                          color: Color(0xFFB48648),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoubleTapSeekIndicator extends StatefulWidget {
  final bool isForward;
  final int value;
  final VoidCallback onComplete;

  const _DoubleTapSeekIndicator({
    super.key,
    required this.isForward,
    required this.value,
    required this.onComplete,
  });

  @override
  State<_DoubleTapSeekIndicator> createState() => _DoubleTapSeekIndicatorState();
}

class _DoubleTapSeekIndicatorState extends State<_DoubleTapSeekIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_animController);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Alignment alignment =
        widget.isForward ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = widget.isForward
        ? const BorderRadius.horizontal(left: Radius.elliptical(80, 160))
        : const BorderRadius.horizontal(right: Radius.elliptical(80, 160));

    final gradientColors = widget.isForward
        ? [Colors.transparent, Colors.black.withValues(alpha: 0.45)]
        : [Colors.black.withValues(alpha: 0.45), Colors.transparent];

    return Align(
      alignment: alignment,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.35,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: borderRadius,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: widget.isForward
                        ? const [
                            Icon(Icons.chevron_right, color: Colors.white, size: 18),
                            Icon(Icons.chevron_right, color: Colors.white, size: 24),
                            Icon(Icons.chevron_right, color: Colors.white, size: 18),
                          ]
                        : const [
                            Icon(Icons.chevron_left, color: Colors.white, size: 18),
                            Icon(Icons.chevron_left, color: Colors.white, size: 24),
                            Icon(Icons.chevron_left, color: Colors.white, size: 18),
                          ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.isForward ? "+" : "-"}${widget.value}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
