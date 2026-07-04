// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:get_it/get_it.dart';
import 'package:s_translation/generated/l10n.dart';
import 'app/core/localization/yo_fallback_localizations.dart';
import 'app/core/localization/zu_fallback_localizations.dart';

import 'package:super_up/app/modules/splash/views/splash_view.dart';
import 'package:super_up/app/core/auth0/auth0_service.dart';
import 'package:super_up/app/modules/live_stream/views/live_stream_view.dart';
import 'package:super_up/app/modules/live_stream/controllers/watch_live_controller.dart';
import 'package:super_up/app/widgets/gift_message_widget.dart';
import 'package:super_up/app/widgets/story_reply_message_widget.dart';
import 'package:super_up/app/widgets/story_like_message_widget.dart';
import 'package:super_up/app/widgets/sticker_message_widget.dart';
import 'package:super_up/app/widgets/poll_message_widget.dart';
import 'package:super_up/app/widgets/time_lock_message_widget.dart';
import 'package:super_up/app/widgets/marketplace_offer_message_widget.dart';
import 'package:super_up/app/widgets/music_share_message_widget.dart';
import 'package:super_up/app/widgets/job_share_message_widget.dart';
import 'package:super_up/app/widgets/profile_share_message_widget.dart';
import 'package:super_up/app/widgets/story_share_message_widget.dart';
import 'package:super_up/app/widgets/post_share_message_widget.dart';
import 'package:super_up/app/widgets/ticket_share_message_widget.dart';
import 'package:super_up/v_chat_v2/v_chat_config.dart';
import 'package:super_up_core/super_up_core.dart';
// Notification handler is now in v_chat_firebase_fcm package
import 'package:url_strategy/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:v_chat_firebase_fcm/v_chat_firebase_fcm.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:platform_local_notifications/platform_local_notifications.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';
import 'package:v_chat_room_page/v_chat_room_page.dart';
import 'package:v_chat_receive_share/v_chat_receive_share.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:window_manager/window_manager.dart';
import 'package:super_up/firebase_options.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app/core/utils/lazy_injection.dart';
import 'app/core/services/live_location_service.dart';
import 'app/core/widgets/main_builder.dart';
import 'app/core/services/deep_link_service.dart';
import 'app/core/services/balance_service.dart';
import 'app/modules/home/mobile/rooms_tab/controllers/rooms_tab_controller.dart';
import 'app/core/services/claimed_gifts_service.dart';
import 'app/core/services/in_app_purchase_service.dart';
import 'app/core/services/subscription_manager.dart';
import 'app/core/services/ai_message_handler.dart';
import 'app/core/services/story_status_service.dart';
import 'app/core/services/call_background_service.dart';
import 'app/core/services/audio_session_service.dart';
import 'app/core/services/custom_emoji_loader.dart';
import 'app/core/app_config/app_config_controller.dart';
import 'app/core/services/ride_socket_service.dart';
import 'package:super_up/app/modules/auth/verify_email/views/verify_email_page.dart';
import 'package:super_up/app/modules/auth/register/views/register_view.dart';
import 'package:super_up/app/modules/music/views/music_home_view.dart';
import 'package:super_up/app/modules/story/media_story/create_media_story.dart';
import 'package:v_chat_media_editor/v_chat_media_editor.dart';

// TOP-LEVEL BACKGROUND HANDLER - MUST BE HERE IN MAIN.DART
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse details) async {
  print('🚨🚨🚨 NOTIFICATION BACKGROUND HANDLER TRIGGERED! 🚨🚨🚨');
  print('ActionId: ${details.actionId}');
  print('Input: ${details.input}');
  print('Payload: ${details.payload}');

  if (details.actionId == "2" &&
      details.input != null &&
      details.input!.isNotEmpty) {
    try {
      String roomId = "";
      String token = "";
      String baseUrl = SConstants.sApiBaseUrl.toString();
      final payload = details.payload ?? "";

      try {
        if (payload.trim().startsWith('{')) {
          final payloadData = jsonDecode(payload);
          roomId = payloadData['roomId'] ?? "";
          token = payloadData['token'] ?? "";
          baseUrl = payloadData['baseUrl'] ?? baseUrl;
        } else {
          roomId = payload;
        }
      } catch (e) {
        roomId = payload;
      }

      if (token.isEmpty) {
        await VAppPref.init();
        token =
            VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name) ?? "";
        final prefBaseUrl = await VAppPref.getStringOrNullKey("vBaseUrl");
        if (prefBaseUrl != null && prefBaseUrl.isNotEmpty) {
          baseUrl = prefBaseUrl;
        }
      }

      if (roomId.isNotEmpty && token.isNotEmpty) {
        print('📤 SENDING REPLY FROM BACKGROUND HANDLER');
        print('RoomId: $roomId');
        print('Message: ${details.input}');
        print('BaseUrl: $baseUrl');

        final uri =
            Uri.parse("$baseUrl/channel/$roomId/message/notification-reply");
        print('Endpoint: $uri');

        final response = await http
            .post(
              uri,
              headers: {
                'authorization': 'Bearer $token',
                'content-type': 'application/json',
                'clint-version': '2.0.0',
                'Accept-Language': 'en',
              },
              body: jsonEncode({
                'content': details.input!.trim(),
                'roomId': roomId,
                'localId': 'notif_${DateTime.now().millisecondsSinceEpoch}',
                'platform': 'android',
              }),
            )
            .timeout(const Duration(seconds: 10));

        print('✅✅✅ REPLY SENT! Status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          try {
            final readUri = Uri.parse("$baseUrl/channel/$roomId/read");
            final readResponse = await http.patch(
              readUri,
              headers: {
                'authorization': 'Bearer $token',
                'clint-version': '2.0.0',
                'Accept-Language': 'en',
              },
            ).timeout(const Duration(seconds: 10));

            if (readResponse.statusCode == 200) {
              try {
                final nativeLocal = VLocalNativeApi();
                await nativeLocal.init();
                await nativeLocal.room.updateRoomUnreadToZero(roomId);
              } catch (e) {}
              try {
                await FlutterLocalNotificationsPlugin().cancelAll();
              } catch (e) {}
            }
          } catch (e) {
            print('❌ Error marking as read after reply: $e');
          }
        }
      } else {
        print('❌ Missing roomId or token - Cannot send reply');
      }
    } catch (e) {
      print('❌ Error sending reply from background: $e');
    }
  } else if (details.actionId == "1") {
    print('👁️ Mark as read action triggered');
    try {
      String roomId = "";
      String token = "";
      String baseUrl = SConstants.sApiBaseUrl.toString();
      final payload = details.payload ?? "";

      try {
        if (payload.trim().startsWith('{')) {
          final payloadData = jsonDecode(payload);
          roomId = payloadData['roomId'] ?? "";
          token = payloadData['token'] ?? "";
          baseUrl = payloadData['baseUrl'] ?? baseUrl;
        } else {
          roomId = payload;
        }
      } catch (e) {
        roomId = payload;
      }

      if (token.isEmpty) {
        await VAppPref.init();
        token =
            VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name) ?? "";
        final prefBaseUrl = await VAppPref.getStringOrNullKey("vBaseUrl");
        if (prefBaseUrl != null && prefBaseUrl.isNotEmpty) {
          baseUrl = prefBaseUrl;
        }
      }

      if (roomId.isNotEmpty && token.isNotEmpty) {
        print('📤 MARKING AS READ FROM BACKGROUND HANDLER');
        print('RoomId: $roomId');
        print('BaseUrl: $baseUrl');

        final uri = Uri.parse("$baseUrl/channel/$roomId/read");
        print('Endpoint: $uri');

        final response = await http.patch(
          uri,
          headers: {
            'authorization': 'Bearer $token',
            'clint-version': '2.0.0',
            'Accept-Language': 'en',
          },
        ).timeout(const Duration(seconds: 10));

        print('✅✅✅ MARKED AS READ! Status: ${response.statusCode}');

        // Clear notifications after successful mark read
        if (response.statusCode == 200) {
          // Update local DB unread count - the UI will refresh on resume via consumePendingMarkReadRoom
          try {
            final nativeLocal = VLocalNativeApi();
            await nativeLocal.init();
            await nativeLocal.room.updateRoomUnreadToZero(roomId);
            print('✅ Local unread count set to zero');
            try {
              final r =
                  await nativeLocal.room.getOneWithLastMessageByRoomId(roomId);
              print(
                  '🔍 Background local room after update: roomId=$roomId unReadCount=${r?.unReadCount}');
            } catch (e) {
              print('❌ Background debug read room error: $e');
            }
          } catch (e) {
            print('❌ Error updating local unread count: $e');
          }
          try {
            await FlutterLocalNotificationsPlugin().cancelAll();
            print('✅ Notifications cleared');
          } catch (e) {
            print('❌ Error clearing notifications: $e');
          }
        }
      } else {
        print('❌ Missing roomId or token - Cannot mark as read');
      }
    } catch (e) {
      print('❌ Error marking as read from background: $e');
    }
  }
}

