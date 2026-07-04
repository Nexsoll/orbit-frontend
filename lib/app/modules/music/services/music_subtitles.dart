class MusicSubtitleSegment {
  final Duration start;
  final Duration end;
  final String text;

  const MusicSubtitleSegment({
    required this.start,
    required this.end,
    required this.text,
  });

  factory MusicSubtitleSegment.fromMap(Map<String, dynamic> map) {
    return MusicSubtitleSegment(
      start: Duration(
        milliseconds:
            ((num.tryParse(map['start']?.toString() ?? '') ?? 0) * 1000)
                .round(),
      ),
      end: Duration(
        milliseconds:
            ((num.tryParse(map['end']?.toString() ?? '') ?? 0) * 1000).round(),
      ),
      text: (map['text'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start.inMilliseconds / 1000,
      'end': end.inMilliseconds / 1000,
      'text': text,
    };
  }
}

class MusicSubtitleRange {
  final double start;
  final double end;

  const MusicSubtitleRange({
    required this.start,
    required this.end,
  });

  factory MusicSubtitleRange.fromMap(Map<String, dynamic> map) {
    return MusicSubtitleRange(
      start: num.tryParse(map['start']?.toString() ?? '')?.toDouble() ?? 0,
      end: num.tryParse(map['end']?.toString() ?? '')?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
    };
  }
}

class MusicSubtitles {
  final String status;
  final String text;
  final String language;
  final String error;
  final bool chunked;
  final List<MusicSubtitleRange> generatedRanges;
  final MusicSubtitleRange? processingRange;
  final List<MusicSubtitleSegment> segments;

  const MusicSubtitles({
    required this.status,
    required this.text,
    required this.language,
    required this.error,
    required this.chunked,
    required this.generatedRanges,
    required this.processingRange,
    required this.segments,
  });

  factory MusicSubtitles.empty() {
    return const MusicSubtitles(
      status: 'not_requested',
      text: '',
      language: '',
      error: '',
      chunked: false,
      generatedRanges: [],
      processingRange: null,
      segments: [],
    );
  }

  factory MusicSubtitles.fromMap(dynamic raw) {
    if (raw is! Map) return MusicSubtitles.empty();
    final segmentsRaw = raw['segments'];
    final segments = segmentsRaw is List
        ? segmentsRaw
            .whereType<Map>()
            .map((e) => MusicSubtitleSegment.fromMap(
                  Map<String, dynamic>.from(
                    e.map((k, v) => MapEntry(k.toString(), v)),
                  ),
                ))
            .where((e) => e.text.isNotEmpty)
            .toList()
        : <MusicSubtitleSegment>[];
    final rangesRaw = raw['generatedRanges'];
    final ranges = rangesRaw is List
        ? rangesRaw
            .whereType<Map>()
            .map((e) => MusicSubtitleRange.fromMap(
                  Map<String, dynamic>.from(
                    e.map((k, v) => MapEntry(k.toString(), v)),
                  ),
                ))
            .where((e) => e.end > e.start)
            .toList()
        : <MusicSubtitleRange>[];
    final processingRaw = raw['processingRange'];
    final processingRange = processingRaw is Map
        ? MusicSubtitleRange.fromMap(
            Map<String, dynamic>.from(
              processingRaw.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
        : null;

    return MusicSubtitles(
      status: (raw['status'] ?? 'not_requested').toString(),
      text: (raw['text'] ?? '').toString().trim(),
      language: (raw['language'] ?? '').toString(),
      error: (raw['error'] ?? '').toString(),
      chunked: raw['chunked'] == true,
      generatedRanges: ranges,
      processingRange: processingRange != null &&
              processingRange.end > processingRange.start
          ? processingRange
          : null,
      segments: segments,
    );
  }

  bool get isReady =>
      status == 'ready' &&
      (segments.isNotEmpty || text.isNotEmpty || generatedRanges.isNotEmpty);
  bool get isProcessing => status == 'processing';
  bool get isFailed => status == 'failed';

  String get displayError {
    final raw = error.trim();
    if (raw.isEmpty) return '';

    final normalized = raw.toLowerCase();
    final looksLikeLanguageDetectionFailure =
        normalized.contains('could not detect') ||
            normalized.contains('failed to detect') ||
            normalized.contains('language undetectable') ||
            normalized.contains('undetectable language') ||
            normalized.contains('no speech') ||
            normalized.contains('invalid file format') ||
            normalized.contains('supported formats');

    if (looksLikeLanguageDetectionFailure) return 'Language undetectable';

    final looksLikeProviderOrConfigFailure =
        normalized.contains('api key') ||
            normalized.contains('invalid_api_key') ||
            normalized.contains('incorrect api key') ||
            normalized.contains('openai') ||
            normalized.contains('unauthorized') ||
            normalized.contains('authentication') ||
            normalized.contains('authorization') ||
            normalized.contains('not configured') ||
            normalized.contains('401');

    if (looksLikeProviderOrConfigFailure) {
      return 'Lyrics/subtitles unavailable right now';
    }

    return raw;
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'text': text,
      'language': language,
      'error': error,
      'chunked': chunked,
      'generatedRanges': generatedRanges.map((e) => e.toMap()).toList(),
      if (processingRange != null) 'processingRange': processingRange!.toMap(),
      'segments': segments.map((e) => e.toMap()).toList(),
    };
  }

  bool hasRangeAt(Duration position) {
    if (!chunked) return isReady;
    final seconds = position.inMilliseconds / 1000;
    return generatedRanges.any((range) {
      return seconds >= range.start && seconds < range.end;
    });
  }

  bool isProcessingAt(Duration position) {
    if (!chunked || processingRange == null) return false;
    final seconds = position.inMilliseconds / 1000;
    return seconds >= processingRange!.start && seconds < processingRange!.end;
  }

  Duration? missingPrefetchPosition(
    Duration position, {
    Duration lookAhead = const Duration(minutes: 4),
  }) {
    if (!chunked || !isReady) return position;
    if (!hasRangeAt(position)) return position;
    final target = position + lookAhead;
    return hasRangeAt(target) ? null : target;
  }

  MusicSubtitleSegment? segmentAt(Duration position) {
    if (segments.isEmpty) return null;
    for (final segment in segments) {
      if (position >= segment.start && position <= segment.end) {
        return segment;
      }
    }
    return null;
  }
}
