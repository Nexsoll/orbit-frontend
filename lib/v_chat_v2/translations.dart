// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

VMessageLocalization vMessageLocalizationPageModel(BuildContext context) {
  return VMessageLocalization(
    youDontHaveAccess: S.of(context).youDontHaveAccess,
    star: S.of(context).star,
    unStar: S.of(context).unStar,
    replyToYourSelf: S.of(context).replyToYourSelf,
    repliedToYourSelf: S.of(context).repliedToYourSelf,
    yesterday: S.of(context).yesterday,
    today: S.of(context).today,
    areYouWantToMakeVideoCall: S.of(context).areYouWantToMakeVideoCall,
    areYouWantToMakeVoiceCall: S.of(context).areYouWantToMakeVoiceCall,
    audioCall: S.of(context).audioCall,
    block: S.of(context).block,
    cancel: S.of(context).cancel,
    canceled: S.of(context).canceled,
    connecting: S.of(context).connecting,
    copy: S.of(context).copy,
    delete: S.of(context).delete,
    deleteFromAll: S.of(context).deleteFromAll,
    deleteFromMe: S.of(context).deleteFromMe,
    download: S.of(context).download,
    downloading: S.of(context).downloading,
    fileHasBeenSavedTo: S.of(context).fileHasBeenSavedTo,
    finished: S.of(context).finished,
    forward: S.of(context).forward,
    inCall: S.of(context).inCall,
    info: S.of(context).info,
    makeCall: S.of(context).makeCall,
    members: S.of(context).members,
    messageHasBeenDeleted: S.of(context).messageHasBeenDeleted,
    ok: S.of(context).ok,
    online: S.of(context).online,
    reply: S.of(context).reply,
    ring: S.of(context).ring,
    search: S.of(context).search,
    sessionEnd: S.of(context).sessionEnd,
    share: S.of(context).share,
    timeout: S.of(context).timeout,
    typing: S.of(context).typing,
    unBlock: S.of(context).unBlock,
    vInputLanguage: VInputLanguage(
      cancel: S.of(context).cancel,
      files: S.of(context).files,
      shareMediaAndLocation: S.of(context).shareMediaAndLocation,
      textFieldHint: S.of(context).textFieldHint,
      thereIsFileHasSizeBiggerThanAllowedSize:
          S.of(context).thereIsFileHasSizeBiggerThanAllowedSize,
      thereIsVideoSizeBiggerThanAllowedSize:
          S.of(context).thereIsVideoSizeBiggerThanAllowedSize,
      location: S.of(context).location,
      media: S.of(context).media,
    ),
    recording: S.of(context).recording,
    rejected: S.of(context).rejected,
    oneTimeMessageSent: "One time message sent",
    chatsAndCallsAreEndToEndEncrypted:
        "Chats and calls are end-to-end encrypted. Only people in this chat can read, listen to, or share them.",
    vMessagesInfoTrans: VMessagesInfoTrans(
      updateTitleTo: S.of(context).updateTitleTo,
      updateImage: S.of(context).updateImage,
      promotedToAdminBy: S.of(context).promotedToAdminBy,
      leftTheGroup: S.of(context).leftTheGroup,
      kickedBy: "Removed by",
      joinedBy: S.of(context).joinedBy,
      groupCreatedBy: S.of(context).groupCreatedBy,
      groupDeletedBy: "Group deleted by",
      dismissedToMemberBy: S.of(context).dismissedToMemberBy,
      addedYouToNewBroadcast: S.of(context).addedYouToNewBroadcast,
      you: S.of(context).you,
    ),
  );
}

VRoomLanguage vRoomLanguageModel(BuildContext context) {
  return VRoomLanguage(
    cancel: S.of(context).cancel,
    ok: S.of(context).ok,
    areYouSureToLeaveThisGroupThisActionCantUndo:
        S.of(context).areYouSureToLeaveThisGroupThisActionCantUndo,
    areYouSureToPermitYourCopyThisActionCantUndo:
        S.of(context).areYouSureToPermitYourCopyThisActionCantUndo,
    connecting: S.of(context).connecting,
    delete: S.of(context).delete,
    deleteYouCopy: S.of(context).deleteYouCopy,
    leaveGroup: S.of(context).leaveGroup,
    leaveGroupAndDeleteYourMessageCopy:
        S.of(context).leaveGroupAndDeleteYourMessageCopy,
    messageHasBeenDeleted: S.of(context).messageHasBeenDeleted,
    mute: S.of(context).mute,
    recording: S.of(context).recording,
    report: S.of(context).report,
    typing: S.of(context).typing,
    unMute: S.of(context).unMute,
    vMessageInfoTrans: VMessageInfoTrans(
      addedYouToNewBroadcast: S.of(context).addedYouToNewBroadcast,
      dismissedToMemberBy: S.of(context).dismissedToMemberBy,
      groupCreatedBy: S.of(context).groupCreatedBy,
      groupDeletedBy: "Group deleted by",
      joinedBy: S.of(context).joinedBy,
      kickedBy: "Removed by",
      leftTheGroup: S.of(context).leftTheGroup,
      promotedToAdminBy: S.of(context).promotedToAdminBy,
      updateImage: S.of(context).updateImage,
      updateTitleTo: S.of(context).updateTitleTo,
      you: S.of(context).you,
    ),
    yesterdayLabel: S.of(context).yesterday,
  );
}
