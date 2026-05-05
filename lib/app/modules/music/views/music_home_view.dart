import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:super_up/app/core/api_service/auth/auth_api_service.dart';
import 'package:super_up/app/core/api_service/story/story_api_service.dart';
import 'package:super_up/app/core/models/story/create_story_dto.dart';
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:super_up/app/core/services/story_status_service.dart';
import 'package:super_up/app/modules/home/mobile/story_tab/controllers/story_tab_controller.dart';
import 'package:super_up/app/modules/home/settings_modules/wallet/views/wallet_page.dart';
import 'package:super_up/app/modules/music/services/articles_api_service.dart';
import 'package:super_up/main.dart' show navigatorKey;

import '../services/music_api_service.dart';
import 'music_audio_player_page.dart';
import 'music_history_page.dart';
import 'music_video_player_page.dart';

class MusicHomeView extends StatefulWidget {
  const MusicHomeView({super.key});

  @override
  State<MusicHomeView> createState() => _MusicHomeViewState();
}

class _MusicHomeViewState extends State<MusicHomeView> {
  // Pagination state per tab
  final Map<String, int> _pages = {
    'all': 1,
    'music': 1,
    'audio': 1,
    'articles': 1
  };
  final Map<String, bool> _hasMore = {
    'all': true,
    'music': true,
    'audio': true,
    'articles': true
  };
  final Map<String, List<Map<String, dynamic>>> _tabItems = {
    'all': [],
    'music': [],
    'audio': [],
    'articles': [],
  };
  static const int _pageSize = 10;
  final _items = <Map<String, dynamic>>[];
  final _fetchedItems = <Map<String, dynamic>>[];
  final _watchHistory = <Map<String, dynamic>>[];
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _loading = false;
  bool _reporting = false;
  String _filter = 'all';
  String _searchQuery = '';
  // Creator filter state
  List<Map<String, dynamic>> _artists = [];
  Map<String, dynamic>? _selectedArtist;
  bool _loadingArtists = false;
  late final MusicApiService _api;
  late final ArticlesApiService _articlesApi;
  late final AuthApiService _authApi;
  static const String _historyStoreKey = 'music/history_seen_v1';

  Future<String?> _askReportReason() async {
    final c = TextEditingController();
    final res = await showCupertinoDialog<String?>(
      context: context,
      builder: (_) {
        return CupertinoAlertDialog(
          title: const Text('Report content'),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: CupertinoTextField(
              controller: c,
              placeholder: 'Reason',
              maxLines: 4,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              isDestructiveAction: true,
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
    return res;
  }

  String _artistImageUrl(Map<String, dynamic> artist) {
    final raw = (artist['userImage'] ?? '').toString().trim();
    if (raw.isEmpty) return raw;

    final updatedAt = artist['userImageUpdatedAt'];
    String? v;
    if (updatedAt is String && updatedAt.isNotEmpty) {
      v = updatedAt;
    } else if (updatedAt is num) {
      v = updatedAt.toString();
    } else if (updatedAt is DateTime) {
      v = updatedAt.millisecondsSinceEpoch.toString();
    }

    if (v == null || v.isEmpty) return raw;
    // Ensure we don't break existing query params
    final sep = raw.contains('?') ? '&' : '?';
    return '$raw${sep}v=$v';
  }

  Future<void> _reportItem(Map<String, dynamic> item) async {
    if (_reporting) return;
    final id = _idOf(item);
    if (id.isEmpty) return;
    final reason = await _askReportReason();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _reporting = true);
    try {
      await _api.reportMusic(id: id, content: reason.trim());
      if (!mounted) return;
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Report submitted successfully',
      );
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  int _normalizeEpochToMs(int v) {
    // 10-digit epoch is usually seconds
    if (v > 0 && v < 10000000000) return v * 1000;
    return v;
  }

  DateTime? _parseCreatedAt(Map<String, dynamic> item) {
    final raw = item['createdAt'] ??
        item['created_at'] ??
        item['createdAtMs'] ??
        item['created_at_ms'];

    if (raw == null) return null;

    if (raw is DateTime) return raw;

    if (raw is String) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) return dt;
      final parsedInt = int.tryParse(raw);
      if (parsedInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          _normalizeEpochToMs(parsedInt),
          isUtc: true,
        );
      }
      return null;
    }

    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        _normalizeEpochToMs(raw.toInt()),
        isUtc: true,
      );
    }

