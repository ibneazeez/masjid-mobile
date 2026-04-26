import 'package:shared_preferences/shared_preferences.dart';

/// App-wide user preferences (school of fiqh, optional nafil prayers,
/// home-screen widget config). All stored locally — no server round-trip.
class UserPrefs {
  static const _kSchool        = 'pref_school';            // 'hanafi' | 'shafi'
  static const _kNafilIshraq   = 'pref_nafil_ishraq';
  static const _kNafilChasht   = 'pref_nafil_chasht';
  static const _kNafilAwwabin  = 'pref_nafil_awwabin';
  static const _kNafilTahajjud = 'pref_nafil_tahajjud';
  static const _kShowEndTimes  = 'pref_show_end_times';

  static Future<School> school() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_kSchool);
    return v == 'shafi' ? School.shafi : School.hanafi;
  }

  static Future<void> setSchool(School s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSchool, s == School.shafi ? 'shafi' : 'hanafi');
  }

  static Future<NafilFlags> nafil() async {
    final p = await SharedPreferences.getInstance();
    return NafilFlags(
      ishraq:   p.getBool(_kNafilIshraq)   ?? false,
      chasht:   p.getBool(_kNafilChasht)   ?? false,
      awwabin:  p.getBool(_kNafilAwwabin)  ?? false,
      tahajjud: p.getBool(_kNafilTahajjud) ?? false,
    );
  }

  static Future<void> setNafil(NafilFlags f) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNafilIshraq,   f.ishraq);
    await p.setBool(_kNafilChasht,   f.chasht);
    await p.setBool(_kNafilAwwabin,  f.awwabin);
    await p.setBool(_kNafilTahajjud, f.tahajjud);
  }

  static Future<bool> showEndTimes() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kShowEndTimes) ?? true;
  }

  static Future<void> setShowEndTimes(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kShowEndTimes, v);
  }
}

enum School { hanafi, shafi }

class NafilFlags {
  bool ishraq;
  bool chasht;
  bool awwabin;
  bool tahajjud;
  NafilFlags({
    this.ishraq = false,
    this.chasht = false,
    this.awwabin = false,
    this.tahajjud = false,
  });

  bool get any => ishraq || chasht || awwabin || tahajjud;
}
