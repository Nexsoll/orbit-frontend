// Web implementation for a host container that the JS shadow client can target
// with AgoraRTC video. This uses HtmlElementView and a <div> with a known viewType
// so the JS can place an overlay inside it.

// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WebShadowHost extends StatefulWidget {
  const WebShadowHost({super.key});

  @override
  State<WebShadowHost> createState() => _WebShadowHostState();
}

class _WebShadowHostState extends State<WebShadowHost> {
  late final String _viewId;
  html.DivElement? _root;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _viewId = 'agora-shadow-host';
      _root = html.DivElement()
        ..id = 'agora-shadow-host'
        ..style.position = 'relative'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = 'none'
        ..style.zIndex = '0'
        ..style.backgroundColor = 'transparent';

      // Register the platform view factory once
      try {
        ui_web.platformViewRegistry.registerViewFactory(
          _viewId,
          (int viewId) => _root!,
        );
      } catch (_) {
        // It's okay if already registered
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }
    return HtmlElementView(viewType: 'agora-shadow-host');
  }
}
