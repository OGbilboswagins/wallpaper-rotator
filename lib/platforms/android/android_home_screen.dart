import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/scanner_service.dart';
import '../../services/settings_service.dart';
import '../../services/wallpaper_service.dart';

class AndroidHomeScreen extends StatefulWidget {
  const AndroidHomeScreen({super.key});

  @override
  State<AndroidHomeScreen> createState() => _AndroidHomeScreenState();
}

class _AndroidHomeScreenState extends State<AndroidHomeScreen> {
  String homeFolderPath = '';
  String lockFolderPath = '';

  int homeImageCount = 0;
  int lockImageCount = 0;
  bool rotationEnabled = false;
  String interval = '4 hours';
  bool showAdvanced = false;
  bool isApplying = false;
  String wallpaperMode = 'Home Only';

  final List<String> wallpaperModes = const [
    'Home Only',
    'Lock Only',
    'Both Shared',
    'Both Separate',
  ];

  final List<String> intervals = const [
    '30 seconds',
    '1 minute',
    '15 minutes',
    '30 minutes',
    '1 hour',
    '4 hours',
    'Daily',
  ];

  int getIntervalSeconds() {
    switch (interval) {
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
        return 14400;
    }
  }

  bool get usesHomeFolder =>
      wallpaperMode == 'Home Only' ||
      wallpaperMode == 'Both Shared' ||
      wallpaperMode == 'Both Separate';

  bool get usesLockFolder =>
      wallpaperMode == 'Lock Only' || wallpaperMode == 'Both Separate';

  String get activeFolderPath {
    if (wallpaperMode == 'Lock Only') return lockFolderPath;
    return homeFolderPath;
  }

  int get activeImageCount {
    if (wallpaperMode == 'Lock Only') return lockImageCount;
    return homeImageCount;
  }

  String get statusText => rotationEnabled ? 'Running' : 'Stopped';

  Future<bool> ensureAndroidImagePermission() async {
    final status = await Permission.photos.request();

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }

