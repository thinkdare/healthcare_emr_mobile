// lib/core/notifications/push_notification_service.dart
//
// Handles all push notification concerns:
//   - Firebase initialization (graceful no-op if unconfigured)
//   - FCM token retrieval and registration with the backend
//   - Foreground message display via flutter_local_notifications
//   - Notification tap routing to the correct screen

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Called from main() — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the plugin in background isolates.
  // Nothing else is needed here — the OS handles showing the notification.
}

class PushNotificationService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  // High-importance Android channel for clinical alerts.
  static const _androidChannel = AndroidNotificationChannel(
    'voya_clinical',
    'Clinical Notifications',
    description: 'Access grants, consultations, patient messages',
    importance: Importance.high,
  );

  // Stream that emits notification data when the user taps a notification
  // while the app is in the foreground or opened from background.
  final _tapController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap => _tapController.stream;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Firebase not configured (placeholder credentials) — notifications disabled.
      debugPrint('PushNotificationService: Firebase not configured — $e');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await _setupLocalNotifications();
    await _requestPermission();
    _listenForeground();
    _listenTaps();

    _initialized = true;
  }

  // ── Token ─────────────────────────────────────────────────────────────────

  /// Returns the current FCM token, or null if not available.
  Future<String?> getToken() async {
    if (!_initialized) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Call after login to register the token with the backend.
  /// Call with the token value to unregister on logout.
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  // ── Private setup ─────────────────────────────────────────────────────────

  Future<void> _setupLocalNotifications() async {
    // Create the high-importance Android channel
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false, // requested separately via FCM
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (details) {
        _handleTapPayload(details.payload);
      },
    );

    // Check if the app was opened from a terminated-state notification
    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _handleTapPayload(launchDetails!.notificationResponse?.payload);
    }
  }

  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
        'PushNotificationService: permission ${settings.authorizationStatus}');
  }

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: _encodePayload(message.data),
      );
    });
  }

  void _listenTaps() {
    // App opened from background via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _tapController.add(message.data);
    });

    // App opened from terminated state via notification tap
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _tapController.add(message.data);
    });
  }

  void _handleTapPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      // Simple key=value pairs separated by '&'
      final data = Map.fromEntries(
        payload.split('&').map((pair) {
          final parts = pair.split('=');
          return MapEntry(
              parts[0], parts.length > 1 ? Uri.decodeComponent(parts[1]) : '');
        }),
      );
      _tapController.add(data);
    } catch (_) {}
  }

  String _encodePayload(Map<String, dynamic> data) {
    return data.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
  }

  void dispose() {
    _tapController.close();
  }
}
