import 'package:cloud_firestore/cloud_firestore.dart';

/// H-07: reads a Firestore Timestamp, DateTime or ISO string as UTC; anything else is null.
DateTime? firestoreTime(dynamic v) {
  if (v is Timestamp) return v.toDate().toUtc();
  if (v is DateTime) return v.toUtc();
  if (v is String) return DateTime.tryParse(v)?.toUtc();
  return null;
}

// Display fields only: a missing date shows as "now" rather than breaking the list.
DateTime _tsToDateTime(dynamic v) => firestoreTime(v) ?? DateTime.now().toUtc();

class UserModel {
  final String uid;
  String username;
  String email;
  final String role;
  int points;          // spendable balance (goes down on redemption)
  int lifetimePoints;  // everything ever credited; drives rank, level and leaderboard (audit M-11)
  final DateTime createdAt;
  int scanCount;
  int streak;
  String? lastScanDate; // yyyy-MM-dd
  List<String> badges;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.role,
    this.points = 0,
    int? lifetimePoints,
    required this.createdAt,
    this.scanCount = 0,
    this.streak = 0,
    this.lastScanDate,
    this.badges = const [],
  }) : lifetimePoints = lifetimePoints ?? points;

  Map<String, dynamic> toMap() => {
        'username': username,
        'email': email,
        'role': role,
        'points': points,
        'lifetimePoints': lifetimePoints,
        'createdAt': Timestamp.fromDate(createdAt.toUtc()),
        'scanCount': scanCount,
        'streak': streak,
        'lastScanDate': lastScanDate,
        'badges': badges,
      };

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      username: d['username'] ?? '',
      email: d['email'] ?? '',
      role: d['role'] ?? 'customer',
      points: d['points'] ?? 0,
      lifetimePoints: d['lifetimePoints'] as int?,   // older docs: falls back to points
      createdAt: _tsToDateTime(d['createdAt']),
      scanCount: d['scanCount'] ?? 0,
      streak: d['streak'] ?? 0,
      lastScanDate: d['lastScanDate'],
      badges: List<String>.from(d['badges'] ?? []),
    );
  }
}

class WasteLog {
  final String? id;
  final String userId;
  final String wasteType; // 'Biodegradable', 'Recyclable', 'Residual'
  final int pointsEarned;  // base points for the category
  final int pointsAwarded; // what was actually credited (base × streak multiplier) — show this (audit M-11)
  final DateTime timestamp;
  final String binId;

  WasteLog({
    this.id,
    required this.userId,
    required this.wasteType,
    required this.pointsEarned,
    int? pointsAwarded,
    required this.timestamp,
    required this.binId,
  }) : pointsAwarded = pointsAwarded ?? pointsEarned;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'wasteType': wasteType,
        'pointsEarned': pointsEarned,
        'pointsAwarded': pointsAwarded,
        'timestamp': FieldValue.serverTimestamp(),
        'binId': binId,
      };

  factory WasteLog.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WasteLog(
      id: doc.id,
      userId: d['userId'] ?? '',
      wasteType: d['wasteType'] ?? '',
      pointsEarned: d['pointsEarned'] ?? 0,
      pointsAwarded: d['pointsAwarded'] as int?,   // older logs: falls back to base
      timestamp: _tsToDateTime(d['timestamp']),
      binId: d['binId'] ?? '',
    );
  }
}

// FIX 10: Added stock field — -1 means unlimited
class Reward {
  final String? id;
  final String title;
  final String description;
  final int pointsCost;
  final String category; // 'Coffee', 'Food', 'Discount', 'Other'
  final bool isActive;
  final int stock; // -1 = unlimited, 0 = sold out, >0 = remaining

  Reward({
    this.id,
    required this.title,
    required this.description,
    required this.pointsCost,
    required this.category,
    this.isActive = true,
    this.stock = -1,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'pointsCost': pointsCost,
        'category': category,
        'isActive': isActive,
        'stock': stock,
      };

  factory Reward.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final isActiveVal = d['isActive'];
    return Reward(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      pointsCost: (d['pointsCost'] ?? 0) is int
          ? (d['pointsCost'] ?? 0) as int
          : int.tryParse('${d['pointsCost']}') ?? 0,
      category: d['category'] ?? 'Other',
      isActive: isActiveVal == true || isActiveVal == 'true',
      // Firestore docs without stock field default to -1 (unlimited)
      stock: (d['stock'] is int) ? d['stock'] as int : -1,
    );
  }
}

