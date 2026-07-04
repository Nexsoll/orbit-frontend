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
import '../controllers/my_account_controller.dart';

class MyAccountPage extends StatefulWidget {
  const MyAccountPage({super.key});

  @override
  State<MyAccountPage> createState() => _MyAccountPageState();
}

class _MyAccountPageState extends State<MyAccountPage> {
  late final MyAccountController controller;

  @override
  Widget build(BuildContext context) {
    final leadingSize = 65.0;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(CupertinoIcons.chevron_back, color: Colors.white),
          ),
        ),
        middle: Text(AppAuth.myProfile.baseUser.fullName),
      ),
      child: SafeArea(
        bottom: false,
        child: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, child) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ChatSettingsTileInfo(
                  tileBackgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.only(
                    right: 15,
                    left: 15,
                    top: 10,
                    bottom: 0,
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      CupertinoListTile(
                        title: Text(
                          S.of(context).updateYourProfile,
                          style: TextStyle(
                            fontSize: 16,
                            color: CupertinoColors.label.resolveFrom(context),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                        ),
                        leadingSize: leadingSize,
                        padding: EdgeInsets.zero,
                        leading: Column(
                          children: [
                            VCircleAvatar(
                              vFileSource: VPlatformFile.fromUrl(
                                networkUrl:
                                    AppAuth.myProfile.baseUser.userImage,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.only(left: 15 + leadingSize + 10),
                        minSize: 0,
                        onPressed: () => controller.updateUserImage(context),
                        child: S.of(context).edit.text.color(const Color(0xFFB48648)),
                      ),
                      const SizedBox(height: 5),
                      ChatSettingsTileInfo(
                        tileBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.all(10),
                        title: Text(AppAuth.myProfile.baseUser.fullName),
                        trailing: const Icon(Icons.edit, color: Color(0xFFB48648)),
                        onPressed: () => controller.updateUserName(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 15,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: S
                      .of(context)
                      .email
                      .toUpperCase()
                      .text
                      .color(CupertinoColors.label.resolveFrom(context))
                      .size(15),
                ),
                ChatSettingsTileInfo(
                  tileBackgroundColor: Colors.grey.shade300,
                  title: Text(AppAuth.myProfile.email),
                  trailing: const Icon(Icons.edit, color: Color(0xFFB48648)),
                  onPressed: () => controller.updateUserEmail(context),
                ),
                const SizedBox(
                  height: 15,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: "PHONE NUMBER"
                      .toUpperCase()
                      .text
                      .color(CupertinoColors.label.resolveFrom(context))
                      .size(15),
                ),
                ChatSettingsTileInfo(
                  tileBackgroundColor: Colors.grey.shade300,
                  title: Text(AppAuth.myProfile.phoneNumber ?? "Not set"),
                  padding: const EdgeInsets.all(10),
                  trailing: const Icon(Icons.edit, color: Color(0xFFB48648)),
                  onPressed: () => controller.updateUserPhoneNumber(context),
                ),
                const SizedBox(
                  height: 15,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: "GENDER"
                      .toUpperCase()
                      .text
                      .color(CupertinoColors.label.resolveFrom(context))
                      .size(15),
                ),
                ChatSettingsTileInfo(
                  tileBackgroundColor: Colors.grey.shade300,
                  title: Text(_getGenderDisplayText()),
                  padding: const EdgeInsets.all(10),
                  trailing: const Icon(Icons.edit, color: Color(0xFFB48648)),
                  onPressed: () => controller.updateUserGender(context),
                ),
                const SizedBox(
                  height: 15,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: "PROFESSION"
                      .toUpperCase()
                      .text
                      .color(CupertinoColors.label.resolveFrom(context))
                      .size(15),
                ),
                ChatSettingsTileInfo(
                  tileBackgroundColor: Colors.grey.shade300,
                  title: Text(AppAuth.myProfile.profession ?? "Not set"),
                  padding: const EdgeInsets.all(10),
                  trailing: const Icon(Icons.edit, color: Color(0xFFB48648)),
                  onPressed: () => controller.updateUserProfession(context),
                ),
                const SizedBox(
                  height: 15,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: "DATE OF BIRTH"
                      .toUpperCase()
                      .text
                      .color(CupertinoColors.label.resolveFrom(context))
                      .size(15),
                ),
                ChatSettingsTileInfo(
                  tileBackgroundColor: Colors.grey.shade300,
                  title: Text(_getDateOfBirthDisplayText()),
                  padding: const EdgeInsets.all(10),
                  trailing: const Icon(Icons.edit, color: Color(0xFFB48648)),
                  onPressed: () => controller.updateDateOfBirth(context),
                ),
                const SizedBox(
                  height: 15,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: S
                      .of(context)
                      .about
                      .toUpperCase()
                      .text
                      .color(CupertinoColors.label.resolveFrom(context))
                      .size(15),
                ),
                ChatSettingsTileInfo(
                  tileBackgroundColor: Colors.grey.shade300,
                  title: Text(
                    AppAuth.myProfile.userBio,
                    maxLines: 3,
                  ),
                  padding: const EdgeInsets.all(10),
                  trailing: const Icon(Icons.edit, color: Color(0xFFB48648)),
                  onPressed: () => controller.updateUserBio(context),
                ),
                const SizedBox(
                  height: 15,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: S
                      .of(context)
                      .password
                      .toUpperCase()
                      .text
                      .color(CupertinoColors.label.resolveFrom(context))
                      .size(15),
                ),
                ChatSettingsTileInfo(
                  tileBackgroundColor: Colors.grey.shade300,
                  title: Text(S.of(context).updateYourPassword),
                  padding: const EdgeInsets.all(10),
                  trailing: const Icon(Icons.edit, color: Color(0xFFB48648)),
                  onPressed: () => controller.updateUserPassword(context),
                ),
                const SizedBox(
                  height: 10,
                ),
                ChatSettingsTileInfo(
                  title: Text(
                    S.of(context).deleteMyAccount,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.red),
                  ),
                  padding: const EdgeInsets.all(10),
                  trailing: const Icon(
                    Icons.delete_forever,
                    color: Colors.red,
                  ),
                  onPressed: () => controller.deleteMyAccount(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    controller = MyAccountController(GetIt.I.get<ProfileApiService>());
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  String _getGenderDisplayText() {
    final gender = AppAuth.myProfile.gender;
    if (gender == null || gender.isEmpty) {
      return "Not set";
    }
    // Capitalize first letter
    return gender[0].toUpperCase() + gender.substring(1);
  }

  String _getDateOfBirthDisplayText() {
    final value = AppAuth.myProfile.dateOfBirth;
    if (value == null || value.isEmpty) {
      return "Not set";
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }
}
