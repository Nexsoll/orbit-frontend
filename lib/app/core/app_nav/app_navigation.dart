// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/modules/home/home_wide_modules/wide_navigation/wide_chat_info_navigation.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../modules/home/home_wide_modules/wide_navigation/no_animation_page_route.dart';
import '../../modules/home/home_wide_modules/wide_navigation/wide_messages_navigation.dart';
import '../../modules/home/home_wide_modules/wide_navigation/wide_rooms_navigation.dart';

abstract class RouteWrapper extends StatefulWidget {
  final String routeName;

  const RouteWrapper({
    required this.routeName,
    super.key,
  });
}

enum AppNavigationType { chatRoom, chatInfo, popUpAlert, messages }

interface class AppNavigation {
  static final wideMessagesInfoNotifier = ValueNotifier<bool>(false);

  static void setWideMessagesInfoNotifier(bool value) {
    if (wideMessagesInfoNotifier.value != value) {
      wideMessagesInfoNotifier.value = value;
    }
  }

  static void popKey(
    GlobalKey<NavigatorState> key,
  ) {
    ///pop all routes in this key
    key.currentState?.popUntil((route) => route.isFirst);
  }

  static Future<Object>? toPage(
    BuildContext context,
    Widget page, {
    AppNavigationType? appNavigationType,
    bool isRemoveAll = false,
    bool isRemoveAllWide = false,
    bool withAnimation = true,
  }) async {
    final sizer = GetIt.I.get<AppSizeHelper>();
    if (!sizer.isWide(context) || appNavigationType == null) {
      return context.toPage(
        page,
        removeAll: isRemoveAll,
        withAnimation: withAnimation,
      );
    }

    switch (appNavigationType) {
      case AppNavigationType.chatRoom:
        return _wideNav(
          WideRoomsNavigation.navKey,
          page,
          isRemoveAllWide,
        );
      case AppNavigationType.chatInfo:
        if (!AppNavigation.wideMessagesInfoNotifier.value) {
          AppNavigation.setWideMessagesInfoNotifier(true);
          await Future.delayed(const Duration(milliseconds: 100));
        }
        return _wideNav(
          WideMessageInfoNavigation.navKey,
          page,
          isRemoveAllWide,
        );

      case AppNavigationType.messages:
        return _wideNav(
          WideMessagesNavigation.navKey,
          page,
          isRemoveAllWide,
        );

      case AppNavigationType.popUpAlert:
        return showCupertinoDialog(
          context: context,
          useRootNavigator: true,
          builder: (context) {
            return page;
          },
        );
    }
  }
}

Future<Object?> _wideNav(
  GlobalKey<NavigatorState> key,
  Widget page,
  bool isRemoveAll,
) async {
  if (isRemoveAll) {
    return key.currentState?.pushAndRemoveUntil(
      NoAnimationPageRoute(builder: (context) => page),
      (route) => false,
    );
  }
  return key.currentState?.push(
    NoAnimationPageRoute(builder: (context) => page),
  );
}
