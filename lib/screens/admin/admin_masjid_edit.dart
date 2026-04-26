import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../api.dart';
import '../../services/prayer_calc.dart';
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
  late final TextEditingController _fajrOffset;
  late final TextEditingController _maghribOffset;
  bool _autoCompute = false;
  int _fajrRoundTo = 5;
  bool _busy = false;
  bool _gpsLoading = false;
  bool _geocoding = false;
  DateTime? _sunsetToday;          // resolved from PrayerCalc once lat/lng known

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
    _fajrOffset    = TextEditingController(text: (m?.fajrOffsetMin ?? 22).toString());
    _maghribOffset = TextEditingController(text: (m?.maghribOffsetMin ?? 0).toString());
    _autoCompute   = m?.autoComputeEnabled ?? false;
    _fajrRoundTo   = m?.fajrRoundToMin ?? 5;
    for (final p in _prayers) {
      final t = m?.timings.where((x) => x.prayer == p).firstOrNull;
      _adhan[p]  = TextEditingController(text: _short(t?.adhanTime));
      _jamaat[p] = TextEditingController(text: _short(t?.jamaatTime));
    }
    if (m?.lat != null && m?.lng != null) _loadSunset(m!.lat!, m.lng!);
  }

  /// Fetch today's sunset for this masjid's location so the Maghrib time
  /// picker can derive offset from (picked time - sunset).
  Future<void> _loadSunset(double lat, double lng) async {
    final day = await PrayerCalc.dayFor(lat, lng, DateTime.now());
    if (!mounted || day == null) return;
    setState(() => _sunsetToday = day.sunset);
  }

  /// Reverse-geocode lat/lng to address+area via Nominatim. Best-effort.
  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() => _geocoding = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json'
        '&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
      final r = await http.get(url, headers: {
        'User-Agent': 'masjid-eesa-mobile/1.0',
      }).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final addr = (j['address'] ?? {}) as Map<String, dynamic>;
      final area = addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter']
                 ?? addr['locality'] ?? addr['village'] ?? addr['city_district'];
      final display = j['display_name']?.toString() ?? '';
      if (mounted) {
        setState(() {
          // Only fill empty fields; never overwrite admin's text
          if (_address.text.trim().isEmpty && display.isNotEmpty) _address.text = display;
          if (_area.text.trim().isEmpty && area != null) _area.text = area.toString();
        });
      }
    } catch (_) {/* silent */} finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  /// For a NEW masjid, fetch the nearest existing masjid and copy its
  /// timings into the form so admin starts with reasonable defaults.
  Future<void> _prefillFromNearest(double lat, double lng) async {
    if (!isNew) return;
    final allFilled = _prayers.every((p) =>
      _adhan[p]!.text.isNotEmpty && _jamaat[p]!.text.isNotEmpty);
    if (allFilled) return;
    try {
      final page = await Api.listMasjids(lat: lat, lng: lng, withTimings: true,
                                          page: 0, size: 1);
      if (page.items.isEmpty) return;
      final near = page.items.first;
      if (mounted) setState(() {
        for (final p in _prayers) {
          final t = near.timings.where((x) => x.prayer == p).firstOrNull;
          if (t != null) {
            if (_adhan[p]!.text.isEmpty)  _adhan[p]!.text  = _short(t.adhanTime);
            if (_jamaat[p]!.text.isEmpty) _jamaat[p]!.text = _short(t.jamaatTime);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pre-filled timings from nearest masjid: ${near.name}')));
      });
    } catch (_) {/* silent */}
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
      // Auto-populate address from GPS + prefill timings from nearest masjid
      await _reverseGeocode(pos.latitude, pos.longitude);
      await _prefillFromNearest(pos.latitude, pos.longitude);
      await _loadSunset(pos.latitude, pos.longitude);
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

      // Add adjustment fields
      body['auto_compute_enabled'] = _autoCompute;
      body['fajr_round_to_min']    = _fajrRoundTo;
      final fajrOff = int.tryParse(_fajrOffset.text.trim());
      if (fajrOff != null) body['fajr_offset_min'] = fajrOff;
      final magOff = int.tryParse(_maghribOffset.text.trim());
      if (magOff != null) body['maghrib_offset_min'] = magOff;

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
      // Ask "Verify or leave Unverified" instead of auto-stamping
      final verify = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(isNew ? 'Created — verify timings?' : 'Saved — verify timings?'),
          content: Text(
            'Are you confident the timings shown are correct right now?\n\n'
            'If yes, tap "Verify" to mark them fresh. Otherwise leave as '
            'unverified — admins can review later.',
            style: GoogleFonts.inter(color: AppTheme.textMid),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Leave unverified'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.check, size: 16),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
              onPressed: () => Navigator.pop(context, true),
              label: const Text('Verify now'),
            ),
          ],
        ),
      );
      if (verify == true) {
        try { await Api.verifyMasjid(masjidId); } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(verify == true ? 'Saved & verified' : 'Saved (unverified)')));
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
          Text('TIMING ADJUSTMENTS',
            style: GoogleFonts.inter(
              color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(children: [
              SwitchListTile(
                value: _autoCompute,
                activeColor: AppTheme.gold,
                title: Text('Auto-compute Fajr daily',
                  style: GoogleFonts.inter(
                    color: AppTheme.cream, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _autoCompute
                    ? 'Fajr jamaat = astronomical Fajr + offset, rounded — refreshed nightly'
                    : 'Fajr stays at the manual time you set below',
                  style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11.5)),
                onChanged: (v) => setState(() => _autoCompute = v),
              ),
              const Divider(height: 1, color: AppTheme.line),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Fajr offset (minutes after astronomical Fajr)'),
                  TextField(
                    controller: _fajrOffset,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(hintText: '22',
                      helperText: 'Common: 17–25 min'),
                  ),
                  const SizedBox(height: 12),
                  _label('Round Fajr jamaat to nearest'),
                  Wrap(spacing: 8, children: [1, 5, 10, 15].map((n) {
                    final sel = _fajrRoundTo == n;
                    return ChoiceChip(
                      label: Text('$n min'),
                      selected: sel,
                      onSelected: (_) => setState(() => _fajrRoundTo = n),
                      selectedColor: AppTheme.gold,
                      backgroundColor: AppTheme.surfaceAlt,
                      labelStyle: TextStyle(
                        color: sel ? AppTheme.bg : AppTheme.cream,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w500),
                    );
                  }).toList()),
                  const SizedBox(height: 4),
                  Text('5 min gives the round-figure pattern most masjids use (05:00, 05:05…)',
                    style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11)),
                  const SizedBox(height: 14),
                  _label('Maghrib jamaat time'),
                  _maghribTimePicker(),
                  const SizedBox(height: 4),
                  Text(
                    _sunsetToday != null
                      ? 'Today\'s sunset: ${_hhmm(_sunsetToday!)} — '
                        'editing the time updates the offset (currently '
                        '${_maghribOffset.text} min after sunset).'
                      : _lat.text.isEmpty
                        ? 'Set GPS coordinates above to enable time picker.'
                        : 'Loading sunset for this location…',
                    style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11)),
                ]),
              ),
            ]),
          ),

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

  String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Time picker for Maghrib that derives offset = picked - sunset.
  /// Updates BOTH _maghribOffset (for the offset column) and the Maghrib
  /// row in PRAYER TIMINGS so the change is immediate end-to-end.
  Widget _maghribTimePicker() {
    final sunset = _sunsetToday;
    final offMin = int.tryParse(_maghribOffset.text.trim()) ?? 5;
    final displayTime = sunset == null
        ? (_jamaat['maghrib']?.text ?? '')
        : _hhmm(sunset.add(Duration(minutes: offMin)));

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: sunset == null ? null : () async {
        final picked = await _pickTime(displayTime);
        if (picked == null) return;
        final pickedDt = DateTime(sunset.year, sunset.month, sunset.day,
                                   picked.hour, picked.minute);
        final off = pickedDt.difference(sunset).inMinutes;
        setState(() {
          _maghribOffset.text = off.toString();
          _jamaat['maghrib']!.text = _fmt(picked);
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.gold.withOpacity(sunset == null ? 0.2 : 0.6)),
        ),
        child: Row(children: [
          Icon(Icons.access_time, size: 18,
            color: sunset == null ? AppTheme.textLo : AppTheme.gold),
          const SizedBox(width: 10),
          Text(displayTime.isEmpty ? '--:--' : displayTime,
            style: GoogleFonts.amiri(
              color: sunset == null ? AppTheme.textLo : AppTheme.gold,
              fontSize: 22, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (sunset != null)
            Text('= sunset + ${_maghribOffset.text} min',
              style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11)),
        ]),
      ),
    );
  }

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
