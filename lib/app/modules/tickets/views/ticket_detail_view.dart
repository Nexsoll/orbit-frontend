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
import '../../../core/services/balance_service.dart';
import '../../../core/api_service/story/story_api_service.dart';
import '../../../core/models/story/create_story_dto.dart';
import '../../../core/services/story_status_service.dart';
import '../../../core/utils/enums.dart';
import '../../home/mobile/story_tab/controllers/story_tab_controller.dart';

class TicketDetailView extends StatefulWidget {
  final String ticketId;
  final Map<String, dynamic>? initialTicket;

  const TicketDetailView({
    super.key,
    required this.ticketId,
    this.initialTicket,
  });

  @override
  State<TicketDetailView> createState() => _TicketDetailViewState();
}

class _TicketDetailViewState extends State<TicketDetailView> {
  static const _brand = Color(0xFFB48648);
  late final TicketsApiService _api;
  Map<String, dynamic>? _ticket;
  bool _loading = false;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _api = GetIt.I.get<TicketsApiService>();
    if (widget.initialTicket != null) {
      _ticket = widget.initialTicket;
    }
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final ticket = await _api.getTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
      });
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isOwner(Map<String, dynamic> t) {
    final id = (t['uploaderId'] ?? '').toString();
    return id == AppAuth.myId;
  }

  bool _isBuyer(Map<String, dynamic> t) {
    return t['isBuyer'] == true;
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

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = date is String ? DateTime.parse(date) : date as DateTime;
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return date.toString();
    }
  }

  Future<void> _buyTicket(Map<String, dynamic> t) async {
    final id = widget.ticketId;
    if (id.isEmpty || _buying) return;

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

    setState(() => _buying = true);
    VAppAlert.showLoading(context: context);
    try {
      await _api.buyTicket(id);
      await BalanceService.instance.init();
      final updated = await _api.getTicket(id);
      if (!mounted) return;
      // dismiss loading
      Navigator.of(context).pop();
      setState(() {
        _ticket = updated;
      });
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
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
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
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _deleteTicket(Map<String, dynamic> t) async {
    final id = widget.ticketId;
    if (id.isEmpty) return;

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
      Navigator.of(context).pop(); // dismiss loading
      Navigator.of(context).pop(true); // Pop with delete success
      VAppAlert.showSuccessSnackBar(context: context, message: 'Ticket deleted');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
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

  Future<void> _shareTicketLink(Map<String, dynamic> t) async {
    try {
      final id = widget.ticketId;
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

  Future<void> _shareTicketToStory(Map<String, dynamic> t) async {
    try {
      final id = widget.ticketId;
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
      Navigator.of(context).pop(); // dismiss loading
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Shared to your story',
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future<void> _shareTicketToChat(Map<String, dynamic> t) async {
    try {
      final roomsIds = await VChatController.I.vNavigator.roomNavigator.toForwardPage(
        context,
        null,
      );
      if (roomsIds == null || roomsIds.isEmpty) return;

      final id = widget.ticketId;
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
        'imageBlurred': true,
        'hasImage': t['hasImage'] ?? (t['imageUrl'] ?? '').toString().isNotEmpty,
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
          await VChatController.I.nativeApi.local.message.insertMessage(message);
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

  void _openFullImage(String imageUrl) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => _TicketImageViewerPage(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(t != null ? (t['name'] ?? 'Ticket Details').toString() : 'Ticket Details'),
      ),
      child: SafeArea(
        child: t == null
            ? const Center(child: CupertinoActivityIndicator())
            : RefreshIndicator(
                onRefresh: _fetch,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    _buildTicketCard(t),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> t) {
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
    // On the single ticket detail screen, show clear image if they bought it or if they are the owner!
    final imageBlurred = t['imageBlurred'] == true;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: CupertinoColors.systemGrey6.resolveFrom(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isSold)
                  _statusBadge('Sold', Colors.grey.shade400)
                else if (isExpired)
                  _statusBadge('Expired', CupertinoColors.destructiveRed)
                else if (!isOwner && !isSold && !isExpired && !isBuyer)
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: _brand,
                    minSize: 30,
                    child: const Text(
                      'Buy',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _buyTicket(t),
                  )
                else if (isBuyer)
                  _statusBadge('Purchased', const Color(0xFF10B981)),
              ],
            ),
            if (hasImage) ...[
              const SizedBox(height: 16),
              _buildTicketImage(imageUrl, imageBlurred, isSold),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
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
                    padding: const EdgeInsets.only(left: 8),
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                      horizontal: 12,
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
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _chip({required String text, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketImage(String imageUrl, bool blurred, bool isSold) {
    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Image.network(
            imageUrl,
            width: double.infinity,
            height: 240,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: double.infinity,
              height: 240,
              color: Colors.grey.shade300,
              child: const Icon(CupertinoIcons.photo, color: Colors.grey),
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
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
                height: 240,
                color: Colors.grey.shade200,
                child: const Center(child: CupertinoActivityIndicator()),
              );
            },
          ),
          if (blurred)
            Container(
              width: double.infinity,
              height: 240,
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Icon(
                  isSold ? CupertinoIcons.lock_fill : CupertinoIcons.lock,
                  color: CupertinoColors.white,
                  size: 44,
                ),
              ),
            ),
        ],
      ),
    );

    if (!blurred) {
      return GestureDetector(
        onTap: () => _openFullImage(imageUrl),
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

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

      await VFileUtils.saveFileToPublicPath(
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
