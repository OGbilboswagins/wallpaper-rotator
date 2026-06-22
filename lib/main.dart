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
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'services/entitlement_service.dart';
import 'services/startup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);

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

class _HomePageState extends State<HomePage> with WindowListener {
  String interval = '4 hours';
  bool rotationEnabled = false;
  bool launchOnStartup = false;
  String globalFitMode = 'Fit';
  Timer? rotationTimer;
  List<WallpaperTarget> targets = [];
  final SystemTray systemTray = SystemTray();
  
  Future<void> initSystemTray() async {
    await systemTray.initSystemTray(
      iconPath: 'assets/icons/tray_icon_dark.ico',
      toolTip: 'Wallpaper Rotator',
    );

    systemTray.registerSystemTrayEventHandler((eventName) async {
      debugPrint('Tray event: $eventName');

      if (eventName == kSystemTrayEventClick) {
        await windowManager.show();
        await windowManager.focus();
      } else if (eventName == kSystemTrayEventRightClick) {
        await systemTray.popUpContextMenu();
      }
    });

    final menu = Menu();

    await menu.buildFrom([
      MenuItemLabel(
        label: 'Show App',
        onClicked: (menuItem) async {
          await windowManager.show();
          await windowManager.focus();
        },
      ),

      MenuItemLabel(
        label: 'Next Wallpaper',
        onClicked: (menuItem) {
          nextWallpaperAllMonitors();
        },
      ),

      MenuItemLabel(
        label: 'Start Rotation',
        onClicked: (menuItem) {
          if (!rotationEnabled) {
            startRotation();
          }
        },
      ),

      MenuItemLabel(
        label: 'Stop Rotation',
        onClicked: (menuItem) {
          if (rotationEnabled) {
            stopRotation();
          }
        },
      ),

      MenuSeparator(),
      MenuItemLabel(
        label: 'Quit',
        onClicked: (menuItem) async {
          rotationTimer?.cancel();
          await systemTray.destroy();
          exit(0);
        },
      ),
    ]);

    await systemTray.setContextMenu(menu);
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  void initializeTargets() {
    final monitorCount = WallpaperService.getWindowsMonitorCount();

    final detectedCount = monitorCount == 0 ? 1 : monitorCount;
    final allowedCount = detectedCount > EntitlementService.maxTargets
        ? EntitlementService.maxTargets
        : detectedCount;

    setState(() {
      targets = List.generate(
        allowedCount,
        (index) => WallpaperTarget(name: 'Monitor ${index + 1}'),
      );
    });
  }

  Duration getIntervalDuration() {
    return EntitlementService.durationFromLabel(interval);
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

void nextWallpaperAllMonitors() {
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
    interval = EntitlementService.normalizeInterval(savedInterval ?? '4 hours');
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
  windowManager.removeListener(this);
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
  windowManager.addListener(this);
  initializeTargets();
  loadSettings();
  StartupService.isStartupEnabled().then((enabled) {
    if (!mounted) return;

    setState(() {
      launchOnStartup = enabled;
    });
  });
  initSystemTray();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VPP Wallpaper Rotator'),
      ),
      body: SingleChildScrollView(
        child: Padding(
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
              launchOnStartup: launchOnStartup,
              onStartupChanged: (value) async {
                if (value) {
                  await StartupService.enableStartup();
                } else {
                  await StartupService.disableStartup();
                }

                setState(() {
                  launchOnStartup = value;
                });
              },

              interval: interval,
              allowedIntervals: EntitlementService.allowedIntervals,
              onIntervalChanged: (value) {
                if (value == null) return;

                setState(() {
                  interval = EntitlementService.normalizeInterval(value);
                });

                saveSettings();
              },
              
              rotationEnabled: rotationEnabled,
              onRotationChanged: (value) {
                if (value) {
                  startRotation();
                } else {
                  stopRotation();
                }
              },

              globalFitMode: globalFitMode,
              onFitModeChanged: (value) {
                if (value == null) return;

                setState(() {
                  globalFitMode = value;
                });

                saveSettings();
              },
            ),          

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
      ),
    );
  }
}