Future<void> consumePendingMarkReadRoom() async {
  print('🔍 consumePendingMarkReadRoom called');
  try {
    // Safety check: ensure VChatController is initialized before proceeding
    try {
      final _ = VChatController.I.nativeApi;
    } catch (e) {
      print('⚠️ VChatController not initialized yet, skipping room refresh');
      return;
    }

    // SharedPreferences doesn't share across isolates on Android
    // Instead, just refresh rooms from local DB - the background handler already updated unread to 0
    if (GetIt.I.isRegistered<RoomsTabController>()) {
      final roomsTabController = GetIt.I.get<RoomsTabController>();
      await roomsTabController.vRoomController.refreshFromLocal();
      print('✅ Rooms refreshed from local DB after mark-read action');
      try {
        final rooms = roomsTabController.vRoomController.rooms;
        final withUnread = rooms.where((e) => e.unReadCount > 0).toList();
        print(
            '🔍 RoomsTabController rooms count=${rooms.length} unreadRooms=${withUnread.length}');
        if (rooms.isNotEmpty) {
          final r = rooms.firstWhere(
            (e) => e.unReadCount > 0,
            orElse: () => rooms.first,
          );
          print(
              '🔍 Sample room after refresh: roomId=${r.id} unReadCount=${r.unReadCount} lastMsg="${r.lastMessage.realContent}"');
        }
      } catch (e) {
        print('❌ RoomsTabController debug state read error: $e');
      }
    } else {
      print('⚠️ RoomsTabController not registered yet');
    }
  } catch (e) {
    print('❌ consumePendingMarkReadRoom error: $e');
  }
}

final GetIt getIt = GetIt.instance;
GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _initWebNotifications() async {
  try {
    // Request web notification permissions via Firebase Messaging
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print(
        'Web notification permission status: ${settings.authorizationStatus}');

    // Foreground message handler: show a simple in-app banner
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'Notification';
      final body = message.notification?.body ?? '';
      VAppAlert.showSuccessSnackBarWithoutContext(
        message: body.isNotEmpty ? '$title: $body' : title,
        duration: const Duration(seconds: 5),
      );
    });
  } catch (e) {
    print('Error initializing web notifications: $e');
  }
}

