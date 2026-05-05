import 'package:flutter/material.dart';

/// A widget that displays a picker for emoji reactions
class EmojiReactionPicker extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;
  final VoidCallback? onCancel;

  const EmojiReactionPicker({
    super.key,
    required this.onEmojiSelected,
    this.onCancel,
  });

  // Common emoji reactions for stories
  static const List<String> _commonEmojis = [
    '❤️', // Love/Like
    '😂', // Laugh
    '😮', // Wow/Surprised
    '😢', // Sad
    '😡', // Angry
    '👍', // Thumbs up
    '🔥', // Fire/Hot
    '💯', // 100/Perfect
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          const Text(
            'React to story',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Emoji grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _commonEmojis.map((emoji) {
              return _buildEmojiButton(emoji);
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Cancel button
          GestureDetector(
            onTap: onCancel,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiButton(String emoji) {
    return GestureDetector(
      onTap: () => onEmojiSelected(emoji),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}

/// A simple overlay widget to show the emoji picker
class EmojiReactionOverlay extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;
  final VoidCallback onCancel;

  const EmojiReactionOverlay({
    super.key,
    required this.onEmojiSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onCancel,
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent dismissing when tapping the picker
              child: EmojiReactionPicker(
                onEmojiSelected: onEmojiSelected,
                onCancel: onCancel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
