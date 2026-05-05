import 'package:flutter/material.dart';
import 'package:v_chat_input_ui/v_chat_input_ui.dart';

/// Widget to display sticker messages in chat
class StickerMessageWidget extends StatelessWidget {
  final bool isMeSender;
  final Map<String, dynamic> data;

  const StickerMessageWidget({
    super.key,
    required this.isMeSender,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = data['assetPath'] as String?;
    final stickerName = data['name'] as String?;
    final emoji = data['emoji'] as String?;
    final stickerId = data['stickerId'] as String?;
    final packId = data['stickerPackId'] as String?;

    if (stickerName == null) {
      return _invalidSticker();
    }

    // Resolve the real sticker from local packs using id/pack when possible
    return FutureBuilder<List<VStickerPack>>(
      future: _loadAllPacks(),
      builder: (context, snapshot) {
        VSticker? resolved;
        final packs = snapshot.data;
        if (packs != null) {
          // Try to find by id and/or pack
          for (final p in packs) {
            if (packId != null && p.id != packId) continue;
            for (final s in p.stickers) {
              if (stickerId != null && s.id == stickerId) {
                resolved = s;
                break;
              }
            }
            if (resolved != null) break;
          }
        }

        // Fallback to message-provided assetPath
        resolved ??= VSticker(
          id: stickerId ?? (assetPath ?? stickerName),
          name: stickerName,
          assetPath: assetPath ?? '',
          emoji: emoji,
        );

        return GestureDetector(
          onTap: () => _showStickerDetails(context),
          child: ChatStickerWidget(
            sticker: resolved,
            size: 120,
          ),
        );
      },
    );
  }

  Future<List<VStickerPack>> _loadAllPacks() async {
    final defaultPacks = VStickerData.getDefaultStickerPacks();
    final dynamicPacks = await DynamicStickerManager.getDynamicStickerPacks();
    return [...defaultPacks, ...dynamicPacks];
  }

  Widget _invalidSticker() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Invalid sticker',
        style: TextStyle(
          color: Colors.red,
          fontSize: 14,
        ),
      ),
    );
  }

  void _showStickerDetails(BuildContext context) {
    final stickerName = data['name'] as String?;

    if (stickerName != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sticker: $stickerName'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}
