import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static Future<void> saveSettings({
    required List<String> targetFolders,
    required List<String> selectedImages,
    required String globalFitMode,
    required String interval,
    required bool rotationEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList('targetFolders', targetFolders);
    await prefs.setStringList('selectedImages', selectedImages);
    await prefs.setString('globalFitMode', globalFitMode);
    await prefs.setString('interval', interval);
    await prefs.setBool('rotationEnabled', rotationEnabled);
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedImages = prefs.getStringList('selectedImages') ?? [];

    return {
      'targetFolders': prefs.getStringList('targetFolders') ?? [],
      'globalFitMode': prefs.getString('globalFitMode') ?? 'Fit',
      'interval': prefs.getString('interval'),
      'rotationEnabled': prefs.getBool('rotationEnabled') ?? false,
      'selectedImages': selectedImages,
    };
  }
}
