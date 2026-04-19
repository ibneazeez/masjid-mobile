import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class Timing {
  final String prayer;
  final String adhanTime;
  final String jamaatTime;
  Timing({required this.prayer, required this.adhanTime, required this.jamaatTime});
  factory Timing.fromJson(Map<String, dynamic> j) => Timing(
    prayer: j['prayer'],
    adhanTime: j['adhan_time'],
    jamaatTime: j['jamaat_time'],
  );
  Map<String, dynamic> toJson() =>
    {'prayer': prayer, 'adhan_time': adhanTime, 'jamaat_time': jamaatTime};
}

class Masjid {
  final int id;
  final String name;
  final String area;
  final String? address;
  final String? phone;
  final double? lat;
  final double? lng;
  final double? distanceKm;
  final bool isFavourite;
  final int? verifiedDaysAgo;          // null if never verified
  final String verificationStatus;     // 'fresh' | 'stale' | 'alarm' | 'never'
  final String? verifiedAt;            // ISO-ish string from backend
  final List<Timing> timings;
  Masjid({
    required this.id, required this.name, required this.area,
    this.address, this.phone, this.lat, this.lng, this.distanceKm,
    this.isFavourite = false,
    this.verifiedDaysAgo, this.verificationStatus = 'never', this.verifiedAt,
    this.timings = const [],
  });
  factory Masjid.fromJson(Map<String, dynamic> j) => Masjid(
    id: j['id'],
    name: j['name'],
    area: j['area'] ?? '',
    address: j['address'],
    phone: j['phone'],
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    distanceKm: (j['distance_km'] as num?)?.toDouble(),
    isFavourite: j['is_favourite'] == true,
    verifiedDaysAgo: (j['verified_days_ago'] as num?)?.toInt(),
    verificationStatus: (j['verification_status'] ?? 'never').toString(),
    verifiedAt: j['verified_at']?.toString(),
    timings: ((j['timings'] as List?) ?? []).map((e) => Timing.fromJson(e)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'area': area, 'address': address, 'phone': phone,
    'lat': lat, 'lng': lng, 'distance_km': distanceKm,
    'is_favourite': isFavourite,
    'verified_days_ago': verifiedDaysAgo,
    'verification_status': verificationStatus,
    'verified_at': verifiedAt,
    'timings': timings.map((t) => t.toJson()).toList(),
  };

  Masjid copyWith({bool? isFavourite, int? verifiedDaysAgo,
                    String? verificationStatus, String? verifiedAt}) => Masjid(
    id: id, name: name, area: area, address: address, phone: phone,
    lat: lat, lng: lng, distanceKm: distanceKm,
    isFavourite: isFavourite ?? this.isFavourite,
    verifiedDaysAgo: verifiedDaysAgo ?? this.verifiedDaysAgo,
    verificationStatus: verificationStatus ?? this.verificationStatus,
    verifiedAt: verifiedAt ?? this.verifiedAt,
    timings: timings,
  );

  /// Returns the next upcoming prayer based on `now` (jamaat_time > now).
  /// Falls back to fajr if Isha is over.
  /// On Friday, Jumu'ah REPLACES Dhuhr in the daily flow.
  Timing? nextPrayer(DateTime now) {
    if (timings.isEmpty) return null;
    final isFri = now.weekday == DateTime.friday;
    final ordered = timings.where((t) {
      if (isFri) return t.prayer != 'dhuhr';   // Jumu'ah replaces Dhuhr on Friday
      return t.prayer != 'jumuah';              // Hide Jumu'ah on other days
    }).toList();
    int toMin(String hms) {
      final p = hms.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }
    final nowMin = now.hour * 60 + now.minute;
    for (final t in ordered) {
      if (toMin(t.jamaatTime) > nowMin) return t;
    }
    return ordered.firstWhere(
      (t) => t.prayer == 'fajr',
      orElse: () => ordered.first,
    );
  }

  Timing? get jumuah {
    for (final t in timings) {
      if (t.prayer == 'jumuah') return t;
    }
    return null;
  }
}

class MasjidPage {
  final List<Masjid> items;
  final int page;
  final int size;
  final int total;
  final bool hasMore;
  MasjidPage({required this.items, required this.page, required this.size,
              required this.total, required this.hasMore});
  factory MasjidPage.fromJson(Map<String, dynamic> j) => MasjidPage(
    items: ((j['items'] as List?) ?? []).map((e) => Masjid.fromJson(e)).toList(),
    page: j['page'] ?? 0,
    size: j['size'] ?? 20,
    total: j['total'] ?? 0,
    hasMore: j['has_more'] == true,
  );
}

class Api {
  static String get base => AppConfig.apiBaseUrl;

