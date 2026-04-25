import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api.dart';
import '../../theme.dart';
import 'admin_masjid_edit.dart';

class AdminMasjidsScreen extends StatefulWidget {
  const AdminMasjidsScreen({super.key});
  @override
  State<AdminMasjidsScreen> createState() => _AdminMasjidsScreenState();
}

class _AdminMasjidsScreenState extends State<AdminMasjidsScreen> {
  List<Masjid> _all = [];
  List<Masjid> _filtered = [];
  bool _loading = true;
  bool _isSuper = false;
  Set<int> _myMasjidIds = {};
  String _query = '';
  Timer? _debounce;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Api.listMasjids(page: 0, size: 200, withTimings: true),
        Api.me(),
      ]);
      final page = results[0] as MasjidPage;
      final me = results[1] as Map<String, dynamic>?;
      _isSuper = me != null && me['is_super_admin'] == true;
      _myMasjidIds = ((me?['roles'] as List?) ?? [])
          .where((r) => r['status'] == 'active' &&
                         {'masjid_admin','imam','moazzan',
                          'committee_president','committee_secretary'}.contains(r['role']))
          .map<int>((r) => r['masjid_id'] as int).toSet();
      // Filter to only the masjids the user manages (super admin sees all)
      var visible = page.items;
      if (!_isSuper) {
        visible = visible.where((m) => _myMasjidIds.contains(m.id)).toList();
      }
      setState(() {
        _all = visible;
        _filtered = _applyFilter(_query);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  List<Masjid> _applyFilter(String q) {
    if (q.length < 3) return _all;
    final s = q.toLowerCase();
    return _all.where((m) => m.name.toLowerCase().contains(s)
                          || m.area.toLowerCase().contains(s)).toList();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() { _query = v; _filtered = _applyFilter(v); });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(_isSuper ? 'Manage Masjids' : 'My Masjids'),
        actions: [
          if (_isSuper)
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.gold),
              tooltip: 'Add masjid',
              onPressed: () async {
                final created = await Navigator.push<bool>(context,
                  MaterialPageRoute(builder: (_) => const AdminMasjidEditScreen()));
                if (created == true) _load();
              },
            ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search (3+ characters)…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixText: '${_filtered.length}/${_all.length}',
              suffixStyle: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.gold)))
        else
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.gold, backgroundColor: AppTheme.surface,
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = _filtered[i];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final saved = await Navigator.push<bool>(context,
                          MaterialPageRoute(builder: (_) => AdminMasjidEditScreen(masjid: m)));
                        if (saved == true) _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.line),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 18, backgroundColor: AppTheme.surfaceAlt,
                            child: Text('${m.id}',
                              style: GoogleFonts.inter(
                                color: AppTheme.goldSoft, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                  style: GoogleFonts.amiri(
                                    color: AppTheme.cream, fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(m.area,
                                  style: GoogleFonts.inter(color: AppTheme.textMid, fontSize: 11.5)),
                              ],
                            ),
                          ),
                          if (m.lat == null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Tooltip(
                                message: 'No coordinates',
                                child: Icon(Icons.location_off, size: 14, color: AppTheme.textLo),
                              ),
                            ),
                          const Icon(Icons.edit, size: 16, color: AppTheme.gold),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ]),
    );
  }
}
