import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

import '../services/tickets_api_service.dart';
import 'create_ticket_view.dart';
import 'ticket_detail_view.dart';
import '../../../core/services/balance_service.dart';
import '../../../core/api_service/story/story_api_service.dart';
import '../../../core/models/story/create_story_dto.dart';
import '../../../core/services/story_status_service.dart';
import '../../../core/utils/enums.dart';
import '../../home/mobile/story_tab/controllers/story_tab_controller.dart';

class TicketsHomeView extends StatefulWidget {
  const TicketsHomeView({super.key});

  @override
  State<TicketsHomeView> createState() => _TicketsHomeViewState();
}

class _TicketsHomeViewState extends State<TicketsHomeView> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _items = <Map<String, dynamic>>[];
  bool _loading = false;
  Timer? _debounce;
  String? _selectedCategory;

  static const _brand = Color(0xFFB48648);

  final List<String> _categories = const [
    'All',
    'Movie',
    'Sports',
    'Transport',
    'Music',
    'Conference',
    'Food & Dining',
    'Tech',
    'Travel',
    'Education',
    'Entertainment',
    'Other',
  ];

  late final TicketsApiService _api;

  @override
  void initState() {
    super.initState();
    _api = GetIt.I.get<TicketsApiService>();
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetch({required bool reset}) async {
    setState(() => _loading = true);
    try {
      final list = await _api.listTickets(
        q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        category: _selectedCategory,
        showAll: true,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(list);
      });
    } catch (e) {
      if (mounted) VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetch(reset: true));
  }

  void _onCategoryChanged(String? category) {
    setState(() => _selectedCategory = category == 'All' ? null : category);
    _fetch(reset: true);
  }

  bool _isOwner(Map<String, dynamic> t) {
    final id = (t['uploaderId'] ?? '').toString();
    return id == AppAuth.myId;
  }

  bool _isBuyer(Map<String, dynamic> t) {
    return t['isBuyer'] == true;
  }

  Future<void> _buyTicket(Map<String, dynamic> t) async {
    final id = (t['_id'] ?? t['id'])?.toString();
    if (id == null || id.isEmpty) return;

    final price = t['priceKes'] ?? 0;
    final balance = BalanceService.instance.balance;

    if (balance < (price is num ? price.toDouble() : double.tryParse(price.toString()) ?? 0)) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Insufficient balance. Please top up your wallet.',
      );
      return;
    }

    final confirm = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: 'Buy Ticket',
      content: 'Buy "${t['name']}" for KES $price from your wallet balance?',
    );
    if (confirm != 1) return;

    VAppAlert.showLoading(context: context);
    try {
      await _api.buyTicket(id);
      await BalanceService.instance.init();
      if (!mounted) return;
      if (Navigator.of(context).canPop()) context.pop();
      await showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Success'),
          content: Text('You have successfully purchased "${t['name']}".'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _fetch(reset: true);
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) context.pop();
      await showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Purchase Failed'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _deleteTicket(Map<String, dynamic> t) async {
    final id = (t['_id'] ?? t['id'])?.toString();
    if (id == null || id.isEmpty) return;

    final confirm = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: 'Delete ticket',
      content: 'Are you sure you want to delete this ticket?',
    );
    if (confirm != 1) return;

    VAppAlert.showLoading(context: context);
    try {
      await _api.deleteTicket(id);
      if (!mounted) return;
      context.pop();
      setState(() {
        _items.removeWhere((e) => (e['_id'] ?? e['id'])?.toString() == id);
      });
      VAppAlert.showSuccessSnackBar(context: context, message: 'Ticket deleted');
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) context.pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  Future<void> _openShareOptions(Map<String, dynamic> t) async {
    String? action;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text((t['name'] ?? 'Ticket').toString()),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'story';
              Navigator.pop(context);
            },
            child: const Text('Share to Story'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'chat';
              Navigator.pop(context);
            },
            child: const Text('Share to Chat'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              action = 'link';
              Navigator.pop(context);
            },
            child: const Text('Share Link'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (action == 'story') return _shareTicketToStory(t);
    if (action == 'chat') return _shareTicketToChat(t);
    if (action == 'link') return _shareTicketLink(t);
  }

  Future<void> _shareTicketToStory(Map<String, dynamic> t) async {
    try {
      final id = (t['_id'] ?? t['id'])?.toString() ?? '';
      final name = (t['name'] ?? 'Ticket').toString();
      if (id.isEmpty) return;

      VAppAlert.showLoading(context: context);

      final dto = CreateStoryDto(
        image: null,
        storyType: StoryType.text,
        content: name,
        caption: name,
        backgroundColor: 'FF000000',
        attachment: {
          'ticketId': id,
          '_id': id,
          'name': name,
          'priceKes': t['priceKes'],
          'category': t['category'],
          'expiryDate': t['expiryDate']?.toString(),
          'imageUrl': t['imageUrl'],
          'imageBlurred': true,
          'hasImage': t['hasImage'] ?? (t['imageUrl'] ?? '').toString().isNotEmpty,
          'isSold': t['isSold'],
          'remaining': t['remaining'],
          'uploaderId': t['uploaderId']?.toString(),
          'uploaderName': t['uploaderName'],
          'uploaderImage': t['uploaderImage'],
        },
        storyPrivacy: StoryPrivacy.public,
        storySource: 'main',
      );

      if (!GetIt.I.isRegistered<StoryApiService>()) {
        GetIt.I.registerSingleton<StoryApiService>(StoryApiService.init());
      }
      await GetIt.I.get<StoryApiService>().createStory(dto);

      try {
        final svc = GetIt.I.get<StoryStatusService>();
        if (GetIt.I.isRegistered<StoryTabController>()) {
          final tab = GetIt.I.get<StoryTabController>();
          await svc.refreshMyStories();
          await tab.getMyStoryFromApi();
          await tab.getStoriesFromApi();
          tab.update();
        }
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop();
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Shared to your story',
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future<void> _shareTicketLink(Map<String, dynamic> t) async {
    try {
      final id = (t['_id'] ?? t['id'])?.toString() ?? '';
      if (id.isEmpty) return;

      final name = (t['name'] ?? 'Ticket').toString();
      final uploaderName = (t['uploaderName'] ?? '').toString();
      final link = 'https://api.orbit.ke/api/v1/public/tickets/share/$id';
      final text = [
        name,
        if (uploaderName.isNotEmpty) 'by $uploaderName',
        'Use the Orbit app or web to buy this ticket.',
        link,
      ].join('\n');

      await Share.share(text, subject: name);
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future<void> _shareTicketToChat(Map<String, dynamic> t) async {
    try {
      final roomsIds =
          await VChatController.I.vNavigator.roomNavigator.toForwardPage(
        context,
        null,
      );
      if (roomsIds == null || roomsIds.isEmpty) return;

      final id = (t['_id'] ?? t['id'])?.toString() ?? '';
      final name = (t['name'] ?? 'Ticket').toString();
      if (id.isEmpty) return;

      final payload = <String, dynamic>{
        'type': 'ticket_share',
        'ticketId': id,
        '_id': id,
        'name': name,
        'priceKes': t['priceKes'],
        'category': t['category'],
        'expiryDate': t['expiryDate']?.toString(),
        'imageUrl': t['imageUrl'],
        'imageBlurred':
            t['hasImage'] == true || (t['imageUrl'] ?? '').toString().isNotEmpty,
        'hasImage': t['hasImage'],
        'isSold': t['isSold'],
        'remaining': t['remaining'],
        'uploaderId': t['uploaderId']?.toString(),
        'uploaderName': t['uploaderName'],
        'uploaderImage': t['uploaderImage'],
      };

      VAppAlert.showLoading(context: context);
      try {
        for (final roomId in roomsIds) {
          final message = VCustomMessage.buildMessage(
            roomId: roomId,
            content: 'Shared ticket: $name',
            data: VCustomMsgData(data: payload),
          );
          await VChatController.I.nativeApi.local.message
              .insertMessage(message);
          try {
            VMessageUploaderQueue.instance.addToQueue(
              await MessageFactory.createUploadMessage(message),
            );
          } catch (_) {}
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Shared to chat',
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future<void> _openChat(Map<String, dynamic> t) async {
    final uploaderId = (t['uploaderId'] ?? '').toString();
    if (uploaderId.isEmpty) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Uploader not found');
      return;
    }
    try {
      await VChatController.I.roomApi.openChatWith(peerId: uploaderId);
    } catch (e) {
      if (mounted) VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = date is String ? DateTime.parse(date) : date as DateTime;
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return date.toString();
    }
  }

  bool _isExpired(Map<String, dynamic> t) {
    try {
      final raw = t['expiryDate'];
      if (raw == null) return false;
      final d = raw is String ? DateTime.parse(raw) : raw as DateTime;
      return d.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: const Text('Tickets'),
        trailing: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          onPressed: () async {
            final res = await context.toPage(const CreateTicketView());
            if (res == true) _fetch(reset: true);
          },
          child: const Text(
            'Create',
            style: TextStyle(
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          color: _brand,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: CupertinoSearchTextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                placeholder: 'Search tickets...',
                onChanged: _onSearchChanged,
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final selected = (cat == 'All' && _selectedCategory == null) ||
                      cat == _selectedCategory;
                  return CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minSize: 0,
                    color: selected
                        ? _brand
                        : CupertinoColors.systemGrey5.resolveFrom(context),
                    borderRadius: BorderRadius.circular(20),
                    onPressed: () => _onCategoryChanged(cat),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? CupertinoColors.white
                            : CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _loading && _items.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _fetch(reset: true),
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.grey.withOpacity(.2),
                        ),
                        itemBuilder: (context, index) {
                          final t = _items[index];
                          final name = (t['name'] ?? 'Untitled').toString();
                          final price = t['priceKes'] ?? 0;
                          final expiry = _formatDate(t['expiryDate']);
                          final isSold = t['isSold'] == true;
                          final isOwner = _isOwner(t);
                          final isBuyer = _isBuyer(t);
                          final isExpired = _isExpired(t);
                          final remaining = (t['remaining'] ?? 0) as int;
                          final category = (t['category'] ?? '').toString();
                          final uploaderName = (t['uploaderName'] ?? '').toString();
                          final imageUrl = (t['imageUrl'] ?? '').toString();
                          final hasImage = t['hasImage'] == true || imageUrl.isNotEmpty;
                          final imageBlurred = t['imageBlurred'] == true || !isOwner;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            elevation: 0,
                            color: CupertinoColors.systemGrey6.resolveFrom(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isSold)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade400,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Sold',
                                            style: TextStyle(
                                              color: CupertinoColors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      else if (isExpired)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.destructiveRed,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Expired',
                                            style: TextStyle(
                                              color: CupertinoColors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      else if (!isOwner && !isSold && !isExpired)
                                        CupertinoButton(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          color: _brand,
                                          minSize: 30,
                                          child: const Text(
                                            'Buy',
                                            style: TextStyle(
                                              color: CupertinoColors.white,
                                            ),
                                          ),
                                          onPressed: () => _buyTicket(t),
                                        )
                                      else if (isBuyer)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Purchased',
                                            style: TextStyle(
                                              color: CupertinoColors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (hasImage) ...[
                                    const SizedBox(height: 12),
                                    _buildTicketImage(imageUrl, imageBlurred, isSold, t),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _chip(
                                        text: 'KES $price',
                                        icon: CupertinoIcons.money_dollar,
                                      ),
                                      if (category.isNotEmpty)
                                        _chip(
                                          text: category,
                                          icon: CupertinoIcons.tag,
                                        ),
                                      if (!isSold && remaining > 0)
                                        _chip(
                                          text: '$remaining left',
                                          icon: CupertinoIcons.number,
                                        )
                                      else if (isSold && remaining <= 0)
                                        _chip(
                                          text: 'Sold out',
                                          icon: CupertinoIcons.xmark_circle,
                                        ),
                                      if (expiry.isNotEmpty)
                                        _chip(
                                          text: 'Exp: $expiry',
                                          icon: CupertinoIcons.calendar,
                                        ),
                                      if (uploaderName.isNotEmpty && !isOwner)
                                        _chip(
                                          text: uploaderName,
                                          icon: CupertinoIcons.person,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      CupertinoButton(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        color: Colors.black.withOpacity(0.05),
                                        minSize: 30,
                                        onPressed: () => _openShareOptions(t),
                                        child: const Icon(
                                          CupertinoIcons.share,
                                          size: 18,
                                          color: _brand,
                                        ),
                                      ),
                                      if (!isOwner || isBuyer)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8),
                                          child: CupertinoButton(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            color: Colors.black.withOpacity(0.05),
                                            minSize: 30,
                                            onPressed: () => _openChat(t),
                                            child: const Icon(
                                              CupertinoIcons.chat_bubble_2,
                                              size: 18,
                                              color: _brand,
                                            ),
                                          ),
                                        ),
                                      if (isOwner) ...[
                                        const SizedBox(width: 8),
                                        CupertinoButton(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          color: Colors.black.withOpacity(0.05),
                                          minSize: 30,
                                          onPressed: () => _deleteTicket(t),
                                          child: const Icon(
                                            CupertinoIcons.delete,
                                            size: 18,
                                            color: CupertinoColors.destructiveRed,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({required String text, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _brand),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketImage(String imageUrl, bool blurred, bool isSold, Map<String, dynamic> ticket) {
    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Image with blur filter if needed
          Image.network(
            imageUrl,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: double.infinity,
              height: 180,
              color: Colors.grey.shade300,
              child: const Icon(CupertinoIcons.photo, color: Colors.grey),
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                // Apply blur overlay if image is blurred
                if (blurred) {
                  return ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: child,
                  );
                }
                return child;
              }
              return Container(
                width: double.infinity,
                height: 180,
                color: Colors.grey.shade200,
                child: const Center(child: CupertinoActivityIndicator()),
              );
            },
          ),
          // Lock icon for blurred images (no text)
          if (blurred)
            Container(
              width: double.infinity,
              height: 180,
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Icon(
                  isSold ? CupertinoIcons.lock_fill : CupertinoIcons.lock,
                  color: CupertinoColors.white,
                  size: 40,
                ),
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () async {
        final res = await Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => TicketDetailView(
              ticketId: (ticket['_id'] ?? ticket['id'])?.toString() ?? '',
              initialTicket: ticket,
            ),
          ),
        );
        if (res == true) {
          _fetch(reset: true);
        }
      },
      child: imageWidget,
    );
  }

  void _openFullImage(String imageUrl) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => _TicketImageViewerPage(imageUrl: imageUrl),
      ),
    );
  }
}

// Simple full-screen image viewer with download
class _TicketImageViewerPage extends StatefulWidget {
  final String imageUrl;

  const _TicketImageViewerPage({required this.imageUrl});

  @override
  State<_TicketImageViewerPage> createState() => _TicketImageViewerPageState();
}

class _TicketImageViewerPageState extends State<_TicketImageViewerPage> {
  bool _downloading = false;

  Future<void> _downloadImage() async {
    setState(() => _downloading = true);
    try {
      final platformFile = VPlatformFile.fromMap({
        'name': 'ticket_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        'networkUrl': widget.imageUrl,
        'size': 0,
        'mimeType': 'image/jpeg',
      });

      final result = await VFileUtils.saveFileToPublicPath(
        fileAttachment: platformFile,
      );

      if (mounted) {
        VAppAlert.showSuccessSnackBar(context: context, message: 'Image saved to gallery');
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Failed to save image');
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withOpacity(0.5),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.white),
        ),
        trailing: _downloading
            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _downloadImage,
                child: const Icon(CupertinoIcons.arrow_down_to_line, color: CupertinoColors.white),
              ),
      ),
      child: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(
              widget.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                CupertinoIcons.photo,
                color: CupertinoColors.white,
                size: 60,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
