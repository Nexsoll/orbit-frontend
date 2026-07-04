import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/modules/music/views/music_audio_player_page.dart';
import 'package:super_up/app/modules/music/views/music_video_player_page.dart';
import 'package:super_up_core/super_up_core.dart';

class MusicShareMessageWidget extends StatelessWidget {
  final bool isMeSender;
  final Map<String, dynamic> data;

  const MusicShareMessageWidget({
    super.key,
    required this.isMeSender,
    required this.data,
  });

  String get _title =>
      (data['title'] ?? data['name'] ?? data['fileName'] ?? 'Shared content')
          .toString();

  String get _rawUrl =>
      (data['mediaUrl'] ?? data['url'] ?? data['fileUrl'] ?? '').toString();

  String get _mediaType => (data['mediaType'] ?? '').toString().toLowerCase();

  String get _mimeType => (data['mimeType'] ?? '').toString().toLowerCase();

  String get _rawThumbnail =>
      (data['thumbnailUrl'] ?? data['thumbUrl'] ?? data['thumb'] ?? '')
          .toString();

  String get _uploaderName =>
      (data['uploaderName'] ?? data['uploader'] ?? '').toString();

  String get _uploaderImage =>
      (data['uploaderImage'] ?? data['uploaderImg'] ?? '').toString();

  String get _musicId => (data['musicId'] ?? data['_id'] ?? data['id'] ?? '')
      .toString();

  Map<String, dynamic>? get _initialSubtitles => data['subtitles'] is Map
      ? Map<String, dynamic>.from(data['subtitles'])
      : null;

  bool get _isArticle {
    if (data['isArticle'] == true) return true;
    if (_mediaType == 'article' || _mediaType == 'pdf') return true;
    if (_mimeType == 'application/pdf') return true;
    if (_rawUrl.toLowerCase().endsWith('.pdf')) return true;
    return false;
  }

  bool get _isAudio {
    if (_mediaType == 'audio') return true;
    if (_mimeType.startsWith('audio/')) return true;
    final lower = _rawUrl.toLowerCase();
    const audioExts = [
      '.mp3',
      '.m4a',
      '.aac',
      '.wav',
      '.ogg',
      '.flac',
      '.opus'
    ];
    return audioExts.any(lower.contains);
  }

  String _fullUrl(String raw) {
    if (raw.isEmpty) return raw;
    return raw.startsWith('http') ? raw : SConstants.baseMediaUrl + raw;
  }

  Future<void> _open(BuildContext context) async {
    if (_rawUrl.isEmpty) return;
    final url = _fullUrl(_rawUrl);

    if (_isArticle) {
      await VStringUtils.lunchLink(url);
      return;
    }

    if (_isAudio) {
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => MusicAudioPlayerPage(
            title: _title,
            url: url,
            musicId: _musicId.isEmpty ? null : _musicId,
            initialSubtitles: _initialSubtitles,
            autoPlay: true,
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => MusicVideoPlayerPage(
          title: _title,
          url: url,
          musicId: _musicId.isEmpty ? null : _musicId,
          initialSubtitles: _initialSubtitles,
          autoPlay: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _title;
    final thumb = _fullUrl(_rawThumbnail);
    final uploaderName = _uploaderName;
    final uploaderImg = _fullUrl(_uploaderImage);

    IconData icon;
    if (_isArticle) {
      icon = CupertinoIcons.doc_text;
    } else if (_isAudio) {
      icon = CupertinoIcons.music_note_2;
    } else {
      icon = CupertinoIcons.play_rectangle;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 56,
                height: 56,
                color: const Color(0xFFB48648).withOpacity(0.12),
                child: _rawThumbnail.isNotEmpty && !_isAudio && !_isArticle
                    ? Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Icon(
                          icon,
                          color: const Color(0xFFB48648),
                          size: 26,
                        ),
                      )
                    : Icon(
                        icon,
                        color: const Color(0xFFB48648),
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (uploaderImg.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.network(
                            uploaderImg,
                            width: 18,
                            height: 18,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              CupertinoIcons.person_alt_circle,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      else
                        const Icon(
                          CupertinoIcons.person_alt_circle,
                          size: 18,
                          color: Colors.grey,
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          uploaderName.isEmpty ? 'Shared content' : uploaderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFB48648),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isArticle
                        ? 'Tap to open'
                        : _isAudio
                            ? 'Tap to play audio'
                            : 'Tap to play video',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
