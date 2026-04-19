import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart' show Share;
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../theme.dart';
import 'login.dart';
import 'suggest_timing.dart';

class MasjidDetailScreen extends StatefulWidget {
  final Masjid masjid;
  const MasjidDetailScreen({super.key, required this.masjid});
  @override
  State<MasjidDetailScreen> createState() => _MasjidDetailScreenState();
}

class _MasjidDetailScreenState extends State<MasjidDetailScreen> {
  List<Timing> _timings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.masjid.timings.isNotEmpty) {
      _timings = widget.masjid.timings;
      _loading = false;
    } else {
      Api.getTimings(widget.masjid.id).then((t) {
        if (mounted) setState(() { _timings = t; _loading = false; });
      });
    }
  }

  static const _names = {
    'fajr': 'Fajr', 'dhuhr': 'Dhuhr', 'asr': 'Asr',
    'maghrib': 'Maghrib', 'isha': 'Isha', 'jumuah': "Jumu'ah",
  };
  String _short(String t) => t.length >= 5 ? t.substring(0, 5) : t;

  String _mapsUrl(Masjid m) =>
    'https://www.google.com/maps/search/?api=1&query=${m.lat},${m.lng}';

  String _directionsUrl(Masjid m) =>
    'https://www.google.com/maps/dir/?api=1&destination=${m.lat},${m.lng}&travelmode=driving';

  Future<void> _openDirections(Masjid m) async {
    final url = Uri.parse(_directionsUrl(m));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')));
    }
  }

  Future<void> _openInMap(Masjid m) async {
    final url = Uri.parse(_mapsUrl(m));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')));
    }
  }

  void _shareMasjid(Masjid m) {
    final lines = <String>[
      '🕌 ${m.name}',
      '📍 ${m.area}, Nellore',
    ];
    if (m.address != null && m.address!.isNotEmpty) {
      lines.add(m.address!);
    }
    if (m.lat != null && m.lng != null) {
      lines.add('');
      lines.add('📌 Open in Google Maps:');
      lines.add(_mapsUrl(m));
    }
    // Add next prayer if available
    if (_timings.isNotEmpty) {
      final next = m.nextPrayer(DateTime.now());
      if (next != null) {
        lines.add('');
        lines.add('🕐 Next: ${_names[next.prayer] ?? next.prayer} at ${_short(next.jamaatTime)}');
      }
    }
    lines.add('');
    lines.add('Shared via Masjids of Nellore app');
    Share.share(lines.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.masjid;
    final hasCoords = m.lat != null && m.lng != null;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(m.name, overflow: TextOverflow.ellipsis),
        actions: [
          if (hasCoords)
            IconButton(
              icon: const Icon(Icons.map_outlined, color: AppTheme.gold),
              tooltip: 'Open in Maps',
              onPressed: () => _openInMap(m),
            ),
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.gold),
            tooltip: 'Share',
            onPressed: () => _shareMasjid(m),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0E6E44), Color(0xFF053B2A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.gold.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.bg,
                    border: Border.all(color: AppTheme.gold, width: 1.4),
                  ),
                  child: const Icon(Icons.mosque, color: AppTheme.goldSoft, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name,
                        style: GoogleFonts.amiri(
                          color: AppTheme.cream, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(m.area,
                        style: GoogleFonts.inter(color: AppTheme.cream.withOpacity(0.80), fontSize: 13)),
                      if (m.distanceKm != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.place, size: 13, color: AppTheme.goldSoft),
                          const SizedBox(width: 3),
                          Text('${m.distanceKm!.toStringAsFixed(2)} km away',
                            style: GoogleFonts.inter(
                              color: AppTheme.goldSoft, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (m.address != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textLo),
              const SizedBox(width: 6),
              Expanded(
                child: Text(m.address!,
                  style: GoogleFonts.inter(color: AppTheme.textMid, fontSize: 12.5))),
            ]),
          ],
          const SizedBox(height: 14),

          // Directions + Share buttons
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.directions, size: 18),
                label: const Text('Directions'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: AppTheme.cream,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: hasCoords ? () => _openDirections(m) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.gold,
                  side: const BorderSide(color: AppTheme.gold),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _shareMasjid(m),
              ),
            ),
          ]),
          if (!hasCoords)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Directions unavailable — coordinates not set yet',
                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11),
                textAlign: TextAlign.center),
            ),
          const SizedBox(height: 22),

          Text('PRAYER TIMINGS',
            style: GoogleFonts.inter(
              color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.line),
            ),
            child: _loading
              ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppTheme.gold)))
              : Column(
                  children: List.generate(_timings.length, (i) {
                    final t = _timings[i];
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: i == _timings.length - 1 ? Colors.transparent : AppTheme.line,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${i + 1}.',
                              style: GoogleFonts.inter(
                                color: AppTheme.textLo, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _names[t.prayer] ?? t.prayer,
                              style: GoogleFonts.amiri(
                                color: AppTheme.cream,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _short(t.jamaatTime),
                                style: GoogleFonts.inter(
                                  color: AppTheme.gold,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Adhan ${_short(t.adhanTime)}',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textLo,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ),
          ),

          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Suggest a time change'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.surfaceAlt,
                foregroundColor: AppTheme.gold,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.gold, width: 1.2),
                ),
              ),
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => SuggestTimingScreen(masjid: m))),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Become a Member'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: AppTheme.cream,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
          ),
        ],
      ),
    );
  }
}
