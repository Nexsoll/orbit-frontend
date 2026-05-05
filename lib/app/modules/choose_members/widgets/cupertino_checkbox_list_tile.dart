// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';

class CupertinoCheckboxListTile extends StatelessWidget {
  final Widget title;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onItemPressed;

  const CupertinoCheckboxListTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.onItemPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      title: title,
      padding: EdgeInsets.zero,
      onTap: onItemPressed,
      trailing: CupertinoCheckbox(
        value: value,
        onChanged: (value) {
          onChanged(value);
        },
      ),
    );
  }
}
