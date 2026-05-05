// Copyright 2025, the Orbit project.
// A modal to paste or type the registration verification token from email link.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';

class RegisterTokenModal extends StatefulWidget {
  final String email;
  final Function(String, VoidCallback) onTokenVerified;
  final VoidCallback onResendLink;

  const RegisterTokenModal({
    super.key,
    required this.email,
    required this.onTokenVerified,
    required this.onResendLink,
  });

  @override
  State<RegisterTokenModal> createState() => _RegisterTokenModalState();
}

class _RegisterTokenModalState extends State<RegisterTokenModal> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  void _resetLoading() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _extractToken(String input) {
    final text = input.trim();
    // If full URL is pasted, try parsing token from query param
    if (text.startsWith('http')) {
      final uri = Uri.tryParse(text);
      final qpToken = uri?.queryParameters['token'];
      if (qpToken != null && qpToken.isNotEmpty) return qpToken;
      // fallback regex
      final reg = RegExp(r"token=([^&]+)");
      final m = reg.firstMatch(text);
      if (m != null && m.groupCount >= 1) return m.group(1)!;
    }
    return text; // assume raw token
  }

  void _verify() {
    final raw = _tokenController.text;
    if (raw.isEmpty) {
      VAppAlert.showErrorSnackBar(
        message: 'Please paste the verification token or link',
        context: context,
      );
      return;
    }
    final token = _extractToken(raw);
    if (token.isEmpty) {
      VAppAlert.showErrorSnackBar(
        message: 'Invalid token. Please paste the token from your email link.',
        context: context,
      );
      return;
    }

    setState(() => _isLoading = true);

    // Auto-reset loading after 10 seconds as a fallback
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        _resetLoading();
      }
    });

    widget.onTokenVerified(token, _resetLoading);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: CupertinoAlertDialog(
        title: const Text('Verify Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              'We\'ve sent a verification link to\n${widget.email}.\n\nOpen the email, copy the token (or the full link), and paste it below.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: TextField(
                controller: _tokenController,
                decoration: InputDecoration(
                  hintText: 'Paste token or full link here',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                minLines: 1,
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Didn't get the email?"),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _isLoading ? null : widget.onResendLink,
                  child: const Text(
                    'Resend',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          CupertinoDialogAction(
            onPressed: _isLoading ? null : _verify,
            child: _isLoading
                ? const CupertinoActivityIndicator()
                : const Text('Verify', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
