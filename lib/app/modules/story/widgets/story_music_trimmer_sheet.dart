import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:super_up_core/super_up_core.dart';

class StoryMusicTrimmerSheet extends StatefulWidget {
  final Map<String, dynamic> musicItem;
  final void Function(Map<String, dynamic> trimmedData) onTrimmed;

  const StoryMusicTrimmerSheet({
    super.key,
    required this.musicItem,
    required this.onTrimmed,
  });

  @override
  State<StoryMusicTrimmerSheet> createState() => _StoryMusicTrimmerSheetState();
}

class _StoryMusicTrimmerSheetState extends State<StoryMusicTrimmerSheet> {
  final _player = AudioPlayer();
  double _startOffset = 0.0; // in seconds
  double _totalDuration = 0.0; // in seconds
  bool _initialized = false;
  bool _isPlaying = false;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _absoluteUrl(String raw) {
    if (raw.startsWith('http')) return raw;
    return SConstants.baseMediaUrl + raw;
  }

  Future<void> _initPlayer() async {
    final rawUrl = (widget.musicItem['mediaUrl'] ?? widget.musicItem['url'] ?? '').toString();
    if (rawUrl.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final fullUrl = _absoluteUrl(rawUrl);

    try {
      final duration = await _player.setUrl(fullUrl);
      if (!mounted) return;

      setState(() {
        _totalDuration = (duration?.inMilliseconds ?? 0) / 1000.0;
        _initialized = true;
      });

      // Play the song starting at 0.0
      await _player.seek(Duration.zero);
      await _player.play();

      _positionSubscription = _player.positionStream.listen((pos) {
        if (!mounted) return;
        final maxEnd = _startOffset + 15.0;
        // Loop back to start offset if position exceeds 15 seconds snippet length
        if (pos.inMilliseconds / 1000.0 >= maxEnd) {
          _player.seek(Duration(milliseconds: (_startOffset * 1000).toInt()));
        }
      });

      _playerStateSubscription = _player.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _isPlaying = state.playing;
        });
      });
    } catch (_) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Failed to load audio preview',
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _onSliderChanged(double value) {
    setState(() {
      _startOffset = value;
    });
    // Seek to the new start point instantly during drag for better feel
    _player.seek(Duration(milliseconds: (value * 1000).toInt()));
  }

  void _togglePlay() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _done() {
    final musicId = (widget.musicItem['_id'] ?? widget.musicItem['id'] ?? '').toString();
    final rawUrl = (widget.musicItem['mediaUrl'] ?? widget.musicItem['url'] ?? '').toString();
    final title = (widget.musicItem['title'] ?? 'Untitled').toString();
    final artist = (widget.musicItem['uploaderData']?['fullName'] ?? 'Unknown').toString();
    
    final endOffset = _totalDuration > _startOffset + 15.0 
        ? _startOffset + 15.0 
        : _totalDuration;

    widget.onTrimmed({
      'musicId': musicId,
      'musicUrl': rawUrl,
      'title': title,
      'artist': artist,
      'startMs': (_startOffset * 1000).toInt(),
      'endMs': (endOffset * 1000).toInt(),
    });
    Navigator.of(context).pop();
  }

  String _formatDuration(double seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height * 0.45,
          child: !_initialized
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoActivityIndicator(radius: 12),
                      SizedBox(height: 12),
                      Text(
                        'Loading music preview...',
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(top: 10, bottom: 20),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text(
                        (widget.musicItem['title'] ?? 'Untitled').toString(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.label,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (widget.musicItem['uploaderData']?['fullName'] ?? 'Unknown').toString(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _togglePlay,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFB48648),
                              ),
                              child: Icon(
                                _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        'Drag to trim 15s snippet',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _formatDuration(_startOffset),
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                          Expanded(
                            child: CupertinoSlider(
                              min: 0.0,
                              max: _totalDuration > 15.0 ? _totalDuration - 15.0 : 0.1,
                              value: _startOffset.clamp(
                                0.0,
                                _totalDuration > 15.0 ? _totalDuration - 15.0 : 0.1,
                              ),
                              activeColor: const Color(0xFFB48648),
                              onChanged: _onSliderChanged,
                            ),
                          ),
                          Text(
                            _formatDuration(_totalDuration > _startOffset + 15.0 
                                ? _startOffset + 15.0 
                                : _totalDuration),
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              color: CupertinoColors.systemGrey5,
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: CupertinoColors.label),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CupertinoButton(
                              color: const Color(0xFFB48648),
                              onPressed: _done,
                              child: const Text('Done'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
