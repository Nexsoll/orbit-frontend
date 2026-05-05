// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:developer';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:super_up/app/modules/auth/register/views/register_view.dart';
import '../../../core/api_service/auth/auth_api_service.dart';
import '../../../core/dto/social_login_dto.dart';
import '../../../core/api_service/profile/profile_api_service.dart';
import 'package:super_up/app/modules/home/mobile/calls_tab/controllers/calls_tab_controller.dart';
import 'package:super_up/app/modules/home/mobile/rooms_tab/controllers/rooms_tab_controller.dart';
import 'package:super_up/app/modules/home/mobile/story_tab/controllers/story_tab_controller.dart';
import 'package:super_up/app/modules/home/mobile/users_tab/controllers/users_tab_controller.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../../../main.dart';
import '../../../../v_chat_v2/v_chat_config.dart';
import '../../../core/app_config/app_config_controller.dart';
import '../../../core/services/balance_service.dart';
import '../../../core/services/claimed_gifts_service.dart';
import '../../../core/services/app_lock_service.dart';
import '../../lock/views/app_locked_page.dart';
import '../../auth/waiting_list/views/waiting_list_page.dart';
import '../../home/home_controller/views/home_view.dart';
import '../../auth/profile_picture_upload/views/profile_picture_upload_view.dart';
import '../views/splash_view.dart';
import '../../../core/services/deep_link_service.dart';

bool isShow450Error = false;

class SplashController extends SLoadingController<String> {
  String get version => data;

  SplashController() : super(SLoadingState(""));

  BuildContext get context => navigatorKey.currentState!.context;
  final appConfigController = GetIt.I.get<VAppConfigController>();
  bool _navigated = false; // guard to avoid being stuck on splash

  @override
  void onInit() {
    
    getAppVersion();
    startNavigate();
    _init450Listener();
    // checkUpdates();
    _installWatchdog();
  }

  Future<bool> _ensureVChatReady() async {
    try {
      // Access to validate initialization
      // ignore: unused_local_variable
      final _ = VChatController.I.nativeApi;
      // ignore: unused_local_variable
      final __ = VChatController.I.profileApi;
      return true;
    } catch (_) {
      // retry init below
    }

    try {
      _log('VChat not ready, retrying init...');
      await initVChat(navigatorKey);
      // ignore: unused_local_variable
      final _ = VChatController.I.nativeApi;
      // ignore: unused_local_variable
      final __ = VChatController.I.profileApi;
      _log('VChat init retry succeeded');
      return true;
    } catch (e) {
      _log('VChat init retry failed: ' + e.toString());
      return false;
    }
  }

  bool _isDefaultImage(String image) {
    final u = image.toLowerCase().trim();
    if (u.isEmpty) return true;
    return u.contains('default_user_image');
  }

  void _init450Listener() async {
    // await Future.delayed(const Duration(milliseconds: 100));
    try {
      unAuthStream450Error.stream.listen((event) async {
        if (isShow450Error == true) return;
        isShow450Error = true;
        await Future.delayed(const Duration(seconds: 1));
        await VChatController.I.profileApi.logout();
        try {
          await BalanceService.instance.clearBalance();
        } catch (_) {}
        final current = MultiAccountManager.instance.currentAccount;
        if (current != null) {
          await MultiAccountManager.instance.removeAccount(current.accountId);
        } else {
          AppAuth.setProfileNull();
          await VAppPref.clearAuthKeys();
        }
        await VAppAlert.showOkAlertDialog(
          context: context,
          title: S.of(context).loginAgain,
          content: S.of(context).yourSessionIsEndedPleaseLoginAgain,
        );

        // Clean up GetIt controllers before navigation
        _cleanupGetItControllers();

        VChatController.I.navigatorKey.currentContext!.toPage(
          const SplashView(),
          withAnimation: false,
          removeAll: true,
        );
        AppAuth.setProfileNull();
      });
    } catch (err) {
      //
    }
  }

