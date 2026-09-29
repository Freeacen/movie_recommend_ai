import 'package:flutter/material.dart';

class TrailerPlayerPlatformView extends StatelessWidget {
  final String youtubeKey;

  const TrailerPlayerPlatformView({super.key, required this.youtubeKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 48),
            const SizedBox(height: 8),
            Text(
              'Fragman: $youtubeKey',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
