// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class GroupMembersController extends SLoadingController<List<VGroupMember>> {
  final txtController = TextEditingController();
  final String roomId;
  final VMyGroupInfo myGroupInfo;

  GroupMembersController(this.roomId, this.myGroupInfo)
      : super(SLoadingState(<VGroupMember>[]));
  bool _isLoadMoreActive = false;
  bool isFinishLoadMore = false;
  final _filterDto = VBaseFilter(
    limit: 30,
    page: 1,
  );

  @override
  void onInit() {
    getData();
  }

  Future<void> getData() async {
    await vSafeApiCall<List<VGroupMember>>(
      onLoading: () async {
        setStateLoading();
      },
      onError: (exception, trace) {
        setStateError();
      },
      request: () async {
        return VChatController.I.roomApi.getGroupMembers(roomId);
      },
      onSuccess: (response) {
        data.clear();
        data.addAll(response);
        setStateSuccess();
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }

  @override
  void onClose() {
    txtController.dispose();
  }

  Future<bool> onLoadMore() async {
    if (_isLoadMoreActive) {
      return false;
    }
    final res = await vSafeApiCall<List<VGroupMember>>(
      onLoading: () {
        _isLoadMoreActive = true;
      },
      request: () async {
        ++_filterDto.page;

        return VChatController.I.roomApi.getGroupMembers(
          roomId,
          filter: _filterDto,
        );
      },
      onSuccess: (response) {
        if (response.isEmpty) {
          isFinishLoadMore = true;
        }
        notifyListeners();
        _isLoadMoreActive = false;
        value.data.addAll(response);
      },
      onError: (exception, trace) {
        if (kDebugMode) {
          print(exception);
        }
        if (kDebugMode) {
          print(trace);
        }
        _isLoadMoreActive = false;
      },
    );
    if (res == null || res.isEmpty) {
      return false;
    }
    return true;
  }

  Future onUserTab(BuildContext context, VGroupMember user) async {
    if (user.userData.isMe) {
      return;
    }
    final data = <ModelSheetItem<int>>[];
    data.add(ModelSheetItem(
      title: S.of(context).profile,
      id: 5,
      iconData: Icon(PhosphorIcons.user()),
    ));
    if (myGroupInfo.isMeAdminOrSuperAdmin &&
        !user.userData.isMe &&
        user.role != VGroupMemberRole.superAdmin) {
      if (user.role == VGroupMemberRole.admin) {
        data.add(ModelSheetItem(
          title: S.of(context).dismissesToMember,
          id: 2,
          iconData: Icon(PhosphorIcons.arrowDown()),
        ));
      } else {
        data.add(ModelSheetItem(
          title: S.of(context).upgradeToAdmin,
          id: 3,
          iconData: Icon(PhosphorIcons.arrowUp()),
        ));
      }
      data.add(ModelSheetItem(
        title: "Remove member",
        id: 4,
        iconData: Icon(PhosphorIcons.trash()),
      ));
    }

    final res = await VAppAlert.showModalSheetWithActions(
      content: data,
      title: "${user.userData.fullName} ${S.of(context).actions}",
      context: context,
    ) as ModelSheetItem<int>?;
    if (res == null) {
      return;
    }
    if (res.id == 1) {
      if (user.userData.isMe) {
        return;
      }
      await VChatController.I.roomApi.openChatWith(
        peerId: user.userData.id,
      );
      return;
    }
    if (res.id == 5) {
      _peerProfile(context, user.userData.id);
      return;
    }
    final yesOkRes = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: S.of(context).areYouSure,
      content: getContent(context, res.id, user.userData.fullName),
    );
    if (yesOkRes != 1) return;
    if (res.id == 2) {
      //to member
      _setToMember(context, user.userData.id);
    }
    if (res.id == 3) {
      //to admin
      _setToAdmin(context, user.userData.id);
    }
    if (res.id == 4) {
      //to kick

      _kickMember(context, user.userData.id);
    }
  }

  void _setToAdmin(BuildContext context, String identifier) async {
    await vSafeApiCall(
      request: () async {
        await VChatController.I.roomApi.changeGroupMemberRole(
          roomId: roomId,
          peerId: identifier,
          role: VGroupMemberRole.admin,
        );
      },
      onSuccess: (response) {},
      onError: (exception, trace) {
        VAppAlert.showErrorSnackBar(message: exception, context: context);
      },
    );
    await getData();
  }

  void _setToMember(BuildContext context, String identifier) async {
    await vSafeApiCall(
      request: () async {
        await VChatController.I.roomApi.changeGroupMemberRole(
          roomId: roomId,
          peerId: identifier,
          role: VGroupMemberRole.member,
        );
      },
      onSuccess: (response) {},
      onError: (exception, trace) {
        VAppAlert.showErrorSnackBar(message: exception, context: context);
      },
    );
    await getData();
  }

  void _kickMember(BuildContext context, String identifier) async {
    await vSafeApiCall(
      request: () async {
        await VChatController.I.roomApi.kickGroupUser(
          roomId: roomId,
          peerId: identifier,
        );
      },
      onSuccess: (response) {},
      onError: (exception, trace) {
        VAppAlert.showErrorSnackBar(message: exception, context: context);
      },
    );
    await getData();
  }

  String getContent(BuildContext context, int id, String userName) {
    if (id == 2) {
      //to member
      return S.of(context).youAreAboutToDismissesToMember;
    }
    if (id == 3) {
      return S.of(context).youAreAboutToUpgradeToAdmin;
      //to admin
    }
    if (id == 4) {
      return "You are about to remove $userName";
      //to remove
    }
    return "";
  }

  void _peerProfile(BuildContext context, String id) {
    context.toPage(PeerProfileView(peerId: id));
  }
}
