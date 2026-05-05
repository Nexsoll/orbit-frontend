// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:super_up_core/super_up_core.dart';

class RegisterOtpModal extends StatefulWidget {
  final String email;
  final Function(String, VoidCallback) onOtpVerified;
  final VoidCallback onResendOtp;
  final bool isFirebasePhoneAuth;

  const RegisterOtpModal({
    super.key,
    required this.email,
    required this.onOtpVerified,
    required this.onResendOtp,
    this.isFirebasePhoneAuth = false,
  });

  @override
  State<RegisterOtpModal> createState() => _RegisterOtpModalState();
}

class _RegisterOtpModalState extends State<RegisterOtpModal> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  void resetLoading() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
          fontSize: 20, color: Colors.black, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.black, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.black, width: 2),
      ),
    );

    return PopScope(
      canPop: !_isLoading, // Allow back button only when not loading
      child: CupertinoAlertDialog(
        title: Text(widget.isFirebasePhoneAuth ? "Verify Phone" : "Verify Email"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Enter OTP sent to ${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            Pinput(
              controller: _otpController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              length: 6,
              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
              showCursor: true,
              onCompleted: (pin) => _verifyOtp(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Didn't receive code?"),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _isLoading ? null : widget.onResendOtp,
                  child: const Text(
                    "Resend",
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          CupertinoDialogAction(
            onPressed: _isLoading ? null : _verifyOtp,
            child: _isLoading
                ? const CupertinoActivityIndicator()
                : const Text("Verify", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _verifyOtp() {
    if (_otpController.text.length == 6) {
      setState(() {
        _isLoading = true;
      });

      // Auto-reset loading after 10 seconds as a fallback
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _isLoading) {
          resetLoading();
        }
      });

      widget.onOtpVerified(_otpController.text, resetLoading);
    } else {
      VAppAlert.showErrorSnackBar(
        message: "Please enter a valid 6-digit OTP",
        context: context,
      );
    }
  }
}
