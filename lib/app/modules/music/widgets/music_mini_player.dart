import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:v_chat_voice_player/v_chat_voice_player.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

typedef MusicMiniVideoOpener = Future<void> Function(
  NavigatorState navigator,
  VideoPlayerController controller,
);

typedef MusicMiniAudioOpener = Future<void> Function(
  NavigatorState navigator,
  VVoiceMessageController controller,
);

class MusicMiniPlayerController extends ChangeNotifier {
  MusicMiniPlayerController._();

  static final MusicMiniPlayerController instance =
      MusicMiniPlayerController._();

  String _title = '';
  VideoPlayerController? _videoController;
  VVoiceMessageController? _audioController;
  MusicMiniVideoOpener? _videoOpener;
  MusicMiniAudioOpener? _audioOpener;
  bool _isVideo = false;

  String get title => _title;
  bool get hasPlayer => _videoController != null || _audioController != null;
  bool get isVideo => _isVideo;
  VideoPlayerController? get videoController => _videoController;
  VVoiceMessageController? get audioController => _audioController;

  Future<void> showVideo({
    required String title,
    required VideoPlayerController controller,
    required MusicMiniVideoOpener onOpenFullPlayer,
  }) async {
    await _disposeCurrent();
    _title = title;
    _videoController = controller;
    _videoOpener = onOpenFullPlayer;
    _isVideo = true;
    unawaited(WakelockPlus.enable());
    notifyListeners();
  }

  Future<void> showAudio({
    required String title,
    required VVoiceMessageController controller,
    required MusicMiniAudioOpener onOpenFullPlayer,
  }) async {
    await _disposeCurrent();
    _title = title;
    _audioController = controller;
    _audioOpener = onOpenFullPlayer;
    _isVideo = false;
    unawaited(WakelockPlus.enable());
    notifyListeners();
  }

  Future<void> openFullPlayer(NavigatorState? navigator) async {
    if (navigator == null) return;
    if (_isVideo) {
      final controller = _videoController;
      final opener = _videoOpener;
      if (controller == null || opener == null) return;
      _clearWithoutDisposing();
      notifyListeners();
      await opener(navigator, controller);
      return;
    }

    final controller = _audioController;
    final opener = _audioOpener;
    if (controller == null || opener == null) return;
    _clearWithoutDisposing();
    notifyListeners();
    await opener(navigator, controller);
  }

  Future<void> close() async {
    await _disposeCurrent();
    notifyListeners();
  }

  void _clearWithoutDisposing() {
    _videoController = null;
    _audioController = null;
    _videoOpener = null;
    _audioOpener = null;
    _title = '';
    _isVideo = false;
  }

  Future<void> _disposeCurrent() async {
    final oldVideo = _videoController;
    final oldAudio = _audioController;
    final hadPlayer = oldVideo != null || oldAudio != null;
    _clearWithoutDisposing();

    try {
      await oldVideo?.pause();
    } catch (_) {}
    try {
      oldVideo?.dispose();
    } catch (_) {}
    try {
      oldAudio?.pausePlaying();
    } catch (_) {}
    try {
      oldAudio?.dispose();
    } catch (_) {}
    if (hadPlayer) {
      unawaited(WakelockPlus.disable());
    }
  }
}

class MusicMiniPlayerOverlay extends StatefulWidget {
  final NavigatorState? Function() navigatorProvider;

  const MusicMiniPlayerOverlay({
    super.key,
    required this.navigatorProvider,
  });

  static const _gold = Color(0xFFB48648);

  @override
  State<MusicMiniPlayerOverlay> createState() => _MusicMiniPlayerOverlayState();
}

class _MusicMiniPlayerOverlayState extends State<MusicMiniPlayerOverlay> {
  Offset? _position;

