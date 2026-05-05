// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:super_up/app/modules/home/mobile/calls_tab/controllers/calls_tab_controller.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/widgets/app_logo.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

import 'call_item.dart';

class CallsTabView extends StatefulWidget {
  const CallsTabView({super.key});

  @override
  State<CallsTabView> createState() => _CallsTabViewState();
}

class _CallsTabViewState extends State<CallsTabView> {
  late final CallsTabController controller;

  @override
  void initState() {
    super.initState();
    controller = GetIt.I.get<CallsTabController>();
    controller.onInit();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false, // 👈 disables Hero animation
            largeTitle: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).calls,
                  style: context.cupertinoTextTheme.textStyle.copyWith(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                InkWell(
                  onTap: () => controller.clearCalls(context),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: S.of(context).clear.b1.black.color(const Color(0xFFB48648)),
                  ),
                ),
              ],
            ),
            middle: const AppLogo(),
          )
        ],
        body: Column(
          children: [
            AdsBannerWidget(
              adsId: VPlatforms.isAndroid
                  ? SConstants.androidBannerAdsUnitId
                  : SConstants.iosBannerAdsUnitId,
              isEnableAds: VAppConfigController.appConfig.enableAds,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 50, top: 10),
                child:
                    ValueListenableBuilder<SLoadingState<List<VCallHistory>>>(
                  valueListenable: controller,
                  builder: (_, value, __) {
                    return VAsyncWidgetsBuilder(
                      loadingState: value.loadingState,
                      onRefresh: controller.getCalls,
                      successWidget: () {
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 0),
                          itemBuilder: (context, index) {
                            return CallItem(
                              callHistory: value.data[index],
                              onLongPress: () => controller.onLongPress(
                                  context, value.data[index]),
                              onPress: () {
                                VChatController.I.roomApi.openChatWith(
                                  peerId: value.data[index].caller.id,
                                );
                              },
                            );
                          },
                          separatorBuilder: (context, index) => Divider(
                            height: 10,
                            thickness: 1,
                            color: Colors.grey.withOpacity(.2),
                          ),
                          itemCount: value.data.length,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
