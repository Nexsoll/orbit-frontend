// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:share_plus/share_plus.dart';
import 'package:v_platform/v_platform.dart';
import '../../../core/api_service/profile/profile_api_service.dart';

class PublicProfileView extends StatefulWidget {
  final String userId;

  const PublicProfileView({
    super.key,
    required this.userId,
  });

  @override
  State<PublicProfileView> createState() => _PublicProfileViewState();
}

class _PublicProfileViewState extends State<PublicProfileView> {
  final _profileApiService = GetIt.I.get<ProfileApiService>();
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _profileApiService.publicProfile(widget.userId);
      setState(() {
        profileData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        middle: Text(S.of(context).contactInfo),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.share),
          onPressed: () {
            // Share this profile
            _shareProfile();
          },
        ),
      ),
      child: SafeArea(
        child: isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading profile',
                          style: context.cupertinoTextTheme.navTitleTextStyle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        CupertinoButton(
                          onPressed: _loadProfile,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _buildProfileContent(),
      ),
    );
  }

  Widget _buildProfileContent() {
    if (profileData == null) return const SizedBox();

    final userImage = profileData!['userImage'] as String;
    final fullName = profileData!['fullName'] as String;
    final bio = profileData!['bio'] as String?;
    final hasBadge = profileData!['hasBadge'] as bool? ?? false;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Profile Image
            VCircleAvatar(
              vFileSource: VPlatformFile.fromUrl(networkUrl: userImage),
              radius: 90,
            ),
            const SizedBox(height: 16),
            // Full Name
            SUserNameWithBadge(
              fullName: fullName,
              isVerified: hasBadge,
              textStyle: context.cupertinoTextTheme.navLargeTitleTextStyle,
              mainAxisAlignment: MainAxisAlignment.center,
              badgeSize: 20.0,
            ),
            const SizedBox(height: 8),
            // Bio
            Text(
              bio ?? "${S.of(context).hiIamUse} ${SConstants.appName}",
              maxLines: 3,
              style: const TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Download App Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Download ${SConstants.appName} to connect',
                    style: context.cupertinoTextTheme.navTitleTextStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton.filled(
                          child: const Text('Android'),
                          onPressed: () => _openAppStore(true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CupertinoButton.filled(
                          child: const Text('iOS'),
                          onPressed: () => _openAppStore(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareProfile() {
    final profileUrl = 'https://api.orbit.ke/profile/${widget.userId}';
    final fullName = profileData?['fullName'] ?? 'User';

    Share.share('''Check out $fullName's profile on ${SConstants.appName}!

$profileUrl

Download ${SConstants.appName}:

ANDROID
${SConstants.playStoreUrl}

IOS
${SConstants.appStoreUrl}''');
  }

  void _openAppStore(bool isAndroid) {
    final url = isAndroid ? SConstants.playStoreUrl : SConstants.appStoreUrl;

    VStringUtils.lunchLink(url);
  }
}