  static Future<String?> _token() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('token');
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final t = await _token();
      if (t != null) h['Authorization'] = 'Bearer $t';
    } else {
      // also send token if present (so server can mark is_favourite)
      final t = await _token();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  // ----- PUBLIC -----
  static Future<MasjidPage> listMasjids({
    double? lat, double? lng, String? q, bool withTimings = false,
    int page = 0, int size = 20,
  }) async {
    final params = <String, String>{};
    if (lat != null) params['lat'] = lat.toString();
    if (lng != null) params['lng'] = lng.toString();
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (withTimings) params['with_timings'] = '1';
    params['page'] = '$page';
    params['size'] = '$size';
    final uri = Uri.parse('$base/api/masjids').replace(queryParameters: params);
    final r = await http.get(uri, headers: await _headers());
    if (r.statusCode != 200) throw Exception('Failed: ${r.body}');
    return MasjidPage.fromJson(jsonDecode(r.body));
  }

  static Future<Masjid> getMasjid(int id) async {
    final r = await http.get(Uri.parse('$base/api/masjids/$id'));
    if (r.statusCode != 200) throw Exception('Failed: ${r.body}');
    return Masjid.fromJson(jsonDecode(r.body));
  }

  static Future<List<Timing>> getTimings(int masjidId) async {
    final r = await http.get(Uri.parse('$base/api/masjids/$masjidId/timings'));
    if (r.statusCode != 200) throw Exception('Failed: ${r.body}');
    final j = jsonDecode(r.body);
    return (j['items'] as List).map((e) => Timing.fromJson(e)).toList();
  }

  // ----- AUTH -----
  static Future<Map<String, dynamic>> register({
    required String name, required String phone, String? email, required String password,
  }) async {
    final r = await http.post(
      Uri.parse('$base/api/auth/register'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'phone': phone, 'email': email, 'password': password}),
    );
    final j = jsonDecode(r.body);
    if (r.statusCode != 200) throw Exception(j['error'] ?? 'register failed');
    final p = await SharedPreferences.getInstance();
    await p.setString('token', j['token']);
    return j;
  }

  static Future<Map<String, dynamic>> login(String phoneOrEmail, String password) async {
    final r = await http.post(
      Uri.parse('$base/api/auth/login'),
      headers: await _headers(),
      body: jsonEncode({'phoneOrEmail': phoneOrEmail, 'password': password}),
    );
    final j = jsonDecode(r.body);
    if (r.statusCode != 200) throw Exception(j['error'] ?? 'login failed');
    final p = await SharedPreferences.getInstance();
    await p.setString('token', j['token']);
    return j;
  }

