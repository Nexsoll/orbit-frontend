import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';
import 'package:super_up/app/modules/marketplace/services/marketplace_api_service.dart';
import 'package:super_up/app/core/services/user_verification_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';
import 'package:v_chat_room_page/v_chat_room_page.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import '../../../../v_chat_v2/translations.dart';
import '../../chats_search/views/chats_search_view.dart';
import 'marketplace_listing_details_view.dart';

class MarketplaceMessagesView extends StatefulWidget {
  const MarketplaceMessagesView({super.key});

  @override
  State<MarketplaceMessagesView> createState() => _MarketplaceMessagesViewState();
}

class _MarketplaceMessagesViewState extends State<MarketplaceMessagesView> {
  late final VRoomController _controller;
  late final MarketplaceApiService _marketplaceApi;
  late final ProfileApiService _profileApi;
  Timer? _normalizeTimer;
  int _normalizeAttempts = 0;
  StreamSubscription<VMessageEvents>? _messageEventsSub;

  @override
  void initState() {
    super.initState();
    _controller = VRoomController();
    _marketplaceApi = GetIt.I.get<MarketplaceApiService>();
    _profileApi = GetIt.I.get<ProfileApiService>();
    _controller.setRoomFilter(
      (room) => room.roomType == VRoomType.o && room.peerId != null,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNormalizeTimer();
    });

