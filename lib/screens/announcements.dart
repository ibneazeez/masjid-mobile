import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../theme.dart';
import 'create_announcement.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<Announcement> _items = [];
  bool _loading = true;
  String? _err;
  Map<String, dynamic>? _me;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    try {
      final results = await Future.wait([
        Api.announcementsActive(),
        Api.me(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<Announcement>;
        _me = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = '$e'; _loading = false; });
    }
  }

  bool get _canCreate {
    if (_me == null) return false;
    if (_me!['is_super_admin'] == true) return true;
    final roles = (_me!['roles'] as List?) ?? [];
    return roles.any((r) =>
      r['status'] == 'active' &&
      ['masjid_admin','imam','committee_president','committee_secretary'].contains(r['role']));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          if (_canCreate)
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.gold),
              tooltip: 'New announcement',
              onPressed: () async {
                final created = await Navigator.push<bool>(context,
                  MaterialPageRoute(builder: (_) => const CreateAnnouncementScreen()));
                if (created == true) _load();
              },
            ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
        : _err != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, color: AppTheme.textLo, size: 48),
                const SizedBox(height: 10),
                Text(_err!, textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppTheme.textMid)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ]),
            ))
          : _items.isEmpty
            ? Center(child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.campaign_outlined, color: AppTheme.textLo, size: 56),
                  const SizedBox(height: 12),
                  Text('No active announcements',
                    style: GoogleFonts.amiri(color: AppTheme.cream, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Janaza, Eid, special prayers will appear here',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppTheme.textLo)),
                ]),
              ))
            : RefreshIndicator(
                color: AppTheme.gold, backgroundColor: AppTheme.surface,
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _card(_items[i]),
                ),
              ),
    );
  }

  Widget _card(Announcement a) {
    final isSuper = _me != null && _me!['is_super_admin'] == true;
    final color = _kindColor(a.kind);
    final label = _kindLabel(a.kind);
    final icon  = _kindIcon(a.kind);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: a.priority == 'urgent' ? color : AppTheme.line,
          width: a.priority == 'urgent' ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.20),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
              style: GoogleFonts.inter(
                color: color, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            const Spacer(),
            if (a.scope == 'city')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppTheme.gold.withOpacity(0.6)),
                ),
                child: Text('ALL NELLORE',
                  style: GoogleFonts.inter(
                    color: AppTheme.gold, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
            if (!a.isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orangeAccent),
            ],
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title,
              style: GoogleFonts.amiri(
                color: AppTheme.cream, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(a.body,
              style: GoogleFonts.inter(color: AppTheme.textHi, fontSize: 13, height: 1.4)),
            if (a.eventAt != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.event, size: 14, color: AppTheme.gold),
                const SizedBox(width: 6),
                Text(_fmtEvent(a.eventAt!),
                  style: GoogleFonts.inter(
                    color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ],
            if (a.locationText != null && a.locationText!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.place, size: 14, color: AppTheme.textLo),
                const SizedBox(width: 6),
                Expanded(child: Text(a.locationText!,
                  style: GoogleFonts.inter(color: AppTheme.textMid, fontSize: 12))),
              ]),
            ],
            const SizedBox(height: 8),
            Text('From ${a.masjidName}',
              style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11)),
            // Admin actions
            if (isSuper) ...[
              const SizedBox(height: 10),
              Row(children: [
                if (!a.isVerified)
                  TextButton.icon(
                    icon: const Icon(Icons.check, size: 16, color: AppTheme.emeraldSoft),
                    label: const Text('Verify', style: TextStyle(color: AppTheme.emeraldSoft)),
                    onPressed: () async {
                      try { await Api.announcementVerify(a.id); _load(); } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    },
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                  onPressed: () async {
                    try { await Api.announcementDelete(a.id); _load(); } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  String _fmtEvent(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('EEE, d MMM · h:mm a').format(dt);
    } catch (_) { return iso; }
  }

  Color _kindColor(String k) {
    switch (k) {
      case 'janaza': return const Color(0xFFDC2626);
      case 'eid':    return const Color(0xFFD4AF37);
      case 'special_prayer': return const Color(0xFF22A06B);
      default:       return AppTheme.gold;
    }
  }
  IconData _kindIcon(String k) {
    switch (k) {
      case 'janaza': return Icons.priority_high;
      case 'eid':    return Icons.celebration;
      case 'special_prayer': return Icons.mosque;
      default:       return Icons.campaign;
    }
  }
  String _kindLabel(String k) {
    switch (k) {
      case 'janaza': return 'JANAZA';
      case 'eid':    return 'EID PRAYER';
      case 'special_prayer': return 'SPECIAL PRAYER';
      default:       return 'ANNOUNCEMENT';
    }
  }
}
