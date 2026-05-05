// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:email_validator/email_validator.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:super_up/app/modules/auth/auth_utils.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import 'package:v_platform/v_platform.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../core/api_service/auth/auth_api_service.dart';
import '../../../../core/api_service/profile/profile_api_service.dart';
import '../../../home/home_controller/views/home_view.dart';
import '../../waiting_list/views/waiting_list_page.dart';
import '../../profile_picture_upload/views/profile_picture_upload_view.dart';
import '../../register/views/register_otp_modal.dart';
import 'package:super_up/app/core/services/firebase_auth_service.dart';

class LoginController implements SBaseController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthApiService authService;
  final ProfileApiService profileService;
  final bool isAddingAccount;
  bool rememberDevice = false;

  LoginController(
    this.authService,
    this.profileService, {
    this.isAddingAccount = false,
  });

  @override
  onInit() {
    if (kDebugMode) {
      emailController.text = "user1@gmail.com";
      passwordController.text = "12345678";
    }
  }

  void _homeNav(BuildContext context) {
    context.toPage(const HomeView(), removeAll: true, withAnimation: true);
  }

  String _normalizePhoneIdentifier(String raw) {
    var v = (raw).toString().trim();
    v = v.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (v.startsWith('00')) v = '+${v.substring(2)}';
    if (!v.startsWith('+')) return '';
    if (v == '+') return '';
    return v;
  }

  Future<void> login(
    BuildContext context, {
    RegisterMethod method = RegisterMethod.email,
  }) async {
    final identifierRaw = emailController.text.trim();

    String identifier;
    if (method == RegisterMethod.phone) {
      if (identifierRaw.isEmpty) {
        VAppAlert.showErrorSnackBar(
          message: 'Phone number is required',
          context: context,
        );
        return;
      }
      if (RegExp(r'\s').hasMatch(identifierRaw)) {
        await VAppAlert.showOkAlertDialog(
          context: context,
          title: S.of(context).error,
          content: 'Remove spaces from phone number',
        );
        return;
      }
      identifier = _normalizePhoneIdentifier(identifierRaw);
      if (identifier.isEmpty) {
        VAppAlert.showErrorSnackBar(
          message: 'Enter phone number with country code (e.g. +254712345678)',
          context: context,
        );
        return;
      }
    } else {
      if (!EmailValidator.validate(identifierRaw)) {
        VAppAlert.showErrorSnackBar(
          message: S.of(context).emailNotValid,
          context: context,
        );
        return;
      }
      identifier = identifierRaw;
    }
    final password = passwordController.text;

    if (password.isEmpty) {
      VAppAlert.showErrorSnackBar(
        message: S.of(context).passwordMustHaveValue,
        context: context,
      );
      return;
    }
    if (_checkIfLoginNoAllowed()) {
      VAppAlert.showErrorSnackBar(
        message: S.of(context).loginNowAllowedNowPleaseTryAgainLater,
        context: context,
      );
      return;
    }

    // For both email and phone login, use the same flow (phone just uses phone number as identifier)
    await _loginWithEmail(context, identifier, password, method);
  }

  /// Login with email/password (existing flow)
  Future<void> _loginWithEmail(
    BuildContext context,
    String identifier,
    String password,
    RegisterMethod method,
  ) async {
    await vSafeApiCall<SMyProfile>(
      onLoading: () async {
        VAppAlert.showLoading(context: context);
      },
      onError: (exception, trace) {
        if (kDebugMode) {
          print(trace);
        }
        Navigator.of(context).pop();
        final errEnum = EnumToString.fromString(
          ApiI18nErrorRes.values,
          exception.toString(),
        );
        VAppAlert.showOkAlertDialog(
          context: context,
          title: S.of(context).error,
          content: AuthTrUtils.tr(errEnum) ?? exception.toString(),
        );
      },
      request: () async {
        final deviceHelper = DeviceInfoHelper();
        final deviceInfo = await deviceHelper.getDeviceMapInfo();
        final deviceId = await deviceHelper.getId();
        final pushKey = await (await VChatController
                .I.vChatConfig.currentPushProviderService)
            ?.getToken(
          VPlatforms.isWeb ? SConstants.webVapidKey : null,
        );

        final res = await authService.login(LoginDto(
          email: identifier,
          method: method,
          pushKey: pushKey,
          deviceInfo: deviceInfo,
          deviceId: deviceId,
          language: VLanguageListener.I.appLocal.languageCode,
          platform: VPlatforms.currentPlatform,
          password: password,
        ));

        // Handle two-factor challenge
        if (res['twoFactorRequired'] == true) {
          // Ask user to input the code sent to their email
          final inputs = await showTextInputDialog(
            context: context,
            title: 'Two-Factor Authentication',
            message:
                'We sent a 6-digit verification code to your email. Enter it below to complete sign-in.',
            textFields: const [
              DialogTextField(
                hintText: '6-digit code',
                keyboardType: TextInputType.number,
              ),
            ],
          );
          if (inputs == null || inputs.isEmpty || inputs.first.trim().isEmpty) {
            throw 'Two-factor code is required to sign in';
          }
          final code = inputs.first.trim();
          await authService.twoFactorVerify({
            'ticket': res['ticket'],
            'code': code,
            'deviceId': deviceId,
            'platform': VPlatforms.currentPlatform,
            'language': VLanguageListener.I.appLocal.languageCode,
            'deviceInfo': deviceInfo,
            'pushKey': pushKey,
            'rememberDevice': this.rememberDevice,
          });
        }

        return profileService.getMyProfile();
      },
      onSuccess: (response) => _handleLoginSuccess(context, identifier, response),
      ignoreTimeoutAndNoInternet: false,
    );
  }

  /// Login with Firebase Phone Auth
  Future<void> _loginWithFirebasePhone(
    BuildContext context,
    String phoneNumber,
    String password,
  ) async {
    VAppAlert.showLoading(context: context, message: 'Sending verification code...');

    await FirebaseAuthService.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId, resendToken) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();

        showCupertinoDialog(
          context: context,
          builder: (mCtx) => RegisterOtpModal(
            email: phoneNumber,
            isFirebasePhoneAuth: true,
            onOtpVerified: (otp, resetLoading) async {
              try {
                VAppAlert.showLoading(context: mCtx);
                final idToken = await FirebaseAuthService.verifyCode(otp);
                if (idToken == null) {
                  throw Exception('Failed to get Firebase ID token');
                }
                await _completeFirebasePhoneLogin(
                  context: context,
                  idToken: idToken,
                  password: password,
                  dialogCtx: mCtx,
                );
              } catch (e) {
                if (Navigator.of(mCtx).canPop()) Navigator.of(mCtx).pop();
                VAppAlert.showOkAlertDialog(
                  context: mCtx,
                  title: S.of(mCtx).error,
                  content: e.toString(),
                );
              } finally {
                resetLoading();
              }
            },
            onResendOtp: () async {
              try {
                await FirebaseAuthService.resendCode(
                  phoneNumber: phoneNumber,
                  onCodeSent: (_, __) {
                    VAppAlert.showSuccessSnackBar(
                      context: context,
                      message: 'Code resent',
                    );
                  },
                  onError: (error) {
                    VAppAlert.showOkAlertDialog(
                      context: context,
                      title: S.of(context).error,
                      content: error,
                    );
                  },
                );
              } catch (e) {
                VAppAlert.showOkAlertDialog(
                  context: context,
                  title: S.of(context).error,
                  content: e.toString(),
                );
              }
            },
          ),
        );
      },
      onError: (error) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        VAppAlert.showOkAlertDialog(
          context: context,
          title: S.of(context).error,
          content: error,
        );
      },
      onAutoVerified: () {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
    );
  }

  /// Complete Firebase Phone Auth login
  Future<void> _completeFirebasePhoneLogin({
    required BuildContext context,
    required String idToken,
    required String password,
    required BuildContext dialogCtx,
  }) async {
    final deviceHelper = DeviceInfoHelper();
    final deviceInfo = await deviceHelper.getDeviceMapInfo();
    final deviceId = await deviceHelper.getId();
    final pushKey = await (await VChatController
            .I.vChatConfig.currentPushProviderService)
        ?.getToken(
      VPlatforms.isWeb ? SConstants.webVapidKey : null,
    );

    final res = await authService.firebasePhoneLogin(
      idToken: idToken,
      password: password,
      deviceId: deviceId,
      platform: VPlatforms.currentPlatform.toString(),
      language: VLanguageListener.I.appLocal.languageCode,
      deviceInfo: deviceInfo,
      pushKey: pushKey,
    );

    // Clear Firebase auth state
    await FirebaseAuthService.signOut();
    FirebaseAuthService.clearState();

    // Handle two-factor challenge if needed
    if (res['twoFactorRequired'] == true) {
      // Ask user to input the code sent to their email
      final inputs = await showTextInputDialog(
        context: context,
        title: 'Two-Factor Authentication',
        message:
            'We sent a 6-digit verification code to your email. Enter it below to complete sign-in.',
        textFields: const [
          DialogTextField(
            hintText: '6-digit code',
            keyboardType: TextInputType.number,
          ),
        ],
      );
      if (inputs == null || inputs.isEmpty || inputs.first.trim().isEmpty) {
        throw 'Two-factor code is required to sign in';
      }
      final code = inputs.first.trim();
      await authService.twoFactorVerify({
        'ticket': res['ticket'],
        'code': code,
        'deviceId': deviceId,
        'platform': VPlatforms.currentPlatform.toString(),
        'language': VLanguageListener.I.appLocal.languageCode,
        'deviceInfo': deviceInfo,
        'pushKey': pushKey,
        'rememberDevice': this.rememberDevice,
      });
    }

    final profile = await profileService.getMyProfile();
    _handleLoginSuccess(context, emailController.text.trim(), profile);
  }

  /// Handle successful login
  void _handleLoginSuccess(
    BuildContext context,
    String identifier,
    SMyProfile response,
  ) async {
    final status = response.registerStatus;

    // Get the access token that was stored during login
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);

    // Add account to multi-account manager
    await MultiAccountManager.instance.addAccount(
      email: identifier,
      accessToken: accessToken ?? '',
      profile: response,
    );

    // Switch to this account
    final accountId =
        AccountSession.createAccountId(identifier, response.baseUser.id);
    await MultiAccountManager.instance.switchToAccount(accountId);

    // Initialize balance service for the new account
    await BalanceService.instance.init();

    // Request notification permissions after successful login on iOS
    if (VPlatforms.isIOS) {
      _requestNotificationPermissionsAfterLogin();
    }

    // --- CRITICAL PERF OPTIMIZATION ---
    // Pre-fetch rooms during the login dialog so the Home screen is EXACTLY INSTANT
    try {
      final currentAccountId = accountId;
      final lastDbAccountId = VAppPref.getStringOrNullKey(SStorageKeys.lastChatDbAccountId.name);
      if (lastDbAccountId != currentAccountId) {
        await VChatController.I.nativeApi.local.reCreate();
        await VAppPref.setStringKey(SStorageKeys.lastChatDbAccountId.name, currentAccountId);
      }
      
      final apiResponse = await VChatController.I.nativeApi.remote.room.getRooms(const VRoomsDto(limit: 20));
      await VChatController.I.nativeApi.local.room.cacheRooms(apiResponse.data, deleteOnEmpty: false);
      if (kDebugMode) {
        print('[LoginController] successfully pre-fetched ${apiResponse.data.length} rooms during login');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LoginController] failed to pre-fetch rooms during login: $e');
      }
    }

    if (status == RegisterStatus.accepted) {
      if (isAddingAccount) {
        // When adding a new account, go back to settings
        Navigator.of(context).pop();
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: S.of(context).accountAddedSuccessfully,
        );
      } else {
        // Check if profile picture is missing
        if (response.baseUser.userImage.isEmpty) {
          // Force user to upload profile picture
          context.toPage(
            ProfilePictureUploadView(
              initialImageUrl: '',
            ),
            withAnimation: true,
            removeAll: true,
          );
        } else {
          // Profile picture exists, go to home
          _homeNav(context);
        }
      }
    } else {
      context.toPage(
        WaitingListPage(
          profile: response,
        ),
        withAnimation: true,
        removeAll: true,
      );
    }
  }

  Future<void> vSafeApiCall<T>({
    required Future<void> Function() onLoading,
    required void Function(dynamic exception, dynamic trace) onError,
    required Future<T> Function() request,
    required void Function(T response) onSuccess,
    required bool ignoreTimeoutAndNoInternet,
  }) async {
    try {
      await onLoading();
      final response = await request();
      onSuccess(response);
    } catch (exception, trace) {
      onError(exception, trace);
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
  }

  void facebook() {}

  void apple() {}

  void google() {}

  bool _checkIfLoginNoAllowed() {
    if (VPlatforms.isMobile &&
        !VAppConfigController.appConfig.allowMobileLogin) {
      return true;
    }
    if (VPlatforms.isWeb && !VAppConfigController.appConfig.allowWebLogin) {
      return true;
    }
    if (VPlatforms.isDeskTop &&
        !VAppConfigController.appConfig.allowDesktopLogin) {
      return true;
    }
    return false;
  }

  /// Request notification permissions after successful login on iOS
  void _requestNotificationPermissionsAfterLogin() async {
    try {
      // Request notification permission using permission_handler
      final notificationPermission = await Permission.notification.request();
      print('iOS notification permission after login: $notificationPermission');

      // Request FCM permissions
      final pushService =
          await VChatController.I.vChatConfig.currentPushProviderService;
      if (pushService != null) {
        await pushService.askForPermissions();
        print('iOS FCM permissions requested after login');

        try {
          final token = await pushService.getToken(
            VPlatforms.isWeb ? SConstants.webVapidKey : null,
          );
          if (token != null && token.isNotEmpty) {
            await VChatController.I.nativeApi.remote.profile.addPushKey(
              fcm: token,
              voipKey: null,
            );
            print('iOS FCM token synced after login: ${token.substring(0, 20)}...');
          }
        } catch (e) {
          print('Error syncing FCM token after login: $e');
        }
      }

      // Also request local notification permissions using flutter_local_notifications
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      final iosImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      if (iosImplementation != null) {
        final localPermissionResult =
            await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: true,
        );
        print(
            'Local notification permission after login: $localPermissionResult');
      }
    } catch (e) {
      print('Error requesting notification permissions after login: $e');
    }
  }
}
