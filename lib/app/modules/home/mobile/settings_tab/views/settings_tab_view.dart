// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/modules/chat_settings/chat_star_messages/views/chat_star_messages_page.dart';
import 'package:super_up/app/modules/home/home_controller/widgets/chat_un_read_counter.dart';
import 'package:super_up/app/modules/home/mobile/settings_tab/states/setting_state.dart';
import 'package:super_up/app/modules/home/mobile/settings_tab/widgets/settings_list_item_tile.dart';
import 'package:super_up/app/modules/home/settings_modules/blocked_contacts/views/blocked_contacts_page.dart';
import 'package:super_up/app/modules/home/settings_modules/devices/linked_devices/views/linked_devices_page.dart';
import 'package:super_up/app/modules/home/settings_modules/my_account/views/my_account_page.dart';
import 'package:super_up/app/modules/peer_profile/views/follow_users_page.dart';
import 'package:super_up/app/modules/peer_profile/views/user_music_gallery_view.dart';
import 'package:super_up/app/widgets/balance_widget.dart';
import 'package:super_up/app/widgets/custom_circle_avatar.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/widgets/app_logo.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_platform/v_platform.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';

import '../../../settings_modules/admin_notification/views/admin_notification_page.dart';
import '../../../settings_modules/help_tab/help/views/help_page.dart';
import '../../../settings_modules/verification/views/verification_request_page.dart';
import '../../../settings_modules/my_privacy/my_privacy_page.dart';
import '../../../settings_modules/chat_lock/chat_lock_settings_page.dart';
import '../../../settings_modules/account_switcher/widgets/account_switcher_button.dart';
import '../../../settings_modules/call_background/views/call_background_settings_page.dart';
import '../../../settings_modules/wallet/views/wallet_page.dart';
import '../../../settings_modules/withdraw/views/withdraw_page.dart';
import '../controllers/settings_tab_controller.dart';
import 'package:super_up/app/core/api_service/api_service.dart';
import '../../../settings_modules/ads/views/submit_ad_page.dart';
import 'package:super_up/app/modules/ride/views/emergency_contacts_view.dart';

class SettingsTabView extends StatefulWidget {
  const SettingsTabView({super.key});

  @override
  State<SettingsTabView> createState() => _SettingsTabViewState();
}

class _SettingsTabViewState extends State<SettingsTabView> {
  final SettingsTabController controller = SettingsTabController();
  Future<List<Map<String, dynamic>>>? _adsFuture;
  Future<Map<String, int>>? _followCountsFuture;
  final _pageCtrl = PageController();
  Timer? _adsTimer;
  int _adsIndex = 0;
  int _adsCount = 0;

