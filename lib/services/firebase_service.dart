import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../core/gamification.dart';

// ── Badge definitions ──────────────────────────────────────────────────────────
const _badgeDefs = [
  {'id': 'first_scan',    'label': 'First Scan',    'desc': 'Completed your first scan',         'icon': '🌱', 'req': 'scans',  'value': 1},
  {'id': 'scan_5',        'label': '5 Scans',       'desc': 'Scanned waste 5 times',              'icon': '♻️', 'req': 'scans',  'value': 5},
  {'id': 'scan_10',       'label': 'Eco Starter',   'desc': 'Scanned waste 10 times',             'icon': '🌿', 'req': 'scans',  'value': 10},
  {'id': 'scan_25',       'label': 'Eco Warrior',   'desc': 'Scanned waste 25 times',             'icon': '🏆', 'req': 'scans',  'value': 25},
  {'id': 'scan_50',       'label': 'Eco Champion',  'desc': 'Scanned waste 50 times',             'icon': '🥇', 'req': 'scans',  'value': 50},
  {'id': 'pts_50',        'label': 'Point Earner',  'desc': 'Earned 50 points total',             'icon': '⭐', 'req': 'points', 'value': 50},
  {'id': 'pts_100',       'label': 'Century Club',  'desc': 'Earned 100 points total',            'icon': '💯', 'req': 'points', 'value': 100},
  {'id': 'pts_500',       'label': 'Platinum Eco',  'desc': 'Earned 500 points total',            'icon': '💎', 'req': 'points', 'value': 500},
  {'id': 'streak_3',      'label': 'On a Roll',     'desc': '3-day scan streak',                  'icon': '🔥', 'req': 'streak', 'value': 3},
  {'id': 'streak_7',      'label': 'Week Warrior',  'desc': '7-day scan streak',                  'icon': '🌟', 'req': 'streak', 'value': 7},
];

/// Badge ids [user] qualifies for but does not have yet. "Points" badges are about points
/// ever earned, so they use lifetimePoints (a redemption must not block them).
List<String> computeNewBadges(UserModel user) {
  final earned = <String>[];
  for (final b in _badgeDefs) {
    final id = b['id'] as String;
    if (user.badges.contains(id)) continue;
    final req = b['req'] as String;
    final val = b['value'] as int;
    if (req == 'scans'  && user.scanCount      >= val) earned.add(id);
    if (req == 'points' && user.lifetimePoints >= val) earned.add(id);
    if (req == 'streak' && user.streak         >= val) earned.add(id);
  }
  return earned;
}

/// The public `profiles/{uid}` document is an exact copy of these four `users` fields;
/// the security rules reject any profile write that does not match the user document.
Map<String, dynamic> _profileMirror({
  required String username, required int points, required int lifetimePoints, required List<String> badges,
}) => {'username': username, 'points': points, 'lifetimePoints': lifetimePoints, 'badges': badges};

class ScanCredit {
  final int pointsAwarded;
  final double multiplier;
  final List<String> newBadges;
  const ScanCredit(this.pointsAwarded, this.multiplier, this.newBadges);
}

Map<String, dynamic> _badgeInfo(String id) =>
    _badgeDefs.firstWhere((b) => b['id'] == id,
        orElse: () => {'id': id, 'label': id, 'desc': '', 'icon': '🏅', 'req': '', 'value': 0});

