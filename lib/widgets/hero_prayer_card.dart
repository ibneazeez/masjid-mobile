import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api.dart';
import '../theme.dart';

/// Big "next prayer" hero card — the focal point of the home screen.
/// Shows the closest masjid + the next prayer name + a live countdown,
/// with all 5 daily prayers listed below and the active one highlighted.
class HeroPrayerCard extends StatelessWidget {
  final Masjid masjid;
  final DateTime now;
  const HeroPrayerCard({super.key, required this.masjid, required this.now});

  static const _names = {
    'fajr': 'Fajr', 'dhuhr': 'Dhuhr', 'asr': 'Asr',
    'maghrib': 'Maghrib', 'isha': 'Isha', 'jumuah': "Jumu'ah",
  };

  String _short(String t) => t.length >= 5 ? t.substring(0, 5) : t;

  String _countdown(Timing next) {
    final p = next.jamaatTime.split(':');
    final pMin = int.parse(p[0]) * 60 + int.parse(p[1]);
    final nowMin = now.hour * 60 + now.minute;
    int diff = pMin - nowMin;
    if (diff <= 0) diff += 24 * 60; // tomorrow
    if (diff < 60) return 'in ${diff}m';
    return 'in ${diff ~/ 60}h ${diff % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final next = masjid.nextPrayer(now);
    final isFri = now.weekday == DateTime.friday;
    // On Friday, Jumu'ah replaces Dhuhr; on other days, hide Jumu'ah.
    final dailyPrayers = masjid.timings.where((t) {
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
                  masjid.name,
                  style: GoogleFonts.inter(
                    color: AppTheme.cream,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (masjid.distanceKm != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.30),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppTheme.gold.withOpacity(0.40)),
                  ),
                  child: Text(
                    '${masjid.distanceKm!.toStringAsFixed(1)} km',
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
            Text('Timings not set', style: GoogleFonts.amiri(color: AppTheme.cream, fontSize: 28, fontWeight: FontWeight.bold))
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
                    ],
                  );
                }).toList(),
              ),
            ),
          // Jumu'ah preview — only on non-Fridays (on Friday it's already in the main row)
          if (masjid.jumuah != null && !isFri) ...[
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
                Text(_short(masjid.jumuah!.jamaatTime),
                  style: GoogleFonts.inter(
                    color: AppTheme.gold, fontSize: 13.5, fontWeight: FontWeight.w800)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}
