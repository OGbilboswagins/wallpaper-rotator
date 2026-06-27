import 'package:flutter/material.dart';

class WallpaperControls extends StatelessWidget {
  final bool hasWallpapers;
  final bool hasSelectedImage;
  final VoidCallback onNextWallpaper;
  final VoidCallback onSetWallpaper;

  const WallpaperControls({
    super.key,
    required this.hasWallpapers,
    required this.hasSelectedImage,
    required this.onNextWallpaper,
    required this.onSetWallpaper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: hasWallpapers ? onNextWallpaper : null,
          child: const Text('Next Wallpaper'),
        ),

        ElevatedButton(
          onPressed: hasSelectedImage ? onSetWallpaper : null,
          child: const Text('Set Wallpaper'),
        ),
      ],
    );
  }
}
