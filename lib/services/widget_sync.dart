import 'package:flutter/services.dart';
import '../api.dart';

/// Pushes the "next prayer" snapshot to the native Android home-screen
/// widget via a dedicated MethodChannel. The Kotlin side writes to a
/// custom `MasjidWidgetPrefs` SharedPreferences file (NOT the Flutter
/// shared_preferences XML), which avoids the ambiguity between the
/// legacy SharedPreferences plugin and the newer DataStore-backed one.
class WidgetSync {
  static const MethodChannel _ch =
    MethodChannel('in.co.eesa.masjid_mobile/widget');

  /// Save next-prayer snapshot for [masjid] and immediately redraw any
  /// pinned widgets. Best-effort: silently ignored on platforms that
  /// don't have the channel (iOS, web, desktop).
  ///
  /// [overdueCount] / [overdueName] surface the nearest admin-overdue
  /// masjid for users with admin roles, so the widget can flag it.
  static Future<void> push({
    required Masjid masjid,
    required DateTime now,
    int overdueCount = 0,
    String? overdueName,
  }) async {
    final next = masjid.nextPrayer(now);
    final timings = <String, String>{};
    for (final t in masjid.timings) {
      if (t.prayer == 'jumuah') continue; // skip Jumu'ah in the 5-row grid
      timings[t.prayer] = t.jamaatTime.length >= 5
          ? t.jamaatTime.substring(0, 5)
          : t.jamaatTime;
    }
    final data = <String, String>{
      'masjid_name': masjid.name,
      'masjid_area': masjid.area,
      'distance_km': masjid.distanceKm == null
          ? ''
          : masjid.distanceKm!.toStringAsFixed(1),
      'next_prayer': next?.prayer ?? '',
      'next_time':   next == null
          ? ''
          : (next.jamaatTime.length >= 5
              ? next.jamaatTime.substring(0, 5)
              : next.jamaatTime),
      'fajr':    timings['fajr']    ?? '',
      'dhuhr':   timings['dhuhr']   ?? '',
      'asr':     timings['asr']     ?? '',
      'maghrib': timings['maghrib'] ?? '',
      'isha':    timings['isha']    ?? '',
      'overdue_count': overdueCount.toString(),
      'overdue_name':  overdueName ?? '',
      'updated_at': now.toIso8601String(),
    };
    try {
      await _ch.invokeMethod('saveWidgetData', data);
    } catch (_) {/* silent — non-Android platforms */}
  }
}
