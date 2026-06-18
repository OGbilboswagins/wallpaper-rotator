import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:async';

void main() {
  runApp(const WallpaperRotatorApp());
}

void setWindowsWallpaper(String imagePath) {
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

class WallpaperRotatorApp extends StatelessWidget {
  const WallpaperRotatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper Rotator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selectedFolder = 'No folder selected';
  String interval = '1 hour';
  bool rotationEnabled = false;
  int imageCount = 0;
  String selectedImage = 'No image selected';
  String selectedImagePath = '';
  List<FileSystemEntity> wallpaperFiles = [];
  String lastImagePath = '';
  Timer? rotationTimer;
  Duration getIntervalDuration() {
    switch (interval) {
      case '10 seconds':
        return const Duration(seconds: 10);
      case '30 seconds':
        return const Duration(seconds: 30);
      case '1 minute':
        return const Duration(minutes: 1);
      case '15 minutes':
        return const Duration(minutes: 15);
      case '30 minutes':
        return const Duration(minutes: 30);
      case '1 hour':
        return const Duration(hours: 1);
      case '4 hours':
        return const Duration(hours: 4);
      case 'Daily':
        return const Duration(days: 1);
      default:
        return const Duration(hours: 1);
    }
  }

void startRotation() {
  if (wallpaperFiles.isEmpty) return;

  rotationTimer?.cancel();

  setState(() {
    rotationEnabled = true;
  });

  rotationTimer = Timer.periodic(getIntervalDuration(), (timer) {
    pickRandomWallpaper();

    if (selectedImagePath.isNotEmpty) {
      setWindowsWallpaper(selectedImagePath);
    }
  });
}

@override
void dispose() {
  rotationTimer?.cancel();
  super.dispose();
}

void pickRandomWallpaper() {
  if (wallpaperFiles.isEmpty) return;

  final random = Random();
  String randomImage = wallpaperFiles[random.nextInt(wallpaperFiles.length)].path;

  if (wallpaperFiles.length > 1) {
    while (randomImage == lastImagePath) {
      randomImage = wallpaperFiles[random.nextInt(wallpaperFiles.length)].path;
    }
  }

  setState(() {
    selectedImagePath = randomImage;
    selectedImage = randomImage;
    lastImagePath = randomImage;
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VPP Wallpaper Rotator'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Wallpaper folder',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(selectedFolder),

            const SizedBox(height: 8),

            Text(
              'Images Found: $imageCount',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            if (selectedImagePath.isNotEmpty)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    border: Border.all(),
                  ),
                  child: Image.file(
                    File(selectedImagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            const SizedBox(height: 8),

//            Text('Selected Image: $selectedImage'),
            Text(
              'Selected Image: ${p.basename(selectedImagePath)}',
            ),

            ElevatedButton(
              onPressed: () async {
                final folderPath = await FilePicker.platform.getDirectoryPath();

                if (folderPath == null) return;

                final directory = Directory(folderPath);

                final imageFiles = directory
                    .listSync(recursive: true)
                    .where((file) =>
                        file.path.toLowerCase().endsWith('.jpg') ||
                        file.path.toLowerCase().endsWith('.jpeg') ||
                        file.path.toLowerCase().endsWith('.png') ||
                        file.path.toLowerCase().endsWith('.webp'))
                    .toList();

                setState(() {
                  selectedFolder = folderPath;
                  imageCount = imageFiles.length;
                  wallpaperFiles = imageFiles;
                });

                pickRandomWallpaper();
              },
              child: const Text('Select Folder'),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: wallpaperFiles.isEmpty ? null : pickRandomWallpaper,
              child: const Text('Next Wallpaper'),
            ),

            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: selectedImagePath.isEmpty
                  ? null
                  : () {
                      setWindowsWallpaper(selectedImagePath);
                    },
              child: const Text('Set Windows Wallpaper'),
            ),

            const Text(
              'Rotation interval',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            DropdownButton<String>(
              value: interval,
              items: const [
                DropdownMenuItem(value: '10 seconds', child: Text('10 seconds')),
                DropdownMenuItem(value: '30 seconds', child: Text('30 seconds')),
                DropdownMenuItem(value: '1 minute', child: Text('1 minute')),
                DropdownMenuItem(value: '15 minutes', child: Text('15 minutes')),
                DropdownMenuItem(value: '30 minutes', child: Text('30 minutes')),
                DropdownMenuItem(value: '1 hour', child: Text('1 hour')),
                DropdownMenuItem(value: '4 hours', child: Text('4 hours')),
                DropdownMenuItem(value: 'Daily', child: Text('Daily')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  interval = value;
                });
              },
            ),

            const SizedBox(height: 30),

            SwitchListTile(
              title: const Text('Rotation enabled'),
              value: rotationEnabled,
              onChanged: (value) {
                setState(() {
                  rotationEnabled = value;
                });
              },
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: wallpaperFiles.isEmpty ? null : startRotation,
              child: const Text('Start Rotation'),
            ),
          ],
        ),
      ),
    );
  }
}