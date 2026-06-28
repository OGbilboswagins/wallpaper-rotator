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
  String folderPath = '';
  int imageCount = 0;
  bool rotationEnabled = false;
  String interval = '4 hours';
  bool showAdvanced = false;
  bool isApplying = false;

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

  Future<void> chooseFolder() async {
    final selectedFolder = await FilePicker.platform.getDirectoryPath();

    if (selectedFolder == null) return;

    final hasPermission = await ensureAndroidImagePermission();
    if (!hasPermission) return;

    final images = ScannerService.scanImages(selectedFolder);

    setState(() {
      folderPath = selectedFolder;
      imageCount = images.length;
    });

    await SettingsService.saveSettings(
      targetFolders: [folderPath],
      selectedImages: [''],
      globalFitMode: 'Fit',
      interval: interval,
      rotationEnabled: rotationEnabled,
    );
  }

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final settings = await SettingsService.loadSettings();

    final savedFolders = settings['targetFolders'] as List<String>;
    final savedInterval = settings['interval'] as String? ?? '4 hours';
    final savedRotationEnabled = settings['rotationEnabled'] as bool? ?? false;

    if (savedFolders.isEmpty || savedFolders.first.isEmpty) {
      setState(() {
        interval = savedInterval;
        rotationEnabled = savedRotationEnabled;
      });
      return;
    }

    final savedFolder = savedFolders.first;
    final images = ScannerService.scanImages(savedFolder);

    setState(() {
      folderPath = savedFolder;
      imageCount = images.length;
      interval = savedInterval;
      rotationEnabled = savedRotationEnabled;
    });
  }

  Future<void> toggleRotation(bool value) async {
    if (folderPath.isEmpty) return;

    if (value) {
      await Permission.notification.request();

      await WallpaperService.startAndroidRotationService(
        folderPath: folderPath,
        intervalSeconds: getIntervalSeconds(),
      );
    } else {
      await WallpaperService.stopAndroidRotationService();
    }

    setState(() {
      rotationEnabled = value;
    });

    await SettingsService.saveSettings(
      targetFolders: [folderPath],
      selectedImages: [''],
      globalFitMode: 'Fit',
      interval: interval,
      rotationEnabled: rotationEnabled,
    );
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
          _FolderCard(
            folderPath: folderPath,
            imageCount: imageCount,
            onChooseFolder: chooseFolder,
          ),
          const SizedBox(height: 16),
          _RotationCard(
            rotationEnabled: rotationEnabled,
            interval: interval,
            intervals: intervals,
            onRotationChanged: toggleRotation,
            onIntervalChanged: (value) {
              if (value == null) return;

              setState(() {
                interval = value;
              });
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: isApplying ? null : () {},
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

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folderPath,
    required this.imageCount,
    required this.onChooseFolder,
  });

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
            Text(
              'Wallpaper Folder',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
