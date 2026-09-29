import 'package:flutter/material.dart';
import 'trailer_player_stub.dart'
    if (dart.library.html) 'trailer_player_web.dart';

class TrailerPlayerView extends StatelessWidget {
  final String youtubeKey;

  const TrailerPlayerView({super.key, required this.youtubeKey});

  @override
  Widget build(BuildContext context) {
    return TrailerPlayerPlatformView(youtubeKey: youtubeKey);
  }
}
