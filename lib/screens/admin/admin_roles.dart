import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api.dart';
import '../../theme.dart';

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});
  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _query = '';
  Timer? _debounce;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await Api.adminListAssignments();
      if (!mounted) return;
      setState(() {
        _all = list;
        _filtered = _applyFilter(_query);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  List<Map<String, dynamic>> _applyFilter(String q) {
    if (q.length < 3) return _all;
    final s = q.toLowerCase();
    return _all.where((r) =>
      ((r['user_name']    ?? '').toString().toLowerCase().contains(s)) ||
      ((r['user_phone']   ?? '').toString().toLowerCase().contains(s)) ||
      ((r['user_email']   ?? '').toString().toLowerCase().contains(s)) ||
      ((r['masjid_name']  ?? '').toString().toLowerCase().contains(s)) ||
      ((r['role']         ?? '').toString().toLowerCase().contains(s))
    ).toList();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() { _query = v; _filtered = _applyFilter(v); });
    });
  }

  Future<void> _setStatus(Map<String, dynamic> r, String newStatus) async {
    try {
      await Api.adminCreateAssignment(
        userPhoneOrEmail: (r['user_email'] ?? r['user_phone']).toString(),
        masjidId: r['masjid_id'],
        role: r['role'],
        status: newStatus,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus == 'active' ? 'Approved' : 'Rejected')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(int id, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Remove role?'),
        content: Text(label),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('REMOVE', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.adminDeleteAssignment(id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Roles & Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.gold),
            tooltip: 'Assign role',
            onPressed: () async {
              final added = await showDialog<bool>(
                context: context, builder: (_) => const _AddRoleDialog());
              if (added == true) _load();
            },
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by user, masjid, role (3+ chars)…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixText: '${_filtered.length}/${_all.length}',
              suffixStyle: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11),
            ),
            onChanged: _onSearch,
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.gold)))
        else if (_filtered.isEmpty)
          Expanded(child: Center(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.assignment_ind, color: AppTheme.textLo, size: 48),
              const SizedBox(height: 12),
              Text(_all.isEmpty ? 'No role assignments yet' : 'No results',
                style: GoogleFonts.inter(color: AppTheme.textLo)),
              const SizedBox(height: 4),
              Text('Tap + to assign someone as masjid_admin, imam, or member',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11.5)),
            ]),
          )))
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
                  final r = _filtered[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r['user_name'] ?? '(unknown)',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.cream, fontWeight: FontWeight.w700, fontSize: 13.5)),
                                Text(r['user_email'] ?? r['user_phone'] ?? '',
                                  style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11)),
                                const SizedBox(height: 6),
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  _chip(r['masjid_name'] ?? '?', AppTheme.surfaceAlt, AppTheme.cream),
                                  _chip(r['role'] ?? '?',
                                    AppTheme.emerald.withOpacity(0.30), AppTheme.cream,
                                    outline: AppTheme.emerald.withOpacity(0.7)),
                                  _chip(r['status'] ?? '?',
                                    r['status'] == 'active'
                                      ? AppTheme.gold.withOpacity(0.20)
                                      : r['status'] == 'pending'
                                        ? const Color(0x552563EB)
                                        : AppTheme.surfaceAlt,
                                    r['status'] == 'active' ? AppTheme.gold
                                    : r['status'] == 'pending' ? const Color(0xFF93C5FD)
                                    : AppTheme.textMid,
                                    outline: r['status'] == 'active'
                                      ? AppTheme.gold.withOpacity(0.5)
                                      : AppTheme.line),
                                ]),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _delete(r['id'],
                              '${r['user_name']} → ${r['masjid_name']} (${r['role']})'),
                          ),
                        ]),
                        // Approve / Reject buttons for pending assignments
                        if (r['status'] == 'pending') ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                                label: const Text('Reject', style: TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  minimumSize: const Size(0, 0),
                                ),
                                onPressed: () => _setStatus(r, 'rejected'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Approve', style: TextStyle(fontSize: 12.5)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.emerald,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  minimumSize: const Size(0, 0),
                                ),
                                onPressed: () => _setStatus(r, 'active'),
                              ),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ]),
    );
  }

  Widget _chip(String text, Color bg, Color fg, {Color? outline}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: outline ?? AppTheme.line),
      ),
      child: Text(text,
        style: GoogleFonts.inter(color: fg, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }
}

class _AddRoleDialog extends StatefulWidget {
  const _AddRoleDialog();
  @override
  State<_AddRoleDialog> createState() => _AddRoleDialogState();
}

class _AddRoleDialogState extends State<_AddRoleDialog> {
  final _userCtrl = TextEditingController();
  int? _masjidId;
  String _role = 'masjid_admin';
  String _status = 'active';
  bool _busy = false;
  List<Masjid> _masjids = [];

  static const _roleOptions = [
    'masjid_admin','imam','moazzan','khateeb',
    'committee_president','committee_secretary','committee_treasurer','committee_member','member',
  ];
  static const _statusOptions = ['active','pending','rejected'];

  @override
  void initState() {
    super.initState();
    Api.listMasjids(page: 0, size: 200).then((p) {
      if (mounted) setState(() => _masjids = p.items);
    });
  }

  Future<void> _save() async {
    if (_userCtrl.text.trim().isEmpty || _masjidId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User and masjid are required')));
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.adminCreateAssignment(
        userPhoneOrEmail: _userCtrl.text.trim(),
        masjidId: _masjidId!,
        role: _role,
        status: _status,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Assign role',
        style: GoogleFonts.amiri(color: AppTheme.cream, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('USER (phone or email)',
              style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            TextField(controller: _userCtrl,
              decoration: const InputDecoration(hintText: '+91… or someone@gmail.com')),
            const SizedBox(height: 12),

            Text('MASJID',
              style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              value: _masjidId,
              items: _masjids.map((m) => DropdownMenuItem(
                value: m.id,
                child: Text('${m.name} · ${m.area}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.cream)),
              )).toList(),
              onChanged: (v) => setState(() => _masjidId = v),
              dropdownColor: AppTheme.surface,
              decoration: const InputDecoration(hintText: 'pick masjid'),
            ),
            const SizedBox(height: 12),

            Text('ROLE',
              style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _role,
              items: _roleOptions.map((r) => DropdownMenuItem(value: r,
                child: Text(r, style: const TextStyle(color: AppTheme.cream)))).toList(),
              onChanged: (v) => setState(() => _role = v ?? 'masjid_admin'),
              dropdownColor: AppTheme.surface,
            ),
            const SizedBox(height: 12),

            Text('STATUS',
              style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _status,
              items: _statusOptions.map((s) => DropdownMenuItem(value: s,
                child: Text(s, style: const TextStyle(color: AppTheme.cream)))).toList(),
              onChanged: (v) => setState(() => _status = v ?? 'active'),
              dropdownColor: AppTheme.surface,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
          onPressed: _busy ? null : _save,
          child: _busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Assign'),
        ),
      ],
    );
  }
}
