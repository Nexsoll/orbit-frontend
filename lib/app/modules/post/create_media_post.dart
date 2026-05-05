import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'post_caption_editor.dart';

class CreateMediaPost extends StatefulWidget {
  final PostType postType;
  final String? initialCaption;

  const CreateMediaPost({
    super.key,
    required this.postType,
    this.initialCaption,
  });

  @override
  State<CreateMediaPost> createState() => _CreateMediaPostState();
}

class _CreateMediaPostState extends State<CreateMediaPost> {
  final _postApiService = GetIt.I.get<PostApiService>();
  final _captionController = TextEditingController();
  final _imagePicker = ImagePicker();

  VPlatformFile? _selectedFile;
  VPlatformFile? _thumbnailFile;
  bool _isUploading = false;
  bool _isReel = false;

  @override
  void initState() {
    super.initState();
    _isReel = widget.postType == PostType.reel;
    if (widget.initialCaption != null) {
      _captionController.text = widget.initialCaption!;
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    if (widget.postType == PostType.image || widget.postType == PostType.reel) {
      final result = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (result != null) {
        setState(() {
          _selectedFile = VPlatformFile.fromPath(fileLocalPath: result.path);
        });
      }
    } else if (widget.postType == PostType.video) {
      final result = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (result != null) {
        setState(() {
          _selectedFile = VPlatformFile.fromPath(fileLocalPath: result.path);
        });
      }
    }
  }

  Future<void> _pickFromCamera() async {
    if (widget.postType == PostType.image || widget.postType == PostType.reel) {
      final result = await _imagePicker.pickImage(source: ImageSource.camera);
      if (result != null) {
        setState(() {
          _selectedFile = VPlatformFile.fromPath(fileLocalPath: result.path);
        });
      }
    } else if (widget.postType == PostType.video) {
      final result = await _imagePicker.pickVideo(source: ImageSource.camera);
      if (result != null) {
        setState(() {
          _selectedFile = VPlatformFile.fromPath(fileLocalPath: result.path);
        });
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _selectedFile = VPlatformFile.fromPath(fileLocalPath: file.path!);
      });
    }
  }

  void _showMediaSourceSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text(
          'Select Media',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              context.pop();
              _pickFromGallery();
            },
            child: const Row(
              children: [
                Icon(Icons.photo_library, color: Color(0xFFB48648)),
                SizedBox(width: 12),
                Text('Gallery'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              context.pop();
              _pickFromCamera();
            },
            child: const Row(
              children: [
                Icon(Icons.camera_alt, color: Color(0xFFB48648)),
                SizedBox(width: 12),
                Text('Camera'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              context.pop();
              _pickFile();
            },
            child: const Row(
              children: [
                Icon(Icons.attach_file, color: Color(0xFFB48648)),
                SizedBox(width: 12),
                Text('Files'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => context.pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _submitPost() async {
    if (_selectedFile == null) return;

    final caption = _captionController.text.trim();

    await vSafeApiCall(
      onLoading: () {
        setState(() => _isUploading = true);
        VAppAlert.showLoading(
          context: context,
          message: 'Uploading ${_isReel ? 'reel' : widget.postType.name}...',
        );
      },
      request: () async {
        await _postApiService.createMediaPost(
          postType: widget.postType,
          file: _selectedFile!,
          caption: caption.isNotEmpty ? caption : null,
          thumbnail: _thumbnailFile,
          isReel: _isReel,
        );
      },
      onSuccess: (_) async {
        context.pop();
        context.pop();
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Post created successfully',
        );
      },
      onError: (exception, _) {
        context.pop();
        setState(() => _isUploading = false);
        VAppAlert.showErrorSnackBar(
          context: context,
          message: exception.toString(),
        );
      },
    );
  }

  Widget _buildMediaPreview() {
    if (_selectedFile == null) {
      return GestureDetector(
        onTap: _showMediaSourceSheet,
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF333333),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.postType == PostType.image
                    ? Icons.photo_library_outlined
                    : widget.postType == PostType.reel
                        ? Icons.movie_outlined
                        : Icons.videocam_outlined,
                size: 64,
                color: const Color(0xFFB48648),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tap to select media',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: VPlatformCacheImageWidget(
              source: _selectedFile!,
              size: const Size(double.infinity, 300),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedFile = null;
                _thumbnailFile = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.clear,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _sourceLabel {
    switch (widget.postType) {
      case PostType.image:
        return 'Photo';
      case PostType.video:
        return 'Video';
      case PostType.reel:
        return 'Reel';
      default:
        return 'Media';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF1A1A1A),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF333333)),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: const Icon(CupertinoIcons.clear, color: Colors.white),
        ),
        middle: Text(
          'Create $_sourceLabel',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMediaPreview(),
                    const SizedBox(height: 16),
                    if (_selectedFile != null) ...[
                      PostCaptionEditor(
                        controller: _captionController,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF333333)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        _buildSourceButton(
                          icon: Icons.photo_library,
                          label: 'Gallery',
                          onTap: _pickFromGallery,
                        ),
                        const SizedBox(width: 12),
                        _buildSourceButton(
                          icon: Icons.camera_alt,
                          label: 'Camera',
                          onTap: _pickFromCamera,
                        ),
                        const SizedBox(width: 12),
                        _buildSourceButton(
                          icon: Icons.attach_file,
                          label: 'Files',
                          onTap: _pickFile,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(
                  top: BorderSide(color: Color(0xFF333333)),
                ),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    color: _selectedFile == null || _isUploading
                        ? const Color(0xFFB48648).withOpacity(0.5)
                        : const Color(0xFFB48648),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: _selectedFile == null || _isUploading
                        ? null
                        : _submitPost,
                    child: _isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Post $_sourceLabel',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 10),
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFB48648)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
