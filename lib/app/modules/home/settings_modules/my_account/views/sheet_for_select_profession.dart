// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import '../../../../../core/app_config/app_config_controller.dart';

class SheetForSelectProfession extends StatelessWidget {
  const SheetForSelectProfession({super.key});

  @override
  Widget build(BuildContext context) {
    return SelectProfessionSheetWidget(
      onCloseSheet: () => Navigator.of(context).pop(),
    );
  }
}

class SelectProfessionSheetWidget extends StatefulWidget {
  final VoidCallback onCloseSheet;

  const SelectProfessionSheetWidget({super.key, required this.onCloseSheet});

  @override
  State<SelectProfessionSheetWidget> createState() => _SelectProfessionSheetWidgetState();
}

class _SelectProfessionSheetWidgetState extends State<SelectProfessionSheetWidget> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<String> _all;
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _all = List<String>.from(
      VAppConfigController.appConfig.professions ?? SConstants.commonProfessions,
    );
    _filtered = _all;
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _all;
      } else {
        _filtered = _all.where((p) => p.toLowerCase().contains(q)).toList();
      }
    });
  }

  void _select(String profession) {
    Navigator.of(context).pop(profession);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        leading: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          onPressed: widget.onCloseSheet,
          child: const Text('Close'),
        ),
        middle: const Text('Select Profession'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: CupertinoSearchTextField(
                controller: _searchCtrl,
                placeholder: 'Search profession',
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemBuilder: (context, index) {
                  final p = _filtered[index];
                  return CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    onPressed: () => _select(p),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.briefcase, color: Color(0xFFB48648)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p,
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withOpacity(.2)),
                itemCount: _filtered.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
