import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api.dart';
import '../theme.dart';
import 'admin/admin_home.dart';
import 'login.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final m = await Api.me();
    if (mounted) setState(() { _me = m; _loading = false; });
  }

  bool get _isSuper => _me != null && (_me!['is_super_admin'] == true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('My Profile')),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
        : _me == null
          ? _notSignedIn()
          : _signedIn(),
    );
  }

  Widget _notSignedIn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_off, size: 56, color: AppTheme.textLo),
          const SizedBox(height: 12),
          Text('Not signed in',
            style: GoogleFonts.amiri(color: AppTheme.cream, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("You're browsing as a guest. Sign in to favourite masjids and become a member.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppTheme.textLo)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
            ),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              _load();
            },
            child: const Text('Sign in'),
          ),
        ]),
      ),
    );
  }

  Widget _signedIn() {
    final pic = _me!['picture_url'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: Column(children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: AppTheme.emerald,
            backgroundImage: (pic is String && pic.isNotEmpty) ? NetworkImage(pic) : null,
            child: (pic is String && pic.isNotEmpty)
              ? null
              : Text((_me!['name'] ?? '?').toString().substring(0, 1),
                  style: GoogleFonts.amiri(
                    color: AppTheme.cream, fontSize: 30, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          Text(_me!['name'] ?? '',
            style: GoogleFonts.amiri(
              color: AppTheme.cream, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          if (_me!['email'] != null)
            Text(_me!['email'],
              style: GoogleFonts.inter(color: AppTheme.textMid, fontSize: 12)),
          if (_isSuper) Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.gold, AppTheme.goldSoft]),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('SUPER ADMIN',
              style: GoogleFonts.inter(
                color: AppTheme.bg, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ),
        ])),
        const SizedBox(height: 22),

        // Admin Panel link (super admins only)
        if (_isSuper) ...[
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminHomeScreen())),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E6E44), Color(0xFF053B2A)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.gold.withOpacity(0.55)),
                ),
                child: Row(children: [
                  const Icon(Icons.shield, color: AppTheme.goldSoft, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Admin Panel',
                        style: GoogleFonts.amiri(
                          color: AppTheme.cream, fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Manage masjids, roles, suggestions',
                        style: GoogleFonts.inter(
                          color: AppTheme.cream.withOpacity(0.75), fontSize: 11.5)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.goldSoft),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],

        Text('MEMBERSHIPS',
          style: GoogleFonts.inter(
            color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        if (((_me!['roles'] as List?) ?? []).isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.line),
            ),
            child: Text('No memberships yet. Open any masjid and tap "Become a Member".',
              style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 12)),
          )
        else
          ...((_me!['roles'] as List?) ?? []).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.line),
              ),
              child: Row(children: [
                const Icon(Icons.mosque, color: AppTheme.goldSoft, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r['masjid_name'] ?? '',
                      style: GoogleFonts.inter(
                        color: AppTheme.cream, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('${r['role']} · ${r['status']}',
                      style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11)),
                  ]),
                ),
              ]),
            ),
          )),
        const SizedBox(height: 18),

        // Sign out
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.line),
          ),
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text('Sign out',
              style: GoogleFonts.inter(color: AppTheme.cream, fontWeight: FontWeight.w600)),
            onTap: () async {
              await Api.logout();
              _load();
            },
          ),
        ),
      ],
    );
  }
}
