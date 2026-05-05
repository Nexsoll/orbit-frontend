// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loadmore/loadmore.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import '../controllers/admin_notification_controller.dart';

class AdminNotificationPage extends StatefulWidget {
  const AdminNotificationPage({super.key});

  @override
  State<AdminNotificationPage> createState() => _AdminNotificationPageState();
}

class _AdminNotificationPageState extends State<AdminNotificationPage> {
  late final AdminNotificationController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        middle: Text(S.of(context).adminNotification),
      ),
      child: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<
            SLoadingState<List<AdminNotificationsModel>>>(
          valueListenable: controller,
          builder: (_, value, ___) => VAsyncWidgetsBuilder(
            loadingState: value.loadingState,
            onRefresh: controller.getData,
            successWidget: () {
              return LoadMore(
                onLoadMore: controller.onLoadMore,
                isFinish: controller.isFinishLoadMore,
                textBuilder: (status) => "",
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: value.data.length,
                  itemBuilder: (context, index) {
                    final item = value.data[index];
                    final divider = const Divider(
                      thickness: 1,
                      color: Colors.black,
                      height: 1,
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (index == 0) ...[
                          const SizedBox(height: 6),
                          divider,
                        ],
                        CupertinoListTile(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          title: Text(item.title),
                          subtitle: Text(
                            item.content,
                            maxLines: 50,
                            style: const TextStyle(fontSize: 15),
                          ),
                          leadingSize: 50,
                          leading: item.imageUrl == null
                              ? null
                              : GestureDetector(
                                  onTap: () {
                                    VChatController.I.vNavigator.messageNavigator
                                        .toImageViewer(
                                      context,
                                      VPlatformFile.fromUrl(
                                        networkUrl: item.imageUrl!,
                                      ),
                                      true,
                                    );
                                  },
                                  child: VCircleAvatar(
                                    vFileSource: VPlatformFile.fromUrl(
                                      networkUrl: item.imageUrl!,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 6),
                        divider,
                        const SizedBox(height: 6),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    controller = AdminNotificationController();
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }
}
