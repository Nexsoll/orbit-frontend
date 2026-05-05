// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../models/live_stream_recording_model.dart';
import '../../controllers/saved_lives_controller.dart';
import '../../services/live_stream_api_service.dart';
import '../../../choose_members/views/choose_members_view.dart';
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:super_up/app/core/api_service/auth/auth_api_service.dart';
import 'package:super_up/main.dart' show navigatorKey;
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class RecordingCard extends StatelessWidget {
  final LiveStreamRecordingModel recording;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  // Whether to show the more options/delete menu
  final bool allowDelete;
  // Whether to show price badge on the thumbnail (used in All Saved Streams)
  final bool showPriceBadge;
  // Whether to show the 3-dots menu at all (independent from delete rights)
  final bool showMoreMenu;
  // When true, show only the Share action in the menu (hide Price/Privacy/Delete)
  final bool shareOnlyMenu;

  const RecordingCard({
    super.key,
    required this.recording,
    required this.onTap,
    required this.onDelete,
    this.allowDelete = true,
    this.showPriceBadge = false,
    this.showMoreMenu = true,
    this.shareOnlyMenu = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey4.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail section
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  image: recording.thumbnailUrl != null && recording.thumbnailUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(recording.thumbnailUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    // Fallback thumbnail with play icon
                    if (recording.thumbnailUrl == null || recording.thumbnailUrl!.isEmpty)
                      const Center(
                        child: Icon(
                          CupertinoIcons.play_circle_fill,
                          size: 40,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    
                    // Duration badge
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          recording.formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    // Price badge (e.g., KES 100) in bottom-left when enabled and paid
                    if (showPriceBadge && recording.isPaid)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            recording.formattedPrice,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    
                    // Status indicator
                    if (recording.status != 'completed')
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: recording.status == 'processing'
                                ? CupertinoColors.systemOrange
                                : CupertinoColors.systemRed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            recording.status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    
                    // More options button (show for owner or when share-only menu is enabled)
                    if (showMoreMenu || allowDelete)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _showMoreOptions(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.ellipsis,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Info section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      recording.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Date and stats
                    Text(
                      recording.formattedRecordedAt,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Stats row
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.eye,
                          size: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${recording.viewCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        Icon(
                          CupertinoIcons.heart,
                          size: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${recording.likesCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        
                        if (recording.fileSize != null) ...[
                          const Spacer(),
                          Text(
                            recording.formattedFileSize,
                            style: const TextStyle(
                              fontSize: 10,
                              color: CupertinoColors.tertiaryLabel,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSpecificUsersPicker() async {
    try {
      // Give the sheet a moment to close before pushing a new route
      await Future.delayed(const Duration(milliseconds: 100));
      final ctx = navigatorKey.currentContext!;
      final selectedUsers = await showCupertinoModalBottomSheet<List<SBaseUser>>(
        context: ctx,
        expand: false,
        builder: (_) => ChooseMembersView(
          maxCount: 100,
          onDone: (users) => Navigator.of(_).pop(users),
          onCloseSheet: () => Navigator.of(_).pop(),
        ),
      );
      if (selectedUsers == null) return; // cancelled
      final ids = selectedUsers.map((e) => e.id).toList();
      final controller = GetIt.I.get<SavedLivesController>();
      await controller.updateRecordingPrivacy(
        recordingId: recording.id,
        isPrivate: true,
        allowedViewers: ids,
      );
      VAppAlert.showSuccessSnackBarWithoutContext(
        message: ids.isEmpty
            ? 'No users selected'
            : 'Privacy set for ${ids.length} user(s)',
      );
    } catch (e) {
      VAppAlert.showErrorSnackBarWithoutContext(
        message: e.toString(),
      );
    }
  }

  void _showMoreOptions(BuildContext context) {
    final isOwner = recording.streamerId == AppAuth.myId;
    final actions = <Widget>[
      CupertinoActionSheetAction(
        child: const Text('Share'),
        onPressed: () async {
          Navigator.pop(context);
          await _shareRecording();
        },
      ),
    ];

    if (!shareOnlyMenu) {
      if (isOwner) {
        actions.addAll([
          CupertinoActionSheetAction(
            child: const Text('Price'),
            onPressed: () async {
              Navigator.pop(context);
              Future.microtask(() => _showPriceOptions(navigatorKey.currentContext!));
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Privacy'),
            onPressed: () async {
              Navigator.pop(context);
              Future.microtask(() => _showPrivacyOptions(navigatorKey.currentContext!));
            },
          ),
        ]);
      } else {
        actions.add(
          CupertinoActionSheetAction(
            child: const Text('Support'),
            onPressed: () async {
              Navigator.pop(context);
              Future.microtask(() => _supportRecording());
            },
          ),
        );
      }
    }

    if (!shareOnlyMenu && allowDelete) {
      actions.add(
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          child: const Text('Delete'),
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
        ),
      );
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: actions,
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _shareRecording() async {
    try {
      if (recording.isPrivate) {
        VAppAlert.showErrorSnackBarWithoutContext(
          message: 'This recording is private. Set privacy to Everyone to generate a public link.',
        );
        return;
      }
      if (recording.status != 'completed') {
        VAppAlert.showErrorSnackBarWithoutContext(
          message: 'Recording is ${recording.status}. Please try again later.',
        );
        return;
      }
      // We will share a public page hosted on the backend that can play the recording
      // Page: https://api.orbit.ke/recording.html
      // Params:
      //   id: recording id
      //   title: recording title
      //   ru: relative recording url (e.g., /recordings/xxx/yyy.mp4)
      //   th: thumbnail url (optional, relative or absolute)
      //   pr: price (0 or empty => free)

      String relativeRecordingPath = recording.recordingUrl.trim();
      // Keep absolute URLs as-is. Only prefix '/' for relative paths.
      final isAbsolute = relativeRecordingPath.startsWith('http://') ||
          relativeRecordingPath.startsWith('https://');
      if (!isAbsolute && !relativeRecordingPath.startsWith('/')) {
        relativeRecordingPath = '/$relativeRecordingPath';
      }

      final title = Uri.encodeComponent(recording.title);
      final ru = Uri.encodeComponent(relativeRecordingPath);
      final th = Uri.encodeComponent(recording.thumbnailUrl ?? '');
      final pr = recording.price == null ? '' : recording.price!.toStringAsFixed(0);

      // Always point to production backend for share links so recipients can open it anywhere
      final shareUrl = 'https://api.orbit.ke/recording.html?id=${recording.id}&title=$title&ru=$ru&th=$th&pr=$pr';

      final message = 'Watch "${recording.title}" on Orbit:\n$shareUrl';
      await Share.share(message);
    } catch (e) {
      VAppAlert.showErrorSnackBarWithoutContext(message: e.toString());
    }
  }

  Future<void> _showPrivacyOptions(BuildContext context) async {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('Recording Privacy'),
        message: const Text('Choose who can see this recording in All Saved Streams'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Everyone'),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final controller = GetIt.I.get<SavedLivesController>();
                await controller.updateRecordingPrivacy(
                  recordingId: recording.id,
                  isPrivate: false,
                  allowedViewers: const [],
                );
                VAppAlert.showSuccessSnackBarWithoutContext(
                  message: 'Privacy set to Everyone',
                );
              } catch (e) {
                VAppAlert.showErrorSnackBarWithoutContext(
                  message: e.toString(),
                );
              }
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Specific users...'),
            onPressed: () async {
              Navigator.pop(ctx);
              // Schedule after the sheet is fully dismissed to avoid using a deactivated context
              Future.microtask(() => _openSpecificUsersPicker());
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Future<void> _showPriceOptions(BuildContext context) async {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('Recording Price'),
        message: const Text('Set a price for this recording or make it free'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Set Price...'),
            onPressed: () async {
              Navigator.pop(ctx);
              Future.microtask(() => _openSetPriceDialog());
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Make Free'),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final controller = GetIt.I.get<SavedLivesController>();
                await controller.updateRecordingPrice(recordingId: recording.id, price: 0);
                VAppAlert.showSuccessSnackBarWithoutContext(message: 'Price set to Free');
              } catch (e) {
                VAppAlert.showErrorSnackBarWithoutContext(message: e.toString());
              }
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Future<void> _openSetPriceDialog() async {
    final ctx = navigatorKey.currentContext!;
    final textController = TextEditingController(
      text: (recording.price == null || recording.price == 0)
          ? ''
          : recording.price!.toStringAsFixed(0),
    );
    await showCupertinoDialog(
      context: ctx,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return CupertinoAlertDialog(
            title: const Text('Set Price (KES)'),
            content: Column(
              children: [
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: textController,
                  placeholder: 'e.g. 100',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Save'),
                onPressed: () async {
                  final raw = textController.text.trim();
                  final value = raw.isEmpty ? null : double.tryParse(raw);
                  if (raw.isNotEmpty && value == null) {
                    VAppAlert.showErrorSnackBarWithoutContext(message: 'Invalid amount');
                    return;
                  }
                  try {
                    final controller = GetIt.I.get<SavedLivesController>();
                    await controller.updateRecordingPrice(
                      recordingId: recording.id,
                      price: value,
                    );
                    Navigator.of(context).pop();
                    VAppAlert.showSuccessSnackBarWithoutContext(message: 'Price updated');
                  } catch (e) {
                    VAppAlert.showErrorSnackBarWithoutContext(message: e.toString());
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _supportRecording() async {
    final ctx = navigatorKey.currentContext!;
    if (recording.streamId.isEmpty) return;
    if (recording.streamerId == AppAuth.myId) {
      VAppAlert.showErrorSnackBar(
        context: ctx,
        message: 'You cannot support your own recording',
      );
      return;
    }

    final amountController = TextEditingController();
    String? res;

    await showCupertinoDialog<void>(
      context: ctx,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Support ${recording.streamerData.fullName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: amountController,
                placeholder: 'Amount (e.g., 100)',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              res = 'ok';
              Navigator.pop(context);
            },
            child: const Text('Support'),
          ),
        ],
      ),
    );

    if (res != 'ok') return;

    final amountStr = amountController.text.trim();
    final amount = int.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      VAppAlert.showErrorSnackBar(
        context: ctx,
        message: 'Invalid amount',
      );
      return;
    }

    final verified = await _verifySupportPassword();
    if (!verified) return;

    VAppAlert.showLoading(context: ctx);
    try {
      final apiService = LiveStreamApiService.init();
      await apiService.support(
        streamId: recording.streamId,
        amount: amount,
      );
      Navigator.of(ctx).pop();
      showCupertinoDialog(
          context: ctx,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Support sent successfully'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('OK'),
              ),
            ],
          ));
      BalanceService.instance.init();
    } catch (e) {
      Navigator.of(ctx).pop();
      VAppAlert.showErrorSnackBar(
        context: ctx,
        message: e.toString(),
      );
    }
  }

  Future<bool> _verifySupportPassword() async {
    final ctx = navigatorKey.currentContext!;
    final passwordCtrl = TextEditingController();
    bool confirmed = false;
    bool obscure = true;
    await showCupertinoDialog<void>(
      context: ctx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Confirm with password'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: passwordCtrl,
              placeholder: 'Password',
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              suffix: CupertinoButton(
                padding: const EdgeInsets.only(right: 8),
                minSize: 0,
                onPressed: () => setDialogState(() => obscure = !obscure),
                child: Icon(
                  obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                  size: 18,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                confirmed = true;
                Navigator.pop(ctx);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (!confirmed) return false;

    final password = passwordCtrl.text;
    if (password.trim().isEmpty) {
      VAppAlert.showErrorSnackBar(
        context: ctx,
        message: 'Password is required',
      );
      return false;
    }

    void hideLoading() {
      try {
        Navigator.of(ctx, rootNavigator: true).pop();
      } catch (_) {}
    }

    String normalizePhone(String raw) {
      var v = raw.trim();
      v = v.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (v.startsWith('00')) v = '+${v.substring(2)}';
      return v;
    }

    final profile = AppAuth.myProfile;
    final email = profile.email.trim();
    final phoneRaw = (profile.phoneNumber ?? '').trim();
    final phoneNormalized = normalizePhone(phoneRaw);
    final preferPhone = profile.registerMethod.toLowerCase().contains('phone');

    final candidates = <MapEntry<String, RegisterMethod>>[];
    void addCandidate(String id, RegisterMethod method) {
      final value = id.trim();
      if (value.isEmpty) return;
      final exists = candidates.any(
        (c) => c.key.toLowerCase() == value.toLowerCase() && c.value == method,
      );
      if (!exists) {
        candidates.add(MapEntry(value, method));
      }
    }

    if (preferPhone) {
      addCandidate(phoneRaw, RegisterMethod.phone);
      addCandidate(phoneNormalized, RegisterMethod.phone);
      addCandidate(email, RegisterMethod.email);
    } else {
      addCandidate(email, RegisterMethod.email);
      addCandidate(phoneRaw, RegisterMethod.phone);
      addCandidate(phoneNormalized, RegisterMethod.phone);
    }

    final map = profile.toMap();
    final me = (map['me'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    addCandidate((me['email'] ?? '').toString(), RegisterMethod.email);
    addCandidate((me['phoneNumber'] ?? '').toString(), RegisterMethod.phone);

    if (candidates.isEmpty) {
      VAppAlert.showErrorSnackBar(
        context: ctx,
        message: 'Unable to verify password right now',
      );
      return false;
    }

    VAppAlert.showLoading(context: ctx);
    try {
      final deviceHelper = DeviceInfoHelper();
      final deviceInfo = await deviceHelper.getDeviceMapInfo();
      final deviceId = await deviceHelper.getId();

      Object? lastError;
      for (final candidate in candidates) {
        try {
          final authApi = GetIt.I.get<AuthApiService>();
          await authApi.verifyLoginPassword(
            LoginDto(
              email: candidate.key,
              method: candidate.value,
              password: password,
              deviceId: deviceId,
              deviceInfo: deviceInfo,
              platform: VPlatforms.currentPlatform,
              language: VLanguageListener.I.appLocal.languageCode,
              pushKey: null,
            ),
          );
          hideLoading();
          return true;
        } catch (e) {
          lastError = e;
        }
      }
      hideLoading();
      VAppAlert.showErrorSnackBar(
        context: ctx,
        message: lastError?.toString() ?? 'Password verification failed',
      );
      return false;
    } catch (e) {
      hideLoading();
      VAppAlert.showErrorSnackBar(
        context: ctx,
        message: e.toString(),
      );
      return false;
    }
  }
}
