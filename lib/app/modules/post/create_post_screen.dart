import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_media_editor/v_chat_media_editor.dart';
import 'package:v_platform/v_platform.dart';

import 'post_caption_editor.dart';
import 'create_location_post.dart';

const _kPrimary = Color(0xFFB48648);
const _kBg = Color(0xFFc9cfc8);
const _kDarkBg = Color(0xFF0D0D0D);
const _kCard = Colors.white;
const _kDarkCard = Color(0xFF1C1C1E);

Future<VPlatformFile?> _pickAndTrimVideo(
  BuildContext context,
  ImagePicker picker,
) async {
  final selected = await picker.pickVideo(source: ImageSource.gallery);
  if (selected == null) return null;

  final source = VPlatformFile.fromPath(fileLocalPath: selected.path);
  final result = await context.toPage(
    VMediaEditorView(
      files: [source],
      config: const VMediaEditorConfig(
        showTextInput: false,
        showOneTimeToggle: false,
      ),
    ),
  ) as VMediaEditorResult?;

  if (result == null || result.mediaFiles.isEmpty) {
    return null;
  }
  return result.mediaFiles.first.getVPlatformFile();
}

// ─── Entry point ─────────────────────────────────────────────────────────────

class CreatePostScreen extends StatefulWidget {
  final String? initialTab;
  const CreatePostScreen({super.key, this.initialTab});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabNames = ['text', 'image', 'video', 'reel', 'location'];

  @override
  void initState() {
    super.initState();
    int initial = 0;
    if (widget.initialTab != null) {
      final idx = _tabNames.indexOf(widget.initialTab!.toLowerCase());
      if (idx >= 0) initial = idx;
    }
    _tabController = TabController(length: 5, vsync: this, initialIndex: initial);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _kDarkBg : _kBg;
    final cardBg = isDark ? _kDarkCard : _kCard;
    final fg = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: fg),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Create Post',
            style: TextStyle(
                color: fg, fontWeight: FontWeight.w700, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: _kPrimary,
          labelColor: _kPrimary,
          unselectedLabelColor: fg.withValues(alpha: 0.5),
          labelPadding: EdgeInsets.zero,
          tabs: const [
            Tab(text: 'Text'),
            Tab(text: 'Photos'),
            Tab(text: 'Video'),
            Tab(text: 'Reel'),
            Tab(text: 'Location'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _TextPostTab(bg: bg, cardBg: cardBg, fg: fg),
          _PhotoPostTab(bg: bg, cardBg: cardBg, fg: fg),
          _VideoPostTab(bg: bg, cardBg: cardBg, fg: fg),
          _ReelPostTab(bg: bg, cardBg: cardBg, fg: fg),
          const CreateLocationPost(),
        ],
      ),
    );
  }
}

// ─── Text Post Tab ────────────────────────────────────────────────────────────

class _TextPostTab extends StatefulWidget {
  final Color bg, cardBg, fg;
  const _TextPostTab({required this.bg, required this.cardBg, required this.fg});

  @override
  State<_TextPostTab> createState() => _TextPostTabState();
}

class _TextPostTabState extends State<_TextPostTab> {
  final _caption = TextEditingController();
  final _svc = GetIt.I.get<PostApiService>();
  bool _loading = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_caption.text.trim().isEmpty) return;
    await vSafeApiCall(
      onLoading: () {
        setState(() => _loading = true);
      },
      request: () => _svc.createTextPost(caption: _caption.text.trim()),
      onSuccess: (_) {
        if (mounted) {
          setState(() => _loading = false);
          PostApiService.notifySocialFeedRefresh();
          Navigator.of(context).pop(true);
        }
      },
      onError: (e, _) {
        setState(() => _loading = false);
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionLabel('What\'s on your mind?', widget.fg),
              const SizedBox(height: 8),
              PostCaptionEditor(
                controller: _caption,
                textColor: widget.fg,
                placeholderColor: widget.fg.withValues(alpha: 0.4),
                highlightColor: _kPrimary,
                decoration: BoxDecoration(
                  color: widget.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
              ),
            ]),
          ),
        ),
        _PostButton(loading: _loading, onTap: _post),
      ]),
    );
  }
}

