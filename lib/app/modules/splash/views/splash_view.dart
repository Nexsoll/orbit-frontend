// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/modules/splash/controllers/splash_controller.dart';
import 'package:super_up_core/super_up_core.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  late final SplashController controller;

  @override
  void initState() {
    super.initState();
    controller = SplashController();
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
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(),
              Column(
                children: [
                  Image.asset(
                    "assets/logo.png",
                    height: 100,
                    width: 100,
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  SConstants.appName.h6
                ],
              ),
              Column(
                children: [
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      return controller.version.text
                          .size(13)
                          .color(Colors.white);
                    },
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
