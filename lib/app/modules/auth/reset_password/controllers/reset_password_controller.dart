// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/dto/reset_password_dto.dart';
import 'package:super_up/app/modules/auth/login/views/login_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';

import '../../../../core/api_service/auth/auth_api_service.dart';
import '../../auth_utils.dart';

class ResetPasswordController extends SLoadingController<SLoadingState?> {
  final codeController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final _authApiService = GetIt.I.get<AuthApiService>();
  final String email;

  ResetPasswordController(this.email) : super(SLoadingState(null));

  @override
  void onClose() {
    newPasswordController.dispose();
    codeController.dispose();
    confirmPasswordController.dispose();
  }

  @override
  void onInit() {}

  Future<void> resetPassword(BuildContext context) async {
    if (codeController.text.isEmpty) {
      VAppAlert.showErrorSnackBar(
        message: "Reset token is required",
        context: context,
      );
      return;
    }
    if (newPasswordController.text.isEmpty) {
      VAppAlert.showErrorSnackBar(
        message: S.of(context).newPasswordMustHaveValue,
        context: context,
      );
      return;
    }
    if (confirmPasswordController.text.isEmpty) {
      VAppAlert.showErrorSnackBar(
        message: S.of(context).confirmPasswordMustHaveValue,
        context: context,
      );
      return;
    }
    if (newPasswordController.text != confirmPasswordController.text) {
      VAppAlert.showErrorSnackBar(
        message: S.of(context).passwordNotMatch,
        context: context,
      );
      return;
    }
    await vSafeApiCall<void>(
      onLoading: () async {
        VAppAlert.showLoading(context: context);
      },
      onError: (exception, trace) {
        context.pop();
        final errEnum = EnumToString.fromString(
          ApiI18nErrorRes.values,
          exception.toString(),
        );
        VAppAlert.showErrorSnackBar(
            message: AuthTrUtils.tr(errEnum) ?? exception.toString(),
            context: context);
      },
      request: () async {
        await _authApiService.verifyAndResetPassword(ResetPasswordDto(
          newPasswordController.text,
          codeController.text,
          email,
        ));
      },
      onSuccess: (response) {
        context.toPageAndRemoveAllWithOutAnimation(const LoginView());
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }
}
