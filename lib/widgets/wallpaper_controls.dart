import 'package:flutter/material.dart';

class WallpaperControls extends StatelessWidget {
  final bool hasWallpapers;
  final bool hasSelectedImage;
  final bool rotationEnabled;
  final VoidCallback onNextWallpaper;
  final VoidCallback onSetWallpaper;
  final VoidCallback onStartRotation;
  final VoidCallback onStopRotation;

  const WallpaperControls({
    super.key,
    required this.hasWallpapers,
    required this.hasSelectedImage,
    required this.rotationEnabled,
    required this.onNextWallpaper,
    required this.onSetWallpaper,
    required this.onStartRotation,
    required this.onStopRotation,
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

        const SizedBox(height: 8),

        ElevatedButton(
          onPressed: hasSelectedImage ? onSetWallpaper : null,
          child: const Text('Set Windows Wallpaper'),
        ),

        const SizedBox(height: 8),

        ElevatedButton(
          onPressed: hasWallpapers
              ? rotationEnabled
                  ? onStopRotation
                  : onStartRotation
              : null,
          child: Text(rotationEnabled ? 'Stop Rotation' : 'Start Rotation'),
        ),
      ],
    );
  }
}