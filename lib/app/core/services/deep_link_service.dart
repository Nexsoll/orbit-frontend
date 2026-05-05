import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';

import 'package:super_up/app/modules/auth/reset_password/views/reset_password_page.dart';
import 'package:super_up/main.dart' show navigatorKey;
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up/app/core/api_service/channel/group_invite_api_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  bool _isInResetFlow = false;
  bool _isHandlingInvite = false;
  bool _hasPendingRoomDeepLink = false;
  AppLinks? _appLinks;
  StreamSubscription<dynamic>? _sub;

  bool get isInResetFlow => _isInResetFlow;
  bool get hasPendingRoomDeepLink => _hasPendingRoomDeepLink;

  Future<void> initialize() async {
    if (kIsWeb) {
      _handleWebUri(Uri.base);
      return;
    }
    try {
      _appLinks = AppLinks();
      Uri? initial;
      try {
        final dynamic links = _appLinks;
        try {
          final dynamic r1 = await (links as dynamic).getInitialAppLink();
          if (r1 is Uri) initial = r1; else if (r1 is String) initial = Uri.tryParse(r1);
        } catch (_) {}
        if (initial == null) {
          try {
            final dynamic r2 = await (links as dynamic).getInitialLink();
            if (r2 is Uri) initial = r2; else if (r2 is String) initial = Uri.tryParse(r2);
          } catch (_) {}
        }
      } catch (_) {}
      if (initial != null) {
        _handleUniversalUri(initial);
      }
      try {
        final dynamic links = _appLinks;
        Stream<dynamic>? stream;
        try { stream = (links as dynamic).uriLinkStream as Stream<dynamic>?; } catch (_) {}
        stream ??= (() { try { return (links as dynamic).stringLinkStream as Stream<dynamic>?; } catch (_) { return null; } })();
        _sub = stream?.listen((event) {
          if (event is Uri) {
            _handleUniversalUri(event);
          } else if (event is String) {
            final u = Uri.tryParse(event);
            if (u != null) _handleUniversalUri(u);
          }
        });
      } catch (_) {}
    } catch (_) {}
  }

  void _handleWebUri(Uri uri) {
    try {
      final path = uri.path.toLowerCase();
      final q = uri.queryParameters;
      final looksLikeReset = path.contains('reset') ||
          path.contains('reset-password') ||
          q.containsKey('reset') ||
          q.containsKey('token') ||
          q.containsKey('reset_token');
      if (!looksLikeReset) {
        if (path.startsWith('/profile/')) {
          final id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
          if (id != null && id.isNotEmpty) _openProfile(id);
        } else if (path.startsWith('/g/')) {
          final code = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
          if (code != null && code.isNotEmpty) _openInvite(code);
        }
        return;
      }

      final token = q['token'] ?? q['reset_token'] ?? q['code'];
      final email = q['email'] ?? q['user'] ?? q['u'];

      if (token != null && token.isNotEmpty && email != null && email.isNotEmpty) {
        _isInResetFlow = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = navigatorKey.currentState;
          if (nav == null) return;
          nav
              .pushAndRemoveUntil(
                CupertinoPageRoute(
                  builder: (_) => ResetPasswordPage(email: email, token: token),
                ),
                (route) => false,
              )
              .whenComplete(() {
            _isInResetFlow = false;
          });
        });
      }
    } catch (_) {
    }
  }

  void _handleUniversalUri(Uri uri) {
    try {
      // Debug: log every universal link we handle
      debugPrint('DeepLinkService._handleUniversalUri -> uri=$uri');
      if (uri.scheme == 'orbit') {
        String? id;
        if (uri.host == 'profile') {
          if (uri.pathSegments.isNotEmpty) id = uri.pathSegments.first;
        } else if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'profile') {
          if (uri.pathSegments.length >= 2) id = uri.pathSegments[1];
        }
        if (id != null && id.isNotEmpty) {
          _openProfile(id);
          return;
        }
        // Handle orbit://g/<code> and orbit://g?code=...
        String? code;
        if (uri.host == 'g') {
          if (uri.pathSegments.isNotEmpty) code = uri.pathSegments.first;
          code ??= uri.queryParameters['code'];
        } else if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'g') {
          if (uri.pathSegments.length >= 2) code = uri.pathSegments[1];
        }
        if (code != null && code.isNotEmpty) {
          _openInvite(code);
          return;
        }

        // Handle orbit://room/<roomId> and orbit://room?roomId=...
        String? roomId;
        if (uri.host == 'room') {
          if (uri.pathSegments.isNotEmpty) roomId = uri.pathSegments.first;
          roomId ??= uri.queryParameters['roomId'] ?? uri.queryParameters['id'];
        } else if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'room') {
          if (uri.pathSegments.length >= 2) roomId = uri.pathSegments[1];
        }
        if (roomId != null && roomId.isNotEmpty) {
          _hasPendingRoomDeepLink = true;
          debugPrint('DeepLinkService._handleUniversalUri -> open roomId=$roomId');
          _openRoom(roomId);
        }
        return;
      }
      if (uri.scheme == 'https' || uri.scheme == 'http') {
        if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'profile' && uri.pathSegments.length >= 2) {
          final id = uri.pathSegments[1];
          if (id.isNotEmpty) _openProfile(id);
          return;
        }
        if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'g' && uri.pathSegments.length >= 2) {
          final code = uri.pathSegments[1];
          if (code.isNotEmpty) _openInvite(code);
        }
      }
    } catch (_) {}
  }

  void _openInvite(String code) {
    if (_isHandlingInvite) return;
    _isHandlingInvite = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final nav = navigatorKey.currentState;
      if (nav == null) {
        _isHandlingInvite = false;
        return;
      }
      final ctx = nav.context;
      try {
        final meta = await GroupInviteApiService.I.resolve(code);
        await GroupInviteApiService.I.join(code);
        final roomId = (meta['roomId'] ?? meta['id']) as String?;
        if (roomId != null && roomId.isNotEmpty) {
          final vRoom = await VChatController.I.nativeApi.remote.room.getRoomById(roomId);
          VChatController.I.vNavigator.messageNavigator.toMessagePage(ctx, vRoom);
        } else {
          VAppAlert.showSuccessSnackBar(context: ctx, message: 'Joined');
        }
      } catch (e) {
        VAppAlert.showErrorSnackBar(context: ctx, message: 'Failed to open invite');
      } finally {
        _isHandlingInvite = false;
      }
    });
  }

  void _openRoom(String roomId) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final nav = navigatorKey.currentState;
      if (nav == null) {
        debugPrint('DeepLinkService._openRoom -> navigatorKey.currentState is null');
        return;
      }
      final ctx = nav.context;
      try {
        debugPrint('DeepLinkService._openRoom -> resolving roomId=$roomId');

        // Prefer local cache first for speed/offline support
        VRoom? vRoom = await VChatController.I.nativeApi.local.room
            .getOneWithLastMessageByRoomId(roomId);
        if (vRoom == null) {
          debugPrint('DeepLinkService._openRoom -> no local room, fetching remote');
          vRoom = await VChatController.I.nativeApi.remote.room.getRoomById(roomId);
        }

        if (vRoom == null) {
          debugPrint('DeepLinkService._openRoom -> room not found for id=$roomId');
          VAppAlert.showErrorSnackBar(context: ctx, message: 'Chat not found');
          return;
        }

        debugPrint('DeepLinkService._openRoom -> navigating to room ${vRoom.id}');
        VChatController.I.vNavigator.messageNavigator.toMessagePage(ctx, vRoom);
      } catch (e) {
        debugPrint('DeepLinkService._openRoom -> error: $e');
        VAppAlert.showErrorSnackBar(context: ctx, message: 'Failed to open chat');
      }
    });
  }

  void _openProfile(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(CupertinoPageRoute(builder: (_) => PeerProfileView(peerId: id)));
    });
  }

  void exitResetFlow() {
    _isInResetFlow = false;
  }
}
