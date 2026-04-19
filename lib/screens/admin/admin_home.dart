import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api.dart';
import '../../theme.dart';
import 'admin_masjids.dart';
import 'admin_roles.dart';
import 'admin_suggestions.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  Map<String, dynamic>? _stats;
  String? _err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final s = await Api.adminStats();
      if (mounted) setState(() { _stats = s; _err = null; });
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Admin Panel')),
      body: RefreshIndicator(
        color: AppTheme.gold,
        backgroundColor: AppTheme.surface,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats grid
            if (_stats != null) _statsGrid(_stats!)
            else if (_err != null) Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_err!, style: const TextStyle(color: Colors.redAccent)),
            ))
            else const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppTheme.gold))),

            const SizedBox(height: 22),
            Text('MANAGE',
              style: GoogleFonts.inter(
                color: AppTheme.gold, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _menuTile(
              icon: Icons.mosque, title: 'Masjids',
              subtitle: 'Add, edit, delete masjids and prayer timings',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminMasjidsScreen())),
            ),
            const SizedBox(height: 10),
            _menuTile(
              icon: Icons.group_outlined, title: 'Roles & Users',
              subtitle: 'Assign masjid admins, imams, committee members',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminRolesScreen())),
            ),
            const SizedBox(height: 10),
            _menuTile(
              icon: Icons.edit_calendar_outlined, title: 'Time Suggestions',
              subtitle: _stats != null && (_stats!['pending_suggestions'] ?? 0) > 0
                ? '${_stats!['pending_suggestions']} pending review'
                : 'Approve user-suggested prayer time changes',
              badge: _stats?['pending_suggestions'],
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminSuggestionsScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsGrid(Map<String, dynamic> s) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        _statCard('Masjids', s['masjids'], Icons.mosque),
        _statCard('Users', s['users'], Icons.people),
        _statCard('Super Admins', s['super_admins'], Icons.shield),
        _statCard('Roles', s['role_assignments'], Icons.assignment_ind),
        _statCard('Pending', s['pending_suggestions'], Icons.pending_actions),
        _statCard('Favourites', s['favourites'], Icons.favorite),
      ],
    );
  }

  Widget _statCard(String label, dynamic value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceAlt,
              border: Border.all(color: AppTheme.gold.withOpacity(0.4)),
            ),
            child: Icon(icon, color: AppTheme.goldSoft, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
              children: [
                Text('${value ?? 0}',
                  style: GoogleFonts.inter(
                    color: AppTheme.cream, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(label,
                  style: GoogleFonts.inter(
                    color: AppTheme.textLo, fontSize: 10.5,
                    fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon, required String title,
    required String subtitle, required VoidCallback onTap, dynamic badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.emerald, Color(0xFF053B2A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppTheme.gold.withOpacity(0.55), width: 1.2),
              ),
              child: Icon(icon, color: AppTheme.goldSoft, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.amiri(
                      color: AppTheme.cream, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                    style: GoogleFonts.inter(color: AppTheme.textMid, fontSize: 12)),
                ],
              ),
            ),
            if (badge != null && (badge as int) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('$badge',
                  style: GoogleFonts.inter(
                    color: AppTheme.bg, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppTheme.textLo),
          ]),
        ),
      ),
    );
  }
}
