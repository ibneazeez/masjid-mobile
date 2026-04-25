import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../api.dart';

/// Schedules on-device notifications before each prayer for the user's
/// preferred masjid. No server-side push is needed.
class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  static const String _kEnabled  = 'notif_enabled';
  static const String _kMasjidId = 'notif_masjid_id';
  static const String _kOffset   = 'notif_offset_min';     // minutes before adhan
  static const String _kPrayers  = 'notif_prayers_csv';    // e.g. "fajr,dhuhr,asr,maghrib,isha"
  static const String _kAtJamaat = 'notif_at_jamaat';      // also ping at jamaat time

  // Flutter local notifications plugin
  final _fln = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _fln.initialize(init);
    _initialised = true;
  }

  /// Ask the user for notification permission (Android 13+) and exact-alarm
  /// permission (Android 12+). Returns true if we can schedule.
  Future<bool> requestPermissions() async {
    final notif = await Permission.notification.request();
    if (!notif.isGranted) return false;
    // exact alarm is best-effort — on older Android it's implicit
    try { await Permission.scheduleExactAlarm.request(); } catch (_) {}
    return true;
  }

  // ---------- settings (shared prefs) ----------
  Future<NotificationSettings> readSettings() async {
    final p = await SharedPreferences.getInstance();
    return NotificationSettings(
      enabled:  p.getBool(_kEnabled) ?? false,
      masjidId: p.getInt(_kMasjidId),
      offsetMin: p.getInt(_kOffset) ?? 10,
      prayers: (p.getString(_kPrayers)
                  ?? 'fajr,dhuhr,asr,maghrib,isha,jumuah').split(','),
      alsoAtJamaat: p.getBool(_kAtJamaat) ?? false,
    );
  }

  Future<void> writeSettings(NotificationSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, s.enabled);
    if (s.masjidId != null) await p.setInt(_kMasjidId, s.masjidId!);
    await p.setInt(_kOffset, s.offsetMin);
    await p.setString(_kPrayers, s.prayers.join(','));
    await p.setBool(_kAtJamaat, s.alsoAtJamaat);
  }

  // ---------- scheduling ----------

  /// Cancel all pending notifications.
  Future<void> cancelAll() => _fln.cancelAll();

  /// Re-read settings, fetch the target masjid, and schedule 2 days of
  /// notifications. Safe to call on every app open.
  Future<void> rescheduleFromSettings() async {
    try {
      await init();
      final s = await readSettings();
      await cancelAll();
      if (!s.enabled || s.masjidId == null) return;

      final masjid = await Api.getMasjid(s.masjidId!);
      final timings = masjid.timings.isNotEmpty
          ? masjid.timings
          : await Api.getTimings(masjid.id);

      // Schedule today + tomorrow (covers the user opening the app any time)
      final now = DateTime.now();
      for (final day in [now, now.add(const Duration(days: 1))]) {
        for (final t in timings) {
          if (!s.prayers.contains(t.prayer)) continue;

          // Skip Jumu'ah on non-Fridays
          if (t.prayer == 'jumuah' && day.weekday != DateTime.friday) continue;
          // On Fridays, Jumu'ah replaces Dhuhr
          if (t.prayer == 'dhuhr' && day.weekday == DateTime.friday) continue;

          // 1. Pre-adhan reminder
          await _scheduleOne(
            id: _idFor(t.prayer, day, 'pre'),
            title: '${_niceName(t.prayer)} in ${s.offsetMin} min',
            body:  'Adhan at ${masjid.name} — ${_short(t.adhanTime)}',
            at:    _combine(day, t.adhanTime).subtract(Duration(minutes: s.offsetMin)),
          );

          // 2. Adhan time notification
          await _scheduleOne(
            id: _idFor(t.prayer, day, 'adhan'),
            title: '🕌 ${_niceName(t.prayer)} adhan',
            body:  '${masjid.name} — jamaat at ${_short(t.jamaatTime)}',
            at:    _combine(day, t.adhanTime),
          );

          // 3. Jamaat time (optional)
          if (s.alsoAtJamaat) {
            await _scheduleOne(
              id: _idFor(t.prayer, day, 'jamaat'),
              title: '${_niceName(t.prayer)} jamaat now',
              body:  'at ${masjid.name}',
              at:    _combine(day, t.jamaatTime),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('notif reschedule failed: $e');
    }
  }

  Future<void> _scheduleOne({
    required int id, required String title, required String body,
    required DateTime at,
  }) async {
    if (at.isBefore(DateTime.now())) return;  // don't schedule in the past
    await _fln.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(at, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_times',
          'Prayer times',
          channelDescription: 'Reminders before adhan and at jamaat time',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
    );
  }

  DateTime _combine(DateTime day, String hms) {
    final p = hms.split(':');
    return DateTime(day.year, day.month, day.day,
                     int.parse(p[0]), int.parse(p[1]));
  }

  int _idFor(String prayer, DateTime day, String kind) {
    // Stable small int id unique per (prayer, date, kind)
    final p = {'fajr':1,'dhuhr':2,'asr':3,'maghrib':4,'isha':5,'jumuah':6}[prayer] ?? 0;
    final k = {'pre':0,'adhan':1,'jamaat':2}[kind] ?? 0;
    return day.day * 100 + p * 10 + k;
  }

  String _short(String t) => t.length >= 5 ? t.substring(0, 5) : t;
  String _niceName(String p) => {
    'fajr':"Fajr",'dhuhr':"Dhuhr",'asr':"Asr",
    'maghrib':"Maghrib",'isha':"Isha",'jumuah':"Jumu'ah",
  }[p] ?? p;

  // For JSON debug (future use)
  @visibleForTesting
  static String settingsJson(NotificationSettings s) => jsonEncode({
    'enabled': s.enabled, 'masjid_id': s.masjidId,
    'offset_min': s.offsetMin, 'prayers': s.prayers,
    'also_at_jamaat': s.alsoAtJamaat,
  });
}

class NotificationSettings {
  bool enabled;
  int? masjidId;
  int offsetMin;
  List<String> prayers;
  bool alsoAtJamaat;
  NotificationSettings({
    required this.enabled, required this.masjidId,
    required this.offsetMin, required this.prayers,
    required this.alsoAtJamaat,
  });
}
