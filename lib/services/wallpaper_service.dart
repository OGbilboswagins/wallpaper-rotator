import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';

class WallpaperService {
  static void setWindowsWallpaper(String imagePath) {
    const int spiSetDeskWallpaper = 20;
    const int spifUpdateIniFile = 0x01;
    const int spifSendChange = 0x02;

    final user32 = DynamicLibrary.open('user32.dll');

    final systemParametersInfo = user32.lookupFunction<
        Int32 Function(Uint32, Uint32, Pointer<Utf16>, Uint32),
        int Function(int, int, Pointer<Utf16>, int)>('SystemParametersInfoW');

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

    final getMonitorCount = exe.lookupFunction<
        Int32 Function(),
        int Function()>('GetMonitorCount');

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

    final applyMonitorWallpaper = exe.lookupFunction<
        Int32 Function(Int32, Pointer<Utf16>, Int32),
        int Function(int, Pointer<Utf16>, int)>('ApplyMonitorWallpaper');

    final pathPointer = imagePath.toNativeUtf16();

    final result = applyMonitorWallpaper(
      monitorIndex,
      pathPointer,
      _fitModeToInt(fitMode),
    );

    calloc.free(pathPointer);

    return result;
  }
}