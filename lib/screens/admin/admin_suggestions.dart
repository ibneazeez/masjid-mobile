import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api.dart';
import '../../theme.dart';

class AdminSuggestionsScreen extends StatefulWidget {
  const AdminSuggestionsScreen({super.key});
  @override
  State<AdminSuggestionsScreen> createState() => _AdminSuggestionsScreenState();
}

class _AdminSuggestionsScreenState extends State<AdminSuggestionsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _isSuper = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await Api.me();
      _isSuper = me != null && me['is_super_admin'] == true;
      final myIds = ((me?['roles'] as List?) ?? [])
          .where((r) => r['status'] == 'active' &&
                         {'masjid_admin','imam','moazzan',
                          'committee_president','committee_secretary'}.contains(r['role']))
          .map<int>((r) => r['masjid_id'] as int).toSet();

      var list = <Map<String, dynamic>>[];
      if (_isSuper) {
        list = await Api.adminPendingSuggestions();
      } else if (myIds.isNotEmpty) {
        // Non-super admins: pull all suggestions and filter to their masjids
        list = await Api.adminPendingSuggestions();
        list = list.where((s) => myIds.contains(s['masjid_id'])).toList();
      }
      if (!mounted) return;
      setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _approve(int id) async {
    try {
      await Api.adminApproveSuggestion(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approved — live timings updated')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reject(int id) async {
    try {
      await Api.adminRejectSuggestion(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rejected')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  static const _names = {
    'fajr':'Fajr','dhuhr':'Dhuhr','asr':'Asr',
    'maghrib':'Maghrib','isha':'Isha','jumuah':"Jumu'ah",
  };

  String _short(String? t) {
    if (t == null) return '';
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Pending Suggestions')),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
        : _items.isEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.emeraldSoft, size: 56),
                const SizedBox(height: 12),
                Text('No pending suggestions',
                  style: GoogleFonts.inter(color: AppTheme.cream, fontSize: 16)),
                const SizedBox(height: 4),
                Text('All caught up!',
                  style: GoogleFonts.inter(color: AppTheme.textLo)),
              ]),
            ))
          : RefreshIndicator(
              color: AppTheme.gold, backgroundColor: AppTheme.surface,
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final s = _items[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(s['masjid_name'] ?? '?',
                              style: GoogleFonts.amiri(
                                color: AppTheme.cream, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: AppTheme.gold.withOpacity(0.5)),
                            ),
                            child: Text(_names[s['prayer']] ?? s['prayer'] ?? '',
                              style: GoogleFonts.inter(
                                color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text('Suggested by ${s['suggested_by_name'] ?? 'unknown'}',
                          style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11)),
                        const SizedBox(height: 12),
                        Row(children: [
                          _timeBox('Adhan', _short(s['adhan_time'])),
                          const SizedBox(width: 10),
                          _timeBox('Jamaat', _short(s['jamaat_time'])),
                        ]),
                        if (s['reason'] != null && (s['reason'] as String).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text('"${s['reason']}"',
                            style: GoogleFonts.inter(
                              color: AppTheme.textMid, fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close, color: Colors.redAccent),
                              label: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => _reject(s['id']),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.emerald,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => _approve(s['id']),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _timeBox(String label, String time) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(
              color: AppTheme.textLo, fontSize: 9, letterSpacing: 0.5)),
            Text(time, style: GoogleFonts.inter(
              color: AppTheme.gold, fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
