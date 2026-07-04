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
import '../../splash/views/splash_view.dart';

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
    return Row(
      children: [
        Expanded(
          child: _buildSocialIconButton(
            icon: FontAwesomeIcons.google,
            onTap: () => _signInWithAuth0(context, 'google-oauth2'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSocialIconButton(
            icon: FontAwesomeIcons.facebookF,
            onTap: () => _signInWithAuth0(context, 'facebook'),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFB48648).withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFB48648).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: FaIcon(
              icon,
              color: const Color(0xFFB48648),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithAuth0(BuildContext context, String connection) async {
    print('🔐 Starting Auth0 login with $connection');
    bool loadingOpen = false;
    try {
      VAppAlert.showLoading(context: context);
      loadingOpen = true;
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
        if (loadingOpen && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          loadingOpen = false;
        }
        context.toPage(
          const SplashView(),
          withAnimation: false,
          removeAll: true,
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
      if (loadingOpen && context.mounted && Navigator.of(context).canPop()) {
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
