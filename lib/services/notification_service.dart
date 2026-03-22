import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ======================================================================
// NOTIFICATION SERVICE — FCM + Firestore
//
// • FCM delivers banners when app is killed / backgrounded
// • Firestore writes power the in-app bell badge
// • Both happen on every status change — no duplication to the user
//
// Usage:
//   main.dart          → await NotificationService.instance.initialize()
//   user_dashboard     → NotificationService.instance.attachRideListener(uid)
//   logout             → NotificationService.instance.detachRideListener()
// ======================================================================

// Top-level handler for background FCM messages (required by Firebase)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are shown automatically by FCM on Android.
  // No action needed here.
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  factory NotificationService() => instance;

  final _db  = FirebaseFirestore.instance;
  final _fcm = FirebaseMessaging.instance;
  final _localNotifs = FlutterLocalNotificationsPlugin();

  // Android notification channel
  static const _channelId   = 'assa_main';
  static const _channelName = 'ASSA Notifications';

  dynamic _rideStatusSub;

  // ── initialize() — call once in main.dart after Firebase.initializeApp ──
  Future<void> initialize() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS + Android 13+)
    await _fcm.requestPermission(
      alert:      true,
      badge:      true,
      sound:      true,
      provisional: false,
    );

    // Android local notification channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'ASSA ride updates and alerts',
      importance:  Importance.high,
    );

    await _localNotifs
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Init flutter_local_notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS:     DarwinInitializationSettings(),
    );
    await _localNotifs.initialize(initSettings);

    // Save FCM token to Firestore so admin can target this device
    await _saveFcmToken();

    // Refresh token whenever it rotates
    _fcm.onTokenRefresh.listen(_updateFcmToken);

    // Show local notification when app is in foreground
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifs.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId, _channelName,
            importance: Importance.high,
            priority:   Priority.high,
            icon:       '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });
  }

  // ── Save FCM token to users/{uid}/fcmToken ────────────────────────────
  Future<void> _saveFcmToken() async {
    try {
      final uid   = FirebaseAuth.instance.currentUser?.uid;
      final token = await _fcm.getToken();
      if (uid == null || token == null) return;
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (_) {}
  }

  Future<void> _updateFcmToken(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await _db.collection('users').doc(uid).update({'fcmToken': token});
    } catch (_) {}
  }

  // ── Write one notification doc to Firestore ───────────────────────────
  Future<void> _writeNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId':    userId,
        'title':     title,
        'body':      body,
        'type':      type,
        'read':      false,
        'createdAt': FieldValue.serverTimestamp(),
        ...extra,
      });
    } catch (_) {}
  }

  // ── Send FCM to a specific user via their stored token ────────────────
  // NOTE: Direct device-to-device FCM requires a backend / Cloud Function.
  // For now, notifications reach the user via Firestore (in-app bell).
  // The FCM token is stored and ready for when you add a Cloud Function.
  // ─────────────────────────────────────────────────────────────────────

  // ── Driver approval / rejection ───────────────────────────────────────
  Future<void> notifyDriverApproved({
    required String driverUid,
    required String driverName,
  }) async {
    await _writeNotification(
      userId: driverUid,
      title:  '✅ Application Approved',
      body:   'Congratulations $driverName! Your driver application has been '
          'approved. You can now log in and start accepting rides.',
      type:   'driver_approved',
    );
  }

  Future<void> notifyDriverRejected({
    required String driverUid,
    required String driverName,
  }) async {
    await _writeNotification(
      userId: driverUid,
      title:  '❌ Application Not Approved',
      body:   'Hi $driverName, your driver application was not approved at '
          'this time. Contact admin for more information.',
      type:   'driver_rejected',
    );
  }

  // ── Admin broadcasts ──────────────────────────────────────────────────
  Future<bool> broadcastToAllUsers({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    try {
      final users = await _db.collection('users').get();
      final batch = _db.batch();
      for (final u in users.docs) {
        final ref = _db.collection('notifications').doc();
        batch.set(ref, {
          'userId':    u.id,
          'title':     title,
          'body':      body,
          'type':      type,
          'read':      false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> broadcastToRole({
    required String role,
    required String title,
    required String body,
    String type = 'general',
  }) async {
    try {
      final users = await _db
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      final batch = _db.batch();
      for (final u in users.docs) {
        final ref = _db.collection('notifications').doc();
        batch.set(ref, {
          'userId':    u.id,
          'title':     title,
          'body':      body,
          'type':      type,
          'read':      false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Ride status listener ──────────────────────────────────────────────
  void attachRideListener(String userId) {
    _rideStatusSub?.cancel();
    _rideStatusSub = _db
        .collection('ride_requests')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: [1, 2, 3, 4, 5])
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.modified) continue;
        final data   = change.doc.data() as Map<String, dynamic>? ?? {};
        final status = data['status'] as int? ?? 0;
        final pickup = data['pickupLocation'] ??
            data['origin'] ?? 'your location';
        final dest   = data['destination'] ?? 'destination';
        String? title, body;

        switch (status) {
          case 1:
            final shuttle =
            (data['shuttleIdFeedback']?.toString() ?? '').isNotEmpty
                ? data['shuttleIdFeedback'] : 'A shuttle';
            title = '🚌 Shuttle Assigned';
            body  = '$shuttle has been assigned to your request from $pickup.';
            break;
          case 2:
            title = '🟢 Shuttle Arriving!';
            body  = 'Your shuttle is on its way to $pickup. Please be ready!';
            break;
          case 3:
            title = '✅ Picked Up';
            body  = "You've been picked up. Heading to $dest. Have a safe ride!";
            break;
          case 4:
            title = '🏁 Ride Completed';
            body  = 'Your ride to $dest is complete. Thank you for using ASSA!';
            break;
          case 5:
            title = '❌ Ride Cancelled';
            body  = 'Your shuttle request from $pickup has been cancelled.';
            break;
        }

        if (title != null && body != null) {
          _writeNotification(
            userId: userId,
            title:  title,
            body:   body,
            type:   'ride_status',
            extra:  {'statusCode': status},
          );
        }
      }
    });
  }

  void detachRideListener() {
    _rideStatusSub?.cancel();
    _rideStatusSub = null;
  }
}