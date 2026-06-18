import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'services/wallpaper_service.dart';
import 'services/scanner_service.dart';
import 'services/settings_service.dart';
import 'services/randomizer_service.dart';
import 'widgets/preview_section.dart';
import 'widgets/folder_section.dart';

void main() {
  runApp(const WallpaperRotatorApp());
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
    saveSettings();
  });

  rotationTimer = Timer.periodic(getIntervalDuration(), (timer) {
    pickRandomWallpaper();

    if (selectedImagePath.isNotEmpty) {
      WallpaperService.setWindowsWallpaper(selectedImagePath);
    }
  });
}

void stopRotation() {
  rotationTimer?.cancel();

  setState(() {
    rotationEnabled = false;
    saveSettings();
  });
}

void scanFolder(String folderPath) {
  final imageFiles = ScannerService.scanImages(folderPath);

  setState(() {
    selectedFolder = folderPath;
    imageCount = imageFiles.length;
    wallpaperFiles = imageFiles;
  });

  pickRandomWallpaper();
}

Future<void> saveSettings() async {
  await SettingsService.saveSettings(
    selectedFolder: selectedFolder,
    interval: interval,
    rotationEnabled: rotationEnabled,
  );
}

Future<void> loadSettings() async {
  final settings = await SettingsService.loadSettings();

  final savedFolder = settings['selectedFolder'] as String?;
  final savedInterval = settings['interval'] as String?;
  final savedRotationEnabled = settings['rotationEnabled'] as bool;

  if (savedFolder == null) return;

  setState(() {
    interval = savedInterval ?? '1 hour';
  });

  scanFolder(savedFolder);

  if (savedRotationEnabled) {
    startRotation();
  }
}

@override
void dispose() {
  rotationTimer?.cancel();
  super.dispose();
}

void pickRandomWallpaper() {
  final randomImage = RandomizerService.pickRandomWallpaper(
    wallpaperFiles,
    lastImagePath,
  );

  if (randomImage.isEmpty) return;

  setState(() {
    selectedImagePath = randomImage;
    selectedImage = randomImage;
    lastImagePath = randomImage;
  });
}

@override
void initState() {
  super.initState();
  loadSettings();
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
            FolderSection(
              selectedFolder: selectedFolder,
              imageCount: imageCount,
              onSelectFolder: () async {
                final folderPath = await FilePicker.platform.getDirectoryPath();

                if (folderPath == null) return;

                scanFolder(folderPath);
                saveSettings();
              },
            ),

            Expanded(
              child: PreviewSection(
                selectedImagePath: selectedImagePath,
              ),
            ),

            ElevatedButton(
              onPressed: wallpaperFiles.isEmpty ? null : pickRandomWallpaper,
              child: const Text('Next Wallpaper'),
            ),

            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: selectedImagePath.isEmpty
                  ? null
                  : () {
                      WallpaperService.setWindowsWallpaper(selectedImagePath);
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
                saveSettings();
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
              onPressed: wallpaperFiles.isEmpty
                  ? null
                  : rotationEnabled
                      ? stopRotation
                      : startRotation,
              child: Text(rotationEnabled ? 'Stop Rotation' : 'Start Rotation'),
            ),
          ],
        ),
      ),
    );
  }
}