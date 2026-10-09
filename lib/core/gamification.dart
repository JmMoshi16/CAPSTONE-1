// Pure scoring rules: no Flutter, no Firebase imports, so `dart test` can run them anywhere.

/// 1-2 days → 1.0×  |  3-6 days → 1.5×  |  7+ days → 2.0×
double streakMultiplier(int streak) {
  if (streak >= 7) return 2.0;
  if (streak >= 3) return 1.5;
  return 1.0;
}

/// yyyy-MM-dd in local time — the format stored in `users.lastScanDate`.
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _daysSince(String? lastScanDate, DateTime today) {
  final last = lastScanDate == null ? null : DateTime.tryParse(lastScanDate);
  if (last == null) return -1;
  return DateTime(today.year, today.month, today.day)
      .difference(DateTime(last.year, last.month, last.day))
      .inDays;
}

/// Streak after a scan made on [today].
int nextStreak(int current, String? lastScanDate, DateTime today) {
  final diff = _daysSince(lastScanDate, today);
  if (diff == 0) return current < 1 ? 1 : current;
  if (diff == 1) return current + 1;
  return 1;
}

/// Streak to DISPLAY: the stored value is only rewritten on a scan, so it goes stale
/// once a whole day has been missed (audit M-11).
int effectiveStreak(int stored, String? lastScanDate, DateTime today) {
  final diff = _daysSince(lastScanDate, today);
  return (diff == 0 || diff == 1) ? stored : 0;
}

/// Points actually credited for one scan: base × streak multiplier, rounded.
int creditedPoints(int base, int streak) => (base * streakMultiplier(streak)).round();

/// Scans in the last [days] calendar days including today.
int scansInLastDays(Iterable<DateTime> scanTimes, DateTime now, {int days = 7}) {
  final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
  return scanTimes.where((t) => !t.toLocal().isBefore(start)).length;
}
