import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mediqtrack03/models/notification_model.dart';

class ApiService {
  static const String baseUrl = "http://10.82.145.75:8000/api"; // ubah ikut IP kalau test di phone

  // ✅ function untuk verify token (testing)
  static Future<void> verifyToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) {
        print('❌ Tiada token (user belum login)');
        return;
      }

      final url = Uri.parse("$baseUrl/verify-token");
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('📩 Laravel Response: ${response.body}');
    } catch (e) {
      print('⚠️ Error verifyToken: $e');
    }
  }

  // ✅ contoh request lain (boleh guna semula pattern ni)
  static Future<dynamic> getUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    final url = Uri.parse("$baseUrl/profile");

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    return jsonDecode(response.body);
  }

  // Sync Firebase user to backend and get patient_id
  static Future<int?> syncUser(String uid, String email) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/sync-user"),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'firebase_uid': uid, 'email': email}),
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body) as Map<String, dynamic>;
        return d['patient_id'] as int?;
      }
    } catch (_) {}
    return null;
  }

  // Fetch notifications for patient
  static Future<List<AlertDto>> fetchNotifications(int patientId) async {
    final url = Uri.parse("$baseUrl/notifications?patient_id=$patientId");
    final res = await http.get(url, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) return [];
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (json['data'] as List).cast<dynamic>();
    return list
        .map((e) => AlertDto.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  static Future<void> markNotificationRead(int id) async {
    await http.patch(
      Uri.parse("$baseUrl/notifications/$id/read"),
      headers: {'Accept': 'application/json'},
    );
  }

  static Future<void> deleteNotification(int id) async {
    await http.delete(
      Uri.parse("$baseUrl/notifications/$id"),
      headers: {'Accept': 'application/json'},
    );
  }
}
