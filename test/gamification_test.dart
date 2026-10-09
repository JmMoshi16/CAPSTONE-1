// Pure Dart: run with `dart test test/gamification_test.dart` (also runs under `flutter test`).
import 'package:test/test.dart';
import 'package:ecoreward_bin/core/gamification.dart';

void main() {
  final today = DateTime(2026, 10, 9, 15, 30);

  group('streak', () {
    test('first ever scan starts at 1', () => expect(nextStreak(0, null, today), 1));
    test('second scan on the same day keeps the streak', () => expect(nextStreak(4, '2026-10-09', today), 4));
    test('scan the next day extends it', () => expect(nextStreak(4, '2026-10-08', today), 5));
    test('a missed day resets it', () => expect(nextStreak(4, '2026-10-07', today), 1));
    test('works across a month boundary', () => expect(nextStreak(2, '2026-09-30', DateTime(2026, 10, 1)), 3));
    test('unreadable date resets it', () => expect(nextStreak(9, 'garbage', today), 1));

    test('displayed streak goes stale after a missed day (audit M-11)', () {
      expect(effectiveStreak(6, '2026-10-09', today), 6);
      expect(effectiveStreak(6, '2026-10-08', today), 6); // can still be extended today
      expect(effectiveStreak(6, '2026-10-06', today), 0);
      expect(effectiveStreak(6, null, today), 0);
    });

    test('dayKey matches the stored yyyy-MM-dd format', () => expect(dayKey(DateTime(2026, 3, 7)), '2026-03-07'));
  });

  group('multiplier and credited points', () {
    test('multiplier tiers', () {
      expect(streakMultiplier(1), 1.0);
      expect(streakMultiplier(2), 1.0);
      expect(streakMultiplier(3), 1.5);
      expect(streakMultiplier(6), 1.5);
      expect(streakMultiplier(7), 2.0);
    });
    test('credited = round(base x multiplier)', () {
      expect(creditedPoints(15, 3), 23); // 22.5 -> the audit's "shown 15, credited 23"
      expect(creditedPoints(5, 3), 8); // 7.5
      expect(creditedPoints(10, 7), 20);
      expect(creditedPoints(15, 1), 15);
    });
    test('largest single credit stays within the +100 rule bound', () => expect(creditedPoints(15, 365), lessThanOrEqualTo(100)));
  });

  group('weekly goal counts the last 7 calendar days only', () {
    test('boundaries', () {
      final scans = [
        DateTime(2026, 10, 9, 8), // today
        DateTime(2026, 10, 3, 0, 1), // 6 days ago -> inside
        DateTime(2026, 10, 2, 23, 59), // 7 days ago -> outside
        DateTime(2025, 1, 1),
      ];
      expect(scansInLastDays(scans, today), 2);
    });
  });
}
