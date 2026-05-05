// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';

class SettingsListItemTile extends StatelessWidget {
  const SettingsListItemTile({
    super.key,
    this.color,
    required this.title,
    this.icon,
    this.additionalInfo,
    this.trailing,
    this.onTap,
    this.isLoading = false,
    this.textColor,
    this.subtitle,
    this.hide = false,
  });

  final Color? color;
  final Color? textColor;
  final bool hide;
  final String title;
  final bool isLoading;
  final IconData? icon;
  final Widget? subtitle;
  final Widget? additionalInfo;
  final Widget? trailing;
  final FutureOr<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    if (hide) return const SizedBox();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoListTile.notched(
          backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
          onTap: onTap,
          subtitle: subtitle,
          leadingSize: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          leading: isLoading
              ? const CupertinoActivityIndicator()
              : color == null
                  ? null
                  : Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: CupertinoColors.white,
                      ),
                    ),
          additionalInfo: additionalInfo,
          title: Text(
            title,
            maxLines: 3,
            style: TextStyle(color: textColor),
          ),
          trailing: trailing ??
              Icon(context.isRtl
                  ? CupertinoIcons.chevron_back
                  : CupertinoIcons.chevron_forward,
                  color: const Color(0xFFB48648)),
        ),
        const Divider(height: 1, color: Colors.black),
      ],
    );
  }
}
