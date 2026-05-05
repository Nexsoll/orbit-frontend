// Copyright 2025, Orbit Chat
// ChatThemePickerPage: choose a prebuilt chat background theme for a room

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class ChatThemePickerPage extends StatefulWidget {
  const ChatThemePickerPage({
    super.key,
    required this.roomId,
    this.peerId,
  });

  final String roomId;
  final String? peerId;

  @override
  State<ChatThemePickerPage> createState() => _ChatThemePickerPageState();
}

class _ChatThemePickerPageState extends State<ChatThemePickerPage> {
  // Asset paths for bundled themes
  static const List<String> _themes = [
    'assets/chat_themes/theme1.jpeg',
    'assets/chat_themes/theme2.jpeg',
    'assets/chat_themes/theme3.jpeg',
    'assets/chat_themes/theme4.jpeg',
    'assets/chat_themes/theme5.jpeg',
  ];

  String? _selectedPath;
  late final _prefs = VChatController.I.sharedPreferences;

  String get _roomKey => 'chat_theme_asset_room_${widget.roomId}';
  String? get _peerKey => widget.peerId == null ? null : 'chat_theme_asset_peer_${widget.peerId}';

  @override
  void initState() {
    super.initState();
    _loadSelected();
  }

  Future<void> _loadSelected() async {
    var path = _prefs.getString(_roomKey);
    path ??= _peerKey == null ? null : _prefs.getString(_peerKey!);
    setState(() => _selectedPath = path);
  }

  Future<void> _applyTheme(String? assetPath) async {
    if (assetPath == null || assetPath.isEmpty) {
      await _prefs.remove(_roomKey);
      if (_peerKey != null) await _prefs.remove(_peerKey!);
    } else {
      await _prefs.setString(_roomKey, assetPath);
      if (_peerKey != null) await _prefs.setString(_peerKey!, assetPath);
    }
    // Notify open chat (if any) to refresh background instantly
    VEventBusSingleton.vEventBus
        .fire(VUpdateRoomWallpaperEvent(roomId: widget.roomId));
    if (mounted) {
      setState(() => _selectedPath = assetPath);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Chat theme'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _applyTheme(null),
          child: const Text('Reset'),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 9 / 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final asset = _themes[index];
                    final isSelected = asset == _selectedPath;
                    return _ThemeTile(
                      assetPath: asset,
                      isSelected: isSelected,
                      onTap: () => _applyTheme(asset),
                    );
                  },
                  childCount: _themes.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: CupertinoButton.filled(
                  onPressed: () => _applyTheme(null),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: const Text('Use default'),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
  });

  final String assetPath;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background preview
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
            ),
            // Subtle gradient overlay for readability
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 60,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black38,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Selected check
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white70, width: 1),
                  ),
                  child: const Icon(
                    CupertinoIcons.check_mark,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
