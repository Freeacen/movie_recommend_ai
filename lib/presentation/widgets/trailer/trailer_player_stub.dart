import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
          ),
        )
        ..loadRequest(
          Uri.parse(
            'https://www.youtube-nocookie.com/embed/${widget.youtubeKey}?autoplay=1&rel=0&modestbranding=1&playsinline=1',
          ),
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