    try {
      _messageEventsSub = VChatController
          .I.nativeApi.streams.messageStream
          .where((event) => event is VInsertMessageEvent)
          .listen((_) async {
        await _controller.refreshFromLocal();
      });
    } catch (_) {
      // ignore
    }
  }

  void _startNormalizeTimer() {
    _normalizeTimer?.cancel();
    _normalizeAttempts = 0;
    _normalizeTimer = Timer.periodic(const Duration(milliseconds: 650), (_) async {
      _normalizeAttempts++;
      await _normalizeMarketplaceRooms();
      if (_normalizeAttempts >= 8) {
        _normalizeTimer?.cancel();
        _normalizeTimer = null;
      }
    });
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      try {
        return Map<String, dynamic>.from(v);
      } catch (_) {
        return null;
      }
    }
    if (v is String) {
      try {
        final parsed = jsonDecode(v);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      } catch (_) {}
    }
    return null;
  }

  String _extractListingId({required String orderId, required dynamic pinData}) {
    final pin = _asMap(pinData);
    final direct = (pin?['listingId'] ?? pin?['listing_id'] ?? pin?['_id'] ?? pin?['id'])
        .toString()
        .trim();
    if (direct.isNotEmpty) return direct;
    final listing = pin?['listing'];
    if (listing is Map) {
      final id = (listing['_id'] ?? listing['id']).toString().trim();
      if (id.isNotEmpty) return id;
    }
    if (orderId.startsWith('mp_')) {
      final parts = orderId.split('_');
      if (parts.length >= 2) return parts[1].toString().trim();
    }
    return '';
  }

  Future<void> _normalizeMarketplaceRooms() async {
    try {
      final rooms = _controller.rooms.isNotEmpty
          ? _controller.rooms
          : await VChatController.I.nativeApi.local.room.getRooms(
              limit: 200,
            );

      await _purgeRemovedMarketplaceRooms(rooms);

      for (final r in rooms) {
        if (r.roomType != VRoomType.o) continue;
        final peerId = r.peerId;
        if (peerId == null || peerId.trim().isEmpty) continue;
        await _normalizeRoomFromPeerProfile(r, peerId);
      }
    } catch (_) {}
  }

  Future<void> _purgeRemovedMarketplaceRooms(List<VRoom> rooms) async {
    bool deletedAny = false;
    for (final r in rooms) {
      if (r.roomType != VRoomType.o) continue;
      try {
        final info = await VChatController.I.nativeApi.remote.room.getOrderRoomInfo(
          roomId: r.id,
        );
        final settings = info.orderSettings;
        final orderId = settings.orderId.toString().trim();
        if (orderId.isEmpty) continue;
        final pin = settings.pinData;
        final type = (_asMap(pin)?['type'] ?? '').toString().trim();
        final isMarketplace = orderId.startsWith('mp_') || type == 'marketplace_listing';
        if (!isMarketplace) continue;
        final listingId = _extractListingId(orderId: orderId, pinData: pin);
        if (listingId.isEmpty) continue;
        await _marketplaceApi.getListingPublic(listingId);
      } catch (_) {
        await _deleteMarketplaceRoom(r.id);
        deletedAny = true;
      }
    }
    if (deletedAny) {
      await _controller.refreshFromLocal();
    }
  }

  Future<void> _deleteMarketplaceRoom(String roomId) async {
    try {
      await VChatController.I.nativeApi.local.room.deleteRoom(roomId);
    } catch (_) {}
  }

  Future<void> _normalizeRoomFromPeerProfile(VRoom room, String peerId) async {
    try {
      final peer = await _profileApi.peerProfile(peerId);
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

  Future<VRoom> _syncMarketplaceOrderRoomIfNeeded(VRoom room) async {
    if (room.roomType != VRoomType.o) return room;
    final peerId = room.peerId;
    if (peerId == null || peerId.trim().isEmpty) return room;
    try {
      final info = await VChatController.I.nativeApi.remote.room.getOrderRoomInfo(
        roomId: room.id,
      );
      final settings = info.orderSettings;
      final orderId = settings.orderId.toString().trim();
      if (orderId.isEmpty) return room;
      final pin = settings.pinData;
      final type = (pin?['type'] ?? '').toString().trim();
      final isMarketplace = orderId.startsWith('mp_') || type == 'marketplace_listing';
      if (!isMarketplace) return room;
      if (pin == null) return room;

      final updatedRoom = await VChatController.I.nativeApi.remote.room.createOrderRoom(
        CreateOrderRoomDto(
          peerId: peerId,
          orderId: orderId,
          orderTitle: null,
          orderImage: null,
          orderData: pin,
        ),
      );
      await VChatController.I.nativeApi.local.room.safeInsertRoom(updatedRoom);
      return updatedRoom;
    } catch (_) {
      return room;
    }
  }

  @override
  void dispose() {
    _normalizeTimer?.cancel();
    _messageEventsSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Messages')),
      child: SafeArea(
        child: VChatPage(
          controller: _controller,
          language: vRoomLanguageModel(context),
          onSearchClicked: () {
            context.toPage(const ChatsSearchView());
          },
          onCreateNewGroup: null,
          onCreateNewBroadcast: null,
          headerWidget: null,
          showDisconnectedWidget: false,
          onRoomItemPress: (room) async {
            final updatedRoom = await _syncMarketplaceOrderRoomIfNeeded(room);

            // Block opening chats for removed marketplace listings
            try {
              if (updatedRoom.roomType == VRoomType.o) {
                final info = await VChatController.I.nativeApi.remote.room.getOrderRoomInfo(
                  roomId: updatedRoom.id,
                );
                final settings = info.orderSettings;
                final orderId = settings.orderId.toString().trim();
                final pin = settings.pinData;
                final type = (_asMap(pin)?['type'] ?? '').toString().trim();
                final isMarketplace = orderId.startsWith('mp_') || type == 'marketplace_listing';
                if (isMarketplace) {
                  final listingId = _extractListingId(orderId: orderId, pinData: pin);
                  if (listingId.isNotEmpty) {
                    try {
                      await _marketplaceApi.getListingPublic(listingId);
                    } catch (_) {
                      if (!mounted) return;
                      VAppAlert.showErrorSnackBar(
                        context: context,
                        message: 'Listing is no longer available',
                      );
                      await _deleteMarketplaceRoom(updatedRoom.id);
                      await _controller.refreshFromLocal();
                      return;
                    }
                  }
                }
              }
            } catch (_) {
              // ignore
            }

            final peerId = updatedRoom.peerId;
            if (peerId != null && peerId.trim().isNotEmpty) {
              await _normalizeRoomFromPeerProfile(updatedRoom, peerId);
            }
            final config = VAppConfigController.appConfig;
            final messageConfig = VMessageConfig(
              googleMapsApiKey: SConstants.googleMapsApiKey,
              isCallsAllowed: false,
              isSendMediaAllowed: true,
              onOrderCardPress: (ctx, r, pin) async {
                final listingId = (pin['listingId'] ?? '').toString().trim();
                if (listingId.isEmpty) return;
                try {
                  final listing = await _marketplaceApi.getListing(listingId);
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
                    final listing = await _marketplaceApi.getListingPublic(listingId);
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
                      vRoom: updatedRoom,
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

            await _controller.refreshFromLocal();
          },
        ),
      ),
    );
  }
}
