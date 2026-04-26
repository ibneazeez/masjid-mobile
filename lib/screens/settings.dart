import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_prefs.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  School _school = School.hanafi;
  NafilFlags _nafil = NafilFlags();
  bool _showEnds = true;
  bool _loaded = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final s = await UserPrefs.school();
    final n = await UserPrefs.nafil();
    final e = await UserPrefs.showEndTimes();
    if (!mounted) return;
    setState(() { _school = s; _nafil = n; _showEnds = e; _loaded = true; });
  }

  Future<void> _setSchool(School s) async {
    setState(() => _school = s);
    await UserPrefs.setSchool(s);
  }

  Future<void> _setNafil(NafilFlags f) async {
    setState(() => _nafil = f);
    await UserPrefs.setNafil(f);
  }

  Future<void> _setShowEnds(bool v) async {
    setState(() => _showEnds = v);
    await UserPrefs.setShowEndTimes(v);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.gold)));
    }
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('SCHOOL OF FIQH'),
          _block([
            RadioListTile<School>(
              value: School.hanafi,
              groupValue: _school,
              activeColor: AppTheme.gold,
              title: Text('Hanafi',
                style: GoogleFonts.amiri(color: AppTheme.cream, fontSize: 16, fontWeight: FontWeight.bold)),
              subtitle: Text('Asr begins when shadow = 2× object length',
                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11.5)),
              onChanged: (v) => v != null ? _setSchool(v) : null,
            ),
            const Divider(height: 1, color: AppTheme.line),
            RadioListTile<School>(
              value: School.shafi,
              groupValue: _school,
              activeColor: AppTheme.gold,
              title: Text('Shafi / Maliki / Hanbali',
                style: GoogleFonts.amiri(color: AppTheme.cream, fontSize: 16, fontWeight: FontWeight.bold)),
              subtitle: Text('Asr begins when shadow = 1× object length',
                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11.5)),
              onChanged: (v) => v != null ? _setSchool(v) : null,
            ),
          ]),
          const SizedBox(height: 18),

          _section('PRAYER WINDOWS'),
          _block([
            SwitchListTile(
              value: _showEnds,
              activeColor: AppTheme.emerald,
              title: Text('Show end times',
                style: GoogleFonts.inter(color: AppTheme.cream, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Display when each prayer window expires (e.g. "Fajr ends 06:14")',
                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11.5)),
              onChanged: _setShowEnds,
            ),
          ]),
          const SizedBox(height: 18),

          _section('NAFIL PRAYERS'),
          _block([
            SwitchListTile(
              value: _nafil.ishraq,
              activeColor: AppTheme.emerald,
              title: Text('Ishraq',
                style: GoogleFonts.amiri(color: AppTheme.cream, fontSize: 16, fontWeight: FontWeight.bold)),
              subtitle: Text('Just after sunrise — 2 rakat',
                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11.5)),
              onChanged: (v) => _setNafil(NafilFlags(
                ishraq: v, chasht: _nafil.chasht,
                awwabin: _nafil.awwabin, tahajjud: _nafil.tahajjud)),
            ),
            const Divider(height: 1, color: AppTheme.line),
            SwitchListTile(
              value: _nafil.chasht,
              activeColor: AppTheme.emerald,
              title: Text('Chasht (Duha)',
                style: GoogleFonts.amiri(color: AppTheme.cream, fontSize: 16, fontWeight: FontWeight.bold)),
              subtitle: Text('Mid-morning — 2 to 8 rakat',
                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11.5)),
              onChanged: (v) => _setNafil(NafilFlags(
                ishraq: _nafil.ishraq, chasht: v,
                awwabin: _nafil.awwabin, tahajjud: _nafil.tahajjud)),
            ),
            const Divider(height: 1, color: AppTheme.line),
            SwitchListTile(
              value: _nafil.awwabin,
              activeColor: AppTheme.emerald,
              title: Text('Awwabin',
                style: GoogleFonts.amiri(color: AppTheme.cream, fontSize: 16, fontWeight: FontWeight.bold)),
              subtitle: Text('After Maghrib — 6 rakat',
                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11.5)),
              onChanged: (v) => _setNafil(NafilFlags(
                ishraq: _nafil.ishraq, chasht: _nafil.chasht,
                awwabin: v, tahajjud: _nafil.tahajjud)),
            ),
            const Divider(height: 1, color: AppTheme.line),
            SwitchListTile(
              value: _nafil.tahajjud,
              activeColor: AppTheme.emerald,
              title: Text('Tahajjud',
                style: GoogleFonts.amiri(color: AppTheme.cream, fontSize: 16, fontWeight: FontWeight.bold)),
              subtitle: Text('Last third of the night · streak tracker enabled',
                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11.5)),
              onChanged: (v) => _setNafil(NafilFlags(
                ishraq: _nafil.ishraq, chasht: _nafil.chasht,
                awwabin: _nafil.awwabin, tahajjud: v)),
            ),
          ]),
          const SizedBox(height: 18),

          _section('HOME-SCREEN WIDGET'),
          _block([
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pin the next prayer to your home screen',
                  style: GoogleFonts.inter(color: AppTheme.cream, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Long-press an empty spot on your phone\'s home screen → '
                  'Widgets → find "Masjid Timings" → drag onto the screen. '
                  'It refreshes every 30 minutes and whenever you open the app.',
                  style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 12, height: 1.45)),
              ]),
            ),
          ]),
          const SizedBox(height: 22),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(label,
      style: GoogleFonts.inter(
        color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  Widget _block(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.line),
    ),
    child: Column(children: children),
  );
}
