// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class GroupRoomSettingState {
  final VToChatSettingsModel settingsModel;
  bool isUpdatingMute = false;
  bool isUpdatingOneSeen = false;
  bool isUpdatingExitGroup = false;
  bool isUpdatingDeleteGroup = false;
  VMyGroupInfo? groupInfo;
  // Custom per-group notification sound
  String? customSoundTitle;
  bool isUpdatingCustomSound = false;
  // Chat lock status
  bool isLocked = false;
  bool isUpdatingLock = false;
  GroupRoomSettingState(this.settingsModel);
}
