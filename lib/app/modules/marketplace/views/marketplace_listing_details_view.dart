import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';
import 'package:super_up/app/core/services/user_verification_service.dart';
import 'package:super_up/app/modules/marketplace/services/marketplace_bookmarks_service.dart';
import 'package:super_up/app/modules/marketplace/services/marketplace_api_service.dart';
import 'package:super_up/v_chat_v2/translations.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

class MarketplaceListingDetailsView extends StatefulWidget {
  final Map<String, dynamic> listing;

  const MarketplaceListingDetailsView({
    super.key,
    required this.listing,
  });

  @override
  State<MarketplaceListingDetailsView> createState() =>
      _MarketplaceListingDetailsViewState();
}

class _MarketplaceListingDetailsViewState
    extends State<MarketplaceListingDetailsView> {
  late final MarketplaceApiService _api;
  late final ProfileApiService _profileApi;
  bool _loading = false;
  Map<String, dynamic>? _listing;
  bool _bookmarking = false;
  bool _bookmarked = false;
  bool _liking = false;
  bool _liked = false;
  num _likesCount = 0;
  num _viewsCount = 0;
  bool _viewCounted = false;
  bool _openingChat = false;
  bool _reporting = false;
  bool _listingUnavailable = false;

  bool _loadingSimilar = false;
  List<Map<String, dynamic>> _similar = const [];

  // Reviews
  bool _loadingReviews = false;
  bool _submittingReview = false;
  bool _deletingReview = false;
  List<Map<String, dynamic>> _reviews = const [];
  num _ratingAvg = 0;
  num _ratingCount = 0;
  int _myRating = 0;
  final _reviewTextCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _api = GetIt.I.get<MarketplaceApiService>();
    _profileApi = GetIt.I.get<ProfileApiService>();
    _listing = widget.listing;
    _initCountsFromListing();
    unawaited(_incrementViewOnce());
    _refresh();
    _loadBookmarkState();
    _loadLikeState();
    _loadSimilar();
    _loadReviews();
  }

  @override
  void dispose() {
    _reviewTextCtrl.dispose();
    super.dispose();
  }

  void _initCountsFromListing() {
    final l = _listing ?? widget.listing;
    final likes = l['likesCount'];
    final views = l['viewsCount'];
    _likesCount = likes is num ? likes : (num.tryParse('${likes ?? 0}') ?? 0);
    _viewsCount = views is num ? views : (num.tryParse('${views ?? 0}') ?? 0);
  }

  String? _myId() {
    try {
      return AppAuth.myProfile.baseUser.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _incrementViewOnce() async {
    if (_viewCounted) return;
    final id = (_listing?['_id'] ?? _listing?['id'] ?? widget.listing['_id'] ?? widget.listing['id'])
        ?.toString();
    if (id == null || id.isEmpty) return;

    final l = _listing ?? widget.listing;
    final ownerId = (l['userId'] ?? '').toString();
    final myId = _myId();
    final isMine = myId != null && myId.isNotEmpty && ownerId.isNotEmpty && ownerId == myId;
    if (isMine) return;

    _viewCounted = true;
    try {
      final res = await _api.incrementListingViewPublic(id);
      final vc = res['viewsCount'];
      final next = vc is num ? vc : (num.tryParse('${vc ?? 0}') ?? _viewsCount);
      if (!mounted) return;
      setState(() => _viewsCount = next);
    } catch (_) {
      // ignore
    }
  }

  Future<String?> _askReportReason() async {
    final c = TextEditingController();
    final res = await showCupertinoDialog<String?>(
      context: context,
      builder: (_) {
        return CupertinoAlertDialog(
          title: const Text('Report listing'),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: CupertinoTextField(
              controller: c,
              placeholder: 'Reason',
              maxLines: 4,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              isDestructiveAction: true,
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
    return res;
  }

  Future<void> _reportListing(String listingId) async {
    if (_reporting) return;
    final reason = await _askReportReason();
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _reporting = true);
    try {
      await _api.reportListing(id: listingId, content: reason.trim());
      if (!mounted) return;
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Report submitted successfully',
      );
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  Future<void> _ensureOrderRoomShowsSellerInfo({
    required VRoom room,
    required String sellerId,
  }) async {
    try {
      final peer = await _profileApi.peerProfile(sellerId);
      final name = peer.searchUser.baseUser.fullName.toString().trim();
      final image = peer.searchUser.baseUser.userImage.toString().trim();
      if (name.isNotEmpty && room.title != name) {
        room.title = name;
        room.enTitle = name;
        await VChatController.I.nativeApi.local.room.updateRoomName(
          VUpdateRoomNameEvent(roomId: room.id, name: name),
        );
      }
      if (image.isNotEmpty && room.thumbImage != image) {
        room.thumbImage = image;
        await VChatController.I.nativeApi.local.room.updateRoomImage(
          VUpdateRoomImageEvent(roomId: room.id, image: image),
        );
      }
    } catch (_) {}
  }

  String _mpOrderId({
    required String listingId,
    required String buyerId,
  }) {
    return 'mp_${listingId}_$buyerId';
  }

  Future<VRoom?> _resolveMarketplaceOrderRoom({
    required String sellerId,
  }) async {
    final listing = _listing ?? widget.listing;
    final listingId = (_idOf(listing)).trim();
    if (listingId.isEmpty) return null;

    final myId = VAppConstants.myId;
    final orderId = _mpOrderId(listingId: listingId, buyerId: myId);

    final title = (listing['title'] ?? '').toString().trim();
    final img = _firstImageUrl(listing);
    final price = listing['price'];

    final room = await VChatController.I.nativeApi.remote.room.createOrderRoom(
      CreateOrderRoomDto(
        peerId: sellerId,
        orderId: orderId,
        orderTitle: null,
        orderImage: null,
        orderData: {
          'type': 'marketplace_listing',
          'listingId': listingId,
          'title': title,
          'image': img,
          'price': price,
        },
      ),
    );

    await VChatController.I.nativeApi.local.room.safeInsertRoom(room);
    return room;
  }

  Future<void> _openChatWithSeller(String sellerId) async {
    if (_openingChat) return;
    if (sellerId.trim().isEmpty) return;

    if (_listingUnavailable) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Listing is no longer available',
      );
      return;
    }

    // Require auth (chat SDK reads AppAuth internally)
    try {
      AppAuth.myProfile;
    } catch (_) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Please login to chat');
      return;
    }

    setState(() => _openingChat = true);
    try {
      final room = await _resolveMarketplaceOrderRoom(sellerId: sellerId);
      if (room == null || !mounted) return;

      await _ensureOrderRoomShowsSellerInfo(room: room, sellerId: sellerId);

      final config = VAppConfigController.appConfig;
      final messageConfig = VMessageConfig(
        googleMapsApiKey: SConstants.googleMapsApiKey,
        isCallsAllowed: false,
        isSendMediaAllowed: true,
        onOrderCardPress: (ctx, r, pin) async {
          final listingId = (pin['listingId'] ?? '').toString().trim();
          if (listingId.isEmpty) return;
          try {
            final listing = await _api.getListing(listingId);
            if (!ctx.mounted) return;
            Navigator.of(ctx, rootNavigator: true).push(
              CupertinoPageRoute(
                builder: (_) => MarketplaceListingDetailsView(
                  listing: listing,
                ),
              ),
            );
          } catch (_) {
            if (!ctx.mounted) return;
            try {
              final listing = await _api.getListingPublic(listingId);
              if (!ctx.mounted) return;
              Navigator.of(ctx, rootNavigator: true).push(
                CupertinoPageRoute(
                  builder: (_) => MarketplaceListingDetailsView(
                    listing: listing,
                  ),
                ),
              );
              return;
            } catch (_) {}
            final img = (pin['image'] ?? '').toString().trim();
            final title = (pin['title'] ?? '').toString().trim();
            final price = pin['price'];
            final peerId = r.peerId?.toString().trim() ?? '';
            final fallback = <String, dynamic>{
              '_id': listingId,
              'id': listingId,
              if (peerId.isNotEmpty) 'userId': peerId,
              if (title.isNotEmpty) 'title': title,
              if (price != null) 'price': price,
              if (img.isNotEmpty)
                'media': [
                  {
                    'type': 'image',
                    'url': img,
                  }
                ],
            };
            Navigator.of(ctx, rootNavigator: true).push(
              CupertinoPageRoute(
                builder: (_) => MarketplaceListingDetailsView(
                  listing: fallback,
                ),
              ),
            );
          }
        },
        onMessageAttachmentIconPress: () async {
          final content = <ModelSheetItem>[];
          content.add(
            ModelSheetItem(
              id: VAttachEnumRes.media,
              title: S.of(context).media,
              iconData: const Icon(CupertinoIcons.photo_on_rectangle),
            ),
          );
          content.add(
            ModelSheetItem(
              id: VAttachEnumRes.files,
              title: S.of(context).files,
              iconData: const Icon(CupertinoIcons.doc),
            ),
          );
          if (SConstants.googleMapsApiKey.isNotEmpty) {
            content.add(
              ModelSheetItem(
                id: VAttachEnumRes.location,
                title: S.of(context).location,
                iconData: const Icon(CupertinoIcons.map_pin),
              ),
            );
          }
          final res = await VAppAlert.showModalSheetWithActions(
            context: context,
            cancelLabel: S.of(context).cancel,
            content: content,
          );
          if (res == null) return null;
          return res.id as VAttachEnumRes?;
        },
        isEnableAds: config.enableAds,
        showDisconnectedWidget: true,
        maxMediaSize: 1024 * 1024 * config.maxChatMediaSize,
        compressImageQuality: 55,
        maxRecordTime: const Duration(minutes: 30),
      );

      await showCupertinoModalPopup(
        context: context,
        builder: (ctx) {
          final h = MediaQuery.of(ctx).size.height;
          return CupertinoPopupSurface(
            child: SizedBox(
              height: h * 0.92,
              child: VMessagePage(
                vRoom: room,
                localization: vMessageLocalizationPageModel(ctx),
                vMessageConfig: messageConfig,
                isUserVerifiedCallback: (userId) {
                  final service = GetIt.instance<UserVerificationService>();
                  return service.getCachedVerificationStatus(userId) ?? false;
                },
              ),
            ),
          );
        },
      );
    } catch (e) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Failed to open chat');
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Future<void> _loadBookmarkState() async {
    final id = (_listing?['_id'] ?? _listing?['id'])?.toString();
    if (id == null || id.isEmpty) return;
    try {
      final saved = await MarketplaceBookmarksService.instance.isBookmarked(id);
      if (!mounted) return;
      setState(() => _bookmarked = saved);
    } catch (_) {}
  }

  Future<void> _toggleBookmark() async {
    if (_bookmarking) return;
    final l = _listing ?? widget.listing;
    setState(() => _bookmarking = true);
    try {
      final saved = await MarketplaceBookmarksService.instance.toggle(l);
      if (!mounted) return;
      setState(() => _bookmarked = saved);
    } finally {
      if (mounted) setState(() => _bookmarking = false);
    }
  }

  Future<void> _loadLikeState() async {
    final myId = _myId();
    if (myId == null || myId.isEmpty) return;

    final l = _listing ?? widget.listing;
    final ownerId = (l['userId'] ?? '').toString();
    final isMine = ownerId.isNotEmpty && ownerId == myId;
    if (isMine) return;

    final id = (_listing?['_id'] ?? _listing?['id'] ?? widget.listing['_id'] ?? widget.listing['id'])
        ?.toString();
    if (id == null || id.isEmpty) return;

    try {
      final res = await _api.getListingLikeState(id);
      final liked = res['liked'] == true ||
          (res['liked']?.toString().trim().toLowerCase() == 'true');
      final lc = res['likesCount'];
      final count = lc is num ? lc : (num.tryParse('${lc ?? 0}') ?? _likesCount);
      if (!mounted) return;
      setState(() {
        _liked = liked;
        _likesCount = count;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    final myId = _myId();
    if (myId == null || myId.isEmpty) return;

    final l = _listing ?? widget.listing;
    final ownerId = (l['userId'] ?? '').toString();
    final isMine = ownerId.isNotEmpty && ownerId == myId;
    if (isMine) return;

    final id = (_listing?['_id'] ?? _listing?['id'] ?? widget.listing['_id'] ?? widget.listing['id'])
        ?.toString();
    if (id == null || id.isEmpty) return;

    setState(() => _liking = true);
    try {
      final res = await _api.toggleListingLike(id);
      final liked = res['liked'] == true ||
          (res['liked']?.toString().trim().toLowerCase() == 'true');
      final lc = res['likesCount'];
      final count = lc is num ? lc : (num.tryParse('${lc ?? 0}') ?? _likesCount);
      if (!mounted) return;
      setState(() {
        _liked = liked;
        _likesCount = count;
      });
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  String _formatKes(num? value) {
    if (value == null) return '';
    final f = NumberFormat('#,##0', 'en_KE');
    return 'KES ${f.format(value)}';
  }

  Future<num?> _askOfferAmount({required num? initial}) async {
    final c = TextEditingController(text: initial == null ? '' : initial.toString());
    final res = await showCupertinoDialog<String?>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Make an offer'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: c,
            placeholder: 'Offer amount (KES)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (res == null) return null;
    final raw = res.trim();
    if (raw.isEmpty) return null;
    final parsed = num.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Enter a valid offer amount');
      }
      return null;
    }
    return parsed;
  }

  Future<void> _sendMarketplaceOfferToSeller({
    required String sellerId,
    required num amount,
  }) async {
    if (_listingUnavailable) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Listing is no longer available',
      );
      return;
    }

    // Require auth (chat SDK reads AppAuth internally)
    try {
      AppAuth.myProfile;
    } catch (_) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Please login to chat');
      return;
    }

    final l = _listing ?? widget.listing;
    final ownerId = (l['userId'] ?? '').toString();
    final myId = _myId();
    final isMine = myId != null && myId.isNotEmpty && ownerId.isNotEmpty && ownerId == myId;
    if (isMine) return;

    setState(() => _openingChat = true);
    try {
      final room = await _resolveMarketplaceOrderRoom(sellerId: sellerId);
      if (room == null) return;

      final payload = <String, dynamic>{
        'type': 'marketplace_offer',
        'amount': amount,
        'currency': 'KES',
        'status': 'pending',
      };

      final msg = VCustomMessage.buildMessage(
        roomId: room.id,
        data: VCustomMsgData(data: payload),
        content: 'Offer: ${_formatKes(amount)}',
      );

      await VChatController.I.nativeApi.local.message.insertMessage(msg);
      try {
        VMessageUploaderQueue.instance.addToQueue(
          await MessageFactory.createUploadMessage(msg),
        );
      } catch (_) {}

      if (!mounted) return;
      VAppAlert.showSuccessSnackBar(context: context, message: 'Offer sent');
      unawaited(_openChatWithSeller(sellerId));
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Future<num?> _askSoldPrice(num? initial) async {
    final c = TextEditingController(text: initial == null ? '' : initial.toString());
    final res = await showCupertinoDialog<String?>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Mark as sold'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: c,
            placeholder: 'Sold price (KES)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Sold'),
          ),
        ],
      ),
    );

    if (res == null) return null;
    final raw = res.trim();
    if (raw.isEmpty) {
      if (initial != null && initial > 0) return initial;
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Enter a valid sold price');
      }
      return null;
    }
    final parsed = num.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Enter a valid sold price');
      }
      return null;
    }
    return parsed;
  }

  Future<void> _markSold(String listingId, {required num? initialPrice}) async {
    final l = _listing ?? widget.listing;
    final isSold = (l['isSold'] == true) ||
        (l['isSold']?.toString().trim().toLowerCase() == 'true');
    if (isSold) return;

    final soldPrice = await _askSoldPrice(initialPrice);
    if (soldPrice == null) return;

    VAppAlert.showLoading(context: context);
    try {
      await _api.markListingSold(listingId, soldPrice: soldPrice);
      if (!mounted) return;
      context.pop();
      await _refresh();
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Marked as sold. Payment will be released by admin.',
      );
    } catch (e) {
      if (!mounted) return;
      context.pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  List<Map<String, dynamic>> _media(Map<String, dynamic> l) {
    final m = l['media'];
    if (m is List) {
      return List<Map<String, dynamic>>.from(
        m.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      );
    }
    return const [];
  }

  Future<void> _refresh() async {
    final id = (_listing?['_id'] ?? _listing?['id'])?.toString();
    if (id == null || id.isEmpty) return;

    setState(() => _loading = true);
    try {
      final latest = await _api.getListing(id);
      if (!mounted) return;
      setState(() {
        _listing = latest;
        _listingUnavailable = false;
        final v = latest['viewsCount'];
        final l = latest['likesCount'];
        _viewsCount = v is num ? v : (num.tryParse('${v ?? _viewsCount}') ?? _viewsCount);
        _likesCount = l is num ? l : (num.tryParse('${l ?? _likesCount}') ?? _likesCount);
      });
      _loadSimilar(base: latest);
    } catch (_) {
      // ignore (feed is public, getListing is seller-only)
      try {
        final latest = await _api.getListingPublic(id);
        if (!mounted) return;
        setState(() {
          _listing = latest;
          _listingUnavailable = false;
          final v = latest['viewsCount'];
          final l = latest['likesCount'];
          _viewsCount = v is num ? v : (num.tryParse('${v ?? _viewsCount}') ?? _viewsCount);
          _likesCount = l is num ? l : (num.tryParse('${l ?? _likesCount}') ?? _likesCount);
        });
        _loadSimilar(base: latest);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _listingUnavailable = true;
        });

        try {
          await MarketplaceBookmarksService.instance.remove(id);
          if (mounted) setState(() => _bookmarked = false);
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    unawaited(_loadLikeState());
  }

  String _idOf(Map<String, dynamic> l) => (l['_id'] ?? l['id'] ?? '').toString();

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double toRad(double d) => d * pi / 180.0;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(toRad(lat1)) * cos(toRad(lat2)) * (sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  List<Map<String, dynamic>> _applyLocalDistanceFilter(
    List<Map<String, dynamic>> items, {
    required double? lat,
    required double? lng,
    required double radiusKm,
  }) {
    if (lat == null || lng == null || radiusKm <= 0) return items;
    return items.where((it) {
      final dLat = (it['locationLat'] as num?)?.toDouble();
      final dLng = (it['locationLng'] as num?)?.toDouble();
      if (dLat == null || dLng == null) return false;
      return _haversineKm(lat, lng, dLat, dLng) <= radiusKm;
    }).toList();
  }

  bool _isStopWord(String w) {
    switch (w) {
      case 'the':
      case 'and':
      case 'or':
      case 'for':
      case 'with':
      case 'a':
      case 'an':
      case 'to':
      case 'in':
      case 'of':
      case 'on':
      case 'at':
      case 'by':
      case 'from':
      case 'new':
        return true;
      default:
        return false;
    }
  }

  Set<String> _keywords(String input) {
    final re = RegExp(r'[A-Za-z0-9]+');
    final out = <String>{};
    for (final m in re.allMatches(input)) {
      final w = (m.group(0) ?? '').trim().toLowerCase();
      if (w.length < 3) continue;
      if (_isStopWord(w)) continue;
      out.add(w);
      if (out.length >= 20) break;
    }
    return out;
  }

  int _similarityScore(Map<String, dynamic> base, Map<String, dynamic> it) {
    var score = 0;
    final baseBrand = (base['brand'] ?? '').toString().trim().toLowerCase();
    final itBrand = (it['brand'] ?? '').toString().trim().toLowerCase();
    if (baseBrand.isNotEmpty && baseBrand == itBrand) score += 3;

    final baseCond = (base['condition'] ?? '').toString().trim().toLowerCase();
    final itCond = (it['condition'] ?? '').toString().trim().toLowerCase();
    if (baseCond.isNotEmpty && baseCond == itCond) score += 1;

    final basePrice = (base['price'] as num?)?.toDouble();
    final itPrice = (it['price'] as num?)?.toDouble();
    if (basePrice != null && itPrice != null && basePrice > 0) {
      final diff = (basePrice - itPrice).abs() / basePrice;
      if (diff <= 0.2) score += 1;
    }

    final baseKw = _keywords((base['title'] ?? '').toString());
    final itKw = _keywords((it['title'] ?? '').toString());
    score += baseKw.intersection(itKw).length;
    return score;
  }

  // =================== Reviews ===================

  Future<void> _loadReviews() async {
    final id = _idOf(_listing ?? widget.listing);
    if (id.isEmpty) return;

    setState(() => _loadingReviews = true);
    try {
      final res = await _api.getListingReviews(id);
      if (!mounted) return;
      final reviewsList = res['reviews'];
      final myId = _myId();
      setState(() {
        _reviews = reviewsList is List
            ? List<Map<String, dynamic>>.from(
                reviewsList.map((e) => Map<String, dynamic>.from(e as Map)),
              )
            : const [];
        _ratingAvg = (res['ratingAvg'] as num?) ?? 0;
        _ratingCount = (res['ratingCount'] as num?) ?? 0;
        _loadingReviews = false;

        // Find user's existing review to pre-fill rating
        if (myId != null && myId.isNotEmpty) {
          final myReview = _reviews.firstWhere(
            (r) => (r['userId'] ?? '').toString() == myId,
            orElse: () => <String, dynamic>{},
          );
          if (myReview.isNotEmpty) {
            _myRating = (myReview['rating'] as num?)?.toInt() ?? 0;
            _reviewTextCtrl.text = (myReview['text'] ?? '').toString();
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReviews = false);
    }
  }

  Future<void> _submitReview() async {
    if (_myRating < 1 || _myRating > 5) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Please select a rating (1-5 stars)');
      return;
    }
    final id = _idOf(_listing ?? widget.listing);
    if (id.isEmpty) return;

    setState(() => _submittingReview = true);
    try {
      await _api.submitReview(
        listingId: id,
        rating: _myRating,
        text: _reviewTextCtrl.text.trim(),
      );
      if (!mounted) return;
      VAppAlert.showSuccessSnackBar(context: context, message: 'Review submitted');
      await _loadReviews();
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  Future<void> _deleteReview() async {
    final id = _idOf(_listing ?? widget.listing);
    if (id.isEmpty) return;

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete review'),
        content: const Text('Are you sure you want to delete your review?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deletingReview = true);
    try {
      await _api.deleteReview(id);
      if (!mounted) return;
      VAppAlert.showSuccessSnackBar(context: context, message: 'Review deleted');
      _myRating = 0;
      _reviewTextCtrl.clear();
      await _loadReviews();
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _deletingReview = false);
    }
  }

  bool _hasMyReview() {
    final myId = _myId();
    if (myId == null || myId.isEmpty) return false;
    return _reviews.any((r) => (r['userId'] ?? '').toString() == myId);
  }

  Widget _buildStarRating({
    required int rating,
    required ValueChanged<int> onChanged,
    double size = 28,
    bool interactive = true,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starNum = i + 1;
        final filled = starNum <= rating;
        return GestureDetector(
          onTap: interactive ? () => onChanged(starNum) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? CupertinoIcons.star_fill : CupertinoIcons.star,
              color: filled ? const Color(0xFFFFB800) : CupertinoColors.systemGrey3,
              size: size,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final user = review['user'] as Map<String, dynamic>? ?? {};
    final fullName = (user['fullName'] ?? 'Unknown').toString();
    final userImage = (user['userImage'] ?? '/v-public/default_user_image.png').toString();
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final text = (review['text'] ?? '').toString();
    final createdAt = review['createdAt'];
    final dateStr = createdAt != null
        ? DateFormat.yMMMd().format(DateTime.tryParse(createdAt.toString()) ?? DateTime.now())
        : '';
    final reviewUserId = (review['userId'] ?? '').toString();
    final myId = _myId();
    final isMine = myId != null && myId.isNotEmpty && reviewUserId == myId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: VPlatformCacheImageWidget(
                    source: VPlatformFile.fromUrl(networkUrl: userImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Row(
                      children: [
                        _buildStarRating(rating: rating, onChanged: (_) {}, size: 14, interactive: false),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isMine)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _deletingReview ? null : _deleteReview,
                  child: _deletingReview
                      ? const CupertinoActivityIndicator(radius: 10)
                      : const Icon(
                          CupertinoIcons.trash,
                          color: CupertinoColors.systemRed,
                          size: 20,
                        ),
                ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    final l = _listing ?? widget.listing;
    final ownerId = (l['userId'] ?? '').toString();
    final myId = _myId();
    final isMine = myId != null && myId.isNotEmpty && ownerId.isNotEmpty && ownerId == myId;
    final hasMyReview = _hasMyReview();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Reviews',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(width: 10),
            if (_ratingCount > 0) ...[
              Icon(CupertinoIcons.star_fill, color: const Color(0xFFFFB800), size: 16),
              const SizedBox(width: 4),
              Text(
                '${_ratingAvg.toStringAsFixed(1)} (${_ratingCount.toInt()})',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
            if (_loadingReviews) ...[
              const SizedBox(width: 10),
              const CupertinoActivityIndicator(radius: 8),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Add review form (only if not own listing and logged in)
        if (!isMine && myId != null && myId.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasMyReview ? 'Update your review' : 'Write a review',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildStarRating(
                  rating: _myRating,
                  onChanged: (r) => setState(() => _myRating = r),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: _reviewTextCtrl,
                  placeholder: 'Share your experience (optional)',
                  maxLines: 3,
                  padding: const EdgeInsets.all(12),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        color: const Color(0xFFB48648),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        onPressed: _submittingReview ? null : _submitReview,
                        child: _submittingReview
                            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                            : Text(
                                hasMyReview ? 'Update' : 'Submit',
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    if (hasMyReview) ...[
                      const SizedBox(width: 10),
                      CupertinoButton(
                        color: CupertinoColors.systemRed,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        onPressed: _deletingReview ? null : _deleteReview,
                        child: _deletingReview
                            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                            : const Text(
                                'Delete',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Reviews list
        if (_reviews.isEmpty && !_loadingReviews)
          const Text(
            'No reviews yet',
            style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
          ),
        if (_reviews.isNotEmpty)
          ..._reviews.map((r) => _buildReviewItem(r)),
      ],
    );
  }

  Future<void> _loadSimilar({Map<String, dynamic>? base}) async {
    if (_loadingSimilar) return;
    final l = base ?? (_listing ?? widget.listing);
    final id = _idOf(l);
    if (id.isEmpty) return;

    final category = (l['category'] ?? '').toString().trim();
    final lat = (l['locationLat'] as num?)?.toDouble();
    final lng = (l['locationLng'] as num?)?.toDouble();
    const radiusKm = 25.0;

    setState(() => _loadingSimilar = true);
    try {
      final list = await _api.feed(
        category: category.isNotEmpty ? category : null,
        limit: 60,
        lat: lat,
        lng: lng,
        radiusKm: (lat != null && lng != null) ? radiusKm : null,
      );

      var filtered = list.where((it) => _idOf(it) != id).toList();
      filtered = _applyLocalDistanceFilter(filtered, lat: lat, lng: lng, radiusKm: radiusKm);

      filtered.sort((a, b) => _similarityScore(l, b).compareTo(_similarityScore(l, a)));

      final top = filtered.take(10).toList();
      if (!mounted) return;
      setState(() {
        _similar = top;
        _loadingSimilar = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _similar = const [];
        _loadingSimilar = false;
      });
    }
  }

  String? _firstImageUrl(Map<String, dynamic> listing) {
    final media = listing['media'];
    if (media is List) {
      for (final m in media) {
        if (m is Map) {
          final type = (m['type'] ?? '').toString();
          final url = (m['url'] ?? '').toString();
          if (type == 'image' && url.isNotEmpty) return url;
        }
      }
    }
    return null;
  }

  Widget _similarCard(CupertinoThemeData theme, Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString();
    final price = (item['price'] as num?);
    final imgUrl = _firstImageUrl(item);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => MarketplaceListingDetailsView(listing: item),
          ),
        );
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: imgUrl == null
                    ? const Icon(
                        CupertinoIcons.photo,
                        size: 40,
                        color: CupertinoColors.systemGrey,
                      )
                    : VPlatformCacheImageWidget(
                        source: VPlatformFile.fromUrl(networkUrl: imgUrl),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    price == null ? '' : _formatKes(price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final l = _listing ?? widget.listing;

    String? myId;
    try {
      myId = AppAuth.myProfile.baseUser.id;
    } catch (_) {
      myId = null;
    }
    final ownerId = (l['userId'] ?? '').toString();
    final isMine = myId != null && myId.isNotEmpty && ownerId.isNotEmpty && ownerId == myId;
    final listingId = _idOf(l).trim();

    final canInteract = myId != null && myId.isNotEmpty && !isMine;

    final title = (l['title'] ?? '').toString();
    final brand = (l['brand'] ?? '').toString();
    final condition = (l['condition'] ?? '').toString();
    final category = (l['category'] ?? '').toString();
    final isRealEstate = category.trim().toLowerCase() == 'real estate';
    final isVehicle = category.trim().toLowerCase() == 'vehicles' ||
        category.trim().toLowerCase() == 'vehicle';
    final isElectronics = category.trim().toLowerCase() == 'electronics';
    final isHomeFurniture = category.trim().toLowerCase() == 'home & furniture' ||
        category.trim().toLowerCase() == 'home and furniture';
    final isClothingFashion = category.trim().toLowerCase() == 'clothing & fashion' ||
        category.trim().toLowerCase() == 'clothing and fashion' ||
        category.trim().toLowerCase() == 'fashion';
    final isPetsAnimals = category.trim().toLowerCase() == 'pets & animals' ||
        category.trim().toLowerCase() == 'pets and animals';
    final isServices = category.trim().toLowerCase() == 'services' ||
        category.trim().toLowerCase() == 'service';
    final isBusinessIndustrial = category.trim().toLowerCase() == 'business & industrial' ||
        category.trim().toLowerCase() == 'business and industrial';
    final isKidsBaby = category.trim().toLowerCase() == 'kids & baby' ||
        category.trim().toLowerCase() == 'kids and baby';
    final isSports = category.trim().toLowerCase() == 'sports' ||
        category.trim().toLowerCase() == 'sports & fitness' ||
        category.trim().toLowerCase() == 'sports and fitness';
    final cLower = category.trim().toLowerCase();
    final isBooksMusicHobbies = cLower.contains('book') ||
        (cLower.contains('music') && cLower.contains('hobb')) ||
        cLower == 'books, music & hobbies' ||
        cLower == 'books, music and hobbies' ||
        cLower == 'books music & hobbies' ||
        cLower == 'books music and hobbies' ||
        cLower == 'music & hobbies' ||
        cLower == 'music and hobbies' ||
        cLower == 'books' ||
        cLower == 'book';
    final isSpecial = isRealEstate || isVehicle;
    final desc = (l['description'] ?? '').toString();
    final loc = (l['locationLabel'] ?? '').toString();
    final price = (l['price'] as num?);
    final delRaw = l['deliveryAvailable'];
    final deliveryAvailable = (delRaw == true) ||
        (delRaw?.toString().trim().toLowerCase() == 'true');
    final ptRaw = (l['priceType'] ?? '').toString();
    final priceType = ptRaw.trim().isEmpty
        ? ''
        : (ptRaw == 'negotiable' ? 'Negotiable' : 'Fixed');
    final isSold = (l['isSold'] == true) ||
        (l['isSold']?.toString().trim().toLowerCase() == 'true');

    final tx = (l['realEstateTransactionType'] ?? '').toString().trim();
    final txLower = tx.toLowerCase();
    final txDisplay = txLower == 'buy'
        ? 'Buy'
        : txLower == 'rent'
            ? 'Rent'
            : txLower == 'lease'
                ? 'Lease'
                : tx;
    final propertyType = (l['realEstatePropertyType'] ?? '').toString().trim();
    final beds = l['realEstateBedrooms'];
    final baths = l['realEstateBathrooms'];
    final sqft = l['realEstateSquareFootage'];
    final furnRaw = l['realEstateFurnished'];
    final furnished = (furnRaw == true) || (furnRaw?.toString().trim().toLowerCase() == 'true');
    final amenitiesRaw = l['realEstateAmenities'];
    final amenities = (amenitiesRaw is List)
        ? amenitiesRaw.map((e) => (e ?? '').toString().trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    final vehicleType = (l['vehicleType'] ?? '').toString().trim();
    final vehicleMake = (l['vehicleMake'] ?? '').toString().trim();
    final vehicleModel = (l['vehicleModel'] ?? '').toString().trim();
    final vYear = l['vehicleYear'];
    final vMileage = l['vehicleMileage'];

    final transRaw = (l['vehicleTransmission'] ?? '').toString().trim();
    final transLower = transRaw.toLowerCase();
    final transmission = transLower == 'automatic'
        ? 'Automatic'
        : transLower == 'manual'
            ? 'Manual'
            : transRaw;

    final fuelRaw = (l['vehicleFuelType'] ?? '').toString().trim();
    final fuelLower = fuelRaw.toLowerCase();
    final fuel = fuelLower.isEmpty
        ? ''
        : fuelLower == 'gasoline'
            ? 'Gasoline'
            : fuelLower == 'diesel'
                ? 'Diesel'
                : fuelLower == 'hybrid'
                    ? 'Hybrid'
                    : fuelLower == 'electric'
                        ? 'Electric'
                        : fuelLower == 'lpg'
                            ? 'LPG'
                            : fuelRaw;

    final warrantyStatus = (l['electronicsWarrantyStatus'] ?? '').toString().trim();

    final homeFurnitureItemDimensions =
        (l['homeFurnitureItemDimensions'] ?? '').toString().trim();
    final homeFurniturePickupDeliveryNotes =
        (l['homeFurniturePickupDeliveryNotes'] ?? '').toString().trim();

    final clothingFashionSize = (l['clothingFashionSize'] ?? '').toString().trim();
    final clothingFashionColor = (l['clothingFashionColor'] ?? '').toString().trim();

    final servicesCategoryRaw = (l['servicesCategory'] ?? '').toString().trim();
    final servicesCategoryLower = servicesCategoryRaw.toLowerCase();
    final servicesCategory = servicesCategoryLower == 'home'
        ? 'Home'
        : servicesCategoryLower == 'professional'
            ? 'Professional'
            : servicesCategoryLower == 'personal'
                ? 'Personal'
                : servicesCategoryRaw;

    final reqBulkOrder = l['businessIndustrialBulkOrder'];
    final businessIndustrialBulkOrder = (reqBulkOrder == true) ||
        (reqBulkOrder?.toString().trim().toLowerCase() == 'true');
    final minQtyRaw = l['businessIndustrialMinQty'];
    final businessIndustrialMinQty = minQtyRaw is num
        ? minQtyRaw.toInt()
        : int.tryParse((minQtyRaw ?? '').toString().trim());

    final sportsTagsRaw = l['sportsOutdoorGearTags'];
    final sportsOutdoorGearTags = (sportsTagsRaw is List)
        ? sportsTagsRaw
            .map((e) => (e ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];

    final booksMusicHobbiesAuthor =
        (l['booksMusicHobbiesAuthor'] ?? '').toString().trim();
    final booksMusicHobbiesInstrument =
        (l['booksMusicHobbiesInstrument'] ?? '').toString().trim();
    final collectibleRaw = l['booksMusicHobbiesCollectible'];
    final booksMusicHobbiesCollectible = (collectibleRaw == true) ||
        (collectibleRaw?.toString().trim().toLowerCase() == 'true');

    final petsAnimalsType = (l['petsAnimalsType'] ?? '').toString().trim();
    final petsAnimalsBreed = (l['petsAnimalsBreed'] ?? '').toString().trim();
    final petsAnimalsVaccinationRecords =
        (l['petsAnimalsVaccinationRecords'] ?? '').toString().trim();

    final vin = (l['vehicleVin'] ?? '').toString().trim();
    final history = (l['vehicleHistoryNotes'] ?? '').toString().trim();

    final vehicleAlertKey = isVehicle && vehicleMake.isNotEmpty && vehicleModel.isNotEmpty
        ? 'marketplace_vehicle_alert_${vehicleMake.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), '_')}_${vehicleModel.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), '_')}'
        : null;
    final vehicleAlertEnabled =
        vehicleAlertKey == null ? false : VAppPref.getBool(vehicleAlertKey);

    final media = _media(l);
    final hasVideoTour = media.any((m) => (m['type'] ?? '').toString() == 'video');

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Listing'),
        trailing: isMine
            ? (_loading
                ? const CupertinoActivityIndicator()
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _refresh,
                    child: const Icon(CupertinoIcons.refresh),
                  ))
            : (!canInteract)
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _liking ? null : _toggleLike,
                        child: _liking
                            ? const CupertinoActivityIndicator()
                            : Icon(
                                _liked
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.heart,
                                color: const Color(0xFFB48648),
                              ),
                      ),
                      const SizedBox(width: 6),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _bookmarking ? null : _toggleBookmark,
                        child: _bookmarking
                            ? const CupertinoActivityIndicator()
                            : Icon(
                                _bookmarked
                                    ? CupertinoIcons.bookmark_fill
                                    : CupertinoIcons.bookmark,
                                color: const Color(0xFFB48648),
                              ),
                      ),
                    ],
                  ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _gallery(media),
              const SizedBox(height: 14),
              if (price != null)
                Text(
                  _formatKes(price),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              if (price == null)
                const Text(
                  'No price',
                  style: TextStyle(color: CupertinoColors.systemGrey),
                ),
              const SizedBox(height: 6),
              Text(
                title.isEmpty ? 'Untitled' : title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.heart_fill,
                    size: 14,
                    color: const Color(0xFFB48648).withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_likesCount.toInt()}',
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (category.isNotEmpty) _field('Category', category),
              if (!isSpecial && !isHomeFurniture && !isPetsAnimals && !isServices && !isBusinessIndustrial && !isKidsBaby && !isSports && !isBooksMusicHobbies && brand.isNotEmpty)
                _field('Brand', brand),
              if (!isSpecial && !isPetsAnimals && !isServices && condition.isNotEmpty)
                _field('Condition', condition),
              if (isElectronics && warrantyStatus.isNotEmpty)
                _field('Warranty status', warrantyStatus),
              if (isHomeFurniture && homeFurnitureItemDimensions.isNotEmpty)
                _field('Item dimensions', homeFurnitureItemDimensions),
              if (isHomeFurniture && homeFurniturePickupDeliveryNotes.isNotEmpty)
                _field('Pickup/Delivery notes', homeFurniturePickupDeliveryNotes),
              if (isClothingFashion && clothingFashionSize.isNotEmpty)
                _field('Size', clothingFashionSize),
              if (isClothingFashion && clothingFashionColor.isNotEmpty)
                _field('Color', clothingFashionColor),
              if (isServices && servicesCategory.isNotEmpty)
                _field('Service category', servicesCategory),
              if (isBusinessIndustrial)
                _field('Bulk order', businessIndustrialBulkOrder ? 'Yes' : 'No'),
              if (isBusinessIndustrial && businessIndustrialBulkOrder && businessIndustrialMinQty != null)
                _field('Min qty', businessIndustrialMinQty.toString()),
              if (isSports && sportsOutdoorGearTags.isNotEmpty)
                _field('Outdoor gear tags', sportsOutdoorGearTags.join(', ')),
              if (isBooksMusicHobbies && booksMusicHobbiesAuthor.isNotEmpty)
                _field('Author', booksMusicHobbiesAuthor),
              if (isBooksMusicHobbies && booksMusicHobbiesInstrument.isNotEmpty)
                _field('Instrument', booksMusicHobbiesInstrument),
              if (isBooksMusicHobbies && booksMusicHobbiesCollectible)
                _field('Collectible', 'Yes'),
              if (isPetsAnimals && petsAnimalsType.isNotEmpty)
                _field('Animal', petsAnimalsType),
              if (isPetsAnimals && petsAnimalsBreed.isNotEmpty)
                _field('Breed', petsAnimalsBreed),
              if (isPetsAnimals && petsAnimalsVaccinationRecords.isNotEmpty)
                _field('Vaccination records', petsAnimalsVaccinationRecords),
              if (isRealEstate && txDisplay.isNotEmpty) _field('Transaction', txDisplay),
              if (isRealEstate && propertyType.isNotEmpty) _field('Property type', propertyType),
              if (isRealEstate && beds != null) _field('Bedrooms', beds.toString()),
              if (isRealEstate && baths != null) _field('Bathrooms', baths.toString()),
              if (isRealEstate && sqft != null) _field('Square footage', sqft.toString()),
              if (isRealEstate) _field('Furnished', furnished ? 'Yes' : 'No'),
              if (isRealEstate && amenities.isNotEmpty) _field('Amenities', amenities.join(', ')),
              if (isRealEstate) _field('Video tour', hasVideoTour ? 'Yes' : 'No'),

              if (isVehicle && vehicleType.isNotEmpty) _field('Vehicle type', vehicleType),
              if (isVehicle && vehicleMake.isNotEmpty) _field('Make', vehicleMake),
              if (isVehicle && vehicleModel.isNotEmpty) _field('Model', vehicleModel),
              if (isVehicle && vYear != null) _field('Year', vYear.toString()),
              if (isVehicle && vMileage != null) _field('Mileage', vMileage.toString()),
              if (isVehicle && transmission.isNotEmpty) _field('Transmission', transmission),
              if (isVehicle && fuel.isNotEmpty) _field('Fuel', fuel),
              if (isVehicle && vin.isNotEmpty) _field('VIN / Chassis', vin),
              if (isVehicle && history.isNotEmpty) _field('History', history),
              if (priceType.isNotEmpty) _field('Price type', priceType),
              if (loc.isNotEmpty) _field('Location', loc),
              if (!isSpecial && !isPetsAnimals && !isServices)
                _field('Delivery', deliveryAvailable ? 'Yes' : 'No'),
              const SizedBox(height: 14),
              if (desc.isNotEmpty) ...[
                const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(desc),
              ],

              if (!isMine && canInteract && isVehicle) ...[
                const SizedBox(height: 14),
                const Text('Negotiate', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (price != null && price > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          color: const Color(0xFFB48648),
                          onPressed: _openingChat
                              ? null
                              : () {
                                  final amt = (price * 0.95).round();
                                  unawaited(
                                    _sendMarketplaceOfferToSeller(
                                      sellerId: ownerId,
                                      amount: amt,
                                    ),
                                  );
                                },
                          child: Text(
                            '-5% (${_formatKes((price * 0.95).round())})',
                            style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CupertinoButton(
                          color: const Color(0xFFB48648),
                          onPressed: _openingChat
                              ? null
                              : () {
                                  final amt = (price * 0.90).round();
                                  unawaited(
                                    _sendMarketplaceOfferToSeller(
                                      sellerId: ownerId,
                                      amount: amt,
                                    ),
                                  );
                                },
                          child: Text(
                            '-10% (${_formatKes((price * 0.90).round())})',
                            style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CupertinoButton(
                          color: const Color(0xFFB48648),
                          onPressed: _openingChat
                              ? null
                              : () {
                                  final amt = (price * 0.85).round();
                                  unawaited(
                                    _sendMarketplaceOfferToSeller(
                                      sellerId: ownerId,
                                      amount: amt,
                                    ),
                                  );
                                },
                          child: Text(
                            '-15% (${_formatKes((price * 0.85).round())})',
                            style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: const Color(0xFFB48648),
                    onPressed: _openingChat
                        ? null
                        : () async {
                            final amt = await _askOfferAmount(initial: price);
                            if (amt == null) return;
                            if (!mounted) return;
                            unawaited(
                              _sendMarketplaceOfferToSeller(
                                sellerId: ownerId,
                                amount: amt,
                              ),
                            );
                          },
                    child: const Text(
                      'Custom offer',
                      style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (vehicleAlertKey != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Alert me for $vehicleMake $vehicleModel',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        CupertinoSwitch(
                          value: vehicleAlertEnabled,
                          onChanged: _loading
                              ? null
                              : (v) {
                                  unawaited(() async {
                                    await VAppPref.setBool(vehicleAlertKey, v);
                                    if (mounted) setState(() {});
                                  }());
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              if (isMine && listingId.isNotEmpty) ...[
                const SizedBox(height: 14),
                if (isSold)
                  const Text(
                    'Sold',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: CupertinoColors.activeGreen,
                    ),
                  ),
                if (!isSold)
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: CupertinoColors.activeGreen,
                      onPressed: _loading ? null : () => _markSold(listingId, initialPrice: price),
                      child: const Text(
                        'Mark as sold',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],

              if (!isMine && ownerId.isNotEmpty && !_listingUnavailable) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: const Color(0xFFB48648),
                    onPressed: _openingChat
                        ? null
                        : () => _openChatWithSeller(ownerId),
                    child: _openingChat
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : const Text(
                            'Chat seller',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],

              if (!isMine && myId != null && myId.isNotEmpty && listingId.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: CupertinoColors.systemRed,
                    onPressed: _reporting ? null : () => _reportListing(listingId),
                    child: _reporting
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : const Text(
                            'Report listing',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],

              // Reviews section
              _buildReviewsSection(),

              if (_loadingSimilar || _similar.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Similar listings',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    if (_loadingSimilar) const CupertinoActivityIndicator(radius: 8),
                  ],
                ),
                const SizedBox(height: 10),
                if (!_loadingSimilar && _similar.isEmpty)
                  Text(
                    'No similar listings found',
                    style: theme.textTheme.textStyle.copyWith(
                      color: CupertinoColors.systemGrey,
                      fontSize: 13,
                    ),
                  ),
                if (_similar.isNotEmpty)
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _similar.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => _similarCard(theme, _similar[index]),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String? _buildCloudinaryVideoThumbnailUrl(String rawUrl) {
    try {
      if (rawUrl.isEmpty) return null;
      final fullUrl = rawUrl.startsWith('http')
          ? rawUrl
          : '${SConstants.baseMediaUrl}$rawUrl';
      final u = Uri.parse(fullUrl);
      if (!u.host.contains('res.cloudinary.com')) return null;
      final path = u.path;
      final idx = path.indexOf('/upload/');
      if (idx == -1) return null;

      final prefix = '${u.scheme}://${u.host}${path.substring(0, idx + '/upload/'.length)}';
      final tail = path.substring(idx + '/upload/'.length).replaceFirst(RegExp(r'^/+'), '');
      final jpgTail = tail.replaceAll(RegExp(r'\.[^./]+$'), '.jpg');
      const transform = 'so_1,w_640,h_360,c_fill,f_jpg';
      return '$prefix$transform/$jpgTail';
    } catch (_) {
      return null;
    }
  }

  Widget _gallery(List<Map<String, dynamic>> media) {
    final imgs = media
        .where((m) => (m['type'] ?? '').toString() == 'image')
        .map((m) => (m['url'] ?? '').toString())
        .where((u) => u.isNotEmpty)
        .toList();

    final videoMedia = media.firstWhere(
      (m) => (m['type'] ?? '').toString() == 'video',
      orElse: () => <String, dynamic>{},
    );
    final hasVideo = videoMedia.isNotEmpty;
    final videoUrl = hasVideo ? (videoMedia['url'] ?? '').toString() : '';

    if (imgs.isEmpty && !hasVideo) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(child: Icon(CupertinoIcons.photo, size: 44)),
      );
    }

    final pages = <Widget>[
      for (final u in imgs)
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            color: CupertinoColors.systemGrey5,
            child: VPlatformCacheImageWidget(
              source: VPlatformFile.fromUrl(networkUrl: u),
              fit: BoxFit.contain,
            ),
          ),
        ),
      if (hasVideo) () {
        final thumbnailUrl = _buildCloudinaryVideoThumbnailUrl(videoUrl);
        if (thumbnailUrl != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: CupertinoColors.systemGrey5,
                  child: VPlatformCacheImageWidget(
                    source: VPlatformFile.fromUrl(networkUrl: thumbnailUrl),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.play_circle_fill,
                    size: 54,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ],
          );
        } else {
          return Container(
            height: 260,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Icon(CupertinoIcons.play_circle, size: 54),
            ),
          );
        }
      }(),
    ];

    return SizedBox(
      height: 350,
      child: PageView(children: pages),
    );
  }
}
