import 'package:cloud_firestore/cloud_firestore.dart';

// H-07: tolerant reader for timestamp fields — handles Firestore Timestamp and ISO string fallback
DateTime _tsToDateTime(dynamic v) {
  if (v is Timestamp) return v.toDate().toUtc();
  if (v is String) return DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc();
  return DateTime.now().toUtc();
}

class UserModel {
  final String uid;
  String username;
  String email;
  final String role;
  int points;
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
    required this.createdAt,
    this.scanCount = 0,
    this.streak = 0,
    this.lastScanDate,
    this.badges = const [],
  });

  Map<String, dynamic> toMap() => {
        'username': username,
        'email': email,
        'role': role,
        'points': points,
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
  final int pointsEarned;
  final DateTime timestamp;
  final String binId;

  WasteLog({
    this.id,
    required this.userId,
    required this.wasteType,
    required this.pointsEarned,
    required this.timestamp,
    required this.binId,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'wasteType': wasteType,
        'pointsEarned': pointsEarned,
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
