import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/rotation_settings.dart';
import 'services/android_rotation_controller.dart';
import 'services/android_settings_store.dart';
import '../../services/wallpaper_service.dart';
import 'services/android_entitlement_service.dart';
import '../../services/billing/billing_service.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AndroidHomeScreen extends StatefulWidget {
  const AndroidHomeScreen({super.key});

  @override
  State<AndroidHomeScreen> createState() => _AndroidHomeScreenState();
}

class _AndroidHomeScreenState extends State<AndroidHomeScreen>
    with WidgetsBindingObserver {
  AndroidRotationSettings settings = AndroidRotationSettings.initial();

  bool showAdvanced = false;
  bool isApplying = false;

  String get homeFolderPath => settings.homeFolderPath;
  String get lockFolderPath => settings.lockFolderPath;
  int get homeImageCount => settings.homeImageCount;
  int get lockImageCount => settings.lockImageCount;
  bool get rotationEnabled => settings.rotationEnabled;
  String get interval => settings.interval.label;
  String get wallpaperMode => settings.wallpaperMode.label;

  List<WallpaperMode> get wallpaperModes => WallpaperMode.values;

  List<IntervalOption> get intervals =>
      AndroidEntitlementService.allowedIntervals;

  bool get usesHomeFolder =>
      settings.wallpaperMode == WallpaperMode.homeOnly ||
      settings.wallpaperMode == WallpaperMode.bothShared ||
      settings.wallpaperMode == WallpaperMode.bothSeparate;

  bool get usesLockFolder =>
      settings.wallpaperMode == WallpaperMode.lockOnly ||
      settings.wallpaperMode == WallpaperMode.bothSeparate;

  String get activeFolderPath {
    if (settings.wallpaperMode == WallpaperMode.lockOnly) {
      return settings.lockFolderPath;
    }

    return settings.homeFolderPath;
  }

  int get activeImageCount {
    if (settings.wallpaperMode == WallpaperMode.lockOnly) {
      return settings.lockImageCount;
    }

    return settings.homeImageCount;
  }

  String get statusText => rotationEnabled ? 'Running' : 'Stopped';

  Future<bool> ensureAndroidImagePermission() async {
    if (!Platform.isAndroid) return true;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    final Permission permission = sdkInt >= 33
        ? Permission.photos
        : Permission.storage;

    final status = await permission.request();

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }

    return false;
  }

  Future<void> persistSettings() async {
    await AndroidSettingsStore.save(settings);
  }

  Future<void> restartRotationServiceIfNeeded() async {
    await AndroidRotationController.restartIfNeeded(settings);
  }

  List<Widget> buildFolderCards() {
    switch (settings.wallpaperMode) {
      case WallpaperMode.lockOnly:
        return [
          _FolderCard(
            title: 'Lock Folder',
            folderPath: lockFolderPath,
            imageCount: lockImageCount,
            validationState: AndroidRotationController.validateFolder(
              lockFolderPath,
            ),
            onChooseFolder: () => chooseFolder(forLockScreen: true),
          ),
        ];

      case WallpaperMode.bothShared:
        return [
          _FolderCard(
            title: 'Home + Lock Folder',
            folderPath: homeFolderPath,
            imageCount: homeImageCount,
            validationState: AndroidRotationController.validateFolder(
              homeFolderPath,
            ),
            onChooseFolder: () => chooseFolder(forLockScreen: false),
          ),
        ];

      case WallpaperMode.bothSeparate:
        return [
          _FolderCard(
            title: 'Home Folder',
            folderPath: homeFolderPath,
            imageCount: homeImageCount,
            validationState: AndroidRotationController.validateFolder(
              homeFolderPath,
            ),
            onChooseFolder: () => chooseFolder(forLockScreen: false),
          ),
          const SizedBox(height: 16),
          _FolderCard(
            title: 'Lock Folder',
            folderPath: lockFolderPath,
            imageCount: lockImageCount,
            validationState: AndroidRotationController.validateFolder(
              lockFolderPath,
            ),
            onChooseFolder: () => chooseFolder(forLockScreen: true),
          ),
        ];

      case WallpaperMode.homeOnly:
        return [
          _FolderCard(
            title: 'Home Folder',
            folderPath: homeFolderPath,
            imageCount: homeImageCount,
            validationState: AndroidRotationController.validateFolder(
              homeFolderPath,
            ),
            onChooseFolder: () => chooseFolder(forLockScreen: false),
          ),
        ];
    }
  }

  Future<void> chooseFolder({required bool forLockScreen}) async {
    debugPrint('Choose Folder tapped. forLockScreen=$forLockScreen');

    try {
      final hasPermission = await ensureAndroidImagePermission();

      debugPrint('Image permission granted: $hasPermission');

      if (!hasPermission) return;

      final selectedFolder = await FilePicker.platform.getDirectoryPath();

      debugPrint('Folder picker returned: $selectedFolder');

      if (selectedFolder == null || !mounted) return;

      setState(() {
        settings = AndroidRotationController.applyFolderSelection(
          settings,
          selectedFolder,
          forLockScreen: forLockScreen,
        );
      });

      await persistSettings();
      await restartRotationServiceIfNeeded();
    } catch (error, stackTrace) {
      debugPrint('Folder selection failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the folder picker.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadSettings();
    }
  }

  Future<void> updateWallpaperMode(WallpaperMode? value) async {
    if (value == null) return;

    setState(() {
      settings = settings.copyWith(wallpaperMode: value);
    });

    await persistSettings();
    await restartRotationServiceIfNeeded();
  }

  Future<void> loadSettings() async {
    final loadedSettings = await AndroidSettingsStore.load();
    final serviceRunning = await WallpaperService.isAndroidRotationRunning();

    if (!mounted) return;

    setState(() {
      settings = loadedSettings.copyWith(rotationEnabled: serviceRunning);
    });
  }

  Future<void> toggleRotation(bool value) async {
    if (activeFolderPath.isEmpty) return;

    final updatedSettings = settings.copyWith(rotationEnabled: value);

    if (value) {
      await Permission.notification.request();
      await AndroidRotationController.start(updatedSettings);
    } else {
      await AndroidRotationController.stop();
    }

    if (!mounted) return;

    setState(() {
      settings = updatedSettings;
    });

    await persistSettings();
  }

  Future<void> changeNow() async {
    if (activeFolderPath.isEmpty || activeImageCount == 0 || isApplying) return;

    setState(() {
      isApplying = true;
    });

    try {
      await AndroidRotationController.changeNow(settings);
    } finally {
      if (mounted) {
        setState(() {
          isApplying = false;
        });
      }
    }
  }

  Future<void> updateInterval(IntervalOption? value) async {
    if (value == null) return;

    setState(() {
      settings = settings.copyWith(interval: value);
    });

    await persistSettings();
    await restartRotationServiceIfNeeded();
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
            mode: settings.wallpaperMode,
            modes: WallpaperMode.values,
            isModeAllowed: AndroidEntitlementService.canUseMode,
            onModeChanged: updateWallpaperMode,
          ),
          const SizedBox(height: 16),
          ...buildFolderCards(),
          const SizedBox(height: 16),
          _RotationCard(
            rotationEnabled: settings.rotationEnabled,
            interval: settings.interval,
            intervals: IntervalOption.values,
            isIntervalAllowed: AndroidEntitlementService.canUseInterval,
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
    required this.isModeAllowed,
  });

  final WallpaperMode mode;
  final List<WallpaperMode> modes;
  final ValueChanged<WallpaperMode?> onModeChanged;
  final bool Function(WallpaperMode mode) isModeAllowed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<WallpaperMode>(
          initialValue: mode,
          decoration: const InputDecoration(labelText: 'Mode'),
          items: modes.map((value) {
            final allowed = isModeAllowed(value);

            return DropdownMenuItem<WallpaperMode>(
              value: value,
              enabled: allowed,
              child: Text(allowed ? value.label : '${value.label} - Pro'),
            );
          }).toList(),
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
    required this.validationState,
    required this.onChooseFolder,
  });

  final String title;
  final String folderPath;
  final int imageCount;
  final FolderValidationState validationState;
  final VoidCallback onChooseFolder;

  bool get hasWarning =>
      folderPath.isNotEmpty && validationState != FolderValidationState.valid;

  String get warningText {
    switch (validationState) {
      case FolderValidationState.missing:
        return 'Folder no longer exists';
      case FolderValidationState.empty:
        return 'No supported images found';
      case FolderValidationState.valid:
        return '';
    }
  }

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
            if (hasWarning) ...[
              const SizedBox(height: 8),
              Text(
                warningText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (hasFolder && !hasWarning) ...[
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
    required this.isIntervalAllowed,
  });

  final bool rotationEnabled;
  final IntervalOption interval;
  final List<IntervalOption> intervals;
  final ValueChanged<bool> onRotationChanged;
  final ValueChanged<IntervalOption?> onIntervalChanged;
  final bool Function(IntervalOption interval) isIntervalAllowed;

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
            DropdownButtonFormField<IntervalOption>(
              initialValue: interval,
              decoration: const InputDecoration(labelText: 'Change Every'),
              items: intervals.map((value) {
                final allowed = isIntervalAllowed(value);

                return DropdownMenuItem<IntervalOption>(
                  value: value,
                  enabled: allowed,
                  child: Text(allowed ? value.label : '${value.label} - Pro'),
                );
              }).toList(),
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
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Unlock Pro'),
              subtitle: const Text(
                'Separate lock screen rotation, faster intervals, and themes',
              ),
              onTap: () async {
                await BillingService.instance.buyPro();

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Purchase started')),
                );
              },
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
