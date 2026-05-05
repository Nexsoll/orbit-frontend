import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';
import 'package:super_up_core/super_up_core.dart';

// ─── Highlighting controller ──────────────────────────────────────────────────
// Overrides buildTextSpan so that @mention and #hashtag tokens are colourised
// inside a single EditableText/CupertinoTextField — no Stack+IgnorePointer
// hack needed, which means the cursor is always at the correct visual position.
class _HighlightingController extends TextEditingController {
  Color textColor;
  Color mentionColor;
  Color hashtagColor;

  _HighlightingController({
    required this.textColor,
    required this.mentionColor,
    required this.hashtagColor,
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;

    // Honour active IME composing region (shows underline while composing)
    if (value.composing.isValid &&
        withComposing &&
        !value.composing.isCollapsed) {
      final composingStyle = (style ?? const TextStyle())
          .merge(const TextStyle(decoration: TextDecoration.underline));
      return TextSpan(style: style, children: [
        _colorize(text.substring(0, value.composing.start), style),
        TextSpan(
          text:
              text.substring(value.composing.start, value.composing.end),
          style: composingStyle,
        ),
        _colorize(text.substring(value.composing.end), style),
      ]);
    }

    return _colorize(text, style);
  }

  TextSpan _colorize(String segment, TextStyle? base) {
    if (segment.isEmpty) return TextSpan(text: '', style: base);

    final pattern = RegExp(r'@\w+|#\w+');
    final matches = pattern.allMatches(segment).toList();

    if (matches.isEmpty) return TextSpan(text: segment, style: base);

    final spans = <TextSpan>[];
    int i = 0;
    for (final m in matches) {
      if (m.start > i) {
        spans.add(TextSpan(text: segment.substring(i, m.start), style: base));
      }
      final token = m.group(0)!;
      spans.add(TextSpan(
        text: token,
        style: (base ?? const TextStyle()).copyWith(
          color: token.startsWith('@') ? mentionColor : hashtagColor,
        ),
      ));
      i = m.end;
    }
    if (i < segment.length) {
      spans.add(TextSpan(text: segment.substring(i), style: base));
    }
    return TextSpan(style: base, children: spans);
  }
}

// ─── Widget ───────────────────────────────────────────────────────────────────

class PostCaptionEditor extends StatefulWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final BoxDecoration? decoration;
  final int? maxLines;
  final int? maxLength;
  final FocusNode? focusNode;
  final Color? textColor;
  final Color? placeholderColor;
  final Color? highlightColor;

  const PostCaptionEditor({
    super.key,
    this.controller,
    this.placeholder =
        'Write a caption... Use @ for mentions and # for hashtags',
    this.decoration,
    this.maxLines,
    this.maxLength = 500,
    this.focusNode,
    this.textColor,
    this.placeholderColor,
    this.highlightColor,
  });

  @override
  State<PostCaptionEditor> createState() => _PostCaptionEditorState();
}

class _PostCaptionEditorState extends State<PostCaptionEditor> {
  late final _HighlightingController _controller;
  late final FocusNode _focusNode;
  OverlayEntry? _overlayEntry;
  ProfileApiService? _profileApiService;
  List<String> _allUserHandles = [];
  Map<String, String> _userDisplayByHandle = {};
  Map<String, String> _userImageByHandle = {};
  List<String> _mentionSuggestions = [];
  List<String> _hashtagSuggestions = [];
  String _currentQuery = '';
  bool _isMention = false;
  Timer? _mentionDebounce;
  int _mentionRequestId = 0;

  final List<String> _mockUsers = [
    'ahmed_hassan',
    'sara_ali',
    'mohamed_omar',
    'fatima_khan',
    'john_doe',
    'jane_smith',
    'alex_wilson',
    'maria_garcia',
    'david_brown',
    'emma_jones',
  ];

  final List<String> _mockHashtags = [
    'trending',
    'viral',
    'photography',
    'travel',
    'foodie',
    'fitness',
    'music',
    'art',
    'nature',
    'love',
  ];

