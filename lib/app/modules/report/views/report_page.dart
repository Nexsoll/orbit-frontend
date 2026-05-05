// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:super_up/app/modules/choose_members/widgets/cupertino_checkbox_list_tile.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import '../controllers/report_controller.dart';

class ReportPage extends StatefulWidget {
  final String userId;
  final bool jobContext;

  const ReportPage({super.key, required this.userId, this.jobContext = false});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late final ReportController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, child) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          transitionBetweenRoutes: false, // 👈 disables Hero animation

          middle: Text(S.of(context).report),
          trailing: CupertinoButton(
            minSize: 0,
            padding: EdgeInsets.zero,
            onPressed: !controller.isSendReady
                ? null
                : () => controller.onReport(context),
            child: Text(S.of(context).send),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ...(() {
                    final reasons = widget.jobContext
                        ? <String>[
                            'Fake or Scam Job: Listing contains false information, asks for upfront fees, or appears fraudulent.',
                            'Non-payment or Payment Issues: Employer refuses to pay, changes agreed payment, or requests unpaid trials.',
                            'Unsafe or Illegal Job: Job appears unsafe, exploitative, violates laws or platform policies.',
                            'Other: Provide more details about the issue related to this job.',
                          ]
                        : <String>[
                            S.of(context).spamOrScamDescription,
                            S.of(context).harassmentOrBullyingDescription,
                            S.of(context).inappropriateContentDescription,
                            S.of(context).otherCategoryDescription,
                          ];

                    return List<Widget>.generate(reasons.length, (i) => Column(
                          children: [
                            CupertinoCheckboxListTile(
                              title: reasons[i].text.maxLine(10),
                              value: controller.data.currentType == (i + 1),
                              onChanged: (value) {
                                controller.onTypePress(value == true ? (i + 1) : 0);
                              },
                            ),
                            const SizedBox(height: 15),
                          ],
                        ));
                  })(),
                  const SizedBox(
                    height: 15,
                  ),
                  CupertinoCheckboxListTile(
                    title: S.of(context).blockUser.text.maxLine(10),
                    value: controller.data.blockThisUser,
                    onChanged: (value) {
                      controller.onBlockPress(value ?? false);
                    },
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  STextFiled(
                    maxLines: 10,
                    minLines: 5,
                    controller: controller.txtController,
                    textHint: S.of(context).explainWhatHappens,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    controller = ReportController(widget.userId);
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }
}
