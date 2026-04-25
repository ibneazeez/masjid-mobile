import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api.dart';
import '../../theme.dart';
import 'admin_masjids.dart';
import 'admin_roles.dart';
import 'admin_suggestions.dart';
import 'admin_users.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _me;
  String? _err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final me = await Api.me();
      if (!mounted) return;
      setState(() => _me = me);
      // Only super admin can call /api/admin/stats; for masjid admins, skip.
      if (me != null && me['is_super_admin'] == true) {
        final s = await Api.adminStats();
        if (mounted) setState(() { _stats = s; _err = null; });
      }
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  bool get _isSuper => _me != null && _me!['is_super_admin'] == true;

  /// Masjid IDs this user can manage (when not super admin)
  List<int> get _myMasjidIds {
    if (_me == null) return [];
    return ((_me!['roles'] as List?) ?? [])
        .where((r) => r['status'] == 'active' &&
                       {'masjid_admin','imam','moazzan',
                        'committee_president','committee_secretary'}.contains(r['role']))
        .map<int>((r) => r['masjid_id'] as int)
        .toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: Text(_isSuper ? 'Admin Panel' : 'My Masjid')),
      body: RefreshIndicator(
        color: AppTheme.gold,
        backgroundColor: AppTheme.surface,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats / verification alert (super admin only)
            if (_isSuper && _stats != null) _verifyAlert(_stats!),
            if (_isSuper && _stats != null) _statsGrid(_stats!),

            // Header for non-super admins — show what they manage
            if (!_isSuper && _myMasjidIds.isNotEmpty) _scopedHeader(),

            const SizedBox(height: 22),
            Text('MANAGE',
              style: GoogleFonts.inter(
                color: AppTheme.gold, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _menuTile(
              icon: Icons.mosque,
              title: _isSuper ? 'Masjids' : 'My Masjid${_myMasjidIds.length > 1 ? 's' : ''}',
              subtitle: _isSuper
                ? 'Add, edit, delete masjids and prayer timings'
                : 'Edit prayer timings & details',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminMasjidsScreen())),
            ),
            // Users — super admin only
            if (_isSuper) ...[
              const SizedBox(height: 10),
              _menuTile(
                icon: Icons.people_outlined, title: 'Users',
                subtitle: 'View all registered users, search by name/email',
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
              ),
            ],
            // Roles — super admin only
            if (_isSuper) ...[
              const SizedBox(height: 10),
              _menuTile(
                icon: Icons.assignment_ind_outlined, title: 'Roles & Memberships',
                subtitle: 'Assign masjid admins, approve member requests',
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminRolesScreen())),
              ),
            ],
            const SizedBox(height: 10),
            _menuTile(
              icon: Icons.edit_calendar_outlined, title: 'Time Suggestions',
              subtitle: _stats != null && (_stats!['pending_suggestions'] ?? 0) > 0
                ? '${_stats!['pending_suggestions']} pending review'
                : _isSuper
                  ? 'Approve user-suggested prayer time changes'
                  : 'Suggestions for masjids you manage',
              badge: _stats?['pending_suggestions'],
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminSuggestionsScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopedHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E6E44), Color(0xFF053B2A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gold.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.shield_outlined, color: AppTheme.goldSoft, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Masjid Admin',
              style: GoogleFonts.amiri(
                color: AppTheme.cream, fontSize: 17, fontWeight: FontWeight.bold)),
            Text('You manage ${_myMasjidIds.length} masjid${_myMasjidIds.length == 1 ? '' : 's'}',
              style: GoogleFonts.inter(color: AppTheme.cream.withOpacity(0.85), fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _verifyAlert(Map<String, dynamic> s) {
    final never = (s['never_verified'] ?? 0) as int;
    final stale = (s['stale'] ?? 0) as int;
    final alarm = (s['alarm'] ?? 0) as int;
    if (never == 0 && stale == 0 && alarm == 0) return const SizedBox.shrink();

    final isAlarm = alarm > 0 || never > 0;
    final color = isAlarm ? const Color(0xFFDC2626) : AppTheme.gold;
    final bg = isAlarm ? const Color(0x33DC2626) : const Color(0x33D4AF37);

    final parts = <String>[];
    if (never > 0) parts.add('$never never verified');
    if (alarm > 0) parts.add('$alarm not verified in 2+ weeks');
    if (stale > 0) parts.add('$stale due for check');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AdminMasjidsScreen())),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.6)),
          ),
          child: Row(children: [
            Icon(isAlarm ? Icons.error_outline : Icons.warning_amber_rounded,
              color: color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Masjids need verification',
                    style: GoogleFonts.inter(
                      color: color, fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Text(parts.join(' · '),
                    style: GoogleFonts.inter(
                      color: color.withOpacity(0.9), fontSize: 11.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ]),
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
