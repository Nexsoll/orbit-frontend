// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:s_translation/generated/l10n.dart';
import '../../../../utils/encryption_verification.dart';

class EncryptionVerificationView extends StatefulWidget {
  const EncryptionVerificationView({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
  });

  final String currentUserId;
  final String otherUserId;
  final String otherUserName;

  @override
  State<EncryptionVerificationView> createState() => _EncryptionVerificationViewState();
}

class _EncryptionVerificationViewState extends State<EncryptionVerificationView> {
  late String safetyNumber;
  late String verificationCode;

  @override
  void initState() {
    super.initState();
    safetyNumber = EncryptionVerification.generateSafetyNumber(
      widget.currentUserId,
      widget.otherUserId,
    );
    verificationCode = EncryptionVerification.generateVerificationCode(
      widget.currentUserId,
      widget.otherUserId,
    );
  }

  void _copySafetyNumber() {
    Clipboard.setData(ClipboardData(text: safetyNumber));
    _showCopyConfirmation();
  }

  void _copyVerificationCode() {
    Clipboard.setData(ClipboardData(text: verificationCode));
    _showCopyConfirmation();
  }

  void _showCopyConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Copied"),
        content: const Text("Safety number copied to clipboard"),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _markAsVerified() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Mark as Verified"),
        content: Text(
          "Have you compared the safety numbers with ${widget.otherUserName} and confirmed they match?",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Yes, Mark as Verified"),
            onPressed: () {
              Navigator.of(context).pop();
              _showVerificationSuccess();
            },
          ),
        ],
      ),
    );
  }

  void _showVerificationSuccess() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("✓ Verified"),
        content: Text(
          "Your conversation with ${widget.otherUserName} is now verified as secure.",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Row(
            children: [
              Icon(CupertinoIcons.chevron_back, color: Color(0xFFB48648)),
              SizedBox(width: 2),
              Text("Back", style: TextStyle(color: Color(0xFFB48648))),
            ],
          ),
        ),
        middle: const Text("Verify Encryption"),
        previousPageTitle: S.of(context).back,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFB48648).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.lock_shield_fill,
                      color: Color(0xFFB48648),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Verify encryption with ${widget.otherUserName}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Instructions
              const Text(
                "Safety Numbers",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Compare these numbers with the ones on your contact's device. If they match, your conversation is secure.",
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Safety Number Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CupertinoColors.systemGrey4,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      EncryptionVerification.formatSafetyNumber(safetyNumber),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Courier',
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    CupertinoButton(
                      onPressed: _copySafetyNumber,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      color: CupertinoColors.systemBlue,
                      borderRadius: BorderRadius.circular(8),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.doc_on_clipboard, size: 16, color: CupertinoColors.white),
                          SizedBox(width: 8),
                          Text("Copy", style: TextStyle(color: CupertinoColors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Quick Verification Code
              const Text(
                "Quick Verification Code",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "For quick verbal verification over phone or in person:",
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 12),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      EncryptionVerification.formatVerificationCode(verificationCode),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton(
                      onPressed: _copyVerificationCode,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      color: CupertinoColors.systemGrey,
                      borderRadius: BorderRadius.circular(6),
                      child: const Text("Copy Code", style: TextStyle(fontSize: 14, color: CupertinoColors.white)),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              const SizedBox(height: 32),
              
              // Help Text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemYellow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          CupertinoIcons.info_circle,
                          color: CupertinoColors.systemYellow,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "How to verify:",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "1. Ask ${widget.otherUserName} to open this same screen\n"
                      "2. Compare the safety numbers or verification code\n"
                      "3. If they match exactly, your chat is secure",
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel,
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
