// lib/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotificationService {
  // Singleton style (supaya senang guna di mana-mana)
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // 1️⃣ Request permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Notification permission granted');

      // 2️⃣ Dapatkan token
      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint('📱 FCM Token: $token');

        // TODO: 3️⃣ Simpan token sementara / upload ke server nanti
      }

      // 4️⃣ Listen kalau token berubah
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 Token refreshed: $newToken');
        // TODO: update ke server nanti
      });
    } else {
      debugPrint('⚠️ Notification permission denied');
    }
  }
}
