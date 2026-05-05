// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import 'package:v_platform/v_platform.dart';
import 'package:super_up/app/core/widgets/custom_image_cropper.dart';

import '../controllers/create_broadcast_controller.dart';

class CreateBroadcastView extends StatefulWidget {
  final Function(VRoom) onDone;

  const CreateBroadcastView({
    super.key,
    required this.users,
    required this.onDone,
  });
  final List<SBaseUser> users;

  @override
  State<CreateBroadcastView> createState() => _CreateBroadcastViewState();
}

class _CreateBroadcastViewState extends State<CreateBroadcastView> {
  late final CreateBroadcastController controller;

  @override
  void initState() {
    super.initState();
    controller = CreateBroadcastController(
      widget.users,
      widget.onDone,
    );
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        middle: Text(S.of(context).createBroadcast),
        trailing: ValueListenableBuilder(
          valueListenable: controller,
          builder: (_, __, ___) {
            if (controller.isCreating) {
              return const CupertinoActivityIndicator();
            }
            return TextButton(
              onPressed: controller.isTextEmpty
                  ? null
                  : () => controller.createBroadcast(context),
              child: Text(
                S.of(context).create,
                style: const TextStyle(fontSize: 13),
              ),
            );
          },
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, __, ___) {
              return Center(
                child: Column(
                  children: [
                    AppImagePicker(
                      onDone: (VPlatformFile file) {
                        controller.image = file;
                      },
                      initImage: VPlatformFile.fromAssets(
                        assetsPath: "assets/ic_addphoto.png",
                      ),
                      withCrop: true,
                      size: 120,
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    STextFiled(
                      controller: controller.txtController,
                      textHint: S.of(context).broadcastName,
                      autofocus: true,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
