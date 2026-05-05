// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../choose_members/views/choose_members_view.dart';
import '../views/create_broadcast_view.dart';

class SheetForCreateBroadcast extends StatelessWidget {
  const SheetForCreateBroadcast({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (VPlatforms.isIOS) {
      return Navigator(
        onGenerateRoute: (___) => CupertinoPageRoute(
          builder: (__) => ChooseMembersView(
            maxCount: VChatController.I.vChatConfig.maxBroadcastMembers,
            onCloseSheet: () {
              Navigator.of(context).pop();
            },
            onDone: (selectedUsers) {
              Navigator.of(__).push(CupertinoPageRoute(
                builder: (_) => CreateBroadcastView(
                  users: selectedUsers,
                  onDone: (vRoom) {
                    Navigator.of(context).pop(vRoom);
                  },
                ),
              ));
            },
          ),
        ),
      );
    }
    return Navigator(
      onGenerateRoute: (___) => MaterialPageRoute(
        builder: (__) => ChooseMembersView(
          maxCount: VChatController.I.vChatConfig.maxBroadcastMembers,
          onCloseSheet: () {
            Navigator.of(context).pop();
          },
          onDone: (selectedUsers) {
            Navigator.of(__).push(MaterialPageRoute(
              builder: (_) => CreateBroadcastView(
                users: selectedUsers,
                onDone: (vRoom) {
                  Navigator.of(context).pop(vRoom);
                },
              ),
            ));
          },
        ),
      ),
    );
  }
}
