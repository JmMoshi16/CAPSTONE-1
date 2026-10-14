// Business rules behind the audit fixes (PROJECT_DEEP_AUDIT.md, 2026-10-15): time fields, reward stock,
// which Firestore errors are worth a retry, email validation, and per-user log counts.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/core/auth_messages.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/admin/admin_users_screen.dart';
import 'package:ecoreward_bin/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firestoreTime (kiosk tokens store Timestamps)', () {
    test('reads Timestamp, DateTime and ISO strings as UTC', () {
      final t = DateTime.utc(2026, 10, 15, 2, 30);
      expect(firestoreTime(Timestamp.fromDate(t)), t);
      expect(firestoreTime(t.toLocal()), t);
      expect(firestoreTime('2026-10-15T02:30:00Z'), t);
    });
    test('an invalid or missing value is null, never "now"', () {
      expect(firestoreTime(null), isNull);
      expect(firestoreTime('not a date'), isNull);
      expect(firestoreTime(42), isNull);
    });
  });

  group('reward stock is decided from the live document', () {
    test('unlimited (-1 or missing) and positive stock can be redeemed', () {
      expect(FirebaseService.stockAllows(-1), isTrue);
      expect(FirebaseService.stockAllows(null), isTrue);
      expect(FirebaseService.stockAllows(3), isTrue);
    });
    test('sold out cannot be redeemed', () {
      expect(FirebaseService.stockAllows(0), isFalse);
      expect(FirebaseService.stockAllows(-5), isFalse);
    });
    test('only limited stock is decremented', () {
      expect(FirebaseService.decrementsStock(3), isTrue);
      expect(FirebaseService.decrementsStock(-1), isFalse, reason: 'unlimited must not become -2');
      expect(FirebaseService.decrementsStock(null), isFalse);
    });
  });

  group('login retries only transient Firestore failures', () {
    test('timeouts and unavailable are retried', () {
      expect(FirebaseService.isTransient(TimeoutException('slow')), isTrue);
      expect(FirebaseService.isTransient(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')), isTrue);
    });
    test('permission and auth errors are not', () {
      expect(FirebaseService.isTransient(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')),
          isFalse);
      expect(FirebaseService.isTransient(FirebaseException(plugin: 'firebase_auth', code: 'user-disabled')), isFalse);
      expect(FirebaseService.isTransient(StateError('bug')), isFalse);
    });
  });

  group('isValidEmail', () {
    test('accepts ordinary addresses', () {
      for (final e in ['ana@gmail.com', 'j.dela-cruz+eco@school.edu.ph']) {
        expect(isValidEmail(e), isTrue, reason: e);
      }
    });
    test('rejects what Firebase would reject anyway', () {
      for (final e in ['@', 'ana@', '@gmail.com', 'ana@gmail', 'ana gmail.com', 'ana@@gmail.com', 'ana@gmail.com ']) {
        expect(isValidEmail(e), isFalse, reason: e);
      }
    });
  });

  test('countLogsByUser counts each user once per log', () {
    WasteLog log(String uid) => WasteLog(
        userId: uid, wasteType: 'Recyclable', pointsEarned: 10, timestamp: DateTime(2026), binId: 'b');
    expect(countLogsByUser([log('a'), log('b'), log('a')]), {'a': 2, 'b': 1});
    expect(countLogsByUser(const []), isEmpty);
  });

  testWidgets('staff see the same rank as the customer: lifetime points, not the balance (audit E)', (tester) async {
    final spentAll = UserModel(uid: 'u', username: 'Ana', email: 'ana@x.com', role: 'customer', points: 0,
        lifetimePoints: 600, createdAt: DateTime(2026));
    await tester.pumpWidget(MaterialApp(theme: AppTheme.admin,
        home: Scaffold(body: AdminUsersScreen(customers: [spentAll], logs: const []))));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Platinum'), findsWidgets);
    expect(find.text('Bronze'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  group('tokenRefusal: one check decides whether a scan may be credited', () {
    final now = DateTime.utc(2026, 10, 15, 12);
    Map<String, dynamic> token({Object? expires, bool isUsed = false, List<String> usedBy = const []}) => {
          'wasteType': 'Recyclable',
          'expiresAt': expires ?? Timestamp.fromDate(now.add(const Duration(minutes: 5))),
          'isUsed': isUsed,
          'usedBy': usedBy,
        };
    test('a fresh token may be claimed', () => expect(FirebaseService.tokenRefusal(token(), 'u', now), isNull));
    test('missing token is invalid', () =>
        expect(FirebaseService.tokenRefusal(null, 'u', now), QRValidationResult.invalid));
    test('expired, or with no readable expiry, is expired', () {
      expect(FirebaseService.tokenRefusal(token(expires: Timestamp.fromDate(now.subtract(const Duration(seconds: 1)))),
          'u', now), QRValidationResult.expired);
      expect(FirebaseService.tokenRefusal(token(expires: 'garbage'), 'u', now), QRValidationResult.expired);
    });
    test('an ISO string expiry still works (older admin tokens)', () => expect(
        FirebaseService.tokenRefusal(token(expires: now.add(const Duration(minutes: 1)).toIso8601String()), 'u', now),
        isNull));
    test('used by anyone is already used', () {
      expect(FirebaseService.tokenRefusal(token(isUsed: true), 'u', now), QRValidationResult.alreadyUsed);
      expect(FirebaseService.tokenRefusal(token(usedBy: ['u']), 'u', now), QRValidationResult.alreadyUsed);
    });
  });

  test('the waste type comes from the token; the QR text is only a fallback', () {
    expect(FirebaseService.scanWasteType({'wasteType': 'Biodegradable'}, 'Residual'), 'Biodegradable');
    expect(FirebaseService.scanWasteType({'wasteType': 'Plutonium'}, 'Recyclable'), 'Recyclable');
    expect(FirebaseService.scanWasteType({}, 'Residual'), 'Residual');
    expect(kBasePoints, {'Biodegradable': 15, 'Recyclable': 10, 'Residual': 5});
  });
}
