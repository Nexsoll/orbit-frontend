import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/modules/post/post_feed_widget.dart';
import 'package:super_up/app/widgets/custom_circle_avatar.dart';
import 'package:super_up_core/super_up_core.dart';

class PostShareMessageWidget extends StatelessWidget {
  final bool isMeSender;
  final Map<String, dynamic> data;

  const PostShareMessageWidget({
    super.key,
    required this.isMeSender,
    required this.data,
  });

  String get _postId => (data['postId'] ?? '').toString();
  String get _caption => (data['caption'] ?? '').toString();
  String get _authorName => (data['authorName'] ?? '').toString();
  String get _authorImage => (data['authorImage'] ?? '').toString();
  String get _mediaUrl => (data['mediaUrl'] ?? '').toString();
  String get _thumbnailUrl => (data['thumbnailUrl'] ?? '').toString();
  String get _postType => (data['postType'] ?? 'image').toString();
  String get _placeName => (data['placeName'] ?? '').toString();
  String get _address => (data['address'] ?? '').toString();
  String get _latitude => (data['latitude'] ?? '').toString();
  String get _longitude => (data['longitude'] ?? '').toString();

  String _deriveCloudinaryThumb(String url) {
    if (url.isEmpty || !url.startsWith('http')) return '';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains('res.cloudinary.com')) return '';
    final path = uri.path;
    const upload = '/upload/';
    final idx = path.indexOf(upload);
    if (idx == -1) return '';
    final prefix = '${uri.scheme}://${uri.host}${path.substring(0, idx + upload.length)}';
    final tail = path.substring(idx + upload.length).replaceFirst(RegExp(r'^/+'), '');
    final jpgTail = tail.replaceFirst(RegExp(r'\.[^./]+$'), '.jpg');
    return '${prefix}so_1,w_640,h_360,c_fill,f_jpg/$jpgTail';
  }

  String get _displayImage {
    final isVideo = _postType == 'video' || _postType == 'reel';
    final thumb = isVideo
        ? (_thumbnailUrl.isNotEmpty
            ? _thumbnailUrl
            : _deriveCloudinaryThumb(_mediaUrl))
        : (_thumbnailUrl.isNotEmpty ? _thumbnailUrl : _mediaUrl);
    if (thumb.isEmpty) return '';
    return thumb.startsWith('http') ? thumb : '${SConstants.baseMediaUrl}$thumb';
  }

  Future<void> _openPost(BuildContext context) async {
    if (_postId.isEmpty) return;
    VAppAlert.showLoading(context: context);
    try {
      final api = GetIt.I.get<PostApiService>();
      final post = await api.getPostById(_postId);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => _SinglePostPage(post: post),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        VAppAlert.showErrorSnackBar(
            context: context, message: 'Could not load post');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _displayImage;
    final hasImage = thumb.isNotEmpty;
    final isReel = _postType == 'reel';
    final isVideo = _postType == 'video' || isReel;
    final isLocation = _postType == 'location';

    String headerLabel;
    IconData headerIcon;
    if (isLocation) {
      headerLabel = 'Shared a Location';
      headerIcon = CupertinoIcons.map_pin_ellipse;
    } else if (isReel) {
      headerLabel = 'Shared a Reel';
      headerIcon = CupertinoIcons.square_grid_2x2;
    } else if (_postType == 'video') {
      headerLabel = 'Shared a Video';
      headerIcon = CupertinoIcons.videocam_fill;
    } else {
      headerLabel = 'Shared a Post';
      headerIcon = CupertinoIcons.square_grid_2x2;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPost(context),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB48648).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header label
            Row(
              children: [
                Icon(headerIcon, size: 14, color: const Color(0xFFB48648)),
                const SizedBox(width: 4),
                Text(
                  headerLabel,
                  style: const TextStyle(
                    color: Color(0xFFB48648),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Media area
            if (isLocation)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB48648).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      CupertinoIcons.map_pin,
                      color: Color(0xFFB48648),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_placeName.isNotEmpty)
                            Text(
                              _placeName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          if (_address.isNotEmpty)
                            Text(
                              _address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          if (_address.isEmpty &&
                              _latitude.isNotEmpty &&
                              _longitude.isNotEmpty)
                            Text(
                              '${_latitude}, ${_longitude}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          if (_placeName.isEmpty && _address.isEmpty)
                            Text(
                              (_latitude.isNotEmpty && _longitude.isNotEmpty)
                                  ? '${_latitude}, ${_longitude}'
                                  : 'Location',
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
              )
            else if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Image.network(
                      thumb,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        height: 140,
                        color: const Color(0xFFB48648).withOpacity(0.1),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.photo,
                            color: Color(0xFFB48648),
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    if (isVideo)
                      const Positioned.fill(
                        child: Center(
                          child: Icon(
                            CupertinoIcons.play_circle_fill,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFB48648).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    isVideo
                        ? CupertinoIcons.play_rectangle
                        : CupertinoIcons.text_alignleft,
                    color: const Color(0xFFB48648),
                    size: 28,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Caption
            if (_caption.isNotEmpty)
              Text(
                _caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            const SizedBox(height: 6),
            // Author row
            Row(
              children: [
                CustomCircleAvatar(
                  radius: 10,
                  imageUrl: _authorImage,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _authorName.isEmpty ? 'View post' : _authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: Color(0xFFB48648),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Minimal single-post viewer screen used when tapping a shared post card
class _SinglePostPage extends StatelessWidget {
  final dynamic post;
  const _SinglePostPage({required this.post});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Post'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: PostFeedWidget(post: post),
        ),
      ),
    );
  }
}
