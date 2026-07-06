import '../../../services/settings_service.dart';
import '../models/rotation_settings.dart';
import '../../../services/scanner_service.dart';
import 'android_entitlement_service.dart';

class AndroidSettingsStore {
  static Future<void> save(AndroidRotationSettings settings) async {
    await SettingsService.saveSettings(
      targetFolders: [settings.homeFolderPath],
      lockFolderPath: settings.lockFolderPath,
      selectedImages: [''],
      globalFitMode: 'Fit',
      interval: settings.interval.label,
      rotationEnabled: settings.rotationEnabled,
      wallpaperMode: settings.wallpaperMode.label,
    );
  }

  static Future<AndroidRotationSettings> load() async {
    final savedSettings = await SettingsService.loadSettings();

    final savedWallpaperMode =
        savedSettings['wallpaperMode'] as String? ?? 'Home Only';
    final savedLockFolderPath =
        savedSettings['lockFolderPath'] as String? ?? '';

    final savedFolders = savedSettings['targetFolders'] as List<String>;
    final savedInterval = savedSettings['interval'] as String? ?? '4 hours';
    final savedRotationEnabled =
        savedSettings['rotationEnabled'] as bool? ?? false;

    final homeFolderPath = savedFolders.isEmpty ? '' : savedFolders.first;

    final homeImageCount = homeFolderPath.isEmpty
        ? 0
        : ScannerService.scanImages(homeFolderPath).length;

    final lockImageCount = savedLockFolderPath.isEmpty
        ? 0
        : ScannerService.scanImages(savedLockFolderPath).length;

    final loadedMode = WallpaperMode.fromLabel(savedWallpaperMode);
    final loadedInterval = IntervalOption.fromLabel(savedInterval);

    return AndroidRotationSettings.initial().copyWith(
      wallpaperMode: AndroidEntitlementService.normalizeMode(loadedMode),
      homeFolderPath: homeFolderPath,
      homeImageCount: homeImageCount,
      interval: AndroidEntitlementService.normalizeInterval(loadedInterval),
      rotationEnabled: savedRotationEnabled,
      lockFolderPath: savedLockFolderPath,
      lockImageCount: lockImageCount,
    );
  }
}
