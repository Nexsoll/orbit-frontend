import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loadmore/loadmore.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../controllers/follow_users_controller.dart';
import 'peer_profile_view.dart';

class FollowUsersPage extends StatefulWidget {
  final String userId;
  final bool isFollowersTab;

  const FollowUsersPage({
    super.key,
    required this.userId,
    required this.isFollowersTab,
  });

  @override
  State<FollowUsersPage> createState() => _FollowUsersPageState();
}

class _FollowUsersPageState extends State<FollowUsersPage> {
  late final FollowUsersController controller;
  bool _privacyDialogShown = false;

  String _normalizeImageUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return v;
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    return '${SConstants.baseMediaUrl}$v';
  }

  @override
  void initState() {
    super.initState();
    controller = FollowUsersController(
      userId: widget.userId,
      isFollowersTab: widget.isFollowersTab,
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
    final title = widget.isFollowersTab
        ? S.of(context).followersLabel
        : 'Following';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text(title),
      ),
      child: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<SLoadingState<List<SBaseUser>>>(
          valueListenable: controller,
          builder: (_, value, ___) {
            final err = (value.stateError ?? '').toLowerCase();
            final isPrivate = err.contains('private');
            if (!_privacyDialogShown &&
                isPrivate &&
                value.loadingState == VChatLoadingState.error) {
              _privacyDialogShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                final listName =
                    widget.isFollowersTab ? 'followers' : 'following';
                await showCupertinoDialog(
                  context: context,
                  builder: (ctx) => CupertinoAlertDialog(
                    title: const Text('List is private'),
                    content: Text('This user has hidden their $listName list.'),
                    actions: [
                      CupertinoDialogAction(
                        isDefaultAction: true,
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                if (!mounted) return;
                Navigator.of(context).maybePop();
              });
            }

            return VAsyncWidgetsBuilder(
              loadingState: value.loadingState,
              onRefresh: controller.getData,
              errorWidget: () {
                return const SizedBox.shrink();
              },
              successWidget: () {
              return LoadMore(
                onLoadMore: controller.onLoadMore,
                isFinish: controller.isFinishLoadMore,
                textBuilder: (status) => "",
                child: ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    final user = value.data[index];
                    return CupertinoListTile.notched(
                      padding: EdgeInsets.zero,
                      trailing: const Icon(CupertinoIcons.chevron_forward),
                      title: SUserNameWithBadge(
                        fullName: user.fullName,
                        isVerified: false,
                      ),
                      leadingSize: 40,
                      onTap: () {
                        context.toPage(PeerProfileView(peerId: user.id));
                      },
                      leading: VCircleAvatar(
                        vFileSource: VPlatformFile.fromUrl(
                          networkUrl: _normalizeImageUrl(user.userImage),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return Divider(
                      thickness: .7,
                      color: Colors.grey.withOpacity(.5),
                      height: 15,
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
    );
  }
}
