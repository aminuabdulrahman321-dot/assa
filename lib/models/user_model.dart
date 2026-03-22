import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String fcmToken;
  final DateTime createdAt;

  /// 3-character Pickup ID assigned at registration.
  /// Format: 1 uppercase letter + 2 digits  →  e.g. K47, T83, B12
  /// This is what the driver sees on the LCD to identify the passenger.
  /// Also shown on the user dashboard so they can tell the driver.
  final String pickupId;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.fcmToken = '',
    required this.createdAt,
    this.pickupId = '',
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid:      uid,
      name:     map['name']     ?? '',
      email:    map['email']    ?? '',
      role:     map['role']     ?? 'user',
      fcmToken: map['fcmToken'] ?? '',
      pickupId: map['pickupId'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory UserModel.fromDocument(DocumentSnapshot doc) {
    return UserModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid':       uid,
      'name':      name,
      'email':     email,
      'role':      role,
      'fcmToken':  fcmToken,
      'pickupId':  pickupId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String?   uid,
    String?   name,
    String?   email,
    String?   role,
    String?   fcmToken,
    String?   pickupId,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid:       uid       ?? this.uid,
      name:      name      ?? this.name,
      email:     email     ?? this.email,
      role:      role      ?? this.role,
      fcmToken:  fcmToken  ?? this.fcmToken,
      pickupId:  pickupId  ?? this.pickupId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isAdmin  => role == 'admin';
  bool get isDriver => role == 'driver';
  bool get isUser   => role == 'user';

  @override
  String toString() =>
      'UserModel(uid: $uid, name: $name, pickupId: $pickupId, role: $role)';
}