Future<void> _initReceiveShareHandlerWithStory() async {
  bool isAuthenticated = false;
  try {
    AppAuth.myProfile;
    isAuthenticated = true;
  } catch (_) {
    isAuthenticated = false;
  }

  if (!isAuthenticated) return;

  try {
    print('Initializing receive share handler...');
    vRegisterPostToStoryCallback(
      (context, files) async {
        if (files.isEmpty) return;
        final file = files.first;
        final lowerName = file.name.toLowerCase();
        final isVideo = lowerName.endsWith('.mp4') ||
            lowerName.endsWith('.mov') ||
            lowerName.endsWith('.avi') ||
            lowerName.endsWith('.mkv');

        final VBaseMediaRes mediaRes = isVideo
            ? VMediaVideoRes(
                data: MessageVideoData(
                  fileSource: file,
                  thumbImage: null,
                  duration: null,
                ),
              )
            : VMediaImageRes(
                data: MessageImageData(
                  fileSource: file,
                  width: 0,
                  height: 0,
                  blurHash: null,
                ),
              );

        await Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => CreateMediaStory(media: mediaRes),
          ),
        );
      },
      navigatorFactory: (onPostToStory) =>
          vBuildRoomNavigator(onPostToStory: onPostToStory),
    );
    vInitReceiveShareHandler();
    print('✅ Receive share handler initialized');
  } catch (e) {
    print('⚠️ Error initializing receive share handler: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On iOS, defer heavy initialization to allow VM Service to attach
  if (VPlatforms.isIOS) {
    print('🚀 iOS detected - using minimal startup sequence');
    await _runMinimalStartup();
    return;
  }

  // Non-iOS: proceed with normal startup
  await _runFullStartup();
}

Future<void> _runMinimalStartup() async {
  print('⏱️  iOS Minimal startup: no platform channels before runApp...');

  print('✅ Minimal startup complete. Running app...');

  runApp(
    VUtilsWrapper(
      builder: (_, local, themeMode) {
        final brightness = _getIosBrightness(themeMode);
        final isDark = brightness == Brightness.dark;
        return CupertinoApp(
          navigatorKey: navigatorKey,
          title: SConstants.appName,
          locale: local,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            S.delegate,
            YoCupertinoFallbackDelegate(),
            YoMaterialFallbackDelegate(),
            YoWidgetsFallbackDelegate(),
            ZuCupertinoFallbackDelegate(),
            ZuMaterialFallbackDelegate(),
            ZuWidgetsFallbackDelegate(),
            ExtraCupertinoFallbackDelegate(),
            ExtraMaterialFallbackDelegate(),
            ExtraWidgetsFallbackDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          builder: (context, child) {
            final themeData =
                (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
              extensions: [
                (isDark ? VMessageTheme.dark() : VMessageTheme.light())
                    .copyWith(
                  senderBubbleColor: isDark
                      ? const Color(0xff005046)
                      : const Color(0xffE2FFD4),
                  receiverBubbleColor: isDark
                      ? const Color(0xff1f2c34)
                      : const Color(0xffFFFFFF),
                  senderTextStyle: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16.5,
                  ),
                  receiverTextStyle: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16.5,
                  ),
                  customMessageItem: (context, isMeSender, data) {
                    Map<String, dynamic> offerData = data;
                    if (data['type'] != 'marketplace_offer' &&
                        data['data'] is Map &&
                        (data['data'] as Map)['type'] == 'marketplace_offer') {
                      offerData = {
                        ...Map<String, dynamic>.from(data['data'] as Map),
                        ...data,
                      };
                    }
                    if (offerData['type'] == 'marketplace_offer') {
                      return MarketplaceOfferMessageWidget(
                        isMeSender: isMeSender,
                        data: offerData,
                      );
                    }
                    if (data['type'] == 'time_lock') {
                      return TimeLockMessageWidget(
                        isMeSender: isMeSender,
                        data: data,
                      );
                    }

                    if (data['type'] == 'poll') {
                      return PollMessageWidget(
                        isMeSender: isMeSender,
                        data: data,
                      );
                    }

                    if (data['type'] == 'gift') {
                      return GiftMessageWidget(
                        isMeSender: isMeSender,
                        data: data,
                      );
                    }

                    if (data['type'] == 'sticker') {
                      return StickerMessageWidget(
                        isMeSender: isMeSender,
                        data: data,
                      );
                    }

                    if (data['type'] == 'story_reply') {
                      return StoryReplyMessageWidget(
                        isMeSender: isMeSender,
                        data: data,
                      );
                    }

                    if (data['type'] == 'story_like') {
                      return StoryLikeMessageWidget(
                        isMeSender: isMeSender,
                        data: data,
                      );
                    }

                    if (data['type'] == 'music_share') {
                      return MusicShareMessageWidget(
                        isMeSender: isMeSender,
                        data: data,
                      );
                    }

                    if (data['type'] == 'job_share') {
                      return JobShareMessageWidget(
                        isMeSender: isMeSender,
                        data: data,
                      );
                    }

                    if (data['type'] == 'profile_share') {
                      return ProfileShareMessageWidget(
                        isMeSender: isMeSender,
                        data: data,
                      );
                    }

                    if (data['type'] == 'story_share') {
                      return StoryShareMessageWidget(
                        isMeSender: isMeSender,
                        data: data,
                      );
                    }

                    if (data['type'] == 'post_share') {
                      return PostShareMessageWidget(
                        isMeSender: isMeSender,
                        data: data,
                      );
                    }

                    if (data['type'] == 'ticket_share') {
                      return TicketShareMessageWidget(
                        isMeSender: isMeSender,
                        data: data,
                      );
                    }

                    Map<String, dynamic> stickerData = data;
                    if (data.containsKey('data') && data['data'] is Map) {
                      stickerData = data['data'] as Map<String, dynamic>;
                    }

                    if (stickerData['type'] == 'job_share') {
                      return JobShareMessageWidget(
                        isMeSender: isMeSender,
                        data: stickerData,
                      );
                    }

                    if (stickerData['type'] == 'profile_share') {
                      return ProfileShareMessageWidget(
                        isMeSender: isMeSender,
                        data: stickerData,
                      );
                    }

                    if (stickerData['type'] == 'story_share') {
                      return StoryShareMessageWidget(
                        isMeSender: isMeSender,
                        data: stickerData,
                      );
                    }

                    if (stickerData['type'] == 'post_share') {
                      return PostShareMessageWidget(
                        isMeSender: isMeSender,
                        data: stickerData,
                      );
                    }

                    if (stickerData['type'] == 'ticket_share') {
                      return TicketShareMessageWidget(
                        isMeSender: isMeSender,
                        data: stickerData,
                      );
                    }

                    if (stickerData['type'] == 'sticker') {
                      return StickerMessageWidget(
                        isMeSender: isMeSender,
                        data: stickerData,
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
                (isDark ? VRoomTheme.dark() : VRoomTheme.light()).copyWith(),
              ],
            );
            return Theme(
              data: themeData,
              child: Material(
                child: MainBuilder(
                  themeMode: themeMode,
                  child: child,
                ),
              ),
            );
          },
          home: const _IosBootstrapView(),
          theme: CupertinoThemeData(
            brightness: brightness,
            primaryColor: const Color(0xFFB48648),
            scaffoldBackgroundColor:
                isDark ? Colors.black : const Color(0xFFc9cfc8),
            barBackgroundColor: isDark ? Colors.black : const Color(0xFFc9cfc8),
          ),
        );
      },
    ),
  );
}

class _IosBootstrapView extends StatefulWidget {
  const _IosBootstrapView();

  @override
  State<_IosBootstrapView> createState() => _IosBootstrapViewState();
}

class _IosBootstrapViewState extends State<_IosBootstrapView> {
  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    try {
      await _initializeHeavyServices();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const SplashView()),
        );
      }
    } catch (e) {
      print('❌ iOS bootstrap error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return CupertinoPageScaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFc9cfc8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/logo.png",
              height: 100,
              width: 100,
            ),
            const SizedBox(height: 20),
            SConstants.appName.h6,
            const SizedBox(height: 24),
            const CupertinoActivityIndicator(radius: 16),
          ],
        ),
      ),
    );
  }
}

