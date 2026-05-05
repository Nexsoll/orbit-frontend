import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up_core/super_up_core.dart';

class PostPhotoDeleteScreen extends StatefulWidget {
  final PostModel post;

  const PostPhotoDeleteScreen({super.key, required this.post});

  @override
  State<PostPhotoDeleteScreen> createState() => _PostPhotoDeleteScreenState();
}

class _PostPhotoDeleteScreenState extends State<PostPhotoDeleteScreen> {
  final List<String> _selectedUrls = [];
  final _postApiService = GetIt.I.get<PostApiService>();

  void _toggleSelection(String url) {
    setState(() {
      if (_selectedUrls.contains(url)) {
        _selectedUrls.remove(url);
      } else {
        _selectedUrls.add(url);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedUrls.isEmpty) return;

    final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Delete Photos'),
            content: Text('Are you sure you want to delete ${_selectedUrls.length} selected photos?'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    VAppAlert.showLoading(context: context);
    try {
      final remainingUrls = widget.post.mediaUrls.where((url) => !_selectedUrls.contains(url)).toList();
      
      if (remainingUrls.isEmpty) {
        // If all photos are removed, delete the post or set to placeholder.
        // Platform policy: treat as deleted.
        await _postApiService.deletePost(widget.post.id);
        if (!mounted) return;
        Navigator.of(context).pop(); // pop loading
        Navigator.of(context).pop('deleted'); // pop screen with deleted signal
        return;
      }

      final Map<String, dynamic> updateBody = {
        'mediaUrls': remainingUrls,
        'media': {
          ...(widget.post.media?.toMap() ?? {}),
          'url': remainingUrls.first,
        },
      };

      await _postApiService.updatePost(widget.post.id, updateBody);

      final updatedPost = await _postApiService.getPostById(widget.post.id);

      if (!mounted) return;
      Navigator.of(context).pop(); // pop loading
      Navigator.of(context).pop(updatedPost); // pop screen with updated post
      
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Photos deleted successfully',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // pop loading
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Failed to delete photos: ${e.toString()}',
      );
    }
  }

  String _resolveMediaUrl(String raw) {
    if (raw.isEmpty) return raw;
    return raw.startsWith('http') ? raw : '${SConstants.baseMediaUrl}$raw';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Selected Photos'),
        actions: [
          if (_selectedUrls.isNotEmpty)
            TextButton(
              onPressed: _deleteSelected,
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: widget.post.mediaUrls.length,
        itemBuilder: (context, index) {
          final url = widget.post.mediaUrls[index];
          final resolvedUrl = _resolveMediaUrl(url);
          final isSelected = _selectedUrls.contains(url);

          return GestureDetector(
            onTap: () => _toggleSelection(url),
            child: Semantics(
              label: 'Photo ${index + 1}${isSelected ? ', selected' : ''}',
              selected: isSelected,
              button: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: resolvedUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey.shade200),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.error_outline),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.check_circle, color: Colors.white, size: 32),
                      ),
                    )
                  else
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.circle_outlined, color: Colors.white, size: 24),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
