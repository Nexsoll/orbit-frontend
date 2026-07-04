import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/models/storage/user_file_model.dart';
import 'package:super_up/app/core/services/user_files_service.dart';
import 'package:super_up/app/modules/music/views/music_video_player_page.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:video_player/video_player.dart';

class PrivateMediaGalleryPage extends StatefulWidget {
  const PrivateMediaGalleryPage({super.key});

  @override
  State<PrivateMediaGalleryPage> createState() =>
      _PrivateMediaGalleryPageState();
}

class _PrivateMediaGalleryPageState extends State<PrivateMediaGalleryPage> {
  final List<UserFileModel> _items = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final items = await UserFilesService.getPrivateMedia(
        page: 1,
        limit: 200,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      VAppAlert.showOkAlertDialog(
        context: context,
        title: 'Error',
        content: 'Failed to load private media: $e',
      );
    }
  }

  Future<void> _upload() async {
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Upload Private Media'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'media'),
            child: const Text('Photos & Videos'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'files'),
            child: const Text('Documents & Files'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (result == null) return;

    List<VPlatformFile>? files;
    if (result == 'media') {
      files = await VAppPick.getMedia();
    } else {
      files = await VAppPick.getFiles();
    }

    if (files == null || files.isEmpty) return;

    setState(() => _uploading = true);
    VAppAlert.showLoading(context: context);
    try {
      final uploaded = await UserFilesService.uploadPrivateMedia(files);
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _items.insertAll(0, uploaded);
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _uploading = false);
      VAppAlert.showOkAlertDialog(
        context: context,
        title: 'Upload Error',
        content: 'Failed to upload private media: $e',
      );
    }
  }

  Future<void> _delete(UserFileModel item) async {
    final confirmed = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: 'Delete',
      content: 'Delete this private item?',
    );
    if (confirmed != 1) return;

    try {
      await UserFilesService.deletePrivateMedia(item.id);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((e) => e.id == item.id);
      });
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showOkAlertDialog(
        context: context,
        title: 'Error',
        content: 'Failed to delete private media: $e',
      );
    }
  }

  Future<void> _open(UserFileModel item) async {
    final url = _fullUrl(item.networkUrl ?? '');
    if (url.isEmpty) return;

    if (_isImage(item)) {
      context.toPage(
        VImageViewer(
          showDownload: false,
          platformFileSource: VPlatformFile.fromUrl(networkUrl: url),
          downloadingLabel: 'Downloading',
          successfullyDownloadedInLabel: 'Downloaded',
        ),
      );
      return;
    }

    if (_isVideo(item)) {
      context.toPage(
        MusicVideoPlayerPage(
          title: item.fileName,
          url: url,
        ),
      );
      return;
    }

    try {
      VAppAlert.showLoading(context: context);
      final result = await UserFilesService.downloadFile(item);
      if (!mounted) return;
      Navigator.of(context).pop();
      VAppAlert.showOkAlertDialog(
        context: context,
        title: 'Download Complete',
        content: result,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      VAppAlert.showOkAlertDialog(
        context: context,
        title: 'Download Error',
        content: 'Failed to download file: $e',
      );
    }
  }

  bool _isImage(UserFileModel item) =>
      item.fileType.toLowerCase() == 'image' ||
      (item.mimeType ?? '').toLowerCase().startsWith('image/');

  bool _isVideo(UserFileModel item) =>
      item.fileType.toLowerCase() == 'video' ||
      (item.mimeType ?? '').toLowerCase().startsWith('video/');

  String _fullUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    final apiBase = SConstants.sApiBaseUrl;
    final origin = Uri(
      scheme: apiBase.scheme,
      host: apiBase.host,
      port: apiBase.hasPort ? apiBase.port : null,
    );
    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
    return origin.resolve(normalized).toString();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Private Media'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _uploading ? null : _upload,
          child: _uploading
              ? const CupertinoActivityIndicator()
              : const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : RefreshIndicator(
                onRefresh: _loadItems,
                child: _items.isEmpty ? _emptyState() : _galleryGrid(),
              ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        const Icon(
          CupertinoIcons.lock_fill,
          size: 58,
          color: CupertinoColors.systemGrey3,
        ),
        const SizedBox(height: 16),
        const Text(
          'No private media yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.systemGrey,
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Upload photos, videos, and files here. Only you can view and delete them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: CupertinoButton.filled(
            onPressed: _uploading ? null : _upload,
            child: const Text('Upload'),
          ),
        ),
      ],
    );
  }

  Widget _galleryGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.72,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _PrivateMediaTile(
          item: item,
          url: _fullUrl(item.networkUrl ?? ''),
          isImage: _isImage(item),
          isVideo: _isVideo(item),
          onTap: () => _open(item),
          onDelete: () => _delete(item),
        );
      },
    );
  }
}

class _PrivateMediaTile extends StatelessWidget {
  final UserFileModel item;
  final String url;
  final bool isImage;
  final bool isVideo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PrivateMediaTile({
    required this.item,
    required this.url,
    required this.isImage,
    required this.isVideo,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _preview()),
          if (isVideo)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(
                    CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 28,
              onPressed: onDelete,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.delete,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          if (!isImage && !isVideo)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                item.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (isImage && url.isNotEmpty) {
      return VPlatformCacheImageWidget(
        source: VPlatformFile.fromUrl(networkUrl: url),
        fit: BoxFit.cover,
      );
    }

    if (isVideo && url.isNotEmpty) {
      return _PrivateVideoThumb(url: url);
    }

    return Container(
      color: const Color(0xFF2C2C2E),
      child: const Center(
        child: Icon(
          CupertinoIcons.doc_text_fill,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

class _PrivateVideoThumb extends StatefulWidget {
  final String url;

  const _PrivateVideoThumb({required this.url});

  @override
  State<_PrivateVideoThumb> createState() => _PrivateVideoThumbState();
}

class _PrivateVideoThumbState extends State<_PrivateVideoThumb> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _PrivateVideoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
      _init();
    }
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      _controller = controller;
      await controller.initialize();
      await controller.setVolume(0);
      await controller.pause();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(
            CupertinoIcons.videocam_fill,
            color: Colors.white70,
            size: 34,
          ),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
