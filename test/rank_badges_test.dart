// Needs Flutter types (colours, Firestore models): run with `flutter test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoreward_bin/core/theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/services/firebase_service.dart' show computeNewBadges;

UserModel _user({int points = 0, int? lifetime, int scans = 0, int streak = 0, List<String> badges = const []}) =>
    UserModel(uid: 'u', username: 'u', email: 'u@x', role: 'customer', points: points,
        lifetimePoints: lifetime, createdAt: DateTime(2026), scanCount: scans, streak: streak, badges: badges);

void main() {
  group('rank and level', () {
    test('rank thresholds', () {
      expect(getRank(0).label, 'Bronze');
      expect(getRank(49).label, 'Bronze');
      expect(getRank(50).label, 'Silver');
      expect(getRank(200).label, 'Gold');
      expect(getRank(500).label, 'Platinum');
    });
    test('level thresholds and progress', () {
      expect(getLevel(99).level, 1);
      expect(getLevel(100).level, 2);
      expect(getLevel(2000).level, 6);
      expect(ptsToNextLevel(2000), 0);
      expect(levelProgress(175), closeTo(0.5, 0.001));
    });
  });

  group('lifetime points (audit M-11)', () {
    test('older documents without lifetimePoints fall back to the balance', () =>
        expect(_user(points: 40).lifetimePoints, 40));
    test('rank uses lifetime points, so redeeming does not demote', () =>
        expect(getRank(_user(points: 10, lifetime: 260).lifetimePoints).label, 'Gold'));
    test('points badges use lifetime points; others use their own counters', () {
      expect(computeNewBadges(_user(points: 0, lifetime: 120)), containsAll(['pts_50', 'pts_100']));
      expect(computeNewBadges(_user(scans: 5)), containsAll(['first_scan', 'scan_5']));
      expect(computeNewBadges(_user(streak: 7)), containsAll(['streak_3', 'streak_7']));
      expect(computeNewBadges(_user(scans: 1, badges: ['first_scan'])), isEmpty);
    });
    test('a waste log without pointsAwarded shows its base points', () {
      final log = WasteLog(userId: 'u', wasteType: 'Recyclable', pointsEarned: 10, timestamp: DateTime(2026), binId: 'b');
      expect(log.pointsAwarded, 10);
      expect(log.toMap()['pointsAwarded'], 10);
    });
  });
}
