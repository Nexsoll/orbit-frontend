// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:s_translation/generated/l10n.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class AuthTrUtils {
  static String? tr(ApiI18nErrorRes? err) {
    if (err == null) return null;
    final context = VChatController.I.navigatorKey.currentState!.context;
    switch (err) {
      case ApiI18nErrorRes.invalidLoginData:
        return S.of(context).invalidLoginData;
      case ApiI18nErrorRes.userEmailNotFound:
        return S.of(context).userEmailNotFound;
      case ApiI18nErrorRes.yourAccountBlocked:
        return S.of(context).yourAccountBlocked;
      case ApiI18nErrorRes.yourAccountDeleted:
        return S.of(context).yourAccountDeleted;
      case ApiI18nErrorRes.userAlreadyRegister:
        return S.of(context).userAlreadyRegister;
      case ApiI18nErrorRes.codeHasBeenExpired:
        return S.of(context).codeHasBeenExpired;
      case ApiI18nErrorRes.invalidCode:
        return S.of(context).invalidCode;
      case ApiI18nErrorRes.whileAuthCanFindYou:
        return S.of(context).whileAuthCanFindYou;
      case ApiI18nErrorRes.userRegisterStatusNotAcceptedYet:
        return S.of(context).userRegisterStatusNotAcceptedYet;
      case ApiI18nErrorRes.deviceHasBeenLogoutFromAllDevices:
        return S.of(context).deviceHasBeenLogoutFromAllDevices;
      case ApiI18nErrorRes.userDeviceSessionEndDeviceDeleted:
        return S.of(context).userDeviceSessionEndDeviceDeleted;
      case ApiI18nErrorRes.noCodeHasBeenSendToYouToVerifyYourEmail:
        return S.of(context).noCodeHasBeenSendToYouToVerifyYourEmail;
      case ApiI18nErrorRes.roomAlreadyInCall:
        return S.of(context).roomAlreadyInCall;
      case ApiI18nErrorRes.peerUserInCallNow:
        return S.of(context).peerUserInCallNow;
      case ApiI18nErrorRes.callNotAllowed:
        return S.of(context).callNotAllowed;
      case ApiI18nErrorRes.peerUserDeviceOffline:
        return S.of(context).peerUserDeviceOffline;
      case ApiI18nErrorRes.emailMustBeValid:
        return S.of(context).emailMustBeValid;
      case ApiI18nErrorRes.wait2MinutesToSendMail:
        return S.of(context).wait2MinutesToSendMail;
    }
  }
}
