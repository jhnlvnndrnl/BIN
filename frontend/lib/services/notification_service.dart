// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Background Handler MUST be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📨 Background message received: ${message.messageId}');
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // name
    description: 'This channel is used for critical flood and report alerts.',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    debugPrint("🔔 Initializing NotificationService...");

    // 1. Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Request Permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('✅ Permission status: ${settings.authorizationStatus}');

    // 3. Setup Local Notifications for Foreground display
    if (!kIsWeb) {
      await _localNotifs
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      // Note: '@mipmap/ic_launcher' must exist in your android/app/src/main/res/ folders
      const initSettingsAndroid = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettingsDarwin = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: initSettingsAndroid,
        iOS: initSettingsDarwin,
      );

      await _localNotifs.initialize(initSettings);
    }

    // 4. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // 5. Handle Notification Taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 User tapped notification: ${message.notification?.title}');
    });

    // 6. Listen for token rotations from Google
    _fcm.onTokenRefresh.listen((newToken) {
      debugPrint("🔄 FCM token rotated natively: $newToken");
      syncFCMToken(newToken);
    });
  }

  static void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null && !kIsWeb) {
      _localNotifs.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFF4CAF50),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }

  /// Syncs the current or provided token to Supabase for the active user
  static Future<void> syncFCMToken([String? specificToken]) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      String? token = specificToken ?? await _fcm.getToken();

      if (token == null) {
        debugPrint("❌ Could not generate FCM token.");
        return;
      }

      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);

      debugPrint("✅ FCM token synced to Supabase: $token");
    } catch (e) {
      debugPrint("❌ Error syncing FCM token: $e");
    }
  }
}
