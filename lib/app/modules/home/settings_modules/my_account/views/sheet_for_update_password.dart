// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_platform/v_platform.dart';

import '../../../../../core/api_service/profile/profile_api_service.dart';
import '../../../../choose_members/widgets/cupertino_checkbox_list_tile.dart';

class SheetForUpdatePassword extends StatelessWidget {
  const SheetForUpdatePassword({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (VPlatforms.isIOS) {
      return Navigator(
        onGenerateRoute: (___) => CupertinoPageRoute(
          builder: (__) => UpdatePasswordSheetWidget(
            onCloseSheet: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    }
    return Navigator(
      onGenerateRoute: (___) => MaterialPageRoute(
        builder: (__) => UpdatePasswordSheetWidget(
          onCloseSheet: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class UpdatePasswordSheetWidget extends StatefulWidget {
  final VoidCallback onCloseSheet;

  const UpdatePasswordSheetWidget({
    super.key,
    required this.onCloseSheet,
  });

  @override
  State<UpdatePasswordSheetWidget> createState() =>
      _UpdatePasswordSheetWidgetState();
}

class _UpdatePasswordSheetWidgetState extends State<UpdatePasswordSheetWidget> {
  bool canRequest = false;

  bool loading = false;
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final profileApiService = GetIt.I.get<ProfileApiService>();
  final dto = UpdatePasswordDto();

  @override
  void dispose() {
    super.dispose();
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        leading: TextButton(
          onPressed: widget.onCloseSheet,
          child: Text(S.of(context).close),
        ),
        trailing: loading
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                onPressed: canRequest ? () => onRequest(context) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      S.of(context).next,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                  ],
                ),
              ),
        middle: Text(S.of(context).updateYourPassword),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const SizedBox(
                height: 20,
              ),
              const Icon(CupertinoIcons.lock_fill, size: 100),
              const SizedBox(
                height: 20,
              ),
              STextFiled(
                textHint: S.of(context).oldPassword,
                controller: oldPasswordController,
                obscureText: true,
                onChanged: (value) {
                  dto.oldPassword = value;
                  _checkTheInput();
                },
              ),
              const SizedBox(
                height: 20,
              ),
              STextFiled(
                textHint: S.of(context).newPassword,
                controller: newPasswordController,
                obscureText: true,
                onChanged: (value) {
                  dto.newPassword = value;
                  _checkTheInput();
                },
              ),
              const SizedBox(
                height: 20,
              ),
              STextFiled(
                textHint: S.of(context).confirmPassword,
                obscureText: true,
                controller: confirmPasswordController,
                onChanged: (value) {
                  dto.newConfPassword = value;
                  _checkTheInput();
                },
              ),
              const SizedBox(
                height: 20,
              ),
              CupertinoCheckboxListTile(
                title: Text(S.of(context).logoutFromAllDevices),
                onChanged: (value) {
                  setState(() {
                    dto.logoutAll = value ?? false;
                  });
                },
                value: dto.logoutAll,
              )
            ],
          ),
        ),
      ),
    );
  }

  void onRequest(BuildContext context) async {
    await vSafeApiCall(
      onLoading: () {
        setState(() {
          loading = true;
        });
      },
      request: () async {
        await profileApiService.updatePassword(dto);
      },
      onSuccess: (response) {
        VAppAlert.showSuccessSnackBar(
            message: S.of(context).passwordHasBeenChanged, context: context);
        widget.onCloseSheet();
      },
      onError: (exception, trace) {
        VAppAlert.showOkAlertDialog(
            content: exception.toString(),
            context: context,
            title: S.of(context).error);
      },
    );
    setState(() {
      loading = false;
    });
  }

  void _checkTheInput() {
    if (dto.isValid) {
      setState(() {
        canRequest = true;
      });
    } else {
      setState(() {
        canRequest = false;
      });
    }
  }
}

class UpdatePasswordDto {
  String oldPassword;
  String newPassword;
  String newConfPassword;
  bool logoutAll;

//<editor-fold desc="Data Methods">
  UpdatePasswordDto({
    this.oldPassword = "",
    this.newPassword = "",
    this.newConfPassword = "",
    this.logoutAll = false,
  });

  bool get isValid {
    if (oldPassword.isEmpty ||
        newPassword.isEmpty ||
        newConfPassword.isEmpty ||
        newPassword != newConfPassword) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
      'newConfPassword': newConfPassword,
      'logoutAll': logoutAll,
    };
  }

  factory UpdatePasswordDto.fromMap(Map<String, dynamic> map) {
    return UpdatePasswordDto(
      oldPassword: map['oldPassword'] as String,
      newPassword: map['newPassword'] as String,
      newConfPassword: map['newConfPassword'] as String,
      logoutAll: map['logoutAll'] as bool,
    );
  }

//</editor-fold>
}
