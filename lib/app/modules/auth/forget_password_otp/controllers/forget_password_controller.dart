// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/api_service.dart';
import 'package:super_up/app/modules/auth/reset_password/views/reset_password_page.dart';
import 'package:super_up_core/super_up_core.dart';
import '../../auth_utils.dart';
import '../states/forget_password_state.dart';

class ForgetPasswordController
    extends SLoadingController<ForgetPasswordState?> {
  final emailController = TextEditingController();
  final _authApiService = GetIt.I.get<AuthApiService>();

  ForgetPasswordController() : super(SLoadingState(null));

  @override
  void onClose() {
    emailController.dispose();
  }

  @override
  void onInit() {}

  Future sendEmail(BuildContext context) async {
    await vSafeApiCall(
      onLoading: () {
        VAppAlert.showLoading(context: context);
      },
      request: () async {
        await _authApiService.sendResetPasswordEmailOtp(emailController.text);
      },
      onSuccess: (response) {
        context.pop();
        VAppAlert.showSuccessSnackBar(
          message: "Password reset link has been sent to your email",
          context: context,
        );
        // After showing the success message, go back to the previous screen (login)
        Navigator.of(context).pop();
      },
      onError: (exception, trace) {
        context.pop();
        final errEnum = EnumToString.fromString(
          ApiI18nErrorRes.values,
          exception.toString(),
        );
        VAppAlert.showErrorSnackBar(
          message: AuthTrUtils.tr(errEnum) ?? exception.toString(),
          context: context,
        );
      },
    );
  }
}
