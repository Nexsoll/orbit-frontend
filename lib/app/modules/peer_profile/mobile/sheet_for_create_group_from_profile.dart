// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/modules/create_group/views/create_group_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

class SheetForCreateGroupFromProfile extends StatelessWidget {
  final SBaseUser peer;

  const SheetForCreateGroupFromProfile({
    super.key,
    required this.peer,
  });

  @override
  Widget build(BuildContext context) {
    if (VPlatforms.isIOS) {
      return Navigator(
        onGenerateRoute: (rootContext) => CupertinoPageRoute(
          builder: (_) {
            return CreateGroupView(
              users: [peer],
              onDone: (vRoom) {
                Navigator.of(context).pop(vRoom);
              },
            );
          },
        ),
      );
    }
    return Navigator(
      onGenerateRoute: (rootContext) => MaterialPageRoute(
        builder: (_) {
          return CreateGroupView(
            users: [peer],
            onDone: (vRoom) {
              Navigator.of(context).pop(vRoom);
            },
          );
        },
      ),
    );
  }
}