  Future<void> getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      value.data = "$version+$buildNumber";
      setStateSuccess();
      await appConfigController.refreshAppConfig();
      final c = VAppConfigController.appConfig;
      VChatController.I.updateConfig(VChatController.I.vChatConfig.copyWith(
        maxForward: c.maxForward,
        maxBroadcastMembers: c.maxBroadcastMembers,
        maxGroupMembers: c.maxGroupMembers,
      ));
    } catch (err) {
      log(err.toString());
    }
  }

  Future<void> _homeNav() async {
    if (_navigated) return;
    _navigated = true;
    final ok = await _ensureVChatReady();
    if (!ok) {
      _navigated = false;
      return;
    }
    context.toPageAndRemoveAllWithOutAnimation(const HomeView());
  }

  // Debug helper
  void _log(String msg) {
    try {
      // ignore: avoid_print
      print('[Splash] ' + msg);
    } catch (_) {}
  }

  void _installWatchdog() {
    // As a last resort, navigate after a short delay if no route was pushed.
    Future.delayed(Duration(seconds: VPlatforms.isIOS ? 10 : 1), () async {
      if (_navigated) return;
      _log('Watchdog triggered');
      // If a room deep link is active (e.g. from a chat notification),
      // do not auto-navigate over the deep-link target.
      try {
        final deep = DeepLinkService();
        if (deep.hasPendingRoomDeepLink) {
          _log('Watchdog: room deep link active, skipping auto navigation');
          return;
        }
      } catch (_) {}
      try {
        // Force route on iOS to avoid being stuck on Splash during simulator debugging
        // Respect app lock; do not bypass if still locked
        try {
          if (AppLockService.instance.isEnabled &&
              await AppLockService.instance.isSupported()) {
            if (!AppLockService.instance.sessionUnlocked) {
              _log('Watchdog: app lock active and not unlocked; keeping splash');
              return;
            }
          }
        } catch (_) {}

        final current = MultiAccountManager.instance.currentAccount;
        if (current != null) {
          _log('Watchdog routing to HomeView (current account present)');
          await _homeNav();
          return;
        }

        // Legacy cached profile fallback
        final map = VAppPref.getMap(SStorageKeys.myProfile.name);
        if (map != null) {
          _log('Watchdog routing to HomeView (legacy cache present)');
          await _homeNav();
          return;
        }

        // If an access token exists, the user is likely logged in but the
        // session/account data might still be loading. Avoid flashing Register.
        final accessToken =
            VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
        if (accessToken != null && accessToken.isNotEmpty) {
          _log('Watchdog: access token exists, skipping RegisterView navigation');
          return;
        }

        _log('Watchdog routing to RegisterView (no account found)');
        _navigated = true;
        context.toPage(
          const RegisterView(),
          withAnimation: true,
          removeAll: true,
        );
      } catch (e) {
        _log('Watchdog error: ' + e.toString());
      }
    });
  }

  void startNavigate() async {
    // If we're in the reset-password deep link flow, do not perform any
    // automatic navigation from the splash controller. This prevents the
    // app from pushing unauthenticated pages like ChooseRooms over the
    // ResetPasswordPage.
    try {
      final deep = DeepLinkService();
      if (deep.isInResetFlow || deep.hasPendingRoomDeepLink) {
        _log('startNavigate: deep link active (reset=' +
            deep.isInResetFlow.toString() +
            ', room=' +
            deep.hasPendingRoomDeepLink.toString() +
            '), skipping auto navigation');
        return;
      }
    } catch (_) {}

    // Web-only: if we have a pending Auth0 access token (set by handleWebCallback),
    // complete the backend login, create/switch account, and route accordingly.
    if (VPlatforms.isWeb) {
      try {
        final pendingToken = VAppPref.getHashedString(
          key: SStorageKeys.pendingAuth0AccessToken.name,
        );
        if (pendingToken != null && pendingToken.isNotEmpty) {
          _log('Completing Auth0 web login from pending token...');

          final deviceHelper = DeviceInfoHelper();
          final pushKey = await (await VChatController.I.vChatConfig.currentPushProviderService)
              ?.getToken(SConstants.webVapidKey);

          final dto = SocialLoginDto(
            accessToken: pendingToken,
            deviceId: await deviceHelper.getId(),
            deviceInfo: await deviceHelper.getDeviceMapInfo(),
            language: VLanguageListener.I.appLocal.languageCode,
            platform: VPlatforms.currentPlatform,
            pushKey: pushKey,
          );

          final authService = GetIt.I.get<AuthApiService>();
          final profileService = GetIt.I.get<ProfileApiService>();

          await authService.auth0Login(dto.toMap());
          final profile = await profileService.getMyProfile();

          // Clear pending token to avoid loops
          await VAppPref.removeKey(SStorageKeys.pendingAuth0AccessToken.name);

          // Cache profile for legacy paths and force AppAuth reload
          await VAppPref.setMap(SStorageKeys.myProfile.name, profile.toMap());
          AppAuth.setProfileNull();

          // Store in multi-account manager
          final accessToken = VAppPref.getHashedString(
                key: SStorageKeys.vAccessToken.name,
              ) ??
              '';
          await MultiAccountManager.instance.addAccount(
            email: profile.email,
            accessToken: accessToken,
            profile: profile,
          );
          final accountId = AccountSession.createAccountId(
            profile.email,
            profile.baseUser.id,
          );
          await MultiAccountManager.instance.switchToAccount(accountId);

          // Mark as pending profile picture to align with login flow
          final pending =
              VAppPref.getList(SStorageKeys.profilePicturePendingAccounts.name) ?? [];
          if (!pending.contains(accountId)) {
            pending.add(accountId);
            await VAppPref.setList(
              SStorageKeys.profilePicturePendingAccounts.name,
              pending,
            );
          }

          // Navigate based on register status
          if (profile.registerStatus == RegisterStatus.accepted) {
            _navigated = true;
            context.toPage(
              ProfilePictureUploadView(
                initialImageUrl: profile.baseUser.userImage,
              ),
              withAnimation: true,
              removeAll: true,
            );
          } else {
            _navigated = true;
            context.toPage(
              WaitingListPage(
                profile: profile,
              ),
              withAnimation: true,
              removeAll: true,
            );
          }
          return; // Done handling auth0 web callback path
        }
      } catch (e) {
        _log('Auth0 web completion failed: ' + e.toString());
        // Fall through to normal navigation in case of error
      }
    }

    if (VPlatforms.isDeskTop) {
      await _setDesktopAutoUpdater();
    }
    if (VPlatforms.isMobile) {
      final request = RequestConfiguration(
        testDeviceIds: [],
      );
      try {
        _log('Initializing MobileAds...');
        await MobileAds.instance
            .initialize()
            .timeout(const Duration(seconds: 3));
        await MobileAds.instance
            .updateRequestConfiguration(request)
            .timeout(const Duration(seconds: 2));
        _log('MobileAds initialized');
      } catch (e) {
        _log('MobileAds init skipped/timed out: ' + e.toString());
      }
    }
    if (VPlatforms.isMobile) {
      try {
        await VFileUtils.refreshAppPath();
      } catch (e) {
        _log('refreshAppPath error: ' + e.toString());
      }
      try {
        await AutoDownloadMediaService().updateMediaDownloadOptionsForData(
          options: const [
            MediaDownloadOptions.images,
            MediaDownloadOptions.videos,
          ],
        );
        await AutoDownloadMediaService().updateMediaDownloadOptionsForWifi(
          options: const [
            MediaDownloadOptions.images,
            MediaDownloadOptions.videos,
          ],
        );
      } catch (e) {
        _log('auto download default error: ' + e.toString());
      }
      try {
        await FileDownloader()
            .trackTasks()
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        _log('trackTasks timeout/err: ' + e.toString());
      }
      try {
        FileDownloader().configureNotificationForGroup(
          "files",
          running: const TaskNotification(
              SConstants.appName, 'File 📁 : {filename}'),
          progressBar: true,
          tapOpensFile: true,
        );
      } catch (e) {
        _log('configureNotificationForGroup err: ' + e.toString());
      }
    }

    await Future.delayed(const Duration(milliseconds: 650));

    // App Lock gate: if enabled, require device authentication before proceeding
    try {
      if (AppLockService.instance.isEnabled &&
          await AppLockService.instance.isSupported()) {
        if (!AppLockService.instance.sessionUnlocked) {
          final ok = await AppLockService.instance.authenticateOnce(context: context);
          if (!ok) {
            // Block on a full-screen lock page; keep Splash underneath
            final res = await Navigator.of(context).push<bool>(
              CupertinoPageRoute(builder: (_) => const AppLockedPage(), fullscreenDialog: true),
            );
            if (res != true) {
              return; // User did not unlock; keep Splash
            }
          }
        }
      }
    } catch (_) {}

    // Initialize multi-account manager
    try {
      _log('Initializing MultiAccountManager...');
      await MultiAccountManager.instance
          .initialize()
          .timeout(const Duration(seconds: 3));
      _log('MultiAccountManager initialized');
    } catch (e) {
      _log('MultiAccountManager init timeout/err: ' + e.toString());
    }

    // Initialize balance service for the current account
    try {
      await BalanceService.instance
          .init()
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      _log('BalanceService init timeout/err: ' + e.toString());
    }

    // Initialize claimed gifts service
    ClaimedGiftsService.instance.init();

    // Check if we have any accounts
    final currentAccount = MultiAccountManager.instance.currentAccount;
    if (DeepLinkService().isInResetFlow) return;
    if (currentAccount != null) {
      // Check if this account still needs to complete the profile picture step
      final pending = VAppPref.getList(SStorageKeys.profilePicturePendingAccounts.name) ?? [];
      final needsProfilePicture = pending.contains(currentAccount.accountId);
      final isImageMissing =
          (currentAccount.profile.baseUser.userImage).trim().isEmpty;
      final isDefault = _isDefaultImage(currentAccount.profile.baseUser.userImage);

      _log('Account found: ' + currentAccount.accountId);
      _log('Pending list: ' + pending.toString());
      _log('Needs profile picture: ' + needsProfilePicture.toString());
      _log('Image missing: ' + isImageMissing.toString() + ', isDefault: ' + isDefault.toString());

      if (currentAccount.profile.registerStatus == RegisterStatus.accepted) {
        if (DeepLinkService().isInResetFlow) return;
        // If we already have a valid image but the pending flag is still set, clear it automatically.
        if (!isImageMissing && !isDefault && needsProfilePicture) {
          try {
            final list = VAppPref.getList(SStorageKeys.profilePicturePendingAccounts.name) ?? [];
            list.removeWhere((e) => e == currentAccount.accountId);
            await VAppPref.setList(SStorageKeys.profilePicturePendingAccounts.name, list);
            _log('Auto-cleared pending profile picture flag for account ${currentAccount.accountId}');
          } catch (_) {}
          // Recompute to avoid false positive routing
          final _needs = (VAppPref.getList(SStorageKeys.profilePicturePendingAccounts.name) ?? [])
              .contains(currentAccount.accountId);
          if (!_needs) {
            _log('Routing to HomeView (multi-account path)');
            await _homeNav();
            return;
          }
        }
        if (needsProfilePicture || isImageMissing) {
          _log('Routing to ProfilePictureUploadView (multi-account path)');
          _navigated = true;
          context.toPage(
            ProfilePictureUploadView(
              initialImageUrl: currentAccount.profile.baseUser.userImage,
            ),
            withAnimation: true,
            removeAll: true,
          );
        } else {
          _log('Routing to HomeView (multi-account path)');
          await _homeNav();
        }
      } else {
        if (DeepLinkService().isInResetFlow) return;
        _log('Routing to WaitingListPage (multi-account path)');
        _navigated = true;
        context.toPage(
          WaitingListPage(
            profile: currentAccount.profile,
          ),
          withAnimation: true,
          removeAll: true,
        );
      }
      return;
    }

    // Fallback to legacy login check for migration
    final isLogin = VAppPref.getBool(SStorageKeys.isLogin.name);
    if (DeepLinkService().isInResetFlow) return;
    if (isLogin) {
      final map = VAppPref.getMap(SStorageKeys.myProfile.name);
      if (map != null) {
        final myProfile = SMyProfile.fromMap(map);
        final accessToken =
            VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);

        // Migrate to multi-account system
        await MultiAccountManager.instance.addAccount(
          email: myProfile.email,
          accessToken: accessToken ?? '',
          profile: myProfile,
        );

        final accountId = AccountSession.createAccountId(
            myProfile.email, myProfile.baseUser.id);
        await MultiAccountManager.instance.switchToAccount(accountId);

        final legacyAccountId = AccountSession.createAccountId(
            myProfile.email, myProfile.baseUser.id);
        final pending = VAppPref.getList(
                SStorageKeys.profilePicturePendingAccounts.name) ??
            [];
        final needsProfilePicture = pending.contains(legacyAccountId);
        final isImageMissing = (myProfile.baseUser.userImage).trim().isEmpty;
        final isDefault = _isDefaultImage(myProfile.baseUser.userImage);

        _log('Legacy account path. AccountId: ' + legacyAccountId);
        _log('Pending list: ' + pending.toString());
        _log('Needs profile picture: ' + needsProfilePicture.toString());
        _log('Image missing: ' + isImageMissing.toString() + ', isDefault: ' + isDefault.toString());

        if (myProfile.registerStatus == RegisterStatus.accepted) {
          if (DeepLinkService().isInResetFlow) return;
          // Auto-clear pending if we already have a valid image
          if (!isImageMissing && !isDefault && needsProfilePicture) {
            try {
              final list = VAppPref.getList(SStorageKeys.profilePicturePendingAccounts.name) ?? [];
              list.removeWhere((e) => e == legacyAccountId);
              await VAppPref.setList(SStorageKeys.profilePicturePendingAccounts.name, list);
              _log('Auto-cleared pending profile picture flag for legacy account $legacyAccountId');
            } catch (_) {}
            final _needs = (VAppPref.getList(SStorageKeys.profilePicturePendingAccounts.name) ?? [])
                .contains(legacyAccountId);
            if (!_needs) {
              _log('Routing to HomeView (legacy path)');
              await _homeNav();
              return;
            }
          }
          if (needsProfilePicture || isImageMissing) {
            _log('Routing to ProfilePictureUploadView (legacy path)');
            _navigated = true;
            context.toPage(
              ProfilePictureUploadView(
                initialImageUrl: myProfile.baseUser.userImage,
              ),
              withAnimation: true,
              removeAll: true,
            );
          } else {
            _log('Routing to HomeView (legacy path)');
            await _homeNav();
          }
        } else {
          if (DeepLinkService().isInResetFlow) return;
          _log('Routing to WaitingListPage (legacy path)');
          _navigated = true;
          context.toPage(
            WaitingListPage(
              profile: myProfile,
            ),
            withAnimation: true,
            removeAll: true,
          );
        }
        return;
      }
    }

    // No accounts found, go to registration
    if (DeepLinkService().isInResetFlow) return;
    _navigated = true;
    context.toPage(
      const RegisterView(),
      withAnimation: true,
      removeAll: true,
    );
  }

  @override
  void onClose() {}

  Future _setDesktopAutoUpdater() async {}

// void checkUpdates() async {
//   if (VPlatforms.isMobile) {
//     final newVersionPlus = NewVersionPlus();
//     try {
//       await newVersionPlus.showAlertIfNecessary(
//           context: navigatorKey.currentState!.context);
//     } catch (err) {
//       if (kDebugMode) print(err);
//     }
//   }
// }

  void _cleanupGetItControllers() {
    // Safely close and unregister controllers to prevent disposed controller errors
    if (GetIt.I.isRegistered<RoomsTabController>()) {
      try {
        GetIt.I.get<RoomsTabController>().onClose();
        GetIt.I.unregister<RoomsTabController>();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }

    if (GetIt.I.isRegistered<CallsTabController>()) {
      try {
        GetIt.I.get<CallsTabController>().onClose();
        GetIt.I.unregister<CallsTabController>();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }

    if (GetIt.I.isRegistered<UsersTabController>()) {
      try {
        GetIt.I.get<UsersTabController>().onClose();
        GetIt.I.unregister<UsersTabController>();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }

    if (GetIt.I.isRegistered<StoryTabController>()) {
      try {
        GetIt.I.unregister<StoryTabController>();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
  }
}
