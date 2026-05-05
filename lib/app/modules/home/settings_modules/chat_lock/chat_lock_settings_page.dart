// Chat Lock Settings Page: set or update the password used to lock chats.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/services/chat_lock_service.dart';
import 'package:super_up_core/super_up_core.dart';

class ChatLockSettingsPage extends StatefulWidget {
  const ChatLockSettingsPage({super.key});

  @override
  State<ChatLockSettingsPage> createState() => _ChatLockSettingsPageState();
}

class _ChatLockSettingsPageState extends State<ChatLockSettingsPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  bool get _hasPassword => ChatLockService.instance.isPasswordSet;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_loading) return;

    if (_hasPassword) {
      if (!ChatLockService.instance.verifyPassword(_currentCtrl.text.trim())) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Current password is incorrect');
        return;
      }
    }

    final newPass = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (newPass.length < 4) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Password must be at least 4 characters');
      return;
    }
    if (newPass != confirm) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Passwords do not match');
      return;
    }

    setState(() => _loading = true);
    try {
      await ChatLockService.instance.setPassword(newPass);
      if (!mounted) return;
      VAppAlert.showSuccessSnackBar(context: context, message: 'Chat Lock password updated');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: 'Failed to save password');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(CupertinoIcons.chevron_back, color: Colors.white),
          ),
        ),
        middle: const Text('Chat Lock'),
        previousPageTitle: 'Settings',
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hasPassword
                    ? 'Update your chat lock password. You will need this password to open locked chats.'
                    : 'Set a password for locking chats. You will need this password to open locked chats.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (_hasPassword)
                _inputTile(
                  label: 'Current password',
                  controller: _currentCtrl,
                  obscure: _obscureCurrent,
                  onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              _inputTile(
                label: 'New password',
                controller: _newCtrl,
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
              ),
              _inputTile(
                label: 'Confirm new password',
                controller: _confirmCtrl,
                obscure: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Text('Save Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputTile({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 6, top: 12),
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        CupertinoTextField(
          controller: controller,
          obscureText: obscure,
          enableSuggestions: false,
          autocorrect: false,
          padding: const EdgeInsets.all(12),
          suffix: GestureDetector(
            onTap: onToggle,
            child: Icon(obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye),
          ),
        ),
      ],
    );
  }
}
