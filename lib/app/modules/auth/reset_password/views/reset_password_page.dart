// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import '../../../../core/widgets/wide_constraints.dart';
import '../../widgets/auth_header.dart';
import '../../login/views/login_view.dart';
import '../controllers/reset_password_controller.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String? token;

  const ResetPasswordPage({
    super.key, 
    required this.email,
    this.token,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  late final ResetPasswordController controller;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    controller = ResetPasswordController(widget.email);
    if (widget.token != null) {
      // Pre-fill the token if provided
      controller.codeController.text = widget.token!;
    }
    controller.onInit();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        return WideConstraints(
          enable: sizingInformation.isDesktop,
          child: WillPopScope(
            onWillPop: () async {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginView()),
                (route) => false,
              );
              return false;
            },
            child: CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(
                transitionBetweenRoutes: false, // 👈 disables Hero animation

                middle: Text(S.of(context).resetPassword),
                leading: CupertinoNavigationBarBackButton(
                  color: const Color(0xFFB48648),
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginView()),
                      (route) => false,
                    );
                  },
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  child: Column(
                  children: [
                    const AuthHeader(),
                    SizedBox(
                      height: context.height * .02,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          STextFiled(
                            controller: controller.codeController,
                            textHint: "Reset Token",
                            autocorrect: false,
                            inputType: TextInputType.text,
                            readOnly: true,
                            enabled: false,
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          STextFiled(
                            autofocus: true,
                            controller: controller.newPasswordController,
                            textHint: S.of(context).newPassword,
                            prefix: const Icon(CupertinoIcons.lock_fill, color: Colors.black),
                            autocorrect: false,
                            obscureText: !_isNewPasswordVisible,
                            inputType: TextInputType.text,
                            suffix: IconButton(
                              icon: Icon(
                                _isNewPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isNewPasswordVisible =
                                      !_isNewPasswordVisible;
                                });
                              },
                            ),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          STextFiled(
                            autofocus: true,
                            controller: controller.confirmPasswordController,
                            textHint: S.of(context).confirmPassword,
                            obscureText: !_isConfirmPasswordVisible,
                            prefix: const Icon(CupertinoIcons.lock_fill, color: Colors.black),
                            autocorrect: false,
                            inputType: TextInputType.text,
                            suffix: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isConfirmPasswordVisible =
                                      !_isConfirmPasswordVisible;
                                });
                              },
                            ),
                          ),
                          const SizedBox(
                            height: 40,
                          ),
                          SElevatedButton(
                            title: S.of(context).resetPassword,
                            onPress: () => controller.resetPassword(context),
                          ),
                          const SizedBox(
                            height: 30,
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }
}
