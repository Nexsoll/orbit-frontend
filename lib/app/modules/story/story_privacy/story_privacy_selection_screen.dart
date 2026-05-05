import 'package:flutter/cupertino.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../choose_members/views/choose_members_view.dart';

class StoryPrivacySelectionScreen extends StatefulWidget {
  final Function(StoryPrivacy privacy, List<String>? selectedUserIds,
      List<String>? excludedUserIds) onPrivacySelected;

  const StoryPrivacySelectionScreen({
    super.key,
    required this.onPrivacySelected,
  });

  @override
  State<StoryPrivacySelectionScreen> createState() =>
      _StoryPrivacySelectionScreenState();
}

class _StoryPrivacySelectionScreenState
    extends State<StoryPrivacySelectionScreen> {
  StoryPrivacy _selectedPrivacy = StoryPrivacy.public;
  List<SBaseUser> _selectedUsers = [];
  List<SBaseUser> _excludedUsers = [];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        middle: Text(S.of(context).yourStory),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _onDone,
          child: Text(
            S.of(context).done,
            style: const TextStyle(
              color: CupertinoColors.activeBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Who can see your story?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    CupertinoListSection(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        CupertinoListTile(
                          leading: const Icon(
                            CupertinoIcons.globe,
                            color: CupertinoColors.activeBlue,
                          ),
                          title: const Text('Everyone'),
                          subtitle: const Text('Share with all your contacts'),
                          trailing: _selectedPrivacy == StoryPrivacy.public
                              ? const Icon(
                                  CupertinoIcons.check_mark_circled_solid,
                                  color: CupertinoColors.activeBlue,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedPrivacy = StoryPrivacy.public;
                              _selectedUsers.clear();
                            });
                          },
                        ),
                        CupertinoListTile(
                          leading: const Icon(
                            CupertinoIcons.person_2,
                            color: CupertinoColors.activeBlue,
                          ),
                          title: const Text('Only Share With'),
                          subtitle: _selectedUsers.isEmpty
                              ? const Text('Choose specific contacts')
                              : Text(
                                  '${_selectedUsers.length} contacts selected'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_selectedPrivacy == StoryPrivacy.somePeople)
                                const Icon(
                                  CupertinoIcons.check_mark_circled_solid,
                                  color: CupertinoColors.activeBlue,
                                ),
                              const SizedBox(width: 8),
                              const Icon(
                                CupertinoIcons.chevron_right,
                                color: CupertinoColors.systemGrey,
                                size: 16,
                              ),
                            ],
                          ),
                          onTap: _selectContacts,
                        ),
                        CupertinoListTile(
                          leading: const Icon(
                            CupertinoIcons.person_2_alt,
                            color: CupertinoColors.activeBlue,
                          ),
                          title: const Text('My contacts except'),
                          subtitle: _excludedUsers.isEmpty
                              ? const Text('Exclude specific contacts')
                              : Text(
                                  '${_excludedUsers.length} contacts excluded'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_selectedPrivacy ==
                                  StoryPrivacy.myContactsExcept)
                                const Icon(
                                  CupertinoIcons.check_mark_circled_solid,
                                  color: CupertinoColors.activeBlue,
                                ),
                              const SizedBox(width: 8),
                              const Icon(
                                CupertinoIcons.chevron_right,
                                color: CupertinoColors.systemGrey,
                                size: 16,
                              ),
                            ],
                          ),
                          onTap: _selectExcludedContacts,
                        ),
                      ],
                    ),
                    if (_selectedUsers.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected contacts:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _selectedUsers[index];
                                  return Container(
                                    width: 60,
                                    margin: const EdgeInsets.only(right: 12),
                                    child: Column(
                                      children: [
                                        VCircleAvatar(
                                          vFileSource: VPlatformFile.fromUrl(
                                            networkUrl: user.userImage,
                                          ),
                                          radius: 22,
                                        ),
                                        const SizedBox(height: 6),
                                        Expanded(
                                          child: Text(
                                            user.fullName.split(' ').first,
                                            style:
                                                const TextStyle(fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectContacts() async {
    final selectedUsers = await Navigator.of(context).push<List<SBaseUser>>(
      CupertinoPageRoute(
        builder: (context) => ChooseMembersView(
          maxCount: 100, // Allow selecting up to 100 contacts
          onDone: (users) {
            Navigator.of(context).pop(users);
          },
          onCloseSheet: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    if (selectedUsers != null && selectedUsers.isNotEmpty) {
      setState(() {
        _selectedPrivacy = StoryPrivacy.somePeople;
        _selectedUsers = selectedUsers;
        _excludedUsers
            .clear(); // Clear excluded users when selecting specific users
      });
    }
  }

  void _selectExcludedContacts() async {
    final excludedUsers = await Navigator.of(context).push<List<SBaseUser>>(
      CupertinoPageRoute(
        builder: (context) => ChooseMembersView(
          maxCount: 100, // Allow excluding up to 100 contacts
          onDone: (users) {
            Navigator.of(context).pop(users);
          },
          onCloseSheet: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    if (excludedUsers != null) {
      setState(() {
        _selectedPrivacy = StoryPrivacy.myContactsExcept;
        _excludedUsers = excludedUsers;
        _selectedUsers
            .clear(); // Clear selected users when excluding specific users
      });
    }
  }

  void _onDone() {
    List<String>? selectedUserIds;
    List<String>? excludedUserIds;

    if (_selectedPrivacy == StoryPrivacy.somePeople &&
        _selectedUsers.isNotEmpty) {
      selectedUserIds = _selectedUsers.map((user) => user.id).toList();
    } else if (_selectedPrivacy == StoryPrivacy.myContactsExcept &&
        _excludedUsers.isNotEmpty) {
      excludedUserIds = _excludedUsers.map((user) => user.id).toList();
    }

    widget.onPrivacySelected(
        _selectedPrivacy, selectedUserIds, excludedUserIds);
    Navigator.of(context).pop();
  }
}
