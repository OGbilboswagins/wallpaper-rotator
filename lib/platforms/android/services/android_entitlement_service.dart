import '../models/rotation_settings.dart';
import '../../../services/billing/billing_service.dart';

class AndroidEntitlementService {
  static bool get isPro => BillingService.instance.isPro;

  static bool canUseMode(WallpaperMode mode) {
    if (isPro) return true;

    return mode == WallpaperMode.homeOnly ||
        mode == WallpaperMode.bothShared;
  }

  static bool canUseInterval(IntervalOption interval) {
    if (isPro) return true;

    return interval == IntervalOption.hours4 ||
        interval == IntervalOption.daily;
  }

  static List<WallpaperMode> get allowedModes {
    if (isPro) return WallpaperMode.values;

    return const [WallpaperMode.homeOnly, WallpaperMode.bothShared];
  }

  static List<IntervalOption> get allowedIntervals {
    if (isPro) return IntervalOption.values;

    return const [IntervalOption.hours4, IntervalOption.daily];
  }

  static WallpaperMode normalizeMode(WallpaperMode mode) {
    if (canUseMode(mode)) return mode;
    return WallpaperMode.homeOnly;
  }

  static IntervalOption normalizeInterval(IntervalOption interval) {
    if (canUseInterval(interval)) return interval;
    return IntervalOption.hours4;
  }
}
