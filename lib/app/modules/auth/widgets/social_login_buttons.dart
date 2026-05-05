import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:super_up/app/core/auth0/auth0_service.dart';
import 'package:super_up/app/modules/auth/waiting_list/views/waiting_list_page.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../../core/api_service/auth/auth_api_service.dart';
import '../../../core/api_service/profile/profile_api_service.dart';
import '../../../core/dto/social_login_dto.dart';
import 'package:super_up/app/modules/auth/profile_picture_upload/views/profile_picture_upload_view.dart';

class SocialLoginButtons extends StatelessWidget {
  final AuthApiService authService;
  final ProfileApiService profileService;
  final bool isAddingAccount;

  const SocialLoginButtons({
    super.key,
    required this.authService,
    required this.profileService,
    this.isAddingAccount = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _SocialBtnWithIcon(icon: FontAwesomeIcons.google, label: 'Google', onTap: () => _signInWithAuth0(context, 'google-oauth2')),
      _SocialBtnWithIcon(icon: FontAwesomeIcons.facebookF, label: 'Facebook', onTap: () => _signInWithAuth0(context, 'facebook')),
      _SocialBtnWithIcon(icon: FontAwesomeIcons.xTwitter, label: 'X', onTap: () => _signInWithAuth0(context, 'twitter')),
      _SocialBtnWithIcon(icon: FontAwesomeIcons.linkedinIn, label: 'LinkedIn', onTap: () => _signInWithAuth0(context, 'linkedin')),
      _SocialBtnWithIcon(icon: FontAwesomeIcons.microsoft, label: 'Microsoft', onTap: () => _signInWithAuth0(context, 'windowslive')),
      _SocialBtnWithIcon(icon: FontAwesomeIcons.yahoo, label: 'Yahoo', onTap: () => _signInWithAuth0(context, 'yahoo')),
      _SocialBtnWithIcon(icon: FontAwesomeIcons.snapchat, label: 'Snapchat', onTap: () => _signInWithAuth0(context, 'snapchat')),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 10,
      spacing: 10,
      children: buttons
          .map((b) => SizedBox(
                width: 60,
                height: 60,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: const Color(0xFFB48648).withOpacity(0.2),
                  onPressed: b.onTap,
                  child: FaIcon(
                    b.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Future<void> _signInWithAuth0(BuildContext context, String connection) async {
    print('🔐 Starting Auth0 login with $connection');
    try {
      VAppAlert.showLoading(context: context);
      print('🔐 Loading dialog shown, calling Auth0...');
      
      final auth0Token = await AppAuth0Service.I.loginWithSocialProvider(connection);
      print('🔐 Auth0 token received: ${auth0Token.substring(0, 20)}...');

      final deviceHelper = DeviceInfoHelper();
      final pushKey = await (await VChatController.I.vChatConfig.currentPushProviderService)
          ?.getToken(VPlatforms.isWeb ? SConstants.webVapidKey : null);

      final dto = SocialLoginDto(
        accessToken: auth0Token,
        deviceId: await deviceHelper.getId(),
        deviceInfo: await deviceHelper.getDeviceMapInfo(),
        language: VLanguageListener.I.appLocal.languageCode,
        platform: VPlatforms.currentPlatform,
        pushKey: pushKey,
      );

      print('🔐 Calling backend auth0Login...');
      await authService.auth0Login(dto.toMap());
      print('🔐 Backend auth0Login successful, getting profile...');
      final profile = await profileService.getMyProfile();
      print('🔐 Profile loaded: ${profile.email}');

      // Update local profile storage and clear cache
      await VAppPref.setMap(SStorageKeys.myProfile.name, profile.toMap());
      AppAuth.setProfileNull(); // Force reload of profile data
      print('🔐 Profile cache cleared, UI will refresh');

      // Store to multi-account manager
      final accessToken = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name) ?? '';
      await MultiAccountManager.instance.addAccount(
        email: profile.email,
        accessToken: accessToken,
        profile: profile,
      );
      final accountId = AccountSession.createAccountId(profile.email, profile.baseUser.id);
      await MultiAccountManager.instance.switchToAccount(accountId);

      // Mark this account as pending profile picture until user completes the step
      // Only for normal sign-in/register flow (not when adding an existing account)
      if (!isAddingAccount) {
        final pending = VAppPref.getList(SStorageKeys.profilePicturePendingAccounts.name) ?? [];
        if (!pending.contains(accountId)) {
          pending.add(accountId);
          await VAppPref.setList(SStorageKeys.profilePicturePendingAccounts.name, pending);
        }
      }

      if (isAddingAccount) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Account added successfully',
        );
      } else {
        if (profile.registerStatus == RegisterStatus.accepted) {
          // After social signup, show the profile picture screen with the
          // social profile picture preloaded so the user can keep or change it.
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(
              builder: (context) => ProfilePictureUploadView(
                initialImageUrl: profile.baseUser.userImage,
              ),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (context) => WaitingListPage(profile: profile)),
            (route) => false,
          );
        }
      }
    } catch (e, stackTrace) {
      print('🔐 Error in Auth0 login: $e');
      print('🔐 Stack trace: $stackTrace');
      VAppAlert.showOkAlertDialog(
        context: context,
        title: 'Error',
        content: 'Auth0 login failed: ${e.toString()}',
      );
    } finally {
      print('🔐 Cleaning up loading dialog...');
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

}

class _SocialBtnWithIcon {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _SocialBtnWithIcon({required this.icon, required this.label, required this.onTap});
}

class _SocialBtnWithLogo {
  final String logo;
  final String label;
  final VoidCallback onTap;

  _SocialBtnWithLogo({required this.logo, required this.label, required this.onTap});
}
