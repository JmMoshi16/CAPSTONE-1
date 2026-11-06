// Needs Flutter types (colours, Firestore models): run with `flutter test`.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoreward_bin/core/theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/services/firebase_service.dart';

UserModel _user({int points = 0, int? lifetime, int scans = 0, int streak = 0, String? lastScan,
        List<String> badges = const []}) =>
    UserModel(uid: 'u', username: 'u', email: 'u@x', role: 'customer', points: points,
        lifetimePoints: lifetime, createdAt: DateTime(2026), scanCount: scans, streak: streak, lastScanDate: lastScan,
        badges: badges);

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

  group('a redeem writes what the rules require (firestore.rules isPaidRedemption)', () {
    final r = Redemption(userId: 'u', userEmail: 'u@x', rewardId: 'latte', rewardTitle: 'Iced Latte', pointsUsed: 120,
        redeemedAt: DateTime(2099), redemptionCode: 'AB12CD34');
    test('the code is dated by the server, never by the phone', () {
      final w = redemptionWrite(r);
      expect(w['redeemedAt'], isA<FieldValue>());
      expect(w.keys, unorderedEquals(['userId', 'userEmail', 'rewardId', 'rewardTitle', 'pointsUsed', 'redeemedAt',
          'status', 'redemptionCode']), reason: 'the rules refuse any other field');
      expect(w['status'], 'pending');
      expect(w['pointsUsed'], 120);
    });
    test('the payment is tagged with the code it pays for', () {
      expect(redeemPayment(newBalance: 30, lifetimePoints: 400, redemptionId: 'rd1'),
          {'points': 30, 'lifetimePoints': 400, 'lastRedemptionId': 'rd1'});
    });
  });

  group('badges pay a one-time bonus', () {
    final today = DateTime(2026, 11, 5, 10);
    final allIds = [for (final b in FirebaseService.getAllBadgeDefs()) b['id'] as String];

    test('every badge has a small bonus, 140 in all', () {
      for (final b in FirebaseService.getAllBadgeDefs()) {
        expect(b['bonus'], isA<int>().having((v) => v, 'bonus', inInclusiveRange(5, 25)), reason: '${b['id']}');
      }
      expect(badgeBonus(allIds), 140);
      expect(badgeBonus(['first_scan']), 5);
      expect(badgeBonus(['scan_50', 'pts_500', 'streak_7']), 65);
      expect(badgeBonus(const []), 0);
    });

    test("the bundled rules.json lists the same bonuses (the web console's copy is checked in its own tests)", () {
      final rules = jsonDecode(File('assets/config/rules.json').readAsStringSync()) as Map<String, dynamic>;
      expect({for (final b in rules['badges'] as List) b['id']: b['bonus']},
          {for (final b in FirebaseService.getAllBadgeDefs()) b['id']: b['bonus']});
    });

    test('a scan that unlocks a badge pays its bonus, spendable and lifetime', () {
      final (credit, after) = creditScanFor(_user(points: 20, lifetime: 20, scans: 4, badges: ['first_scan']), 5, today);
      expect(credit.pointsAwarded, 5);
      expect(credit.newBadges, ['scan_5']);
      expect(credit.badgeBonus, 10);
      expect(credit.total, 15);
      expect(after.points, 35);
      expect(after.lifetimePoints, 35, reason: 'counts toward rank, level and leaderboard');
      expect(after.scanCount, 5);
      expect(after.badges, ['first_scan', 'scan_5']);
    });

    test('a badge already held pays nothing again', () {
      final (credit, after) =
          creditScanFor(_user(points: 30, scans: 5, badges: ['first_scan', 'scan_5']), 5, today);
      expect(credit.newBadges, isEmpty);
      expect(credit.badgeBonus, 0);
      expect(after.points, 35);
    });

    test('the rarest pile-up, three badges on a doubled scan, is paid in full within the +100 rule bound', () {
      final held = allIds.where((id) => !['scan_50', 'pts_500', 'streak_7'].contains(id)).toList();
      final (credit, after) = creditScanFor(
          _user(points: 100, lifetime: 480, scans: 49, streak: 6, lastScan: '2026-11-04', badges: held), 15, today);
      expect(credit.pointsAwarded, 30);
      expect(credit.newBadges, unorderedEquals(['scan_50', 'pts_500', 'streak_7']));
      expect(credit.badgeBonus, 65);
      expect(credit.total, lessThanOrEqualTo(100));
      expect(after.lifetimePoints, 480 + 95);
    });

    test('a bonus that crosses a points badge unlocks it on the next scan, not this one', () {
      // 40 + 5 = 45 lifetime: no Point Earner yet; First Scan's +5 makes 50, which counts from the next scan.
      final (credit, after) = creditScanFor(_user(points: 40, lifetime: 40), 5, today);
      expect(credit.newBadges, ['first_scan']);
      expect(after.lifetimePoints, 50);
      expect(computeNewBadges(after), ['pts_50']);
    });

    test('a waste log records the badge bonus inside what it credited', () {
      final log = WasteLog(userId: 'u', wasteType: 'Residual', pointsEarned: 5, pointsAwarded: 15, badgeBonus: 10,
          timestamp: DateTime(2026), binId: 'b');
      expect(log.toMap()['badgeBonus'], 10);
      expect(log.toMap()['pointsAwarded'], 15);
      expect(WasteLog(userId: 'u', wasteType: 'Residual', pointsEarned: 5, timestamp: DateTime(2026), binId: 'b')
          .badgeBonus, 0, reason: 'older logs had none');
    });
  });
}
