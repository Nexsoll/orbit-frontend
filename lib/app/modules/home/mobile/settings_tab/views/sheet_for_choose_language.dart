// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:get_it/get_it.dart';

class SheetForChooseLanguage extends StatefulWidget {
  const SheetForChooseLanguage({super.key});

  @override
  State<SheetForChooseLanguage> createState() => _SheetForChooseLanguageState();
}

class _SheetForChooseLanguageState extends State<SheetForChooseLanguage> {
  final txtController = TextEditingController();

  var _languages = <ModelSheetItem>[];

  @override
  void initState() {
    super.initState();
    _refreshAndLoad();
  }

  Future<void> _refreshAndLoad() async {
    try {
      await GetIt.I.get<VAppConfigController>().refreshAppConfig();
    } catch (_) {}
    if (mounted) {
      _addLanguage();
      setState(() {});
    }
  }

  List<ModelSheetItem> get _availableLocales {
    final active = VAppConfigController.appConfig.activeLocales;
    final all = S.delegate.supportedLocales;
    final filtered = (active == null || active.isEmpty)
        ? all
        : all.where((loc) => active.contains(loc.languageCode));

    // Custom order: English first, then Kiswahili (sw), then the rest alphabetically by display name
    final priority = <String, int>{
      'en': 0,
      'sw': 1,
    };

    final sorted = filtered.toList()
      ..sort((a, b) {
        final pa = priority[a.languageCode] ?? 2;
        final pb = priority[b.languageCode] ?? 2;
        if (pa != pb) return pa.compareTo(pb);
        // Same priority: sort by localized display name
        final na = getFullLanguageName(a.languageCode).toLowerCase();
        final nb = getFullLanguageName(b.languageCode).toLowerCase();
        return na.compareTo(nb);
      });

    return sorted
        .map((e) => ModelSheetItem(
              id: e.languageCode,
              title: getFullLanguageName(e.languageCode),
            ))
        .toList();
  }

  void _addLanguage() {
    _languages = _availableLocales;
  }

  @override
  void dispose() {
    super.dispose();
    txtController.dispose();
  }

  @override
  Widget build(BuildContext contextParent) {
    return Navigator(
      onGenerateRoute: (___) => CupertinoPageRoute(
        builder: (__) => CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            transitionBetweenRoutes: false, // 👈 disables Hero animation

            leading: TextButton(
              onPressed: Navigator.of(contextParent).pop,
              child: Text(S.of(context).close),
            ),
            middle: Text(S.of(context).language),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: CupertinoSearchTextField(
                      controller: txtController,
                      onChanged: onSearchChanged,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: ModalScrollController.of(context),
                      padding: const EdgeInsets.all(5),
                      separatorBuilder: (context, index) => Divider(
                        height: 10,
                        thickness: 1,
                        color: Colors.grey.withOpacity(.2),
                      ),
                      itemBuilder: (context, index) {
                        final item = _languages[index];
                        return CupertinoListTile(
                          onTap: () {
                            Navigator.of(contextParent).pop(item);
                          },
                          title: item.title.text,
                        );
                      },
                      itemCount: _languages.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void onSearchChanged(String value) {
    if (value.isEmpty) {
      _addLanguage();
    } else {
      _languages = _availableLocales
          .where((e) => e.title.toLowerCase().startsWith(value.toLowerCase()))
          .toList();
    }

    setState(() {});
  }
}