Future<void> _runFullStartup() async {
  // Full startup for non-iOS platforms
  print('🚀 Full startup: initializing all services...');

  // Initialize app preferences as early as possible
  await VAppPref.init();

  // Ensure Google Maps uses the latest renderer on Android
  if (VPlatforms.isAndroid) {
    final GoogleMapsFlutterPlatform mapsPlatform =
        GoogleMapsFlutterPlatform.instance;
    if (mapsPlatform is GoogleMapsFlutterAndroid) {
      try {
        mapsPlatform.useAndroidViewSurface = true;
        final used = await mapsPlatform
            .initializeWithRenderer(AndroidMapRenderer.latest);
        debugPrint('Google Maps Android renderer initialized: ${used?.name}');
      } catch (e) {
        debugPrint('Google Maps renderer init failed: $e');
      }
    }
  }

  // Initialize notifications using the shared PlatformNotifier (single instance)
  if (VPlatforms.isAndroid) {
    print('🔔 Initializing PlatformNotifier notifications...');
    try {
      PlatformNotifier.setBackgroundHandler(notificationBackgroundHandler);
      await PlatformNotifier.I
          .init(appName: SConstants.appName)
          .timeout(const Duration(seconds: 3));
      unawaited(() async {
        try {
          await PlatformNotifier.I
              .requestPermissions()
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          print('PlatformNotifier.requestPermissions error: $e');
        }
      }());
      print('✅ PlatformNotifier notifications initialized');
    } catch (e) {
      print('⚠️ PlatformNotifier init skipped/timed out: $e');
    }
  }

  // Initialize Auth0
  AppAuth0Service.I.initialize();

  if (VPlatforms.isDeskTop) {
    await _setDesktopWindow();
  }

  if (VPlatforms.isWeb) {
    setPathUrlStrategy();
  }

  try {
    registerSingletons();
  } catch (e) {
    print('ERROR during registerSingletons: $e');
  }

  try {
    await GetIt.I.get<VAppConfigController>().refreshAppConfig();
  } catch (e) {
    print('Failed to refresh app config at startup: $e');
  }

  // Initialize Firebase
  if (VPlatforms.isMobile || VPlatforms.isMacOs || VPlatforms.isWeb) {
    try {
      print('Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized');
    } catch (e) {
      print('⚠️ Firebase initialization error: $e');
    }
  }

  if (VPlatforms.isWeb) {
    await _initWebNotifications();
  }

  // Register FCM background message handler
  if (VPlatforms.isMobile) {
    print('DEBUG: Registering FCM background message handler');
    FirebaseMessaging.onBackgroundMessage(vFirebaseMessagingBackgroundHandler);
    print('DEBUG: FCM background handler registered successfully');
  }

  try {
    print('Loading custom emojis...');
    await CustomEmojiLoader.loadOrbitEmojis();
    print('✅ Custom emojis loaded');
  } catch (e) {
    print('⚠️ Error loading custom emojis: $e');
  }

  try {
    print('Initializing VChat...');
    await initVChat(navigatorKey);
    print('✅ VChat initialized');
  } catch (e) {
    print('❌ VChat initialization failed: $e');
  }

  // Ensure VNotificationListener is initialized so that notification
  // click / reply / mark-read events from PlatformNotifier are handled
  // and can navigate directly to the appropriate chat room.
  try {
    print('Initializing VNotificationListener...');
    await VNotificationListener.init();
    print('✅ VNotificationListener initialized');
  } catch (e) {
    print('⚠️ Error initializing VNotificationListener: $e');
  }

  // Initialize LiveLocationService for real-time location sharing
  try {
    print('Initializing LiveLocationService...');
    LiveLocationService.instance.listenForUpdates();
    print('✅ LiveLocationService initialized');
  } catch (e) {
    print('⚠️ Error initializing LiveLocationService: $e');
  }

  try {
    print('Initializing ride socket service...');
    RideSocketService.instance.init();
    print('✅ Ride socket service initialized');
  } catch (e) {
    print('⚠️ Error initializing ride socket service: $e');
  }

  await _initReceiveShareHandlerWithStory();

  if (VPlatforms.isAndroid) {
    try {
      print('Initializing CallKit (Android)...');
      _initCallKit();
      print('✅ CallKit initialized (Android)');
    } catch (e) {
      print('⚠️ Error initializing CallKit: $e');
    }
  }

  try {
    print('Initializing deep link service...');
    await DeepLinkService().initialize();
    print('✅ Deep link service initialized');
  } catch (e) {
    print('⚠️ Error initializing deep link service: $e');
  }

  try {
    print('Initializing balance service...');
    await BalanceService.instance.init();
    print('✅ Balance service initialized');
  } catch (e) {
    print('⚠️ Error initializing balance service: $e');
  }

  try {
    print('Initializing claimed gifts service...');
    ClaimedGiftsService.instance.init();
    print('✅ Claimed gifts service initialized');
  } catch (e) {
    print('⚠️ Error initializing claimed gifts service: $e');
  }

  if (!VPlatforms.isWeb) {
    try {
      print('Initializing subscription manager...');
      await SubscriptionManager().initialize();
      print('✅ Subscription manager initialized');
    } catch (e) {
      print('⚠️ Error initializing subscription manager: $e');
    }

    try {
      print('Initializing in-app purchase service...');
      await InAppPurchaseService().initialize();
      print('✅ In-app purchase service initialized');
    } catch (e) {
      print('⚠️ Error initializing in-app purchase service: $e');
    }
  }

  try {
    print('Initializing AI message handler...');
    AiMessageHandler().initialize();
    print('✅ AI message handler initialized');
  } catch (e) {
    print('⚠️ Error initializing AI message handler: $e');
  }

  try {
    print('Initializing story status service...');
    StoryStatusService().initialize();
    print('✅ Story status service initialized');
  } catch (e) {
    print('⚠️ Error initializing story status service: $e');
  }

  try {
    print('Initializing call background service...');
    await CallBackgroundService.instance.init();
    print('✅ Call background service initialized');
  } catch (e) {
    print('⚠️ Error initializing call background service: $e');
  }

  try {
    print('Initializing audio session for background playback...');
    await AudioSessionService.instance.init();
    print('✅ Audio session initialized');
  } catch (e) {
    print('⚠️ Error initializing audio session: $e');
  }

  try {
    print('Initializing FCM token refresh...');
    _initFcmTokenRefresh();
    print('✅ FCM token refresh initialized');
  } catch (e) {
    print('⚠️ Error initializing FCM token refresh: $e');
  }

  try {
    print('Initializing live stream notification handler...');
    _initLiveStreamNotificationHandler();
    print('✅ Live stream notification handler initialized');
  } catch (e) {
    print('⚠️ Error initializing live stream notification handler: $e');
  }

  try {
    print('Initializing music upload notification navigation...');
    _initMusicUploadNotificationNavigation();
    print('✅ Music upload notification navigation initialized');
  } catch (e) {
    print('⚠️ Error initializing music upload notification navigation: $e');
  }

  try {
    print('Initializing support credit notification handler...');
    _initSupportNotificationHandler();
    print('✅ Support credit notification handler initialized');
  } catch (e) {
    print('⚠️ Error initializing support credit notification handler: $e');
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (VPlatforms.isMobile) {
      try {
        print('Requesting notification permissions (post-frame)...');
        _requestNotificationPermissions();
        print('✅ Notification permissions requested (post-frame)');
      } catch (e) {
        print('⚠️ Error requesting notification permissions: $e');
      }
      try {
        print('Checking notification permissions status (post-frame)...');
        _checkNotificationPermissionsStatus();
        print('✅ Notification permissions status checked (post-frame)');
      } catch (e) {
        print('⚠️ Error checking notification permissions status: $e');
      }
    }
  });

  if (VPlatforms.isIOS) {
    runApp(
      CupertinoApp(
        navigatorKey: navigatorKey,
        title: SConstants.appName,
        localizationsDelegates: const [
          S.delegate,
          YoCupertinoFallbackDelegate(),
          YoMaterialFallbackDelegate(),
          YoWidgetsFallbackDelegate(),
          ZuCupertinoFallbackDelegate(),
          ZuMaterialFallbackDelegate(),
          ZuWidgetsFallbackDelegate(),
          ExtraCupertinoFallbackDelegate(),
          ExtraMaterialFallbackDelegate(),
          ExtraWidgetsFallbackDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        builder: (context, child) => Material(
          child: MainBuilder(
            themeMode: ThemeMode.light,
            child: child,
          ),
        ),
        home: const RegisterView(),
        debugShowCheckedModeBanner: false,
      ),
    );
    return;
  }
  // Fallback (non-iOS) retains full app wrappers
  runApp(
    VUtilsWrapper(
      builder: (_, local, theme) {
        return OKToast(
          position: ToastPosition.bottom,
          child: Theme(
            data: _getIosBrightness(theme) == Brightness.dark
                ? ThemeData.dark().copyWith(
                    extensions: [
                      VMessageTheme.dark().copyWith(
                        senderBubbleColor: const Color(0xff005046),
                        receiverBubbleColor: const Color(0xff363638),
                        senderTextStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                        ),
                        receiverTextStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                        ),
                        customMessageItem: (context, isMeSender, data) {
                          print('=== HANDLER 1 CALLED ===');
                          print('Custom message data: $data');
                          print('Data type: ${data.runtimeType}');
                          print('Data keys: ${data.keys.toList()}');

                          Map<String, dynamic> offerData = data;
                          if (data['type'] != 'marketplace_offer' &&
                              data['data'] is Map &&
                              (data['data'] as Map)['type'] ==
                                  'marketplace_offer') {
                            offerData = {
                              ...Map<String, dynamic>.from(data['data'] as Map),
                              ...data,
                            };
                          }

                          if (offerData['type'] == 'marketplace_offer') {
                            return MarketplaceOfferMessageWidget(
                              isMeSender: isMeSender,
                              data: offerData,
                            );
                          }

                          if (data['type'] == 'time_lock') {
                            return TimeLockMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'poll') {
                            return PollMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'gift') {
                            return GiftMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'sticker') {
                            print('DIRECT STICKER CHECK PASSED - HANDLER 1');
                            return StickerMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'story_reply') {
                            return StoryReplyMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'story_like') {
                            return StoryLikeMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'music_share') {
                            return MusicShareMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'job_share') {
                            return JobShareMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'profile_share') {
                            return ProfileShareMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'story_share') {
                            return StoryShareMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'post_share') {
                            return PostShareMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'ticket_share') {
                            return TicketShareMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          Map<String, dynamic> stickerData = data;
                          if (data.containsKey('data') && data['data'] is Map) {
                            stickerData = data['data'] as Map<String, dynamic>;
                          }

                          if (stickerData['type'] == 'job_share') {
                            return JobShareMessageWidget(
                              isMeSender: isMeSender,
                              data: stickerData,
                            );
                          }

                          if (stickerData['type'] == 'profile_share') {
                            return ProfileShareMessageWidget(
                              isMeSender: isMeSender,
                              data: stickerData,
                            );
                          }

                          if (stickerData['type'] == 'story_share') {
                            return StoryShareMessageWidget(
                              isMeSender: isMeSender,
                              data: stickerData,
                            );
                          }

                          if (stickerData['type'] == 'post_share') {
                            return PostShareMessageWidget(
                              isMeSender: isMeSender,
                              data: stickerData,
                            );
                          }

                          if (stickerData['type'] == 'ticket_share') {
                            return TicketShareMessageWidget(
                              isMeSender: isMeSender,
                              data: stickerData,
                            );
                          }

                          if (stickerData['type'] == 'sticker') {
                            return StickerMessageWidget(
                              isMeSender: isMeSender,
                              data: stickerData,
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                      VRoomTheme.dark().copyWith(
                          //see options here
                          ),
                    ],
                  )
                : ThemeData.light().copyWith(
                    extensions: [
                      VMessageTheme.light().copyWith(
                        senderBubbleColor: const Color(0xffE2FFD4),
                        receiverBubbleColor: const Color(0xffFFFFFF),
                        senderTextStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 16.5,
                        ),
                        receiverTextStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 16.5,
                        ),
                        customMessageItem: (context, isMeSender, data) {
                          print('=== HANDLER 2 CALLED ===');
                          print('Custom message data: $data');
                          print('Data type: ${data.runtimeType}');
                          print('Data keys: ${data.keys.toList()}');

                          Map<String, dynamic> offerData = data;
                          if (data['type'] != 'marketplace_offer' &&
                              data['data'] is Map &&
                              (data['data'] as Map)['type'] ==
                                  'marketplace_offer') {
                            offerData = {
                              ...Map<String, dynamic>.from(data['data'] as Map),
                              ...data,
                            };
                          }

                          if (offerData['type'] == 'marketplace_offer') {
                            return MarketplaceOfferMessageWidget(
                              isMeSender: isMeSender,
                              data: offerData,
                            );
                          }

                          if (data['type'] == 'time_lock') {
                            return TimeLockMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'poll') {
                            return PollMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'gift') {
                            return GiftMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'sticker') {
                            print('DIRECT STICKER CHECK PASSED - HANDLER 2');
                            return StickerMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'story_reply') {
                            return StoryReplyMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'story_like') {
                            return StoryLikeMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'music_share') {
                            return MusicShareMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'job_share') {
                            return JobShareMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'profile_share') {
                            return ProfileShareMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'story_share') {
                            return StoryShareMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'post_share') {
                            return PostShareMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          if (data['type'] == 'ticket_share') {
                            return TicketShareMessageWidget(
                              isMeSender: isMeSender,
                              data: data,
                            );
                          }

                          Map<String, dynamic> stickerData = data;
                          if (data.containsKey('data') && data['data'] is Map) {
                            stickerData = data['data'] as Map<String, dynamic>;
                          }

                          if (stickerData['type'] == 'job_share') {
                            return JobShareMessageWidget(
                              isMeSender: isMeSender,
                              data: stickerData,
                            );
                          }

                          if (stickerData['type'] == 'profile_share') {
                            return ProfileShareMessageWidget(
                              isMeSender: isMeSender,
                              data: stickerData,
                            );
                          }

                          if (stickerData['type'] == 'story_share') {
                            return StoryShareMessageWidget(
                              isMeSender: isMeSender,
                              data: stickerData,
                            );
                          }

                          if (stickerData['type'] == 'post_share') {
                            return PostShareMessageWidget(
                              isMeSender: isMeSender,
                              data: stickerData,
                            );
                          }

                          if (stickerData['type'] == 'ticket_share') {
                            return TicketShareMessageWidget(
                              isMeSender: isMeSender,
                              data: stickerData,
                            );
                          }

                          if (stickerData['type'] == 'sticker') {
                            return StickerMessageWidget(
                              isMeSender: isMeSender,
                              data: stickerData,
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                      VRoomTheme.light().copyWith(
                          //see options here
                          ),
                    ],
                  ),
            child: CupertinoApp(
              navigatorKey: navigatorKey,
              title: SConstants.appName,
              locale: local,
              supportedLocales: S.delegate.supportedLocales,
              localizationsDelegates: const [
                S.delegate,
                YoCupertinoFallbackDelegate(),
                YoMaterialFallbackDelegate(),
                YoWidgetsFallbackDelegate(),
                ZuCupertinoFallbackDelegate(),
                ZuMaterialFallbackDelegate(),
                ZuWidgetsFallbackDelegate(),
                ExtraCupertinoFallbackDelegate(),
                ExtraMaterialFallbackDelegate(),
                ExtraWidgetsFallbackDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => Material(
                child: MainBuilder(themeMode: theme, child: child),
              ),
              home: const SplashView(),
              debugShowCheckedModeBanner: false,
              onGenerateRoute: (settings) {
                if (settings.name == '/live-stream') {
                  final args = settings.arguments as Map<String, dynamic>?;
                  if (args != null && args['streamId'] != null) {
                    return _handleLiveStreamRoute(
                        args['streamId'], args['isStreamer'] ?? false);
                  }
                }
                if (VPlatforms.isWeb && settings.name == '/verify-email') {
                  final uri = Uri.base;
                  final token = uri.queryParameters['token'];
                  final email = uri.queryParameters['email'];
                  return CupertinoPageRoute(
                    builder: (_) => VerifyEmailPage(token: token, email: email),
                  );
                }
                if (VPlatforms.isWeb && settings.name == '/register') {
                  final uri = Uri.base;
                  final email = uri.queryParameters['email'];
                  return CupertinoPageRoute(
                    builder: (_) => RegisterView(initialEmail: email),
                  );
                }
                return null;
              },
              theme: CupertinoThemeData(
                brightness: _getIosBrightness(theme),
                applyThemeToAll: true,
                primaryColor: const Color(0xFFB48648),
                barBackgroundColor: _getIosBrightness(theme) == Brightness.dark
                    ? Colors.black
                    : const Color(0xFFc9cfc8),
                scaffoldBackgroundColor:
                    _getIosBrightness(theme) == Brightness.dark
                        ? Colors.black
                        : const Color(0xFFc9cfc8),
              ),
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _initializeHeavyServices() async {
  print('🔧 Initializing heavy services on iOS...');
  try {
    await VAppPref.init();
    print('✅ VAppPref initialized');

    await VLanguageListener.I.setLocal(VLanguageListener.I.appLocal);
    await VThemeListener.I.setTheme(VThemeListener.I.appTheme);
  } catch (e) {
    print('⚠️ VAppPref init failed: $e');
  }

  // Initialize Auth0 (moved from minimal startup)
  try {
    AppAuth0Service.I.initialize();
    print('✅ Auth0 initialized');
  } catch (e) {
    print('⚠️ Auth0 init failed: $e');
  }

  // Initialize deep links (moved from minimal startup)
  try {
    await DeepLinkService().initialize();
    print('✅ Deep link service initialized');
  } catch (e) {
    print('⚠️ Deep link init failed: $e');
  }

  try {
    registerSingletons();
  } catch (e) {
    print('ERROR during registerSingletons: $e');
  }

  try {
    await GetIt.I.get<VAppConfigController>().refreshAppConfig();
  } catch (e) {
    print('Failed to refresh app config: $e');
  }

  if (VPlatforms.isMobile || VPlatforms.isMacOs || VPlatforms.isWeb) {
    try {
      print('Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized');
    } catch (e) {
      print('⚠️ Firebase initialization error: $e');
    }
  }

  if (VPlatforms.isMobile) {
    print('DEBUG: Registering FCM background message handler');
    FirebaseMessaging.onBackgroundMessage(vFirebaseMessagingBackgroundHandler);
    print('DEBUG: FCM background handler registered successfully');
  }

  try {
    print('Loading custom emojis...');
    await CustomEmojiLoader.loadOrbitEmojis();
    print('✅ Custom emojis loaded');
  } catch (e) {
    print('⚠️ Error loading custom emojis: $e');
  }

  try {
    print('Initializing VChat...');
    await initVChat(navigatorKey);
    print('✅ VChat initialized');
  } catch (e) {
    print('❌ VChat initialization failed: $e');
  }

  try {
    print('Initializing ride socket service...');
    RideSocketService.instance.init();
    print('✅ Ride socket service initialized');
  } catch (e) {
    print('⚠️ Error initializing ride socket service: $e');
  }

  await _initReceiveShareHandlerWithStory();

  try {
    print('Initializing deep link service...');
    await DeepLinkService().initialize();
    print('✅ Deep link service initialized');
  } catch (e) {
    print('⚠️ Error initializing deep link service: $e');
  }

  try {
    print('Initializing balance service...');
    await BalanceService.instance.init();
    print('✅ Balance service initialized');
  } catch (e) {
    print('⚠️ Error initializing balance service: $e');
  }

  try {
    print('Initializing claimed gifts service...');
    ClaimedGiftsService.instance.init();
    print('✅ Claimed gifts service initialized');
  } catch (e) {
    print('⚠️ Error initializing claimed gifts service: $e');
  }

  try {
    print('Initializing subscription manager...');
    await SubscriptionManager().initialize();
    print('✅ Subscription manager initialized');
  } catch (e) {
    print('⚠️ Error initializing subscription manager: $e');
  }

  try {
    print('Initializing in-app purchase service...');
    await InAppPurchaseService().initialize();
    print('✅ In-app purchase service initialized');
  } catch (e) {
    print('⚠️ Error initializing in-app purchase service: $e');
  }

  try {
    print('Initializing AI message handler...');
    AiMessageHandler().initialize();
    print('✅ AI message handler initialized');
  } catch (e) {
    print('⚠️ Error initializing AI message handler: $e');
  }

  try {
    print('Initializing story status service...');
    StoryStatusService().initialize();
    print('✅ Story status service initialized');
  } catch (e) {
    print('⚠️ Error initializing story status service: $e');
  }

  try {
    print('Initializing call background service...');
    await CallBackgroundService.instance.init();
    print('✅ Call background service initialized');
  } catch (e) {
    print('⚠️ Error initializing call background service: $e');
  }

  try {
    print('Initializing audio session for background playback...');
    await AudioSessionService.instance.init();
    print('✅ Audio session initialized');
  } catch (e) {
    print('⚠️ Error initializing audio session: $e');
  }

  try {
    print('Initializing FCM token refresh...');
    _initFcmTokenRefresh();
    print('✅ FCM token refresh initialized');
  } catch (e) {
    print('⚠️ Error initializing FCM token refresh: $e');
  }

  try {
    print('Initializing live stream notification handler...');
    _initLiveStreamNotificationHandler();
    print('✅ Live stream notification handler initialized');
  } catch (e) {
    print('⚠️ Error initializing live stream notification handler: $e');
  }

  try {
    print('Initializing music upload notification navigation...');
    _initMusicUploadNotificationNavigation();
    print('✅ Music upload notification navigation initialized');
  } catch (e) {
    print('⚠️ Error initializing music upload notification navigation: $e');
  }

  try {
    print('Initializing support credit notification handler...');
    _initSupportNotificationHandler();
    print('✅ Support credit notification handler initialized');
  } catch (e) {
    print('⚠️ Error initializing support credit notification handler: $e');
  }

  try {
    print('Requesting notification permissions...');
    _requestNotificationPermissions();
    print('✅ Notification permissions requested');
  } catch (e) {
    print('⚠️ Error requesting notification permissions: $e');
  }

  try {
    print('Checking notification permissions status...');
    _checkNotificationPermissionsStatus();
    print('✅ Notification permissions status checked');
  } catch (e) {
    print('⚠️ Error checking notification permissions status: $e');
  }

  print('✅ All heavy services initialized on iOS');
}

Brightness _getIosBrightness(ThemeMode themeMode) {
  if (themeMode == ThemeMode.dark) {
    return Brightness.dark;
  }
  if (themeMode == ThemeMode.light) {
    return Brightness.light;
  }
  return Brightness.light;
}

Future<void> _setDesktopWindow() async {
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = WindowOptions(
    minimumSize: const Size(600, 1000),
    size: const Size(1500, 1000),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    title: SConstants.appName,
    titleBarStyle: VPlatforms.isWindows ? null : TitleBarStyle.hidden,
    fullScreen: false,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  // await autoUpdater.setFeedURL(SConstants.feedUrl);
  // await autoUpdater.setScheduledCheckInterval(3600 + 12);
}

void _initCallKit() async {
  CallKeepHandler.I.configureFlutterCallKeep(true);
}

/// Initialize FCM token refresh for existing users
void _initFcmTokenRefresh() {
  // Listen for FCM token refresh events
  VEventBusSingleton.vEventBus.on<VOnUpdateNotificationsToken>().listen((
    event,
  ) async {
    try {
      // Send the new token to the backend
      await VChatController.I.nativeApi.remote.profile.addPushKey(
        fcm: event.token,
        voipKey: null,
      );
      print(
        'FCM token refreshed and sent to backend: ${event.token.substring(0, 20)}...',
      );
    } catch (e) {
      print('Error sending refreshed FCM token to backend: $e');
    }
  });

  // Also refresh token immediately for existing users
  Future.delayed(const Duration(seconds: 2), () async {
    try {
      final pushService =
          await VChatController.I.vChatConfig.currentPushProviderService;
      if (pushService != null) {
        final token = await pushService.getToken(
          VPlatforms.isWeb ? SConstants.webVapidKey : null,
        );
        if (token != null) {
          await VChatController.I.nativeApi.remote.profile.addPushKey(
            fcm: token,
            voipKey: null,
          );
          print(
            'FCM token refreshed on app start: ${token.substring(0, 20)}...',
          );
        }
      }
    } catch (e) {
      print('Error refreshing FCM token on app start: $e');
    }
  });
}

bool _supportNotificationHandlerInitialized = false;

bool _isSupportCreditType(String? type) {
  final t = (type ?? '').toLowerCase();
  return t == 'music_support_received' ||
      t == 'article_support_received' ||
      t == 'support_received';
}

String _buildSupportFallbackMessage(Map<String, dynamic> data) {
  final sender = (data['senderName'] ?? '').toString().trim();
  final amount = (data['amountKes'] ?? data['amount'] ?? '').toString().trim();
  if (sender.isNotEmpty && amount.isNotEmpty) {
    return 'You received KES $amount from $sender';
  }
  if (amount.isNotEmpty) {
    return 'You received support of KES $amount';
  }
  return 'Support received';
}

Future<void> _handleSupportCreditNotification(
  RemoteMessage message, {
  bool showToast = true,
}) async {
  final type = message.data['type']?.toString();
  if (!_isSupportCreditType(type)) return;

  try {
    AppAuth.myProfile;
  } catch (_) {
    return;
  }

  try {
    await BalanceService.instance.init();
    print('✅ Balance refreshed from support notification');
  } catch (e) {
    print('⚠️ Failed to refresh balance from support notification: $e');
  }

  if (!showToast) return;
  final text = (message.notification?.body ?? '').trim().isNotEmpty
      ? (message.notification?.body ?? '').trim()
      : _buildSupportFallbackMessage(message.data);
  VAppAlert.showSuccessSnackBarWithoutContext(
    message: text,
    duration: const Duration(seconds: 4),
  );
}

void _initSupportNotificationHandler() {
  if (_supportNotificationHandlerInitialized) return;
  _supportNotificationHandlerInitialized = true;

  try {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _handleSupportCreditNotification(message);
    });
  } catch (e) {
    print('⚠️ Error listening to foreground support notifications: $e');
  }

  try {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await _handleSupportCreditNotification(message, showToast: false);
    });
  } catch (e) {
    print('⚠️ Error listening to opened-app support notifications: $e');
  }

  try {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final msg = await FirebaseMessaging.instance.getInitialMessage();
        if (msg == null) return;
        await _handleSupportCreditNotification(msg, showToast: false);
      } catch (e) {
        print('⚠️ Error handling initial support notification: $e');
      }
    });
  } catch (e) {
    print('⚠️ Error initializing initial support notification check: $e');
  }
}

void _initMusicUploadNotificationNavigation() {
  try {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final type = message.data['type']?.toString();
      if (type != 'music_upload') return;
      try {
        AppAuth.myProfile;
      } catch (_) {
        return;
      }
      navigatorKey.currentState?.push(
        CupertinoPageRoute(builder: (_) => const MusicHomeView()),
      );
    });
  } catch (e) {
    print('Error initializing music upload notification navigation: $e');
  }

  try {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final msg = await FirebaseMessaging.instance.getInitialMessage();
        if (msg == null) return;
        final type = msg.data['type']?.toString();
        if (type != 'music_upload') return;
        try {
          AppAuth.myProfile;
        } catch (_) {
          return;
        }
        navigatorKey.currentState?.push(
          CupertinoPageRoute(builder: (_) => const MusicHomeView()),
        );
      } catch (_) {}
    });
  } catch (_) {}
}

/// Initialize live stream notification handler
void _initLiveStreamNotificationHandler() {
  // Listen for non-VChat notifications (like live stream notifications)
  VEventBusSingleton.vEventBus.on<VOnNewNotifications>().listen((event) async {
    try {
      // Show a simple snackbar notification for live stream notifications
      // This ensures the notification is visible when the app is in foreground
      VAppAlert.showSuccessSnackBarWithoutContext(
        message: '${event.title}: ${event.body}',
        duration: const Duration(seconds: 5),
      );
      print(
        'Live stream notification displayed: ${event.title} - ${event.body}',
      );
    } catch (e) {
      print('Error displaying live stream notification: $e');
    }
  });
}

/// Request notification permissions for mobile platforms
void _requestNotificationPermissions() async {
  try {
    // Request notification permission using permission_handler
    final notificationPermission = await Permission.notification.request();
    print('Mobile notification permission status: $notificationPermission');

    // Request FCM permissions
    final pushService =
        await VChatController.I.vChatConfig.currentPushProviderService;
    if (pushService != null) {
      await pushService.askForPermissions();
      print('Mobile FCM permissions requested');
    }

    // Also request local notification permissions using flutter_local_notifications
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    if (VPlatforms.isIOS) {
      final iosImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      if (iosImplementation != null) {
        final localPermissionResult =
            await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: true,
        );
        print(
            'iOS local notification permission result: $localPermissionResult');
      }
    } else if (VPlatforms.isAndroid) {
      final androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final localPermissionResult =
            await androidImplementation.requestNotificationsPermission();
        print(
            'Android local notification permission result: $localPermissionResult');
      }
    }
  } catch (e) {
    print('Error requesting notification permissions: $e');
  }
}

/// Check notification permissions status for debugging
void _checkNotificationPermissionsStatus() async {
  try {
    // Check permission_handler status
    final notificationStatus = await Permission.notification.status;
    print('iOS notification permission status: $notificationStatus');

    // Check FCM authorization status
    final fcmSettings =
        await FirebaseMessaging.instance.getNotificationSettings();
    print('FCM authorization status: ${fcmSettings.authorizationStatus}');
    print('FCM alert setting: ${fcmSettings.alert}');
    print('FCM badge setting: ${fcmSettings.badge}');
    print('FCM sound setting: ${fcmSettings.sound}');

    // Check if we can get FCM token
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      print('FCM token available: ${fcmToken != null ? "YES" : "NO"}');
      if (fcmToken != null) {
        print('FCM token: ${fcmToken.substring(0, 20)}...');
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  } catch (e) {
    print('Error checking notification permissions status: $e');
  }
}

// Handle live stream route navigation
Route<dynamic>? _handleLiveStreamRoute(String streamId, bool isStreamer) {
  return CupertinoPageRoute(
    builder: (context) => FutureBuilder(
      future: _joinLiveStream(streamId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text('Joining Stream'),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(radius: 20),
                  SizedBox(height: 16),
                  Text('Joining stream...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text('Error'),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.exclamationmark_triangle,
                      size: 64, color: CupertinoColors.systemRed),
                  const SizedBox(height: 16),
                  Text('Failed to join stream: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          // Create a new isolated LiveStreamView that doesn't depend on room controllers
          return LiveStreamView(
            stream: snapshot.data!,
            isStreamer: isStreamer,
          );
        }

        return const CupertinoPageScaffold(
          child: Center(
            child: Text('Unable to load stream'),
          ),
        );
      },
    ),
  );
}

// Join live stream using the watch live controller
Future<dynamic> _joinLiveStream(String streamId) async {
  try {
    final watchController = GetIt.I.get<WatchLiveController>();
    final result = await watchController.joinStream(streamId);
    return result;
  } catch (e) {
    throw Exception('Failed to join stream: $e');
  }
}
