import 'dart:convert';
import 'package:flutter/services.dart' as services;
import 'package:v_chat_input_ui/v_chat_input_ui.dart';
import 'package:v_platform/v_platform.dart';

/// Loads bundled asset emojis (webp/png/jpg/gif) from `assets/custom_emojis/`
/// into a dynamic sticker pack so they appear under Stickers → My.
class CustomEmojiLoader {
  static bool _loaded = false;

  static Future<void> loadOrbitEmojis() async {
    if (_loaded) return;

    // Dynamic sticker storage is not supported on web yet in our manager
    if (VPlatforms.isWeb) {
      _loaded = true;
      return;
    }

    try {
      // Read the Flutter asset manifest and filter our emoji assets
      var emojiAssets = <String>[];

      try {
        final manifest =
            await services.AssetManifest.loadFromAssetBundle(services.rootBundle);
        final assets = await manifest.listAssets();
        emojiAssets = assets
            .where((k) => k.startsWith('assets/custom_emojis/'))
            .where((k) {
              final lower = k.toLowerCase();
              return lower.endsWith('.webp') ||
                  lower.endsWith('.png') ||
                  lower.endsWith('.jpg') ||
                  lower.endsWith('.jpeg') ||
                  lower.endsWith('.gif');
            })
            .toList();
      } catch (_) {}

      // Fallback for older Flutter builds
      if (emojiAssets.isEmpty) {
        try {
          final manifestRaw =
              await services.rootBundle.loadString('AssetManifest.json');
          final Map<String, dynamic> manifest = jsonDecode(manifestRaw);
          emojiAssets = manifest.keys
              .where((k) => k.startsWith('assets/custom_emojis/'))
              .where((k) {
                final lower = k.toLowerCase();
                return lower.endsWith('.webp') ||
                    lower.endsWith('.png') ||
                    lower.endsWith('.jpg') ||
                    lower.endsWith('.jpeg') ||
                    lower.endsWith('.gif');
              })
              .toList();
        } catch (_) {}
      }

      emojiAssets.sort();

      if (emojiAssets.isEmpty) {
        _loaded = true;
        return;
      }

      final files = <VPlatformFile>[];
      for (final asset in emojiAssets) {
        final byteData = await services.rootBundle.load(asset);
        final bytes = byteData.buffer.asUint8List().toList();
        final name = asset.split('/').last;
        files.add(VPlatformFile.fromBytes(bytes: bytes, name: name));
      }

      // Recreate the pack each run to stay in sync with bundled assets
      await DynamicStickerManager.removeStickerPack('orbit_emojis');
      await DynamicStickerManager.addStickersToPackFromPlatformFiles(
        packName: 'orbit_emojis',
        stickerFiles: files,
      );

      _loaded = true;
    } catch (e) {
      // Silently ignore; emoji pack is optional
      // print('CustomEmojiLoader error: $e');
    }
  }
}
