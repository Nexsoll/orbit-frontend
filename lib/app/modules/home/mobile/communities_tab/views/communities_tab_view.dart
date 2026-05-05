// Copyright 2025, Orbit
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:super_up/app/core/widgets/custom_image_cropper.dart';

import '../../../../create_group/mobile/sheet_for_create_group.dart';

import '../controllers/communities_tab_controller.dart';
import '../../../../../core/api_service/community/community_api_service.dart';

class CommunitiesTabView extends StatefulWidget {
  const CommunitiesTabView({super.key});

  @override
  State<CommunitiesTabView> createState() => _CommunitiesTabViewState();
}

class _AnnouncementsFeed extends StatelessWidget {
  final List<Map<String, dynamic>> feed;
  final bool isLoading;
  final void Function(Map<String, dynamic>) onDelete;
  final String Function(String?) mediaUrl;
  const _AnnouncementsFeed({
    required this.feed,
    required this.isLoading,
    required this.onDelete,
    required this.mediaUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(S.of(context).announcements, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          const Center(child: CupertinoActivityIndicator()),
        ],
      );
    }
    if (feed.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(S.of(context).announcements, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        ...feed.map((ann) => _FeedItemCard(ann: ann, onDelete: onDelete, mediaUrl: mediaUrl)).toList(),
      ],
    );
  }
}

class _FeedItemCard extends StatelessWidget {
  final Map<String, dynamic> ann;
  final void Function(Map<String, dynamic>) onDelete;
  final String Function(String?) mediaUrl;
  const _FeedItemCard({required this.ann, required this.onDelete, required this.mediaUrl});

  @override
  Widget build(BuildContext context) {
    final title = (ann['title']?.toString() ?? '').trim();
    final content = (ann['content']?.toString() ?? '').trim();
    final community = (ann['community'] is Map) ? Map<String, dynamic>.from(ann['community'] as Map) : null;
    final cName = community?['name']?.toString() ?? '';
    final cImg = mediaUrl(community?['img']?.toString());
    final isAdmin = ann['isAdmin'] == true;

    return GestureDetector(
      onTap: () {
        final cId = (community?['_id']?.toString() ?? ann['cId']?.toString());
        if (cId == null || cId.isEmpty) return;
        final data = {
          '_id': cId,
          'name': cName,
          'img': community?['img']?.toString() ?? '',
          'desc': '',
        };
        context.toPage(CommunityDetailView(community: data));
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (cImg.isNotEmpty)
                CircleAvatar(backgroundImage: NetworkImage(cImg), radius: 14)
              else
                const CircleAvatar(radius: 14, backgroundColor: Colors.grey, child: Icon(CupertinoIcons.person_2, size: 14, color: Colors.white)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(cName.isEmpty ? S.of(context).community : cName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87), overflow: TextOverflow.ellipsis),
              ),
              if (isAdmin)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minSize: 26,
                  onPressed: () => onDelete(ann),
                  child: Text(S.of(context).delete, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (title.isNotEmpty)
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
          if (title.isNotEmpty) const SizedBox(height: 4),
          if (content.isNotEmpty)
            Text(content, style: const TextStyle(fontSize: 14, height: 1.35, color: Colors.black)),
        ],
      ),
    ),
  );
}
}

class _AnnouncementTile extends StatelessWidget {
  final Map<String, dynamic> ann;
  final String Function(String?) mediaUrl;
  const _AnnouncementTile({required this.ann, required this.mediaUrl});

