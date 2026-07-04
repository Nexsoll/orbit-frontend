// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loadmore/loadmore.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import '../controllers/group_members_controller.dart';

class GroupMembersView extends StatefulWidget {
  const GroupMembersView({
    super.key,
    required this.roomId,
    required this.myGroupInfo,
    required this.settingsModel,
  });
  final String roomId;
  final VMyGroupInfo myGroupInfo;
  final VToChatSettingsModel settingsModel;

  @override
  State<GroupMembersView> createState() => _GroupMembersViewState();
}

class _GroupMembersViewState extends State<GroupMembersView> {
  late final GroupMembersController controller;

  @override
  void initState() {
    super.initState();
    controller = GroupMembersController(
      widget.roomId,
      widget.myGroupInfo,
    );
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

        middle: Text(S.of(context).groupMembers),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                child: CupertinoSearchTextField(
                  controller: controller.txtController,
                  onChanged: controller.onSearchChanged,
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<SLoadingState<List<VGroupMember>>>(
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
                            padding: const EdgeInsets.all(10),
                            separatorBuilder: (context, index) => Divider(
                              height: 10,
                              thickness: 1,
                              color: Colors.grey.withOpacity(.2),
                            ),
                            itemBuilder: (context, index) => SUserItem(
                              baseUser: value.data[index].userData,
                              subtitle: format(
                                value.data[index].createdAtLocal,
                                locale: Localizations.localeOf(context).languageCode,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getTr(value.data[index].role),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Icon(
                                    context.isRtl
                                        ? CupertinoIcons.chevron_back
                                        : CupertinoIcons.chevron_forward,
                                  ),
                                ],
                              ),
                              onTap: () => controller.onUserTab(
                                context,
                                value.data[index],
                              ),
                              onLongPress: () => controller.onUserTab(
                                context,
                                value.data[index],
                              ),
                            ),
                            itemCount: value.data.length,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTr(VGroupMemberRole role) {
    switch (role) {
      case VGroupMemberRole.admin:
        return S.of(context).admin;
      case VGroupMemberRole.member:
        return S.of(context).member;
      case VGroupMemberRole.superAdmin:
        return S.of(context).creator;
    }
  }
}
