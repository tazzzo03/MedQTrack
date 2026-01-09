import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
// nanti kita buat
import 'view/auth/auth_gate.dart'; 
// simple Home screen (boleh guna placeholder)
import 'view/app_shell.dart';
import 'view/theme.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/notification_event.dart';


const AndroidNotificationChannel _mediqtrackChannel = AndroidNotificationChannel(
  'mediqtrack_channel',
  'MediQTrack Notifications',
  description: 'Notification channel for MediQTrack alerts',
  importance: Importance.max,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📨 [Background] ${message.notification?.title} → ${message.notification?.body}');
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.url.isEmpty || SupabaseConfig.anonKey.isEmpty) {
    throw StateError(
      'Supabase credentials missing. Pass SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
    );
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ init local notifications (supaya boleh tunjuk banner masa app buka)
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: initSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(_mediqtrackChannel);
  }

  // ✅ background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ foreground listener (notifikasi masa app tengah buka)
  
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print(
        '[Foreground] ${message.notification?.title} | ${message.notification?.body}');
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title != null || body != null) {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'mediqtrack_channel',
        'MediQTrack Notifications',
        channelDescription: 'Notification channel for MediQTrack alerts',
        importance: Importance.max,
        priority: Priority.high,
      );
      const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
      final notificationId = notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        platformDetails,
      );
      NotificationEventBus.ping();
    }
  });

  runApp(const MediQTrackApp());
}

Future<void> _syncFcmTokenToServer(String token) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  try {
    final res = await http.post(
      Uri.parse('http://172.20.10.4:8000/api/update-fcm-token'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'firebase_uid': uid, 'fcm_token': token}),
    );
    print('📡 [SYNC] ${res.statusCode} → ${res.body}');
  } catch (e) {
    print('❌ Sync error: $e');
  }
}


Future<void> setupFCM() async {
  
  print('🧩 [DEBUG] _setupFCM() masuk');
  final user = FirebaseAuth.instance.currentUser;
  print('🧩 [DEBUG] currentUser = ${user?.uid}');
  if (user == null) {
    print('⚠️ [DEBUG] Tiada user login lagi — stop dulu.');
    return;
  }
  final messaging = FirebaseMessaging.instance;

  // ✅ Request notification permission
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('🔔 Permission: ${settings.authorizationStatus}');

  // ✅ Dapatkan token
  String? token = await messaging.getToken();
  print('🔥 FCM Token: $token');
  if (token != null) {
    await _syncFcmTokenToServer(token);
  }

  // ✅ Handle token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    print('♻️ Token refreshed: $newToken');
    _syncFcmTokenToServer(newToken);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediQTrack',
      debugShowCheckedModeBanner: false,
      theme: buildMediTheme(),
      home: const AuthGate(), // dari file auth_gate.dart
    );
  }
}

bool didSetupFCM = false;
