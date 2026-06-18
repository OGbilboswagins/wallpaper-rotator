import 'dart:io';
import 'dart:math';

class RandomizerService {
  static String pickRandomWallpaper(
    List<FileSystemEntity> wallpaperFiles,
    String lastImagePath,
  ) {
    if (wallpaperFiles.isEmpty) return '';

    final random = Random();

    String randomImage =
        wallpaperFiles[random.nextInt(wallpaperFiles.length)].path;

    if (wallpaperFiles.length > 1) {
      while (randomImage == lastImagePath) {
        randomImage =
            wallpaperFiles[random.nextInt(wallpaperFiles.length)].path;
      }
    }

    return randomImage;
  }
}