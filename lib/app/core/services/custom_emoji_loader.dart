import 'dart:convert';
import 'package:flutter/services.dart' as services;
import 'package:v_chat_input_ui/v_chat_input_ui.dart';
import 'package:v_platform/v_platform.dart';

/// Loads bundled asset emojis (webp/png/jpg/gif) from `assets/custom_emojis/`
/// into a dynamic sticker pack so they appear under Stickers → My.
class CustomEmojiLoader {
  static bool _loaded = false;

  static Future<void> loadOrbitEmojis() async {
    // No-op: Emojis are now loaded directly from Cloudinary URLs static config
    _loaded = true;
  }
}
