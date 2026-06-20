import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static Future<void> saveSettings({
    required List<String> targetFolders,
    required String interval,
    required bool rotationEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList('targetFolders', targetFolders);
    await prefs.setString('interval', interval);
    await prefs.setBool('rotationEnabled', rotationEnabled);
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'targetFolders': prefs.getStringList('targetFolders') ?? [],
      'interval': prefs.getString('interval'),
      'rotationEnabled': prefs.getBool('rotationEnabled') ?? false,
    };
  }
}