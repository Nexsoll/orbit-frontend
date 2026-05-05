// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import '../../../../mobile/settings_tab/widgets/settings_list_item_tile.dart';
import '../controllers/help_controller.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  late final HelpController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        middle: Text(S.of(context).help),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Center(
            child: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, child) => Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 60,
                  ),
                  Image.asset(
                    "assets/logo.png",
                    height: 200,
                  ),
                  const SizedBox(
                    height: 60,
                  ),
                  CupertinoListSection.insetGrouped(
                    hasLeading: false,
                    margin: const EdgeInsets.all(10),
                    dividerMargin: 0,
                    topMargin: 0,
                    footer: Text(
                      "@ ${DateTime.now().year} ${SConstants.appName} LLC  V ${value.data.version}",
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    children: [
                      SettingsListItemTile(
                        color: Colors.grey.shade800,
                        icon: CupertinoIcons.chat_bubble_text,
                        title: S.of(context).supportChatSoon,
                        onTap: () => controller.openChatWith(context),
                      ),
                      SettingsListItemTile(
                        color: Colors.grey.shade800,
                        icon: Icons.email_outlined,
                        title: S.of(context).contactUs,
                        onTap: () => controller.onEmailContact(context),
                      ),
                      SettingsListItemTile(
                        color: Colors.grey.shade800,
                        icon: CupertinoIcons.doc,
                        onTap: () => controller.onPrivacy(context),
                        title: S.of(context).privacyPolicy,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    controller = HelpController();
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }
}
