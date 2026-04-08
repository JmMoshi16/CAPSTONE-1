import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  String username;
  String email;
  final String role; // 'customer' or 'admin'
  int points;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.role,
    this.points = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'username': username,
        'email': email,
        'role': role,
        'points': points,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      username: d['username'] ?? '',
      email: d['email'] ?? '',
      role: d['role'] ?? 'customer',
      points: d['points'] ?? 0,
      createdAt: DateTime.tryParse(d['createdAt'] ?? '') ?? DateTime.now(),
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
        'timestamp': timestamp.toIso8601String(),
        'binId': binId,
      };

  factory WasteLog.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WasteLog(
      id: doc.id,
      userId: d['userId'] ?? '',
      wasteType: d['wasteType'] ?? '',
      pointsEarned: d['pointsEarned'] ?? 0,
      timestamp: DateTime.tryParse(d['timestamp'] ?? '') ?? DateTime.now(),
      binId: d['binId'] ?? '',
    );
  }
}

class Reward {
  final String? id;
  final String title;
  final String description;
  final int pointsCost;
  final String category; // 'Coffee', 'Food', 'Discount', 'Other'
  final bool isActive;

  Reward({
    this.id,
    required this.title,
    required this.description,
    required this.pointsCost,
    required this.category,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'pointsCost': pointsCost,
        'category': category,
        'isActive': isActive,
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

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userEmail': userEmail,
        'rewardId': rewardId,
        'rewardTitle': rewardTitle,
        'pointsUsed': pointsUsed,
        'redeemedAt': redeemedAt.toIso8601String(),
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
      redeemedAt: DateTime.tryParse(d['redeemedAt'] ?? '') ?? DateTime.now(),
      status: d['status'] ?? 'pending',
      redemptionCode: d['redemptionCode'] ?? '',
    );
  }
}
