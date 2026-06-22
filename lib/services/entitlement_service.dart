import 'dart:async';

class EntitlementService {
  static bool get isPro => false;

  static int get maxTargets {
    return isPro ? 999 : 1;
  }

  static List<String> get allowedIntervals {
    if (isPro) {
      return const [
        '10 seconds',
        '30 seconds',
        '1 minute',
        '15 minutes',
        '30 minutes',
        '1 hour',
        '4 hours',
        'Daily',
      ];
    }

    return const [
      '4 hours',
      'Daily',
    ];
  }

  static bool isIntervalAllowed(String interval) {
    return allowedIntervals.contains(interval);
  }

  static String normalizeInterval(String interval) {
    if (isIntervalAllowed(interval)) return interval;
    return '4 hours';
  }

  static Duration durationFromLabel(String interval) {
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
        return const Duration(hours: 4);
    }
  }
}