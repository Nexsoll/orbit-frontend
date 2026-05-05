import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

/// Shows a comment bottom sheet for a given post.
///
/// [postId]         – the post document ID.
/// [postUserId]     – the owner of the post (used to decide who may reply).
/// [initialCount]   – current commentsCount displayed while loading.
/// [onCountChanged] – called with the new commentsCount after each CUD op.
class PostCommentSheet {
  static Future<void> show(
    BuildContext context, {
    required String postId,
    required String postUserId,
    int initialCount = 0,
    ValueChanged<int>? onCountChanged,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _PostCommentSheetContent(
        postId: postId,
        postUserId: postUserId,
        onCountChanged: onCountChanged,
      ),
    );
  }
}

class _PostCommentSheetContent extends StatefulWidget {
  const _PostCommentSheetContent({
    required this.postId,
    required this.postUserId,
    this.onCountChanged,
  });

  final String postId;
  final String postUserId;
  final ValueChanged<int>? onCountChanged;

  @override
  State<_PostCommentSheetContent> createState() =>
      _PostCommentSheetContentState();
}

class _PostCommentSheetContentState extends State<_PostCommentSheetContent> {
  final _api = GetIt.I.get<PostApiService>();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final _comments = <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _replyingToCommentId;
  String? _replyingToUserName;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _api.listComments(widget.postId);
      if (mounted) {
        setState(() {
          _comments
            ..clear()
            ..addAll(docs);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    final parentId = _replyingToCommentId;
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserName = null;
    });
    try {
      final res = await _api.addComment(
        widget.postId,
        text,
        parentCommentId: parentId,
      );
      final c = res['comment'];
      final count = (res['commentsCount'] as num?)?.toInt() ?? 0;
      if (c is Map) {
        final newComment = Map<String, dynamic>.from(c);
        if (mounted) {
          setState(() {
            if (parentId == null) {
              _comments.insert(0, newComment);
            } else {
              final idx = _comments.indexWhere((comment) =>
                  (comment['_id'] ?? comment['id'])?.toString() == parentId);
              if (idx != -1) {
                final replies =
                    ((_comments[idx]['replies'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        [])
                      ..add(newComment);
                _comments[idx]['replies'] = replies;
                _comments[idx]['repliesCount'] = replies.length;
              }
            }
          });
        }
      }
      widget.onCountChanged?.call(count);
      await Future.delayed(const Duration(milliseconds: 50));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
            context: context, message: e.toString());
      }
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> c) async {
    final commentId = (c['_id'] ?? c['id'] ?? '').toString();
    if (commentId.isEmpty) return;
    try {
      final res =
          await _api.deleteComment(widget.postId, commentId);
      final count = (res['commentsCount'] as num?)?.toInt() ?? 0;
      if (mounted) {
        setState(() => _comments.remove(c));
      }
      widget.onCountChanged?.call(count);
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
            context: context, message: e.toString());
      }
    }
  }

  void _startReply(Map<String, dynamic> c) {
    setState(() {
      _replyingToCommentId = (c['_id'] ?? c['id'] ?? '').toString();
      _replyingToUserName =
          (c['userData']?['fullName'] ?? 'User').toString();
    });
  }

  void _cancelReply() => setState(() {
        _replyingToCommentId = null;
        _replyingToUserName = null;
      });

  bool _canDelete(Map<String, dynamic> c) {
    final commentUserId =
        (c['userData']?['_id'] ?? c['userId'] ?? '').toString();
    return commentUserId == AppAuth.myId || widget.postUserId == AppAuth.myId;
  }

  Widget _buildCommentItem(Map<String, dynamic> c, {bool isReply = false}) {
    final userName = (c['userData']?['fullName'] ?? '').toString();
    final userImg = (c['userData']?['userImage'] ?? '').toString();
    final text = (c['text'] ?? '').toString();
    final replies =
        (c['replies'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final repliesCount = (c['repliesCount'] ?? replies.length) as int;
    final canDelete = _canDelete(c);

    return Container(
      padding: const EdgeInsets.all(10),
      margin: isReply ? const EdgeInsets.only(left: 40, top: 8) : null,
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
                vFileSource: VPlatformFile.fromUrl(networkUrl: userImg),
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
                            onPressed: () => _deleteComment(c),
                            child: const Icon(
                              CupertinoIcons.delete,
                              size: 18,
                              color: CupertinoColors.systemRed,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(text,
                        style: TextStyle(fontSize: isReply ? 13 : 14)),
                    if (!isReply)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: GestureDetector(
                          onTap: () => _startReply(c),
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
          ...replies
              .map((reply) => _buildCommentItem(reply, isReply: true))
              .toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: Navigator.of(context).pop,
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
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minSize: 28,
                          onPressed: Navigator.of(context).pop,
                          child:
                              const Icon(CupertinoIcons.xmark, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CupertinoActivityIndicator())
                          : _comments.isEmpty
                              ? const Center(
                                  child: Text('No comments yet'))
                              : ListView.builder(
                                  controller: _scrollCtrl,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  itemCount: _comments.length,
                                  itemBuilder: (context, i) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10),
                                    child: _buildCommentItem(_comments[i]),
                                  ),
                                ),
                    ),
                    if (_replyingToCommentId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        color: CupertinoColors.secondarySystemBackground,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Replying to $_replyingToUserName',
                                style: const TextStyle(
                                  color: Color(0xFFB48648),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 24,
                              onPressed: _cancelReply,
                              child: const Icon(
                                CupertinoIcons.xmark,
                                size: 16,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                              controller: _inputCtrl,
                              placeholder: _replyingToCommentId != null
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
                            onPressed: _addComment,
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
  }
}
