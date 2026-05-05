// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';

import '../../../../core/app_config/app_config_controller.dart';
import 'no_animation_page_route.dart';

class WideMessagesNavigation extends StatelessWidget {
  WideMessagesNavigation({
    super.key,
  });

  final controller = GetIt.I.get<VAppConfigController>();

  static final navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      initialRoute: 'IdleMessagesRoute',
      onGenerateRoute: (settings) {
        return NoAnimationPageRoute(
          builder: (context) {
            return const IdleMessagesRoute();
          },
        );
      },
    );
  }
}

class IdleMessagesRoute extends StatelessWidget {
  const IdleMessagesRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      navigationBar: const CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        middle: Text(
          SConstants.appName,
        ),
      ),
      child: Container(
        decoration: context.vMessageTheme.scaffoldDecoration,
        child: Center(
          child: Image.asset(
            "assets/logo.png",
            height: 150,
            width: 150,
          ),
        ),
      ),
    );
  }
}
