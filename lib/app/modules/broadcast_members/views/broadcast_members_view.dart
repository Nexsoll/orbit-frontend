// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:loadmore/loadmore.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import '../controllers/broadcast_members_controller.dart';

class BroadcastMembersView extends StatefulWidget {
  final String roomId;
  final VToChatSettingsModel settingsModel;

  const BroadcastMembersView({
    super.key,
    required this.roomId,
    required this.settingsModel,
  });

  @override
  State<BroadcastMembersView> createState() => _BroadcastMembersViewState();
}

class _BroadcastMembersViewState extends State<BroadcastMembersView> {
  late final BroadcastMembersController controller;

  @override
  void initState() {
    super.initState();
    controller = BroadcastMembersController(widget.roomId, context);
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        middle: Text(S.of(context).broadcastMembers),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: ValueListenableBuilder<SLoadingState<List<VBroadcastMember>>>(
            valueListenable: controller,
            builder: (_, value, __) {
              return VAsyncWidgetsBuilder(
                loadingState: value.loadingState,
                onRefresh: controller.getData,
                successWidget: () {
                  return LoadMore(
                    onLoadMore: controller.onLoadMore,
                    isFinish: controller.isFinishLoadMore,
                    textBuilder: (status) => "",
                    child: ListView.separated(
                      separatorBuilder: (context, index) => const SizedBox(
                        height: 10,
                      ),
                      padding: const EdgeInsets.all(10),
                      itemBuilder: (context, index) {
                        return SUserItem(
                          subtitle: format(value.data[index].createdAtLocal,
                              locale:
                                  Localizations.localeOf(context).languageCode),
                          onTap: () => controller.onUserTab(
                              context, value.data[index].userData),
                          baseUser: value.data[index].userData,
                        );
                      },
                      itemCount: value.data.length,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
