// Copyright 2025, Orbit app.
// Custom image cropper page with bottom confirm/cancel actions.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

class AppImageCropper {
  static Future<VPlatformFile?> pickAndCrop(
    BuildContext context, {
    bool isFromCamera = false,
  }) async {
    // Pick image first using the existing cross-platform picker
    final picked = await VAppPick.getImage(isFromCamera: isFromCamera);
    if (picked == null) return null;

    final bytes = await _readBytes(picked);
    if (bytes == null) return null;

    final dynamic croppedPayload = await context.toPage(
      _CustomImageCropPage(imageBytes: bytes),
      withAnimation: true,
    );
    final Uint8List? croppedBytes = extractCroppedBytes(croppedPayload);

    if (croppedBytes == null) return null;

    // Persist to temporary file and return as VPlatformFile
    try {
      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final f = File(filePath);
      await f.writeAsBytes(croppedBytes, flush: true);
      return VPlatformFile.fromPath(fileLocalPath: f.path);
    } catch (e) {
      // Return bytes directly if file writing fails (can happen on some Android devices)
      return VPlatformFile.fromBytes(name: 'cropped_profile.jpg', bytes: croppedBytes);
    }
  }

  // Extract raw bytes from crop_your_image v2 result objects or plain Uint8List.
  static Uint8List? extractCroppedBytes(dynamic data) {
    if (data == null) return null;
    if (data is Uint8List) return data;
    try {
      final dynamic v = (data as dynamic).croppedImage;
      if (v is Uint8List) return v;
    } catch (_) {}
    try {
      final dynamic v = (data as dynamic).image;
      if (v is Uint8List) return v;
    } catch (_) {}
    try {
      final dynamic v = (data as dynamic).bytes;
      if (v is Uint8List) return v;
    } catch (_) {}
    return null;
  }

  static Future<Uint8List?> _readBytes(VPlatformFile file) async {
    try {
      if (file.bytes != null) return Uint8List.fromList(file.bytes!);
      if (file.fileLocalPath != null) {
        return await File(file.fileLocalPath!).readAsBytes();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _CustomImageCropPage extends StatefulWidget {
  final Uint8List imageBytes;

  const _CustomImageCropPage({required this.imageBytes});

  @override
  State<_CustomImageCropPage> createState() => _CustomImageCropPageState();
}

class _CustomImageCropPageState extends State<_CustomImageCropPage> {
  final _controller = CropController();
  double? _aspectRatio; // null = original

  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Crop area
            Positioned.fill(
              child: Center(
                child: Crop(
                  image: widget.imageBytes,
                  controller: _controller,
                  // show grid similar to native cropper
                  withCircleUi: false,
                  onCropped: (result) {
                    final bytes = AppImageCropper.extractCroppedBytes(result);
                    if (bytes != null) {
                      Navigator.of(context).pop(bytes);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  baseColor: Colors.black,
                  maskColor: Colors.black.withOpacity(0.5),
                  aspectRatio: _aspectRatio, // null = original
                ),
              ),
            ),

            // Bottom controls: actions then ratio tabs
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Actions row (Cancel / Done)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark),
                          color: Colors.white,
                          onPressed: _isCropping
                              ? null
                              : () => Navigator.of(context).pop(),
                          tooltip: 'Cancel',
                        ),
                        const Spacer(),
                        IconButton(
                          icon: _isCropping
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(CupertinoIcons.check_mark),
                          color: Colors.white,
                          onPressed: _isCropping
                              ? null
                              : () {
                                  setState(() => _isCropping = true);
                                  // Trigger cropping; result delivered via onCropped callback above
                                  _controller.crop();
                                },
                          tooltip: 'Done',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Aspect ratio chips similar to native tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _ratioChip('Original', null),
                          _ratioChip('square', 1 / 1),
                          _ratioChip('3x2', 3 / 2),
                          _ratioChip('4x3', 4 / 3),
                          _ratioChip('16x9', 16 / 9),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratioChip(String label, double? ratio) {
    final isSelected = _aspectRatio == ratio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
        selectedColor: const Color(0xFFc9cfc8),
        backgroundColor: Colors.black45,
        onSelected: (_) => setState(() => _aspectRatio = ratio),
      ),
    );
  }
}

/// App-level image picker widget that uses the custom cropper.
class AppImagePicker extends StatefulWidget {
  final bool withCrop;
  final bool isFromCamera;
  final void Function(VPlatformFile file) onDone;
  final int size;
  final VPlatformFile initImage;

  const AppImagePicker({
    super.key,
    this.withCrop = true,
    this.isFromCamera = false,
    required this.onDone,
    required this.initImage,
    this.size = 70,
  });

  @override
  State<AppImagePicker> createState() => _AppImagePickerState();
}

class _AppImagePickerState extends State<AppImagePicker> {
  late VPlatformFile current;

  @override
  void initState() {
    super.initState();
    current = widget.initImage;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size.toDouble(),
      width: widget.size.toDouble(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          VPlatformCacheImageWidget(
            source: current,
            borderRadius: BorderRadius.circular(130),
            fit: BoxFit.cover,
            size: Size.fromHeight(widget.size.toDouble()),
          ),
          PositionedDirectional(
            bottom: 1,
            end: 1,
            child: GestureDetector(
              onTap: _getImage,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.black87,
                  size: 19,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _getImage() async {
    if (!mounted) return;
    if (!widget.withCrop) {
      final image = await VAppPick.getImage(
        isFromCamera: widget.isFromCamera,
      );
      if (image == null) return;
      setState(() => current = image);
      widget.onDone(image);
      return;
    }
    final image = await AppImageCropper.pickAndCrop(
      context,
      isFromCamera: widget.isFromCamera,
    );
    if (image == null) return;
    if (!mounted) return;
    setState(() => current = image);
    widget.onDone(image);
  }
}
