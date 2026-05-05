// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:super_up_core/super_up_core.dart';

class ChatSettingsListSection extends StatelessWidget {
  const ChatSettingsListSection({
    super.key,
    required this.icon,
    required this.title,
    this.iconWidget,
    this.iconSize = 30,
    this.horizontalPadding = 20,
    this.verticalPadding = 10,
    this.titleFontSize,
    required this.onPressed,
  });

  final IconData icon;
  final Widget? iconWidget;
  final String title;
  final double iconSize;
  final double horizontalPadding;
  final double verticalPadding;
  final double? titleFontSize;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: CupertinoListSection(
        hasLeading: false,
        topMargin: 0,
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: context.isDark
              ? CupertinoColors.secondarySystemGroupedBackground.darkColor
              : null,
        ),
        dividerMargin: 0,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                onPressed: onPressed,
                child: Column(
                  children: [
                    iconWidget ??
                        Icon(
                          icon,
                          color: onPressed == null
                              ? CupertinoColors.systemGrey
                              : const Color(0xFFB48648),
                          size: iconSize,
                        ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        color: onPressed == null
                            ? CupertinoColors.systemGrey
                            : const Color(0xFFB48648),
                      ),
                    )
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
