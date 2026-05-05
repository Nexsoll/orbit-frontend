import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MusicVideoPlayerPage extends StatefulWidget {
  final String title;
  final String url;
  final bool autoPlay;
  final Future<void> Function(BuildContext context)? onPlayNext;
  final Future<void> Function(BuildContext context)? onPlayPrevious;
  final Future<void> Function(BuildContext context)? onDownload;

  const MusicVideoPlayerPage({
    super.key,
    required this.title,
    required this.url,
    this.autoPlay = true,
    this.onPlayNext,
    this.onPlayPrevious,
    this.onDownload,
  });

  @override
  State<MusicVideoPlayerPage> createState() => _MusicVideoPlayerPageState();
}

class _MusicVideoPlayerPageState extends State<MusicVideoPlayerPage> {
  static const MethodChannel _pipChannel =
      MethodChannel('com.orbit.ke/picture_in_picture');

  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _isCompletedHandled = false;
  bool _pipSupported = false;

  void _stopPlayback() {
    final c = _controller;
    if (c == null) return;
    try {
      c.pause();
      c.seekTo(Duration.zero);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _init();
    _loadPipSupport();
  }

  bool get _platformSupportsPip {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _loadPipSupport() async {
    if (!_platformSupportsPip) return;
    try {
      final isSupported =
          await _pipChannel.invokeMethod<bool>('isPictureInPictureSupported');
      if (!mounted) return;
      setState(() {
        _pipSupported = isSupported == true;
      });
    } catch (_) {}
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    await c.initialize();
    c.setLooping(false);
    c.addListener(_onVideoTick);
    if (widget.autoPlay) {
      await c.play();
    }
    if (!mounted) return;
    setState(() {
      _isReady = true;
    });
  }

  Future<void> _enterPictureInPicture() async {
    if (!_platformSupportsPip) return;
    if (!_pipSupported) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Picture in Picture'),
          content: const Text('Picture in Picture is not supported on this device.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _pipChannel.invokeMethod<bool>('enterPictureInPictureMode', {
          'url': widget.url,
        });
      } else {
        await _pipChannel.invokeMethod<bool>('enterPictureInPictureMode');
      }
    } catch (_) {}
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

  @override
  void dispose() {
    _stopPlayback();
    WakelockPlus.disable();
    final c = _controller;
    if (c != null) {
      c.removeListener(_onVideoTick);
      c.dispose();
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
              if (_platformSupportsPip) ...[
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 30,
                  onPressed: _isReady && _controller != null ? _enterPictureInPicture : null,
                  child: Icon(
                    CupertinoIcons.rectangle_on_rectangle,
                    color: _pipSupported
                        ? const Color(0xFFB48648)
                        : CupertinoColors.systemGrey,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
              ],
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
                            child: GestureDetector(
                              onTap: () async {
                                if (_controller!.value.isPlaying) {
                                  await _controller!.pause();
                                } else {
                                  if (_controller!.value.position >=
                                      _controller!.value.duration) {
                                    _isCompletedHandled = false;
                                    await _controller!.seekTo(Duration.zero);
                                  }
                                  await _controller!.play();
                                }
                                if (mounted) setState(() {});
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  VideoPlayer(_controller!),
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
                              : _controller!.value.duration.inMilliseconds.toDouble(),
                          value: _controller!.value.position.inMilliseconds
                              .clamp(
                                0,
                                _controller!.value.duration.inMilliseconds <= 0
                                    ? 1
                                    : _controller!.value.duration.inMilliseconds,
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
