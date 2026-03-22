import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/user_model.dart';
import '../models/driver_model.dart';
import '../models/admin_model.dart';
import '../models/booking_model.dart';
import '../models/route_model.dart';
import '../models/notification_model.dart';
import 'esp32_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ======================================================================
  // USER OPERATIONS
  // ======================================================================

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromDocument(doc);
    } catch (_) {
      return null;
    }
  }

  Future<DriverModel?> getDriver(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return DriverModel.fromDocument(doc);
    } catch (_) {
      return null;
    }
  }

  Future<AdminModel?> getAdmin(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return AdminModel.fromDocument(doc);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Stream<DocumentSnapshot> userStream(String uid) =>
      _db.collection('users').doc(uid).snapshots();

  Stream<List<UserModel>> getAllUsers() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'user')
        .snapshots()
        .map((s) => s.docs.map((d) => UserModel.fromDocument(d)).toList());
  }

  // ======================================================================
  // DRIVER OPERATIONS
  // ======================================================================

  Stream<List<DriverModel>> getAllDrivers() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .snapshots()
        .map((s) => s.docs.map((d) => DriverModel.fromDocument(d)).toList());
  }

  Stream<List<DriverModel>> getPendingDrivers() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => DriverModel.fromDocument(d)).toList());
  }

  Stream<List<DriverModel>> getApprovedDrivers() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((s) => s.docs.map((d) => DriverModel.fromDocument(d)).toList());
  }

  Stream<List<DriverModel>> getRejectedDrivers() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('status', isEqualTo: 'rejected')
        .snapshots()
        .map((s) => s.docs.map((d) => DriverModel.fromDocument(d)).toList());
  }

  Future<bool> approveDriver({
    required String driverUid,
    required String approvedByUid,
  }) async {
    try {
      await _db.collection('users').doc(driverUid).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': approvedByUid,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectDriver({
    required String driverUid,
    required String rejectedByUid,
  }) async {
    try {
      await _db.collection('users').doc(driverUid).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': rejectedByUid,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ======================================================================
  // ROUTE OPERATIONS
  // ======================================================================

  Future<bool> createRoute(RouteModel route) async {
    try {
      await _db.collection('routes').doc(route.routeId).set(route.toMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateRoute({
    required String routeId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _db.collection('routes').doc(routeId).update(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteRoute(String routeId) async {
    try {
      await _db.collection('routes').doc(routeId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<RouteModel>> getActiveRoutes() {
    return _db
        .collection('routes')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => RouteModel.fromDocument(d)).toList());
  }

  Stream<List<RouteModel>> getAllRoutes() {
    return _db.collection('routes').snapshots().map((s) {
      final list = s.docs.map((d) => RouteModel.fromDocument(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<RouteModel?> getDriverRoute(String driverId) {
    return _db
        .collection('routes')
        .where('driverId', isEqualTo: driverId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((s) =>
    s.docs.isEmpty ? null : RouteModel.fromDocument(s.docs.first));
  }

  String generateRouteId() => _uuid.v4();

  // ======================================================================
  // RIDE REQUEST / BOOKING OPERATIONS
  // ======================================================================

  Future<Map<String, dynamic>> createBooking(BookingModel booking) async {
    try {
      await _db
          .collection('ride_requests')
          .doc(booking.bookingId)
          .set(booking.toMap());
      return {'success': true, 'bookingId': booking.bookingId};
    } catch (_) {
      return {'success': false, 'error': 'Failed to create booking.'};
    }
  }

  Future<bool> cancelBooking({
    required String bookingId,
    required String routeId,
  }) async {
    try {
      await _db.collection('ride_requests').doc(bookingId).update({
        'status': 5,
        'statusName': 'Cancelled',
      });
      if (routeId.isNotEmpty) {
        await _db.collection('routes').doc(routeId).update({
          'availableSeats': FieldValue.increment(1),
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<Map<String, dynamic>?> getRideStatusStream(String bookingId) {
    return _db
        .collection('ride_requests')
        .doc(bookingId)
        .snapshots()
        .map((doc) => doc.exists ? {'id': doc.id, ...doc.data()!} : null);
  }

  Stream<List<BookingModel>> getUserBookings(String userId) {
    return _db
        .collection('ride_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) {
      final list =
      s.docs.map((d) => BookingModel.fromDocument(d)).toList();
      list.sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> getAllRequestsStream() {
    return _db.collection('ride_requests').snapshots().map((s) {
      final list = s.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
      list.sort((a, b) {
        final at = a['timestamp'];
        final bt = b['timestamp'];
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return (bt as Timestamp).compareTo(at as Timestamp);
      });
      return list;
    });
  }

  Stream<List<BookingModel>> getAllBookings() {
    return _db.collection('ride_requests').snapshots().map((s) {
      final list =
      s.docs.map((d) => BookingModel.fromDocument(d)).toList();
      list.sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
      return list;
    });
  }

  String generateBookingId() => _uuid.v4();

  Future<bool> submitOnlineRequest({
    required String userId,
    required String userName,
    required String onlineUUID,
    required String pickupLocation,
    required String destination,
    required String rideType,
    int passengerCount = 1,
  }) async {
    for (int _attempt = 1; _attempt <= 3; _attempt++) {
      try {
        final id = _uuid.v4();
        final pickupCode = Esp32Service.getLocationCode(pickupLocation);
        final destCode = Esp32Service.getLocationCode(destination);
        final rideCode = Esp32Service.getRideTypeCode(rideType);

        final userSnap = await _db.collection('users').doc(userId).get();
        final pickupId = (userSnap.data()?['pickupId'] as String?) ?? '';

        await _db.collection('ride_requests').doc(id).set({
          'pickupId': pickupId,
          'pickup_code': pickupCode,
          'destination_code': destCode,
          'ride_type': rideCode,
          'pax': passengerCount,
          'status': 0,
          'shuttle_id': 0,
          'timestamp': FieldValue.serverTimestamp(),
          'requestType': 'online',
          'isSynced': true,
          'assignedAt': null,
          'gatewayId': '',
          'bookingId': id,
          'userId': userId,
          'userName': userName,
          'onlineUUID': onlineUUID,
          'pickupLocation': pickupLocation,
          'destination': destination,
          'rideTypeName': rideType,
          'statusName': 'Pending',
          'passengerCount': passengerCount,
          'bookedAt': FieldValue.serverTimestamp(),
        });
        return true;
      } catch (e) {
        if (_attempt == 3) return false;
        await Future.delayed(Duration(milliseconds: 500 * _attempt));
      }
    }
    return false;
  }

  Future<bool> submitOfflineRequest({
    required String userId,
    required String userName,
    required String offlineUUID,
    required String pickupLocation,
    required String destination,
    required String rideType,
    int passengerCount = 1,
  }) async {
    for (int _attempt = 1; _attempt <= 3; _attempt++) {
      try {
        final id = _uuid.v4();
        final pickupCode = Esp32Service.getLocationCode(pickupLocation);
        final destCode = Esp32Service.getLocationCode(destination);
        final rideCode = Esp32Service.getRideTypeCode(rideType);

        final userSnap = await _db.collection('users').doc(userId).get();
        final pickupId = (userSnap.data()?['pickupId'] as String?) ?? '';

        final data = {
          'pickupId': pickupId,
          'pickup_code': pickupCode,
          'destination_code': destCode,
          'ride_type': rideCode,
          'pax': passengerCount,
          'status': 0,
          'shuttle_id': 0,
          'timestamp': FieldValue.serverTimestamp(),
          'requestType': 'offline',
          'isSynced': false,
          'assignedAt': null,
          'gatewayId': '',
          'bookingId': id,
          'userId': userId,
          'userName': userName,
          'offlineUUID': offlineUUID,
          'pickupLocation': pickupLocation,
          'destination': destination,
          'rideTypeName': rideType,
          'statusName': 'Pending',
          'passengerCount': passengerCount,
          'bookedAt': FieldValue.serverTimestamp(),
        };

        await _db.collection('ride_requests').doc(id).set(data);
        await _db.collection('offline_requests').doc(id).set({
          ...data,
          'requestId': id,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      } catch (e) {
        if (_attempt == 3) return false;
        await Future.delayed(Duration(milliseconds: 500 * _attempt));
      }
    }
    return false;
  }

  Future<bool> updateOfflineRequestFeedback({
    required String offlineUUID,
    required String shuttleId,
  }) async {
    try {
      final q = await _db
          .collection('ride_requests')
          .where('offlineUUID', isEqualTo: offlineUUID)
          .where('requestType', isEqualTo: 'offline')
          .where('status', isEqualTo: 0)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return false;
      final docId = q.docs.first.id;
      final shuttleIdInt = int.tryParse(shuttleId) ?? 0;
      final update = {
        'shuttleIdFeedback': shuttleId,
        'shuttle_id': shuttleIdInt,
        'status': 1,
        'statusName': 'Assigned',
        'isSynced': true,
      };
      await _db.collection('ride_requests').doc(docId).update(update);
      await _db.collection('offline_requests').doc(docId).update(update);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncOfflineRequests() async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final q = await _db
            .collection('ride_requests')
            .where('requestType', isEqualTo: 'offline')
            .where('isSynced', isEqualTo: false)
            .get();
        if (q.docs.isEmpty) return;
        final batch = _db.batch();
        for (final doc in q.docs) {
          batch.update(doc.reference, {
            'isSynced': true,
            'syncedAt': FieldValue.serverTimestamp(),
          });
          final offlineRef = _db.collection('offline_requests').doc(doc.id);
          batch.update(offlineRef, {
            'isSynced': true,
            'syncedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        return;
      } catch (_) {
        if (attempt == 3) return;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  Future<void> cleanOldPuzzleScores() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 28));
      final q = await _db.collection('puzzle_scores')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
          .get();
      if (q.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in q.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  // ======================================================================
  // NOTIFICATION OPERATIONS
  // ======================================================================

  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) {
      final list =
      s.docs.map((d) => NotificationModel.fromDocument(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(50).toList();
    });
  }

  Future<bool> markNotificationRead(String notificationId) async {
    try {
      await _db
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllNotificationsRead(String userId) async {
    try {
      final batch = _db.batch();
      final snap = await _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  String generateNotificationId() => _uuid.v4();

  // ======================================================================
  // ADS OPERATIONS
  // ======================================================================

  Stream<List<Map<String, dynamic>>> getActiveAds() {
    return _db
        .collection('ads')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) {
      final list =
      s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) {
        final at = a['createdAt'];
        final bt = b['createdAt'];
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return (bt as Timestamp).compareTo(at as Timestamp);
      });
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> getAllAds() {
    return _db.collection('ads').snapshots().map((s) {
      final list =
      s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) {
        final at = a['createdAt'];
        final bt = b['createdAt'];
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return (bt as Timestamp).compareTo(at as Timestamp);
      });
      return list;
    });
  }

  Future<bool> createAd({
    required String title,
    String body = '',
    required String imageUrl,
    required String linkUrl,
    required String createdBy,
  }) async {
    try {
      final adId = _uuid.v4();
      await _db.collection('ads').doc(adId).set({
        'adId': adId,
        'title': title,
        'body': body,
        'imageUrl': imageUrl,
        'linkUrl': linkUrl,
        'isActive':    true,
        'impressions': 0,
        'taps':        0,
        'createdBy':   createdBy,
        'createdAt':   FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleAdStatus(String adId, bool isActive) async {
    try {
      await _db.collection('ads').doc(adId).update({'isActive': isActive});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAd(String adId) async {
    try {
      await _db.collection('ads').doc(adId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ======================================================================
  // LOCATIONS OPERATIONS
  // ======================================================================

  Stream<List<String>>? _locationsStreamCache;

  Stream<List<String>> getLocationsStream() {
    _locationsStreamCache ??= _db
        .collection('settings')
        .doc('locations')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <String>[];
      final data = doc.data();
      if (data == null) return <String>[];
      final list = data['list'];
      if (list is List) return list.cast<String>();
      return <String>[];
    })
        .asBroadcastStream();
    return _locationsStreamCache!;
  }

  Future<List<String>> getLocations() async {
    return Esp32Service.allLocations;
  }

  Future<bool> addLocation(String locationName) async {
    try {
      final ref = _db.collection('settings').doc('locations');
      final doc = await ref.get();
      if (doc.exists) {
        await ref.update({'list': FieldValue.arrayUnion([locationName])});
      } else {
        await ref.set({'list': [locationName]});
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeLocation(String locationName) async {
    try {
      await _db.collection('settings').doc('locations').update({
        'list': FieldValue.arrayRemove([locationName]),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ======================================================================
  // REPORTS OPERATIONS
  // ======================================================================

  Future<bool> submitReport({
    required String reportedBy,
    required String reporterName,
    required String reporterRole,
    required String shuttleId,
    required String category,
    required String description,
  }) async {
    try {
      final id = _uuid.v4();
      await _db.collection('reports').doc(id).set({
        'reportId': id,
        'reportedBy': reportedBy,
        'reporterName': reporterName,
        'reporterRole': reporterRole,
        'shuttleId': shuttleId,
        'category': category,
        'description': description,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ======================================================================
  // DATA EXPORT / ANALYTICS
  // ======================================================================

  Future<Map<String, dynamic>> getAnalyticsData() async {
    try {
      final results = await Future.wait([
        _db.collection('users').where('role', isEqualTo: 'user').count().get(),
        _db.collection('users').where('role', isEqualTo: 'driver').where(
            'status', isEqualTo: 'approved').count().get(),
        _db.collection('ride_requests').count().get(),
        _db.collection('routes').where('isActive', isEqualTo: true).count().get(),
        _db.collection('users').where('role', isEqualTo: 'driver').where(
            'status', isEqualTo: 'pending').count().get(),
      ]);
      return {
        'totalUsers': results[0].count ?? 0,
        'totalDrivers': results[1].count ?? 0,
        'totalBookings': results[2].count ?? 0,
        'activeRoutes': results[3].count ?? 0,
        'pendingDrivers': results[4].count ?? 0,
      };
    } catch (_) {
      try {
        final snaps = await Future.wait([
          _db.collection('users').where('role', isEqualTo: 'user').get(),
          _db.collection('users').where('role', isEqualTo: 'driver').where(
              'status', isEqualTo: 'approved').get(),
          _db.collection('ride_requests').get(),
          _db.collection('routes').where('isActive', isEqualTo: true).get(),
          _db.collection('users').where('role', isEqualTo: 'driver').where(
              'status', isEqualTo: 'pending').get(),
        ]);
        return {
          'totalUsers': snaps[0].docs.length,
          'totalDrivers': snaps[1].docs.length,
          'totalBookings': snaps[2].docs.length,
          'activeRoutes': snaps[3].docs.length,
          'pendingDrivers': snaps[4].docs.length,
        };
      } catch (_) {
        return {
          'totalUsers': 0, 'totalDrivers': 0,
          'totalBookings': 0, 'activeRoutes': 0, 'pendingDrivers': 0,
        };
      }
    }
  }

  Map<String, dynamic> _cleanForExport(Map<String, dynamic> data) {
    final clean = <String, dynamic>{};
    data.forEach((k, v) {
      if (v is Timestamp) {
        clean[k] = v.toDate().toIso8601String();
      } else if (v is Map) {
        clean[k] = v.toString();
      } else if (v != null) {
        clean[k] = v;
      }
    });
    return clean;
  }

  Future<List<Map<String, dynamic>>> exportBookingsData() async {
    final snap = await _db.collection('ride_requests').get();
    final list = snap.docs.map((d) => _cleanForExport(d.data())).toList();
    list.sort((a, b) {
      final at = a['timestamp']?.toString() ?? '';
      final bt = b['timestamp']?.toString() ?? '';
      return bt.compareTo(at);
    });
    return list;
  }

  Future<List<Map<String, dynamic>>> exportUsersData() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'user')
        .get();
    return snap.docs.map((d) {
      final data = _cleanForExport(d.data());
      data.remove('offlineUUID');
      data.remove('onlineUUID');
      return data;
    }).toList();
  }

  // ======================================================================
  // PUZZLE SCORES
  // ======================================================================

  Future<bool> hasPlayedPuzzle(String uid, String weekId) async {
    try {
      final doc = await _db.collection('puzzle_scores').doc('${uid}_$weekId').get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Future<int?> getUserLeaderboardScore(String uid, String period) async {
    try {
      final snap = await _db
          .collection('puzzle_scores')
          .where('userId', isEqualTo: uid)
          .where(period.contains('W') ? 'weekKey' : 'monthKey', isEqualTo: period)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs
          .map((d) => (d.data()['score'] as num?)?.toInt() ?? 0)
          .reduce((a, b) => a > b ? a : b);
    } catch (_) {
      return null;
    }
  }

  Future<bool> savePuzzleImageDoc({
    required String imageUrl,
    required String title,
    required int gridSize,
    required String weekKey,
    required String uploadedBy,
  }) async {
    try {
      final existing = await _db
          .collection('puzzle_images')
          .where('gridSize', isEqualTo: gridSize)
          .where('isActive', isEqualTo: true)
          .get();
      final batch = _db.batch();
      for (final doc in existing.docs) {
        batch.update(doc.reference, {'isActive': false});
      }
      final newRef = _db.collection('puzzle_images').doc();
      batch.set(newRef, {
        'imageId': newRef.id,
        'imageUrl': imageUrl,
        'title': title,
        'gridSize': gridSize,
        'gridLabel': '${gridSize}x$gridSize',
        'weekKey': weekKey,
        'isActive': true,
        'uploadedBy': uploadedBy,
        'uploadedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ======================================================================
  // LOST & FOUND
  // ======================================================================

  Stream<List<Map<String, dynamic>>> getActiveLostFoundItems() {
    return _db.collection('lost_found')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) {
        final at = a['createdAt'];
        final bt = b['createdAt'];
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return (bt as Timestamp).compareTo(at as Timestamp);
      });
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> getUserLostFoundItems(String uid) {
    return _db.collection('lost_found')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) {
        final at = a['createdAt'];
        final bt = b['createdAt'];
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return (bt as Timestamp).compareTo(at as Timestamp);
      });
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> getAllLostFoundItems() {
    return _db.collection('lost_found').snapshots().map((s) {
      final list = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) {
        final at = a['createdAt'];
        final bt = b['createdAt'];
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return (bt as Timestamp).compareTo(at as Timestamp);
      });
      return list;
    });
  }

  Future<bool> deleteLostFoundItem(String docId) async {
    try {
      await _db.collection('lost_found').doc(docId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> adminForceCloseLostFound(String docId) async {
    try {
      await _db.collection('lost_found').doc(docId).update({
        'isActive': false,
        'status': 'Recovered',
        'closedBy': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> exportDriversData() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .get();
    return snap.docs.map((d) => _cleanForExport(d.data())).toList();
  }
}