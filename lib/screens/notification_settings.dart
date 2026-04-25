import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../services/notification_service.dart';
import '../theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  NotificationSettings? _s;
  List<Masjid> _masjids = [];
  bool _saving = false;

  static const _prayerNames = {
    'fajr':'Fajr','dhuhr':'Dhuhr','asr':'Asr',
    'maghrib':'Maghrib','isha':'Isha','jumuah':"Jumu'ah",
  };
  static const _offsetChoices = [0, 5, 10, 15, 30];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final svc = NotificationService();
    await svc.init();
    final settings = await svc.readSettings();
    final page = await Api.listMasjids(page: 0, size: 200);
    if (!mounted) return;
    setState(() { _s = settings; _masjids = page.items; });
  }

  Future<void> _save() async {
    if (_s == null) return;
    setState(() => _saving = true);
    try {
      final svc = NotificationService();
      if (_s!.enabled) {
        final granted = await svc.requestPermissions();
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission required to enable alerts')));
          setState(() { _s!.enabled = false; _saving = false; });
          return;
        }
      }
      await svc.writeSettings(_s!);
      await svc.rescheduleFromSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved — notifications scheduled')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_s == null) {
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
      );
    }
    final s = _s!;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Prayer Notifications'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('SAVE',
              style: GoogleFonts.inter(color: AppTheme.gold, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Master switch
          _block([
            SwitchListTile(
              value: s.enabled,
              activeColor: AppTheme.gold,
              title: Text('Enable prayer notifications',
                style: GoogleFonts.inter(color: AppTheme.cream, fontWeight: FontWeight.w600)),
              subtitle: Text(
                s.enabled
                  ? 'You\'ll be reminded ${s.offsetMin} min before each adhan'
                  : 'Tap to turn on',
                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 12)),
              onChanged: (v) => setState(() => s.enabled = v),
            ),
          ]),
          const SizedBox(height: 14),

          if (s.enabled) ...[
            // Masjid picker
            _sectionLabel('MASJID'),
            _block([
              DropdownButtonFormField<int>(
                value: s.masjidId,
                isExpanded: true,
                items: _masjids.map((m) => DropdownMenuItem(
                  value: m.id,
                  child: Text('${m.name} · ${m.area}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.cream)),
                )).toList(),
                onChanged: (v) => setState(() => s.masjidId = v),
                dropdownColor: AppTheme.surface,
                decoration: const InputDecoration(
                  hintText: 'Pick a masjid',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // Offset
            _sectionLabel('REMIND ME BEFORE ADHAN'),
            _block([
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Wrap(spacing: 8, runSpacing: 8,
                  children: _offsetChoices.map((m) {
                    final sel = s.offsetMin == m;
                    return ChoiceChip(
                      label: Text(m == 0 ? 'At adhan' : '$m min before'),
                      selected: sel,
                      onSelected: (_) => setState(() => s.offsetMin = m),
                      selectedColor: AppTheme.gold,
                      backgroundColor: AppTheme.surfaceAlt,
                      labelStyle: GoogleFonts.inter(
                        color: sel ? AppTheme.bg : AppTheme.cream,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w500),
                      side: BorderSide(color: sel ? AppTheme.gold : AppTheme.line),
                    );
                  }).toList(),
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // Prayer toggles
            _sectionLabel('WHICH PRAYERS'),
            _block(_prayerNames.entries.map((e) =>
              SwitchListTile(
                value: s.prayers.contains(e.key),
                activeColor: AppTheme.emerald,
                title: Text(e.value,
                  style: GoogleFonts.amiri(color: AppTheme.cream, fontWeight: FontWeight.bold)),
                onChanged: (on) => setState(() {
                  if (on) { if (!s.prayers.contains(e.key)) s.prayers.add(e.key); }
                  else    { s.prayers.remove(e.key); }
                }),
              ),
            ).toList()),
            const SizedBox(height: 14),

            _sectionLabel('EXTRAS'),
            _block([
              SwitchListTile(
                value: s.alsoAtJamaat,
                activeColor: AppTheme.emerald,
                title: Text('Also ping at jamaat time',
                  style: GoogleFonts.inter(color: AppTheme.cream, fontWeight: FontWeight.w600)),
                subtitle: Text('Extra notification when jamaat starts',
                  style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 12)),
                onChanged: (v) => setState(() => s.alsoAtJamaat = v),
              ),
            ]),
            const SizedBox(height: 22),
            Text(
              'Notifications are scheduled on your phone — no data usage, and they '
              'work even when the app is closed. They\'ll re-schedule automatically '
              'whenever you open the app.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11.5, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
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
