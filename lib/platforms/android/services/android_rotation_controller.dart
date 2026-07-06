import '../../../services/wallpaper_service.dart';
import '../models/rotation_settings.dart';
import '../../../services/scanner_service.dart';
import 'dart:io';

class AndroidRotationController {
  static Future<void> start(AndroidRotationSettings settings) async {
    final folderPath = settings.wallpaperMode == WallpaperMode.lockOnly
        ? settings.lockFolderPath
        : settings.homeFolderPath;

    if (folderPath.isEmpty) return;

    await WallpaperService.startAndroidRotationService(
      folderPath: folderPath,
      lockFolderPath: settings.lockFolderPath,
      intervalSeconds: settings.intervalSeconds,
      wallpaperMode: settings.wallpaperMode.label,
    );
  }

  static Future<void> stop() async {
    await WallpaperService.stopAndroidRotationService();
  }

  static Future<void> restartIfNeeded(AndroidRotationSettings settings) async {
    if (!settings.rotationEnabled) return;
    await start(settings);
  }

  static Future<void> changeNow(AndroidRotationSettings settings) async {
    final folderPath = settings.wallpaperMode == WallpaperMode.lockOnly
        ? settings.lockFolderPath
        : settings.homeFolderPath;

    if (folderPath.isEmpty) return;

    final images = ScannerService.scanImages(folderPath);
    if (images.isEmpty) return;

    images.shuffle();

    await WallpaperService.applyWallpaper(
      monitorIndex: 0,
      imagePath: images.first.path,
      fitMode: 'Fit',
      wallpaperMode: settings.wallpaperMode.label,
    );
  }

  static FolderValidationState validateFolder(String folderPath) {
    if (folderPath.isEmpty) {
      return FolderValidationState.empty;
    }

    final dir = Directory(folderPath);

    if (!dir.existsSync()) {
      return FolderValidationState.missing;
    }

    final images = ScannerService.scanImages(folderPath);

    if (images.isEmpty) {
      return FolderValidationState.empty;
    }

    return FolderValidationState.valid;
  }

  static AndroidRotationSettings applyFolderSelection(
    AndroidRotationSettings settings,
    String selectedFolder, {
    required bool forLockScreen,
  }) {
    final images = ScannerService.scanImages(selectedFolder);
    final count = images.length;

    if (forLockScreen) {
      return settings.copyWith(
        lockFolderPath: selectedFolder,
        lockImageCount: count,
      );
    }

    return settings.copyWith(
      homeFolderPath: selectedFolder,
      homeImageCount: count,
    );
  }
}
