import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static Future<void> saveSettings({
    required String wallpaperMode,
    required List<String> targetFolders,
    required List<String> selectedImages,
    required String globalFitMode,
    required String interval,
    required bool rotationEnabled,
    required String lockFolderPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('wallpaperMode', wallpaperMode);
    await prefs.setStringList('targetFolders', targetFolders);
    await prefs.setString(
      'androidFolderPath',
      targetFolders.isNotEmpty ? targetFolders.first : '',
    );
    await prefs.setStringList('selectedImages', selectedImages);
    await prefs.setString('globalFitMode', globalFitMode);
    await prefs.setString('interval', interval);
    await prefs.setBool('rotationEnabled', rotationEnabled);
    await prefs.setString('lockFolderPath', lockFolderPath);
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedImages = prefs.getStringList('selectedImages') ?? [];
    final lastAppliedWallpaperPath =
        prefs.getString('lastAppliedWallpaperPath') ?? '';

    return {
      'wallpaperMode': prefs.getString('wallpaperMode') ?? 'Home Only',
      'targetFolders': prefs.getStringList('targetFolders') ?? [],
      'globalFitMode': prefs.getString('globalFitMode') ?? 'Fit',
      'interval': prefs.getString('interval'),
      'rotationEnabled': prefs.getBool('rotationEnabled') ?? false,
      'selectedImages': selectedImages,
      'lastAppliedWallpaperPath': lastAppliedWallpaperPath,
      'androidFolderPath': prefs.getString('androidFolderPath') ?? '',
      'lockFolderPath': prefs.getString('lockFolderPath') ?? '',
    };
  }
}
