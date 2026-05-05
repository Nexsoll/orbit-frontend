// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:developer';
import 'dart:async' show unawaited;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:get_it/get_it.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:super_up/app/core/app_nav/app_navigation.dart';
import 'package:super_up/app/core/services/user_verification_service.dart';
import 'package:super_up/app/modules/home/mobile/rooms_tab/controllers/rooms_tab_controller.dart';
import 'package:super_up/app/modules/ai_assistant/views/ai_assistant_page.dart';
import 'package:super_up/app/modules/chat_settings/broadcast_room_settings/views/broadcast_room_settings_view.dart';
import 'package:super_up/app/modules/chat_settings/group_room_settings/views/group_room_settings_view.dart';
import 'package:super_up/app/modules/chat_settings/single_room_settings/views/single_room_settings_view.dart';
import 'package:super_up/app/modules/marketplace/services/marketplace_api_service.dart';
import 'package:super_up/app/modules/marketplace/views/marketplace_listing_details_view.dart';
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up/app/modules/report/views/report_page.dart';
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';
import 'package:super_up/v_chat_v2/translations.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_firebase_fcm/v_chat_firebase_fcm.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';

// import 'package:v_chat_one_signal/v_chat_one_signal.dart';
// import 'package:v_chat_one_signal/v_chat_one_signal.dart';
import 'package:v_chat_room_page/v_chat_room_page.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:path_provider/path_provider.dart';
import 'package:super_up/app/utils/current_room_holder.dart';
import 'package:super_up/app/modules/poll/create_poll_page.dart';
import 'package:super_up/app/modules/schedule/schedule_message_page.dart';
import 'package:super_up/app/widgets/live_location_duration_picker.dart';

Future<void> _showPhoneNumberActions(
  BuildContext context, {
  required String phone,
}) async {
  if (!context.mounted) return;

  if (!VPlatforms.isMobile) {
    await VStringUtils.lunchLink('tel:$phone');
    return;
  }

  final inviteMsg =
      'Hi, join me on ${SConstants.appName}!\n\nAndroid: ${SConstants.playStoreUrl}\n\niOS: ${SConstants.appStoreUrl}';

  await showCupertinoModalPopup(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(phone),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await VStringUtils.lunchLink('tel:$phone');
          },
          child: const Text('Dial pad'),
        ),
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.of(ctx).pop();
            final encodedBody = Uri.encodeComponent(inviteMsg);
            final smsUrl = VPlatforms.isIOS
                ? 'sms:$phone&body=$encodedBody'
                : 'sms:$phone?body=$encodedBody';
            await VStringUtils.lunchLink(smsUrl);
          },
          child: const Text('Send invite link'),
        ),
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.of(ctx).pop();

            final granted = await FlutterContacts.requestPermission();
            if (!granted) {
              if (!context.mounted) return;
              VAppAlert.showErrorSnackBar(
                context: context,
                message: 'Contacts permission denied',
              );
              return;
            }

            try {
              // Use phone number as the contact name (WhatsApp-style)
              final contact = Contact(
                name: Name(first: phone),
                phones: [Phone(phone)],
              );
              await FlutterContacts.insertContact(contact);
              if (!context.mounted) return;
              VAppAlert.showSuccessSnackBar(
                context: context,
                message: 'Contact saved',
              );
            } catch (e) {
              if (!context.mounted) return;
              VAppAlert.showErrorSnackBar(
                context: context,
                message: 'Failed to save contact: ${e.toString()}',
              );
            }
          },
          child: const Text('Add to contact'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text('Cancel'),
      ),
    ),
  );
}

