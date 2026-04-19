import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api.dart';
import '../theme.dart';
import 'login.dart';

class SuggestTimingScreen extends StatefulWidget {
  final Masjid masjid;
  const SuggestTimingScreen({super.key, required this.masjid});
  @override
  State<SuggestTimingScreen> createState() => _SuggestTimingScreenState();
}

class _SuggestTimingScreenState extends State<SuggestTimingScreen> {
  String _prayer = 'fajr';
  TimeOfDay _adhan = const TimeOfDay(hour: 5, minute: 0);
  TimeOfDay _jamaat = const TimeOfDay(hour: 5, minute: 15);
  final _reason = TextEditingController();
  bool _busy = false;

  static const _prayers = ['fajr','dhuhr','asr','maghrib','isha','jumuah'];
  static const _names = {
    'fajr':'Fajr','dhuhr':'Dhuhr','asr':'Asr','maghrib':'Maghrib','isha':'Isha','jumuah':"Jumu'ah",
  };

  String _fmt(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  Future<void> _pickTime(bool isAdhan) async {
    final picked = await showTimePicker(
      context: context, initialTime: isAdhan ? _adhan : _jamaat);
    if (picked != null) setState(() => isAdhan ? _adhan = picked : _jamaat = picked);
  }

  Future<void> _submit() async {
    if (!await Api.isLoggedIn()) {
      if (!mounted) return;
      final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      await Api.suggestTiming(widget.masjid.id, _prayer, _fmt(_adhan), _fmt(_jamaat),
          _reason.text.trim().isEmpty ? null : _reason.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suggestion submitted — pending admin approval')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Suggest a time change')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Masjid', style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(widget.masjid.name,
            style: GoogleFonts.amiri(color: AppTheme.cream, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),

          Text('Prayer', style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _prayers.map((p) {
              final on = p == _prayer;
              return ChoiceChip(
                label: Text(_names[p]!),
                selected: on,
                onSelected: (_) => setState(() => _prayer = p),
                selectedColor: AppTheme.emerald,
                backgroundColor: AppTheme.surface,
                side: BorderSide(color: on ? AppTheme.gold : AppTheme.line),
                labelStyle: GoogleFonts.inter(
                  color: on ? AppTheme.cream : AppTheme.textMid,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          Row(children: [
            Expanded(child: _timeField('Adhan time', _adhan, () => _pickTime(true))),
            const SizedBox(width: 12),
            Expanded(child: _timeField('Jamaat time', _jamaat, () => _pickTime(false))),
          ]),
          const SizedBox(height: 18),

          Text('Reason (optional)', style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: _reason, maxLines: 3,
            decoration: const InputDecoration(hintText: 'e.g. winter schedule, masjid committee announcement...'),
          ),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: AppTheme.cream,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _busy ? null : _submit,
              child: _busy
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit suggestion'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your suggestion will be reviewed by a Masjid Admin or the Super Admin and applied if approved.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay t, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 10, letterSpacing: 0.6, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(_fmt(t),
              style: GoogleFonts.inter(color: AppTheme.gold, fontSize: 22, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
