import 'dart:ffi';
import 'package:ffi/ffi.dart';

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
}