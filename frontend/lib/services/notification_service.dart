import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static BuildContext? _context;

  // Set context from main.dart
  static void setContext(BuildContext context) {
    _context = context;
  }

  static Future<void> initialize() async {
    print("🔔 Initializing NotificationService...");

    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('✅ Permission status: ${settings.authorizationStatus}');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Foreground message: ${message.notification?.title}');
      _showNotificationSnackBar(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Message opened: ${message.notification?.title}');
    });

    print("✅ NotificationService initialized");
  }

  static Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  static void _showNotificationSnackBar(RemoteMessage message) {
    if (_context == null) return;

    final notification = message.notification;
    if (notification != null) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title ?? 'Notification',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notification.body ?? '',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      print("✅ Notification displayed!");
    }
  }
}
