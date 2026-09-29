import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class TrailerPlayerPlatformView extends StatefulWidget {
  final String youtubeKey;

  const TrailerPlayerPlatformView({super.key, required this.youtubeKey});

  @override
  State<TrailerPlayerPlatformView> createState() => _TrailerPlayerPlatformViewState();
}

class _TrailerPlayerPlatformViewState extends State<TrailerPlayerPlatformView> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(TrailerPlayerPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeKey != widget.youtubeKey) {
      _setupController();
    }
  }

  void _setupController() {
    try {
      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      background-color: #000000;
      overflow: hidden;
    }
    .video-wrapper {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
    }
    iframe {
      width: 100%;
      height: 100%;
      border: none;
    }
  </style>
</head>
<body>
  <div class="video-wrapper">
    <iframe
      src="https://www.youtube-nocookie.com/embed/${widget.youtubeKey}?autoplay=1&playsinline=1&rel=0&modestbranding=1&enablejsapi=1&origin=https://www.youtube-nocookie.com"
      referrerpolicy="strict-origin-when-cross-origin"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen"
      allowfullscreen>
    </iframe>
  </div>
</body>
</html>
''';

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
            onWebResourceError: (_) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
          ),
        );

      if (controller.platform is AndroidWebViewController) {
        (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }

      controller.loadHtmlString(
        htmlContent,
        baseUrl: 'https://www.youtube-nocookie.com',
      );

      _controller = controller;
    } catch (_) {
      // In case webview is not supported in CLI test environment
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.movie_filter_rounded, color: Colors.white54, size: 40),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _controller!),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.redAccent,
              ),
            ),
        ],
      ),
    );
  }
}