  Offset _clampPosition({
    required Offset position,
    required Size screenSize,
    required EdgeInsets padding,
    required double playerWidth,
    required double playerHeight,
  }) {
    final minX = 8.0;
    final minY = padding.top + 8;
    final rawMaxX = screenSize.width - playerWidth - 8;
    final rawMaxY = screenSize.height - padding.bottom - playerHeight - 8;
    final maxX = rawMaxX < minX ? minX : rawMaxX;
    final maxY = rawMaxY < minY ? minY : rawMaxY;

    return Offset(
      position.dx.clamp(minX, maxX).toDouble(),
      position.dy.clamp(minY, maxY).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = MusicMiniPlayerController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.hasPlayer) return const SizedBox.shrink();

        final mediaSize = MediaQuery.sizeOf(context);
        final padding = MediaQuery.paddingOf(context);
        final playerWidth =
            mediaSize.width < 380 ? mediaSize.width - 24 : 320.0;
        final playerHeight = controller.isVideo ? playerWidth * 9 / 16 : 76.0;
        final defaultPosition = Offset(
          mediaSize.width - playerWidth - 12,
          mediaSize.height - padding.bottom - playerHeight - 14,
        );
        final currentPosition = _clampPosition(
          position: _position ?? defaultPosition,
          screenSize: mediaSize,
          padding: padding,
          playerWidth: playerWidth,
          playerHeight: playerHeight,
        );

        return Positioned(
          left: currentPosition.dx,
          top: currentPosition.dy,
          child: _MiniPlayerSurface(
            controller: controller,
            navigatorProvider: widget.navigatorProvider,
            width: playerWidth,
            onPanUpdate: (details) {
              setState(() {
                _position = _clampPosition(
                  position: currentPosition + details.delta,
                  screenSize: mediaSize,
                  padding: padding,
                  playerWidth: playerWidth,
                  playerHeight: playerHeight,
                );
              });
            },
          ),
        );
      },
    );
  }
}

class _MiniPlayerSurface extends StatelessWidget {
  const _MiniPlayerSurface({
    required this.controller,
    required this.navigatorProvider,
    required this.width,
    required this.onPanUpdate,
  });

  final MusicMiniPlayerController controller;
  final NavigatorState? Function() navigatorProvider;
  final double width;
  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(
          controller.openFullPlayer(navigatorProvider()),
        ),
        onPanUpdate: onPanUpdate,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: controller.isVideo
              ? _MiniVideoPlayer(controller: controller)
              : _MiniAudioPlayer(controller: controller),
        ),
      ),
    );
  }
}

class _MiniVideoPlayer extends StatelessWidget {
  const _MiniVideoPlayer({required this.controller});

  final MusicMiniPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final video = controller.videoController;
    if (video == null) return const SizedBox.shrink();

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ValueListenableBuilder(
        valueListenable: video,
        builder: (context, value, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: value.size.width,
                    height: value.size.height,
                    child: VideoPlayer(video),
                  ),
                )
              else
                const Center(child: CupertinoActivityIndicator()),
              _MiniGradient(),
              Positioned(
                left: 10,
                right: 86,
                bottom: 9,
                child: Text(
                  controller.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                right: 48,
                bottom: 2,
                child: _MiniIconButton(
                  icon: value.isPlaying
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  onPressed: () async {
                    if (video.value.isPlaying) {
                      await video.pause();
                    } else {
                      if (video.value.position >= video.value.duration) {
                        await video.seekTo(Duration.zero);
                      }
                      await video.play();
                    }
                  },
                ),
              ),
              Positioned(
                right: 6,
                bottom: 2,
                child: _MiniIconButton(
                  icon: CupertinoIcons.xmark,
                  onPressed: MusicMiniPlayerController.instance.close,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniAudioPlayer extends StatelessWidget {
  const _MiniAudioPlayer({required this.controller});

  final MusicMiniPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final audio = controller.audioController;
    if (audio == null) return const SizedBox.shrink();

    return ValueListenableBuilder(
      valueListenable: audio,
      builder: (context, value, _) {
        return SizedBox(
          height: 76,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MusicMiniPlayerOverlay._gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.music_note_2,
                  color: MusicMiniPlayerOverlay._gold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        value: value.progress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          MusicMiniPlayerOverlay._gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _MiniIconButton(
                icon: value.isPlaying
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                onPressed: () async {
                  if (audio.value.isPlaying) {
                    audio.pausePlaying();
                  } else {
                    await audio.initAndPlay();
                  }
                },
              ),
              _MiniIconButton(
                icon: CupertinoIcons.xmark,
                onPressed: MusicMiniPlayerController.instance.close,
              ),
              const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final FutureOr<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(Future<void>.sync(onPressed)),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _MiniGradient extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Color(0xAA000000),
          ],
        ),
      ),
    );
  }
}
