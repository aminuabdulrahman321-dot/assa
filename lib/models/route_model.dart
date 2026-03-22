import 'package:cloud_firestore/cloud_firestore.dart';

class RouteModel {
  final String routeId;
  final String routeName;
  final String origin;
  final String destination;
  final String driverId;
  final String driverName;
  final DateTime departureTime;
  final int totalSeats;
  final int availableSeats;
  final bool isActive;
  final DateTime createdAt;

  RouteModel({
    required this.routeId,
    required this.routeName,
    required this.origin,
    required this.destination,
    required this.driverId,
    this.driverName = '',
    required this.departureTime,
    required this.totalSeats,
    required this.availableSeats,
    this.isActive = true,
    required this.createdAt,
  });

  // ── From Firestore ─────────────────────────────────────────────────
  factory RouteModel.fromMap(Map<String, dynamic> map, String routeId) {
    return RouteModel(
      routeId: routeId,
      routeName: map['routeName'] ?? '',
      origin: map['origin'] ?? '',
      destination: map['destination'] ?? '',
      driverId: map['driverId'] ?? '',
      driverName: map['driverName'] ?? '',
      departureTime: map['departureTime'] != null
          ? (map['departureTime'] as Timestamp).toDate()
          : DateTime.now(),
      totalSeats: map['totalSeats'] ?? 0,
      availableSeats: map['availableSeats'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory RouteModel.fromDocument(DocumentSnapshot doc) {
    return RouteModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  // ── To Firestore ───────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'routeId': routeId,
      'routeName': routeName,
      'origin': origin,
      'destination': destination,
      'driverId': driverId,
      'driverName': driverName,
      'departureTime': Timestamp.fromDate(departureTime),
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ── Copy With ──────────────────────────────────────────────────────
  RouteModel copyWith({
    String? routeId,
    String? routeName,
    String? origin,
    String? destination,
    String? driverId,
    String? driverName,
    DateTime? departureTime,
    int? totalSeats,
    int? availableSeats,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return RouteModel(
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      departureTime: departureTime ?? this.departureTime,
      totalSeats: totalSeats ?? this.totalSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────
  bool get isFullyBooked => availableSeats <= 0;
  bool get hasSeats => availableSeats > 0;
  double get occupancyRate =>
      totalSeats > 0 ? (totalSeats - availableSeats) / totalSeats : 0;

  @override
  String toString() =>
      'RouteModel(routeId: $routeId, routeName: $routeName, origin: $origin, destination: $destination)';
}