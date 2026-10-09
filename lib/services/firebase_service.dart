import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../core/theme.dart';

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

List<String> _computeNewBadges(UserModel user) {
  final earned = <String>[];
  for (final b in _badgeDefs) {
    final id = b['id'] as String;
    if (user.badges.contains(id)) continue;
    final req = b['req'] as String;
    final val = b['value'] as int;
    if (req == 'scans'  && user.scanCount >= val) earned.add(id);
    if (req == 'points' && user.points    >= val) earned.add(id);
    if (req == 'streak' && user.streak    >= val) earned.add(id);
  }
  return earned;
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
  static Future<UserModel> register(String username, String email, String password, String role) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = UserModel(
      uid: cred.user!.uid,
      username: username,
      email: email,
      role: role,
      points: 0,
      createdAt: DateTime.now(),
      scanCount: 0,
      streak: 0,
      badges: [],
    );
    await _db.collection('users').doc(user.uid).set(user.toMap());
    return user;
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
        await _db.collection('users').doc(uid).set(fallback.toMap());
        return fallback;
      } catch (_) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    // Firestore unreachable after retries
    throw Exception('Could not reach Firestore after 3 attempts. Check your connection and try again.');
  }

  static Future<void> logout() => _auth.signOut();

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
    await _db.collection('users').doc(uid).update({'username': username});
  }

  // ── Waste Logs ──────────────────────────────────────────────────────────────
  /// Logs waste, credits points, updates streak, awards badges.
  /// Returns list of newly earned badge IDs (empty if none).
  static Future<List<String>> logWaste(WasteLog log) async {
    await _db.collection('waste_logs').add(log.toMap());

    final userRef = _db.collection('users').doc(log.userId);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';

    List<String> newBadges = [];

    await _db.runTransaction((tx) async {
      final userDoc = await tx.get(userRef);
      if (!userDoc.exists) return;

      final snapshot = UserModel.fromDoc(userDoc);
      final user = snapshot;

      // streak logic
      int newStreak = user.streak;
      if (user.lastScanDate == null) {
        newStreak = 1;
      } else {
        final last = DateTime.tryParse(user.lastScanDate!);
        if (last != null) {
          final diff = DateTime(today.year, today.month, today.day)
              .difference(DateTime(last.year, last.month, last.day))
              .inDays;
          if (diff == 0)      newStreak = user.streak;
          else if (diff == 1) newStreak = user.streak + 1;
          else                newStreak = 1;
        }
      }

      // ── Streak multiplier: applied AFTER streak is updated ────────────────
      final multiplier = streakMultiplier(newStreak);
      final earnedPts  = (log.pointsEarned * multiplier).round();

      final currentPoints = snapshot.points + earnedPts;
      final currentScans  = snapshot.scanCount + 1;

      final projected = UserModel(
        uid: user.uid, username: user.username, email: user.email,
        role: user.role, points: currentPoints, createdAt: user.createdAt,
        scanCount: currentScans, streak: newStreak,
        lastScanDate: todayStr, badges: List<String>.from(user.badges),
      );

      newBadges = _computeNewBadges(projected);
      final allBadges = [...user.badges, ...newBadges];

      tx.update(userRef, {
        'points':       FieldValue.increment(earnedPts),
        'scanCount':    FieldValue.increment(1),
        'streak':       newStreak,
        'lastScanDate': todayStr,
        'badges':       allBadges,
      });
    });

    return newBadges;
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

  static Future<void> updateReward(Reward reward) async {
    await _db.collection('rewards').doc(reward.id).update(reward.toMap());
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
      final userRef   = _db.collection('users').doc(user.uid);
      final rewardRef = _db.collection('rewards').doc(reward.id);
      final userDoc   = await tx.get(userRef);
      final rewardDoc = await tx.get(rewardRef);
      if (!userDoc.exists) return;

      final currentPoints = (userDoc.data()?['points'] ?? 0) as int;
      if (currentPoints < reward.pointsCost) return;

      // FIX 10: Stock check — read live from Firestore to avoid races
      if (rewardDoc.exists) {
        final liveStock = rewardDoc.data()?['stock'];
        final stockInt = (liveStock is int) ? liveStock : -1;
        if (stockInt != -1 && stockInt <= 0) return;
      }

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
      tx.update(userRef, {'points': FieldValue.increment(-reward.pointsCost)});

      // FIX 10: Decrement stock only if limited
      if (reward.stock != -1 && rewardDoc.exists) {
        tx.update(rewardRef, {'stock': FieldValue.increment(-1)});
      }

      success = true;
    });

    return success;
  }

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

  static Future<List<UserModel>> getLeaderboard({int limit = 20}) async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'customer')  // filter in Firestore, not in Dart
        .orderBy('points', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => UserModel.fromDoc(d))
        .toList();
  }

  static Future<int> getUserRank(String uid) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get()
          .timeout(const Duration(seconds: 5));
      if (!userDoc.exists) return 0;
      final pts = (userDoc.data()?['points'] ?? 0) as int;
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'customer')  // exclude admins from rank
          .where('points', isGreaterThan: pts)
          .get()
          .timeout(const Duration(seconds: 5));
      final above = snap.docs.length;
      return above + 1;
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
      for (final r in items) {
        await _db.collection('rewards').add(r);
      }
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
      'expiresAt': expiresAt.toIso8601String(),
      'usedBy': [],
      'isUsed': false,
      'createdAt': DateTime.now().toIso8601String(),
      'claimCode': claimCode,
    });
  }

  static Future<QRValidationResult> validateAndUseQRToken(String token, String userId) async {
    final ref = _db.collection('qr_tokens').doc(token);
    final scanTime = DateTime.now();

    // Run the atomic transaction — only tx.get/tx.update inside
    final result = await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return QRValidationResult.invalid;

      final data = doc.data()!;
      final expiresAt = DateTime.tryParse(data['expiresAt'] ?? '');
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) return QRValidationResult.expired;

      // H-02: token-level guard — reject any second claimer regardless of account
      if (data['isUsed'] == true) return QRValidationResult.alreadyUsed;
      final usedBy = List<String>.from(data['usedBy'] ?? []);
      if (usedBy.contains(userId)) return QRValidationResult.alreadyUsed;

      tx.update(ref, {
        'isUsed': true,
        'usedBy': FieldValue.arrayUnion([userId]),
      });
      return QRValidationResult.valid;
    });

    // Write scan history outside the transaction (non-atomic, non-critical)
    if (result == QRValidationResult.valid) {
      try {
        final tokenDoc = await ref.get();
        final data = tokenDoc.data() ?? {};
        final wasteType = data['wasteType'] ?? 'Residual';
        final pointsMap = {'Biodegradable': 15, 'Recyclable': 10, 'Residual': 5};
        final points = pointsMap[wasteType] ?? 5;
        final createdAt = DateTime.tryParse(data['createdAt'] ?? '') ?? scanTime;
        final secondsAfterCreation = scanTime.difference(createdAt).inSeconds;
        final userDoc = await _db.collection('users').doc(userId).get();
        final username = userDoc.exists ? (userDoc.data()?['username'] ?? '') : '';
        final email = userDoc.exists ? (userDoc.data()?['email'] ?? '') : '';
        await _db.collection('qr_scan_history').add({
          'token': token,
          'wasteType': wasteType,
          'scannedAt': scanTime.toIso8601String(),
          'scannedByUid': userId,
          'scannedByName': username,
          'scannedByEmail': email,
          'pointsAwarded': points,
          'tokenCreatedAt': data['createdAt'] ?? scanTime.toIso8601String(),
          'expiresAt': data['expiresAt'] ?? scanTime.toIso8601String(),
          'secondsAfterCreation': secondsAfterCreation,
        });
      } catch (_) {
        // Non-critical — scan history write failure should not block the user
      }
    }

    return result;
  }
}

enum QRValidationResult { valid, expired, alreadyUsed, invalid }
