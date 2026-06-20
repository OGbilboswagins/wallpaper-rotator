import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'services/wallpaper_service.dart';
import 'services/scanner_service.dart';
import 'services/settings_service.dart';
import 'services/randomizer_service.dart';
import 'widgets/monitor_card.dart';
import 'widgets/wallpaper_controls.dart';
import 'widgets/rotation_settings.dart';
import 'models/wallpaper_target.dart';

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
  String interval = '1 hour';
  bool rotationEnabled = false;
  String globalFitMode = 'Fit';
  Timer? rotationTimer;
  List<WallpaperTarget> targets = [];
  
  void initializeTargets() {
  final monitorCount = WallpaperService.getWindowsMonitorCount();

  setState(() {
    targets = List.generate(
      monitorCount == 0 ? 1 : monitorCount,
      (index) => WallpaperTarget(name: 'Monitor ${index + 1}'),
    );
  });
}

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
  if (targets.isEmpty) return;

  rotationTimer?.cancel();

  setState(() {
    rotationEnabled = true;
  });

  saveSettings();

  rotationTimer = Timer.periodic(getIntervalDuration(), (timer) {
    for (int i = 0; i < targets.length; i++) {
      if (targets[i].files.isEmpty) continue;

      pickRandomWallpaperForTarget(i);

      if (targets[i].selectedImagePath.isEmpty) continue;

      final result = WallpaperService.applyMonitorWallpaper(
        monitorIndex: i,
        imagePath: targets[i].selectedImagePath,
        fitMode: globalFitMode,
      );

      debugPrint('Monitor $i result: $result');
    }
  });
}

void stopRotation() {
  rotationTimer?.cancel();

  setState(() {
    rotationEnabled = false;
  });

  saveSettings();
}

void scanFolderForTarget(int targetIndex, String folderPath) {
  final imageFiles = ScannerService.scanImages(folderPath);

  setState(() {
    targets[targetIndex].folderPath = folderPath;
    targets[targetIndex].files = imageFiles;
  });

  pickRandomWallpaperForTarget(targetIndex);
}

Future<void> saveSettings() async {
  await SettingsService.saveSettings(
    targetFolders: targets.map((target) => target.folderPath).toList(),
    globalFitMode: globalFitMode,
    interval: interval,
    rotationEnabled: rotationEnabled,
  );
}

Future<void> loadSettings() async {
  final settings = await SettingsService.loadSettings();

  final savedFolders = settings['targetFolders'] as List<String>;
  final savedGlobalFitMode = settings['globalFitMode'] as String;
  final savedInterval = settings['interval'] as String?;
  final savedRotationEnabled = settings['rotationEnabled'] as bool;

  setState(() {
    interval = savedInterval ?? '1 hour';
    globalFitMode = savedGlobalFitMode;
  });

  for (int i = 0; i < savedFolders.length && i < targets.length; i++) {
    final folder = savedFolders[i];

    if (folder.isNotEmpty) {
      scanFolderForTarget(i, folder);
    }
  }

  if (savedRotationEnabled) {
    startRotation();
  }
}

@override
void dispose() {
  rotationTimer?.cancel();
  super.dispose();
}

void pickRandomWallpaperForTarget(int targetIndex) {
  final target = targets[targetIndex];

  final randomImage = RandomizerService.pickRandomWallpaper(
    target.files,
    target.lastImagePath,
  );

  if (randomImage.isEmpty) return;

  setState(() {
    target.selectedImagePath = randomImage;
    target.lastImagePath = randomImage;
  });
}

@override
void initState() {
  super.initState();
  initializeTargets();
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
            for (int i = 0; i < targets.length; i++)
              MonitorCard(
                targetName: targets[i].name,
                selectedFolder: targets[i].folderPath.isEmpty
                    ? 'No folder selected'
                    : targets[i].folderPath,
                imageCount: targets[i].files.length,
                onSelectFolder: () async {
                  final folderPath = await FilePicker.platform.getDirectoryPath();

                  if (folderPath == null) return;

                  scanFolderForTarget(i, folderPath);
                  saveSettings();
                },
                selectedImagePath: targets[i].selectedImagePath,
              ),

            RotationSettings(
              interval: interval,
              rotationEnabled: rotationEnabled,
              globalFitMode: globalFitMode,
              onFitModeChanged: (value) {
                if (value == null) return;

                setState(() {
                  globalFitMode = value;
                });

                saveSettings();
              },

              onIntervalChanged: (value) {
                if (value == null) return;

                setState(() {
                  interval = value;
                });

                saveSettings();
              },
              onRotationChanged: (value) {
                setState(() {
                  rotationEnabled = value;
                });
              },
            ),

            const Spacer(),

            WallpaperControls(
              hasWallpapers: targets[0].files.isNotEmpty,
              hasSelectedImage: targets[0].selectedImagePath.isNotEmpty,
              rotationEnabled: rotationEnabled,
              onNextWallpaper: () => pickRandomWallpaperForTarget(0),
              onSetWallpaper: () {
                for (int i = 0; i < targets.length; i++) {
                  if (targets[i].selectedImagePath.isEmpty) continue;

                  final result = WallpaperService.applyMonitorWallpaper(
                    monitorIndex: i,
                    imagePath: targets[i].selectedImagePath,
                    fitMode: globalFitMode,
                  );

                  debugPrint('Monitor $i result: $result');
                }
              },
              onStartRotation: startRotation,
              onStopRotation: stopRotation,
            ),
          ],
        ),
      ),
    );
  }
}
