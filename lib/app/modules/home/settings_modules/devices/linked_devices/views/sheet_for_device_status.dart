// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/core/api_service/api_service.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../../../../../core/models/user_device_model.dart';
import '../../../../mobile/settings_tab/widgets/settings_list_item_tile.dart';

class SheetForDeviceStatus extends StatelessWidget {
  final UserDeviceModel deviceModel;

  const SheetForDeviceStatus({
    super.key,
    required this.deviceModel,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (___) => CupertinoPageRoute(
        builder: (__) => _DeviceStatusSheet(
          deviceModel: deviceModel,
          onCloseSheet: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class _DeviceStatusSheet extends StatefulWidget {
  final VoidCallback onCloseSheet;
  final UserDeviceModel deviceModel;

  const _DeviceStatusSheet({
    required this.onCloseSheet,
    required this.deviceModel,
  });

  @override
  State<_DeviceStatusSheet> createState() => _DeviceStatusSheetState();
}

class _DeviceStatusSheetState extends State<_DeviceStatusSheet> {
  bool isLoading = false;

  bool get isMyDevice => AppAuth.myProfile.deviceId == widget.deviceModel.id;
  final profileApi = GetIt.I.get<ProfileApiService>();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.isDark ? null : CupertinoColors.systemGrey6,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        middle: Text(S.of(context).deviceStatus),
        leading: TextButton(
          onPressed: widget.onCloseSheet,
          child: Text(S.of(context).close),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Column(
            children: [
              Icon(
                _getIcon(widget.deviceModel.platform),
                size: 100,
              ),
              const SizedBox(
                height: 10,
              ),
              Text(widget.deviceModel.platform),
              const SizedBox(
                height: 60,
              ),
              CupertinoListSection.insetGrouped(
                additionalDividerMargin: 0,
                margin: const EdgeInsets.all(10),
                dividerMargin: 0,
                topMargin: 0,
                children: [
                  SettingsListItemTile(
                    trailing: Text(
                      "${S.of(context).lastActiveFrom} ${format(widget.deviceModel.lastSeenAtLocal)}",
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                    title: "Activity",
                  ),
                  SettingsListItemTile(
                    trailing: Text(
                      "${S.of(context).visits} ${widget.deviceModel.visits}",
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                    title: S.of(context).visits,
                  )
                ],
              ),
              const SizedBox(
                height: 30,
              ),
              CupertinoListSection.insetGrouped(
                additionalDividerMargin: 0,
                margin: const EdgeInsets.all(10),
                dividerMargin: 0,
                topMargin: 0,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoButton(
                        onPressed: isMyDevice
                            ? null
                            : () => logoutDevice(widget.deviceModel),
                        child: isLoading
                            ? const CupertinoActivityIndicator()
                            : isMyDevice
                                ? Text(S.of(context).currentDevice)
                                : Text(S.of(context).logOut),
                      ),
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String platform) {
    if (platform == "android" || platform == "ios") {
      return PhosphorIcons.deviceMobile();
    }
    if (platform == "web") {
      return PhosphorIcons.googleChromeLogo();
    }
    if (platform == "macOs" || platform == "windows") {
      return PhosphorIcons.computerTower();
    }
    return Icons.question_mark;
  }

  Future checkPassword() async {
    vSafeApiCall(
      request: () async {
        profileApi.passwordCheck("");
      },
      onSuccess: (response) {},
    );
  }

  Future logoutDevice(UserDeviceModel deviceModel) async {
    final x = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: S.of(context).areYouSure,
      content: S.of(context).deleteThisDeviceDesc,
    );
    if (x != 1) return;

    final passwordRes = await VAppAlert.showTextInputDialog(
      context: context,
      textFields: [
        DialogTextField(hintText: S.of(context).password, obscureText: true)
      ],
    );
    if (passwordRes == null) return;
    await vSafeApiCall(
      onLoading: () {
        setState(() {
          isLoading = true;
        });
      },
      request: () {
        return profileApi.deleteDevice(deviceModel.id, passwordRes.first);
      },
      onSuccess: (response) {
        setState(() {
          isLoading = false;
        });
        widget.onCloseSheet();
      },
      onError: (exception, trace) {
        setState(() {
          isLoading = false;
        });
        if (exception == "invalidLoginData") {
          VAppAlert.showErrorSnackBar(
              message: S.of(context).invalidLoginData, context: context);
        } else {
          VAppAlert.showErrorSnackBar(message: exception, context: context);
        }
      },
    );
  }
}
