import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api.dart';
import '../../theme.dart';

class AdminMasjidEditScreen extends StatefulWidget {
  final Masjid? masjid;  // null = create new
  const AdminMasjidEditScreen({super.key, this.masjid});
  @override
  State<AdminMasjidEditScreen> createState() => _AdminMasjidEditScreenState();
}

class _AdminMasjidEditScreenState extends State<AdminMasjidEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _area;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _capacity;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  bool _busy = false;
  bool _gpsLoading = false;

  // Timing controllers per prayer
  final Map<String, TextEditingController> _adhan = {};
  final Map<String, TextEditingController> _jamaat = {};
  static const _prayers = ['fajr','dhuhr','asr','maghrib','isha','jumuah'];
  static const _names = {
    'fajr':'Fajr','dhuhr':'Dhuhr','asr':'Asr',
    'maghrib':'Maghrib','isha':'Isha','jumuah':"Jumu'ah",
  };

  bool get isNew => widget.masjid == null;

  @override
  void initState() {
    super.initState();
    final m = widget.masjid;
    _name     = TextEditingController(text: m?.name     ?? '');
    _area     = TextEditingController(text: m?.area     ?? '');
    _address  = TextEditingController(text: m?.address  ?? '');
    _phone    = TextEditingController(text: m?.phone    ?? '');
    _capacity = TextEditingController(text: '');
    _lat      = TextEditingController(text: m?.lat?.toString() ?? '');
    _lng      = TextEditingController(text: m?.lng?.toString() ?? '');
    for (final p in _prayers) {
      final t = m?.timings.where((x) => x.prayer == p).firstOrNull;
      _adhan[p]  = TextEditingController(text: _short(t?.adhanTime));
      _jamaat[p] = TextEditingController(text: _short(t?.jamaatTime));
    }
  }

  String _short(String? t) {
    if (t == null) return '';
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  @override
  void dispose() {
    _name.dispose(); _area.dispose(); _address.dispose(); _phone.dispose();
    _capacity.dispose(); _lat.dispose(); _lng.dispose();
    for (final c in _adhan.values) c.dispose();
    for (final c in _jamaat.values) c.dispose();
    super.dispose();
  }

  Future<void> _fetchGps() async {
    setState(() => _gpsLoading = true);
    try {
      // Check & request permission
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied. Enable it in device settings.')));
        }
        return;
      }
      if (perm == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required to get GPS coordinates.')));
        }
        return;
      }
      // Get high-accuracy position
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 15));
      setState(() {
        _lat.text = pos.latitude.toStringAsFixed(7);
        _lng.text = pos.longitude.toStringAsFixed(7);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            'Location captured: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
            ' (accuracy: ${pos.accuracy.toStringAsFixed(0)}m)')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS error: $e')));
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<TimeOfDay?> _pickTime(String current) {
    var hour = 5, min = 0;
    if (current.length >= 5) {
      hour = int.tryParse(current.substring(0, 2)) ?? 5;
      min  = int.tryParse(current.substring(3, 5)) ?? 0;
    }
    return showTimePicker(context: context, initialTime: TimeOfDay(hour: hour, minute: min));
  }

  String _fmt(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _area.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and area are required')));
      return;
    }
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'area': _area.text.trim(),
        if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
        if (_phone.text.trim().isNotEmpty)   'phone':   _phone.text.trim(),
        if (_lat.text.trim().isNotEmpty)     'lat':     double.tryParse(_lat.text.trim()),
        if (_lng.text.trim().isNotEmpty)     'lng':     double.tryParse(_lng.text.trim()),
      };

      int masjidId;
      if (isNew) {
        masjidId = await Api.adminCreateMasjid(body);
      } else {
        masjidId = widget.masjid!.id;
        await Api.adminUpdateMasjid(masjidId, body);
      }

      // Save timings (only the ones that have both adhan + jamaat filled)
      final timings = <Timing>[];
      for (final p in _prayers) {
        final a = _adhan[p]!.text.trim();
        final j = _jamaat[p]!.text.trim();
        if (a.isNotEmpty && j.isNotEmpty) {
          timings.add(Timing(prayer: p, adhanTime: a, jamaatTime: j));
        }
      }
      if (timings.isNotEmpty) {
        await Api.adminUpdateTimings(masjidId, timings);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNew ? 'Created' : 'Saved')));
      Navigator.pop(context, true);
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
      appBar: AppBar(
        title: Text(isNew ? 'New Masjid' : 'Edit Masjid', overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text('SAVE',
              style: GoogleFonts.inter(color: AppTheme.gold, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _label('Name'),
          TextField(controller: _name, decoration: const InputDecoration(hintText: 'e.g. Masjid-e-Huda')),
          const SizedBox(height: 12),

          _label('Area'),
          TextField(controller: _area, decoration: const InputDecoration(hintText: 'e.g. Kotamitta')),
          const SizedBox(height: 12),

          _label('Address (optional)'),
          TextField(controller: _address, maxLines: 2),
          const SizedBox(height: 12),

          _label('Phone (optional)'),
          TextField(controller: _phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),

          // GPS capture button — the key feature for admins standing at a masjid
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _gpsLoading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.my_location),
              label: Text(_gpsLoading ? 'Getting location…' : '📍 Use my current location'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: AppTheme.cream,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _gpsLoading ? null : _fetchGps,
            ),
          ),
          const SizedBox(height: 6),
          Text('Stand inside the masjid and tap the button above for exact coordinates',
            style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11),
            textAlign: TextAlign.center),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Latitude'),
              TextField(
                controller: _lat,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]'))],
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Longitude'),
              TextField(
                controller: _lng,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]'))],
              ),
            ])),
          ]),
          const SizedBox(height: 4),
          Text('Or paste manually from Google Maps',
            style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11)),

          const SizedBox(height: 24),
          Text('PRAYER TIMINGS',
            style: GoogleFonts.inter(
              color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              children: _prayers.map((p) => Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(children: [
                  SizedBox(width: 80, child: Text(_names[p]!,
                    style: GoogleFonts.amiri(
                      color: AppTheme.cream, fontSize: 15, fontWeight: FontWeight.bold))),
                  Expanded(child: _timeField(_adhan[p]!, 'Adhan')),
                  const SizedBox(width: 8),
                  Expanded(child: _timeField(_jamaat[p]!, 'Jamaat')),
                ]),
              )).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(s, style: GoogleFonts.inter(
      color: AppTheme.textLo, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
  );

  Widget _timeField(TextEditingController c, String hint) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final t = await _pickTime(c.text);
        if (t != null) setState(() => c.text = _fmt(t));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hint, style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 9, letterSpacing: 0.5)),
            Text(c.text.isEmpty ? '--:--' : c.text,
              style: GoogleFonts.inter(
                color: c.text.isEmpty ? AppTheme.textLo : AppTheme.gold,
                fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
