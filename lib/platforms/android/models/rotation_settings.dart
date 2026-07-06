enum WallpaperMode {
  homeOnly,
  lockOnly,
  bothShared,
  bothSeparate;

  String get label {
    switch (this) {
      case WallpaperMode.homeOnly:
        return 'Home Only';
      case WallpaperMode.lockOnly:
        return 'Lock Only';
      case WallpaperMode.bothShared:
        return 'Both Shared';
      case WallpaperMode.bothSeparate:
        return 'Both Separate';
    }
  }

  static WallpaperMode fromLabel(String value) {
    switch (value) {
      case 'Lock Only':
        return WallpaperMode.lockOnly;
      case 'Both Shared':
        return WallpaperMode.bothShared;
      case 'Both Separate':
        return WallpaperMode.bothSeparate;
      case 'Home Only':
      default:
        return WallpaperMode.homeOnly;
    }
  }
}

enum IntervalOption {
  seconds30,
  minute1,
  minutes15,
  minutes30,
  hour1,
  hours4,
  daily;

  String get label {
    switch (this) {
      case IntervalOption.seconds30:
        return '30 seconds';
      case IntervalOption.minute1:
        return '1 minute';
      case IntervalOption.minutes15:
        return '15 minutes';
      case IntervalOption.minutes30:
        return '30 minutes';
      case IntervalOption.hour1:
        return '1 hour';
      case IntervalOption.hours4:
        return '4 hours';
      case IntervalOption.daily:
        return 'Daily';
    }
  }

  int get seconds {
    switch (this) {
      case IntervalOption.seconds30:
        return 30;
      case IntervalOption.minute1:
        return 60;
      case IntervalOption.minutes15:
        return 900;
      case IntervalOption.minutes30:
        return 1800;
      case IntervalOption.hour1:
        return 3600;
      case IntervalOption.hours4:
        return 14400;
      case IntervalOption.daily:
        return 86400;
    }
  }

  static IntervalOption fromLabel(String value) {
    switch (value) {
      case '30 seconds':
        return IntervalOption.seconds30;
      case '1 minute':
        return IntervalOption.minute1;
      case '15 minutes':
        return IntervalOption.minutes15;
      case '30 minutes':
        return IntervalOption.minutes30;
      case '1 hour':
        return IntervalOption.hour1;
      case 'Daily':
        return IntervalOption.daily;
      case '4 hours':
      default:
        return IntervalOption.hours4;
    }
  }
}

enum FolderValidationState {
  valid,
  missing,
  empty,
}

class AndroidRotationSettings {
  final String homeFolderPath;
  final String lockFolderPath;
  final int homeImageCount;
  final int lockImageCount;
  final bool rotationEnabled;
  final IntervalOption interval;
  final WallpaperMode wallpaperMode;

  const AndroidRotationSettings({
    required this.homeFolderPath,
    required this.lockFolderPath,
    required this.homeImageCount,
    required this.lockImageCount,
    required this.rotationEnabled,
    required this.interval,
    required this.wallpaperMode,
  });

  factory AndroidRotationSettings.initial() {
    return const AndroidRotationSettings(
      homeFolderPath: '',
      lockFolderPath: '',
      homeImageCount: 0,
      lockImageCount: 0,
      rotationEnabled: false,
      interval: IntervalOption.hours4,
      wallpaperMode: WallpaperMode.homeOnly,
    );
  }

  int get intervalSeconds => interval.seconds;

  AndroidRotationSettings copyWith({
    String? homeFolderPath,
    String? lockFolderPath,
    int? homeImageCount,
    int? lockImageCount,
    bool? rotationEnabled,
    IntervalOption? interval,
    WallpaperMode? wallpaperMode,
  }) {
    return AndroidRotationSettings(
      homeFolderPath: homeFolderPath ?? this.homeFolderPath,
      lockFolderPath: lockFolderPath ?? this.lockFolderPath,
      homeImageCount: homeImageCount ?? this.homeImageCount,
      lockImageCount: lockImageCount ?? this.lockImageCount,
      rotationEnabled: rotationEnabled ?? this.rotationEnabled,
      interval: interval ?? this.interval,
      wallpaperMode: wallpaperMode ?? this.wallpaperMode,
    );
  }
}