// ─── Photo Post Tab ───────────────────────────────────────────────────────────

class _PhotoPostTab extends StatefulWidget {
  final Color bg, cardBg, fg;
  const _PhotoPostTab(
      {required this.bg, required this.cardBg, required this.fg});

  @override
  State<_PhotoPostTab> createState() => _PhotoPostTabState();
}

class _PhotoPostTabState extends State<_PhotoPostTab> {
  final _caption = TextEditingController();
  final _svc = GetIt.I.get<PostApiService>();
  final _picker = ImagePicker();
  final List<File> _images = [];
  bool _loading = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final results = await _picker.pickMultiImage(imageQuality: 85);
    if (results.isNotEmpty) {
      setState(() {
        for (final x in results) {
          if (_images.length < 10) _images.add(File(x.path));
        }
      });
    }
  }

  Future<void> _post() async {
    if (_images.isEmpty) {
      VAppAlert.showErrorSnackBar(
          context: context, message: 'Pick at least one photo');
      return;
    }
    final files = _images
        .map((f) => VPlatformFile.fromPath(fileLocalPath: f.path))
        .toList();
    await vSafeApiCall(
      onLoading: () {
        setState(() => _loading = true);
      },
      request: () => _svc.createMultiPhotoPost(
        files: files,
        caption:
            _caption.text.trim().isNotEmpty ? _caption.text.trim() : null,
      ),
      onSuccess: (_) {
        if (mounted) {
          setState(() => _loading = false);
          PostApiService.notifySocialFeedRefresh();
          Navigator.of(context).pop(true);
        }
      },
      onError: (e, _) {
        setState(() => _loading = false);
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PostCaptionEditor(
                controller: _caption,
                textColor: widget.fg,
                placeholderColor: widget.fg.withValues(alpha: 0.4),
                highlightColor: _kPrimary,
                decoration: BoxDecoration(
                  color: widget.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                _SectionLabel('Photos (${_images.length}/10)', widget.fg),
                const Spacer(),
                if (_images.length < 10)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_photo_alternate,
                            color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Add',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              if (_images.isEmpty)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: widget.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _kPrimary.withValues(alpha: 0.3), width: 2,
                          style: BorderStyle.solid),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              size: 48,
                              color: _kPrimary.withValues(alpha: 0.6)),
                          const SizedBox(height: 8),
                          Text('Tap to add up to 10 photos',
                              style: TextStyle(
                                  color: widget.fg.withValues(alpha: 0.5),
                                  fontSize: 14)),
                        ]),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _images.length,
                  itemBuilder: (_, i) => Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_images[i],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
        _PostButton(loading: _loading, onTap: _post),
      ]),
    );
  }
}

// ─── Video Post Tab ───────────────────────────────────────────────────────────

class _VideoPostTab extends StatefulWidget {
  final Color bg, cardBg, fg;
  const _VideoPostTab(
      {required this.bg, required this.cardBg, required this.fg});

  @override
  State<_VideoPostTab> createState() => _VideoPostTabState();
}

class _VideoPostTabState extends State<_VideoPostTab> {
  final _caption = TextEditingController();
  final _svc = GetIt.I.get<PostApiService>();
  final _picker = ImagePicker();
  VPlatformFile? _video;
  bool _loading = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await _pickAndTrimVideo(context, _picker);
    if (!mounted || result == null) return;
    setState(() => _video = result);
  }

  Future<void> _post() async {
    if (_video == null) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Pick a video');
      return;
    }
    await vSafeApiCall(
      onLoading: () {
        setState(() => _loading = true);
      },
      request: () => _svc.createVideoPost(
        file: _video!,
        caption:
            _caption.text.trim().isNotEmpty ? _caption.text.trim() : null,
      ),
      onSuccess: (_) {
        if (mounted) {
          setState(() => _loading = false);
          PostApiService.notifySocialFeedRefresh();
          Navigator.of(context).pop(true);
        }
      },
      onError: (e, _) {
        setState(() => _loading = false);
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PostCaptionEditor(
                    controller: _caption,
                    textColor: widget.fg,
                    placeholderColor: widget.fg.withValues(alpha: 0.4),
                    highlightColor: _kPrimary,
                    decoration: BoxDecoration(
                      color: widget.cardBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel('Video (1 max)', widget.fg),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pick,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: widget.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _kPrimary.withValues(alpha: 0.3),
                            width: 2),
                      ),
                      child: _video == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam,
                                    size: 56,
                                    color: _kPrimary.withValues(alpha: 0.6)),
                                const SizedBox(height: 8),
                                Text('Tap to select a video',
                                    style: TextStyle(
                                        color:
                                            widget.fg.withValues(alpha: 0.5))),
                              ],
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                const Icon(Icons.play_circle_fill,
                                    color: Colors.white, size: 56),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    child: Text(
                                      _video!.name,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _video = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ]),
          ),
        ),
        _PostButton(loading: _loading, onTap: _post),
      ]),
    );
  }
}

