// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

// Stub implementations for Agora view types when running on web

import 'package:flutter/cupertino.dart';
import 'agora_stubs.dart';

// Export all the classes from agora_stubs.dart
export 'agora_stubs.dart';

class AgoraVideoView extends StatelessWidget {
  final VideoViewController controller;

  const AgoraVideoView({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoColors.black,
      child: const Center(
        child: Text(
          'Video not supported on web',
          style: TextStyle(color: CupertinoColors.white),
        ),
      ),
    );
  }
}
