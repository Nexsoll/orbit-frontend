import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class CreatePostBottomSheet extends StatefulWidget {
  const CreatePostBottomSheet({super.key});

  @override
  State<CreatePostBottomSheet> createState() => _CreatePostBottomSheetState();
}

class _CreatePostBottomSheetState extends State<CreatePostBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Create Post',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          _buildOption(
            context,
            icon: Icons.text_fields,
            title: 'Text Post',
            subtitle: 'Share your thoughts',
            onTap: () => Navigator.pop(context, 'text'),
          ),
          _buildOption(
            context,
            icon: Icons.photo_library,
            title: 'Photo',
            subtitle: 'Share a photo',
            onTap: () => Navigator.pop(context, 'image'),
          ),
          _buildOption(
            context,
            icon: Icons.videocam,
            title: 'Video',
            subtitle: 'Share a video',
            onTap: () => Navigator.pop(context, 'video'),
          ),
          _buildOption(
            context,
            icon: Icons.movie,
            title: 'Reel',
            subtitle: 'Create a short video',
            onTap: () => Navigator.pop(context, 'reel'),
          ),
          _buildOption(
            context,
            icon: Icons.location_on,
            title: 'Location',
            subtitle: 'Add a location',
            onTap: () => Navigator.pop(context, 'location'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFFB48648)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
