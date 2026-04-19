import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart' show Share;
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../theme.dart';
import 'login.dart';

class MasjidDetailScreen extends StatefulWidget {
  final Masjid masjid;
  const MasjidDetailScreen({super.key, required this.masjid});
  @override
  State<MasjidDetailScreen> createState() => _MasjidDetailScreenState();
}

class _MasjidDetailScreenState extends State<MasjidDetailScreen> {
  List<Timing> _timings = [];
  bool _loading = true;
  Map<String, dynamic>? _me;      // null = not logged in
  bool _canAdminEdit = false;     // super admin OR this-masjid admin/imam/moazzan
  late Masjid _m;                 // mutable copy so we can reflect verify state

  static const _editableRoles = {
    'masjid_admin', 'imam', 'moazzan'
  };

  @override
  void initState() {
    super.initState();
    _m = widget.masjid;
    if (widget.masjid.timings.isNotEmpty) {
      _timings = List.of(widget.masjid.timings);
      _loading = false;
    } else {
      Api.getTimings(widget.masjid.id).then((t) {
        if (mounted) setState(() { _timings = t; _loading = false; });
      });
    }
    _loadMe();
  }

  Future<void> _verify() async {
    try {
      await Api.verifyMasjid(_m.id);
      if (!mounted) return;
      setState(() {
        _m = _m.copyWith(verifiedDaysAgo: 0, verificationStatus: 'fresh');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as verified — thank you!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _loadMe() async {
    final me = await Api.me();
    if (!mounted) return;
    bool canEdit = false;
    if (me != null) {
      if (me['is_super_admin'] == true) {
        canEdit = true;
      } else {
        final roles = (me['roles'] as List?) ?? [];
        for (final r in roles) {
          if (r['masjid_id'] == widget.masjid.id &&
              r['status'] == 'active' &&
              _editableRoles.contains(r['role'])) {
            canEdit = true; break;
          }
        }
      }
    }
    setState(() { _me = me; _canAdminEdit = canEdit; });
  }

  static const _names = {
    'fajr': 'Fajr', 'dhuhr': 'Dhuhr', 'asr': 'Asr',
    'maghrib': 'Maghrib', 'isha': 'Isha', 'jumuah': "Jumu'ah",
  };
  String _short(String t) => t.length >= 5 ? t.substring(0, 5) : t;
  String _pad(String t) => t.length == 5 ? '$t:00' : t;

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
    if (m.address != null && m.address!.isNotEmpty) lines.add(m.address!);
    if (m.lat != null && m.lng != null) {
      lines.add('');
      lines.add('📌 Open in Google Maps:');
      lines.add(_mapsUrl(m));
    }
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

  /// Open the time editor. For admins, saves directly. For logged-in non-admins,
  /// submits a suggestion. Logged-out users are bounced to the login screen.
  Future<void> _editTiming(Timing t) async {
    // Require login — anyone who can see this button is logged in, but belt and braces
    if (_me == null) {
      final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (ok != true) return;
      await _loadMe();
    }

    final adhan = await _pickTime(t.adhanTime, 'Adhan');
    if (adhan == null) return;
    final jamaat = await _pickTime(t.jamaatTime, 'Jamaat');
    if (jamaat == null) return;

    // Confirm
    if (!mounted) return;
    final msg = _canAdminEdit
      ? 'Update ${_names[t.prayer]} to Adhan $adhan / Jamaat $jamaat?'
      : 'Suggest ${_names[t.prayer]} change to Adhan $adhan / Jamaat $jamaat?\n\nThis will be reviewed by an admin before going live.';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(_canAdminEdit ? 'Save time change' : 'Submit suggestion'),
        content: Text(msg, style: GoogleFonts.inter(color: AppTheme.textMid)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_canAdminEdit ? 'Save' : 'Submit'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (_canAdminEdit) {
        await Api.adminUpdateTimings(widget.masjid.id, [
          Timing(prayer: t.prayer, adhanTime: _pad(adhan), jamaatTime: _pad(jamaat)),
        ]);
        // Update local state
        setState(() {
          final i = _timings.indexWhere((x) => x.prayer == t.prayer);
          if (i >= 0) {
            _timings[i] = Timing(prayer: t.prayer,
              adhanTime: _pad(adhan), jamaatTime: _pad(jamaat));
          }
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated')));
      } else {
        await Api.suggestTiming(widget.masjid.id, t.prayer,
                                 _pad(adhan), _pad(jamaat), null);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suggestion submitted for admin review')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')));
    }
  }

  Future<String?> _pickTime(String current, String label) async {
    int h = 5, m = 0;
    if (current.length >= 5) {
      h = int.tryParse(current.substring(0, 2)) ?? 5;
      m = int.tryParse(current.substring(3, 5)) ?? 0;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
      helpText: 'Pick $label time',
    );
    if (picked == null) return null;
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  /// Bounce to login if not signed in, then open the review dialog.
  Future<void> _becomeMember() async {
    if (_me == null) {
      final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (ok != true) return;
      await _loadMe();
      if (_me == null) return;
    }
    // Check if already a member of THIS masjid
    final roles = (_me!['roles'] as List?) ?? [];
    final existing = roles.firstWhere(
      (r) => r['masjid_id'] == widget.masjid.id && r['role'] == 'member',
      orElse: () => null);
    if (existing != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          existing['status'] == 'active'
            ? 'You are already a member of this masjid'
            : 'Membership request is ${existing['status']} — pending admin approval')));
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Register as a member',
          style: GoogleFonts.amiri(color: AppTheme.cream, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('of ${widget.masjid.name}',
              style: GoogleFonts.inter(color: AppTheme.gold, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _reviewRow('Name',  _me!['name'] ?? ''),
            _reviewRow('Phone', _me!['phone'] ?? ''),
            if ((_me!['email'] ?? '').toString().isNotEmpty)
              _reviewRow('Email', _me!['email']),
            const SizedBox(height: 12),
            Text('Your request will be reviewed by the masjid admin.',
              style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11.5)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await Api.registerAsMember(widget.masjid.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membership request submitted — awaiting admin approval')));
      // refresh our cached profile so the dialog next time says "pending"
      _loadMe();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')));
    }
  }

  Widget _verificationBanner() {
    final status = _m.verificationStatus;
    final days = _m.verifiedDaysAgo;

    late Color bg, fg, border;
    late IconData icon;
    late String title, sub;
    switch (status) {
      case 'fresh':
        bg = const Color(0x3315803D); fg = const Color(0xFF86EFAC);
        border = const Color(0xFF15803D);
        icon = Icons.verified; title = 'Verified'; sub = 'Times confirmed $days day${days == 1 ? '' : 's'} ago';
        break;
      case 'stale':
        bg = const Color(0x33D4AF37); fg = AppTheme.gold; border = AppTheme.gold;
        icon = Icons.warning_amber_rounded;
        title = 'Please verify'; sub = 'Not verified in $days days — admins, please confirm times are still correct';
        break;
      case 'alarm':
        bg = const Color(0x33DC2626); fg = const Color(0xFFFCA5A5);
        border = const Color(0xFFDC2626);
        icon = Icons.error_outline;
        title = 'Times may be outdated';
        sub = 'Not verified in $days days — timings shown may be wrong';
        break;
      default:  // 'never'
        bg = const Color(0x1A738880); fg = AppTheme.textMid; border = AppTheme.line;
        icon = Icons.help_outline;
        title = 'Not yet verified'; sub = 'An admin hasn\'t confirmed these times recently';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border.withOpacity(0.6)),
        ),
        child: Row(children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(
                  color: fg, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                Text(sub, style: GoogleFonts.inter(
                  color: fg.withOpacity(0.85), fontSize: 11.5)),
              ],
            ),
          ),
          if (_canAdminEdit && status != 'fresh') ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Verify', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 0),
              ),
              onPressed: _verify,
            ),
          ],
        ]),
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 56,
          child: Text(label,
            style: GoogleFonts.inter(
              color: AppTheme.textLo, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
        Expanded(
          child: Text(value,
            style: GoogleFonts.inter(
              color: AppTheme.cream, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
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
          // Gradient header card
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

          // Directions + Share
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

          // Verification badge (+ verify button for admins)
          _verificationBanner(),

          // Prayer timings header
          Row(children: [
            Text('PRAYER TIMINGS',
              style: GoogleFonts.inter(
                color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const Spacer(),
            if (_me != null && !_loading)
              Text(_canAdminEdit ? 'tap to edit' : 'tap to suggest',
                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 10.5, letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.line),
            ),
            child: _loading
              ? const Padding(padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.gold)))
              : Column(
                  children: List.generate(_timings.length, (i) {
                    final t = _timings[i];
                    final last = i == _timings.length - 1;
                    return InkWell(
                      onTap: _me != null ? () => _editTiming(t) : null,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(
                            color: last ? Colors.transparent : AppTheme.line)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        child: Row(children: [
                          SizedBox(
                            width: 28,
                            child: Text('${i + 1}.',
                              style: GoogleFonts.inter(
                                color: AppTheme.textLo, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            child: Text(_names[t.prayer] ?? t.prayer,
                              style: GoogleFonts.amiri(
                                color: AppTheme.cream, fontSize: 18, fontWeight: FontWeight.w700)),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_short(t.jamaatTime),
                                style: GoogleFonts.inter(
                                  color: AppTheme.gold, fontSize: 17, fontWeight: FontWeight.w700)),
                              Text('Adhan ${_short(t.adhanTime)}',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textLo, fontSize: 10.5)),
                            ],
                          ),
                          if (_me != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.edit_outlined,
                              color: AppTheme.gold.withOpacity(0.7), size: 16),
                          ],
                        ]),
                      ),
                    );
                  }),
                ),
          ),

          const SizedBox(height: 22),
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
              onPressed: _becomeMember,
            ),
          ),
        ],
      ),
    );
  }
}
