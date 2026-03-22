import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String bookingId;
  final String userId;
  final String userName;
  final String userMatric;
  final String driverId;
  final String driverName;
  final String routeId;
  final String routeName;
  final String origin;
  final String destination;
  final int seatNumber;
  final String status; // pending | confirmed | cancelled
  final DateTime departureTime;
  final DateTime bookedAt;
  final bool notified;
  final bool isSyncedOnline; // tracks if queued offline booking has synced

  BookingModel({
    required this.bookingId,
    required this.userId,
    required this.userName,
    this.userMatric = '',
    required this.driverId,
    this.driverName = '',
    required this.routeId,
    this.routeName = '',
    this.origin = '',
    this.destination = '',
    required this.seatNumber,
    this.status = 'pending',
    required this.departureTime,
    required this.bookedAt,
    this.notified = false,
    this.isSyncedOnline = true,
  });

  // ── From Firestore ─────────────────────────────────────────────────
  factory BookingModel.fromMap(Map<String, dynamic> map, String bookingId) {
    return BookingModel(
      bookingId: bookingId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userMatric: map['userMatric'] ?? '',
      driverId: map['driverId'] ?? '',
      driverName: map['driverName'] ?? '',
      routeId: map['routeId'] ?? '',
      routeName: map['routeName'] ?? '',
      origin: map['origin'] ?? '',
      destination: map['destination'] ?? '',
      seatNumber: map['seatNumber'] ?? 0,
      status: map['status'] ?? 'pending',
      departureTime: map['departureTime'] != null
          ? (map['departureTime'] as Timestamp).toDate()
          : DateTime.now(),
      bookedAt: map['bookedAt'] != null
          ? (map['bookedAt'] as Timestamp).toDate()
          : DateTime.now(),
      notified: map['notified'] ?? false,
      isSyncedOnline: map['isSyncedOnline'] ?? true,
    );
  }

  factory BookingModel.fromDocument(DocumentSnapshot doc) {
    return BookingModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  // ── To Firestore ───────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'userId': userId,
      'userName': userName,
      'userMatric': userMatric,
      'driverId': driverId,
      'driverName': driverName,
      'routeId': routeId,
      'routeName': routeName,
      'origin': origin,
      'destination': destination,
      'seatNumber': seatNumber,
      'status': status,
      'departureTime': Timestamp.fromDate(departureTime),
      'bookedAt': Timestamp.fromDate(bookedAt),
      'notified': notified,
      'isSyncedOnline': isSyncedOnline,
    };
  }

  // ── Copy With ──────────────────────────────────────────────────────
  BookingModel copyWith({
    String? bookingId,
    String? userId,
    String? userName,
    String? userMatric,
    String? driverId,
    String? driverName,
    String? routeId,
    String? routeName,
    String? origin,
    String? destination,
    int? seatNumber,
    String? status,
    DateTime? departureTime,
    DateTime? bookedAt,
    bool? notified,
    bool? isSyncedOnline,
  }) {
    return BookingModel(
      bookingId: bookingId ?? this.bookingId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userMatric: userMatric ?? this.userMatric,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      seatNumber: seatNumber ?? this.seatNumber,
      status: status ?? this.status,
      departureTime: departureTime ?? this.departureTime,
      bookedAt: bookedAt ?? this.bookedAt,
      notified: notified ?? this.notified,
      isSyncedOnline: isSyncedOnline ?? this.isSyncedOnline,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────
  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get isUpcoming => departureTime.isAfter(DateTime.now());
  bool get isPast => departureTime.isBefore(DateTime.now());

  @override
  String toString() =>
      'BookingModel(bookingId: $bookingId, userId: $userId, routeId: $routeId, status: $status)';
}