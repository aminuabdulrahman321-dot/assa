import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String userId; // recipient uid
  final String title;
  final String body;
  final String type; // booking | arrival | approval | rejection | general
  final bool read;
  final String? bookingId; // optional reference
  final String? routeId;   // optional reference
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.read = false,
    this.bookingId,
    this.routeId,
    required this.createdAt,
  });

  // ── From Firestore ─────────────────────────────────────────────────
  factory NotificationModel.fromMap(
      Map<String, dynamic> map, String notificationId) {
    return NotificationModel(
      notificationId: notificationId,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'general',
      read: map['read'] ?? false,
      bookingId: map['bookingId'],
      routeId: map['routeId'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory NotificationModel.fromDocument(DocumentSnapshot doc) {
    return NotificationModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  // ── To Firestore ───────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'read': read,
      'bookingId': bookingId,
      'routeId': routeId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ── Copy With ──────────────────────────────────────────────────────
  NotificationModel copyWith({
    String? notificationId,
    String? userId,
    String? title,
    String? body,
    String? type,
    bool? read,
    String? bookingId,
    String? routeId,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      read: read ?? this.read,
      bookingId: bookingId ?? this.bookingId,
      routeId: routeId ?? this.routeId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ── Notification Type Helpers ──────────────────────────────────────
  bool get isBookingNotification => type == 'booking';
  bool get isArrivalNotification => type == 'arrival';
  bool get isApprovalNotification => type == 'approval';
  bool get isRejectionNotification => type == 'rejection';
  bool get isUnread => !read;

  @override
  String toString() =>
      'NotificationModel(id: $notificationId, title: $title, type: $type, read: $read)';
}