class FirebaseService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  // Call once at app start to enable offline cache
  static void init() {
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  static String? get currentUid => _auth.currentUser?.uid;

  // ── Auth ────────────────────────────────────────────────────────────────────
  // Every self-registered account is a customer; the Firestore rules enforce the same on create (audit D).
  static Future<UserModel> register(String username, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = UserModel(
      uid: cred.user!.uid,
      username: username,
      email: email,
      role: 'customer',
      points: 0,
      createdAt: DateTime.now(),
      scanCount: 0,
      streak: 0,
      badges: [],
    );
    await _createUserAndProfile(user);
    return user;
  }

  static Future<void> _createUserAndProfile(UserModel user) async {
    final batch = _db.batch()
      ..set(_db.collection('users').doc(user.uid), user.toMap())
      ..set(_db.collection('profiles').doc(user.uid), _profileMirror(
          username: user.username, points: 0, lifetimePoints: 0, badges: const []));
    await batch.commit();
  }

  static Future<UserModel> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    // Retry up to 3 times for Firestore to respond
    for (int i = 0; i < 3; i++) {
      try {
        final doc = await _db.collection('users').doc(uid).get()
            .timeout(const Duration(seconds: 8));
        if (doc.exists) return UserModel.fromDoc(doc);
        // H-10: profile doc missing (auth exists but Firestore write failed at registration)
        // Create a default customer profile so the account is not permanently locked.
        final fallback = UserModel(
          uid: uid,
          email: email,
          username: email.split('@').first,
          role: 'customer',
          points: 0,
          createdAt: DateTime.now(),
          scanCount: 0,
          streak: 0,
          badges: [],
        );
        await _createUserAndProfile(fallback);
        return fallback;
      } catch (e) {
        if (!isTransient(e)) rethrow;   // permission-denied etc. would fail the same way again (audit H)
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    // Firestore unreachable after retries
    throw Exception('Could not reach Firestore after 3 attempts. Check your connection and try again.');
  }

  /// Errors worth retrying: the request may succeed a second later.
  static bool isTransient(Object e) =>
      e is TimeoutException ||
      (e is FirebaseException && const {'unavailable', 'deadline-exceeded', 'aborted'}.contains(e.code));

  static Future<void> logout() => _auth.signOut();

  static Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email);

  static Future<UserModel?> getCurrentUser() async {
    final uid = currentUid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromDoc(doc) : null;
  }

  /// Changes ONLY the display name. Never write the whole user document back from a
  /// client-side snapshot: that overwrites points/streak/badges earned since it was loaded
  /// and re-sends `role` (audit H-01).
  static Future<void> updateUsername(String uid, String username) async {
    final userRef = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final u = UserModel.fromDoc(await tx.get(userRef));
      tx.update(userRef, {'username': username});
      tx.set(_db.collection('profiles').doc(uid), _profileMirror(
          username: username, points: u.points, lifetimePoints: u.lifetimePoints, badges: u.badges));
    });
  }

  // ── Waste Logs ──────────────────────────────────────────────────────────────
  /// Credits one scan inside [tx]: the waste log, points (base × streak multiplier), lifetime
  /// points, streak and badges, so the log always records what was credited.
  static ScanCredit _creditScan(Transaction tx, DocumentSnapshot<Map<String, dynamic>> userDoc, WasteLog log,
      DateTime today) {
    final userRef = _db.collection('users').doc(log.userId);
    final profileRef = _db.collection('profiles').doc(log.userId);
    final logRef = _db.collection('waste_logs').doc();
    final todayStr = dayKey(today);
    final user = UserModel.fromDoc(userDoc);

    final streak     = nextStreak(user.streak, user.lastScanDate, today);
    final multiplier = streakMultiplier(streak);
    final awarded    = creditedPoints(log.pointsEarned, streak);

    final projected = UserModel(
      uid: user.uid, username: user.username, email: user.email, role: user.role,
      points: user.points + awarded, lifetimePoints: user.lifetimePoints + awarded,
      createdAt: user.createdAt, scanCount: user.scanCount + 1, streak: streak,
      lastScanDate: todayStr, badges: List<String>.from(user.badges),
    );
    final newBadges = computeNewBadges(projected);
    final allBadges = [...user.badges, ...newBadges];

    tx.set(logRef, WasteLog(
      userId: log.userId, wasteType: log.wasteType, pointsEarned: log.pointsEarned,
      pointsAwarded: awarded, timestamp: today, binId: log.binId,
    ).toMap());
    tx.update(userRef, {
      'points':         projected.points,
      'lifetimePoints': projected.lifetimePoints,
      'scanCount':      projected.scanCount,
      'streak':         streak,
      'lastScanDate':   todayStr,
      'badges':         allBadges,
    });
    tx.set(profileRef, _profileMirror(
        username: user.username, points: projected.points,
        lifetimePoints: projected.lifetimePoints, badges: allBadges));
    return ScanCredit(awarded, multiplier, newBadges);
  }

  static Future<List<WasteLog>> getUserWasteLogs(String userId) async {
    final snap = await _db
        .collection('waste_logs')
        .where('userId', isEqualTo: userId)
        .get();
    final list = snap.docs.map((d) => WasteLog.fromDoc(d)).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  static Future<List<WasteLog>> getAllWasteLogs() async {
    final snap = await _db.collection('waste_logs').get();
    final list = snap.docs.map((d) => WasteLog.fromDoc(d)).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  // ── Rewards ─────────────────────────────────────────────────────────────────
  static Future<void> addReward(Reward reward) async {
    await _db.collection('rewards').add(reward.toMap());
  }

  /// Partial update: pass only the fields that changed (audit M-12).
  static Future<void> updateReward(String id, Map<String, dynamic> changes) async {
    await _db.collection('rewards').doc(id).update(changes);
  }

  static Future<void> deleteReward(String id) async {
    await _db.collection('rewards').doc(id).delete();
  }

  static Future<List<Reward>> getRewards() async {
    final snap = await _db.collection('rewards').get();
    return snap.docs
        .map((d) => Reward.fromDoc(d))
        .where((r) => r.isActive)
        .toList();
  }

  static Future<List<Reward>> getAllRewards() async {
    final snap = await _db.collection('rewards').get();
    return snap.docs.map((d) => Reward.fromDoc(d)).toList();
  }

  // ── Redemptions ─────────────────────────────────────────────────────────────
  static Future<bool> redeemReward(UserModel user, Reward reward) async {
    if (user.points < reward.pointsCost) return false;
    final code = _generateCode();
    bool success = false;

    await _db.runTransaction((tx) async {
      final userRef    = _db.collection('users').doc(user.uid);
      final profileRef = _db.collection('profiles').doc(user.uid);  // H-13
      final rewardRef = _db.collection('rewards').doc(reward.id);
      final userDoc   = await tx.get(userRef);
      final rewardDoc = await tx.get(rewardRef);
      if (!userDoc.exists) return;

      final live = UserModel.fromDoc(userDoc);
      if (live.points < reward.pointsCost) return;

      // FIX 10: Stock is read live inside the transaction; the client copy may be stale (audit C).
      final liveStock = rewardDoc.exists ? (rewardDoc.data()?['stock']) : null;
      final stockInt = liveStock is int ? liveStock : null;
      if (!stockAllows(stockInt)) return;

      final redemptionRef = _db.collection('redemptions').doc();
      final redemption = Redemption(
        userId: user.uid,
        userEmail: user.email,
        rewardId: reward.id!,
        rewardTitle: reward.title,
        pointsUsed: reward.pointsCost,
        redeemedAt: DateTime.now(),
        redemptionCode: code,
      );
      tx.set(redemptionRef, redemption.toMap());
      // Spending lowers the balance only; lifetimePoints (rank/level) is untouched (audit M-11).
      final newBalance = live.points - reward.pointsCost;
      // lifetimePoints is written explicitly: on older documents it is missing and would otherwise
      // be read as the (now lower) balance.
      tx.update(userRef, {'points': newBalance, 'lifetimePoints': live.lifetimePoints});
      tx.set(profileRef, _profileMirror(
          username: live.username, points: newBalance,
          lifetimePoints: live.lifetimePoints, badges: live.badges));

      if (decrementsStock(stockInt)) {
        tx.update(rewardRef, {'stock': FieldValue.increment(-1)});
      }

      success = true;
    });

    return success;
  }

  /// Stock -1 or missing means unlimited.
  static bool stockAllows(int? stock) => stock == null || stock == -1 || stock > 0;
  static bool decrementsStock(int? stock) => stock != null && stock > 0;

  static String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static Future<void> claimRedemption(String redemptionId) async {
    await _db.collection('redemptions').doc(redemptionId).update({'status': 'claimed'});
  }

  static Future<List<Redemption>> getUserRedemptions(String userId) async {
    final snap = await _db.collection('redemptions').where('userId', isEqualTo: userId).get();
    final list = snap.docs.map((d) => Redemption.fromDoc(d)).toList();
    list.sort((a, b) => b.redeemedAt.compareTo(a.redeemedAt));
    return list;
  }

  static Future<List<Redemption>> getAllRedemptions() async {
    final snap = await _db.collection('redemptions').get();
    final list = snap.docs.map((d) => Redemption.fromDoc(d)).toList();
    list.sort((a, b) => b.redeemedAt.compareTo(a.redeemedAt));
    return list;
  }

  // ── Gamification ────────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> getAllBadgeDefs() =>
      _badgeDefs.map((b) => Map<String, dynamic>.from(b)).toList();

  static Map<String, dynamic> getBadgeInfo(String id) => _badgeInfo(id);

  // Ranked by lifetimePoints so redeeming a reward never costs a leaderboard place (audit M-11).
  // Profiles without lifetimePoints are not returned until tools/backfill_profiles.py has run.
  static Future<List<UserModel>> getLeaderboard({int limit = 20}) async {
    final snap = await _db
        .collection('profiles')
        .orderBy('lifetimePoints', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return UserModel(
        uid: d.id,
        username: data['username'] ?? '',
        email: '',
        role: 'customer',
        // Tolerate numbers stored as doubles (e.g. 12.0 written by a tool) instead of failing the list.
        points: (data['points'] as num?)?.toInt() ?? 0,
        lifetimePoints: (data['lifetimePoints'] as num?)?.toInt(),
        createdAt: DateTime.now(),
        badges: List<String>.from(data['badges'] ?? []),
      );
    }).toList();
  }

  /// 1 + number of customers with more lifetime points; 0 if unknown.
  /// Uses a server-side count() instead of downloading every higher-ranked profile (audit M-16).
  static Future<int> getUserRank(String uid) async {
    try {
      final profileDoc = await _db.collection('profiles').doc(uid).get()
          .timeout(const Duration(seconds: 5));
      if (!profileDoc.exists) return 0;
      final p = ProfileModel.fromDoc(profileDoc);
      final agg = await _db
          .collection('profiles')
          .where('lifetimePoints', isGreaterThan: p.lifetimePoints)
          .count()
          .get()
          .timeout(const Duration(seconds: 5));
      return (agg.count ?? 0) + 1;
    } catch (_) {
      return 0;
    }
  }

  // ── Admin: All Users ────────────────────────────────────────────────────────
  static Future<List<UserModel>> getAllCustomers() async {
    final snap = await _db.collection('users').where('role', isEqualTo: 'customer').get();
    return snap.docs.map((d) => UserModel.fromDoc(d)).toList();
  }

  static Future<void> seedRewardsIfEmpty() async {
    try {
      final snap = await _db.collection('rewards').limit(1).get();
      if (snap.docs.isNotEmpty) return;
      final items = [
        {'title': 'Free Coffee', 'description': 'Enjoy a free cup of coffee at the cafe', 'pointsCost': 50, 'category': 'Coffee', 'isActive': true},
        {'title': 'Iced Latte', 'description': 'Refreshing iced latte on us', 'pointsCost': 80, 'category': 'Coffee', 'isActive': true},
        {'title': 'Free Meal', 'description': 'Get a free meal from our menu', 'pointsCost': 150, 'category': 'Food', 'isActive': true},
        {'title': 'Snack Pack', 'description': 'A pack of assorted snacks', 'pointsCost': 60, 'category': 'Food', 'isActive': true},
        {'title': '10% Discount', 'description': '10% off your next purchase', 'pointsCost': 30, 'category': 'Discount', 'isActive': true},
        {'title': '20% Discount', 'description': '20% off any item in the store', 'pointsCost': 100, 'category': 'Discount', 'isActive': true},
        {'title': 'Eco Tote Bag', 'description': 'Reusable eco-friendly tote bag', 'pointsCost': 120, 'category': 'Other', 'isActive': true},
        {'title': 'Plant a Tree', 'description': 'We plant a tree in your name', 'pointsCost': 200, 'category': 'Other', 'isActive': true},
      ];
      // Fixed IDs in one batch: two clients seeding at once write the same 8 docs, not 16 (audit L).
      final batch = _db.batch();
      for (final (i, r) in items.indexed) {
        batch.set(_db.collection('rewards').doc('seed_$i'), r);
      }
      await batch.commit();
    } catch (_) {
      // Non-critical — rewards will seed on next successful connection
    }
  }

  // ── QR Tokens ───────────────────────────────────────────────────────────────
  static Future<void> createQRToken(String token, String wasteType, DateTime expiresAt) async {
    // Use Random.secure() for unpredictable claim codes
    final claimCode = (1000 + Random.secure().nextInt(9000)).toString();
    await _db.collection('qr_tokens').doc(token).set({
      'wasteType': wasteType,
      'expiresAt': Timestamp.fromDate(expiresAt.toUtc()),   // H-07
      'usedBy': [],
      'isUsed': false,
      'createdAt': FieldValue.serverTimestamp(),             // H-07
      'claimCode': claimCode,
    });
  }

  /// Why [userId] may not claim a token with this [data] at [nowUtc], or null when they may.
  static QRValidationResult? tokenRefusal(Map<String, dynamic>? data, String userId, DateTime nowUtc) {
    if (data == null) return QRValidationResult.invalid;
    // H-07: Timestamp or ISO string; an unreadable expiry counts as expired.
    final expiresAt = firestoreTime(data['expiresAt']);
    if (expiresAt == null || nowUtc.isAfter(expiresAt)) return QRValidationResult.expired;
    // H-02: token-level guard — reject any second claimer regardless of account
    if (data['isUsed'] == true) return QRValidationResult.alreadyUsed;
    if (List<String>.from(data['usedBy'] ?? []).contains(userId)) return QRValidationResult.alreadyUsed;
    return null;
  }

  /// The token's category is authoritative; the QR text is only a fallback for tokens without one.
  static String scanWasteType(Map<String, dynamic> token, String fromQr) {
    final t = token['wasteType'];
    return kBasePoints.containsKey(t) ? t as String : fromQr;
  }

  /// Claims the token AND credits the points in one transaction, so a dropped connection can no
  /// longer use up a token without crediting it.
  static Future<ScanClaim> claimScan(String token, String userId, {required String qrWasteType}) async {
    final ref = _db.collection('qr_tokens').doc(token);
    final userRef = _db.collection('users').doc(userId);
    final scanTime = DateTime.now();
    Map<String, dynamic> tokenData = const {};
    Map<String, dynamic> userData = const {};

    final claim = await _db.runTransaction<ScanClaim>((tx) async {
      final doc = await tx.get(ref);
      final refusal = tokenRefusal(doc.data(), userId, scanTime.toUtc());
      if (refusal != null) return ScanClaim(refusal);
      final userDoc = await tx.get(userRef);   // all reads before any write
      if (!userDoc.exists) throw StateError('User profile not found');
      tokenData = doc.data()!;
      userData = userDoc.data() ?? const {};

      final wasteType = scanWasteType(tokenData, qrWasteType);
      final base = kBasePoints[wasteType]!;
      tx.update(ref, {'isUsed': true, 'usedBy': FieldValue.arrayUnion([userId])});
      final credit = _creditScan(tx, userDoc, WasteLog(
        userId: userId, wasteType: wasteType, pointsEarned: base, timestamp: scanTime,
        binId: token.substring(0, min(8, token.length)),
      ), scanTime);
      return ScanClaim(QRValidationResult.valid, wasteType: wasteType, basePoints: base, credit: credit);
    });

    // Audit trail for staff, outside the transaction: a failure here must not undo or hide the credit.
    if (claim.result == QRValidationResult.valid) {
      try {
        // Kiosk tokens store a Timestamp; the old String-only parse threw and the history row was lost (audit B).
        final createdAt = firestoreTime(tokenData['createdAt']) ?? scanTime.toUtc();
        await _db.collection('qr_scan_history').add({
          'token': token,
          'wasteType': claim.wasteType,
          'scannedAt': Timestamp.fromDate(scanTime.toUtc()),  // H-07
          'scannedByUid': userId,
          'scannedByName': userData['username'] ?? '',
          'scannedByEmail': userData['email'] ?? '',
          'pointsAwarded': claim.basePoints,
          'tokenCreatedAt': tokenData['createdAt'] ?? Timestamp.fromDate(scanTime.toUtc()),
          'expiresAt': tokenData['expiresAt'] ?? Timestamp.fromDate(scanTime.toUtc()),
          'secondsAfterCreation': scanTime.toUtc().difference(createdAt).inSeconds,
        });
      } catch (_) {
        // Non-critical — scan history write failure should not block the user
      }
    }
    return claim;
  }
}

/// Base points per category: the kiosk, the admin QR screen and the scanner all award these.
const kBasePoints = {'Biodegradable': 15, 'Recyclable': 10, 'Residual': 5};

/// The outcome of a scan; [credit] is set only when [result] is valid.
class ScanClaim {
  final QRValidationResult result;
  final String wasteType;
  final int basePoints;
  final ScanCredit? credit;
  const ScanClaim(this.result, {this.wasteType = '', this.basePoints = 0, this.credit});
}

enum QRValidationResult { valid, expired, alreadyUsed, invalid }
