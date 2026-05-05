// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

class WideConstraints extends StatelessWidget {
  final Widget child;
  final bool enable;

  const WideConstraints({super.key, required this.child, this.enable = true});

  @override
  Widget build(BuildContext context) {
    if (!enable) {
      return child;
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700,
          maxHeight: 1000,
        ),
        child: child,
      ),
    );
  }
}
