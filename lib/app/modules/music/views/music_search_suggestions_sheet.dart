import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';

import '../services/music_api_service.dart';

typedef MusicSearchSelectionHandler = Future<void> Function(
  BuildContext context,
  Map<String, dynamic> item,
  List<Map<String, dynamic>> sourceItems,
);

Future<void> showMusicSearchSuggestionsSheet({
  required BuildContext context,
  required MusicApiService api,
  required MusicSearchSelectionHandler onSelected,
  String? currentMusicId,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) {
      return _MusicSearchSuggestionsSheet(
        playerContext: context,
        api: api,
        currentMusicId: currentMusicId,
        onSelected: onSelected,
      );
    },
  );
}

class _MusicSearchSuggestionsSheet extends StatefulWidget {
  final BuildContext playerContext;
  final MusicApiService api;
  final String? currentMusicId;
  final MusicSearchSelectionHandler onSelected;

  const _MusicSearchSuggestionsSheet({
    required this.playerContext,
    required this.api,
    required this.onSelected,
    this.currentMusicId,
  });

  @override
  State<_MusicSearchSuggestionsSheet> createState() =>
      _MusicSearchSuggestionsSheetState();
}

class _MusicSearchSuggestionsSheetState
    extends State<_MusicSearchSuggestionsSheet> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  bool _selecting = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _idOf(Map<String, dynamic> item) {
    return (item['_id'] ?? item['id'] ?? '').toString();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    _debounce?.cancel();

    if (query.isEmpty) {
      _requestId++;
      setState(() {
        _results = [];
        _loading = false;
        _hasSearched = false;
        _error = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_fetchSuggestions(query));
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      final result = await widget.api.listMusic(
        query: query,
        page: 1,
        limit: 12,
      );
      if (!mounted || requestId != _requestId) return;

      final currentId = (widget.currentMusicId ?? '').trim();
      final docs = ((result['docs'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .where((item) => currentId.isEmpty || _idOf(item) != currentId)
          .map((item) {
        item['likesCount'] = _asInt(item['likesCount'] ?? 0);
        item['commentsCount'] = _asInt(item['commentsCount'] ?? 0);
        item['playsCount'] = _asInt(item['playsCount'] ?? 0);
        item['isLiked'] = item['isLiked'] == true;
        return item;
      }).toList();

      setState(() {
        _results = docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _select(Map<String, dynamic> item) async {
    if (_selecting) return;
    setState(() => _selecting = true);

    final sourceItems = List<Map<String, dynamic>>.from(_results);
    Navigator.of(context).pop();
    await widget.onSelected(widget.playerContext, item, sourceItems);
  }

  bool _isVideo(Map<String, dynamic> item) {
    final mediaType = (item['mediaType'] ?? '').toString().toLowerCase();
    if (mediaType == 'video') return true;
    final mime = (item['mimeType'] ?? '').toString().toLowerCase();
    return mime.startsWith('video/');
  }

  String _mediaLabel(Map<String, dynamic> item) {
    return _isVideo(item) ? 'Video' : 'Audio';
  }

  String _absoluteUrl(String raw) {
    if (raw.startsWith('http')) return raw;
    return SConstants.baseMediaUrl + raw;
  }

  Widget _buildThumbnail(Map<String, dynamic> item) {
    final thumbnail = (item['thumbnailUrl'] ?? '').toString().trim();
    if (_isVideo(item) && thumbnail.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          _absoluteUrl(thumbnail),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildIconThumb(item),
        ),
      );
    }
    return _buildIconThumb(item);
  }

  Widget _buildIconThumb(Map<String, dynamic> item) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFB48648).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        _isVideo(item)
            ? CupertinoIcons.play_rectangle_fill
            : CupertinoIcons.music_note_2,
        color: const Color(0xFFB48648),
        size: 24,
      ),
    );
  }

  Widget _buildResults() {
    if (!_hasSearched) {
      return _buildEmptyState(
        icon: CupertinoIcons.search,
        title: 'Search audio or video',
      );
    }

    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_error != null) {
      return _buildEmptyState(
        icon: CupertinoIcons.exclamationmark_circle,
        title: 'Search failed',
      );
    }

    if (_results.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.music_note_list,
        title: 'No results found',
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 80,
        color: CupertinoColors.separator,
      ),
      itemBuilder: (context, index) {
        final item = _results[index];
        final title = (item['title'] ?? 'Untitled').toString();
        final uploader =
            (item['uploaderData']?['fullName'] ?? 'Unknown artist').toString();
        final plays = _asInt(item['playsCount']);
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _selecting ? null : () => _select(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildThumbnail(item),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CupertinoColors.label,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        uploader,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_mediaLabel(item)} - $plays plays',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.play_fill,
                  color: Color(0xFFB48648),
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CupertinoColors.systemGrey, size: 34),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height * 0.82,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoSearchTextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        placeholder: 'Search audio or video',
                        onChanged: _onSearchChanged,
                        onSubmitted: (value) {
                          final query = value.trim();
                          if (query.isNotEmpty) {
                            _debounce?.cancel();
                            unawaited(_fetchSuggestions(query));
                          }
                        },
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        color: CupertinoColors.secondaryLabel,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }
}