// ─── Reel Post Tab ────────────────────────────────────────────────────────────

class _ReelPostTab extends StatefulWidget {
  final Color bg, cardBg, fg;
  const _ReelPostTab(
      {required this.bg, required this.cardBg, required this.fg});

  @override
  State<_ReelPostTab> createState() => _ReelPostTabState();
}

class _ReelPostTabState extends State<_ReelPostTab> {
  final _caption = TextEditingController();
  final _svc = GetIt.I.get<PostApiService>();
  final _picker = ImagePicker();
  VPlatformFile? _reel;
  bool _loading = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await _pickAndTrimVideo(context, _picker);
    if (!mounted || result == null) return;
    setState(() => _reel = result);
  }

  Future<void> _post() async {
    if (_reel == null) {
      VAppAlert.showErrorSnackBar(
          context: context, message: 'Pick a reel video');
      return;
    }
    await vSafeApiCall(
      onLoading: () {
        setState(() => _loading = true);
      },
      request: () => _svc.createReelPost(
        file: _reel!,
        caption:
            _caption.text.trim().isNotEmpty ? _caption.text.trim() : null,
      ),
      onSuccess: (_) {
        if (mounted) {
          setState(() => _loading = false);
          PostApiService.notifySocialFeedRefresh();
          Navigator.of(context).pop(true);
        }
      },
      onError: (e, _) {
        setState(() => _loading = false);
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reel tips chip row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _Chip('Vertical 9:16', Icons.smartphone),
                      _Chip('Unlimited duration', Icons.timer),
                      _Chip('HD video', Icons.hd),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  PostCaptionEditor(
                    controller: _caption,
                    textColor: widget.fg,
                    placeholderColor: widget.fg.withValues(alpha: 0.4),
                    highlightColor: _kPrimary,
                    decoration: BoxDecoration(
                      color: widget.cardBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel('Reel Video', widget.fg),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pick,
                    child: Container(
                      height: 260,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: widget.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _kPrimary.withValues(alpha: 0.4),
                            width: 2),
                      ),
                      child: _reel == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.movie_creation,
                                    size: 60,
                                    color:
                                    _kPrimary.withValues(alpha: 0.6)),
                                const SizedBox(height: 12),
                                Text('Tap to select your reel',
                                    style: TextStyle(
                                        color:
                                            widget.fg.withValues(alpha: 0.5),
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text('Vertical portrait video recommended',
                                    style: TextStyle(
                                        color:
                                            widget.fg.withValues(alpha: 0.3),
                                        fontSize: 12)),
                              ],
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                    decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                const Icon(Icons.play_circle_fill,
                                  color: _kPrimary, size: 72),
                                Positioned(
                                  bottom: 12,
                                  left: 12,
                                  right: 12,
                                  child: Text(
                                    _reel!.name,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _reel = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ]),
          ),
        ),
        _PostButton(
            loading: _loading,
            onTap: _post,
            label: 'Publish Reel',
            color: _kPrimary),
      ]),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color fg;
  const _SectionLabel(this.text, this.fg);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            color: fg, fontWeight: FontWeight.w600, fontSize: 15));
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: _kPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kPrimary.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: _kPrimary),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: _kPrimary, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _PostButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  final String label;
  final Color color;

  const _PostButton({
    required this.loading,
    required this.onTap,
    this.label = 'Post',
    this.color = _kPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: loading ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: color.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                        CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
