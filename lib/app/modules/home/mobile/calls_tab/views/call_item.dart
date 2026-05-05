// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

class CallItem extends StatelessWidget {
  final VCallHistory callHistory;
  final VoidCallback onPress;
  final VoidCallback onLongPress;

  const CallItem({
    super.key,
    required this.callHistory,
    required this.onPress,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPress,
      onLongPress: onLongPress,
      child: CupertinoListTile(
        leadingSize: 40,
        leading: VCircleAvatar(
          vFileSource:
          VPlatformFile.fromUrl(networkUrl: callHistory.caller.userImage),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          child: callHistory.withVideo
              ?   Icon(
            PhosphorIcons.videoCamera(PhosphorIconsStyle.fill),
            color: const Color(0xFFB48648),
          )
              : const Icon(
            CupertinoIcons.phone_fill,
            color: Color(0xFFB48648),
          ),
        ),
        padding: EdgeInsets.zero,
        additionalInfo: Text(
          format(
            callHistory.startAtDate,
            locale: Localizations.localeOf(context).languageCode,
          ),
          style: const TextStyle(fontSize: 12),
        ),
        title: callHistory.caller.fullName.text,
        subtitle: transCallStatus(callHistory, context).text,
      ),
    );
  }

  String transCallStatus(VCallHistory call, BuildContext context) {
    switch (call.callStatus) {
      case VCallStatus.ring:
        return S.of(context).ring;

      case VCallStatus.timeout:
        return S.of(context).timeout;
      case VCallStatus.finished:
        return S.of(context).finished;
      case VCallStatus.rejected:
        return S.of(context).rejected;
      case VCallStatus.canceled:
        return S.of(context).cancel;

      case VCallStatus.offline:
        return 'offline';

      case VCallStatus.serverRestart:
        return "serverRestart";
      case VCallStatus.inCall:
        return "inCall";
    }
    return "";
  }
}
