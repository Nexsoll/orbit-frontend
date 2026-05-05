// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_platform/v_platform.dart';
import 'package:v_chat_message_page/src/agora/pages/widgets/web_camera_view.dart';

import '../controllers/go_live_controller.dart';
import '../models/live_category_model.dart';
import 'live_stream_view.dart';
import 'widgets/member_selection_sheet.dart';

class GoLiveView extends StatefulWidget {
  const GoLiveView({super.key});

  @override
  State<GoLiveView> createState() => _GoLiveViewState();
}

class _GoLiveViewState extends State<GoLiveView> {
  late final GoLiveController controller;

  @override
  void initState() {
    super.initState();
    controller = GetIt.I.get<GoLiveController>();
    controller.onInit();
  }

  @override
  void dispose() {
    // Don't dispose the singleton controller, just reset its state
    controller.resetController();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Row(
            children: [
              const Icon(CupertinoIcons.chevron_back, color: Color(0xFFB48648)),
              const SizedBox(width: 2),
              Text(S.of(context).back, style: const TextStyle(color: Color(0xFFB48648))),
            ],
          ),
        ),
        middle: Text(
          S.of(context).goLive,
          style: context.cupertinoTextTheme.textStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: ValueListenableBuilder<bool>(
          valueListenable: controller.isCreatingStream,
          builder: (context, isCreating, child) {
            return CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: isCreating ? null : () => _startLiveStream(context),
              child: Text(
                S.of(context).startAction,
                style: TextStyle(
                  color: isCreating
                      ? CupertinoColors.systemGrey
                      : const Color(0xFFB48648),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview container
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: CupertinoColors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    // Camera preview
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: VPlatforms.isWeb
                            ? const WebCameraView()
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.video_camera,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Camera Preview',
                                      style: context.cupertinoTextTheme.textStyle
                                          .copyWith(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    // Camera controls
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCameraControl(
                            icon: CupertinoIcons.camera_rotate,
                            onPressed: controller.switchCamera,
                          ),
                          const SizedBox(width: 12),
                          _buildCameraControl(
                            icon: controller.isMuted.value
                                ? CupertinoIcons.mic_slash
                                : CupertinoIcons.mic,
                            onPressed: controller.toggleMute,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Stream title
              Text(
                S.of(context).streamTitle,
                style: context.cupertinoTextTheme.textStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: controller.titleController,
                placeholder: S.of(context).enterStreamTitle,
                maxLines: 1,
                maxLength: 100,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
              ),

              const SizedBox(height: 20),

              // Stream description
              Text(
                S.of(context).descriptionOptional,
                style: context.cupertinoTextTheme.textStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: controller.descriptionController,
                placeholder: S.of(context).descriptionPlaceholder,
                maxLines: 3,
                maxLength: 500,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
              ),

              const SizedBox(height: 20),

              // Category selection
              Text(
                S.of(context).categoryLabel,
                style: context.cupertinoTextTheme.textStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: controller.isLoadingCategories,
                builder: (context, isLoading, child) {
                  if (isLoading) {
                    return Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: CupertinoActivityIndicator()),
                    );
                  }
                  return ValueListenableBuilder<List<LiveCategoryModel>>(
                    valueListenable: controller.availableCategories,
                    builder: (context, categories, child) {
                      return ValueListenableBuilder<LiveCategoryModel?>(
                        valueListenable: controller.selectedCategory,
                        builder: (context, selectedCategory, child) {
                          return GestureDetector(
                            onTap: () => _showCategorySelection(context, categories),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey4,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.tag,
                                    size: 20,
                                    color: selectedCategory != null
                                        ? const Color(0xFFB48648)
                                        : CupertinoColors.systemGrey,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      selectedCategory?.name ?? S.of(context).selectCategory,
                                      style: context.cupertinoTextTheme.textStyle.copyWith(
                                        fontSize: 16,
                                        color: selectedCategory != null
                                            ? CupertinoColors.label
                                            : CupertinoColors.systemGrey,
                                      ),
                                    ),
                                  ),
                                  const Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 20),

              // Privacy settings (disabled)
              /*
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.of(context).privateStream,
                    style: context.cupertinoTextTheme.textStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: controller.isPrivate,
                    builder: (context, isPrivate, child) {
                      return CupertinoSwitch(
                        value: isPrivate,
                        onChanged: controller.togglePrivacy,
                        activeTrackColor: const Color(0xFFB48648),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                S.of(context).onlyPeopleCanViewStream,
                style: context.cupertinoTextTheme.textStyle.copyWith(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              */

              // Approval/private stream options removed per request

              // Member selection for private streams (disabled)
              /*
              ValueListenableBuilder<bool>(
                valueListenable: controller.isPrivate,
                builder: (context, isPrivate, child) {
                  if (!isPrivate) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Selected members display
                      ValueListenableBuilder<List<SBaseUser>>(
                        valueListenable: controller.selectedMembers,
                        builder: (context, selectedMembers, child) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: CupertinoColors.systemGrey4,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      CupertinoIcons.person_2,
                                      size: 16,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                    selectedMembers.isEmpty
                                        ? S.of(context).noMembersSelected
                                        : '${selectedMembers.length} ${selectedMembers.length == 1 ? S.of(context).member : S.of(context).members} selected',
                                    style: context
                                        .cupertinoTextTheme.textStyle
                                        .copyWith(
                                      fontSize: 14,
                                      color: CupertinoColors.systemGrey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: _showMemberSelection,
                                    child: Text(
                                      selectedMembers.isEmpty
                                          ? S.of(context).selectAction
                                          : S.of(context).editAction,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFB48648),
                                      ),
                                    ),
                                  ),
                                  ],
                                ),
                                if (selectedMembers.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: selectedMembers.map((user) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFB48648)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              user.fullName,
                                              style: context
                                                  .cupertinoTextTheme.textStyle
                                                  .copyWith(
                                                fontSize: 12,
                                                color:
                                                    const Color(0xFFB48648),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            GestureDetector(
                                              onTap: () => controller
                                                  .removeSelectedMember(user),
                                              child: const Icon(
                                                CupertinoIcons
                                                    .xmark_circle_fill,
                                                size: 14,
                                                color:
                                                    CupertinoColors.systemGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              */

              const SizedBox(height: 40),

              // Loading indicator
              ValueListenableBuilder<bool>(
                valueListenable: controller.isCreatingStream,
                builder: (context, isCreating, child) {
                  if (isCreating) {
                    return Center(
                      child: Column(
                        children: [
                          const CupertinoActivityIndicator(radius: 16),
                          const SizedBox(height: 12),
                          Text(S.of(context).creatingYourLiveStream),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraControl({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  void _startLiveStream(BuildContext context) async {
    if (controller.titleController.text.trim().isEmpty) {
      VAppAlert.showErrorSnackBar(
        message: S.of(context).pleaseEnterStreamTitle,
        context: context,
      );
      return;
    }

    // Require category selection
    if (controller.selectedCategory.value == null) {
      VAppAlert.showErrorSnackBar(
        message: S.of(context).pleaseSelectCategory,
        context: context,
      );
      return;
    }

    // Validate private stream has selected members
    if (controller.isPrivate.value &&
        controller.selectedMembers.value.isEmpty) {
      VAppAlert.showErrorSnackBar(
        message: S.of(context).pleaseSelectAtLeastOneMember,
        context: context,
      );
      return;
    }

    final stream = await controller.createLiveStream();
    if (stream != null) {
      // Navigate to live stream view
      context.toPage(LiveStreamView(
        stream: stream,
        isStreamer: true,
      ));
    }
  }

  void _showMemberSelection() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return MemberSelectionSheet(
          selectedMembers: controller.selectedMembers.value,
          onMembersSelected: (List<SBaseUser> members) {
            // Update the controller with selected members
            controller.selectedMembers.value = members;
          },
        );
      },
    );
  }

  void _showCategorySelection(BuildContext context, List<LiveCategoryModel> categories) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(S.of(context).selectCategoryTitle),
          message: Text(S.of(context).selectCategoryMessage),
          actions: [
            ...categories.map((category) {
              return CupertinoActionSheetAction(
                onPressed: () {
                  controller.selectCategory(category);
                  Navigator.pop(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.tag,
                      size: 18,
                      color: controller.selectedCategory.value?.id == category.id
                          ? const Color(0xFFB48648)
                          : CupertinoColors.label,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category.name,
                      style: TextStyle(
                        color: controller.selectedCategory.value?.id == category.id
                            ? const Color(0xFFB48648)
                            : CupertinoColors.label,
                        fontWeight: controller.selectedCategory.value?.id == category.id
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            if (controller.selectedCategory.value != null)
              CupertinoActionSheetAction(
                onPressed: () {
                  controller.selectCategory(null);
                  Navigator.pop(context);
                },
                isDestructiveAction: true,
                child: Text(S.of(context).removeCategory),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).cancel),
          ),
        );
      },
    );
  }
}
