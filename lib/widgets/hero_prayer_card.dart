import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api.dart';
import '../services/prayer_calc.dart';
import '../services/tahajjud_streak.dart';
import '../services/user_prefs.dart';
import '../theme.dart';

/// Big "next prayer" hero card — the focal point of the home screen.
/// Shows the closest masjid + the next prayer name + a live countdown,
/// with all 5 daily prayers listed below and the active one highlighted.
/// Optional end-times and nafil rows are driven by user settings.
class HeroPrayerCard extends StatefulWidget {
  final Masjid masjid;
  final DateTime now;
  const HeroPrayerCard({super.key, required this.masjid, required this.now});

  @override
  State<HeroPrayerCard> createState() => _HeroPrayerCardState();
}

class _HeroPrayerCardState extends State<HeroPrayerCard> {
  static const _names = {
    'fajr': 'Fajr', 'dhuhr': 'Dhuhr', 'asr': 'Asr',
    'maghrib': 'Maghrib', 'isha': 'Isha', 'jumuah': "Jumu'ah",
  };

  PrayerDay? _today;
  PrayerDay? _tomorrow;
  NafilFlags _nafil = NafilFlags();
  bool _showEnds = true;
  StreakState? _streak;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HeroPrayerCard old) {
    super.didUpdateWidget(old);
    // Re-load if user navigated to a different masjid (different lat/lng).
    if (old.masjid.id != widget.masjid.id) _load();
  }

  Future<void> _load() async {
    final nafil   = await UserPrefs.nafil();
    final endsOn  = await UserPrefs.showEndTimes();
    final streak  = await TahajjudStreak.read();
    final lat = widget.masjid.lat, lng = widget.masjid.lng;
    PrayerDay? today, tomorrow;
    if (lat != null && lng != null) {
      today    = await PrayerCalc.dayFor(lat, lng, widget.now);
      tomorrow = await PrayerCalc.dayFor(lat, lng,
                   widget.now.add(const Duration(days: 1)));
    }
    if (!mounted) return;
    setState(() {
      _nafil = nafil; _showEnds = endsOn; _streak = streak;
      _today = today; _tomorrow = tomorrow;
    });
  }

  String _short(String t) => t.length >= 5 ? t.substring(0, 5) : t;

  String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _countdown(Timing next) {
    final p = next.jamaatTime.split(':');
    final pMin = int.parse(p[0]) * 60 + int.parse(p[1]);
    final nowMin = widget.now.hour * 60 + widget.now.minute;
    int diff = pMin - nowMin;
    if (diff <= 0) diff += 24 * 60;
    if (diff < 60) return 'in ${diff}m';
    return 'in ${diff ~/ 60}h ${diff % 60}m';
  }

  /// Window-end time for a given prayer name, if astronomical data loaded.
  String? _endFor(String prayer) {
    if (_today == null) return null;
    final w = _today!.windows.where((x) => x.name == prayer).cast<PrayerWindow?>().firstOrNull;
    return w == null ? null : _hhmm(w.end);
  }

  Future<void> _markTahajjud() async {
    final s = await TahajjudStreak.markToday();
    if (!mounted) return;
    setState(() => _streak = s);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Tahajjud streak: ${s.current} day${s.current == 1 ? "" : "s"} 🌙'),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.masjid.nextPrayer(widget.now);
    final isFri = widget.now.weekday == DateTime.friday;
    final dailyPrayers = widget.masjid.timings.where((t) {
      if (isFri) return t.prayer != 'dhuhr';
      return t.prayer != 'jumuah';
    }).toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E6E44), Color(0xFF053B2A), Color(0xFF071A14)],
          stops: [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: AppTheme.gold.withOpacity(0.45), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emerald.withOpacity(0.30),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mosque, size: 16, color: AppTheme.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.masjid.name,
                  style: GoogleFonts.inter(
                    color: AppTheme.cream,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (widget.masjid.distanceKm != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.30),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppTheme.gold.withOpacity(0.40)),
                  ),
                  child: Text(
                    '${widget.masjid.distanceKm!.toStringAsFixed(1)} km',
                    style: GoogleFonts.inter(
                      color: AppTheme.goldSoft, fontSize: 10.5, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'NEXT PRAYER',
            style: GoogleFonts.inter(
              color: AppTheme.gold.withOpacity(0.85),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          if (next == null)
            Text('Timings not set',
              style: GoogleFonts.amiri(color: AppTheme.cream, fontSize: 28, fontWeight: FontWeight.bold))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _names[next.prayer] ?? next.prayer,
                  style: GoogleFonts.amiri(
                    color: AppTheme.cream,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _short(next.jamaatTime),
                    style: GoogleFonts.inter(
                      color: AppTheme.goldSoft,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          if (next != null) ...[
            const SizedBox(height: 2),
            Text(
              _countdown(next),
              style: GoogleFonts.inter(
                color: AppTheme.cream.withOpacity(0.75),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (dailyPrayers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.gold.withOpacity(0.18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: dailyPrayers.map((t) {
                  final isNext = next != null && t.prayer == next.prayer;
                  final endsAt = _showEnds ? _endFor(t.prayer) : null;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _names[t.prayer] ?? t.prayer,
                        style: GoogleFonts.inter(
                          color: isNext ? AppTheme.gold : AppTheme.cream.withOpacity(0.65),
                          fontSize: 10.5,
                          fontWeight: isNext ? FontWeight.w800 : FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _short(t.jamaatTime),
                        style: GoogleFonts.inter(
                          color: isNext ? AppTheme.goldSoft : AppTheme.cream.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      if (endsAt != null) ...[
                        const SizedBox(height: 2),
                        Text('ends $endsAt',
                          style: GoogleFonts.inter(
                            color: AppTheme.cream.withOpacity(0.45),
                            fontSize: 9, fontWeight: FontWeight.w500)),
                      ],
                    ],
                  );
                }).toList(),
              ),
            ),
          // Friday Jumu'ah preview
          if (widget.masjid.jumuah != null && !isFri) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.gold.withOpacity(0.30)),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 12, color: AppTheme.goldSoft),
                const SizedBox(width: 6),
                Text("Friday Jumu'ah",
                  style: GoogleFonts.inter(
                    color: AppTheme.cream.withOpacity(0.78),
                    fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                const Spacer(),
                Text(_short(widget.masjid.jumuah!.jamaatTime),
                  style: GoogleFonts.inter(
                    color: AppTheme.gold, fontSize: 13.5, fontWeight: FontWeight.w800)),
              ]),
            ),
          ],
          // Optional nafil prayers
          if (_nafil.any && _today != null) _nafilPanel(),
        ],
      ),
    );
  }

  Widget _nafilPanel() {
    final nextDayFajr = _tomorrow?.fajr ??
        _today!.fajr.add(const Duration(days: 1));
    final list = _today!.nafil(_nafil, nextDayFajr);
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.gold.withOpacity(0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NAFIL',
              style: GoogleFonts.inter(
                color: AppTheme.gold.withOpacity(0.8),
                fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            ...list.map(_nafilRow),
          ],
        ),
      ),
    );
  }

  Widget _nafilRow(NafilWindow w) {
    final active = w.active(widget.now);
    final isTahajjud = w.name == 'tahajjud';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(isTahajjud ? Icons.nightlight_round : Icons.brightness_5,
          size: 12,
          color: active ? AppTheme.gold : AppTheme.cream.withOpacity(0.45)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(w.label,
            style: GoogleFonts.amiri(
              color: active ? AppTheme.gold : AppTheme.cream.withOpacity(0.75),
              fontSize: 14,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600)),
        ),
        Text('${_hhmm(w.start)}–${_hhmm(w.end)}',
          style: GoogleFonts.inter(
            color: active ? AppTheme.goldSoft : AppTheme.cream.withOpacity(0.55),
            fontSize: 11, fontWeight: FontWeight.w600)),
        if (isTahajjud && _streak != null) ...[
          const SizedBox(width: 8),
          _tahajjudChip(),
        ],
      ]),
    );
  }

  Widget _tahajjudChip() {
    final s = _streak!;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: s.markedToday ? null : _markTahajjud,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: s.markedToday
            ? AppTheme.emerald.withOpacity(0.4)
            : Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppTheme.gold.withOpacity(0.55)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(s.markedToday ? Icons.check_circle : Icons.add_circle_outline,
            size: 11, color: AppTheme.goldSoft),
          const SizedBox(width: 3),
          Text(s.current > 0 ? '${s.current}d' : 'mark',
            style: GoogleFonts.inter(
              color: AppTheme.cream, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T?> {
  T? get firstOrNull => isEmpty ? null : first;
}