    return false;
  }

  Future<void> saveAndroidSettings() async {
    await SettingsService.saveSettings(
      targetFolders: [homeFolderPath],
      lockFolderPath: lockFolderPath,
      selectedImages: [''],
      globalFitMode: 'Fit',
      interval: interval,
      rotationEnabled: rotationEnabled,
      wallpaperMode: wallpaperMode,
    );
  }

  List<Widget> buildFolderCards() {
    switch (wallpaperMode) {
      case 'Lock Only':
        return [
          _FolderCard(
            title: 'Lock Folder',
            folderPath: lockFolderPath,
            imageCount: lockImageCount,
            onChooseFolder: () => chooseFolder(forLockScreen: true),
          ),
        ];

      case 'Both Shared':
        return [
          _FolderCard(
            title: 'Home + Lock Folder',
            folderPath: homeFolderPath,
            imageCount: homeImageCount,
            onChooseFolder: () => chooseFolder(forLockScreen: false),
          ),
        ];

      case 'Both Separate':
        return [
          _FolderCard(
            title: 'Home Folder',
            folderPath: homeFolderPath,
            imageCount: homeImageCount,
            onChooseFolder: () => chooseFolder(forLockScreen: false),
          ),
          const SizedBox(height: 16),
          _FolderCard(
            title: 'Lock Folder',
            folderPath: lockFolderPath,
            imageCount: lockImageCount,
            onChooseFolder: () => chooseFolder(forLockScreen: true),
          ),
        ];

      case 'Home Only':
      default:
        return [
          _FolderCard(
            title: 'Home Folder',
            folderPath: homeFolderPath,
            imageCount: homeImageCount,
            onChooseFolder: () => chooseFolder(forLockScreen: false),
          ),
        ];
    }
  }

  Future<void> chooseFolder({required bool forLockScreen}) async {
    final selectedFolder = await FilePicker.platform.getDirectoryPath();

    if (selectedFolder == null) return;

    final hasPermission = await ensureAndroidImagePermission();
    if (!hasPermission) return;

    final images = ScannerService.scanImages(selectedFolder);

    setState(() {
      if (forLockScreen) {
        lockFolderPath = selectedFolder;
        lockImageCount = images.length;
      } else {
        homeFolderPath = selectedFolder;
        homeImageCount = images.length;
      }
    });

    await saveAndroidSettings();
  }

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> updateWallpaperMode(String? value) async {
    if (value == null) return;

    setState(() {
      wallpaperMode = value;
    });

    await SettingsService.saveSettings(
      targetFolders: [activeFolderPath],
      lockFolderPath: lockFolderPath,
      selectedImages: [''],
      globalFitMode: 'Fit',
      interval: interval,
      rotationEnabled: rotationEnabled,
      wallpaperMode: wallpaperMode,
    );
  }

  Future<void> loadSettings() async {
    final settings = await SettingsService.loadSettings();
    final savedWallpaperMode =
        settings['wallpaperMode'] as String? ?? 'Home Only';
    final savedLockFolderPath = settings['lockFolderPath'] as String? ?? '';

    final savedFolders = settings['targetFolders'] as List<String>;
    final savedInterval = settings['interval'] as String? ?? '4 hours';
    final savedRotationEnabled = settings['rotationEnabled'] as bool? ?? false;

    if (savedFolders.isEmpty || savedFolders.first.isEmpty) {
      setState(() {
        wallpaperMode = savedWallpaperMode;
        interval = savedInterval;
        rotationEnabled = savedRotationEnabled;
      });
      return;
    }

    final savedFolder = savedFolders.first;
    final images = ScannerService.scanImages(savedFolder);

    int restoredLockCount = 0;

    if (savedLockFolderPath.isNotEmpty) {
      restoredLockCount = ScannerService.scanImages(savedLockFolderPath).length;
    }

    setState(() {
      wallpaperMode = savedWallpaperMode;
      homeFolderPath = savedFolder;
      homeImageCount = images.length;
      interval = savedInterval;
      rotationEnabled = savedRotationEnabled;
      lockFolderPath = savedLockFolderPath;
      lockImageCount = restoredLockCount;
    });
  }

  Future<void> toggleRotation(bool value) async {
    if (activeFolderPath.isEmpty) return;

    if (value) {
      await Permission.notification.request();

      await WallpaperService.startAndroidRotationService(
        folderPath: activeFolderPath,
        intervalSeconds: getIntervalSeconds(),
        wallpaperMode: wallpaperMode,
      );
    } else {
      await WallpaperService.stopAndroidRotationService();
    }

    setState(() {
      rotationEnabled = value;
    });

    await SettingsService.saveSettings(
      targetFolders: [activeFolderPath],
      lockFolderPath: lockFolderPath,
      selectedImages: [''],
      globalFitMode: 'Fit',
      interval: interval,
      rotationEnabled: rotationEnabled,
      wallpaperMode: wallpaperMode,
    );
  }

  Future<void> changeNow() async {
    if (activeFolderPath.isEmpty || activeImageCount == 0 || isApplying) return;

    setState(() {
      isApplying = true;
    });

    try {
      final images = ScannerService.scanImages(activeFolderPath);
      if (images.isEmpty) return;

      images.shuffle();
      final imagePath = images.first.path;

      await WallpaperService.applyWallpaper(
        monitorIndex: 0,
        imagePath: imagePath,
        fitMode: 'Fit',
        wallpaperMode: wallpaperMode,
      );
    } finally {
      if (mounted) {
        setState(() {
          isApplying = false;
        });
      }
    }
  }

  Future<void> updateInterval(String? value) async {
    if (value == null) return;

    setState(() {
      interval = value;
    });

    await SettingsService.saveSettings(
      targetFolders: [activeFolderPath],
      lockFolderPath: lockFolderPath,
      selectedImages: [''],
      globalFitMode: 'Fit',
      interval: interval,
      rotationEnabled: rotationEnabled,
      wallpaperMode: wallpaperMode,
    );

    if (rotationEnabled && activeFolderPath.isNotEmpty) {
      await WallpaperService.startAndroidRotationService(
        folderPath: activeFolderPath,
        intervalSeconds: getIntervalSeconds(),
        wallpaperMode: wallpaperMode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpaper Rotator'),
        actions: [
          IconButton(
            tooltip: 'More',
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(statusText: statusText, rotationEnabled: rotationEnabled),
          const SizedBox(height: 16),
          _ModeCard(
            mode: wallpaperMode,
            modes: wallpaperModes,
            onModeChanged: updateWallpaperMode,
          ),
          const SizedBox(height: 16),
          ...buildFolderCards(),
          const SizedBox(height: 16),
          _RotationCard(
            rotationEnabled: rotationEnabled,
            interval: interval,
            intervals: intervals,
            onRotationChanged: toggleRotation,
            onIntervalChanged: updateInterval,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed:
                activeFolderPath.isEmpty || activeImageCount == 0 || isApplying
                ? null
                : changeNow,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(isApplying ? 'Applying...' : 'Change Now'),
            ),
          ),
          const SizedBox(height: 16),
          _AdvancedCard(
            expanded: showAdvanced,
            onToggle: () {
              setState(() {
                showAdvanced = !showAdvanced;
              });
            },
          ),
          if (!Platform.isAndroid)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text(
                'This screen is intended for Android only.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.statusText, required this.rotationEnabled});

  final String statusText;
  final bool rotationEnabled;

  @override
  Widget build(BuildContext context) {
    final color = rotationEnabled ? Colors.green : Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.circle, size: 14, color: color),
            const SizedBox(width: 12),
            Text(
              'Status: $statusText',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.modes,
    required this.onModeChanged,
  });

  final String mode;
  final List<String> modes;
  final ValueChanged<String?> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<String>(
          initialValue: mode,
          decoration: const InputDecoration(labelText: 'Mode'),
          items: modes
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: onModeChanged,
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.title,
    required this.folderPath,
    required this.imageCount,
    required this.onChooseFolder,
  });

  final String title;
  final String folderPath;
  final int imageCount;
  final VoidCallback onChooseFolder;

  String displayPath(String path) {
    if (path.length <= 32) return path;
    return '...${path.substring(path.length - 32)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasFolder = folderPath.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              hasFolder ? displayPath(folderPath) : 'No folder selected',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (hasFolder) ...[
              const SizedBox(height: 8),
              Text('Images Found: $imageCount'),
            ],
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onChooseFolder,
              child: Text(hasFolder ? 'Change Folder' : 'Choose Folder'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RotationCard extends StatelessWidget {
  const _RotationCard({
    required this.rotationEnabled,
    required this.interval,
    required this.intervals,
    required this.onRotationChanged,
    required this.onIntervalChanged,
  });

  final bool rotationEnabled;
  final String interval;
  final List<String> intervals;
  final ValueChanged<bool> onRotationChanged;
  final ValueChanged<String?> onIntervalChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rotation Enabled'),
              subtitle: rotationEnabled
                  ? const Text('Rotation service is running')
                  : const Text('Rotation service is stopped'),
              value: rotationEnabled,
              onChanged: onRotationChanged,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: interval,
              decoration: const InputDecoration(labelText: 'Change Every'),
              items: intervals
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: onIntervalChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedCard extends StatelessWidget {
  const _AdvancedCard({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Advanced'),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
          if (expanded) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.battery_alert_outlined),
              title: const Text('Battery Optimization Help'),
              subtitle: const Text(
                'Recommended for reliable background rotation',
              ),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Lock Screen Rotation'),
              subtitle: const Text('Coming later'),
              enabled: false,
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              subtitle: const Text('Version 1.0.0'),
              onTap: () {},
            ),
          ],
        ],
      ),
    );
  }
}
