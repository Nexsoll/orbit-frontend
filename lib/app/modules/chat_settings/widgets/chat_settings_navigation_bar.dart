import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../../core/app_nav/app_navigation.dart';
import '../../home/home_wide_modules/wide_navigation/wide_messages_navigation.dart';

class ChatSettingsNavigationBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  final String middle;
  final String previousPageTitle;
  final Widget? middleWidget;

  ChatSettingsNavigationBar({
    super.key,
    required this.middle,
    required this.previousPageTitle,
    this.middleWidget,
  });

  final sizer = GetIt.I.get<AppSizeHelper>();

  @override
  Widget build(BuildContext context) {
    final isWide = sizer.isWide(context);
    return CupertinoNavigationBar(
      transitionBetweenRoutes: false, // 👈 disables Hero animation
      middle: middleWidget ?? middle.text,
      automaticallyImplyLeading: false,
      previousPageTitle: previousPageTitle,
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          if (isWide) {
            AppNavigation.popKey(WideMessagesNavigation.navKey);
            AppNavigation.setWideMessagesInfoNotifier(false);
          } else {
            context.pop();
          }
        },
        child: isWide
            ? Container(
                decoration: BoxDecoration(
                  color: context.isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.red,
                  size: 27,
                ),
              )
            : const Icon(
                Icons.arrow_back_ios,
                color: Colors.red,
                size: 27,
              ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(50);

  @override
  bool shouldFullyObstruct(BuildContext context) {
    return true;
  }
}