  @override
  void initState() {
    super.initState();
    _controller = _HighlightingController(
      textColor: widget.textColor ?? Colors.black,
      mentionColor: widget.highlightColor ?? const Color(0xFFB48648),
      hashtagColor: const Color(0xFF5DADE2),
    );
    // Seed from the external controller if provided
    if (widget.controller != null && widget.controller!.text.isNotEmpty) {
      _controller.text = widget.controller!.text;
    }
    _focusNode = widget.focusNode ?? FocusNode();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _removeOverlay();
      }
    });
    _loadUsers();
  }

  @override
  void didUpdateWidget(PostCaptionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.textColor = widget.textColor ?? Colors.black;
    _controller.mentionColor =
        widget.highlightColor ?? const Color(0xFFB48648);
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    _controller.dispose(); // always dispose internal controller
    if (widget.focusNode == null) _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    // Keep the external TextEditingController in sync (callers read .text)
    if (widget.controller != null &&
        widget.controller!.text != _controller.text) {
      widget.controller!.value = TextEditingValue(text: _controller.text);
    }
    if (mounted) setState(() {});
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.baseOffset < 0 || selection.baseOffset > text.length) {
      _removeOverlay();
      return;
    }

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final words = textBeforeCursor.split(' ');
    final currentWord = words.isNotEmpty ? words.last : '';

    final mentionMatch = RegExp(r'@(\w*)$').firstMatch(currentWord);
    final hashtagMatch = RegExp(r'#(\w*)$').firstMatch(currentWord);

    if (mentionMatch != null) {
      _isMention = true;
      _currentQuery = mentionMatch.group(1) ?? '';
      _mentionSuggestions = _filterMentionSuggestions(_currentQuery);
      _showOverlay();
      unawaited(_searchMentionSuggestions(_currentQuery));
    } else if (hashtagMatch != null) {
      _isMention = false;
      _currentQuery = hashtagMatch.group(1) ?? '';
      _hashtagSuggestions = _mockHashtags
          .where(
              (tag) => tag.toLowerCase().contains(_currentQuery.toLowerCase()))
          .toList();
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  List<String> _filterMentionSuggestions(String query) {
    final source = _allUserHandles.isNotEmpty ? _allUserHandles : _mockUsers;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<String>.from(source);

    return source.where((handle) {
      final display = (_userDisplayByHandle[handle] ?? '').toLowerCase();
      return handle.toLowerCase().contains(q) || display.contains(q);
    }).toList();
  }

  Future<void> _searchMentionSuggestions(String query) async {
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 250), () async {
      final requestId = ++_mentionRequestId;

      try {
        if (!GetIt.I.isRegistered<ProfileApiService>()) return;
        _profileApiService ??= GetIt.I.get<ProfileApiService>();

        const pageSize = 80;
        final mergedHandles = List<String>.from(_allUserHandles);
        final mergedNames = Map<String, String>.from(_userDisplayByHandle);
        final mergedAvatars = Map<String, String>.from(_userImageByHandle);
        final seenHandles = Set<String>.from(mergedHandles);

        final searchQuery = query.trim();
        final maxPages = searchQuery.isEmpty ? 2 : 20;
        var page = 1;
        var hasMore = true;

        while (hasMore && page <= maxPages) {
          final dto = UserFilterDto.init().copyWith(
            page: page,
            limit: pageSize,
            fullName: searchQuery.isEmpty ? null : searchQuery,
          );
          final users = await _profileApiService!.appUsers(dto);

          for (final user in users) {
            final fullName = user.baseUser.fullName.trim();
            if (fullName.isEmpty) continue;
            final handle = _normalizeMentionHandle(fullName);
            if (handle.isEmpty) continue;

            if (!seenHandles.contains(handle)) {
              seenHandles.add(handle);
              mergedHandles.add(handle);
            }
            mergedNames[handle] = fullName;
            mergedAvatars[handle] = user.baseUser.userImage.isNotEmpty
                ? user.baseUser.userImageS3
                : '';
          }

          hasMore = users.length >= pageSize;
          page++;
        }

        if (!mounted || requestId != _mentionRequestId) return;

        setState(() {
          _allUserHandles = mergedHandles;
          _userDisplayByHandle = mergedNames;
          _userImageByHandle = mergedAvatars;
          _mentionSuggestions = _filterMentionSuggestions(query);
        });

        if (_isMention) {
          _showOverlay();
        }
      } catch (_) {
        if (!mounted || requestId != _mentionRequestId) return;
        setState(() {
          _mentionSuggestions = _filterMentionSuggestions(query);
        });
        if (_isMention) {
          _showOverlay();
        }
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();

    final suggestions = _isMention ? _mentionSuggestions : _hashtagSuggestions;
    if (suggestions.isEmpty) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    final newEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 8,
        width: size.width,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF333333)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: Color(0xFF333333),
              ),
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                final displayName = _userDisplayByHandle[suggestion] ?? suggestion;
                final avatarUrl = _userImageByHandle[suggestion] ?? '';
                return ListTile(
                  dense: true,
                  leading: _isMention
                      ? CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              const Color(0xFFB48648).withValues(alpha: 0.2),
                          backgroundImage:
                              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFFB48648),
                                  size: 16,
                                )
                              : null,
                        )
                      : const Icon(
                          Icons.tag,
                          color: Color(0xFFB48648),
                          size: 20,
                        ),
                  title: Text(
                    _isMention ? displayName : suggestion,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: _isMention
                      ? Text(
                          '@$suggestion',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        )
                      : null,
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
        ),
      ),
    );

    _overlayEntry = newEntry;
    overlay.insert(newEntry);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(String suggestion) {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursor = selection.baseOffset.clamp(0, text.length);
    final textBeforeCursor = text.substring(0, cursor);
    final textAfterCursor = text.substring(cursor);

    final pattern = _isMention ? r'@\w*$' : r'#\w*$';
    final regex = RegExp(pattern);
    final match = regex.firstMatch(textBeforeCursor);
    if (match == null) {
      _removeOverlay();
      return;
    }

    final replaceStart = match.start;
    final prefix = _isMention ? '@' : '#';
    final insertedToken = '$prefix$suggestion ';
    final newText =
        '${textBeforeCursor.substring(0, replaceStart)}$insertedToken$textAfterCursor';
    final newCursorOffset = newText.length;

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: newCursorOffset,
      ),
      composing: TextRange.empty,
    );

    _focusNode.requestFocus();
    _removeOverlay();
    if (mounted) setState(() {});
  }

  Future<void> _loadUsers() async {
    try {
      if (!GetIt.I.isRegistered<ProfileApiService>()) return;
      _profileApiService = GetIt.I.get<ProfileApiService>();
      final dto = UserFilterDto.init().copyWith(page: 1, limit: 80);
      final users = await _profileApiService!.appUsers(dto);
      final handles = <String>[];
      final names = <String, String>{};
      final avatars = <String, String>{};
      for (final user in users) {
        final fullName = user.baseUser.fullName.trim();
        if (fullName.isEmpty) continue;
        final handle = _normalizeMentionHandle(fullName);
        if (handle.isEmpty || names.containsKey(handle)) continue;
        handles.add(handle);
        names[handle] = fullName;
        avatars[handle] = user.baseUser.userImage.isNotEmpty
            ? user.baseUser.userImageS3
            : '';
      }
      if (!mounted) return;
      setState(() {
        _allUserHandles = handles;
        _userDisplayByHandle = names;
        _userImageByHandle = avatars;
      });
    } catch (_) {
      // Keep fallback mock users when API lookup is unavailable.
    }
  }

  String _normalizeMentionHandle(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.textColor ?? Colors.black;
    final placeholderColor = widget.placeholderColor ?? Colors.black54;
    return Container(
      decoration: widget.decoration ??
          BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF333333)),
          ),
      padding: const EdgeInsets.all(12),
      child: CupertinoTextField(
        controller: _controller,
        focusNode: _focusNode,
        placeholder: widget.placeholder ?? '',
        maxLines: widget.maxLines ?? 4,
        minLines: 1,
        maxLength: widget.maxLength,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          height: 1.4,
        ),
        placeholderStyle: TextStyle(
          color: placeholderColor,
          fontSize: 15,
          height: 1.4,
        ),
        cursorColor: const Color(0xFFB48648),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          border: Border(),
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
