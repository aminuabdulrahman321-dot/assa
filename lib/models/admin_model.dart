import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String fcmToken;
  final String? createdBy; // uid of admin who created this admin (null = seeded)
  final DateTime createdAt;

  AdminModel({
    required this.uid,
    required this.name,
    required this.email,
    this.role = 'admin',
    this.fcmToken = '',
    this.createdBy,
    required this.createdAt,
  });

  // ── From Firestore ─────────────────────────────────────────────────
  factory AdminModel.fromMap(Map<String, dynamic> map, String uid) {
    return AdminModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'admin',
      fcmToken: map['fcmToken'] ?? '',
      createdBy: map['createdBy'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory AdminModel.fromDocument(DocumentSnapshot doc) {
    return AdminModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  // ── To Firestore ───────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'fcmToken': fcmToken,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ── Copy With ──────────────────────────────────────────────────────
  AdminModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    String? fcmToken,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return AdminModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      fcmToken: fcmToken ?? this.fcmToken,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────
  bool get isSeeded => createdBy == null;

  @override
  String toString() =>
      'AdminModel(uid: $uid, name: $name, email: $email)';
}