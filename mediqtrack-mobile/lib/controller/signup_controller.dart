// lib/controllers/signup_controller.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class SignUpController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // dY� Daftar akaun baru (Firebase + Laravel)
  Future<UserModel?> signUp({
    required String name,
    required String icNumber,
    required String dob,
    required String gender,
    required String email,
    required String password,
    required String phone,
    required BuildContext context,
  }) async {
    try {
      // 1�,?��� Daftar akaun dalam Firebase Auth
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) throw Exception('Gagal buat akaun.');

      // 2�,?��� Update display name
      await user.updateDisplayName(name);
      await user.reload();

      // 3�,?��� Simpan ke Firestore (optional backup)
      final firestoreData = {
        'name': name,
        'email': email,
        'phone': phone,
        'ic_number': icNumber,
        'dob': dob,
        'gender': gender,
        'createdAt': FieldValue.serverTimestamp(),
        'profileCompleted': true,
        'acceptedTosAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('users').doc(user.uid).set(firestoreData);

      // 4�,?��� Hantar data ke Laravel API (untuk simpan ke MySQL)
      const apiUrl = "http://10.82.150.157:8000/api/register-patient";

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
  'Accept': 'application/json',
  'Content-Type': 'application/json',
},

        body: jsonEncode({
          "firebase_uid": user.uid,
          "name": name,
          "ic_number": icNumber,
          "dob": dob,
          "gender": gender,
          "phone_number": phone,
          "email": email,
          "password": password,
        }),
      );

      print("STATUS: ${response.statusCode}");
print("RAW BODY: ${response.body}");

if (response.statusCode != 200) {
  // Kalau bukan status 200, jangan jsonDecode (sebab mungkin HTML)
  await user.delete();
  _showMessage(context, "Server error (${response.statusCode}).");
  return null;
}

Map<String, dynamic> data;
try {
  data = jsonDecode(response.body);
} catch (e) {
  await user.delete();
  _showMessage(context, "Invalid server response.");
  return null;
}

final ok = data['success'] == true || data['ok'] == true;

if (!ok) {
  await user.delete();
  _showMessage(context, data['message'] ?? "Pendaftaran gagal pada server.");
  return null;
}
      debugPrint("�o. Laravel response: ${data['message'] ?? 'registered'}");

      // 5�,?��� Hantar email pengesahan
      await user.sendEmailVerification();

      // 6�,?��� Papar dialog kejayaan
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Akaun Dicipta'),
          content: Text(
            'Akaun anda telah dicipta.\n\n'
            'Email pengesahan telah dihantar ke $email.\n'
            'Sila sahkan email anda sebelum log masuk.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // 7�,?��� Sign out lepas daftar supaya user kena verify email dulu
      await _auth.signOut();

      return UserModel.fromFirebaseUser(user);
    } on FirebaseAuthException catch (e) {
      String msg = 'Pendaftaran gagal.';
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Email sudah digunakan.';
          break;
        case 'weak-password':
          msg = 'Katalaluan terlalu lemah (min 6 aksara).';
          break;
        case 'invalid-email':
          msg = 'Email tidak sah.';
          break;
        case 'operation-not-allowed':
          msg = 'Pendaftaran tidak dibenarkan. Semak konfigurasi Firebase.';
          break;
        default:
          msg = e.message ?? e.code;
      }
      _showMessage(context, msg);
      return null;
    } catch (e) {
      _showMessage(context, 'Ralat: ${e.toString()}');
      return null;
    }
  }

  void _showMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
