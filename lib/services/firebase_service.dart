import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

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
    );
    // Save to Firestore in background — don't block registration
    _db.collection('users').doc(user.uid).set(user.toMap());
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
      } catch (_) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    // Firestore unavailable — return minimal user from Auth only
    return UserModel(
      uid: uid,
      username: email.split('@')[0],
      email: email,
      role: email.contains('admineco') ? 'admin' : 'customer',
      points: 0,
      createdAt: DateTime.now(),
    );
  }

  static Future<void> logout() => _auth.signOut();

  static Future<UserModel?> getCurrentUser() async {
    final uid = currentUid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromDoc(doc) : null;
  }

  static Future<void> updateUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).update(user.toMap());
  }

  // ── Waste Logs ──────────────────────────────────────────────────────────────
  static Future<void> logWaste(WasteLog log) async {
    await _db.collection('waste_logs').add(log.toMap());
    // Add points to user
    await _db.collection('users').doc(log.userId).update({
      'points': FieldValue.increment(log.pointsEarned),
    });
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
    final redemption = Redemption(
      userId: user.uid,
      userEmail: user.email,
      rewardId: reward.id!,
      rewardTitle: reward.title,
      pointsUsed: reward.pointsCost,
      redeemedAt: DateTime.now(),
      redemptionCode: code,
    );
    await _db.collection('redemptions').add(redemption.toMap());
    await _db.collection('users').doc(user.uid).update({
      'points': FieldValue.increment(-reward.pointsCost),
    });
    return true;
  }

  static String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = DateTime.now().millisecondsSinceEpoch;
    return List.generate(8, (i) => chars[(rand >> i) % chars.length]).join();
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

  // ── Admin: All Users ────────────────────────────────────────────────────────
  static Future<List<UserModel>> getAllCustomers() async {
    final snap = await _db.collection('users').where('role', isEqualTo: 'customer').get();
    return snap.docs.map((d) => UserModel.fromDoc(d)).toList();
  }

  static Future<void> seedRewardsIfEmpty() async {
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
  }

  // ── QR Tokens ───────────────────────────────────────────────────────────────
  static Future<void> createQRToken(String token, String wasteType, DateTime expiresAt) async {
    await _db.collection('qr_tokens').doc(token).set({
      'wasteType': wasteType,
      'expiresAt': expiresAt.toIso8601String(),
      'usedBy': [],
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<QRValidationResult> validateAndUseQRToken(String token, String userId) async {
    final ref = _db.collection('qr_tokens').doc(token);
    return _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return QRValidationResult.invalid;

      final data = doc.data()!;
      final expiresAt = DateTime.tryParse(data['expiresAt'] ?? '');
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) return QRValidationResult.expired;

      final usedBy = List<String>.from(data['usedBy'] ?? []);
      if (usedBy.contains(userId)) return QRValidationResult.alreadyUsed;

      tx.update(ref, {'usedBy': FieldValue.arrayUnion([userId])});
      return QRValidationResult.valid;
    });
  }
}

enum QRValidationResult { valid, expired, alreadyUsed, invalid }
