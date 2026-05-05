import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:v_platform/v_platform.dart';
import 'package:v_chat_voice_player/v_chat_voice_player.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MusicAudioPlayerPage extends StatefulWidget {
  final String title;
  final String url;
  final bool autoPlay;
  final Future<void> Function(BuildContext context)? onPlayNext;
  final Future<void> Function(BuildContext context)? onPlayPrevious;
  final Future<void> Function(BuildContext context)? onDownload;

  const MusicAudioPlayerPage({
    super.key,
    required this.title,
    required this.url,
    this.autoPlay = true,
    this.onPlayNext,
    this.onPlayPrevious,
    this.onDownload,
  });

  @override
  State<MusicAudioPlayerPage> createState() => _MusicAudioPlayerPageState();
}

class _MusicAudioPlayerPageState extends State<MusicAudioPlayerPage> {
  late final VVoiceMessageController _controller;

  void _stopPlayback() {
    try {
      _controller.pausePlaying();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    // Enable wakelock to keep screen awake during music playback
    WakelockPlus.enable();
    
    final src = VPlatformFile.fromUrl(networkUrl: widget.url);
    _controller = VVoiceMessageController(
      id: 'music_${widget.title}_${widget.url.hashCode}',
      audioSrc: src,
      onComplete: (_) {
        widget.onPlayNext?.call(context);
      },
    );
    if (widget.autoPlay) {
      _controller.initAndPlay();
    }
  }

  @override
  void dispose() {
    _stopPlayback();
    // Disable wakelock when leaving music player
    WakelockPlus.disable();
    _controller.dispose();
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
          trailing: CupertinoButton(
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
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.music_note_2, size: 42, color: Color(0xFFB48648)),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  VVoiceMessageView(
                    controller: _controller,
                    colorConfig: const VoiceColorConfig(
                      activeSliderColor: Color(0xFFB48648),
                    ),
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
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
