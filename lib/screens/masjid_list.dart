import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets/hero_prayer_card.dart';
import 'announcements.dart';
import 'masjid_detail.dart';
import 'profile.dart';

class MasjidListScreen extends StatefulWidget {
  const MasjidListScreen({super.key});
  @override
  State<MasjidListScreen> createState() => _MasjidListScreenState();
}

class _MasjidListScreenState extends State<MasjidListScreen> {
  final List<Masjid> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _query = '';
  int _page = 0;
  static const int _pageSize = 20;
  bool _hasMore = true;
  Timer? _ticker;
  Timer? _searchDebounce;
  DateTime _now = DateTime.now();
  DateTime? _lastBackPress;
  bool _locationOn = false;
  double? _lat, _lng;
  bool _fromCache = false;

  // For proximity alert — populated from /api/auth/me
  Set<int> _myMasjidIds = {};    // masjids where I'm a masjid_admin / imam / moazzan
  bool _amSuperAdmin = false;
  final Set<int> _dismissedProximityIds = {};

  // Active announcements (refreshed on every load)
  List<Announcement> _announcements = [];
  final Set<int> _dismissedAnnouncementIds = {};

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _loadMe();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
  }

  Future<void> _loadMe() async {
    final me = await Api.me();
    if (!mounted || me == null) return;
    final ids = <int>{};
    for (final r in (me['roles'] as List? ?? [])) {
      if (r['status'] == 'active' &&
          {'masjid_admin', 'imam', 'moazzan'}.contains(r['role'])) {
        ids.add(r['masjid_id']);
      }
    }
    setState(() {
      _myMasjidIds = ids;
      _amSuperAdmin = me['is_super_admin'] == true;
    });
  }

  /// Returns the "nearest admin masjid that still needs verification" — if any.
  /// Used to show the big proximity banner at the top of the list.
  Masjid? _proximityAlert() {
    if (!_locationOn) return null;
    // Super admin cares about every masjid. Role-holders only about theirs.
    final candidates = _items.where((m) {
      if (m.verificationStatus == 'fresh') return false;
      if (m.distanceKm == null || m.distanceKm! * 1000 > 200) return false;
      if (_dismissedProximityIds.contains(m.id)) return false;
      return _amSuperAdmin || _myMasjidIds.contains(m.id);
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
    return candidates.first;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      // Only apply filter for 3+ chars; shorter input is treated as no filter.
      // This ensures the list always updates consistently as the user types or
      // deletes, instead of getting stuck with a stale query.
      final newQuery = v.length >= 3 ? v : '';
      if (newQuery != _query) {
        _query = newQuery;
        _loadFirstPage();
      }
    });
  }

  Future<void> _handleBackPress() async {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    SystemNavigator.pop();
  }

  Future<void> _bootstrap() async {
    final cached = await MasjidCache.read();
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _items.addAll(cached);
        _loading = false;
        _fromCache = true;
      });
    }
    await _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    if (!_fromCache) setState(() { _loading = true; _error = null; });
    try {
      await _resolveLocation();
      final pageData = await Api.listMasjids(
        lat: _lat, lng: _lng, q: _query, withTimings: true,
        page: 0, size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items.clear();
        _items.addAll(pageData.items);
        _page = 0;
        _hasMore = pageData.hasMore;
        _loading = false;
        _error = null;
        _fromCache = false;
      });
      MasjidCache.write(pageData.items);
      // Fetch announcements separately (failure doesn't break the list)
      Api.announcementsActive().then((list) {
        if (mounted) setState(() => _announcements = list);
      }).catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_items.isEmpty) _error = '$e';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final pageData = await Api.listMasjids(
        lat: _lat, lng: _lng, q: _query, withTimings: true,
        page: _page + 1, size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(pageData.items);
        _page = pageData.page;
        _hasMore = pageData.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _resolveLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ).timeout(const Duration(seconds: 8));
        _lat = p.latitude; _lng = p.longitude;
        _locationOn = true;
      }
    } catch (_) { _locationOn = false; }
  }

  Future<void> _toggleFavourite(Masjid m) async {
    if (!await Api.isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save favourites')));
      return;
    }
    final newState = !m.isFavourite;
    setState(() {
      final i = _items.indexWhere((x) => x.id == m.id);
      if (i >= 0) _items[i] = _items[i].copyWith(isFavourite: newState);
    });
    try {
      if (newState) {
        await Api.addFavourite(m.id);
      } else {
        await Api.removeFavourite(m.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((x) => x.id == m.id);
        if (i >= 0) _items[i] = _items[i].copyWith(isFavourite: !newState);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  static const _names = {
    'fajr': 'Fajr', 'dhuhr': 'Dhuhr', 'asr': 'Asr',
    'maghrib': 'Maghrib', 'isha': 'Isha', 'jumuah': "Jumu'ah",
  };

  String _shortTime(String t) => t.length >= 5 ? t.substring(0, 5) : t;

  String _nextPrayerLabel(Masjid m) {
    final next = m.nextPrayer(_now);
    if (next == null) return 'Timings not set';
    return '${_names[next.prayer] ?? next.prayer} · ${_shortTime(next.jamaatTime)}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) { if (!didPop) _handleBackPress(); },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/logo/logo_1024.png', width: 30, height: 30),
            ),
            const SizedBox(width: 10),
            const Text('Masjid Timings'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.gold),
            tooltip: 'Refresh',
            onPressed: _loadFirstPage,
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: AppTheme.gold),
            tooltip: 'Profile',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              _loadFirstPage();
            },
          ),
        ],
      ),
      body: _loading && _items.isEmpty
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
        : _error != null && _items.isEmpty
          ? _errorView()
          : RefreshIndicator(
              color: AppTheme.gold,
              backgroundColor: AppTheme.surface,
              onRefresh: _loadFirstPage,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _heroOffset() + _items.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i < _heroOffset()) return _buildHeader(i);
                  final dataIdx = i - _heroOffset();
                  if (dataIdx >= _items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: _loadingMore
                          ? const CircularProgressIndicator(color: AppTheme.gold)
                          : Text('Loading more...', style: GoogleFonts.inter(color: AppTheme.textLo)),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _masjidCard(_items[dataIdx]),
                  );
                },
              ),
            ),
    );
  }

  Widget _errorView() {
    final isNetwork = _error != null &&
        (_error!.contains('SocketException') ||
         _error!.contains('Connection') ||
         _error!.contains('TimeoutException') ||
         _error!.contains('Failed host lookup') ||
         _error!.contains('Network is unreachable'));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetwork ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
              size: 64,
              color: AppTheme.textLo,
            ),
            const SizedBox(height: 16),
            Text(
              isNetwork ? 'No internet connection' : 'Something went wrong',
              style: GoogleFonts.amiri(
                color: AppTheme.cream, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isNetwork
                ? 'Check your Wi-Fi or mobile data and try again'
                : 'The server might be down temporarily. Please try again in a moment.',
              style: GoogleFonts.inter(color: AppTheme.textMid, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: AppTheme.cream,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loadFirstPage,
            ),
          ],
        ),
      ),
    );
  }

  /// True when GPS is on AND closest masjid is > 50 km away.
  /// Interpreted as: user is outside the Nellore coverage area.
  bool get _isOutOfCoverage {
    if (!_locationOn || _items.isEmpty) return false;
    final d = _items.first.distanceKm;
    return d != null && d > 50.0;
  }

  /// Active announcements not yet dismissed by user
  List<Announcement> get _visibleAnnouncements =>
      _announcements.where((a) => !_dismissedAnnouncementIds.contains(a.id)).toList();

  int _heroOffset() {
    if (_items.isEmpty) return 0;
    int base = 3;  // hero + search + section header
    if (_isOutOfCoverage) base++;
    if (_proximityAlert() != null) base++;
    if (_visibleAnnouncements.isNotEmpty) base++;
    return base;
  }

  Widget _buildHeader(int i) {
    if (_visibleAnnouncements.isNotEmpty) {
      if (i == 0) return _announcementsBanner();
      i = i - 1;
    }
    final nearby = _proximityAlert();
    if (nearby != null) {
      if (i == 0) return _proximityBanner(nearby);
      i = i - 1;
    }
    if (_isOutOfCoverage) {
      if (i == 0) return _coverageBanner();
      i = i - 1;
    }
    if (i == 0) {
      return Column(children: [
        HeroPrayerCard(masjid: _items.first, now: _now),
        const SizedBox(height: 18),
      ]);
    }
    if (i == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by name or area (3+ chars)…',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          ),
          onChanged: _onSearchChanged,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text('NEARBY MASJIDS',
          style: GoogleFonts.inter(
            color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppTheme.line)),
        const SizedBox(width: 10),
        if (_fromCache) ...[
          const Icon(Icons.history, size: 11, color: AppTheme.textLo),
          const SizedBox(width: 3),
          Text('cached', style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 10)),
          const SizedBox(width: 8),
        ],
        Icon(_locationOn ? Icons.my_location : Icons.location_disabled,
          size: 12, color: _locationOn ? AppTheme.emeraldSoft : AppTheme.textLo),
        const SizedBox(width: 4),
        Text(_locationOn ? 'GPS' : 'no GPS',
          style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 10)),
      ]),
    );
  }

  Widget _announcementsBanner() {
    final list = _visibleAnnouncements;
    final urgent = list.firstWhere((a) => a.priority == 'urgent', orElse: () => list.first);
    final color = urgent.kind == 'janaza'
      ? const Color(0xFFDC2626)
      : urgent.kind == 'eid'
        ? const Color(0xFFD4AF37)
        : AppTheme.emerald;
    final extras = list.length - 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AnnouncementsScreen())),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(
                  urgent.kind == 'janaza' ? Icons.priority_high
                  : urgent.kind == 'eid' ? Icons.celebration
                  : Icons.campaign,
                  color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(urgent.title,
                        style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                      const SizedBox(height: 2),
                      Text(extras > 0
                          ? '${urgent.body.split('\n').first} · +$extras more'
                          : urgent.body.split('\n').first,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.92), fontSize: 11.5),
                        overflow: TextOverflow.ellipsis, maxLines: 2),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: () => setState(() {
                    for (final a in list) {
                      _dismissedAnnouncementIds.add(a.id);
                    }
                  }),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _proximityBanner(Masjid m) {
    final meters = (m.distanceKm! * 1000).round();
    final statusColor = _statusColor(m.verificationStatus);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [statusColor, statusColor.withOpacity(0.7)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: statusColor.withOpacity(0.4),
                      blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => MasjidDetailScreen(masjid: m))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.location_on, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("You're near ${m.name}",
                        style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('About ${meters}m away · '
                           '${m.verificationStatus == "never" ? "not yet verified" : "last verified ${m.verifiedDaysAgo} days ago"}'
                           ' — tap to update timings',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.93), fontSize: 11.5)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  tooltip: 'Dismiss',
                  onPressed: () => setState(() => _dismissedProximityIds.add(m.id)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _coverageBanner() {
    final km = _items.first.distanceKm!.toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0x33D4AF37),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.gold.withOpacity(0.55)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline, color: AppTheme.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Outside coverage area',
                  style: GoogleFonts.inter(
                    color: AppTheme.gold, fontSize: 13,
                    fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(
                  'This app currently covers only Nellore masjids. '
                  'Your location is about $km km away from the nearest listed masjid.',
                  style: GoogleFonts.inter(
                    color: AppTheme.gold.withOpacity(0.90), fontSize: 11.5)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _masjidCard(Masjid m) {
    final statusColor = _statusColor(m.verificationStatus);
    final statusLabel = _statusLabel(m);
    final statusIcon  = _statusIcon(m.verificationStatus);
    final isNotFresh  = m.verificationStatus != 'fresh';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => MasjidDetailScreen(masjid: m))),
        child: Container(
          padding: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNotFresh ? statusColor.withOpacity(0.6) : AppTheme.line,
              width: isNotFresh ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main row
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.emerald, Color(0xFF053B2A)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: AppTheme.gold.withOpacity(0.55), width: 1.2),
                    ),
                    child: const Icon(Icons.mosque, color: AppTheme.goldSoft, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name,
                          style: GoogleFonts.amiri(
                            color: AppTheme.cream, fontWeight: FontWeight.bold,
                            fontSize: 17, height: 1.1)),
                        const SizedBox(height: 4),
                        // PROMINENT status chip right under the name
                        _bigStatusChip(statusColor, statusIcon, statusLabel),
                        const SizedBox(height: 6),
                        Text(m.area,
                          style: GoogleFonts.inter(color: AppTheme.textMid, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.access_time, size: 11, color: AppTheme.gold),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text('Next: ${_nextPrayerLabel(m)}',
                              style: GoogleFonts.inter(
                                color: AppTheme.goldSoft, fontSize: 11.5, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () => _toggleFavourite(m),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            m.isFavourite ? Icons.favorite : Icons.favorite_border,
                            color: m.isFavourite ? AppTheme.gold : AppTheme.textLo,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (m.distanceKm != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: AppTheme.gold.withOpacity(0.35)),
                          ),
                          child: Text(
                            '${m.distanceKm!.toStringAsFixed(1)} km',
                            style: GoogleFonts.inter(
                              color: AppTheme.goldSoft, fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ]),
              ),
              // Footer stripe — ONLY for non-fresh, fully-coloured so admins can't miss it
              if (isNotFresh) _bottomStatusStripe(statusColor, statusIcon, m),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- status helpers ----------
  Color _statusColor(String s) {
    switch (s) {
      case 'fresh': return const Color(0xFF22A06B);
      case 'stale': return const Color(0xFFF59E0B);
      case 'alarm': return const Color(0xFFDC2626);
      default:      return AppTheme.textLo;        // never
    }
  }
  IconData _statusIcon(String s) {
    switch (s) {
      case 'fresh': return Icons.verified;
      case 'stale': return Icons.warning_amber_rounded;
      case 'alarm': return Icons.error_outline;
      default:      return Icons.help_outline;
    }
  }
  String _statusLabel(Masjid m) {
    switch (m.verificationStatus) {
      case 'fresh':
        return 'VERIFIED · ${m.verifiedDaysAgo}d ago';
      case 'stale':
        return 'UPDATE DUE · ${m.verifiedDaysAgo}d old';
      case 'alarm':
        return 'OUTDATED · ${m.verifiedDaysAgo}d old';
      default:
        return 'NOT VERIFIED';
    }
  }

  Widget _bigStatusChip(Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.20),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.75), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
            style: GoogleFonts.inter(
              color: color, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _bottomStatusStripe(Color color, IconData icon, Masjid m) {
    final label = m.verificationStatus == 'never'
      ? 'Admin hasn\'t verified these times yet'
      : m.verificationStatus == 'alarm'
        ? 'Times not verified in ${m.verifiedDaysAgo}+ days — likely outdated'
        : 'Admin check due — last verified ${m.verifiedDaysAgo} days ago';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: color.withOpacity(0.22),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
            style: GoogleFonts.inter(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