class Redemption {
  final String? id;
  final String userId;
  final String userEmail;
  final String rewardId;
  final String rewardTitle;
  final int pointsUsed;
  final DateTime redeemedAt;
  final String status; // 'pending', 'claimed'
  final String redemptionCode;

  Redemption({
    this.id,
    required this.userId,
    this.userEmail = '',
    required this.rewardId,
    required this.rewardTitle,
    required this.pointsUsed,
    required this.redeemedAt,
    this.status = 'pending',
    required this.redemptionCode,
  });

  // FIX 9: Expiry is always redeemedAt + 7 days (computed, not stored)
  DateTime get expiresAt => redeemedAt.add(const Duration(days: 7));

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userEmail': userEmail,
        'rewardId': rewardId,
        'rewardTitle': rewardTitle,
        'pointsUsed': pointsUsed,
        'redeemedAt': Timestamp.fromDate(redeemedAt.toUtc()),
        'status': status,
        'redemptionCode': redemptionCode,
      };

  factory Redemption.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Redemption(
      id: doc.id,
      userId: d['userId'] ?? '',
      userEmail: d['userEmail'] ?? '',
      rewardId: d['rewardId'] ?? '',
      rewardTitle: d['rewardTitle'] ?? '',
      pointsUsed: d['pointsUsed'] ?? 0,
      redeemedAt: _tsToDateTime(d['redeemedAt']),
      status: d['status'] ?? 'pending',
      redemptionCode: d['redemptionCode'] ?? '',
    );
  }
}

// H-13: public leaderboard profile — no email, no role, no private fields
class ProfileModel {
  final String uid;
  final String username;
  final int points;
  final int lifetimePoints;
  final List<String> badges;

  ProfileModel({
    required this.uid,
    required this.username,
    this.points = 0,
    int? lifetimePoints,
    this.badges = const [],
  }) : lifetimePoints = lifetimePoints ?? points;

  Map<String, dynamic> toMap() => {
        'username': username,
        'points': points,
        'lifetimePoints': lifetimePoints,
        'badges': badges,
      };

  factory ProfileModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProfileModel(
      uid: doc.id,
      username: d['username'] ?? '',
      points: d['points'] ?? 0,
      lifetimePoints: d['lifetimePoints'] as int?,
      badges: List<String>.from(d['badges'] ?? []),
    );
  }

  factory ProfileModel.fromUser(UserModel user) => ProfileModel(
        uid: user.uid,
        username: user.username,
        points: user.points,
        lifetimePoints: user.lifetimePoints,
        badges: user.badges,
      );
}

/// One bin compartment as the kiosk last reported it (`bins/{kioskId}-{bio|rec|res}`, written by app.py).
class BinStatus {
  final String id;
  final String location;
  final int fillLevel;
  final String status;          // 'online' | 'offline'
  final DateTime? lastUpdated;
  const BinStatus({required this.id, required this.location, required this.fillLevel, required this.status,
      this.lastUpdated});

  factory BinStatus.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    return BinStatus(
      id: doc.id,
      location: d['location'] as String? ?? doc.id,
      fillLevel: (d['fillLevel'] as num?)?.round().clamp(0, 100) ?? 0,
      status: d['status'] as String? ?? 'offline',
      lastUpdated: firestoreTime(d['lastUpdated']),
    );
  }
}

/// What the staff dashboard can honestly say about the bins: no reading is ever invented, and an
/// old or offline reading is shown with its age. The kiosk refreshes every 5 minutes while running.
typedef BinsReport = ({String value, String detail, double? level, bool stale});

BinsReport describeBins(List<BinStatus>? bins, DateTime now) {
  if (bins == null) return (value: '—', detail: 'Could not load bin status', level: null, stale: true);
  if (bins.isEmpty) return (value: '—', detail: 'No kiosk has reported yet', level: null, stale: true);
  final fullest = bins.reduce((a, b) => b.fillLevel > a.fillLevel ? b : a);
  DateTime? newest;
  for (final t in bins.map((b) => b.lastUpdated).whereType<DateTime>()) {
    if (newest == null || t.isAfter(newest)) newest = t;
  }
  final age = newest == null ? null : now.difference(newest);
  final stale = age == null || age > const Duration(minutes: 10) || bins.every((b) => b.status != 'online');
  return (
    value: '${fullest.fillLevel}%',
    detail: stale ? 'Last report ${_ago(age)}' : '${fullest.location} · ${_ago(age)}',
    level: fullest.fillLevel / 100,
    stale: stale,
  );
}

String _ago(Duration? d) {
  if (d == null) return 'time unknown';
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}
