import 'dart:io';

class StartupService {
  static const String appName = 'WallpaperRotator';

  static Future<void> enableStartup() async {
    if (!Platform.isWindows) return;

    final exePath = Platform.resolvedExecutable;

    await Process.run(
      'reg',
      [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        appName,
        '/t',
        'REG_SZ',
        '/d',
        '"$exePath"',
        '/f',
      ],
    );
  }

  static Future<void> disableStartup() async {
    if (!Platform.isWindows) return;

    await Process.run(
      'reg',
      [
        'delete',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        appName,
        '/f',
      ],
    );
  }

  static Future<bool> isStartupEnabled() async {
    if (!Platform.isWindows) return false;

    final result = await Process.run(
      'reg',
      [
        'query',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        appName,
      ],
    );

    return result.exitCode == 0;
  }
}