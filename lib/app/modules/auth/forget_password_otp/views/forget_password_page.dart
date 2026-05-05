// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up_core/super_up_core.dart';
import '../../../../core/widgets/wide_constraints.dart';
import '../../widgets/auth_header.dart';
import '../controllers/forget_password_controller.dart';

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  late final ForgetPasswordController controller;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        return WideConstraints(
          enable: sizingInformation.isDesktop,
          child: CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              transitionBetweenRoutes: false, // 👈 disables Hero animation

              middle: Text(S.of(context).forgetPassword),
              previousPageTitle: S.of(context).back,
              leading: CupertinoNavigationBarBackButton(
                color: const Color(0xFFB48648),
                onPressed: () => Navigator.of(context).pop(),
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
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          STextFiled(
                            autofocus: true,
                            controller: controller.emailController,
                            textHint: S.of(context).email,
                            prefix: const Icon(Icons.email_outlined, color: Colors.black),
                            autocorrect: false,
                            inputType: TextInputType.emailAddress,
                          ),
                          const SizedBox(
                            height: 40,
                          ),
                          SElevatedButton(
                            title: 'Send link to my email',
                            onPress: () => controller.sendEmail(context),
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
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    controller = ForgetPasswordController();
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }
}
