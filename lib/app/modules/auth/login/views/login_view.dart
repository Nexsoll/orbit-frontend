// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';

import '../../../../core/api_service/auth/auth_api_service.dart';
import '../../../../core/api_service/profile/profile_api_service.dart';
import '../../widgets/social_login_buttons.dart';
import '../../../../core/widgets/wide_constraints.dart';
import '../../forget_password_otp/views/forget_password_page.dart';
import '../../widgets/auth_header.dart';
import '../../register/views/register_view.dart';
import '../controllers/login_controller.dart';

class LoginView extends StatefulWidget {
  final bool showBackButton;

  const LoginView({
    super.key,
    this.showBackButton = false,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final LoginController controller;
  bool _isPasswordVisible = false;
  RegisterMethod _loginMethod = RegisterMethod.email;

  @override
  void initState() {
    super.initState();
    controller = LoginController(
      GetIt.I.get<AuthApiService>(),
      GetIt.I.get<ProfileApiService>(),
      isAddingAccount: widget.showBackButton,
    );
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) => WideConstraints(
        enable: sizingInformation.isDesktop,
        child: CupertinoPageScaffold(
          navigationBar: widget.showBackButton
              ? CupertinoNavigationBar(
                  transitionBetweenRoutes: false, // 👈 disables Hero animation

                  leading: CupertinoNavigationBarBackButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  middle: Text(S.of(context).addAccount),
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
                    const SizedBox(
                        height:
                            20), // Add some spacing when back button is shown
                  SizedBox(
                    height: context.height * .02,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [

                        STextFiled(
                          controller: controller.emailController,
                          textHint: _loginMethod == RegisterMethod.phone
                              ? 'Phone number (e.g. +254712345678)'
                              : S.of(context).email,
                          prefix: _loginMethod == RegisterMethod.phone
                              ? const Icon(CupertinoIcons.phone, color: Colors.black)
                              : const Icon(Icons.email_outlined, color: Colors.black),
                          autocorrect: false,
                          inputType: _loginMethod == RegisterMethod.phone
                              ? TextInputType.phone
                              : TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 8),
                        // Toggle between email and phone login
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _loginMethod = _loginMethod == RegisterMethod.email
                                    ? RegisterMethod.phone
                                    : RegisterMethod.email;
                                controller.emailController.clear();
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
                                    _loginMethod == RegisterMethod.email
                                        ? CupertinoIcons.phone
                                        : Icons.email_outlined,
                                    size: 16,
                                    color: const Color(0xFFB48648),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _loginMethod == RegisterMethod.email
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
                        const SizedBox(
                          height: 20,
                        ),
                        STextFiled(
                          autocorrect: false,
                          controller: controller.passwordController,
                          textHint: S.of(context).password,
                          prefix: const Icon(CupertinoIcons.lock_fill, color: Colors.black),
                          obscureText: !_isPasswordVisible,
                          suffix: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CupertinoSwitch(
                                  value: controller.rememberDevice,
                                  activeColor: const Color(0xFFB48648),
                                  onChanged: (v) => setState(() {
                                    controller.rememberDevice = v;
                                  }),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Remember device',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                context.toPage(const ForgetPasswordPage());
                              },
                              child: S
                                  .of(context)
                                  .forgetPassword
                                  .text
                                  .color(const Color(0xFFB48648))
                                  .black,
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 40,
                        ),
                        SElevatedButton(
                          title: S.of(context).login,
                          onPress: () => controller.login(
                            context,
                            method: _loginMethod,
                          ),
                        ),
                        const SizedBox(
                          height: 30,
                        ),
                        Row(
                          children: const [
                            Expanded(
                              child: Divider(
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Or login with', style: TextStyle(color: Colors.black)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Divider(
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Center(
                          child: SocialLoginButtons(
                            authService: GetIt.I.get<AuthApiService>(),
                            profileService: GetIt.I.get<ProfileApiService>(),
                            isAddingAccount: widget.showBackButton,
                          ),
                        ),
                        const SizedBox(
                          height: 15,
                        ),
                        const SizedBox(
                          height: 15,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            S.of(context).needNewAccount.text,
                            const SizedBox(
                              width: 5,
                            ),
                            GestureDetector(
                              onTap: () {
                                final initialEmail =
                                    controller.emailController.text.trim();
                                context.toPage(
                                  RegisterView(
                                    initialEmail: initialEmail.isEmpty
                                        ? null
                                        : initialEmail,
                                    showBackButton: widget.showBackButton,
                                  ),
                                );
                              },
                              child: S
                                  .of(context)
                                  .register
                                  .text
                                  .color(const Color(0xFFB48648))
                                  .black,
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
