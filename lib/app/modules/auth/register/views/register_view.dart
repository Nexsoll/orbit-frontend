import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:email_validator/email_validator.dart';

import '../../widgets/auth_header.dart';
import '../../widgets/social_login_buttons.dart';
import '../../../../core/api_service/auth/auth_api_service.dart';
import '../../../../core/api_service/profile/profile_api_service.dart';
import '../../../../core/widgets/wide_constraints.dart';
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:super_up/app/core/services/firebase_auth_service.dart';
import 'package:super_up/app/core/services/firebase_auth_service_web.dart';
import '../../login/views/login_view.dart';
import '../../waiting_list/views/waiting_list_page.dart';
import 'package:super_up/app/modules/home/settings_modules/my_account/views/sheet_for_select_profession.dart';
import '../views/register_otp_modal.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/modules/auth/profile_picture_upload/views/profile_picture_upload_view.dart';

class RegisterView extends StatefulWidget {
  final String? initialEmail;
  final bool showBackButton;

  const RegisterView({
    Key? key,
    this.initialEmail,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  late final AuthApiService _authService;
  late final ProfileApiService _profileService;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _professionController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  RegisterMethod _registerMethod = RegisterMethod.email;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _profession;

  @override
  void initState() {
    super.initState();
    _authService = GetIt.I.get<AuthApiService>();
    _profileService = GetIt.I.get<ProfileApiService>();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _professionController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _normalizePhoneIdentifier(String raw) {
    var v = (raw).toString().trim();
    v = v.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (v.startsWith('00')) v = '+${v.substring(2)}';
    if (!v.startsWith('+')) return '';
    if (v == '+') return '';
    return v;
  }

  Future<void> _selectProfession() async {
    final selected = await showCupertinoModalBottomSheet<String>(
      expand: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const SheetForSelectProfession(),
    );
    if (selected == null || selected.trim().isEmpty) return;
    setState(() {
      _profession = selected.trim();
      _professionController.text = _profession!;
    });
  }

  Future<void> _startRegisterFlow() async {
    final name = _nameController.text.trim();
    final identifierRaw = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final profession = _profession?.trim();

    if (name.isEmpty) {
      VAppAlert.showErrorSnackBar(message: 'Full name is required', context: context);
      return;
    }
    final method = _registerMethod;
    String identifier;

    if (method == RegisterMethod.email) {
      if (!EmailValidator.validate(identifierRaw)) {
        VAppAlert.showErrorSnackBar(message: S.of(context).emailNotValid, context: context);
        return;
      }
      identifier = identifierRaw;
    } else {
      if (identifierRaw.isEmpty) {
        VAppAlert.showErrorSnackBar(message: 'Phone number is required', context: context);
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
    }
    if (password.isEmpty || password.length < 8) {
      VAppAlert.showErrorSnackBar(message: S.of(context).passwordMustHaveValue, context: context);
      return;
    }
    if (password != confirm) {
      VAppAlert.showErrorSnackBar(message: S.of(context).passwordNotMatch, context: context);
      return;
    }

    if (profession == null || profession.isEmpty) {
      VAppAlert.showErrorSnackBar(message: 'Profession is required', context: context);
      return;
    }

    // For phone registration, use Firebase Phone Auth
    if (method == RegisterMethod.phone) {
      await _startFirebasePhoneRegistration(identifier, name, password, profession);
      return;
    }

    // For email registration, use existing link-based flow
    try {
      VAppAlert.showLoading(context: context);
      // Send registration data with verification link
      await _authService.sendLinkRegister(
        identifier,
        name,
        password,
        profession: profession,
        method: method,
      );
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();

      if (!mounted) return;
      // Show simple success message
      showCupertinoDialog(
        context: context,
        builder: (mCtx) => CupertinoAlertDialog(
          title: Text(method == RegisterMethod.phone ? 'Check your phone' : 'Check your email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                method == RegisterMethod.phone
                    ? 'We\'ve sent a verification link to\n$identifier.\n\nClick the link to verify your phone number and create your account.'
                    : 'We\'ve sent a verification link to\n$identifier.\n\nClick the link to verify your email and create your account.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(mCtx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  CupertinoPageRoute(
                    builder: (_) => const LoginView(),
                  ),
                  (route) => false,
                );
              },
              isDefaultAction: true,
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      // Check if it's the fallback OTP case
      final shouldFallbackToOTP = e.toString().contains('404') || e.toString().contains('Not Found');
      if (shouldFallbackToOTP && method == RegisterMethod.email) {
        // Fallback to OTP
        try {
          VAppAlert.showLoading(context: context);
          await _authService.sendOtpRegister(identifier);
          if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
          if (!mounted) return;
          showCupertinoDialog(
            context: context,
            builder: (mCtx) => RegisterOtpModal(
              email: identifier,
              onOtpVerified: (otp, resetLoading) async {
                try {
                  VAppAlert.showLoading(context: mCtx);
                  await _authService.verifyOtpRegister(email: identifier, code: otp);
                  await _completeRegistration(name, identifier, password, mCtx, method: method);
                } catch (e) {
                  VAppAlert.showOkAlertDialog(
                    context: mCtx,
                    title: S.of(context).error,
                    content: e.toString(),
                  );
                } finally {
                  if (Navigator.of(mCtx).canPop()) Navigator.of(mCtx).pop();
                  resetLoading();
                }
              },
              onResendOtp: () async {
                try {
                  await _authService.sendOtpRegister(identifier);
                  VAppAlert.showSuccessSnackBar(
                    context: context,
                    message: 'OTP resent',
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
        } catch (e2) {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          VAppAlert.showOkAlertDialog(
            context: context,
            title: S.of(context).error,
            content: e2.toString(),
          );
        }
      } else {
        VAppAlert.showOkAlertDialog(
          context: context,
          title: S.of(context).error,
          content: e.toString(),
        );
      }
    }
  }

  /// Start Firebase Phone Auth registration flow
  Future<void> _startFirebasePhoneRegistration(
    String phoneNumber,
    String name,
    String password,
    String profession,
  ) async {
    VAppAlert.showLoading(context: context, message: 'Sending verification code...');

    // Use web Firebase service for web platform, mobile service for mobile
    if (VPlatforms.isWeb) {
      await _startFirebasePhoneRegistrationWeb(phoneNumber, name, password, profession);
    } else {
      await _startFirebasePhoneRegistrationMobile(phoneNumber, name, password, profession);
    }
  }

  /// Web-specific Firebase Phone Auth registration
  Future<void> _startFirebasePhoneRegistrationWeb(
    String phoneNumber,
    String name,
    String password,
    String profession,
  ) async {
    await FirebaseAuthServiceWeb.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId, resendToken) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        if (!mounted) return;

        showCupertinoDialog(
          context: context,
          builder: (mCtx) => RegisterOtpModal(
            email: phoneNumber,
            isFirebasePhoneAuth: true,
            onOtpVerified: (otp, resetLoading) async {
              try {
                VAppAlert.showLoading(context: mCtx);
                final idToken = await FirebaseAuthServiceWeb.verifyCode(otp);
                if (idToken == null) {
                  throw Exception('Failed to get Firebase ID token');
                }
                await _completeFirebasePhoneRegistration(
                  idToken: idToken,
                  name: name,
                  password: password,
                  profession: profession,
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
                await FirebaseAuthServiceWeb.resendCode(
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

  /// Mobile-specific Firebase Phone Auth registration
  Future<void> _startFirebasePhoneRegistrationMobile(
    String phoneNumber,
    String name,
    String password,
    String profession,
  ) async {

    await FirebaseAuthService.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId, resendToken) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        if (!mounted) return;

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
                await _completeFirebasePhoneRegistration(
                  idToken: idToken,
                  name: name,
                  password: password,
                  profession: profession,
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
        // Auto-verified on Android
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
    );
  }

  /// Complete Firebase Phone Auth registration
  Future<void> _completeFirebasePhoneRegistration({
    required String idToken,
    required String name,
    required String password,
    required String profession,
    required BuildContext dialogCtx,
  }) async {
    final deviceHelper = DeviceInfoHelper();
    final deviceInfo = await deviceHelper.getDeviceMapInfo();
    final deviceId = await deviceHelper.getId();
    final pushKey = await (await VChatController.I.vChatConfig.currentPushProviderService)
        ?.getToken(VPlatforms.isWeb ? SConstants.webVapidKey : null);

    await _authService.firebasePhoneRegister(
      idToken: idToken,
      fullName: name,
      password: password,
      deviceId: deviceId,
      platform: VPlatforms.currentPlatform.toString(),
      profession: profession,
      language: VLanguageListener.I.appLocal.languageCode,
      deviceInfo: deviceInfo,
      pushKey: pushKey,
    );

    // Clear Firebase auth state
    await FirebaseAuthService.signOut();
    FirebaseAuthService.clearState();

    final profile = await _profileService.getMyProfile();

    // Save to multi-account manager
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name) ?? '';
    final identifier = _emailController.text.trim();
    await MultiAccountManager.instance.addAccount(
      email: identifier,
      accessToken: accessToken,
      profile: profile,
    );
    final accountId = AccountSession.createAccountId(identifier, profile.baseUser.id);
    await MultiAccountManager.instance.switchToAccount(accountId);

    // Initialize balance for the new account
    await BalanceService.instance.init();

    if (!mounted) return;

    if (profile.registerStatus == RegisterStatus.accepted) {
      Navigator.of(dialogCtx).pushAndRemoveUntil(
        CupertinoPageRoute(
          builder: (_) => ProfilePictureUploadView(
            initialImageUrl: profile.baseUser.userImage,
          ),
        ),
        (route) => false,
      );
    } else {
      Navigator.of(dialogCtx).pushAndRemoveUntil(
        CupertinoPageRoute(
          builder: (_) => WaitingListPage(profile: profile),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _completeRegistration(
      String name, String identifier, String password, BuildContext dialogCtx, {
        RegisterMethod method = RegisterMethod.email,
      }) async {
    final deviceHelper = DeviceInfoHelper();
    final deviceInfo = await deviceHelper.getDeviceMapInfo();
    final deviceId = await deviceHelper.getId();
    final pushKey = await (await VChatController.I.vChatConfig.currentPushProviderService)
        ?.getToken(VPlatforms.isWeb ? SConstants.webVapidKey : null);

    final dto = RegisterDto(
      email: identifier,
      method: method,
      fullName: name,
      deviceId: deviceId,
      language: VLanguageListener.I.appLocal.languageCode,
      pushKey: pushKey,
      deviceInfo: deviceInfo,
      platform: VPlatforms.currentPlatform,
      password: password,
      profession: _profession,
    );

    await _authService.register(dto);
    final profile = await _profileService.getMyProfile();

    // Save to multi-account manager
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name) ?? '';
    await MultiAccountManager.instance.addAccount(
      email: identifier,
      accessToken: accessToken,
      profile: profile,
    );
    final accountId = AccountSession.createAccountId(identifier, profile.baseUser.id);
    await MultiAccountManager.instance.switchToAccount(accountId);

    // Initialize balance for the new account
    await BalanceService.instance.init();

    if (!mounted) return;

    if (profile.registerStatus == RegisterStatus.accepted) {
      Navigator.of(dialogCtx).pushAndRemoveUntil(
        CupertinoPageRoute(
          builder: (_) => ProfilePictureUploadView(
            initialImageUrl: profile.baseUser.userImage,
          ),
        ),
        (route) => false,
      );
    } else {
      Navigator.of(dialogCtx).pushAndRemoveUntil(
        CupertinoPageRoute(
          builder: (_) => WaitingListPage(profile: profile),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) => WideConstraints(
        enable: sizingInformation.isDesktop,
        child: CupertinoPageScaffold(
          navigationBar: widget.showBackButton
              ? CupertinoNavigationBar(
                  transitionBetweenRoutes: false,
                  leading: CupertinoNavigationBarBackButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  middle: Text(S.of(context).register),
                  backgroundColor:
                      CupertinoColors.systemBackground.resolveFrom(context),
                )
              : null,
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (!widget.showBackButton) const AuthHeader(),
                  if (widget.showBackButton)
                    const SizedBox(height: 20),
                  SizedBox(height: context.height * .02),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        STextFiled(
                          controller: _nameController,
                          textHint: 'Full name',
                          prefix: const Icon(Icons.person_outline, color: Colors.black),
                          autocorrect: false,
                          inputType: TextInputType.name,
                        ),
                        const SizedBox(height: 20),

                        STextFiled(
                          controller: _emailController,
                          textHint: _registerMethod == RegisterMethod.phone
                              ? 'Phone number (e.g. +254712345678)'
                              : S.of(context).email,
                          prefix: _registerMethod == RegisterMethod.phone
                              ? const Icon(CupertinoIcons.phone, color: Colors.black)
                              : const Icon(Icons.email_outlined, color: Colors.black),
                          autocorrect: false,
                          inputType: _registerMethod == RegisterMethod.phone
                              ? TextInputType.phone
                              : TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 8),
                        // Toggle between email and phone registration
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _registerMethod = _registerMethod == RegisterMethod.email
                                    ? RegisterMethod.phone
                                    : RegisterMethod.email;
                                _emailController.clear();
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _registerMethod == RegisterMethod.email
                                        ? CupertinoIcons.phone
                                        : Icons.email_outlined,
                                    size: 16,
                                    color: const Color(0xFFB48648),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _registerMethod == RegisterMethod.email
                                        ? 'Use phone number instead'
                                        : 'Use email instead',
                                    style: const TextStyle(
                                      color: Color(0xFFB48648),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _selectProfession,
                          child: AbsorbPointer(
                            child: STextFiled(
                              controller: _professionController,
                              textHint: 'Profession',
                              prefix: const Icon(CupertinoIcons.briefcase, color: Colors.black),
                              autocorrect: false,
                              readOnly: true,
                              suffix: const Icon(Icons.arrow_drop_down, color: Colors.black),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        STextFiled(
                          controller: _passwordController,
                          textHint: S.of(context).password,
                          prefix: const Icon(CupertinoIcons.lock_fill, color: Colors.black),
                          autocorrect: false,
                          obscureText: !_isPasswordVisible,
                          inputType: TextInputType.text,
                          suffix: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        STextFiled(
                          controller: _confirmPasswordController,
                          textHint: S.of(context).confirmPassword,
                          prefix: const Icon(CupertinoIcons.lock_fill, color: Colors.black),
                          autocorrect: false,
                          obscureText: !_isConfirmPasswordVisible,
                          inputType: TextInputType.text,
                          suffix: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                        SElevatedButton(
                          title: 'Register',
                          onPress: _startRegisterFlow,
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: const [
                            Expanded(child: Divider(color: Colors.black)),
                            SizedBox(width: 10),
                            Text('Or sign up with', style: TextStyle(color: Colors.black)),
                            SizedBox(width: 10),
                            Expanded(child: Divider(color: Colors.black)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Center(
                          child: SocialLoginButtons(
                            authService: _authService,
                            profileService: _profileService,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account?'),
                            const SizedBox(width: 5),
                            GestureDetector(
                              onTap: () {
                                context.toPage(const LoginView());
                              },
                              child: const Text(
                                'Login',
                                style: TextStyle(color: Color(0xFFB48648)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