Future initVChat(GlobalKey<NavigatorState> navigatorKey) async {
  await VChatController.init(
    navigatorKey: navigatorKey,
    vChatConfig: VChatConfig(
      ///don't update
      baseUrl: SConstants.sApiBaseUrl,
      enableEndToEndMessageEncryption: true,
      vPush: VPush(
        enableVForegroundNotification: true,
        vPushConfig: const VLocalNotificationPushConfig(),

        ///if you support fcm push notifications
        fcmProvider: VChatFcmProver(initializeApp: false),

        ///if you support OneSignal push notifications
        // oneSignalProvider: VChatOneSignalProver(
        //   appId: SConstants.oneSignalAppId,
        // ),
      ),

      ///don't update
      onReportUserPress: (context, id) {
        context.toPage(ReportPage(userId: id));
      },
    ),

    ///don't update
    vNavigator: VNavigator(
      roomNavigator: vDefaultRoomNavigator,
      callNavigator: vDefaultCallNavigator,
      messageNavigator: VMessageNavigator(
        //this happens when user click on image in message page
        toImageViewer: (context, source, showDownload) {
          AppNavigation.toPage(
            context,
            VImageViewer(
              showDownload: showDownload,
              platformFileSource: source,
              downloadingLabel: S.of(context).downloading,
              successfullyDownloadedInLabel:
                  S.of(context).successfullyDownloadedIn,
            ),
            appNavigationType: AppNavigationType.popUpAlert,
          );
        },
        //this happens when user click on video in message page
        toVideoPlayer: (context, source, showDownload) async {
          // Try to load drawing overlay metadata to pass to the player
          String? drawingData;
          try {
            String? videoPath = source.fileLocalPath;
            if (videoPath == null && VPlatforms.isMobile) {
              // Best-effort: look for latest sidecar in app docs dir
              final dir = await getApplicationDocumentsDirectory();
              final d = Directory(dir.path);
              if (await d.exists()) {
                final files = d
                    .listSync()
                    .whereType<File>()
                    .where((f) => f.path.endsWith('.drawing.json'))
                    .toList();
                if (files.isNotEmpty) {
                  files.sort((a, b) =>
                      b.lastModifiedSync().compareTo(a.lastModifiedSync()));
                  final content = files.first.readAsStringSync();
                  if (content.trim().startsWith('{') && content.contains(':')) {
                    drawingData = content;
                  }
                }
              }
            }

            if (videoPath != null) {
              final candidates = [
                videoPath.replaceAll('.mp4', '.drawing.json'),
                videoPath.replaceAll('.mp4', '_drawing.json'),
                videoPath.replaceAll('.mp4', '.drawing'),
              ];
              for (final p in candidates) {
                final f = File(p);
                if (f.existsSync()) {
                  final content = f.readAsStringSync();
                  if (content.trim().startsWith('{') && content.contains(':')) {
                    drawingData = content;
                    log('v_chat_config: found drawing metadata at $p');
                    break;
                  }
                }
              }
              // Fallback: scan app documents dir for the most recent .drawing.json
              if (drawingData == null) {
                try {
                  final dir = await getApplicationDocumentsDirectory();
                  final d = Directory(dir.path);
                  if (await d.exists()) {
                    final files = d
                        .listSync()
                        .whereType<File>()
                        .where((f) => f.path.endsWith('.drawing.json'))
                        .toList();
                    if (files.isNotEmpty) {
                      files.sort((a, b) =>
                          b.lastModifiedSync().compareTo(a.lastModifiedSync()));
                      final content = files.first.readAsStringSync();
                      if (content.trim().startsWith('{') &&
                          content.contains(':')) {
                        drawingData = content;
                        log('v_chat_config: fallback using ${files.first.path}');
                      }
                    }
                  }
                } catch (e) {
                  log('v_chat_config: fallback scan failed: $e');
                }
              }
            }
          } catch (e) {
            log('v_chat_config: error loading drawing metadata: $e');
          }

          SStorageKeys.vAccessToken;
          AppNavigation.toPage(
            context,
            VVideoPlayer(
              showDownload: showDownload,
              platformFileSource: source,
              downloadingLabel: S.of(context).downloading,
              successfullyDownloadedInLabel:
                  S.of(context).successfullyDownloadedIn,
              drawingOverlayData: drawingData,
            ),
            appNavigationType: AppNavigationType.popUpAlert,
          );
        },

        //when user click on notification or lunch the app from notification this function will call to open the message page
        toMessagePage: (context, vRoom) async {
          final config = VAppConfigController.appConfig;
          final isOrderRoom = vRoom.roomType == VRoomType.o;
          var roomToOpen = vRoom;

          if (isOrderRoom) {
            try {
              final peerId = vRoom.peerId;
              if (peerId != null && peerId.trim().isNotEmpty) {
                final info = await VChatController.I.nativeApi.remote.room
                    .getOrderRoomInfo(roomId: vRoom.id);
                final settings = info.orderSettings;
                final orderId = settings.orderId.toString().trim();
                final pin = settings.pinData;
                final type = (pin?['type'] ?? '').toString().trim();
                final isMarketplace =
                    orderId.startsWith('mp_') || type == 'marketplace_listing';

                if (isMarketplace) {
                  MarketplaceApiService api;
                  try {
                    api = GetIt.I.get<MarketplaceApiService>();
                  } catch (_) {
                    api = MarketplaceApiService.init();
                  }

                  var listingId =
                      (pin?['listingId'] ?? pin?['listing_id'] ?? '')
                          .toString()
                          .trim();
                  if (listingId.isEmpty && orderId.startsWith('mp_')) {
                    final parts = orderId.split('_');
                    if (parts.length >= 2) {
                      listingId = parts[1].toString().trim();
                    }
                  }

                  if (listingId.isNotEmpty) {
                    try {
                      await api.getListingPublic(listingId);
                    } catch (_) {
                      if (context.mounted) {
                        VAppAlert.showErrorSnackBar(
                          context: context,
                          message: 'Listing is no longer available',
                        );
                      }
                      unawaited(VChatController.I.nativeApi.local.room
                          .deleteRoom(vRoom.id));
                      return null;
                    }
                  }
                }

                if (isMarketplace && orderId.isNotEmpty && pin != null) {
                  final updatedRoom = await VChatController
                      .I.nativeApi.remote.room
                      .createOrderRoom(
                    CreateOrderRoomDto(
                      peerId: peerId,
                      orderId: orderId,
                      orderTitle: null,
                      orderImage: null,
                      orderData: pin,
                    ),
                  );
                  await VChatController.I.nativeApi.local.room
                      .safeInsertRoom(updatedRoom);
                  roomToOpen = updatedRoom;
                }
              }
            } catch (_) {}
          }

          // Check if this is the AI Assistant room - use custom page
          final isAiAssistant = vRoom.id == "ai_assistant_room" ||
              vRoom.peerId == "ai_assistant_peer";

          if (isAiAssistant) {
            // Use custom AI Assistant page with web search toggle
            return AppNavigation.toPage(
              context,
              AiAssistantPage(vRoom: vRoom),
              appNavigationType: AppNavigationType.messages,
              isRemoveAllWide: true,
            );
          }

          final messageConfig = VMessageConfig(
            googleMapsApiKey: SConstants.googleMapsApiKey,
            isCallsAllowed: isOrderRoom ? false : config.allowCall,
            isSendMediaAllowed: isOrderRoom ? true : config.allowSendMedia,
            isEnableAds: config.enableAds,
            onPhoneNumberPress: (ctx, phone) async {
              ProfileApiService api;
              try {
                api = GetIt.I.get<ProfileApiService>();
              } catch (_) {
                api = ProfileApiService.init();
              }

              try {
                final userId = await api.resolvePhoneToUserId(phone);
                final v = userId.toString().trim();
                if (v.isEmpty) {
                  await _showPhoneNumberActions(ctx, phone: phone);
                  return;
                }
                if (!ctx.mounted) return;
                await AppNavigation.toPage(
                  ctx,
                  PeerProfileView(peerId: v),
                  appNavigationType: AppNavigationType.chatRoom,
                );
              } catch (e) {
                await _showPhoneNumberActions(ctx, phone: phone);
              }
            },
            onOrderCardPress: (ctx, room, pin) async {
              final listingId = (pin['listingId'] ?? '').toString().trim();
              if (listingId.isEmpty) return;
              MarketplaceApiService api;
              try {
                api = GetIt.I.get<MarketplaceApiService>();
              } catch (_) {
                api = MarketplaceApiService.init();
              }
              try {
                final listing = await api.getListing(listingId);
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
                  final listing = await api.getListingPublic(listingId);
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
                final peerId = room.peerId?.toString().trim() ?? '';
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
              if (!context.mounted) return null;
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
                // Add live location option
                content.add(
                  ModelSheetItem(
                    id: 'live_location',
                    title: 'Live Location',
                    iconData: const Icon(CupertinoIcons.location_fill),
                  ),
                );
              }
              if (!isOrderRoom) {
                content.addAll([
                  ModelSheetItem(
                    id: 'poll',
                    title: 'Poll',
                    iconData: const Icon(CupertinoIcons.chart_bar),
                  ),
                  ModelSheetItem(
                    id: 'schedule',
                    title: 'Schedule',
                    iconData: const Icon(CupertinoIcons.alarm),
                  ),
                ]);
              }

              if (!context.mounted) return null;
              final res = await VAppAlert.showModalSheetWithActions(
                context: context,
                cancelLabel: S.of(context).cancel,
                content: content,
              );
              if (res == null) return null;
              if (!context.mounted) return null;
              if (res.id == 'poll') {
                // Open create poll UI
                final roomId = vRoom.id;
                CurrentRoomHolder.set(roomId);
                await AppNavigation.toPage(
                  context,
                  const CreatePollPage(),
                  appNavigationType: AppNavigationType.popUpAlert,
                );
                return null; // do not propagate default sheet
              } else if (res.id == 'schedule') {
                final roomId = vRoom.id;
                CurrentRoomHolder.set(roomId);
                await AppNavigation.toPage(
                  context,
                  const ScheduleMessagePage(),
                  appNavigationType: AppNavigationType.popUpAlert,
                );
                return null;
              } else if (res.id == 'live_location') {
                // Handle live location selection
                final duration = await LiveLocationDurationPicker.show(context);
                if (duration != null && context.mounted) {
                  // Store the duration for the location picker to use
                  LiveLocationHolder.setDuration(duration);
                  return VAttachEnumRes.location;
                }
                return null;
              }
              return res.id as VAttachEnumRes?;
            },
            onUserUnBlockAnother: null,
            showDisconnectedWidget: true,
            onMessageLongPress: null,
            onUserBlockAnother: null,
            maxMediaSize: 1024 * 1024 * config.maxChatMediaSize,
            compressImageQuality: 55,
            maxRecordTime: const Duration(minutes: 30),
          );
          if (kDebugMode) {
            log('[VNavigator.toMessagePage] Opening room ' +
                roomToOpen.id +
                ' title=' +
                roomToOpen.realTitle +
                ' lastMessage="' +
                roomToOpen.lastMessage.realContent +
                '"');
          }

          // Pre-fetch verification status to ensure the badge displays correctly
          if (roomToOpen.peerId != null && roomToOpen.peerId!.trim().isNotEmpty) {
            try {
              final service = GetIt.instance<UserVerificationService>();
              await service.isUserVerified(roomToOpen.peerId!);
            } catch (_) {}
          }

          final msgPage = VMessagePage(
            vRoom: roomToOpen,
            localization: vMessageLocalizationPageModel(context),
            vMessageConfig: messageConfig,
            isUserVerifiedCallback: (userId) {
              final service = GetIt.instance<UserVerificationService>();
              // Use cached value if available, otherwise return false
              return service.getCachedVerificationStatus(userId) ?? false;
            },
          );
          // Track current room for utilities like polls
          CurrentRoomHolder.set(roomToOpen.id);
          final res = await AppNavigation.toPage(
            context,
            msgPage,
            appNavigationType: AppNavigationType.messages,
            isRemoveAllWide: true,
          );
          return res;
        },
        //this happens when user click on see message information to know when the message send or delivered or seen at for `direct` chat
        toSingleChatMessageInfo: (context, baseMessage) {
          AppNavigation.toPage(
            context,
            VMessageSingleStatusPage(
              message: baseMessage,
              deliveredLabel: S.of(context).delivered,
              readLabel: S.of(context).read,
              vMessageLocalization: VMessageLocalization.fromEnglish(),
            ),
            appNavigationType: AppNavigationType.messages,
          );
        },
        //this happens when user click on see message information to know when the message send or delivered or seen at for `broadcast` chat
        toBroadcastChatMessageInfo: (context, baseMessage) {
          AppNavigation.toPage(
            context,
            VMessageBroadcastStatusPage(
              message: baseMessage,
              deliveredLabel: S.of(context).delivered,
              readLabel: S.of(context).read,
              messageInfoLabel: S.of(context).messageInfo,
              vMessageLocalization: VMessageLocalization.fromEnglish(),
            ),
            appNavigationType: AppNavigationType.messages,
          );
        },
        //this happens when user click on see message information to know when the message send or delivered or seen at for `group` chat
        toGroupChatMessageInfo: (context, baseMessage) {
          AppNavigation.toPage(
            context,
            VMessageGroupStatusPage(
              message: baseMessage,
              deliveredLabel: S.of(context).delivered,
              readLabel: S.of(context).read,
              messageInfoLabel: S.of(context).messageInfo,
              vMessageLocalization: VMessageLocalization.fromEnglish(),
            ),
            appNavigationType: AppNavigationType.messages,
          );
        },
        //when user click on group title or icon to open group information to know more about this group like group members and more data
        toGroupSettings: (context, data) async {
          return await AppNavigation.toPage(
            context,
            GroupRoomSettingsView(settingsModel: data),
            appNavigationType: AppNavigationType.chatInfo,
            isRemoveAllWide: true,
          );
        },
        //when user click on peer user in direct chat title or icon to open peer chat user page you should handle this out of v chat scope
        toSingleSettings: (context, data, identifier) async {
          // Check if this is the AI Assistant room - prevent profile access
          if (data.roomId == "ai_assistant_room" ||
              identifier == "ai_assistant_peer") {
            // Do nothing - disable profile access for AI Assistant
            return null;
          }

          return await AppNavigation.toPage(
            context,
            SingleRoomSettingsView(settingsModel: data),
            appNavigationType: AppNavigationType.chatInfo,
            isRemoveAllWide: true,
          );
        },
        //when user click `broadcast` chat title or icon to open broadcast chat page you should handle this out of v chat scope
        toBroadcastSettings: (context, data) async {
          return await AppNavigation.toPage(
            context,
            BroadcastRoomSettingsView(settingsModel: data),
            appNavigationType: AppNavigationType.chatInfo,
            isRemoveAllWide: true,
          );
        },
        //when user click on group mention so need to open peer profile you should handle this out of v chat scope
        toUserProfilePage: (context, identifier) {
          return AppNavigation.toPage(
            context,
            PeerProfileView(peerId: identifier),
            appNavigationType: AppNavigationType.chatRoom,
          );
        },
      ),
    ),
  );

  // Ensure RoomsTabController is available globally for chat list refresh hooks
  if (!GetIt.I.isRegistered<RoomsTabController>()) {
    GetIt.I.registerLazySingleton<RoomsTabController>(
      () => RoomsTabController(),
    );
  }
}
