import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api.dart';
import '../../theme.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _rootSuperAdminEmail = 'mdaneesahmed@gmail.com';

  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  bool _amRoot = false;      // true if current user is the root super admin
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _load();
  }
  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  Future<void> _loadMe() async {
    final me = await Api.me();
    if (!mounted) return;
    final email = (me?['email'] ?? '').toString().toLowerCase();
    setState(() => _amRoot = email == _rootSuperAdminEmail);
  }

  Future<void> _toggleSuper(Map<String, dynamic> u) async {
    final target = !(u['is_super_admin'] == true);
    final action = target ? 'promote' : 'demote';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('${target ? "Make" : "Remove as"} super admin?'),
        content: Text('${target ? "Grant" : "Revoke"} super-admin powers for ${u['name']} (${u['email'] ?? u['phone']})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: target ? AppTheme.gold : Colors.redAccent,
              foregroundColor: target ? AppTheme.bg : Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(target ? 'Promote' : 'Demote'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Api.adminSetSuperAdmin(u['id'], target);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$action-d successfully')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await Api.adminUsers(q: _query.isEmpty ? null : _query);
      if (!mounted) return;
      setState(() { _users = users; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    if (v.length >= 3 || v.isEmpty) {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _query = v;
        _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Users')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, email, phone (3+ chars)…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixText: '${_users.length} users',
              suffixStyle: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11),
            ),
            onChanged: _onSearch,
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.gold)))
        else if (_users.isEmpty)
          Expanded(child: Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_search, color: AppTheme.textLo, size: 48),
              const SizedBox(height: 10),
              Text(_query.isEmpty ? 'No users yet' : 'No match',
                style: GoogleFonts.inter(color: AppTheme.textLo)),
            ]),
          )))
        else
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.gold, backgroundColor: AppTheme.surface,
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                itemCount: _users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final u = _users[i];
                  final pic = u['picture_url'];
                  final isSuper = u['is_super_admin'] == true;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSuper ? AppTheme.gold.withOpacity(0.5) : AppTheme.line),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 22, backgroundColor: AppTheme.emerald,
                        backgroundImage: (pic is String && pic.isNotEmpty) ? NetworkImage(pic) : null,
                        child: (pic is String && pic.isNotEmpty)
                          ? null
                          : Text((u['name'] ?? '?').toString().substring(0, 1),
                              style: GoogleFonts.amiri(
                                color: AppTheme.cream, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(u['name'] ?? '(no name)',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.cream, fontSize: 14, fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis),
                              ),
                              if (isSuper)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.gold,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text('SUPER',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.bg, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                                ),
                            ]),
                            if ((u['email'] ?? '').toString().isNotEmpty)
                              Text(u['email'],
                                style: GoogleFonts.inter(color: AppTheme.textMid, fontSize: 11.5),
                                overflow: TextOverflow.ellipsis),
                            if ((u['phone'] ?? '').toString().isNotEmpty)
                              Text(u['phone'],
                                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('#${u['id']}',
                            style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 10)),
                          if (_amRoot) ...[
                            const SizedBox(height: 6),
                            IconButton(
                              icon: Icon(
                                isSuper ? Icons.remove_circle_outline : Icons.add_moderator,
                                color: isSuper ? Colors.redAccent : AppTheme.gold,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              tooltip: isSuper ? 'Remove super admin' : 'Make super admin',
                              onPressed: () => _toggleSuper(u),
                            ),
                          ],
                        ],
                      ),
                    ]),
                  );
                },
              ),
            ),
          ),
      ]),
    );
  }
}
