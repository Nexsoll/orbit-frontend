import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import '../../music/services/music_api_service.dart';
import 'story_music_trimmer_sheet.dart';

typedef StoryMusicSelectionCallback = void Function(Map<String, dynamic> musicMetadata);

class StoryMusicSelectionSheet extends StatefulWidget {
  final StoryMusicSelectionCallback onSelected;

  const StoryMusicSelectionSheet({
    super.key,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required StoryMusicSelectionCallback onSelected,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        return StoryMusicSelectionSheet(onSelected: onSelected);
      },
    );
  }

  @override
  State<StoryMusicSelectionSheet> createState() => _StoryMusicSelectionSheetState();
}

class _StoryMusicSelectionSheetState extends State<StoryMusicSelectionSheet> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _api = MusicApiService.init();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    // Fetch initial list of music when opened
    unawaited(_fetchSuggestions(''));
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
      // Force fetching audio-only tracks for story background music
      final result = await _api.listMusic(
        query: query.isEmpty ? null : query,
        mediaType: 'audio',
        page: 1,
        limit: 20,
      );
      if (!mounted || requestId != _requestId) return;

      final docs = ((result['docs'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
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

  void _select(Map<String, dynamic> item) {
    // Dismiss selection sheet and push trimmer sheet
    Navigator.of(context).pop();
    
    showCupertinoModalPopup<void>(
      context: context,
      builder: (trimmerContext) {
        return StoryMusicTrimmerSheet(
          musicItem: item,
          onTrimmed: widget.onSelected,
        );
      },
    );
  }

  String _absoluteUrl(String raw) {
    if (raw.startsWith('http')) return raw;
    return SConstants.baseMediaUrl + raw;
  }

  Widget _buildThumbnail(Map<String, dynamic> item) {
    final thumbnail = (item['thumbnailUrl'] ?? '').toString().trim();
    if (thumbnail.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          _absoluteUrl(thumbnail),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildIconThumb(),
        ),
      );
    }
    return _buildIconThumb();
  }

  Widget _buildIconThumb() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFB48648).withOpacity(0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        CupertinoIcons.music_note_2,
        color: Color(0xFFB48648),
        size: 24,
      ),
    );
  }

  Widget _buildResults() {
    if (_loading && _results.isEmpty) {
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
        title: 'No audio tracks found',
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
        
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _select(item),
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.chevron_right,
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
                        placeholder: 'Search background music',
                        onChanged: _onSearchChanged,
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Available Audios',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.label,
                    ),
                  ),
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
