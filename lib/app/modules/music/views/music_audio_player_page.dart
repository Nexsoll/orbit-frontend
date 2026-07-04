import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:v_platform/v_platform.dart';
import 'package:v_chat_voice_player/v_chat_voice_player.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/music_api_service.dart';
import '../services/music_subtitles.dart';
import '../widgets/music_mini_player.dart';
import 'music_search_suggestions_sheet.dart';

class MusicAudioPlayerPage extends StatefulWidget {
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
  final VVoiceMessageController? initialController;

  const MusicAudioPlayerPage({
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
  State<MusicAudioPlayerPage> createState() => _MusicAudioPlayerPageState();
}

class _MusicAudioPlayerPageState extends State<MusicAudioPlayerPage> {
  static const Duration _subtitleLookAhead = Duration(minutes: 4);
  late final VVoiceMessageController _controller;
  late final MusicApiService _musicApi;
  MusicSubtitles _subtitles = MusicSubtitles.empty();
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
    final current = _controller.value.currentDuration;
    final max = _controller.value.maxDuration;

    final seekAmount = const Duration(seconds: 10);
    final target = isForward ? current + seekAmount : current - seekAmount;
    final clamped = _clampDuration(target, Duration.zero, max);

    unawaited(_controller.onSeek(clamped));

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

  Future<void> _startAfterInitialLyrics() async {
    await _waitForLyricsBeforePlayback(Duration.zero);
    if (!mounted) return;
    _controller.initAndPlay();
    _scheduleSubtitlePollIfNeeded();
  }

  void _stopPlayback() {
    try {
      _controller.pausePlaying();
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
    _releasedToMiniPlayer = true;

    await MusicMiniPlayerController.instance.showAudio(
      title: widget.title,
      controller: _controller,
      onOpenFullPlayer: (navigator, controller) async {
        await navigator.push(
          CupertinoPageRoute(
            builder: (_) => MusicAudioPlayerPage(
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

      final value = _controller.value;
      final currentPosition = value.currentDuration;
      Duration? requestPosition;
      if (_subtitles.isReady && _subtitles.chunked) {
        requestPosition = _subtitles.missingPrefetchPosition(
          currentPosition,
          lookAhead: _subtitleLookAhead,
        );
      } else if (value.isPlaying == true ||
          _subtitles.isProcessing ||
          _subtitles.status == 'not_requested') {
        requestPosition = currentPosition;
      }
      if (requestPosition == null) return;
      unawaited(_loadSubtitlesIfNeeded(position: requestPosition));
    });
  }

  Widget _buildSubtitlePanel(
    Duration position, {
    required bool isPlaying,
  }) {
    if (!_showSubtitles) return const SizedBox.shrink();

    final musicId = (widget.musicId ?? '').trim();
    if (musicId.isEmpty) return const SizedBox.shrink();

    if (_subtitles.isReady) {
      final activeText = _subtitles.segmentAt(position)?.text ??
          (_subtitles.chunked ? '' : _subtitles.text);
      if (activeText.trim().isEmpty) {
        if (isPlaying) return const SizedBox.shrink();
        if (_subtitles.chunked &&
            (!_subtitles.hasRangeAt(position) ||
                _subtitles.isProcessingAt(position))) {
          return _subtitleShell(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoActivityIndicator(radius: 8),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Generating lyrics',
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      }

      return _subtitleShell(
        child: Text(
          activeText,
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_subtitles.isFailed && _subtitleGenerationRequested) {
      final error = _subtitles.displayError.trim();
      return _subtitleShell(
        child: Text(
          error.isEmpty ? 'Lyrics/subtitles unavailable' : error,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    if (isPlaying) return const SizedBox.shrink();

    return _subtitleShell(
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(radius: 8),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Generating lyrics',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtitleShell({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        child: child,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(MusicMiniPlayerController.instance.close());
    // Enable wakelock to keep screen awake during music playback
    WakelockPlus.enable();
    _musicApi = MusicApiService.init();
    _subtitles = MusicSubtitles.fromMap(widget.initialSubtitles);

    final initialController = widget.initialController;
    if (initialController != null) {
      _controller = initialController;
    } else {
      final src = VPlatformFile.fromUrl(networkUrl: widget.url);
      _controller = VVoiceMessageController(
        id: 'music_${widget.title}_${widget.url.hashCode}',
        audioSrc: src,
        onComplete: (_) {
          widget.onPlayNext?.call(context);
        },
      );
    }
    if (widget.autoPlay && initialController == null) {
      unawaited(_startAfterInitialLyrics());
    } else {
      unawaited(_loadSubtitlesIfNeeded(position: Duration.zero));
      _scheduleSubtitlePollIfNeeded();
    }
  }

  @override
  void dispose() {
    _subtitlePollTimer?.cancel();
    if (!_releasedToMiniPlayer) {
      _stopPlayback();
      // Disable wakelock when leaving music player
      WakelockPlus.disable();
      _controller.dispose();
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
                onPressed: _minimizeToMiniPlayer,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
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
                  children: [
                    Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.music_note_2,
                                size: 42, color: Color(0xFFB48648)),
                            const SizedBox(height: 12),
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 20),
                            VVoiceMessageView(
                              controller: _controller,
                              colorConfig: const VoiceColorConfig(
                                activeSliderColor: Color(0xFFB48648),
                              ),
                            ),
                            ValueListenableBuilder(
                              valueListenable: _controller,
                              builder: (context, value, _) {
                                return _buildSubtitlePanel(
                                  value.currentDuration,
                                  isPlaying: value.isPlaying == true,
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            Row(
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
                            const SizedBox(height: 8),
                            Text(
                              S.of(context).downloading,
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        if (value.isPlaying != true) return const SizedBox.shrink();
                        return IgnorePointer(
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              margin: const EdgeInsets.only(right: 16, bottom: 16),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(10),
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
                        );
                      },
                    ),
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
                  ],
                ),
              );
            },
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
