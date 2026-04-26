import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'user_prefs.dart';

/// Astronomical prayer windows for a given lat/lng/date.
///
/// "Jamaat time" is what each masjid sets. "Window" is the astronomical
/// span during which a prayer is valid — a separate concept that we
/// surface as "ends at HH:mm" labels and as the basis for optional
/// nafil prayers (Ishraq, Chasht, Tahajjud).
class PrayerWindow {
  final String name;       // 'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'
  final DateTime start;
  final DateTime end;
  PrayerWindow(this.name, this.start, this.end);
}

class NafilWindow {
  final String name;       // 'ishraq', 'chasht', 'awwabin', 'tahajjud'
  final String label;      // user-friendly
  final DateTime start;
  final DateTime end;
  NafilWindow(this.name, this.label, this.start, this.end);

  bool active(DateTime now) =>
      !now.isBefore(start) && now.isBefore(end);
}

class PrayerCalc {
  /// Returns the 5 prayer windows for the given location/date plus useful
  /// astronomical anchors (sunrise, sunset, midnight) for nafil computation.
  /// Cached for the day per (lat,lng,date,school).
  ///
  /// Hanafi vs Shafi only changes Asr start; Asr end (= sunset) is the same.
  static Future<PrayerDay?> dayFor(double lat, double lng, DateTime date) async {
    final school = await UserPrefs.school();
    final ymd = '${date.year}-${_2(date.month)}-${_2(date.day)}';
    final cacheKey = 'pcalc_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}'
                     '_${ymd}_${school.name}';
    final p = await SharedPreferences.getInstance();
    final cached = p.getString(cacheKey);
    if (cached != null) {
      try { return PrayerDay.fromJson(jsonDecode(cached), date); } catch (_) {}
    }
    try {
      // AlAdhan: method=1 (Karachi/Hanafi) is fine for Subh-Sadiq Fajr +
      // Isha. The school param flips Asr start (1 = Hanafi shadow=2x,
      // 0 = Shafi shadow=1x).
      final dd = '${_2(date.day)}-${_2(date.month)}-${date.year}';
      final uri = Uri.parse(
        'https://api.aladhan.com/v1/timings/$dd?'
        'latitude=$lat&longitude=$lng&method=1'
        '&school=${school == School.hanafi ? 1 : 0}',
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body);
      final t = (j['data']?['timings'] as Map?) ?? {};
      final raw = <String, String>{
        for (final e in t.entries) e.key.toString(): e.value.toString(),
      };
      await p.setString(cacheKey, jsonEncode(raw));
      return PrayerDay.fromJson(raw, date);
    } catch (_) {
      return null;
    }
  }

  static String _2(int n) => n.toString().padLeft(2, '0');
}

class PrayerDay {
  final DateTime fajr, sunrise, dhuhr, asr, sunset, maghrib, isha, midnight;
  PrayerDay({
    required this.fajr, required this.sunrise, required this.dhuhr,
    required this.asr, required this.sunset, required this.maghrib,
    required this.isha, required this.midnight,
  });

  factory PrayerDay.fromJson(Map<String, dynamic> j, DateTime date) {
    DateTime parse(String key, {String fallback = '00:00'}) {
      final raw = (j[key] ?? fallback).toString();
      // AlAdhan format like "05:14 (IST)" — strip parens
      final clean = raw.split(' ').first;
      final parts = clean.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return DateTime(date.year, date.month, date.day, h, m);
    }
    return PrayerDay(
      fajr:     parse('Fajr'),
      sunrise:  parse('Sunrise'),
      dhuhr:    parse('Dhuhr'),
      asr:      parse('Asr'),
      sunset:   parse('Sunset'),
      maghrib:  parse('Maghrib'),
      isha:     parse('Isha'),
      midnight: parse('Midnight', fallback: '00:00'),
    );
  }

  /// Five canonical prayer windows.
  List<PrayerWindow> get windows => [
    PrayerWindow('fajr',    fajr,    sunrise),
    PrayerWindow('dhuhr',   dhuhr,   asr),
    PrayerWindow('asr',     asr,     sunset),
    PrayerWindow('maghrib', maghrib, isha),
    // Isha runs to "Islamic midnight" (≈ midpoint of sunset → next-day Fajr).
    PrayerWindow('isha',    isha,    midnight.isAfter(isha)
                                       ? midnight
                                       : midnight.add(const Duration(days: 1))),
  ];

  /// Compute the optional nafil prayer windows the user enabled.
  ///
  ///   • Ishraq:   ~15 min after sunrise → ~45 min after sunrise
  ///   • Chasht (Duha): ~30 min after sunrise → ~10 min before Dhuhr
  ///   • Awwabin:  starts after Maghrib salah → ends ~1h after sunset
  ///   • Tahajjud: last third of the night (sunset → next-day Fajr)
  List<NafilWindow> nafil(NafilFlags f, DateTime nextDayFajr) {
    final out = <NafilWindow>[];
    if (f.ishraq) {
      out.add(NafilWindow('ishraq', 'Ishraq',
        sunrise.add(const Duration(minutes: 15)),
        sunrise.add(const Duration(minutes: 45))));
    }
    if (f.chasht) {
      out.add(NafilWindow('chasht', 'Chasht (Duha)',
        sunrise.add(const Duration(minutes: 30)),
        dhuhr.subtract(const Duration(minutes: 10))));
    }
    if (f.awwabin) {
      out.add(NafilWindow('awwabin', 'Awwabin',
        maghrib.add(const Duration(minutes: 15)),
        maghrib.add(const Duration(minutes: 75))));
    }
    if (f.tahajjud) {
      // Last third of the night.
      final nightLen = nextDayFajr.difference(sunset);
      final start = nextDayFajr.subtract(Duration(minutes: nightLen.inMinutes ~/ 3));
      out.add(NafilWindow('tahajjud', 'Tahajjud',
        start, nextDayFajr.subtract(const Duration(minutes: 5))));
    }
    return out;
  }
}
