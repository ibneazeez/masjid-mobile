import 'package:shared_preferences/shared_preferences.dart';

/// Tracks consecutive days the user has marked Tahajjud as prayed.
/// Local-only — no server. One mark per "Islamic day" (we approximate as
/// calendar day in user's local zone).
class TahajjudStreak {
  static const _kLast   = 'tahajjud_last_ymd';     // 'YYYY-MM-DD'
  static const _kStreak = 'tahajjud_streak';
  static const _kBest   = 'tahajjud_best';

  static String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Snapshot of state — current streak length, best ever, and whether
  /// the user has already marked today.
  static Future<StreakState> read() async {
    final p = await SharedPreferences.getInstance();
    final last = p.getString(_kLast);
    int current = p.getInt(_kStreak) ?? 0;
    final best  = p.getInt(_kBest)   ?? 0;
    final today = _ymd(DateTime.now());

    bool markedToday = last == today;
    // If the streak is older than yesterday, it's broken — surface 0
    // (we'll persist the reset on the next mark).
    if (last != null && !markedToday) {
      final lastDate = DateTime.parse(last);
      final daysSince = DateTime.now().difference(lastDate).inDays;
      if (daysSince > 1) current = 0;
    }
    return StreakState(current: current, best: best, markedToday: markedToday);
  }

  /// Mark today as prayed. Returns the new state.
  /// No-op if today is already marked.
  static Future<StreakState> markToday() async {
    final p = await SharedPreferences.getInstance();
    final last = p.getString(_kLast);
    final today = _ymd(DateTime.now());
    if (last == today) return read();

    int current = p.getInt(_kStreak) ?? 0;
    int best    = p.getInt(_kBest)   ?? 0;
    if (last != null) {
      final yesterday = _ymd(DateTime.now().subtract(const Duration(days: 1)));
      // Continue the streak only if the previous mark was literally yesterday.
      current = (last == yesterday) ? current + 1 : 1;
    } else {
      current = 1;
    }
    if (current > best) best = current;
    await p.setString(_kLast, today);
    await p.setInt(_kStreak, current);
    await p.setInt(_kBest, best);
    return StreakState(current: current, best: best, markedToday: true);
  }
}

class StreakState {
  final int current;
  final int best;
  final bool markedToday;
  StreakState({required this.current, required this.best, required this.markedToday});
}
