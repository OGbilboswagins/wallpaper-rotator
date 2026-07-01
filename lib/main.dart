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
import 'package:permission_handler/permission_handler.dart';
import 'platforms/android/android_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
  }

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
      home: Platform.isAndroid ? const AndroidHomeScreen() : const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WindowListener, WidgetsBindingObserver {
  String interval = '4 hours';
  bool rotationEnabled = false;
  bool launchOnStartup = false;
  bool isApplyingWallpaper = false;
  String globalFitMode = 'Fit';
  Timer? rotationTimer;
  List<WallpaperTarget> targets = [];
  final SystemTray systemTray = SystemTray();
  bool settingsLoaded = false;
  //  DateTime? _resumeStartedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('Lifecycle state: $state at ${DateTime.now()}');

    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed');
    }
  }

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
        onClicked: (menuItem) async {
          await nextWallpaperAllMonitors();
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
    if (Platform.isAndroid) {
      targets = [WallpaperTarget(name: 'Home Screen')];
      return;
    }

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

    debugPrint('Rotation started. Interval: $interval');

    rotationTimer = Timer.periodic(getIntervalDuration(), (timer) async {
      debugPrint('Rotation tick: ${DateTime.now()}');

      for (int i = 0; i < targets.length; i++) {
        debugPrint('Checking target $i');

        if (targets[i].files.isEmpty) {
          debugPrint('Target $i skipped: no files');
          continue;
        }

        debugPrint('Rotating target $i');
        await nextAndApplyWallpaperForTarget(i);
        debugPrint('Finished target $i');
      }
    });
  }

  int getIntervalSeconds() {
    switch (interval) {
      case '10 seconds':
        return 10;
      case '30 seconds':
        return 30;
      case '1 minute':
        return 60;
      case '15 minutes':
        return 900;
      case '30 minutes':
        return 1800;
      case '1 hour':
        return 3600;
      case '4 hours':
        return 14400;
      case 'Daily':
        return 86400;
      default:
        return 30;
    }
  }

  Future<void> nextWallpaperAllMonitors() async {
    for (int i = 0; i < targets.length; i++) {
      if (targets[i].files.isEmpty) continue;

      await nextAndApplyWallpaperForTarget(i);
    }
  }

  void stopRotation() {
    debugPrint('Rotation stopped');

    rotationTimer?.cancel();

    setState(() {
      rotationEnabled = false;
    });

    saveSettings();
  }

  Future<bool> ensureAndroidImagePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final status = await Permission.photos.request();

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }

    return false;
  }

  void scanFolderForTarget(
    int targetIndex,
    String folderPath, {
    String preferredSelectedImagePath = '',
  }) {
    final stopwatch = Stopwatch()..start();
    debugPrint('scanFolderForTarget started: $folderPath');

    final imageFiles = ScannerService.scanImages(folderPath);

    String selectedImagePath = '';

    if (preferredSelectedImagePath.isNotEmpty) {
      final savedImageStillExists = imageFiles.any(
        (file) => file.path == preferredSelectedImagePath,
      );

      if (savedImageStillExists) {
        selectedImagePath = preferredSelectedImagePath;
      }
    }

    if (selectedImagePath.isEmpty && imageFiles.isNotEmpty) {
      selectedImagePath = imageFiles.first.path;
    }

    setState(() {
      targets[targetIndex].folderPath = folderPath;
      targets[targetIndex].files = imageFiles;
      targets[targetIndex].selectedImagePath = selectedImagePath;
      targets[targetIndex].lastImagePath = selectedImagePath;
    });

    stopwatch.stop();
    debugPrint(
      'scanFolderForTarget finished in ${stopwatch.elapsedMilliseconds}ms with ${imageFiles.length} images',
    );
  }

  Future<void> saveSettings() async {
    await SettingsService.saveSettings(
      targetFolders: targets.map((target) => target.folderPath).toList(),
      lockFolderPath: '',
      selectedImages: targets
          .map((target) => target.selectedImagePath)
          .toList(),
      globalFitMode: globalFitMode,
      interval: interval,
      rotationEnabled: rotationEnabled,
      wallpaperMode: 'Home Only',
    );
  }

  Future<void> loadSettings() async {
    final settings = await SettingsService.loadSettings();

    final savedFolders = settings['targetFolders'] as List<String>;
    final savedSelectedImages = settings['selectedImages'] as List<String>;

    final savedGlobalFitMode = settings['globalFitMode'] as String;
    final savedInterval = settings['interval'] as String?;
    final savedRotationEnabled = settings['rotationEnabled'] as bool;
    //    final shouldRestoreRotationEnabled = !Platform.isAndroid;

    setState(() {
      interval = EntitlementService.normalizeInterval(
        savedInterval ?? '4 hours',
      );
      globalFitMode = savedGlobalFitMode;
      rotationEnabled = savedRotationEnabled;
      settingsLoaded = true;
    });

    for (int i = 0; i < savedFolders.length && i < targets.length; i++) {
      final folder = savedFolders[i];

      if (folder.isNotEmpty) {
        final selectedImage = i < savedSelectedImages.length
            ? savedSelectedImages[i]
            : '';

        scanFolderForTarget(
          i,
          folder,
          preferredSelectedImagePath: selectedImage,
        );
      }
    }
  }

  @override
  void dispose() {
    rotationTimer?.cancel();

    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }

    WidgetsBinding.instance.removeObserver(this);

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

  Future<void> applySelectedWallpaperForTarget(int targetIndex) async {
    final target = targets[targetIndex];

    if (target.selectedImagePath.isEmpty) return;

    setState(() {
      isApplyingWallpaper = true;
    });

    try {
      final result = await WallpaperService.applyWallpaper(
        monitorIndex: targetIndex,
        imagePath: target.selectedImagePath,
        fitMode: globalFitMode,
      );

      debugPrint('Target $targetIndex result: $result');
    } finally {
      if (mounted) {
        setState(() {
          isApplyingWallpaper = false;
        });
      }
    }
  }

  Future<void> nextAndApplyWallpaperForTarget(int targetIndex) async {
    pickRandomWallpaperForTarget(targetIndex);
    saveSettings();

    Future.microtask(() async {
      await applySelectedWallpaperForTarget(targetIndex);
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    initializeTargets();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadSettings();
    });

    if (Platform.isWindows) {
      windowManager.addListener(this);

      StartupService.isStartupEnabled().then((enabled) {
        if (!mounted) return;
        setState(() {
          launchOnStartup = enabled;
        });
      });

      initSystemTray();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VPP Wallpaper Rotator')),
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
                    final folderPath = await FilePicker.platform
                        .getDirectoryPath();

                    if (folderPath == null) return;

                    final hasPermission = await ensureAndroidImagePermission();

                    if (!hasPermission) return;

                    scanFolderForTarget(i, folderPath);
                    saveSettings();
                  },
                  selectedImagePath: targets[i].selectedImagePath,
                ),

              RotationSettings(
                showStartupOption: Platform.isWindows,
                showFitMode: Platform.isWindows,
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

                rotationEnabled: settingsLoaded && rotationEnabled,
                onRotationChanged: (value) async {
                  if (!settingsLoaded) return;

                  if (Platform.isAndroid) {
                    if (value) {
                      await Permission.notification.request();

                      await WallpaperService.startAndroidRotationService(
                        wallpaperMode: 'Home Only',
                        folderPath: targets[0].folderPath,
                        intervalSeconds: getIntervalSeconds(),
                      );

                      setState(() {
                        rotationEnabled = true;
                      });

                      await saveSettings();
                    } else {
                      await WallpaperService.stopAndroidRotationService();

                      setState(() {
                        rotationEnabled = false;
                      });

                      await saveSettings();
                    }

                    return;
                  }

                  // Windows only
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

              if (isApplyingWallpaper)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Center(child: Text('Applying wallpaper...')),
                ),

              if (Platform.isAndroid && rotationEnabled)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Center(child: Text('Rotation service is running')),
                ),

              WallpaperControls(
                hasWallpapers:
                    targets[0].files.isNotEmpty && !isApplyingWallpaper,
                hasSelectedImage:
                    targets[0].selectedImagePath.isNotEmpty &&
                    !isApplyingWallpaper,
                onNextWallpaper: () {
                  pickRandomWallpaperForTarget(0);
                  saveSettings();
                },
                onSetWallpaper: () async {
                  for (int i = 0; i < targets.length; i++) {
                    await applySelectedWallpaperForTarget(i);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
