// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  bool _isLoading = true;
  String? _policyText;

  @override
  void initState() {
    super.initState();
    _loadPrivacyPolicy();
  }

  Future<void> _loadPrivacyPolicy() async {
    // Refresh app config to get latest privacy policy
    try {
      final configController = GetIt.I.get<VAppConfigController>();
      await configController.refreshAppConfig();
    } catch (e) {
      // If refresh fails, we'll use cached config
    }

    if (mounted) {
      setState(() {
        _policyText = _getPrivacyPolicyText();
        _isLoading = false;
      });
    }
  }

  String _getPrivacyPolicyText() {
    final appConfig = VAppConfigController.appConfig;
    
    // Use privacy policy text from backend if available
    if (appConfig.privacyPolicyText != null && appConfig.privacyPolicyText!.isNotEmpty) {
      return appConfig.privacyPolicyText!;
    }
    
    // Otherwise return default policy
    return '''Privacy Policy
This privacy policy explains how we collect, use, and protect your personal data when you use our chat app Orbit Chat.

Information we collect
When you use our chat app Orbit Chat, we may collect the following information:

Your name, email, photo and IP address (if you choose to provide them)
Your device's IP address and other technical information
Your location (if you choose to share it)

How we use your information
We may use your information to:

Provide our chat and project management services to you
Improve our chat app and services
Communicate with you about our chat app and services
Comply with legal requirements

Storage, microphone, and location permissions
Our chat app Orbit Chat requires access to your device's storage, microphone, and location services in order to provide the following features:

Send and receive files and media in chat
Send and receive voice chat
Send and receive location information in chat

Data storage
All data that you send and receive through our chat app Orbit Chat is stored on our servers, so that you can access it even if you delete the app and reinstall it later. We take all reasonable measures to protect your data, including encryption and secure storage.

No third-party use of your data
We do not share your personal data with third-party services, except as required by law or to provide our chat and project management services to you.

Data security
We take the security of your personal data seriously, and have implemented appropriate technical and organizational measures to protect your data from unauthorized access, disclosure, and misuse.

Contact us
If you have any questions or concerns about our privacy policy, please contact us at info@orbit.ke.''';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text(S.of(context).privacyPolicy),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _policyText ?? _getPrivacyPolicyText(),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
      ),
    );
  }
}
