import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../mobile/settings_tab/widgets/settings_list_item_tile.dart';
import '../../../choose_members/views/choose_members_view.dart';

class MyPrivacyPage extends StatefulWidget {
  const MyPrivacyPage({super.key});

  @override
  State<MyPrivacyPage> createState() => _MyPrivacyPageState();
}

class _MyPrivacyPageState extends State<MyPrivacyPage> {
  UserPrivacy _userPrivacy = AppAuth.myProfile.userPrivacy;
  final _profileApi = GetIt.instance.get<ProfileApiService>();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false, // 👈 disables Hero animation
            largeTitle: Text(S.of(context).myPrivacy),
          )
        ],
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 10,
              ),
              S.of(context).configureYourAccountPrivacy.text.color(Colors.grey),
              CupertinoListSection(
                dividerMargin: 0,
                topMargin: 10,
                additionalDividerMargin: 0,
                margin: EdgeInsets.zero,
                hasLeading: false,
                children: [
                  SettingsListItemTile(
                    color: Colors.amber,
                    title: S.of(context).youInPublicSearch,
                    subtitle: S
                        .of(context)
                        .yourProfileAppearsInPublicSearchAndAddingForGroups
                        .text,
                    icon: Icons.search,
                    trailing: CupertinoSwitch(
                      value: _userPrivacy.publicSearch,
                      onChanged: _onUpdatePublicSearch,
                    ),
                  ),
                  SettingsListItemTile(
                    color: Colors.green,
                    title: S.of(context).yourLastSeen,
                    subtitle: S.of(context).yourLastSeenInChats.text,
                    icon: Icons.last_page_rounded,
                    trailing: CupertinoSwitch(
                      value: _userPrivacy.lastSeen,
                      onChanged: _onUpdateLastSeen,
                    ),
                  ),
                  SettingsListItemTile(
                    color: Colors.purple,
                    title: 'Read receipts',
                    subtitle:
                        'Keep messages marked as delivered unless you send read receipts'
                            .text,
                    icon: CupertinoIcons.check_mark_circled_solid,
                    trailing: CupertinoSwitch(
                      value: _userPrivacy.readReceipts,
                      onChanged: _onUpdateReadReceipts,
                    ),
                  ),
                  SettingsListItemTile(
                    color: Colors.deepPurple,
                    title: 'Hide followers list',
                    subtitle: 'Others cannot view your followers list'.text,
                    icon: CupertinoIcons.eye_slash,
                    trailing: CupertinoSwitch(
                      value: _userPrivacy.hideFollowers,
                      onChanged: _onUpdateHideFollowers,
                    ),
                  ),
                  SettingsListItemTile(
                    color: Colors.deepPurple,
                    title: 'Hide following list',
                    subtitle: 'Others cannot view your following list'.text,
                    icon: CupertinoIcons.eye_slash,
                    trailing: CupertinoSwitch(
                      value: _userPrivacy.hideFollowing,
                      onChanged: _onUpdateHideFollowing,
                    ),
                  ),
                  SettingsListItemTile(
                    color: Colors.deepPurple,
                    title: 'Hide both lists',
                    subtitle:
                        'Others cannot view your followers or following lists'
                            .text,
                    icon: CupertinoIcons.eye_slash_fill,
                    trailing: CupertinoSwitch(
                      value: _userPrivacy.hideFollowers &&
                          _userPrivacy.hideFollowing,
                      onChanged: _onUpdateHideBothFollowLists,
                    ),
                  ),
                  SettingsListItemTile(
                    color: Colors.indigo,
                    title: 'Who can add me to groups',
                    subtitle: (_userPrivacy.groupAddPermission ==
                                UserPrivacyType.public
                            ? 'Everyone'
                            : 'By request')
                        .text,
                    icon: CupertinoIcons.person_3_fill,
                    onTap: _onUpdateWhoCanAddMeToGroups,
                  ),
                  SettingsListItemTile(
                    color: Colors.orange,
                    title: 'Who cannot call me',
                    subtitle: (_userPrivacy.callBlockedUsers.isEmpty
                            ? 'No one is blocked'
                            : 'Blocked ${_userPrivacy.callBlockedUsers.length} users')
                        .text,
                    icon: CupertinoIcons.phone_fill,
                    onTap: _onChooseCallBlockedUsers,
                  ),
                  SettingsListItemTile(
                    color: Colors.blue,
                    title: S.of(context).yourStory,
                    subtitle: _getTrans(_userPrivacy.showStory).text,
                    onTap: _onUpdateShowStory,
                    icon: Icons.history_toggle_off_rounded,
                  ),
                  SettingsListItemTile(
                    color: Colors.cyan,
                    title: 'Allow screenshots in story',
                    subtitle:
                        'Others can take screenshots while viewing your stories'
                            .text,
                    icon: Icons.camera_alt_outlined,
                    trailing: CupertinoSwitch(
                      value: _userPrivacy.allowStoryScreenshot,
                      onChanged: _onUpdateAllowStoryScreenshot,
                    ),
                  ),
                  SettingsListItemTile(
                    color: Colors.teal,
                    title: 'Who cannot view my profile photo',
                    subtitle: (_userPrivacy.profilePicBlockedUsers.isEmpty
                            ? 'No one is blocked'
                            : 'Blocked ${_userPrivacy.profilePicBlockedUsers.length} users')
                        .text,
                    icon: CupertinoIcons.person_crop_circle,
                    onTap: _onChooseProfilePhotoBlockedUsers,
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onChooseCallBlockedUsers() async {
    final selectedUsers = await Navigator.of(context).push<List<SBaseUser>>(
      CupertinoPageRoute(
        builder: (context) => ChooseMembersView(
          maxCount: 500,
          initialSelectedUserIds: _userPrivacy.callBlockedUsers,
          enforceGroupAddPermission: false,
          onDone: (users) {
            Navigator.of(context).pop(users);
          },
          onCloseSheet: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
    if (selectedUsers == null) return;
    final ids = selectedUsers.map((u) => u.id).toList();
    _userPrivacy = _userPrivacy.copyWith(
      callBlockedUsers: ids,
      // Ensure calls remain generally allowed for everyone except blocked users
      callPermission: UserPrivacyType.public,
      callAllowedUsers: const [],
    );
    await _updateLocalProfile();
  }

  Future<void> _onChooseProfilePhotoBlockedUsers() async {
    final selectedUsers = await Navigator.of(context).push<List<SBaseUser>>(
      CupertinoPageRoute(
        builder: (context) => ChooseMembersView(
          maxCount: 500,
          initialSelectedUserIds: _userPrivacy.profilePicBlockedUsers,
          enforceGroupAddPermission: false,
          onDone: (users) {
            Navigator.of(context).pop(users);
          },
          onCloseSheet: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
    if (selectedUsers == null) return;
    final ids = selectedUsers.map((u) => u.id).toList();
    _userPrivacy = _userPrivacy.copyWith(
      profilePicBlockedUsers: ids,
      // Clear legacy allow-list to ensure deny-list is the active rule
      profilePicAllowedUsers: const [],
    );
    await _updateLocalProfile();
  }

  Future<void> _onUpdatePublicSearch(bool value) async {
    _userPrivacy = _userPrivacy.copyWith(publicSearch: value);
    await _updateLocalProfile();
  }

  Future<void> _onUpdateLastSeen(bool value) async {
    _userPrivacy = _userPrivacy.copyWith(lastSeen: value);
    await _updateLocalProfile();
  }

  Future<void> _onUpdateReadReceipts(bool value) async {
    _userPrivacy = _userPrivacy.copyWith(readReceipts: value);
    await _updateLocalProfile();
  }

  Future<void> _onUpdateHideFollowers(bool value) async {
    _userPrivacy = _userPrivacy.copyWith(hideFollowers: value);
    await _updateLocalProfile();
  }

  Future<void> _onUpdateHideFollowing(bool value) async {
    _userPrivacy = _userPrivacy.copyWith(hideFollowing: value);
    await _updateLocalProfile();
  }

  Future<void> _onUpdateHideBothFollowLists(bool value) async {
    _userPrivacy = _userPrivacy.copyWith(
      hideFollowers: value,
      hideFollowing: value,
    );
    await _updateLocalProfile();
  }

  Future<void> _onUpdateAllowStoryScreenshot(bool value) async {
    _userPrivacy = _userPrivacy.copyWith(allowStoryScreenshot: value);
    await _updateLocalProfile();
  }

  Future<void> _onUpdateWhoCanAddMeToGroups() async {
    final res = await VAppAlert.showModalSheetWithActions<UserPrivacyType>(
      context: context,
      content: [
        ModelSheetItem<UserPrivacyType>(
          title: 'Everyone',
          id: UserPrivacyType.public,
        ),
        ModelSheetItem<UserPrivacyType>(
          title: S.of(context).forRequest,
          id: UserPrivacyType.forReq,
        ),
      ],
    ) as ModelSheetItem<UserPrivacyType>?;
    if (res == null) return;
    _userPrivacy = _userPrivacy.copyWith(groupAddPermission: res.id);
    await _updateLocalProfile();
  }

  Future<void> _onUpdateStartChat() async {
    final res = await VAppAlert.showModalSheetWithActions<UserPrivacyType>(
      context: context,
      content: [
        ModelSheetItem<UserPrivacyType>(
          title: S.of(context).forRequest,
          id: UserPrivacyType.forReq,
        ),
        ModelSheetItem<UserPrivacyType>(
          title: S.of(context).public,
          id: UserPrivacyType.public,
        ),
      ],
    ) as ModelSheetItem<UserPrivacyType>?;
    if (res == null) return;
    _userPrivacy = _userPrivacy.copyWith(startChat: res.id);
    await _updateLocalProfile();
  }

  Future<void> _onUpdateShowStory() async {
    final res = await VAppAlert.showModalSheetWithActions<UserPrivacyType>(
      context: context,
      content: [
        ModelSheetItem<UserPrivacyType>(
          title: S.of(context).forRequest,
          id: UserPrivacyType.forReq,
        ),
        ModelSheetItem<UserPrivacyType>(
          title: S.of(context).public,
          id: UserPrivacyType.public,
        ),
      ],
    ) as ModelSheetItem<UserPrivacyType>?;
    if (res == null) return;
    _userPrivacy = _userPrivacy.copyWith(showStory: res.id);

    await _updateLocalProfile();
  }

  Future<void> _updateLocalProfile() async {
    final newProfile = AppAuth.myProfile.copyWith(
      userPrivacy: _userPrivacy,
    );
    await VAppPref.setMap(SStorageKeys.myProfile.name, newProfile.toMap());
    AppAuth.setProfileNull();
    setState(() {});
    _updateInApi();
  }

  String _getTrans(UserPrivacyType type) {
    switch (type) {
      case UserPrivacyType.forReq:
        return S.of(context).forRequest;
      case UserPrivacyType.public:
        return S.of(context).public;
      case UserPrivacyType.none:
        return S.of(context).none;
    }
  }

  Future _updateInApi() async {
    vSafeApiCall(
      request: () async {
        return _profileApi.updatePrivacy(_userPrivacy);
      },
      onSuccess: (response) {},
      onError: (exception, trace) {
        VAppAlert.showErrorSnackBar(message: exception, context: context);
        print(exception);
      },
    );
  }
}
