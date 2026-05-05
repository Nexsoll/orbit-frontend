// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';

import 'no_animation_page_route.dart';

class WideMessageInfoNavigation extends StatelessWidget {
  const WideMessageInfoNavigation({
    super.key,
  });

  static final navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      initialRoute: 'IdleChatInfoRoute',
      onGenerateRoute: (settings) {
        return NoAnimationPageRoute(
          fullscreenDialog: false,
          builder: (context) {
            return const IdleChatInfoRoute();
          },
        );
      },
    );
  }
}

class IdleChatInfoRoute extends StatelessWidget {
  const IdleChatInfoRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: context.vMessageTheme.scaffoldDecoration,
      child: const CupertinoPageScaffold(
        backgroundColor: Colors.transparent,
        navigationBar: CupertinoNavigationBar(
          transitionBetweenRoutes: false, // 👈 disables Hero animation
        ),
        child: SizedBox(),
      ),
    );
  }
}
