import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:super_up_core/super_up_core.dart';

import 'social_main_view.dart';

class SocialSplashView extends StatefulWidget {
  const SocialSplashView({super.key});

  @override
  State<SocialSplashView> createState() => _SocialSplashViewState();
}

class _SocialSplashViewState extends State<SocialSplashView> {
  @override
  void initState() {
    super.initState();
    unawaited(_navigateNext());
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (_) => const SocialMainView(),
      ),
    );
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
                    'assets/logo.png',
                    height: 100,
                    width: 100,
                  ),
                  const SizedBox(height: 20),
                  'Orbit Social'.h6,
                ],
              ),
              const SizedBox(),
            ],
          ),
        ),
      ),
    );
  }
}