    return null;
  }

  String _formatUploadDate(BuildContext ctx, DateTime dt) {
    final lang = Localizations.localeOf(ctx).languageCode;
    try {
      return DateFormat.yMMMd(lang).format(dt.toLocal());
    } catch (_) {
      return DateFormat.yMMMd('en').format(dt.toLocal());
    }
  }

  void _applyLocalFilterInPlace() {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) {
      _items
        ..clear()
        ..addAll(_tabItems[_filter]!);
      return;
    }
    bool matches(Map<String, dynamic> item) {
      final title = (item['title'] ?? '').toString().toLowerCase();
      final desc = (item['description'] ?? '').toString().toLowerCase();
      final uploader =
          (item['uploaderData']?['fullName'] ?? '').toString().toLowerCase();
      return title.contains(q) || desc.contains(q) || uploader.contains(q);
    }

    _items
      ..clear()
      ..addAll(_tabItems[_filter]!.where(matches));
  }

  void _onSearchChanged(String v) {
    setState(() {
      _searchQuery = v;
      _applyLocalFilterInPlace();
    });

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _fetch(reset: true);
    });
  }

  Map<String, dynamic> _toHistoryItem(Map<String, dynamic> item) {
    return {
      '_id': (item['_id'] ?? item['id'] ?? '').toString(),
      'id': (item['id'] ?? item['_id'] ?? '').toString(),
      'title': (item['title'] ?? 'Untitled').toString(),
      'mediaUrl': (item['mediaUrl'] ?? item['url'] ?? '').toString(),
      'url': (item['url'] ?? item['mediaUrl'] ?? '').toString(),
      'fileUrl': (item['fileUrl'] ?? item['url'] ?? '').toString(),
      'mediaType': (item['mediaType'] ?? '').toString(),
      'mimeType': (item['mimeType'] ?? '').toString(),
      'thumbnailUrl': (item['thumbnailUrl'] ?? item['thumbUrl'] ?? '')
          .toString(),
      'uploaderData': item['uploaderData'] is Map
          ? Map<String, dynamic>.from(item['uploaderData'])
          : null,
      'seenAt': DateTime.now().toIso8601String(),
    };
  }

  void _loadHistory() {
    try {
      final map = VAppPref.getMap(_historyStoreKey);
      final raw = map?['items'];
      if (raw is! List) return;
      _watchHistory
        ..clear()
        ..addAll(raw.whereType<Map>().map((e) =>
            Map<String, dynamic>.from(e.map((k, v) => MapEntry(k.toString(), v)))));
    } catch (_) {
      _watchHistory.clear();
    }
  }

  Future<void> _saveHistory() async {
    try {
      await VAppPref.setMap(_historyStoreKey, {
        'items': _watchHistory,
      });
    } catch (_) {}
  }

  void _rememberSeen(Map<String, dynamic> item) {
    final h = _toHistoryItem(item);
    final id = _idOf(h);
    if (id.isEmpty) return;
    _watchHistory.removeWhere((e) => _idOf(e) == id);
    _watchHistory.insert(0, h);
    if (_watchHistory.length > 200) {
      _watchHistory.removeRange(200, _watchHistory.length);
    }
    unawaited(_saveHistory());
  }

  bool _isPlayableItem(Map<String, dynamic> item) {
    final raw = (item['mediaUrl'] ?? item['url'] ?? '').toString();
    if (raw.isEmpty) return false;

    final mediaType = (item['mediaType'] ?? '').toString().toLowerCase();
    if (mediaType == 'audio' || mediaType == 'video') return true;

    final mime = (item['mimeType'] ?? '').toString().toLowerCase();
    if (mime.startsWith('audio/') || mime.startsWith('video/')) return true;

    final lowerUrl = raw.toLowerCase();
    const audioExts = [
      '.mp3',
      '.m4a',
      '.aac',
      '.wav',
      '.ogg',
      '.flac',
      '.opus'
    ];
    return audioExts.any((e) => lowerUrl.contains(e));
  }

  int _indexOfIn(List<Map<String, dynamic>> source, Map<String, dynamic> item) {
    final id = _idOf(item);
    if (id.isEmpty) return source.indexOf(item);
    return source.indexWhere((e) => _idOf(e) == id);
  }

  int _nextPlayableIndexIn(
    List<Map<String, dynamic>> source, {
    required int fromIndex,
  }) {
    if (source.isEmpty) return -1;
    for (int i = fromIndex + 1; i < source.length; i++) {
      if (_isPlayableItem(source[i])) return i;
    }
    return -1;
  }

  int _previousPlayableIndexIn(
    List<Map<String, dynamic>> source, {
    required int fromIndex,
  }) {
    if (source.isEmpty) return -1;
    for (int i = fromIndex - 1; i >= 0; i--) {
      if (_isPlayableItem(source[i])) return i;
    }
    return -1;
  }

  Future<void> _downloadFromPlayer(BuildContext context, String url) async {
    try {
      await VStringUtils.lunchLink(url);
      if (!mounted) return;
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Download started',
      );
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(
        context: context,
        message: e.toString(),
      );
    }
  }

  Future<void> _clearHistory() async {
    setState(() {
      _watchHistory.clear();
    });
    await _saveHistory();
  }

  Future<void> _openHistory() async {
    final selected = await context.toPage(
      MusicHistoryPage(
        historyItems: _watchHistory,
        onClearHistory: _clearHistory,
      ),
    );

    if (selected == null) return;
    if (!_isPlayableItem(selected)) {
      final raw = (selected['fileUrl'] ?? selected['url'] ?? '').toString();
      if (raw.isEmpty) return;
      final fullUrl =
          raw.startsWith('http') ? raw : SConstants.baseMediaUrl + raw;
      VStringUtils.lunchLink(fullUrl);
      return;
    }
    final idx = _indexOfIn(_watchHistory, selected);
    if (idx == -1) return;
    await _play(selected, index: idx, sourceItems: _watchHistory);
  }

  Future<void> _incrementPlayCount(Map<String, dynamic> item) async {
    final id = (item['_id'] ?? item['id'])?.toString();
    if (id == null || id.isEmpty || _isOwner(item)) return;

    try {
      await _api.incrementPlay(id);
      if (!mounted) return;
      setState(() {
        final index = _items.indexOf(item);
        if (index != -1) {
          final current = (_items[index]['playsCount'] ?? 0) as int;
          _items[index]['playsCount'] = current + 1;
        }
      });
    } catch (_) {}
  }

  Future<void> _playAtIndex({
    required BuildContext navContext,
    required List<Map<String, dynamic>> sourceItems,
    required int index,
    bool replace = false,
  }) async {
    if (index < 0 || index >= sourceItems.length) return;

    final item = sourceItems[index];
    final raw = (item['mediaUrl'] ?? item['url'] ?? '').toString();
    if (raw.isEmpty) return;
    final fullUrl = raw.startsWith('http') ? raw : SConstants.baseMediaUrl + raw;

    final mediaType = (item['mediaType'] ?? '').toString().toLowerCase();
    final mime = (item['mimeType'] ?? '').toString().toLowerCase();
    final lowerUrl = fullUrl.toLowerCase();
    const audioExts = [
      '.mp3',
      '.m4a',
      '.aac',
      '.wav',
      '.ogg',
      '.flac',
      '.opus'
    ];
    final isAudioByExt = audioExts.any((e) => lowerUrl.contains(e));
    final isAudio =
        mediaType == 'audio' || mime.startsWith('audio/') || isAudioByExt;
    final title = (item['title'] ?? 'Untitled').toString();

    _rememberSeen(item);
    unawaited(_incrementPlayCount(item));

    final route = CupertinoPageRoute(
      builder: (_) => isAudio
          ? MusicAudioPlayerPage(
              title: title,
              url: fullUrl,
              autoPlay: true,
              onDownload: (ctx) => _downloadFromPlayer(ctx, fullUrl),
              onPlayPrevious: (ctx) async {
                final prev =
                    _previousPlayableIndexIn(sourceItems, fromIndex: index);
                if (prev == -1) return;
                await _playAtIndex(
                  navContext: ctx,
                  sourceItems: sourceItems,
                  index: prev,
                  replace: true,
                );
              },
              onPlayNext: (ctx) async {
                final next = _nextPlayableIndexIn(sourceItems, fromIndex: index);
                if (next == -1) return;
                await _playAtIndex(
                  navContext: ctx,
                  sourceItems: sourceItems,
                  index: next,
                  replace: true,
                );
              },
            )
          : MusicVideoPlayerPage(
              title: title,
              url: fullUrl,
              autoPlay: true,
              onDownload: (ctx) => _downloadFromPlayer(ctx, fullUrl),
              onPlayPrevious: (ctx) async {
                final prev =
                    _previousPlayableIndexIn(sourceItems, fromIndex: index);
                if (prev == -1) return;
                await _playAtIndex(
                  navContext: ctx,
                  sourceItems: sourceItems,
                  index: prev,
                  replace: true,
                );
              },
              onPlayNext: (ctx) async {
                final next = _nextPlayableIndexIn(sourceItems, fromIndex: index);
                if (next == -1) return;
                await _playAtIndex(
                  navContext: ctx,
                  sourceItems: sourceItems,
                  index: next,
                  replace: true,
                );
              },
            ),
    );

    if (replace) {
      await Navigator.of(navContext).pushReplacement(route);
    } else {
      await Navigator.of(navContext).push(route);
    }
  }

  bool get _isArticlesMode => _filter == 'articles';

  String _idOf(Map<String, dynamic> item) {
    return (item['_id'] ?? item['id'] ?? '').toString();
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  bool _isOwner(Map<String, dynamic> item) {
    try {
      final uploaderId =
          (item['uploaderData']?['_id'] ?? item['uploaderId'] ?? '').toString();
      if (uploaderId.isEmpty) return false;
      return uploaderId == AppAuth.myId;
    } catch (_) {
      return false;
    }
  }

  Future<void> _shareLink(Map<String, dynamic> item) async {
    try {
      final id = _idOf(item);
      if (id.isEmpty) return;
      final rawTitle = (item['title'] ?? 'Shared content').toString();

      final title = rawTitle.replaceAll('.', '.\u200B');

      final uploaderName =
          (item['uploaderData']?['fullName'] ?? item['uploaderName'] ?? '')
              .toString();

      // Use new server-side rendered share page for proper WhatsApp/Telegram previews
      final link = 'https://api.orbit.ke/api/v1/public/music/share/$id';

      await Share.share(
        uploaderName.isEmpty ? link : '$title\nby $uploaderName\n$link',
        subject: title,
      );
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future<void> _shareToChat(Map<String, dynamic> item) async {
    try {
      final roomsIds =
          await VChatController.I.vNavigator.roomNavigator.toForwardPage(
        context,
        null,
      );

      if (roomsIds == null || roomsIds.isEmpty) return;

      final id = _idOf(item);
      final title = (item['title'] ?? 'Shared content').toString();
      final rawUrl =
          (item['mediaUrl'] ?? item['url'] ?? item['fileUrl'] ?? '').toString();
      if (rawUrl.isEmpty) return;

      final mediaType = (item['mediaType'] ?? '').toString();
      final mimeType = (item['mimeType'] ?? '').toString();
      final thumb = (item['thumbnailUrl'] ??
              item['thumbUrl'] ??
              item['thumb'] ??
              item['thumbImage']?['url'] ??
              '')
          .toString();

      final uploaderName =
          (item['uploaderData']?['fullName'] ?? item['uploaderName'] ?? '')
              .toString();
      final uploaderImage =
          (item['uploaderData']?['userImage'] ?? item['uploaderImage'] ?? '')
              .toString();
      final uploaderId =
          (item['uploaderData']?['_id'] ?? item['uploaderId'] ?? '').toString();

      final payload = <String, dynamic>{
        'type': 'music_share',
        'musicId': id,
        'title': title,
        'url': rawUrl,
        'mediaUrl': rawUrl,
        'fileUrl': rawUrl,
        'mediaType': mediaType,
        'mimeType': mimeType,
        'thumbnailUrl': thumb,
        'uploaderName': uploaderName,
        'uploaderImage': uploaderImage,
        'uploaderId': uploaderId,
      };

      final previewText = 'Shared: $title';

      VAppAlert.showLoading(context: context);
      try {
        for (final roomId in roomsIds) {
          final message = VCustomMessage.buildMessage(
            roomId: roomId,
            content: previewText,
            data: VCustomMsgData(data: payload),
          );
          await VChatController.I.nativeApi.local.message
              .insertMessage(message);
          try {
            VMessageUploaderQueue.instance.addToQueue(
              await MessageFactory.createUploadMessage(message),
            );
          } catch (_) {
            // message remains local only
          }
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Shared to chat',
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  bool _isAdmin() {
    try {
      return AppAuth.myProfile.roles.contains(UserRoles.admin);
    } catch (_) {
      return false;
    }
  }

  StoryTabController _ensureStoryTabController() {
    bool newlyRegistered = false;
    if (!GetIt.I.isRegistered<StoryTabController>()) {
      GetIt.I.registerLazySingleton<StoryTabController>(
          () => StoryTabController());
      newlyRegistered = true;
    }

    final ctrl = GetIt.I.get<StoryTabController>();
    if (newlyRegistered) {
      // Ensure controller timers/streams are started so UI picks updates without restart
      ctrl.onInit();
    }
    return ctrl;
  }

  Future<void> _toggleLike(Map<String, dynamic> item) async {
    final id = _idOf(item);
    if (id.isEmpty) return;
    try {
      final res = _isArticlesMode
          ? await _articlesApi.toggleLike(id)
          : await _api.toggleLike(id);
      if (!mounted) return;
      setState(() {
        final idx = _items.indexOf(item);
        if (idx != -1) {
          _items[idx]['isLiked'] = res['liked'] == true;
          _items[idx]['likesCount'] =
              _asInt(res['likesCount'] ?? _items[idx]['likesCount'] ?? 0);
        }
      });
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future<void> _openUploaderChat(Map<String, dynamic> item) async {
    try {
      final uploaderId =
          (item['uploaderData']?['_id'] ?? item['uploaderId'] ?? '').toString();
      if (uploaderId.isEmpty) return;
      if (uploaderId == AppAuth.myId) return;
      await VChatController.I.roomApi.openChatWith(peerId: uploaderId);
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final id = _idOf(item);
    if (id.isEmpty) return;
    final allowed = _isOwner(item) || _isAdmin();
    if (!allowed) return;

    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: 'Delete',
      content: 'Delete this upload?',
    );
    if (res != 1) return;

    VAppAlert.showLoading(context: context);
    try {
      if (_isArticlesMode) {
        await _articlesApi.deleteArticle(id);
      } else {
        await _api.deleteMusic(id);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _items.remove(item);
      });
      VAppAlert.showSuccessSnackBar(context: context, message: 'Deleted');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  Future<void> _openComments(Map<String, dynamic> item) async {
    final targetId = _idOf(item);
    if (targetId.isEmpty) return;

    final inputCtrl = TextEditingController();
    final scrollCtrl = ScrollController();
    final comments = <Map<String, dynamic>>[];
    bool isLoading = true;
    bool didLoad = false;
    String? replyingToCommentId;
    String? replyingToUserName;

    Future<void> load() async {
      isLoading = true;
      final Map<String, dynamic> result = _isArticlesMode
          ? await _articlesApi.listComments(targetId)
          : await _api.listComments(targetId);
      final docs =
          (result['docs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      comments
        ..clear()
        ..addAll(docs);
      isLoading = false;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (!didLoad) {
              didLoad = true;
              Future.microtask(() async {
                try {
                  await load();
                } catch (_) {
                  isLoading = false;
                }
                if (Navigator.of(context).canPop()) {
                  setModalState(() {});
                }
              });
            }

            Future<void> add({String? parentCommentId}) async {
              final text = inputCtrl.text.trim();
              if (text.isEmpty) return;
              inputCtrl.clear();
              setModalState(() {});
              try {
                final res = _isArticlesMode
                    ? await _articlesApi.addComment(
                        articleId: targetId,
                        text: text,
                        parentCommentId: parentCommentId)
                    : await _api.addComment(
                        musicId: targetId,
                        text: text,
                        parentCommentId: parentCommentId);
                final c = res['comment'];
                final count = res['commentsCount'];
                if (c is Map) {
                  final newComment = Map<String, dynamic>.from(c);
                  if (parentCommentId == null) {
                    // Top-level comment
                    comments.insert(0, newComment);
                  } else {
                    // Reply - add to parent's replies
                    final parentIndex = comments.indexWhere((comment) =>
                        (comment['_id'] ?? comment['id'])?.toString() ==
                        parentCommentId);
                    if (parentIndex != -1) {
                      final replies =
                          (comments[parentIndex]['replies'] as List?)
                                  ?.cast<Map<String, dynamic>>() ??
                              [];
                      replies.add(newComment);
                      comments[parentIndex]['replies'] = replies;
                      comments[parentIndex]['repliesCount'] = replies.length;
                    }
                  }
                }
                final newCount = _asInt(count);
                final idx = _items.indexOf(item);
                if (idx != -1) {
                  setState(() {
                    _items[idx]['commentsCount'] = newCount;
                  });
                }
                setModalState(() {});
                // Clear reply state
                replyingToCommentId = null;
                replyingToUserName = null;
                setModalState(() {});
                try {
                  await Future.delayed(const Duration(milliseconds: 50));
                  if (scrollCtrl.hasClients) {
                    scrollCtrl.animateTo(
                      0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                } catch (_) {}
              } catch (e) {
                VAppAlert.showErrorSnackBar(
                    context: context, message: e.toString());
              }
            }

            Future<void> del(Map<String, dynamic> c) async {
              final commentId = (c['_id'] ?? c['id'] ?? '').toString();
              if (commentId.isEmpty) return;
              final userId =
                  (c['userData']?['_id'] ?? c['userId'] ?? '').toString();
              final canDelete = userId == AppAuth.myId || _isAdmin();
              if (!canDelete) return;
              try {
                final res = _isArticlesMode
                    ? await _articlesApi.deleteComment(
                        articleId: targetId, commentId: commentId)
                    : await _api.deleteComment(
                        musicId: targetId, commentId: commentId);
                final count = res['commentsCount'];
                comments.remove(c);
                final newCount = _asInt(count);
                final idx = _items.indexOf(item);
                if (idx != -1) {
                  setState(() {
                    _items[idx]['commentsCount'] = newCount;
                  });
                }
                setModalState(() {});
              } catch (e) {
                VAppAlert.showErrorSnackBar(
                    context: context, message: e.toString());
              }
            }

            void startReply(Map<String, dynamic> c) {
              replyingToCommentId = (c['_id'] ?? c['id'] ?? '').toString();
              replyingToUserName =
                  (c['userData']?['fullName'] ?? 'User').toString();
              setModalState(() {});
              // Focus the input field
              Future.delayed(const Duration(milliseconds: 100), () {
                // Could add focus node here if needed
              });
            }

            void cancelReply() {
              replyingToCommentId = null;
              replyingToUserName = null;
              setModalState(() {});
            }

            // Check if current user is the content uploader
            final currentUserId = AppAuth.myId;
            final uploaderId =
                (item['uploaderData']?['_id'] ?? item['uploaderId'] ?? '')
                    .toString();
            final isContentOwner = currentUserId == uploaderId || _isAdmin();

            Widget buildCommentItem(Map<String, dynamic> c,
                {bool isReply = false}) {
              final userName = (c['userData']?['fullName'] ?? '').toString();
              final userImg = (c['userData']?['userImage'] ?? '').toString();
              final text = (c['text'] ?? '').toString();
              final userId =
                  (c['userData']?['_id'] ?? c['userId'] ?? '').toString();
              final canDelete = userId == AppAuth.myId || _isAdmin();
              final replies =
                  (c['replies'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              final repliesCount = (c['repliesCount'] ?? replies.length) as int;

              return Container(
                padding: const EdgeInsets.all(10),
                margin:
                    isReply ? const EdgeInsets.only(left: 40, top: 8) : null,
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VCircleAvatar(
                          radius: isReply ? 12 : 16,
                          vFileSource:
                              VPlatformFile.fromUrl(networkUrl: userImg),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      userName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: isReply ? 13 : 14,
                                      ),
                                    ),
                                  ),
                                  if (canDelete)
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      minSize: 22,
                                      onPressed: () => del(c),
                                      child: const Icon(
                                        CupertinoIcons.delete,
                                        size: 18,
                                        color: CupertinoColors.systemRed,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                text,
                                style: TextStyle(
                                  fontSize: isReply ? 13 : 14,
                                ),
                              ),
                              // Reply button - only show for content owner and not on replies
                              if (!isReply && isContentOwner)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: GestureDetector(
                                    onTap: () => startReply(c),
                                    child: Text(
                                      repliesCount > 0
                                          ? 'Reply ($repliesCount)'
                                          : 'Reply',
                                      style: const TextStyle(
                                        color: Color(0xFFB48648),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Show nested replies
                    if (replies.isNotEmpty)
                      ...replies
                          .map(
                              (reply) => buildCommentItem(reply, isReply: true))
                          .toList(),
                  ],
                ),
              );
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(ctx).pop();
              },
              child: Material(
                color: Colors.black.withOpacity(0.25),
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.72,
                        decoration: const BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Comments',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  minSize: 28,
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Icon(CupertinoIcons.xmark,
                                      size: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: isLoading
                                  ? const Center(
                                      child: CupertinoActivityIndicator())
                                  : (comments.isEmpty
                                      ? const Center(
                                          child: Text('No comments yet'))
                                      : ListView.builder(
                                          controller: scrollCtrl,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          itemCount: comments.length,
                                          itemBuilder: (context, index) {
                                            final c = comments[index];
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              child: buildCommentItem(c),
                                            );
                                          },
                                        )),
                            ),
                            // Reply indicator
                            if (replyingToCommentId != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                color:
                                    CupertinoColors.secondarySystemBackground,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Replying to $replyingToUserName',
                                        style: const TextStyle(
                                          color: Color(0xFFB48648),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      minSize: 24,
                                      onPressed: cancelReply,
                                      child: const Icon(
                                        CupertinoIcons.xmark,
                                        size: 16,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Input field with keyboard-aware padding
                            Container(
                              padding: EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                12 + MediaQuery.viewInsetsOf(context).bottom,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBackground,
                                border: Border(
                                    top: BorderSide(
                                        color: Colors.grey.withOpacity(.2))),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: CupertinoTextField(
                                      controller: inputCtrl,
                                      placeholder: replyingToCommentId != null
                                          ? 'Write a reply...'
                                          : 'Write a comment...',
                                      maxLines: 2,
                                      minLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    color: const Color(0xFFB48648),
                                    onPressed: () => add(
                                        parentCommentId: replyingToCommentId),
                                    child: const Icon(
                                        CupertinoIcons.paperplane_fill,
                                        size: 18,
                                        color: CupertinoColors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (!GetIt.I.isRegistered<ArticlesApiService>()) {
      GetIt.I.registerSingleton<ArticlesApiService>(ArticlesApiService.init());
    }
    _api = GetIt.I.get<MusicApiService>();
    _articlesApi = GetIt.I.get<ArticlesApiService>();
    _authApi = GetIt.I.get<AuthApiService>();
    _loadHistory();
    _loadArtists();
    _fetch(reset: true);
  }

  Future<bool> _verifySupportPassword() async {
    final passwordCtrl = TextEditingController();
    bool confirmed = false;
    bool obscure = true;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('Confirm with password'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: passwordCtrl,
              placeholder: 'Password',
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              suffix: CupertinoButton(
                padding: const EdgeInsets.only(right: 8),
                minSize: 0,
                onPressed: () => setDialogState(() => obscure = !obscure),
                child: Icon(
                  obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                  size: 18,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                confirmed = true;
                Navigator.pop(dialogContext);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (!confirmed) return false;

    final password = passwordCtrl.text;
    if (password.trim().isEmpty) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Password is required',
        );
      }
      return false;
    }

    void hideLoading() {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }

    String normalizePhone(String raw) {
      var v = raw.trim();
      v = v.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (v.startsWith('00')) v = '+${v.substring(2)}';
      return v;
    }

    final profile = AppAuth.myProfile;
    final email = profile.email.trim();
    final phoneRaw = (profile.phoneNumber ?? '').trim();
    final phoneNormalized = normalizePhone(phoneRaw);
    final preferPhone = profile.registerMethod.toLowerCase().contains('phone');

    final candidates = <MapEntry<String, RegisterMethod>>[];
    void addCandidate(String id, RegisterMethod method) {
      final value = id.trim();
      if (value.isEmpty) return;
      final exists = candidates.any(
        (c) => c.key.toLowerCase() == value.toLowerCase() && c.value == method,
      );
      if (!exists) {
        candidates.add(MapEntry(value, method));
      }
    }

    if (preferPhone) {
      addCandidate(phoneRaw, RegisterMethod.phone);
      addCandidate(phoneNormalized, RegisterMethod.phone);
      addCandidate(email, RegisterMethod.email);
    } else {
      addCandidate(email, RegisterMethod.email);
      addCandidate(phoneRaw, RegisterMethod.phone);
      addCandidate(phoneNormalized, RegisterMethod.phone);
    }

    // Extra fallback for persisted maps that may have a different shape.
    final map = profile.toMap();
    final me = (map['me'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    addCandidate((me['email'] ?? '').toString(), RegisterMethod.email);
    addCandidate((me['phoneNumber'] ?? '').toString(), RegisterMethod.phone);

    if (candidates.isEmpty) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Unable to verify password right now',
      );
      return false;
    }

    VAppAlert.showLoading(context: context);
    try {
      final deviceHelper = DeviceInfoHelper();
      final deviceInfo = await deviceHelper.getDeviceMapInfo();
      final deviceId = await deviceHelper.getId();

      Object? lastError;
      for (final candidate in candidates) {
        try {
          await _authApi.verifyLoginPassword(
            LoginDto(
              email: candidate.key,
              method: candidate.value,
              password: password,
              deviceId: deviceId,
              deviceInfo: deviceInfo,
              platform: VPlatforms.currentPlatform,
              language: VLanguageListener.I.appLocal.languageCode,
              pushKey: null,
            ),
          );
          if (!mounted) return false;
          hideLoading();
          return true;
        } catch (e) {
          lastError = e;
        }
      }

      throw lastError ?? Exception('Password verification failed');
    } catch (e) {
      if (!mounted) return false;
      hideLoading();
      final error = e.toString().toLowerCase();
      final isInvalid = error.contains('invalidlogindata') ||
          error.contains('invalid login') ||
          error.contains('password');
      VAppAlert.showErrorSnackBar(
        context: context,
        message: isInvalid ? 'Incorrect password' : e.toString(),
      );
      return false;
    }
  }

  Future<void> _loadArtists() async {
    if (_loadingArtists) return;
    setState(() => _loadingArtists = true);
    try {
      _artists = await _api.getArtists();
    } catch (_) {
      _artists = [];
    }
    if (mounted) setState(() => _loadingArtists = false);
  }

  Future<void> _openArtistPicker() async {
    if (_artists.isEmpty && !_loadingArtists) {
      await _loadArtists();
    }
    if (!mounted) return;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Select Creator'),
        message: _artists.isEmpty
            ? const Text('No creators found')
            : Text('${_artists.length} creators available'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedArtist = null;
              });
              _fetch(reset: true);
            },
            child: const Text('All Creators'),
          ),
          ..._artists.take(12).map((artist) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedArtist = artist;
                  });
                  _fetch(reset: true);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (artist['userImage'] != null)
                      VCircleAvatar(
                        radius: 12,
                        vFileSource: VPlatformFile.fromUrl(
                          networkUrl: _artistImageUrl(artist),
                        ),
                      ),
                    if (artist['userImage'] != null) const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        artist['fullName']?.toString() ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${artist['contentCount'] ?? 0})',
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _shareToStory(Map<String, dynamic> item) async {
    final raw = (item['mediaUrl'] ?? item['url'] ?? '').toString();
    if (raw.isEmpty) return;
    final fullUrl =
        raw.startsWith('http') ? raw : SConstants.baseMediaUrl + raw;
    final mediaType = (item['mediaType'] ?? '').toString().toLowerCase();
    final mime = (item['mimeType'] ?? '').toString().toLowerCase();
    final lowerUrl = fullUrl.toLowerCase();
    const audioExts = [
      '.mp3',
      '.m4a',
      '.aac',
      '.wav',
      '.ogg',
      '.flac',
      '.opus'
    ];
    final isAudioByExt = audioExts.any((e) => lowerUrl.contains(e));
    final isAudio =
        mediaType == 'audio' || mime.startsWith('audio/') || isAudioByExt;

    final title = (item['title'] ?? '').toString();

    VAppAlert.showLoading(context: context);
    try {
      final st = isAudio ? StoryType.voice : StoryType.video;
      // Download the media first, then upload as bytes (multipart)
      final fileName = fullUrl.split('/').last;
      final bytes = await http.readBytes(Uri.parse(fullUrl));
      final vFile = VPlatformFile.fromBytes(
        name: fileName.isEmpty
            ? (st == StoryType.voice ? 'story_audio.mp3' : 'story_video.mp4')
            : fileName,
        bytes: bytes,
      );
      final dto = CreateStoryDto(
        image: vFile,
        storyType: st,
        content: st.name, // must be non-null and match type naming
        caption: title, // non-null string
        backgroundColor: '000000', // avoid null PartValue
        attachment: const {}, // ensure backend jsonDecoder gets a valid JSON string
        storyPrivacy: StoryPrivacy.public,
      );
      await GetIt.I.get<StoryApiService>().createStory(dto);
      // Make it visible immediately in the Stories tab (with quick retries)
      try {
        final svc = GetIt.I.get<StoryStatusService>();
        final tab = _ensureStoryTabController();
        // First pass
        await svc.refreshMyStories();
        await tab.getMyStoryFromApi();
        await tab.getStoriesFromApi();
        tab.update();
        // Small retries to beat eventual consistency / delayed processing (~5s)
        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 1000));
          await svc.refreshMyStories();
          await tab.getMyStoryFromApi();
          tab.update();
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pop();
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Shared to your story',
      );
      // Do not navigate; keep user on Music and allow Stories tab to show new ring
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  Future<void> _support(Map<String, dynamic> item) async {
    final id = (item['_id'] ?? item['id'])?.toString();
    final uploader = (item['uploaderData']?['fullName'] ?? '').toString();
    if (id == null || id.isEmpty) return;
    if (!_isArticlesMode && _isOwner(item)) return;

    void hideLoading() {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }

    final amtCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? res;

    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Support${uploader.isNotEmpty ? ' $uploader' : ''}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: amtCtrl,
                placeholder: 'Amount (KES)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
              ),
              if (_isArticlesMode) ...[
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: phoneCtrl,
                  placeholder: 'Phone (07.. or 2547..)',
                  keyboardType: TextInputType.phone,
                ),
              ],
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              res = 'ok';
              Navigator.pop(context);
            },
            child: const Text('Support'),
          ),
        ],
      ),
    );

    if (res != 'ok') return;
    final amount = num.tryParse(amtCtrl.text.trim());
    final phone = phoneCtrl.text.trim();
    if (amount == null || amount <= 0) {
      VAppAlert.showErrorSnackBar(
          context: context, message: 'Enter valid amount');
      return;
    }
    if (_isArticlesMode && phone.isEmpty) {
      VAppAlert.showErrorSnackBar(
          context: context, message: 'Enter phone number');
      return;
    }

    if (!_isArticlesMode) {
      final verified = await _verifySupportPassword();
      if (!verified) return;
    }

    VAppAlert.showLoading(context: context);
    try {
      if (_isArticlesMode) {
        await _articlesApi.support(articleId: id, amount: amount, phone: phone);
      } else {
        await GetIt.I.get<MusicApiService>().support(
              musicId: id,
              amount: amount,
            );
      }
      if (!mounted) return;
      hideLoading();

      if (!_isArticlesMode) {
        await BalanceService.instance.init();
      }

      // Wait for loading dialog to fully dismiss, then show success dialog
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        final navContext = navigatorKey.currentState?.overlay?.context;
        debugPrint(
            'DEBUG SUCCESS: navContext = $navContext, mounted = ${navContext?.mounted}');
        if (navContext != null && navContext.mounted) {
          debugPrint('DEBUG SUCCESS: Showing success dialog');
          await showDialog(
            context: navContext,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Success'),
              content: Text(_isArticlesMode
                  ? 'STK push sent. Check your phone to complete payment.'
                  : 'Support sent successfully'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          debugPrint('DEBUG SUCCESS: Success dialog dismissed');
        } else {
          debugPrint('DEBUG SUCCESS: navContext is null or not mounted');
        }
      });
    } catch (e) {
      if (!mounted) return;
      hideLoading();

      final msg = e.toString().toLowerCase();
      debugPrint('DEBUG ERROR: Original error: $e');
      debugPrint('DEBUG ERROR: Lowercase message: $msg');
      final isInsufficient = msg.contains('insufficient balance') ||
          msg.contains('400') ||
          msg.contains('bad request');
      debugPrint('DEBUG ERROR: isInsufficient = $isInsufficient');
      if (!_isArticlesMode && isInsufficient) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future.delayed(const Duration(milliseconds: 200));
          final navContext = navigatorKey.currentState?.overlay?.context;
          if (navContext != null) {
            final r = await VAppAlert.showAskYesNoDialog(
                context: navContext,
                title: 'Insufficient balance',
                content:
                    'You do not have enough balance. Would you like to top up?');
            if (r == 1 && mounted) {
              await Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const WalletPage()),
              );

              if (mounted) {
                await BalanceService.instance.init();
              }
            }
          }
        });
        return;
      }

      // Wait for loading dialog to fully dismiss, then show error dialog
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        final navContext = navigatorKey.currentState?.overlay?.context;
        debugPrint(
            'DEBUG: navContext = $navContext, mounted = ${navContext?.mounted}');
        if (navContext != null && navContext.mounted) {
          debugPrint('DEBUG: Showing error dialog');
          await showDialog(
            context: navContext,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Error'),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          debugPrint('DEBUG: Error dialog dismissed');
        } else {
          debugPrint('DEBUG: navContext is null or not mounted');
        }
      });
    }
  }

  Future<void> _fetch({required bool reset, bool loadMore = false}) async {
    if (reset) {
      _pages[_filter] = 1;
      _hasMore[_filter] = true;
      _tabItems[_filter]!.clear();
    }

    if (!_hasMore[_filter]! && loadMore) return;

    setState(() {
      _loading = true;
    });

    try {
      if (_isArticlesMode) {
        final Map<String, dynamic> result = await _articlesApi.listArticles(
          query: _searchQuery,
          page: _pages[_filter]!,
          limit: _pageSize,
        );
        if (!mounted) return;

        final List<Map<String, dynamic>> docs =
            (result['docs'] as List).cast<Map<String, dynamic>>();
        final int total = (result['total'] as num).toInt();

        for (final a in docs) {
          a['likesCount'] = _asInt(a['likesCount'] ?? 0);
          a['commentsCount'] = _asInt(a['commentsCount'] ?? 0);
          a['isLiked'] = a['isLiked'] == true;
        }

        setState(() {
          if (reset) {
            _tabItems[_filter]!.clear();
          }
          _tabItems[_filter]!.addAll(docs);
          // Check if there are more items based on total count
          final loadedCount = _tabItems[_filter]!.length;
          _hasMore[_filter] = loadedCount < total;
          if (_hasMore[_filter]!) {
            _pages[_filter] = _pages[_filter]! + 1;
          }
          _applyLocalFilterInPlace();
        });
        return;
      }

      String? category;
      String? mediaType;
      if (_filter == 'music') {
        mediaType = 'video';
      } else if (_filter == 'audio') {
        mediaType = 'audio';
      }

      final Map<String, dynamic> result = await _api.listMusic(
        category: category,
        mediaType: mediaType,
        query: _searchQuery,
        uploaderId: _selectedArtist?['_id']?.toString(),
        page: _pages[_filter]!,
        limit: _pageSize,
      );

      if (!mounted) return;

      final List<Map<String, dynamic>> docs =
          (result['docs'] as List).cast<Map<String, dynamic>>();
      final int total = (result['total'] as num).toInt();

      for (final m in docs) {
        m['likesCount'] = _asInt(m['likesCount'] ?? 0);
        m['commentsCount'] = _asInt(m['commentsCount'] ?? 0);
        m['playsCount'] = _asInt(m['playsCount'] ?? 0);
        m['isLiked'] = m['isLiked'] == true;
      }

      setState(() {
        if (reset) {
          _tabItems[_filter]!.clear();
        }
        _tabItems[_filter]!.addAll(docs);
        // Check if there are more items based on total count
        final loadedCount = _tabItems[_filter]!.length;
        _hasMore[_filter] = loadedCount < total;
        if (_hasMore[_filter]!) {
          _pages[_filter] = _pages[_filter]! + 1;
        }
        _applyLocalFilterInPlace();
      });
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _upload() async {
    try {
      final choice = await showCupertinoModalPopup<String>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('Upload'),
          message: const Text('Choose what you want to upload'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'audio'),
              child: const Text('Audio file'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'video'),
              child: const Text('Video'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'pdf'),
              child: const Text('Article (PDF)'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      );

      if (choice == null) return;

      List<VPlatformFile>? picked;
      if (choice == 'audio') {
        picked = await VAppPick.getFiles();
      } else {
        if (choice == 'video') {
          final v = await VAppPick.getVideo();
          picked = v == null ? null : [v];
        } else {
          picked = await VAppPick.getFiles();
        }
      }

      if (picked == null || picked.isEmpty) return;
      final file = picked.first;

      final titleCtrl = TextEditingController(text: file.name);
      final descCtrl = TextEditingController();
      final genreCtrl = TextEditingController();
      String? result;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      CupertinoTextField(
                        controller: titleCtrl,
                        placeholder: 'Title',
                        textInputAction: TextInputAction.next,
                      ),
                      if (choice != 'pdf') ...[
                        const SizedBox(height: 12),
                        CupertinoTextField(
                          controller: genreCtrl,
                          placeholder: 'Genre (optional)',
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                      const SizedBox(height: 12),
                      CupertinoTextField(
                        controller: descCtrl,
                        placeholder: 'Description (optional)',
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton.filled(
                        onPressed: () {
                          result = 'ok';
                          Navigator.pop(ctx);
                        },
                        child: const Text('Upload'),
                      ),
                      const SizedBox(height: 8),
                      CupertinoButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

      if (result != 'ok') return;

      VAppAlert.showLoading(context: context);
      try {
        final String title =
            titleCtrl.text.trim().isEmpty ? file.name : titleCtrl.text.trim();
        final String? desc =
            descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();

        Map<String, dynamic> item;
        if (choice == 'pdf') {
          item = await _articlesApi.uploadPdf(
            file: file,
            title: title,
            description: desc,
          );
        } else {
          item = await _api.uploadMusic(
            file: file,
            title: title,
            description: desc,
            genre: genreCtrl.text.trim().isEmpty ? null : genreCtrl.text.trim(),
            category: choice == 'audio' ? 'music' : 'video',
          );
        }
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          if (choice != 'pdf') {
            item['isLiked'] = false;
            item['likesCount'] = item['likesCount'] ?? 0;
            item['commentsCount'] = item['commentsCount'] ?? 0;
          }
          _fetchedItems.insert(0, item);
          _applyLocalFilterInPlace();
        });
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Uploaded successfully',
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future<void> _play(
    Map<String, dynamic> item, {
    int? index,
    List<Map<String, dynamic>>? sourceItems,
  }) async {
    final source = sourceItems ?? _items;
    var targetIndex = index ?? _indexOfIn(source, item);

    if (targetIndex < 0 || targetIndex >= source.length) {
      // Fallback for items opened from outside the current list.
      await _playAtIndex(
        navContext: context,
        sourceItems: [item],
        index: 0,
      );
      return;
    }

    try {
      await _playAtIndex(
        navContext: context,
        sourceItems: source,
        index: targetIndex,
      );
    } catch (_) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Cannot play this media',
      );
    }
  }

  Widget _buildLargeThumbnail(Map<String, dynamic> item) {
    final thumbnailUrl = (item['thumbnailUrl'] ?? '').toString();

    if (thumbnailUrl.isNotEmpty) {
      final fullThumbnailUrl = thumbnailUrl.startsWith('http')
          ? thumbnailUrl
          : SConstants.baseMediaUrl + thumbnailUrl;

      return Image.network(
        fullThumbnailUrl,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black.withOpacity(0.05),
      child: const Center(
        child: Icon(
          CupertinoIcons.video_camera,
          color: Color(0xFFB48648),
          size: 40,
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(Map<String, dynamic> item) {
    final t = (item['mediaType'] ?? '').toString().toLowerCase();
    if (t == 'audio') return CupertinoIcons.music_note_2;
    if (t == 'video') return CupertinoIcons.play_rectangle;
    final mime = (item['mimeType'] ?? '').toString();
    if (mime.startsWith('audio/')) return CupertinoIcons.music_note_2;
    if (mime.startsWith('video/')) return CupertinoIcons.play_rectangle;
    return CupertinoIcons.square_on_square;
  }

  Future<void> _openItemMenu(Map<String, dynamic> item) async {
    final allowedDelete = _isOwner(item) || _isAdmin();
    final allowedReport = !_isOwner(item);
    final canSupport = _isArticlesMode || !_isOwner(item);
    String? action;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text((item['title'] ?? 'Music').toString()),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'comments';
              Navigator.pop(context);
            },
            child: const Text('Comments'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'share';
              Navigator.pop(context);
            },
            child: const Text('Share to Story'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'share_chat';
              Navigator.pop(context);
            },
            child: const Text('Share to Chat'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'share_link';
              Navigator.pop(context);
            },
            child: const Text('Share Link'),
          ),
          if (canSupport)
            CupertinoActionSheetAction(
              onPressed: () {
                action = 'support';
                Navigator.pop(context);
              },
              child: const Text('Support'),
            ),
          if (allowedReport)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                action = 'report';
                Navigator.pop(context);
              },
              child: const Text('Report'),
            ),
          if (allowedDelete)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                action = 'delete';
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (action == 'comments') return _openComments(item);
    if (action == 'share') return _shareToStory(item);
    if (action == 'share_chat') return _shareToChat(item);
    if (action == 'share_link') return _shareLink(item);
    if (action == 'support') return _support(item);
    if (action == 'report') return _reportItem(item);
    if (action == 'delete') return _confirmDelete(item);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 30,
          onPressed: _openHistory,
          child: const Icon(
            CupertinoIcons.time,
            color: Color(0xFFB48648),
            size: 22,
          ),
        ),
        middle: const Text('Music'),
        trailing: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          onPressed: _upload,
          child: const Text(
            'Upload',
            style: TextStyle(
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          color: const Color(0xFFB48648),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: CupertinoSegmentedControl<String>(
                groupValue: _filter,
                onValueChanged: (v) {
                  setState(() {
                    _filter = v;
                  });
                  _fetch(reset: true);
                },
                children: const {
                  'all': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Content'),
                  ),
                  'music': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Music Video'),
                  ),
                  'audio': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Audio'),
                  ),
                  'articles': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Articles'),
                  ),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search',
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _fetch(reset: true),
              ),
            ),
            // Creator filter row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.person_circle,
                      size: 18, color: CupertinoColors.systemGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _openArtistPicker,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.secondarySystemBackground,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: CupertinoColors.systemGrey4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedArtist?['fullName']?.toString() ??
                                    'All Creators',
                                style: TextStyle(
                                  color: _selectedArtist != null
                                      ? const Color(0xFFB48648)
                                      : CupertinoColors.systemGrey,
                                  fontWeight: _selectedArtist != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _loadingArtists
                                ? const CupertinoActivityIndicator(radius: 8)
                                : const Icon(CupertinoIcons.chevron_down,
                                    size: 14,
                                    color: CupertinoColors.systemGrey),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_selectedArtist != null) ...[
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 32,
                      onPressed: () {
                        setState(() {
                          _selectedArtist = null;
                        });
                        _fetch(reset: true);
                      },
                      child: const Icon(CupertinoIcons.xmark_circle_fill,
                          size: 22, color: CupertinoColors.systemGrey),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _loading && _items.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _fetch(reset: true),
                      child: _items.isEmpty
                          ? Center(
                              child: Text(_isArticlesMode
                                  ? 'No articles uploaded yet'
                                  : 'No music uploaded yet'),
                            )
                          : ListView.separated(
                              itemCount:
                                  _items.length + (_hasMore[_filter]! ? 1 : 0),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                // Show Load More button at the end
                                if (index == _items.length) {
                                  return Center(
                                    child: _loading
                                        ? const CupertinoActivityIndicator()
                                        : CupertinoButton.filled(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 24, vertical: 12),
                                            onPressed: () => _fetch(
                                                reset: false, loadMore: true),
                                            child: const Text(
                                              'Load More',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                  );
                                }

                                final m = _items[index];
                                final title =
                                    (m['title'] ?? 'Untitled').toString();
                                final genre =
                                    (m['genre'] ?? '').toString().trim();
                                final uploader =
                                    (m['uploaderData']?['fullName'] ?? '')
                                        .toString();
                                final uploaderImg =
                                    (m['uploaderData']?['userImage'] ?? '')
                                        .toString();
                                final createdAt = _parseCreatedAt(m);
                                final plays = _isArticlesMode
                                    ? 0
                                    : (m['playsCount'] ?? 0) as int;
                                final isLiked = (m['isLiked'] == true);
                                final likesCount =
                                    (m['likesCount'] ?? 0) as int;
                                final commentsCount =
                                    (m['commentsCount'] ?? 0) as int;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors
                                        .secondarySystemBackground,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () {
                                        if (_isArticlesMode) {
                                          final raw =
                                              (m['fileUrl'] ?? m['url'] ?? '')
                                                  .toString();
                                          if (raw.isEmpty) return;
                                          _rememberSeen(m);
                                          final fullUrl = raw.startsWith('http')
                                              ? raw
                                              : SConstants.baseMediaUrl + raw;
                                          VStringUtils.lunchLink(fullUrl);
                                          return;
                                        }
                                        _play(m, index: index);
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (!_isArticlesMode &&
                                              m['mediaType'] == 'video')
                                            Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Container(
                                                  height: 200,
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        const BorderRadius
                                                            .vertical(
                                                            top:
                                                                Radius.circular(
                                                                    20)),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        const BorderRadius
                                                            .vertical(
                                                            top:
                                                                Radius.circular(
                                                                    20)),
                                                    child:
                                                        _buildLargeThumbnail(m),
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFB48648)
                                                            .withOpacity(0.8),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    CupertinoIcons.play_fill,
                                                    color: Colors.white,
                                                    size: 30,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    if (_isArticlesMode ||
                                                        m['mediaType'] !=
                                                            'video') ...[
                                                      Container(
                                                        width: 50,
                                                        height: 50,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                                  0xFFB48648)
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: Icon(
                                                          _isArticlesMode
                                                              ? CupertinoIcons
                                                                  .doc_text
                                                              : _iconFor(m),
                                                          color: const Color(
                                                              0xFFB48648),
                                                          size: 28,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                    ],
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            title,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              fontSize: 17,
                                                            ),
                                                          ),
                                                          if (genre
                                                              .isNotEmpty) ...[
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(
                                                              genre,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ],
                                                          const SizedBox(
                                                              height: 4),
                                                          Row(
                                                            children: [
                                                              if (uploaderImg
                                                                  .isNotEmpty)
                                                                VCircleAvatar(
                                                                  radius: 9,
                                                                  vFileSource:
                                                                      VPlatformFile.fromUrl(
                                                                          networkUrl:
                                                                              uploaderImg),
                                                                )
                                                              else
                                                                const Icon(
                                                                    CupertinoIcons
                                                                        .person_alt_circle,
                                                                    size: 18,
                                                                    color: Colors
                                                                        .grey),
                                                              const SizedBox(
                                                                  width: 6),
                                                              Expanded(
                                                                child:
                                                                    GestureDetector(
                                                                  onTap: () =>
                                                                      _openUploaderChat(
                                                                          m),
                                                                  behavior:
                                                                      HitTestBehavior
                                                                          .opaque,
                                                                  child: Text(
                                                                    uploader.isEmpty
                                                                        ? 'Unknown'
                                                                        : uploader,
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Color(
                                                                          0xFFB48648),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (createdAt !=
                                                              null) ...[
                                                            const SizedBox(
                                                                height: 2),
                                                            Text(
                                                              'Uploaded ${_formatUploadDate(context, createdAt)}',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .grey
                                                                    .shade500,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    CupertinoButton(
                                                      padding: EdgeInsets.zero,
                                                      minSize: 32,
                                                      onPressed: () {
                                                        if (_isArticlesMode) {
                                                          _openArticleMenu(m);
                                                          return;
                                                        }
                                                        _openItemMenu(m);
                                                      },
                                                      child: const Icon(
                                                        CupertinoIcons.ellipsis,
                                                        size: 22,
                                                        color: CupertinoColors
                                                            .systemGrey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                if (_isArticlesMode)
                                                  Row(
                                                    children: [
                                                      _buildStatItem(
                                                        icon: isLiked
                                                            ? CupertinoIcons
                                                                .heart_fill
                                                            : CupertinoIcons
                                                                .heart,
                                                        label: '$likesCount',
                                                        color: isLiked
                                                            ? CupertinoColors
                                                                .systemRed
                                                            : Colors
                                                                .grey.shade600,
                                                        onTap: () =>
                                                            _toggleLike(m),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      _buildStatItem(
                                                        icon: CupertinoIcons
                                                            .chat_bubble,
                                                        label: '$commentsCount',
                                                        color: Colors
                                                            .grey.shade600,
                                                        onTap: () =>
                                                            _openComments(m),
                                                      ),
                                                      const Spacer(),
                                                      if (_isArticlesMode ||
                                                          !_isOwner(m))
                                                        CupertinoButton(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      14,
                                                                  vertical: 8),
                                                          minSize: 0,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                          color: const Color(
                                                              0xFFB48648),
                                                          onPressed: () =>
                                                              _support(m),
                                                          child: const Text(
                                                            'Support',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  )
                                                else
                                                  Row(
                                                    children: [
                                                      _buildStatItem(
                                                        icon: isLiked
                                                            ? CupertinoIcons
                                                                .heart_fill
                                                            : CupertinoIcons
                                                                .heart,
                                                        label: '$likesCount',
                                                        color: isLiked
                                                            ? CupertinoColors
                                                                .systemRed
                                                            : Colors
                                                                .grey.shade600,
                                                        onTap: () =>
                                                            _toggleLike(m),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      _buildStatItem(
                                                        icon: CupertinoIcons
                                                            .chat_bubble,
                                                        label: '$commentsCount',
                                                        color: Colors
                                                            .grey.shade600,
                                                        onTap: () =>
                                                            _openComments(m),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Text(
                                                        '$plays plays',
                                                        style: TextStyle(
                                                          color: Colors
                                                              .grey.shade500,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      const Spacer(),
                                                      if (_isArticlesMode ||
                                                          !_isOwner(m))
                                                        CupertinoButton(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      14,
                                                                  vertical: 8),
                                                          minSize: 0,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                          color: const Color(
                                                              0xFFB48648),
                                                          onPressed: () =>
                                                              _support(m),
                                                          child: const Text(
                                                            'Support',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openArticleMenu(Map<String, dynamic> item) async {
    String? action;
    final allowedDelete = _isOwner(item) || _isAdmin();
    final allowedReport = !_isOwner(item);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text((item['title'] ?? 'Article').toString()),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'open';
              Navigator.pop(context);
            },
            child: const Text('Open PDF'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'share_chat';
              Navigator.pop(context);
            },
            child: const Text('Share to Chat'),
          ),
          if (allowedReport)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                action = 'report';
                Navigator.pop(context);
              },
              child: const Text('Report'),
            ),
          if (allowedDelete)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                action = 'delete';
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (action == 'open') {
      final raw = (item['fileUrl'] ?? item['url'] ?? '').toString();
      if (raw.isEmpty) return;
      final fullUrl =
          raw.startsWith('http') ? raw : SConstants.baseMediaUrl + raw;
      VStringUtils.lunchLink(fullUrl);
      return;
    }

    if (action == 'share_chat') {
      return _shareToChat(item);
    }

    if (action == 'report') {
      return _reportArticle(item);
    }

    if (action == 'delete') {
      return _confirmDeleteArticle(item);
    }
  }

  Future<void> _reportArticle(Map<String, dynamic> item) async {
    if (_reporting) return;
    final id = _idOf(item);
    if (id.isEmpty) return;
    final reason = await _askReportReason();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _reporting = true);
    try {
      await _articlesApi.reportArticle(id: id, content: reason.trim());
      if (!mounted) return;
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Report submitted successfully',
      );
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  Future<void> _confirmDeleteArticle(Map<String, dynamic> item) async {
    final id = _idOf(item);
    if (id.isEmpty) return;
    final allowed = _isOwner(item) || _isAdmin();
    if (!allowed) return;

    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: 'Delete',
      content: 'Delete this article?',
    );
    if (res != 1) return;

    VAppAlert.showLoading(context: context);
    try {
      await _articlesApi.deleteArticle(id);
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _items.remove(item);
      });
      VAppAlert.showSuccessSnackBar(context: context, message: 'Deleted');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }
}
