// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:s_translation/generated/l10n.dart';

import '../../../../core/api_service/profile/profile_api_service.dart';
import '../../../../core/widgets/wide_constraints.dart';
import '../controllers/profile_picture_upload_controller.dart';
import '../../../../core/widgets/custom_image_cropper.dart';

class ProfilePictureUploadView extends StatefulWidget {
  final String? initialImageUrl;

  const ProfilePictureUploadView({super.key, this.initialImageUrl});

  @override
  State<ProfilePictureUploadView> createState() =>
      _ProfilePictureUploadViewState();
}

class _ProfilePictureUploadViewState extends State<ProfilePictureUploadView> {
  late ProfilePictureUploadController controller;

  @override
  void initState() {
    super.initState();
    controller = ProfilePictureUploadController(
      ProfileApiService.init(),
      initialImageUrl: widget.initialImageUrl,
    );
    // Ensure we persist a pending flag for this account as soon as
    // the profile picture step is reached, so a restart returns here.
    // This flag is cleared when the user keeps/changes the picture.
    controller.ensurePendingMark();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  String _resolveImageUrl(String imageUrl) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http')) return trimmed;
    if (trimmed.startsWith('/v-public/') || trimmed.startsWith('/media/')) {
      return SConstants.baseMediaUrl + trimmed;
    }
    return SConstants.baseMediaUrl + '/v-public/' + trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            controller.handleBackPress(context);
          }
        },
        child: ResponsiveBuilder(
          builder: (context, sizingInformation) => WideConstraints(
            enable: sizingInformation.isDesktop,
            child: CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(
                transitionBetweenRoutes: false, // 👈 disables Hero animation
                middle: Text(S.of(context).addProfilePicture),
                backgroundColor:
                    CupertinoColors.systemBackground.withOpacity(0.9),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(height: context.height * .03),

                      // Subtitle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          S.of(context).profilePictureRequired,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: context.height * .05),

                      // Profile Picture Picker
                      ValueListenableBuilder<ProfilePictureUploadState>(
                        valueListenable: controller,
                        builder: (context, state, child) {
                          if (state.selectedImage == null) {
                            // If we have an initial social image, show it as the default
                            if (widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty) {
                              final initialUrl = _resolveImageUrl(widget.initialImageUrl!);
                              return AppImagePicker(
                                onDone: (VPlatformFile file) {
                                  controller.value = controller.value.copyWith(selectedImage: file);
                                },
                                initImage: VPlatformFile.fromUrl(networkUrl: initialUrl),
                                withCrop: true,
                                size: 150,
                              );
                            }
                            // Fallback: prompt to add a photo
                            return GestureDetector(
                              onTap: () async {
                                await controller.selectImage(context);
                              },
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.3),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add_a_photo,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }
                          return AppImagePicker(
                            onDone: (VPlatformFile file) {
                              controller.value = controller.value.copyWith(selectedImage: file);
                            },
                            initImage: state.selectedImage!,
                            withCrop: true,
                            size: 150,
                          );
                        },
                      ),

                      SizedBox(height: context.height * .05),

                      // Upload Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child:
                            ValueListenableBuilder<ProfilePictureUploadState>(
                          valueListenable: controller,
                          builder: (context, state, child) {
                            return SElevatedButton(
                              title: state.isUploading
                                  ? S.of(context).uploading
                                  : S.of(context).continueText,
                              onPress: state.isUploading
                                  ? () {} // Disabled state
                                  : () {
                                      controller.uploadProfilePicture(context);
                                    },
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
  }
}