  static Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final r = await http.post(
      Uri.parse('$base/api/auth/google'),
      headers: await _headers(),
      body: jsonEncode({'id_token': idToken}),
    );
    final j = jsonDecode(r.body);
    if (r.statusCode != 200) throw Exception(j['error'] ?? 'google login failed');
    final p = await SharedPreferences.getInstance();
    await p.setString('token', j['token']);
    return j;
  }

  static Future<void> logout() async {
    // Clear backend JWT
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    // Clear cached Google account so the next sign-in shows the picker.
    // disconnect() also revokes the consent so a fresh consent screen appears.
    try {
      final g = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: AppConfig.googleServerClientId,
      );
      try { await g.disconnect(); } catch (_) {/* might fail if not signed in */}
      try { await g.signOut();    } catch (_) {/* same */}
    } catch (_) {/* google_sign_in not initialised — fine */}
  }

  static Future<bool> isLoggedIn() async => (await _token()) != null;

  static Future<Map<String, dynamic>?> me() async {
    final t = await _token();
    if (t == null) return null;
    final r = await http.get(
      Uri.parse('$base/api/auth/me'),
      headers: await _headers(auth: true),
    );
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body);
  }

  // ----- FAVOURITES -----
  static Future<void> addFavourite(int masjidId) async {
    final r = await http.post(Uri.parse('$base/api/me/favourites/$masjidId'),
                              headers: await _headers(auth: true));
    if (r.statusCode != 200) throw Exception('add favourite failed');
  }

  static Future<void> removeFavourite(int masjidId) async {
    final r = await http.delete(Uri.parse('$base/api/me/favourites/$masjidId'),
                                headers: await _headers(auth: true));
    if (r.statusCode != 200) throw Exception('remove favourite failed');
  }

  // ----- VERIFY TIMINGS -----
  static Future<void> verifyMasjid(int masjidId) async {
    final r = await http.post(
      Uri.parse('$base/api/masjids/$masjidId/verify'),
      headers: await _headers(auth: true),
    );
    if (r.statusCode != 200) {
      String msg = 'verify failed';
      try { msg = jsonDecode(r.body)['error'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // ----- MEMBERSHIP -----
  static Future<void> registerAsMember(int masjidId) async {
    final r = await http.post(
      Uri.parse('$base/api/masjids/$masjidId/members'),
      headers: await _headers(auth: true),
    );
    if (r.statusCode != 200) {
      String msg = 'register failed';
      try { msg = jsonDecode(r.body)['error'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // ----- TIME SUGGESTIONS -----
  static Future<void> suggestTiming(int masjidId, String prayer,
      String adhanTime, String jamaatTime, String? reason) async {
    final r = await http.post(
      Uri.parse('$base/api/masjids/$masjidId/suggestions'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'prayer': prayer, 'adhan_time': adhanTime,
        'jamaat_time': jamaatTime, 'reason': reason,
      }),
    );
    final j = jsonDecode(r.body);
    if (r.statusCode != 200) throw Exception(j['error'] ?? 'suggest failed');
  }

  // ----- ADMIN: dashboard stats -----
  static Future<Map<String, dynamic>> adminStats() async {
    final r = await http.get(Uri.parse('$base/api/admin/stats'),
                              headers: await _headers(auth: true));
    if (r.statusCode != 200) throw Exception('stats failed: ${r.body}');
    return jsonDecode(r.body);
  }

  // ----- ADMIN: users -----
  static Future<List<Map<String, dynamic>>> adminUsers({String? q}) async {
    final params = <String, String>{};
    if (q != null && q.isNotEmpty) params['q'] = q;
    final uri = Uri.parse('$base/api/admin/users').replace(queryParameters: params);
    final r = await http.get(uri, headers: await _headers(auth: true));
    if (r.statusCode != 200) throw Exception('users failed: ${r.body}');
    return List<Map<String, dynamic>>.from(jsonDecode(r.body)['items']);
  }

  // ----- ADMIN: root super admin — promote/demote -----
  static Future<void> adminSetSuperAdmin(int userId, bool makeSuper) async {
    final r = await http.post(
      Uri.parse('$base/api/admin/users/$userId/super-admin'),
      headers: await _headers(auth: true),
      body: jsonEncode({'is_super_admin': makeSuper}),
    );
    if (r.statusCode != 200) {
      String msg = 'toggle failed';
      try { msg = jsonDecode(r.body)['error'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // ----- ADMIN: role assignments -----
  static Future<List<Map<String, dynamic>>> adminListAssignments() async {
    final r = await http.get(Uri.parse('$base/api/admin/role-assignments'),
                              headers: await _headers(auth: true));
    if (r.statusCode != 200) throw Exception('list failed: ${r.body}');
    return List<Map<String, dynamic>>.from(jsonDecode(r.body)['items']);
  }

  static Future<void> adminCreateAssignment({
    required String userPhoneOrEmail,
    required int masjidId,
    required String role,
    String status = 'active',
  }) async {
    final r = await http.post(
      Uri.parse('$base/api/admin/role-assignments'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'user_phone_or_email': userPhoneOrEmail,
        'masjid_id': masjidId,
        'role': role,
        'status': status,
      }),
    );
    final j = jsonDecode(r.body);
    if (r.statusCode != 200) throw Exception(j['error'] ?? 'create failed');
  }

  static Future<void> adminDeleteAssignment(int id) async {
    final r = await http.delete(Uri.parse('$base/api/admin/role-assignments/$id'),
                                headers: await _headers(auth: true));
    if (r.statusCode != 200) throw Exception('delete failed: ${r.body}');
  }

  // ----- ADMIN: pending suggestions -----
  static Future<List<Map<String, dynamic>>> adminPendingSuggestions() async {
    final r = await http.get(Uri.parse('$base/api/admin/suggestions/pending'),
                              headers: await _headers(auth: true));
    if (r.statusCode != 200) throw Exception('list failed: ${r.body}');
    return List<Map<String, dynamic>>.from(jsonDecode(r.body)['items']);
  }

  static Future<void> adminApproveSuggestion(int id) async {
    final r = await http.post(Uri.parse('$base/api/admin/suggestions/$id/approve'),
                                headers: await _headers(auth: true));
    if (r.statusCode != 200) throw Exception('approve failed: ${r.body}');
  }

  static Future<void> adminRejectSuggestion(int id) async {
    final r = await http.post(Uri.parse('$base/api/admin/suggestions/$id/reject'),
                                headers: await _headers(auth: true));
    if (r.statusCode != 200) throw Exception('reject failed: ${r.body}');
  }

  // ----- ADMIN: masjid CRUD -----
  static Future<int> adminCreateMasjid(Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('$base/api/masjids'),
        headers: await _headers(auth: true), body: jsonEncode(body));
    final j = jsonDecode(r.body);
    if (r.statusCode != 200) throw Exception(j['error'] ?? 'create failed');
    return j['id'];
  }

  static Future<void> adminUpdateMasjid(int id, Map<String, dynamic> body) async {
    final r = await http.patch(Uri.parse('$base/api/masjids/$id'),
        headers: await _headers(auth: true), body: jsonEncode(body));
    if (r.statusCode != 200) throw Exception('update failed: ${r.body}');
  }

  static Future<void> adminUpdateTimings(int masjidId, List<Timing> timings) async {
    String pad(String t) => t.length == 5 ? '$t:00' : t;
    final r = await http.patch(
      Uri.parse('$base/api/masjids/$masjidId/timings'),
      headers: await _headers(auth: true),
      body: jsonEncode({'items': timings.map((t) => {
        'prayer': t.prayer,
        'adhan_time': pad(t.adhanTime),
        'jamaat_time': pad(t.jamaatTime),
      }).toList()}),
    );
    if (r.statusCode != 200) throw Exception('update timings failed: ${r.body}');
  }
}

// ----- LOCAL CACHE -----
class MasjidCache {
  static const _kKey = 'masjid_cache_v1';
  static const _kTime = 'masjid_cache_time_v1';
  static const Duration _ttl = Duration(hours: 6);

  static Future<List<Masjid>?> read() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    final ts = p.getInt(_kTime);
    if (raw == null || ts == null) return null;
    if (DateTime.now().millisecondsSinceEpoch - ts > _ttl.inMilliseconds) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Masjid.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return null; }
  }

  static Future<void> write(List<Masjid> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kKey, jsonEncode(items.map((m) => m.toJson()).toList()));
    await p.setInt(_kTime, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
    await p.remove(_kTime);
  }
}