  String _mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final apiBase = SConstants.sApiBaseUrl;
    final origin = Uri(
      scheme: apiBase.scheme,
      host: apiBase.host,
      port: apiBase.hasPort ? apiBase.port : null,
    );
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return origin.resolve(normalized).toString();
  }

  @override
  void initState() {
    super.initState();
    controller.onInit();
    _adsFuture = ProfileApiService.init().getApprovedAds(limit: 5);
    _followCountsFuture = _loadFollowCounts();
    // Refresh my profile in the background to pick up any new roles (e.g., admin)
    _refreshProfile();
  }

  @override
  void dispose() {
    controller.onClose();
    _adsTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startAdsAutoScroll(int count) {
    if (count <= 1) {
      _adsTimer?.cancel();
      _adsTimer = null;
      return;
    }
    if (_adsTimer != null && _adsCount == count) return;

    _adsCount = count;
    _adsTimer?.cancel();
    _adsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (!_pageCtrl.hasClients) return;
      if (_adsCount <= 1) return;

      final next = (_adsIndex + 1) % _adsCount;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _refreshProfile() async {
    try {
      final profile = await ProfileApiService.init().getMyProfile();
      await VAppPref.setMap(SStorageKeys.myProfile.name, profile.toMap());
      AppAuth.setProfileNull();
      if (mounted) setState(() {});
    } catch (_) {
      // Ignore refresh errors to avoid blocking settings page
    }
  }

  Future<Map<String, int>> _loadFollowCounts() async {
    try {
      return await ProfileApiService.init().getFollowCounts(
        AppAuth.myProfile.baseUser.id,
      );
    } catch (_) {
      return {
        'followers': 0,
        'following': 0,
      };
    }
  }

  Widget _buildFollowStat({
    required BuildContext context,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: textTheme.textStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: textTheme.textStyle.copyWith(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: CupertinoPageScaffold(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            CupertinoSliverNavigationBar(
              transitionBetweenRoutes: false, // disables Hero animation
              largeTitle: Text(S.of(context).settings,
                  style: context.cupertinoTextTheme.textStyle.copyWith(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                  )),
              middle: const AppLogo(),
            )
          ],
          body: SingleChildScrollView(
            child: ValueListenableBuilder<SLoadingState<SettingState>>(
              valueListenable: controller,
              builder: (_, value, ___) {
                return Column(
                  children: [
                    // Advertisements Label
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Advertisements',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Banner Ads Slider
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _adsFuture,
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const SizedBox(height: 8);
                        }
                        final ads = snap.data ?? const [];
                        if (ads.isEmpty) {
                          _adsTimer?.cancel();
                          _adsTimer = null;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            child: GestureDetector(
                              onTap: () => context.toPage(const SubmitAdPage()),
                              child: Container(
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.campaign, size: 28),
                                    const SizedBox(height: 6),
                                    Text(
                                      S.of(context).advertiseHereTitle,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      S.of(context).advertiseHereSubtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          _startAdsAutoScroll(ads.length);
                        });
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: SizedBox(
                            height: 140,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: PageView.builder(
                                controller: _pageCtrl,
                                itemCount: ads.length,
                                onPageChanged: (i) {
                                  _adsIndex = i;
                                },
                                itemBuilder: (ctx, i) {
                                  final ad = ads[i];
                                  final img = ad['imageUrl']?.toString();
                                  final link = ad['linkUrl']?.toString();
                                  return GestureDetector(
                                    onTap: link == null || link.isEmpty
                                        ? null
                                        : () => VStringUtils.lunchLink(link),
                                    child: Image.network(
                                      _mediaUrl(img),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.black12,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.image_not_supported_outlined),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Profile row (outside list section to avoid white background)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: CustomListTile(
                        title: AppAuth.myProfile.hasBadge
                            ? SUserNameWithBadge(
                                fullName: AppAuth.myProfile.baseUser.fullName,
                                isVerified: true,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                badgeSize: 16.0,
                              )
                            : Text(
                                AppAuth.myProfile.baseUser.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        padding: const EdgeInsets.all(0),
                        leading: CustomCircleAvatar(
                          imageUrl: AppAuth.myProfile.baseUser.userImageS3,
                        ),
                        subtitle: AppAuth.myProfile.bio,
                        trailing: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BalanceChip(),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 6),
                      child: FutureBuilder<Map<String, int>>(
                        future: _followCountsFuture,
                        builder: (ctx, snap) {
                          final followers = snap.data?['followers'] ?? 0;
                          final following = snap.data?['following'] ?? 0;
                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildFollowStat(
                                  context: context,
                                  label: S.of(context).followersLabel,
                                  value: followers.toString(),
                                  onTap: () async {
                                    await context.toPage(
                                      FollowUsersPage(
                                        userId: AppAuth.myProfile.baseUser.id,
                                        isFollowersTab: true,
                                      ),
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      _followCountsFuture = _loadFollowCounts();
                                    });
                                  },
                                ),
                                Container(
                                  width: 1,
                                  height: 32,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.12),
                                ),
                                _buildFollowStat(
                                  context: context,
                                  label: 'Following',
                                  value: following.toString(),
                                  onTap: () async {
                                    await context.toPage(
                                      FollowUsersPage(
                                        userId: AppAuth.myProfile.baseUser.id,
                                        isFollowersTab: false,
                                      ),
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      _followCountsFuture = _loadFollowCounts();
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          final me = AppAuth.myProfile.baseUser;
                          context.toPage(
                            UserMusicGalleryView(
                              userId: me.id,
                              userName: me.fullName,
                              userImage: me.userImage,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                CupertinoIcons.photo_on_rectangle,
                                color: Color(0xFFB48648),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Gallery',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Icon(
                                CupertinoIcons.chevron_forward,
                                color: CupertinoColors.systemGrey2,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    CupertinoListSection(
                      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                      dividerMargin: 0,
                      hasLeading: false,
                      children: [
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).account,
                          onTap: () async {
                            await context.toPage(const MyAccountPage());
                            controller.update();
                          },
                          icon: CupertinoIcons.profile_circled,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).verification,
                          onTap: () async {
                            if (AppAuth.myProfile.hasBadge) {
                              await showOkAlertDialog(
                                context: context,
                                title: S.of(context).alreadyVerifiedTitle,
                                message: S.of(context).alreadyVerifiedMessage,
                              );
                              return;
                            }
                            // Not verified: proceed to submission page
                            // ignore: use_build_context_synchronously
                            context.toPage(const VerificationRequestPage());
                          },
                          icon: CupertinoIcons.checkmark_seal_fill,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).wallet,
                          onTap: () => context.toPage(const WalletPage()),
                          icon: CupertinoIcons.creditcard_fill,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).withdraw,
                          onTap: () => context.toPage(const WithdrawPage()),
                          icon: CupertinoIcons.arrow_down_circle_fill,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).emergencyContacts,
                          onTap: () => context.toPage(const EmergencyContactsView()),
                          icon: CupertinoIcons.phone_solid,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).shareProfile,
                          onTap: () => controller.shareMyProfile(context),
                          icon: CupertinoIcons.share,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).callBackground,
                          onTap: () =>
                              context.toPage(const CallBackgroundSettingsPage()),
                          icon: CupertinoIcons.videocam_fill,
                        ),
                        const AccountSwitcherButton(),
                      ],
                    ),
                    CupertinoListSection(
                      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                      dividerMargin: 0,
                      topMargin: 30,
                      hasLeading: false,
                      children: [
                        SettingsListItemTile(
                          hide: true,
                          color: Colors.grey.shade800,
                          title: S.of(context).starredMessages,
                          onTap: () =>
                              context.toPage(const ChatStarMessagesPage()),
                          icon: CupertinoIcons.star_fill,
                        ),
                        SettingsListItemTile(
                          hide: !VPlatforms.isMobile,
                          color: Colors.grey.shade800,
                          title: S.of(context).linkedDevices,
                          onTap: () =>
                              context.toPage(const LinkedDevicesPage()),
                          icon: CupertinoIcons.device_laptop,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).language,
                          onTap: () => controller.onLanguageChange(context),
                          additionalInfo: value.data.language.text,
                          icon: Icons.language,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: "Dark Mode",
                          onTap: () => controller.onThemeChange(context),
                          trailing: CupertinoSwitch(
                            value: value.data.isDarkMode,
                            activeColor: const Color(0xFFB48648),
                            onChanged: (v) => controller.onThemeChange(context),
                          ),
                          icon: CupertinoIcons.moon_fill,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).adminNotification,
                          onTap: () =>
                              context.toPage(const AdminNotificationPage()),
                          icon: CupertinoIcons.app_badge_fill,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).submitAd,
                          onTap: () => context.toPage(const SubmitAdPage()),
                          icon: Icons.campaign,
                        ),
                      ],
                    ),
                    CupertinoListSection(
                      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                      dividerMargin: 0,
                      topMargin: 30,
                      hasLeading: false,
                      children: [
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).appLock,
                          subtitle: Text(S.of(context).appLockSubtitle),
                          onTap: () async {
                            final enabledNow = controller.value.data.appLockEnabled;
                            await controller.onToggleAppLock(context, !enabledNow);
                          },
                          trailing: CupertinoSwitch(
                            value: value.data.appLockEnabled,
                            activeColor: const Color(0xFFB48648),
                            onChanged: (v) => controller.onToggleAppLock(context, v),
                          ),
                          icon: CupertinoIcons.lock_shield,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).email2FA,
                          subtitle: Text(S.of(context).email2FASubtitle),
                          onTap: () async {
                            final enabledNow = controller.value.data.twoFactorEnabled;
                            await controller.onToggleTwoFactor(context, !enabledNow);
                          },
                          trailing: CupertinoSwitch(
                            value: value.data.twoFactorEnabled,
                            activeColor: const Color(0xFFB48648),
                            onChanged: (v) => controller.onToggleTwoFactor(context, v),
                          ),
                          icon: CupertinoIcons.lock_fill,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).chatLock,
                          onTap: () => context.toPage(const ChatLockSettingsPage()),
                          icon: CupertinoIcons.lock,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).myPrivacy,
                          onTap: () => context.toPage(const MyPrivacyPage()),
                          icon: Icons.privacy_tip_outlined,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).blockedUsers,
                          onTap: () =>
                              context.toPage(const BlockedContactsPage()),
                          icon: CupertinoIcons.ant,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).inAppAlerts,
                          onTap: () =>
                              controller.onChangeAppNotifications(context),
                          icon: CupertinoIcons.app_badge,
                          additionalInfo: value.data.inAppAlerts
                              ? Text(S.of(context).on)
                              : Text(S.of(context).off),
                        ),
                        if (VPlatforms.isMobile)
                          SettingsListItemTile(
                            color: Colors.grey.shade800,
                            title: S.of(context).storageAndData,
                            onTap: () => controller.onStorageClick(context),
                            icon: CupertinoIcons.wifi,
                          ),
                      ],
                    ),
                    CupertinoListSection(
                      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                      dividerMargin: 0,
                      topMargin: 30,
                      hasLeading: false,
                      children: [
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).help,
                          onTap: () => context.toPage(const HelpPage()),
                          icon: CupertinoIcons.question,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).tellAFriend,
                          onTap: () => controller.tellAFriend(context),
                          icon: CupertinoIcons.heart_fill,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).checkForUpdates,
                          onTap: () => controller.checkForUpdates(context),
                          icon: CupertinoIcons.refresh_thick,
                          trailing: controller
                                  .versionCheckerController.value.isNeedUpdates
                              ? Row(
                                  children: [
                                    const ChatUnReadWidget(
                                      unReadCount: 1,
                                    ),
                                    const SizedBox(
                                      width: 5,
                                    ),
                                    Icon(context.isRtl
                                        ? CupertinoIcons.chevron_back
                                        : CupertinoIcons.chevron_forward),
                                  ],
                                )
                              : null,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).adminPanel,
                          hide: !AppAuth.myProfile.roles.contains(UserRoles.admin),
                          onTap: () => controller.openAdminPanel(context),
                          icon: CupertinoIcons.settings_solid,
                        ),
                        SettingsListItemTile(
                          color: Colors.grey.shade800,
                          title: S.of(context).logOut,
                          onTap: () => controller.logout(context),
                          icon: CupertinoIcons.arrow_right_circle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: GestureDetector(
                        onTap: () => VStringUtils.lunchLink('https://www.orbit.ke'),
                        child: "www.orbit.ke".text.size(16).color(Colors.black),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
