// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:s_translation/generated/l10n.dart';

import '../../../../core/api_service/profile/profile_api_service.dart';
import '../../../home/home_controller/views/home_view.dart';
import '../../../../core/widgets/custom_image_cropper.dart';

class ProfilePictureUploadState {
  VPlatformFile? selectedImage;
  bool isUploading;

  ProfilePictureUploadState({
    this.selectedImage,
    this.isUploading = false,
  });

  ProfilePictureUploadState copyWith({
    VPlatformFile? selectedImage,
    bool? isUploading,
  }) {
    return ProfilePictureUploadState(
      selectedImage: selectedImage ?? this.selectedImage,
      isUploading: isUploading ?? this.isUploading,
    );
  }

}

class ProfilePictureUploadController
    extends ValueNotifier<ProfilePictureUploadState>
    implements SBaseController {
  final ProfileApiService profileService;
  final String? initialImageUrl;

  ProfilePictureUploadController(this.profileService, {this.initialImageUrl})
      : super(ProfilePictureUploadState());

  /// Resolve the current accountId from the multi-account manager if available,
  /// otherwise fall back to the stored myProfile map in preferences.
  /// This avoids depending on AppAuth which may be temporarily null.
  String? _resolveCurrentAccountId() {
    try {
      final current = MultiAccountManager.instance.currentAccount;
      if (current != null) return current.accountId;

      final Map<String, dynamic>? mp = VAppPref.getMap(SStorageKeys.myProfile.name);
      if (mp != null) {
        final email = mp['email'];
        final baseUser = mp['baseUser'];
        if (email != null && baseUser is Map) {
          final id = baseUser['id'] ?? baseUser['_id'];
          if (id != null) {
            return AccountSession.createAccountId(email.toString(), id.toString());
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> ensurePendingMark() async {
    try {
      final String? accountId = _resolveCurrentAccountId();
      if (accountId == null) return;
      final pending =
          VAppPref.getList(SStorageKeys.profilePicturePendingAccounts.name) ?? [];
      if (!pending.contains(accountId)) {
        pending.add(accountId);
        await VAppPref.setList(
          SStorageKeys.profilePicturePendingAccounts.name,
          pending,
        );
      }
    } catch (_) {}
  }

  Future<void> _markCompleted() async {
    try {
      final String? accountId = _resolveCurrentAccountId();
      if (accountId == null) return;
      final pending =
          VAppPref.getList(SStorageKeys.profilePicturePendingAccounts.name) ?? [];
      if (pending.contains(accountId)) {
        pending.remove(accountId);
        await VAppPref.setList(
            SStorageKeys.profilePicturePendingAccounts.name, pending);
      }
    } catch (_) {}
  }

  Future<void> selectImage(BuildContext context) async {
    final image = await AppImageCropper.pickAndCrop(context);
    if (image != null) {
      value = value.copyWith(selectedImage: image);
    }
  }

  bool _isDefaultImage(String urlOrPath) {
    final u = urlOrPath.toLowerCase().trim();
    return u.contains('default_user_image');
  }

  void uploadProfilePicture(BuildContext context) async {
    // If user didn't pick a new image but has an initial image (from social),
    // allow proceeding without uploading.
    if (value.selectedImage == null) {
      if (initialImageUrl != null && initialImageUrl!.isNotEmpty && !_isDefaultImage(initialImageUrl!)) {
        // Mark as completed and navigate straight to home, keeping the social profile picture
        await _markCompleted();
        context.toPage(
          const HomeView(),
          withAnimation: true,
          removeAll: true,
        );
        return;
      }
      final defaultImage = '/v-public/default_user_image.png';
      try {
        final newProfile = AppAuth.myProfile.copyWith(
          baseUser: AppAuth.myProfile.baseUser.copyWith(userImage: defaultImage),
        );
        await VAppPref.setMap(SStorageKeys.myProfile.name, newProfile.toMap());
        await MultiAccountManager.instance.updateCurrentAccountProfile(newProfile);
      } catch (_) {}
      await _markCompleted();
      context.toPage(
        const HomeView(),
        withAnimation: true,
        removeAll: true,
      );
      return;
    }

    await vSafeApiCall<String>(
      onLoading: () async {
        value = value.copyWith(isUploading: true);
        VAppAlert.showLoading(context: context);
      },
      onError: (exception, trace) {
        value = value.copyWith(isUploading: false);
        Navigator.of(context).pop();
        VAppAlert.showOkAlertDialog(
          context: context,
          title: S.of(context).error,
          content: exception.toString(),
        );
      },
      request: () async {
        return await profileService.updateImage(value.selectedImage!);
      },
      onSuccess: (response) async {
        value = value.copyWith(isUploading: false);

        // Update the stored profile with new image
        final newProfile = AppAuth.myProfile.copyWith(
          baseUser: AppAuth.myProfile.baseUser.copyWith(userImage: response),
        );
        // Persist to preferences for backward compatibility
        await VAppPref.setMap(SStorageKeys.myProfile.name, newProfile.toMap());
        // Also update the multi-account session so restarts see the correct image
        await MultiAccountManager.instance.updateCurrentAccountProfile(newProfile);

        Navigator.of(context).pop(); // Close loading dialog

        // Mark profile picture step as completed for this account
        await _markCompleted();

        // Navigate to home screen
        context.toPage(
          const HomeView(),
          withAnimation: true,
          removeAll: true,
        );
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }

  void handleBackPress(BuildContext context) async {
    // Show info dialog that profile picture is required
    await VAppAlert.showOkAlertDialog(
      context: context,
      title: S.of(context).addProfilePicture,
      content: S.of(context).profilePictureRequired,
    );
  }

  @override
  void onClose() {
    dispose();
  }

  @override
  void onInit() {
    // Initialize if needed
  }
}
