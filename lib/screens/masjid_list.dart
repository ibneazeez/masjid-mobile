import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets/hero_prayer_card.dart';
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

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
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

  int _heroOffset() {
    if (_items.isEmpty) return 0;
    // Hero + search + section header (+ coverage banner on top if relevant)
    return _isOutOfCoverage ? 4 : 3;
  }

  Widget _buildHeader(int i) {
    if (_isOutOfCoverage) {
      if (i == 0) return _coverageBanner();
      i = i - 1; // shift the rest
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => MasjidDetailScreen(masjid: m))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: m.verificationStatus == 'alarm'
                ? const Color(0x77DC2626)
                : m.verificationStatus == 'stale'
                  ? const Color(0x77D4AF37)
                  : AppTheme.line,
            ),
          ),
          child: Row(children: [
            Stack(alignment: Alignment.bottomRight, children: [
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
              if (m.verificationStatus == 'fresh')
                const _StatusDot(color: Color(0xFF22A06B), icon: Icons.check)
              else if (m.verificationStatus == 'stale')
                const _StatusDot(color: Color(0xFFD4AF37), icon: Icons.warning_amber_rounded)
              else if (m.verificationStatus == 'alarm')
                const _StatusDot(color: Color(0xFFDC2626), icon: Icons.priority_high),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                    style: GoogleFonts.amiri(
                      color: AppTheme.cream, fontWeight: FontWeight.bold,
                      fontSize: 17, height: 1.1)),
                  const SizedBox(height: 2),
                  Text(m.area, style: GoogleFonts.inter(color: AppTheme.textMid, fontSize: 12)),
                  const SizedBox(height: 6),
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
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _StatusDot({required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18, height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: AppTheme.surface, width: 2),
      ),
      child: Icon(icon, size: 10, color: Colors.white),
    );
  }
}