  @override
  Widget build(BuildContext context) {
    final title = (ann['title']?.toString() ?? '').trim();
    final content = (ann['content']?.toString() ?? '').trim();
    final pinned = ann['pinned'] == true;
    final userData = (ann['userData'] is Map)
        ? Map<String, dynamic>.from(ann['userData'] as Map)
        : const <String, dynamic>{};
    final authorName = userData['fullName']?.toString() ?? '';
    final authorImg = mediaUrl(userData['userImage']?.toString());
    DateTime? createdAt;
    try {
      final raw = ann['createdAt']?.toString();
      if (raw != null && raw.isNotEmpty) createdAt = DateTime.tryParse(raw);
    } catch (_) {}

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (pinned)
                const Icon(CupertinoIcons.pin_fill, size: 16, color: Color(0xFFB48648)),
              if (pinned) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.isEmpty ? S.of(context).announcements : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (content.isNotEmpty)
            Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.35, color: Colors.black),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (authorImg.isNotEmpty)
                VCircleAvatar(
                  radius: 14,
                  vFileSource: VPlatformFile.fromUrl(networkUrl: authorImg),
                )
              else
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey,
                  child: Icon(CupertinoIcons.person_solid, size: 14, color: Colors.white),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  authorName.isEmpty ? S.of(context).admin : authorName,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (createdAt != null)
                Text(
                  _fmtTime(createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}

class _CommunitiesTabViewState extends State<CommunitiesTabView> {
  late final CommunitiesTabController controller;
  final CommunityApiService _api = GetIt.I.get<CommunityApiService>();
  final _searchCtrl = TextEditingController();
  String _query = '';
  final _feed = <Map<String, dynamic>>[];
  bool _feedLoading = false;

  @override
  void initState() {
    super.initState();
    controller = CommunitiesTabController();
    controller.onInit();
    _loadFeed();
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) {
      final name = (c['name']?.toString() ?? '').toLowerCase();
      final desc = (c['desc']?.toString() ?? '').toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  @override
  void dispose() {
    controller.onClose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() => _feedLoading = true);
    try {
      final list = await _api.getMyAnnouncements(page: 1, limit: 20);
      _feed
        ..clear()
        ..addAll(list);
    } catch (_) {}
    if (mounted) setState(() => _feedLoading = false);
  }

  Future<void> _deleteAnnouncement(Map<String, dynamic> ann) async {
    final res = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: S.of(context).deleteAnnouncementQuestion,
      content: S.of(context).thisActionCannotBeUndone,
    );
    if (res != 1) return;
    try {
      final cId = ann['cId']?.toString() ?? ann['community']?['_id']?.toString();
      final id = ann['_id']?.toString();
      if (cId == null || id == null) throw Exception('Missing identifiers');
      await _api.deleteAnnouncement(communityId: cId, id: id);
      _feed.removeWhere((e) => e['_id']?.toString() == id);
      if (mounted) setState(() {});
      VAppAlert.showSuccessSnackBar(context: context, message: S.of(context).deleted);
    } catch (e) {
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  String _mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final apiBase = SConstants.sApiBaseUrl;
    final origin = Uri(
      scheme: apiBase.scheme,
      host: apiBase.host,
      port: apiBase.hasPort ? apiBase.port : null,
    );
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return origin.resolve(normalized).toString();
  }

  Future<void> _createCommunityDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isLoading = false;
    VPlatformFile? imageFile;

    await showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSt) {
          return CupertinoAlertDialog(
            title: Text(S.of(context).createCommunity),
            content: Column(
              children: [
                const SizedBox(height: 8),
                Center(
                  child: AppImagePicker(
                    onDone: (VPlatformFile file) {
                      imageFile = file;
                    },
                    initImage: VPlatformFile.fromAssets(
                      assetsPath: "assets/ic_addphoto.png",
                    ),
                    withCrop: true,
                    size: 100,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: nameCtrl,
                  placeholder: S.of(context).communityName,
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: descCtrl,
                  placeholder: S.of(context).descriptionOptional,
                ),
                if (isLoading) ...[
                  const SizedBox(height: 12),
                  const CupertinoActivityIndicator(),
                ]
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context).cancel),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setSt(() => isLoading = true);
                  try {
                    final created = await _api.createCommunity(
                      name: nameCtrl.text.trim(),
                      desc: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      image: imageFile,
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    controller.addCommunity(created);
                    // Also refresh from server shortly after to ensure membership is persisted
                    // ignore: unawaited_futures
                    Future.delayed(const Duration(milliseconds: 900), () => controller.load());
                    VAppAlert.showSuccessSnackBar(
                      message: S.of(context).communityCreated,
                      context: context,
                    );
                  } catch (e) {
                    setSt(() => isLoading = false);
                    VAppAlert.showErrorSnackBar(
                      message: e.toString(),
                      context: context,
                    );
                  }
                },
                child: Text(S.of(context).create),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text(S.of(context).communities,
            style: context.cupertinoTextTheme.textStyle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            )),
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            ValueListenableBuilder<SLoadingState<List<Map<String, dynamic>>>>(
              valueListenable: controller,
              builder: (_, value, __) {
                return VAsyncWidgetsBuilder(
                  loadingState: value.loadingState,
                  onRefresh: () async {
                    await controller.load();
                    await _loadFeed();
                  },
                  loadingWidget: () => _HeaderWithContent(
                    header: _Header(searchCtrl: _searchCtrl, onChanged: (v) => setState(() => _query = v)),
                    child: const Center(child: CupertinoActivityIndicator()),
                  ),
                  emptyWidget: () => _HeaderWithContent(
                    header: _Header(searchCtrl: _searchCtrl, onChanged: (v) => setState(() => _query = v)),
                    child: _EmptyState(onCreate: _createCommunityDialog),
                  ),
                  errorWidget: () => _HeaderWithContent(
                    header: _Header(searchCtrl: _searchCtrl, onChanged: (v) => setState(() => _query = v)),
                    child: _ErrorState(onRetry: controller.load),
                  ),
                  successWidget: () {
                    final list = _filtered(value.data);
                    if (list.isEmpty) {
                      return _HeaderWithContent(
                        header: _Header(searchCtrl: _searchCtrl, onChanged: (v) => setState(() => _query = v)),
                        child: _NoResults(onClear: () {
                          setState(() {
                            _query = '';
                            _searchCtrl.clear();
                          });
                        }),
                      );
                    }
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _Header(
                            searchCtrl: _searchCtrl,
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: _AnnouncementsFeed(
                              feed: _feed,
                              isLoading: _feedLoading,
                              onDelete: _deleteAnnouncement,
                              mediaUrl: _mediaUrl,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: .84,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final c = list[i];
                                final img = _mediaUrl(c['img']?.toString());
                                final title = c['name']?.toString() ?? '';
                                final desc = c['desc']?.toString() ?? '';
                                final tag = 'community_${c['_id']}';
                                return _CommunityCard(
                                  tag: tag,
                                  title: title,
                                  subtitle: desc,
                                  imageUrl: img,
                                  onTap: () => context.toPage(
                                    CommunityDetailView(community: c),
                                  ),
                                );
                              },
                              childCount: list.length,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            // Floating Create Button
            Positioned(
              right: 16,
              bottom: 16,
              child: CupertinoButton(
                color: const Color(0xFFB48648),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onPressed: _createCommunityDialog,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.add, color: Colors.white),
                    SizedBox(width: 8),
                    Text(S.of(context).create, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class CommunityDetailView extends StatefulWidget {
  final Map<String, dynamic> community;
  const CommunityDetailView({super.key, required this.community});

  @override
  State<CommunityDetailView> createState() => _CommunityDetailViewState();
}

class _CommunityDetailViewState extends State<CommunityDetailView> {
  final CommunityApiService _api = GetIt.I.get<CommunityApiService>();
  final _groups = <Map<String, dynamic>>[];
  final _announcements = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _isAdmin = false;

  String get cId => widget.community['_id'].toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getCommunityGroups(cId),
        _api.getAnnouncements(cId, page: 1, limit: 50),
        _api.getMyRole(cId),
      ]);
      final groupsRaw = results[0];
      final annsRaw = results[1];
      final roleRaw = results[2];
      final groupsList = (groupsRaw is List ? groupsRaw : const [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final annList = (annsRaw is List ? annsRaw : const [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _groups
        ..clear()
        ..addAll(groupsList);
      _announcements
        ..clear()
        ..addAll(annList);
      try {
        final role = (roleRaw is Map<String, dynamic>) ? roleRaw : <String, dynamic>{};
        _isAdmin = role['isAdmin'] == true;
      } catch (_) {}
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createAnnouncementDialog() async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    bool pinned = false;
    bool isLoading = false;

    await showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSt) {
          return CupertinoAlertDialog(
            title: Text(S.of(context).postAnnouncementTitle),
            content: Column(
              children: [
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: titleCtrl,
                  placeholder: S.of(context).titleOptional,
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: contentCtrl,
                  placeholder: S.of(context).writeYourAnnouncement,
                  maxLines: 5,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(S.of(context).pin),
                    const Spacer(),
                    CupertinoSwitch(
                      value: pinned,
                      onChanged: (v) => setSt(() => pinned = v),
                    ),
                  ],
                ),
                if (isLoading) ...[
                  const SizedBox(height: 12),
                  const CupertinoActivityIndicator(),
                ]
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context).cancel),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  if (contentCtrl.text.trim().isEmpty) return;
                  setSt(() => isLoading = true);
                  try {
                    await _api.createAnnouncement(
                      communityId: cId,
                      title: titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
                      content: contentCtrl.text.trim(),
                      pinned: pinned,
                    );
                    // refresh announcements only
                    final list = await _api.getAnnouncements(cId, page: 1, limit: 50);
                    _announcements
                      ..clear()
                      ..addAll(list);
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    setState(() {});
                    VAppAlert.showSuccessSnackBar(
                      context: context,
                      message: S.of(context).announcementPosted,
                    );
                  } catch (e) {
                    setSt(() => isLoading = false);
                    VAppAlert.showErrorSnackBar(
                      context: context,
                      message: e.toString(),
                    );
                  }
                },
                child: Text(S.of(context).postAction),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _startCreateGroupFlow() async {
    // Reuse existing New group flow from Chats tab
    final vRoom = await showCupertinoModalBottomSheet(
      expand: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const SheetForCreateGroup(),
    ) as VRoom?;
    if (vRoom == null) return;
    try {
      // Attach the newly created room to this community
      await _api.attachExisting(cId, vRoom.id);
      // Refresh groups list
      final groups = await _api.getCommunityGroups(cId);
      _groups
        ..clear()
        ..addAll((groups is List ? groups : const [])
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList());
      if (!mounted) return;
      setState(() {});
      // Navigate to the new group chat
      VChatController.I.vNavigator.messageNavigator.toMessagePage(context, vRoom);
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  Future<void> _openGroupRoom(String roomId, String title) async {
    try {
      VRoom? vRoom;
      final localRoom = await VChatController.I.nativeApi.local.room
          .getOneWithLastMessageByRoomId(roomId);
      if (localRoom != null) {
        vRoom = localRoom;
      } else {
        // Fallback to remote fetch (requires membership)
        vRoom = await VChatController.I.nativeApi.remote.room.getRoomById(roomId);
      }
      if (!mounted) return;
      VChatController.I.vNavigator.messageNavigator.toMessagePage(context, vRoom);
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(
        context: context,
        message: S.of(context).unableToOpenGroup,
      );
    }
  }
  
  Future<void> _changeImage() async {
    final picked = await AppImageCropper.pickAndCrop(context);
    if (picked == null) return;
    try {
      final url = await _api.updateImage(cId, picked);
      if (!mounted) return;
      setState(() {
        widget.community['img'] = url;
      });
      VAppAlert.showSuccessSnackBar(context: context, message: 'Image updated');
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  String _mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final apiBase = SConstants.sApiBaseUrl;
    final origin = Uri(
      scheme: apiBase.scheme,
      host: apiBase.host,
      port: apiBase.hasPort ? apiBase.port : null,
    );
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return origin.resolve(normalized).toString();
  }

  // Removed create group flow per request

  @override
  Widget build(BuildContext context) {
    final name = widget.community['name']?.toString() ?? S.of(context).community;
    final desc = widget.community['desc']?.toString() ?? '';
    final img = _mediaUrl(widget.community['img']?.toString());
    final tag = 'community_${widget.community['_id']}';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text(name),
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          alignment: Alignment.bottomLeft,
                          children: [
                            Hero(
                              tag: tag,
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Container(
                                  decoration: BoxDecoration(
                                    image: img.isEmpty
                                        ? null
                                        : DecorationImage(
                                            image: NetworkImage(img),
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black54,
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_isAdmin)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: CupertinoButton(
                                padding: const EdgeInsets.all(6),
                                minSize: 28,
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(20),
                                onPressed: _changeImage,
                                child: const Icon(CupertinoIcons.camera, color: Colors.white, size: 16),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      desc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Announcements header + action
                          Row(
                            children: [
                              Text(S.of(context).announcements, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                minSize: 30,
                                onPressed: _createAnnouncementDialog,
                                child: Text(S.of(context).postAction),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_announcements.isEmpty)
                            Text(S.of(context).noAnnouncementsYet)
                          else
                            Column(
                              children: [
                                for (int i = 0; i < _announcements.length; i++)
                                  _AnnouncementTile(ann: _announcements[i], mediaUrl: _mediaUrl),
                              ],
                            ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Text(S.of(context).groups, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                minSize: 30,
                                onPressed: _startCreateGroupFlow,
                                child: Text(S.of(context).create),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_groups.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(S.of(context).noGroupsInThisCommunity),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final g = _groups[i];
                          return Column(
                            children: [
                              ListTile(
                                title: Text(g['gName']?.toString() ?? ''),
                                subtitle: const Text(''),
                                trailing: const Icon(CupertinoIcons.chevron_forward),
                                onTap: () {
                                  final rid = (g['rId'] ?? g['_id'] ?? g['id'] ?? g['roomId'])?.toString();
                                  if (rid == null || rid.isEmpty) {
                                    VAppAlert.showErrorSnackBar(
                                      context: context,
                                      message: S.of(context).missingRoomId,
                                    );
                                    return;
                                  }
                                  _openGroupRoom(rid, g['gName']?.toString() ?? '');
                                },
                              ),
                              if (i < _groups.length - 1)
                                const Divider(height: 1),
                            ],
                          );
                        },
                        childCount: _groups.length,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// ===================== Helper UI Widgets =====================

class _HeaderWithContent extends StatelessWidget {
  final Widget header;
  final Widget child;
  const _HeaderWithContent({required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverToBoxAdapter(child: child),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onChanged;
  const _Header({required this.searchCtrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF2E2E2E), Color(0xFF1B1B1B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Find your community',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            CupertinoSearchTextField(
              controller: searchCtrl,
              placeholder: 'Search communities',
              onChanged: onChanged,
              backgroundColor: Colors.white.withOpacity(0.12),
              style: const TextStyle(color: Colors.white),
              placeholderStyle: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final String tag;
  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onTap;
  const _CommunityCard({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            Hero(
              tag: tag,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF202020),
                  image: imageUrl.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black54.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const Icon(CupertinoIcons.person_3_fill, size: 72, color: Colors.grey),
          const SizedBox(height: 8),
          Text(S.of(context).noCommunitiesYet, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          CupertinoButton.filled(onPressed: onCreate, child: Text(S.of(context).createCommunity)),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final VoidCallback onClear;
  const _NoResults({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const Icon(CupertinoIcons.search, size: 60, color: Colors.grey),
          const SizedBox(height: 8),
          Text(S.of(context).noResults, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          CupertinoButton(onPressed: onClear, child: Text(S.of(context).clearSearch)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle, size: 60, color: CupertinoColors.systemRed),
          const SizedBox(height: 8),
          Text(S.of(context).somethingWentWrong),
          const SizedBox(height: 6),
          CupertinoButton.filled(onPressed: onRetry, child: Text(S.of(context).retry)),
        ],
      ),
    );
  }
}
