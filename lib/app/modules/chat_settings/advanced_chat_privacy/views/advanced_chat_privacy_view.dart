// Copyright 2025, the Orbit Chat project authors.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/modules/chat_settings/widgets/chat_settings_navigation_bar.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class AdvancedChatPrivacyView extends StatefulWidget {
  const AdvancedChatPrivacyView({
    super.key,
    required this.roomId,
    this.initialEnabled = false,
  });

  final String roomId;
  final bool initialEnabled;

  @override
  State<AdvancedChatPrivacyView> createState() => _AdvancedChatPrivacyViewState();
}

class _AdvancedChatPrivacyViewState extends State<AdvancedChatPrivacyView> {
  bool _enabled = false;
  bool _loading = false;
  String get _prefsKey => 'acp_room_${_roomId}';
  String get _roomId => widget.roomId;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() => _loading = true);
    try {
      // Try backend first
      final server = await VChatController.I.roomApi
          .getAdvancedPrivacyEnabled(roomId: _roomId);
      _enabled = server;
      try {
        final prefs = VChatController.I.sharedPreferences;
        await prefs.setBool(_prefsKey, _enabled);
      } catch (_) {}
      if (mounted) setState(() {});
    } catch (_) {
      // Fallback to local persisted value
      try {
        final prefs = VChatController.I.sharedPreferences;
        final saved = prefs.getBool(_prefsKey);
        if (saved != null) {
          _enabled = saved;
          if (mounted) setState(() {});
        }
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _loading = true);
    try {
      await VChatController.I.roomApi
          .setAdvancedPrivacy(roomId: _roomId, enabled: value);
      setState(() => _enabled = value);

      // Persist locally so it stays ON when you come back
      try {
        final prefs = VChatController.I.sharedPreferences;
        await prefs.setBool(_prefsKey, _enabled);
      } catch (_) {}

      // Feedback
      if (mounted) {
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: _enabled
              ? 'Advanced chat privacy turned on'
              : 'Advanced chat privacy turned off',
        );
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Failed to update. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final scaffoldBg = theme.scaffoldBackgroundColor;
    final isDark = context.isDark;
    final titleColor = CupertinoColors.label.resolveFrom(context);
    final subColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final linkColor = theme.primaryColor;
    // Brand brown color requested
    const brandBrown = Color(0xFFB48648);
    // Make cards brown and text inside white
    final cardBg = brandBrown;
    final sectionBg = brandBrown;
    final borderColor = brandBrown.withOpacity(0.35);

    return CupertinoPageScaffold(
      backgroundColor: scaffoldBg,
      navigationBar: ChatSettingsNavigationBar(
        middle: 'Advanced chat privacy',
        previousPageTitle: S.of(context).back,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header
              Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: (isDark
                              ? CupertinoColors.systemGrey2
                              : CupertinoColors.systemGrey5)
                          .withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.lock_shield, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                  'Limit how messages and media from this chat can be shared outside of Orbit',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Your personal messages are protected with end-to-end encryption even if you don't turn on advanced chat privacy. No one outside of the chat, not even Orbit, can read, listen to, or share them.",
                style: TextStyle(
                  color: subColor,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              const SizedBox(height: 10),
              Text(
                'If you turn this on, people in this chat:',
                style: TextStyle(
                  color: subColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Bullet list (single item for now) - custom brown card with white text
              Container(
                decoration: BoxDecoration(
                  color: sectionBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Icon(CupertinoIcons.photo, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Can't save media to their device gallery automatically",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Toggle card (moved below the bullet row, subtitle removed) - brown with white text
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.lock_circle, size: 22, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Advanced chat privacy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    _loading
                        ? const CupertinoActivityIndicator()
                        : Container(
                            width: 64,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(_enabled ? 0.28 : 0.18),
                              border: Border.all(color: Colors.white.withOpacity(0.65)),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: CupertinoSwitch(
                              value: _enabled,
                              activeColor: brandBrown,
                              onChanged: (v) => _toggle(v),
                            ),
                          ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (_enabled)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: brandBrown,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: brandBrown.withOpacity(0.85)),
                  ),
                  child: Row(
                    children: const [
                      Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Advanced chat privacy is ON. Media downloads from this chat will be limited.',
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
