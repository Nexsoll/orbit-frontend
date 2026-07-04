import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:pinput/pinput.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:super_up/app/core/services/firebase_auth_service.dart';
import 'package:super_up/app/modules/auth/profile_picture_upload/views/profile_picture_upload_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../../../core/api_service/auth/auth_api_service.dart';
import '../../../../core/api_service/profile/profile_api_service.dart';
import '../../../../core/widgets/wide_constraints.dart';
import '../../login/views/login_view.dart';
import '../../waiting_list/views/waiting_list_page.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/social_login_buttons.dart';
import 'package:super_up/app/modules/home/settings_modules/my_account/views/sheet_for_select_profession.dart';

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

  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _professionController = TextEditingController();
  final _dateOfBirthController = TextEditingController();

  RegisterMethod _registerMethod = RegisterMethod.email;
  int _step = 0;
  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _profession;
  DateTime? _dateOfBirth;
  String? _firebasePhoneIdToken;

  @override
  void initState() {
    super.initState();
    _authService = GetIt.I.get<AuthApiService>();
    _profileService = GetIt.I.get<ProfileApiService>();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _identifierController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _professionController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  String get _identifier => _registerMethod == RegisterMethod.phone
      ? _normalizePhoneIdentifier(_identifierController.text)
      : _identifierController.text.trim().toLowerCase();

  String _normalizePhoneIdentifier(String raw) {
    var v = raw.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (v.startsWith('00')) v = '+${v.substring(2)}';
    if (!v.startsWith('+')) return '';
    if (v == '+') return '';
    return v;
  }

  String _formatDateOfBirth(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> _sendOtp() async {
    final identifier = _identifier;
    if (_registerMethod == RegisterMethod.email &&
        !EmailValidator.validate(identifier)) {
      VAppAlert.showErrorSnackBar(
          message: S.of(context).emailNotValid, context: context);
      return;
    }
    if (_registerMethod == RegisterMethod.phone && identifier.isEmpty) {
      VAppAlert.showErrorSnackBar(
        message: 'Enter phone number with country code (e.g. +254712345678)',
        context: context,
      );
      return;
    }
    await _run(() async {
      if (_registerMethod == RegisterMethod.phone) {
        await FirebaseAuthService.verifyPhoneNumber(
          phoneNumber: identifier,
          onCodeSent: (_, __) {
            if (!mounted) return;
            _firebasePhoneIdToken = null;
            _otpController.clear();
            setState(() => _step = 1);
          },
          onError: (error) {
            if (!mounted) return;
            VAppAlert.showOkAlertDialog(
              context: context,
              title: S.of(context).error,
              content: error,
            );
          },
          onAutoVerified: () async {
            final idToken = await FirebaseAuthService.getIdToken();
            if (!mounted || idToken == null || idToken.isEmpty) return;
            _firebasePhoneIdToken = idToken;
            _otpController.clear();
            setState(() => _step = 2);
          },
        );
        return;
      }

      await _authService.sendOtpRegister(identifier, method: _registerMethod);
      _otpController.clear();
      setState(() => _step = 1);
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().length != 6) {
      VAppAlert.showErrorSnackBar(
          message: 'Please enter a valid 6-digit OTP', context: context);
      return;
    }
    await _run(() async {
      if (_registerMethod == RegisterMethod.phone) {
        final idToken =
            await FirebaseAuthService.verifyCode(_otpController.text.trim());
        if (idToken == null || idToken.isEmpty) {
          throw Exception('Failed to verify phone number');
        }
        _firebasePhoneIdToken = idToken;
        setState(() => _step = 2);
        return;
      }

      await _authService.verifyOtpRegister(
          email: _identifier, code: _otpController.text.trim());
      setState(() => _step = 2);
    });
  }

  Future<void> _finishRegistration() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final fullName = _nameController.text.trim();
    final profession = _profession?.trim();
    final dob = _dateOfBirthController.text.trim();

    if (password.length < 8) {
      VAppAlert.showErrorSnackBar(
          message: S.of(context).passwordMustHaveValue, context: context);
      setState(() => _step = 2);
      return;
    }
    if (password != confirm) {
      VAppAlert.showErrorSnackBar(
          message: S.of(context).passwordNotMatch, context: context);
      setState(() => _step = 2);
      return;
    }
    if (fullName.isEmpty) {
      VAppAlert.showErrorSnackBar(
          message: 'Full name is required', context: context);
      return;
    }
    if (profession == null || profession.isEmpty) {
      VAppAlert.showErrorSnackBar(
          message: 'Profession is required', context: context);
      return;
    }
    if (dob.isEmpty) {
      VAppAlert.showErrorSnackBar(
          message: 'Date of birth is required', context: context);
      return;
    }

    await _run(() async {
      final deviceHelper = DeviceInfoHelper();
      final pushKey =
          await (await VChatController.I.vChatConfig.currentPushProviderService)
              ?.getToken(VPlatforms.isWeb ? SConstants.webVapidKey : null);
      final deviceId = await deviceHelper.getId();
      final deviceInfo = await deviceHelper.getDeviceMapInfo();

      if (_registerMethod == RegisterMethod.phone) {
        final idToken =
            _firebasePhoneIdToken ?? await FirebaseAuthService.getIdToken();
        if (idToken == null || idToken.isEmpty) {
          throw Exception(
              'Phone verification expired. Please verify your phone again.');
        }
        await _authService.firebasePhoneRegister(
          idToken: idToken,
          fullName: fullName,
          password: password,
          deviceId: deviceId,
          language: VLanguageListener.I.appLocal.languageCode,
          pushKey: pushKey,
          deviceInfo: deviceInfo,
          platform: VPlatforms.currentPlatform.toString(),
          profession: profession,
          dateOfBirth: dob,
        );
        await FirebaseAuthService.signOut();
        FirebaseAuthService.clearState();
      } else {
        await _authService.register(
          RegisterDto(
            email: _identifier,
            method: _registerMethod,
            fullName: fullName,
            deviceId: deviceId,
            language: VLanguageListener.I.appLocal.languageCode,
            pushKey: pushKey,
            deviceInfo: deviceInfo,
            platform: VPlatforms.currentPlatform.toString(),
            password: password,
            profession: profession,
            dateOfBirth: dob,
          ),
        );
      }
      final profile = await _profileService.getMyProfile();
      await VAppPref.setMap(SStorageKeys.myProfile.name, profile.toMap());
      AppAuth.setProfileNull();
      final accessToken =
          VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name) ?? '';
      await MultiAccountManager.instance.addAccount(
        email: profile.email,
        accessToken: accessToken,
        profile: profile,
      );
      final accountId =
          AccountSession.createAccountId(profile.email, profile.baseUser.id);
      await MultiAccountManager.instance.switchToAccount(accountId);
      await BalanceService.instance.init();
      if (!mounted) return;
      if (profile.registerStatus == RegisterStatus.accepted) {
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(
            builder: (_) => ProfilePictureUploadView(
                initialImageUrl: profile.baseUser.userImage),
          ),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => WaitingListPage(profile: profile)),
          (route) => false,
        );
      }
    });
  }

  Future<void> _run(Future<void> Function() body) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await body();
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showOkAlertDialog(
          context: context, title: S.of(context).error, content: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final initialDate =
        _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    DateTime selected = initialDate;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (modalContext) => Container(
        height: 310,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(modalContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      setState(() {
                        _dateOfBirth = selected;
                        _dateOfBirthController.text =
                            _formatDateOfBirth(selected);
                      });
                      Navigator.of(modalContext).pop();
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                maximumDate: now,
                minimumYear: 1900,
                maximumYear: now.year,
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextFromPassword() {
    if (_passwordController.text.length < 8) {
      VAppAlert.showErrorSnackBar(
          message: S.of(context).passwordMustHaveValue, context: context);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      VAppAlert.showErrorSnackBar(
          message: S.of(context).passwordNotMatch, context: context);
      return;
    }
    setState(() => _step = 3);
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
                  backgroundColor:
                      CupertinoColors.systemBackground.resolveFrom(context),
                )
              : null,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  24, widget.showBackButton ? 8 : 40, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.showBackButton) const AuthHeader(),
                  if (!widget.showBackButton) const SizedBox(height: 20),
                  _buildProgressBar(),
                  const SizedBox(height: 32),
                  _headerTexts(),
                  const SizedBox(height: 32),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(0.02, 0), end: Offset.zero)
                            .animate(animation),
                        child: child,
                      ),
                    ),
                    child: _stepBody(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: List.generate(4, (index) {
        final isActive = index <= _step;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFB48648) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _headerTexts() {
    String title = '';
    String sub = '';
    switch (_step) {
      case 0:
        title = "Join Orbit";
        sub = "Choose how to register";
        break;
      case 1:
        title = "Verification";
        sub = "Enter the 6-digit code sent to $_identifier";
        break;
      case 2:
        title = "Security";
        sub = "Create a strong password";
        break;
      case 3:
        title = "Almost Done";
        sub = "Tell us a bit about yourself";
        break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(
          sub,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 1:
        return _otpStep();
      case 2:
        return _passwordStep();
      case 3:
        return _personalStep();
      default:
        return _identityStep();
    }
  }

  Widget _identityStep() {
    return Column(
      key: const ValueKey('identity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialLoginButtons(
            authService: _authService, profileService: _profileService),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade200)),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('or continue with',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 14))),
            Expanded(child: Divider(color: Colors.grey.shade200)),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              _tab(RegisterMethod.email, CupertinoIcons.mail, 'Email'),
              _tab(RegisterMethod.phone, CupertinoIcons.phone, 'Phone'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        STextFiled(
          controller: _identifierController,
          textHint: _registerMethod == RegisterMethod.email
              ? S.of(context).email
              : 'Phone number (e.g. +254712345678)',
          prefix: Icon(
              _registerMethod == RegisterMethod.email
                  ? CupertinoIcons.mail
                  : CupertinoIcons.phone,
              color: Colors.grey.shade600),
          autocorrect: false,
          inputType: _registerMethod == RegisterMethod.email
              ? TextInputType.emailAddress
              : TextInputType.phone,
        ),
        const SizedBox(height: 32),
        _primaryButton('Continue', _sendOtp),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () => context.toPage(const LoginView()),
            child: RichText(
              text: TextSpan(
                text: 'Already have an account? ',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                children: const [
                  TextSpan(
                      text: 'Log in',
                      style: TextStyle(
                          color: Color(0xFFB48648),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _otpStep() {
    final pinTheme = PinTheme(
      width: 60,
      height: 68,
      textStyle: const TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
    );
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pinput(
          controller: _otpController,
          length: 6,
          defaultPinTheme: pinTheme,
          focusedPinTheme: pinTheme.copyDecorationWith(
              border: Border.all(color: const Color(0xFFB48648), width: 2),
              color: Colors.white),
          submittedPinTheme: pinTheme.copyDecorationWith(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300, width: 1.5)),
          onCompleted: (_) => _verifyOtp(),
        ),
        const SizedBox(height: 32),
        _primaryButton('Verify OTP', _verifyOtp),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _sendOtp,
            child: const Text('Resend code',
                style: TextStyle(
                    color: Color(0xFFB48648),
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _loading ? null : () => setState(() => _step = 0),
            child: Text(
                'Change ${_registerMethod == RegisterMethod.email ? 'Email' : 'Phone'}',
                style: TextStyle(color: Colors.grey.shade500)),
          ),
        ),
      ],
    );
  }

  Widget _passwordStep() {
    return Column(
      key: const ValueKey('password'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _passwordField(
            _passwordController,
            S.of(context).password,
            _passwordVisible,
            () => setState(() => _passwordVisible = !_passwordVisible)),
        const SizedBox(height: 20),
        _passwordField(
            _confirmPasswordController,
            S.of(context).confirmPassword,
            _confirmPasswordVisible,
            () => setState(
                () => _confirmPasswordVisible = !_confirmPasswordVisible)),
        const SizedBox(height: 32),
        _primaryButton('Continue', _nextFromPassword),
        const SizedBox(height: 16),
        _backButton(),
      ],
    );
  }

  Widget _personalStep() {
    return Column(
      key: const ValueKey('personal'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        STextFiled(
            controller: _nameController,
            textHint: 'Full name',
            prefix: Icon(CupertinoIcons.person, color: Colors.grey.shade600),
            autocorrect: false,
            inputType: TextInputType.name),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _selectProfession,
          child: AbsorbPointer(
            child: STextFiled(
                controller: _professionController,
                textHint: 'Profession',
                prefix:
                    Icon(CupertinoIcons.briefcase, color: Colors.grey.shade600),
                readOnly: true,
                suffix: Icon(CupertinoIcons.chevron_down,
                    color: Colors.grey.shade600),
                autocorrect: false),
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _selectDateOfBirth,
          child: AbsorbPointer(
            child: STextFiled(
                controller: _dateOfBirthController,
                textHint: 'Date of birth',
                prefix:
                    Icon(CupertinoIcons.calendar, color: Colors.grey.shade600),
                readOnly: true,
                suffix: Icon(CupertinoIcons.chevron_down,
                    color: Colors.grey.shade600),
                autocorrect: false),
          ),
        ),
        const SizedBox(height: 40),
        _primaryButton('Create Account', _finishRegistration),
        const SizedBox(height: 16),
        _backButton(),
      ],
    );
  }

  Widget _tab(RegisterMethod method, IconData icon, String text) {
    final selected = _registerMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _registerMethod = method;
          _identifierController.clear();
          _firebasePhoneIdToken = null;
          FirebaseAuthService.clearState();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color:
                      selected ? const Color(0xFFB48648) : Colors.grey.shade500,
                  size: 20),
              const SizedBox(width: 8),
              Text(text,
                  style: TextStyle(
                      color: selected
                          ? const Color(0xFF111827)
                          : Colors.grey.shade500,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(String title, VoidCallback onTap) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFB48648).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB48648),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
      ),
    );
  }

  Widget _backButton() {
    return Center(
      child: TextButton(
        onPressed:
            _loading || _step == 0 ? null : () => setState(() => _step -= 1),
        child: Text('Back',
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _passwordField(TextEditingController controller, String hint,
      bool visible, VoidCallback toggle) {
    return STextFiled(
      controller: controller,
      textHint: hint,
      prefix: Icon(CupertinoIcons.lock, color: Colors.grey.shade600),
      autocorrect: false,
      obscureText: !visible,
      inputType: TextInputType.text,
      suffix: IconButton(
        icon: Icon(visible ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
            color: Colors.grey.shade500),
        onPressed: toggle,
      ),
    );
  }
}
