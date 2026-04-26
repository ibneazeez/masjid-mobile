import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';

/// Pushes the "next prayer" snapshot into SharedPreferences so the native
/// Android home-screen widget can render it without doing its own network
/// or location work. The Flutter shared_preferences plugin stores values
/// under the "FlutterSharedPreferences" XML file, prefixing keys with
/// "flutter." — the widget reads from the same file.
class WidgetSync {
  static const MethodChannel _ch =
    MethodChannel('in.co.eesa.masjid_mobile/widget');

  /// Save next-prayer snapshot for [masjid]; the widget polls these on
  /// its periodic update or whenever we kick it via [refresh].
  static Future<void> push({
    required Masjid masjid,
    required DateTime now,
  }) async {
    final next = masjid.nextPrayer(now);
    final p = await SharedPreferences.getInstance();
    await p.setString('widget_masjid_name', masjid.name);
    await p.setString('widget_masjid_area', masjid.area);
    if (next != null) {
      await p.setString('widget_next_prayer', next.prayer);
      await p.setString('widget_next_time',   next.jamaatTime.length >= 5
                                                ? next.jamaatTime.substring(0, 5)
                                                : next.jamaatTime);
    } else {
      await p.remove('widget_next_prayer');
      await p.remove('widget_next_time');
    }
    await p.setString('widget_updated_at', now.toIso8601String());
    await refresh();
  }

  /// Tell Android to redraw all instances of MasjidWidgetProvider.
  /// Best-effort: silently ignored on platforms that don't have the channel
  /// (iOS, web, desktop).
  static Future<void> refresh() async {
    try { await _ch.invokeMethod('refreshWidget'); } catch (_) {}
  }
}
