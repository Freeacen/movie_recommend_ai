// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredTrailerViews = {};

class TrailerPlayerPlatformView extends StatelessWidget {
  final String youtubeKey;

  const TrailerPlayerPlatformView({super.key, required this.youtubeKey});

  @override
  Widget build(BuildContext context) {
    final viewType = 'youtube-trailer-$youtubeKey';

    if (!_registeredTrailerViews.contains(viewType)) {
      _registeredTrailerViews.add(viewType);
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = 'https://www.youtube-nocookie.com/embed/$youtubeKey?autoplay=1&rel=0&modestbranding=1'
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.borderRadius = '16px'
            ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen'
            ..allowFullscreen = true;
          return iframe;
        },
      );
    }

    return HtmlElementView(viewType: viewType);
  }
}
