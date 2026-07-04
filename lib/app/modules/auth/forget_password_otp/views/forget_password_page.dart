// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:pinput/pinput.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/core/api_service/auth/auth_api_service.dart';
import 'package:super_up/app/core/dto/reset_password_dto.dart';
import 'package:super_up/app/modules/auth/login/views/login_view.dart';
import 'package:super_up_core/super_up_core.dart';
import '../../../../core/widgets/wide_constraints.dart';
import '../../widgets/auth_header.dart';

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final _authService = GetIt.I.get<AuthApiService>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 0;
  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!EmailValidator.validate(email)) {
      VAppAlert.showErrorSnackBar(message: S.of(context).emailNotValid, context: context);
      return;
    }
    await _run(() async {
      await _authService.sendResetPasswordEmailOtp(email);
      _otpController.clear();
      setState(() => _step = 1);
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().length != 6) {
      VAppAlert.showErrorSnackBar(message: 'Please enter a valid 6-digit OTP', context: context);
      return;
    }
    final email = _emailController.text.trim().toLowerCase();
    final code = _otpController.text.trim();
    await _run(() async {
      await _authService.verifyOtpResetPasswordOnly(email, code);
      setState(() => _step = 2);
    });
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final email = _emailController.text.trim().toLowerCase();
    final code = _otpController.text.trim();

    if (password.length < 8) {
      VAppAlert.showErrorSnackBar(message: S.of(context).passwordMustHaveValue, context: context);
      return;
    }
    if (password != confirm) {
      VAppAlert.showErrorSnackBar(message: S.of(context).passwordNotMatch, context: context);
      return;
    }

    await _run(() async {
      await _authService.verifyAndResetPassword(ResetPasswordDto(password, code, email));
      if (!mounted) return;
      VAppAlert.showSuccessSnackBar(message: 'Password reset successfully', context: context);
      context.toPageAndRemoveAllWithOutAnimation(const LoginView());
    });
  }

  Future<void> _run(Future<void> Function() body) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await body();
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showOkAlertDialog(context: context, title: S.of(context).error, content: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) => WideConstraints(
        enable: sizingInformation.isDesktop,
        child: CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            transitionBetweenRoutes: false,
            middle: Text(S.of(context).forgetPassword),
            previousPageTitle: S.of(context).back,
            leading: CupertinoNavigationBarBackButton(
              color: const Color(0xFFB48648),
              onPressed: () {
                if (_step > 0) {
                  setState(() => _step -= 1);
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuthHeader(),
                  const SizedBox(height: 20),
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
                        position: Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero).animate(animation),
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
      children: List.generate(3, (index) {
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
        title = "Forgot Password?";
        sub = "Enter your email to receive a reset code";
        break;
      case 1:
        title = "Verification";
        sub = "Enter the 6-digit code sent to ${_emailController.text.trim()}";
        break;
      case 2:
        title = "New Password";
        sub = "Create a strong password for your account";
        break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF111827), letterSpacing: -0.5),
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
      default:
        return _emailStep();
    }
  }

  Widget _emailStep() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        STextFiled(
          controller: _emailController,
          textHint: S.of(context).email,
          prefix: Icon(CupertinoIcons.mail, color: Colors.grey.shade600),
          autocorrect: false,
          inputType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 32),
        _primaryButton('Send OTP', _sendOtp),
      ],
    );
  }

  Widget _otpStep() {
    final pinTheme = PinTheme(
      width: 60,
      height: 68,
      textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
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
          focusedPinTheme: pinTheme.copyDecorationWith(border: Border.all(color: const Color(0xFFB48648), width: 2), color: Colors.white),
          submittedPinTheme: pinTheme.copyDecorationWith(color: Colors.white, border: Border.all(color: Colors.grey.shade300, width: 1.5)),
          onCompleted: (_) => _verifyOtp(),
        ),
        const SizedBox(height: 32),
        _primaryButton('Verify OTP', _verifyOtp),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _sendOtp,
            child: const Text('Resend code', style: TextStyle(color: Color(0xFFB48648), fontWeight: FontWeight.w600, fontSize: 16)),
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
        _passwordField(_passwordController, S.of(context).newPassword, _passwordVisible, () => setState(() => _passwordVisible = !_passwordVisible)),
        const SizedBox(height: 20),
        _passwordField(_confirmPasswordController, S.of(context).confirmPassword, _confirmPasswordVisible, () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible)),
        const SizedBox(height: 32),
        _primaryButton('Reset Password', _resetPassword),
      ],
    );
  }

  Widget _primaryButton(String title, VoidCallback onTap) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFFB48648).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB48648),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _passwordField(TextEditingController controller, String hint, bool visible, VoidCallback toggle) {
    return STextFiled(
      controller: controller,
      textHint: hint,
      prefix: Icon(CupertinoIcons.lock, color: Colors.grey.shade600),
      autocorrect: false,
      obscureText: !visible,
      inputType: TextInputType.text,
      suffix: IconButton(
        icon: Icon(visible ? CupertinoIcons.eye : CupertinoIcons.eye_slash, color: Colors.grey.shade500),
        onPressed: toggle,
      ),
    );
  }
}
