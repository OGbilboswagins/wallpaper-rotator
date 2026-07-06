import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

class WallpaperService {
  static const MethodChannel _androidWallpaperChannel = MethodChannel(
    'vpp_wallpaper_rotator/wallpaper',
  );

  static void setWindowsWallpaper(String imagePath) {
    if (!Platform.isWindows) return;

    const int spiSetDeskWallpaper = 20;
    const int spifUpdateIniFile = 0x01;
    const int spifSendChange = 0x02;

    final user32 = DynamicLibrary.open('user32.dll');

    final systemParametersInfo = user32
        .lookupFunction<
          Int32 Function(Uint32, Uint32, Pointer<Utf16>, Uint32),
          int Function(int, int, Pointer<Utf16>, int)
        >('SystemParametersInfoW');

    final pathPointer = imagePath.toNativeUtf16();

    systemParametersInfo(
      spiSetDeskWallpaper,
      0,
      pathPointer,
      spifUpdateIniFile | spifSendChange,
    );

    calloc.free(pathPointer);
  }

  static int getWindowsMonitorCount() {
    if (!Platform.isWindows) return 0;

    final exe = DynamicLibrary.executable();

    final getMonitorCount = exe
        .lookupFunction<Int32 Function(), int Function()>('GetMonitorCount');

    return getMonitorCount();
  }

  static int _fitModeToInt(String fitMode) {
    switch (fitMode) {
      case 'Fill':
        return 1;
      case 'Stretch':
        return 2;
      case 'Center':
        return 3;
      case 'Fit':
      default:
        return 0;
    }
  }

  static int applyMonitorWallpaper({
    required int monitorIndex,
    required String imagePath,
    required String fitMode,
  }) {
    if (!Platform.isWindows) return -99;

    final exe = DynamicLibrary.executable();

    final applyMonitorWallpaper = exe
        .lookupFunction<
          Int32 Function(Int32, Pointer<Utf16>, Int32),
          int Function(int, Pointer<Utf16>, int)
        >('ApplyMonitorWallpaper');

    final pathPointer = imagePath.toNativeUtf16();

    final result = applyMonitorWallpaper(
      monitorIndex,
      pathPointer,
      _fitModeToInt(fitMode),
    );

    calloc.free(pathPointer);

    return result;
  }

  static Future<String> applyWallpaper({
    required int monitorIndex,
    required String imagePath,
    required String fitMode,
    String wallpaperMode = 'Home Only',
  }) async {
    if (Platform.isAndroid) {
      final result = await _androidWallpaperChannel.invokeMethod<String>(
        'setHomeWallpaper',
        {'path': imagePath, 'mode': wallpaperMode},
      );

      return result ?? 'Android wallpaper set';
    }

    if (Platform.isWindows) {
      final result = applyMonitorWallpaper(
        monitorIndex: monitorIndex,
        imagePath: imagePath,
        fitMode: fitMode,
      );

      return 'Windows wallpaper result: $result';
    }

    return 'Unsupported platform';
  }

  static Future<void> moveAndroidAppToBackground() async {
    if (!Platform.isAndroid) return;

    await _androidWallpaperChannel.invokeMethod<String>('moveToBackground');
  }

  static Future<void> startAndroidRotationService({
    required String folderPath,
    required int intervalSeconds,
    required String wallpaperMode,
    String lockFolderPath = '',
  }) async {
    if (!Platform.isAndroid) return;

    await _androidWallpaperChannel
        .invokeMethod<String>('startRotationService', {
          'folderPath': folderPath,
          'lockFolderPath': lockFolderPath,
          'intervalSeconds': intervalSeconds,
          'wallpaperMode': wallpaperMode,
        });
  }

  static Future<bool> isAndroidRotationRunning() async {
    if (!Platform.isAndroid) return false;

    final result = await _androidWallpaperChannel.invokeMethod<bool>(
      'isAndroidRotationRunning',
    );

    return result ?? false;
  }

  static Future<void> stopAndroidRotationService() async {
    if (!Platform.isAndroid) return;

    await _androidWallpaperChannel.invokeMethod<String>('stopRotationService');
  }
}
